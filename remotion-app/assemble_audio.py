# -*- coding: utf-8 -*-
import os, json, subprocess
import numpy as np
import scipy.io.wavfile as wavfile

BASE_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app"
VOICE_DIR = os.path.join(BASE_DIR, "public/rotaplus/voice")
OUT_AUDIO = os.path.join(BASE_DIR, "public/rotaplus/audio_master.wav")
METADATA_PATH = os.path.join(BASE_DIR, "src/rotaplus_metadata.json")

# Read voice durations
with open(os.path.join(BASE_DIR, "voice_durations.json"), "r", encoding="utf-8") as f:
    durations = json.load(f)

FPS = 30
SAMPLE_RATE = 48000

scenes_def = [
    {
        "id": "hook",
        "dur_sec": durations["hook"] + 0.5,
        "tag": "UYARI",
        "title": "ŞEBEKE YOK",
        "sub": "ROTA+ ÇALIŞMAYA DEVAM EDER"
    },
    {
        "id": "s01",
        "dur_sec": durations["s01"] + 0.5,
        "num": "01",
        "tag": "METEOROLOJİ",
        "title": "KOKPİT & METEOROLOJİ",
        "sub": "Hava durumu, barometre, irtifa ve pusula tek bakışta elinizin altında.",
        "screen": "s01_kokpit.jpg"
    },
    {
        "id": "s02",
        "dur_sec": durations["s02"] + 0.5,
        "num": "02",
        "tag": "NAVİGASYON",
        "title": "CANLI GPS TAKİBİ",
        "sub": "Canlı GPS takibiyle adımlarınızı haritaya işleyin, rotanızı asla kaybetmeyin.",
        "screen": "s02_takip.jpg"
    },
    {
        "id": "s03",
        "dur_sec": durations["s03"] + 0.5,
        "num": "03",
        "tag": "GÜVENLİK",
        "title": "AUTO-SOS PRO",
        "sub": "Hareketsizlik sensörü, bayılma veya kaza anında otomatik devreye girer.",
        "screen": "s02_takip.jpg"
    },
    {
        "id": "s04",
        "dur_sec": durations["s04"] + 0.5,
        "num": "04",
        "tag": "HARİTA",
        "title": "TOPOGRAFİK ROTA",
        "sub": "İzohipsli sahra haritasıyla internet olmadan yeni rotalar çizin ve ara nokta ekleyin.",
        "screen": "s03_rota.jpg"
    },
    {
        "id": "s05",
        "dur_sec": durations["s05"] + 0.5,
        "num": "05",
        "tag": "GÜVENLİK AĞI",
        "title": "EKİP GÜVENLİK AĞI",
        "sub": "Sahadaki tüm ekip üyelerinin durumunu ve anlık yardım çağrılarını koordinatlarıyla görün.",
        "screen": "s07_sos.jpg"
    },
    {
        "id": "s06",
        "dur_sec": durations["s06"] + 0.5,
        "num": "06",
        "tag": "AFET",
        "title": "DEPREM & ENKAZ MODU",
        "sub": "Tek dokunuşla Güvendeyim mesajı atın, hayatta kalma sayacı ve ses arama dedektörünü başlatın.",
        "screen": "s04_deprem.jpg"
    },
    {
        "id": "s07",
        "dur_sec": durations["s07"] + 0.5,
        "num": "07",
        "tag": "İLKYARDIM",
        "title": "ACİL İLK YARDIM",
        "sub": "Yaralanma ve travmalarda adım adım sesli ve görsel müdahale rehberi sunar.",
        "screen": "s05_ilkyardim.jpg"
    },
    {
        "id": "s08",
        "dur_sec": durations["s08"] + 0.5,
        "num": "08",
        "tag": "DAĞCILIK",
        "title": "HAYATTA KALMA REHBERİ",
        "sub": "Teknik dağcılık düğümleri ve sahra protokolleri internetsiz elinizin altında.",
        "screen": "s06_rehber.jpg"
    },
    {
        "id": "s09",
        "dur_sec": durations["s09"] + 0.5,
        "num": "09",
        "tag": "DONANIM",
        "title": "ASKERİ DONANIM UYUMU",
        "sub": "L-Band uydu uyumu ve minimum pil tüketimiyle en zorlu şartlarda yanınızda.",
        "screen": "s01_kokpit.jpg"
    },
    {
        "id": "outro",
        "dur_sec": durations["outro"] + 1.2,
        "tag": "İNDİR",
        "title": "ROTA+",
        "sub": "ZORLU KOŞULLARDA YANINDA."
    }
]

