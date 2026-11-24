# -*- coding: utf-8 -*-
import os, json, subprocess
import numpy as np
import scipy.io.wavfile as wavfile

BASE_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app"
VOICE_DIR = os.path.join(BASE_DIR, "public/rotaplus/ad_voice")
OUT_AUDIO = os.path.join(BASE_DIR, "public/rotaplus/ad_audio_master.wav")
METADATA_PATH = os.path.join(BASE_DIR, "src/ad_metadata.json")

with open(os.path.join(BASE_DIR, "ad_voice_durations.json"), "r", encoding="utf-8") as f:
    durations = json.load(f)

FPS = 30
SAMPLE_RATE = 48000

scenes_def = [
    {
        "id": "ad_hook",
        "dur_sec": durations["ad_hook"] + 0.3,
        "title": "ŞEBEKE ÇÖKTÜĞÜNDE",
        "sub": "Peki şimdi ne yapacaksın?",
        "tag": "UYARI"
    },
    {
        "id": "ad_deprem",
        "dur_sec": durations["ad_deprem"] + 0.3,
        "title": "DEPREM & ENKAZ ALTI",
        "sub": "Sesin kısılsa bile kurtarma ekipleri seni bulur.",
        "tag": "AFET PROTOKOLÜ",
        "screen": "s04_deprem.jpg"
    },
    {
        "id": "ad_gps",
        "dur_sec": durations["ad_gps"] + 0.3,
        "title": "SIFIR İNTERNET CANLI GPS",
        "sub": "Doğrudan uydu bağlantısıyla çevrimdışı izohipsli sahra haritası.",
        "tag": "SEYRÜSEFER",
        "screen": "s03_rota.jpg"
    },
    {
        "id": "ad_autosos",
        "dur_sec": durations["ad_autosos"] + 0.3,
        "title": "AUTO-SOS & HAREKETSİZLİK",
        "sub": "Kaza veya bayılma anında otomatik siren ve acil durum çağrısı.",
        "tag": "DEADMAN SWITCH",
        "screen": "s02_takip.jpg"
    },
    {
        "id": "ad_ilkyardim",
        "dur_sec": durations["ad_ilkyardim"] + 0.3,
        "title": "ÇEVRİMDIŞI İLK YARDIM",
        "sub": "Turnike, kanama ve dağcılık düğümleri internetsiz elinin altında.",
        "tag": "ACİL MÜDAHALE",
        "screen": "s05_ilkyardim.jpg",
        "screen2": "s06_rehber.jpg"
    },
    {
        "id": "ad_outro",
        "dur_sec": durations["ad_outro"] + 1.2,
        "title": "ROTA+",
        "sub": "Acil durum kapını çalmadan önce indir.",
        "tag": "HEMEN İNDİR"
    }
]

current_frame = 0
final_scenes = []

for sc in scenes_def:
    dur_frames = int(round(sc["dur_sec"] * FPS))
    end_frame = current_frame + dur_frames
    sc_copy = dict(sc)
    sc_copy["startFrame"] = current_frame
    sc_copy["endFrame"] = end_frame
    sc_copy["durationFrames"] = dur_frames
    final_scenes.append(sc_copy)
    current_frame = end_frame

total_frames = current_frame
total_sec = total_frames / FPS

metadata = {
    "fps": FPS,
    "width": 1080,
    "height": 1920,
    "totalFrames": total_frames,
    "totalDurationSec": total_sec,
    "scenes": final_scenes
}

with open(METADATA_PATH, "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, ensure_ascii=False)

print(f"Ad Metadata: {total_frames} frames ({total_sec:.2f}s)")

# Audio Mix
total_samples = int(total_sec * SAMPLE_RATE) + SAMPLE_RATE
mix = np.zeros((total_samples, 2), dtype=np.float32)

# Pulse heartbeat rhythm 124 BPM
t = np.linspace(0, total_sec, total_samples, endpoint=False)
hum = np.sin(2 * np.pi * 50 * t) * 0.02
mix[:, 0] += hum
mix[:, 1] += hum

beat_interval = 60.0 / 124.0
num_beats = int(total_sec / beat_interval)
for b in range(num_beats):
    beat_time = b * beat_interval
    idx = int(beat_time * SAMPLE_RATE)
    kick_len = int(0.08 * SAMPLE_RATE)
    if idx + kick_len < total_samples:
        kt = np.linspace(0, 0.08, kick_len, endpoint=False)
        decay = np.exp(-kt * 45)
        k_wave = np.sin(2 * np.pi * (85 - 40 * kt / 0.08) * kt) * decay * 0.075
        mix[idx:idx+kick_len, 0] += k_wave
        mix[idx:idx+kick_len, 1] += k_wave

# Add voice tracks
for sc in final_scenes:
    sc_id = sc["id"]
    wav_file = os.path.join(VOICE_DIR, f"{sc_id}.wav")
    start_sec = sc["startFrame"] / FPS
    v_start_sec = start_sec + 0.12
    v_start_idx = int(v_start_sec * SAMPLE_RATE)
    
    if os.path.exists(wav_file):
        sr, vdata = wavfile.read(wav_file)
        if vdata.dtype == np.int16:
            v_norm = vdata.astype(np.float32) / 32768.0
        elif vdata.dtype == np.float32:
            v_norm = vdata
        else:
            v_norm = vdata.astype(np.float32) / np.max(np.abs(vdata))
            
        if len(v_norm.shape) == 1:
            v_stereo = np.column_stack((v_norm, v_norm))
        else:
            v_stereo = v_norm
            
        v_len = len(v_stereo)
        if v_start_idx + v_len <= total_samples:
            mix[v_start_idx:v_start_idx+v_len] += v_stereo * 0.98
        else:
            fit_len = total_samples - v_start_idx
            mix[v_start_idx:total_samples] += v_stereo[:fit_len] * 0.98

    # Scene switch whoosh SFX
    t_idx = int(start_sec * SAMPLE_RATE)
    sfx_len = int(0.15 * SAMPLE_RATE)
    if t_idx + sfx_len < total_samples:
        st = np.linspace(0, 0.15, sfx_len, endpoint=False)
        whoosh = np.sin(2 * np.pi * (1200 - 800 * st / 0.15) * st) * np.exp(-st * 30) * 0.1
        mix[t_idx:t_idx+sfx_len, 0] += whoosh
        mix[t_idx:t_idx+sfx_len, 1] += whoosh

# Normalize and convert
peak = np.max(np.abs(mix))
if peak > 0:
    mix = (mix / peak) * 0.92

int_mix = (mix * 32767).astype(np.int16)
raw_wav = os.path.join(BASE_DIR, "public/rotaplus/raw_ad_mix.wav")
wavfile.write(raw_wav, SAMPLE_RATE, int_mix)

subprocess.run([
    "ffmpeg", "-y", "-i", raw_wav,
    "-af", "loudnorm=I=-14:LRA=7:TP=-1.5",
    "-ar", "48000", "-ac", "2",
    OUT_AUDIO
], check=True)

print("Ad Master Audio ready at:", OUT_AUDIO)
