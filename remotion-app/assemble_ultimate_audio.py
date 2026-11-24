# -*- coding: utf-8 -*-
import os, json, subprocess
import numpy as np
import scipy.io.wavfile as wavfile

BASE_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app"
SFX_DIR = os.path.join(BASE_DIR, "public/rotaplus/sfx")
VOICE_DIR = os.path.join(BASE_DIR, "public/rotaplus/ad_voice")
PRO_VOICE_DIR = os.path.join(BASE_DIR, "public/rotaplus/voice")
OUT_DIR = os.path.join(BASE_DIR, "public/rotaplus/ultimate_voice")
os.makedirs(OUT_DIR, exist_ok=True)

# 1. Pump and normalize voice clips
# We have ad_hook, s05 (mesh/ekip), ad_deprem, ad_gps, ad_autosos, ad_ilkyardim, ad_outro
voice_map = {
    "u_hook": os.path.join(VOICE_DIR, "ad_hook.mp3"),
    "u_mesh": os.path.join(PRO_VOICE_DIR, "s05.mp3"), # Ekip Güvenlik Ağı & Mesh
    "u_deprem": os.path.join(VOICE_DIR, "ad_deprem.mp3"),
    "u_gps": os.path.join(VOICE_DIR, "ad_gps.mp3"),
    "u_autosos": os.path.join(VOICE_DIR, "ad_autosos.mp3"),
    "u_ilkyardim": os.path.join(VOICE_DIR, "ad_ilkyardim.mp3"),
    "u_outro": os.path.join(VOICE_DIR, "ad_outro.mp3")
}

durations = {}