# Calculate start and end frames
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

print(f"Total Frames: {total_frames} ({total_sec:.2f}s)")

# Now assemble Master Audio using numpy
total_samples = int(total_sec * SAMPLE_RATE) + SAMPLE_RATE
mix = np.zeros((total_samples, 2), dtype=np.float32)

# 1. Add subtle 124 BPM tactical heartbeat pulse & low hum
t = np.linspace(0, total_sec, total_samples, endpoint=False)
hum = np.sin(2 * np.pi * 55 * t) * 0.025 + np.sin(2 * np.pi * 110 * t) * 0.015
mix[:, 0] += hum
mix[:, 1] += hum

# Pulse beat at 124 BPM (0.4839 sec interval)
beat_interval = 60.0 / 124.0
num_beats = int(total_sec / beat_interval)
for b in range(num_beats):
    beat_time = b * beat_interval
    idx = int(beat_time * SAMPLE_RATE)
    # 80ms kick
    kick_len = int(0.08 * SAMPLE_RATE)
    if idx + kick_len < total_samples:
        kt = np.linspace(0, 0.08, kick_len, endpoint=False)
        decay = np.exp(-kt * 45)
        # sub drop pitch glide 90Hz -> 45Hz
        k_wave = np.sin(2 * np.pi * (90 - 45 * kt / 0.08) * kt) * decay * 0.08
        mix[idx:idx+kick_len, 0] += k_wave
        mix[idx:idx+kick_len, 1] += k_wave

# 2. Add Voice Tracks and Scene Transition SFX
for sc in final_scenes:
    sc_id = sc["id"]
    wav_file = os.path.join(VOICE_DIR, f"{sc_id}.wav")
    start_sec = sc["startFrame"] / FPS
    # start voice 0.15s after scene start
    v_start_sec = start_sec + 0.15
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
            mix[v_start_idx:v_start_idx+v_len] += v_stereo * 0.95
        else:
            fit_len = total_samples - v_start_idx
            mix[v_start_idx:total_samples] += v_stereo[:fit_len] * 0.95

    # Tactical Transition SFX at slide start
    t_idx = int(start_sec * SAMPLE_RATE)
    # Tactical whoosh / metallic click
    sfx_len = int(0.12 * SAMPLE_RATE)
    if t_idx + sfx_len < total_samples:
        st = np.linspace(0, 0.12, sfx_len, endpoint=False)
        click = np.sin(2 * np.pi * 1400 * st) * np.exp(-st * 60) * 0.12
        mix[t_idx:t_idx+sfx_len, 0] += click
        mix[t_idx:t_idx+sfx_len, 1] += click

# Normalize mix to avoid any digital clipping
peak = np.max(np.abs(mix))
if peak > 0:
    mix = (mix / peak) * 0.92

int_mix = (mix * 32767).astype(np.int16)
raw_wav = os.path.join(BASE_DIR, "public/rotaplus/raw_mix.wav")
wavfile.write(raw_wav, SAMPLE_RATE, int_mix)

# Final loudnorm to -14.0 LUFS via ffmpeg
subprocess.run([
    "ffmpeg", "-y", "-i", raw_wav,
    "-af", "loudnorm=I=-14:LRA=7:TP=-1.5",
    "-ar", "48000", "-ac", "2",
    OUT_AUDIO
], check=True)

print("Master Audio generated successfully at:", OUT_AUDIO)