for sc_id, src_path in voice_map.items():
    out_wav = os.path.join(OUT_DIR, f"{sc_id}.wav")
    # Apply energetic trailer pump filter (atempo=1.07, punchy bass, crystal high presence, dynamic compand)
    subprocess.run([
        "ffmpeg", "-y", "-i", src_path,
        "-filter:a", "atempo=1.07, equalizer=f=110:t=q:w=1:g=3.5, equalizer=f=3800:t=q:w=1:g=4.0, compand=0|0:1|1:-60/-60|-20/-10|0/-3:6:0:-90:0.2",
        "-ar", "48000", "-ac", "2",
        out_wav
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", out_wav], stdout=subprocess.PIPE, text=True)
    dur = float(res.stdout.strip())
    durations[sc_id] = dur
    print(f"{sc_id}: {dur:.2f}s")

FPS = 30
SAMPLE_RATE = 48000

scenes_def = [
    {
        "id": "u_hook",
        "dur_sec": durations["u_hook"] + 0.3,
        "title": "ŞEBEKE TAMAMEN ÇÖKTÜĞÜNDE!",
        "sub": "Peki şimdi ne yapacaksın?",
        "tag": "KRİZ SENARYOSU"
    },
    {
        "id": "u_mesh",
        "dur_sec": durations["u_mesh"] + 0.4,
        "title": "DOĞA MESH AĞI & P2P",
        "sub": "Sıfır baz istasyonu. Telefonlar arası doğrudan telsiz ve konum bağı.",
        "tag": "ÇEVRİMDIŞI İLETİŞİM",
        "screen": "s10_mesh.jpg"
    },
    {
        "id": "u_deprem",
        "dur_sec": durations["u_deprem"] + 0.4,
        "title": "DEPREM & ENKAZ ALTI",
        "sub": "Sesin kısılsa bile BLE radarı ve akustik arama yerini ekiplere bildirir.",
        "tag": "AFET PROTOKOLÜ",
        "screen": "s04_deprem.jpg"
    },
    {
        "id": "u_gps",
        "dur_sec": durations["u_gps"] + 0.4,
        "title": "DOĞRUDAN UYDU GPS",
        "sub": "İnternetsiz izohipsli sahra haritasında adım adım rota ve irtifa takibi.",
        "tag": "SEYRÜSEFER",
        "screen": "s03_rota.jpg"
    },
    {
        "id": "u_autosos",
        "dur_sec": durations["u_autosos"] + 0.4,
        "title": "AUTO-SOS & HAREKETSİZLİK",
        "sub": "Düşme veya bayılma anında 20 saniye içinde otomatik siren ve acil SMS.",
        "tag": "DEADMAN SWITCH",
        "screen": "s02_takip.jpg"
    },
    {
        "id": "u_ilkyardim",
        "dur_sec": durations["u_ilkyardim"] + 0.4,
        "title": "ÇEVRİMDIŞI İLK YARDIM",
        "sub": "Turnike, kanama ve dağcılık düğümleri internetsiz elinin altında.",
        "tag": "ACİL MÜDAHALE",
        "screen": "s05_ilkyardim.jpg"
    },
    {
        "id": "u_outro",
        "dur_sec": durations["u_outro"] + 1.2,
        "title": "ROTA+",
        "sub": "Acil durum kapını çalmadan önce telefonunda mutlaka olmalı.",
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

with open(os.path.join(BASE_DIR, "src/ultimate_metadata.json"), "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, ensure_ascii=False)

print(f"Total Frames: {total_frames} ({total_sec:.2f}s)")

# Audio Mix
total_samples = int(total_sec * SAMPLE_RATE) + SAMPLE_RATE
mix = np.zeros((total_samples, 2), dtype=np.float32)

# Load background music
music_file = os.path.join(SFX_DIR, "music.wav")
if os.path.exists(music_file):
    sr, mdata = wavfile.read(music_file)
    if mdata.dtype == np.int16:
        m_norm = mdata.astype(np.float32) / 32768.0
    else:
        m_norm = mdata.astype(np.float32) / np.max(np.abs(mdata))
    if len(m_norm.shape) == 1:
        m_norm = np.column_stack((m_norm, m_norm))
    
    # Loop music to cover total duration
    m_len = len(m_norm)
    for offset in range(0, total_samples, m_len):
        chunk = min(m_len, total_samples - offset)
        # Background music level balanced under voice
        mix[offset:offset+chunk] += m_norm[:chunk] * 0.22

# Add Braam and Intro Boom at start
intro_boom = os.path.join(SFX_DIR, "intro_boom.wav")
if os.path.exists(intro_boom):
    sr, bdata = wavfile.read(intro_boom)
    bnorm = bdata.astype(np.float32) / (32768.0 if bdata.dtype == np.int16 else np.max(np.abs(bdata)))
    if len(bnorm.shape) == 1: bnorm = np.column_stack((bnorm, bnorm))
    blen = min(len(bnorm), total_samples)
    mix[:blen] += bnorm[:blen] * 0.45

# Add SFX per scene
whoosh_file = os.path.join(SFX_DIR, "whoosh.wav")
alarm_file = os.path.join(SFX_DIR, "alarm.wav")
pulse_file = os.path.join(SFX_DIR, "pulse.wav")

sr_w, wdata = wavfile.read(whoosh_file)
wnorm = wdata.astype(np.float32) / (32768.0 if wdata.dtype == np.int16 else np.max(np.abs(wdata)))
if len(wnorm.shape) == 1: wnorm = np.column_stack((wnorm, wnorm))

sr_a, adata = wavfile.read(alarm_file)
anorm = adata.astype(np.float32) / (32768.0 if adata.dtype == np.int16 else np.max(np.abs(adata)))
if len(anorm.shape) == 1: anorm = np.column_stack((anorm, anorm))

# Mix voices and scene cues
for sc in final_scenes:
    sc_id = sc["id"]
    wpath = os.path.join(OUT_DIR, f"{sc_id}.wav")
    start_sec = sc["startFrame"] / FPS
    v_start_idx = int((start_sec + 0.12) * SAMPLE_RATE)
    
    if os.path.exists(wpath):
        sr, vdata = wavfile.read(wpath)
        vnorm = vdata.astype(np.float32) / (32768.0 if vdata.dtype == np.int16 else np.max(np.abs(vdata)))
        if len(vnorm.shape) == 1: vnorm = np.column_stack((vnorm, vnorm))
        vlen = len(vnorm)
        if v_start_idx + vlen <= total_samples:
            mix[v_start_idx:v_start_idx+vlen] += vnorm * 0.98
        else:
            fit = total_samples - v_start_idx
            mix[v_start_idx:total_samples] += vnorm[:fit] * 0.98

    # Scene transition whoosh
    t_idx = int(start_sec * SAMPLE_RATE)
    if t_idx + len(wnorm) < total_samples:
        mix[t_idx:t_idx+len(wnorm)] += wnorm * 0.25

    # Alarm SFX on Auto-SOS scene
    if sc_id == "u_autosos":
        al_idx = t_idx + int(0.5 * SAMPLE_RATE)
        if al_idx + len(anorm) < total_samples:
            mix[al_idx:al_idx+len(anorm)] += anorm * 0.35

# Peak normalize
peak = np.max(np.abs(mix))
if peak > 0:
    mix = (mix / peak) * 0.92

int_mix = (mix * 32767).astype(np.int16)
raw_wav = os.path.join(BASE_DIR, "public/rotaplus/raw_ultimate_mix.wav")
wavfile.write(raw_wav, SAMPLE_RATE, int_mix)

OUT_MASTER = os.path.join(BASE_DIR, "public/rotaplus/ultimate_audio_master.wav")
subprocess.run([
    "ffmpeg", "-y", "-i", raw_wav,
    "-af", "loudnorm=I=-14:LRA=7:TP=-1.5",
    "-ar", "48000", "-ac", "2",
    OUT_MASTER
], check=True)

print("Ultimate Audio Master generated successfully at:", OUT_MASTER)
