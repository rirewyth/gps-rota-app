import os
import json
import math
import asyncio
import subprocess
import edge_tts

WORK_DIR = r"C:\Users\rirew\Downloads\gps-rota-app-repo\remotion-app"
PUBLIC_DIR = os.path.join(WORK_DIR, "public", "yercekimi_v2")
SFX_DIR = os.path.join(PUBLIC_DIR, "sfx")
os.makedirs(PUBLIC_DIR, exist_ok=True)
os.makedirs(SFX_DIR, exist_ok=True)

FPS = 30
VOICE = "tr-TR-EmelNeural"
RATE = "+10%"
PITCH = "-5Hz"

SCENES = [
    {
        "id": "scene_00_intro",
        "badge": "ROTA MEDYA ÖZEL DOSYA",
        "timer": "00:00",
        "script": "Rota Medya Özel Dosya."
    },
    {
        "id": "scene_01_hook",
        "badge": "🛸 YERÇEKİMİ: 0G",
        "timer": "10.0 SN",
        "script": "Peki ya Dünya'da yerçekimi bir anda, sadece 10 saniyeliğine tamamen yok olsaydı ne olurdu?"
    },
    {
        "id": "scene_02_room",
        "badge": "☕ HAVADA SÜZÜLME",
        "timer": "08.5 SN",
        "script": "İlk saniyede hiçbir şey fark etmezsin. Ta ki masandaki kahve fincandan çıkıp havada bir su küresi gibi süzülene ve sen tavana doğru uçana kadar!"
    },
    {
        "id": "scene_03_street",
        "badge": "☁️ İRTİFA: +45 METRE",
        "timer": "06.0 SN",
        "script": "Dışarıda ise tam bir kaos başlar! Arabaların tekerlekleri havada boşa döner. İnsanlar, köpekler ve sokaktaki her şey gökyüzüne doğru savrulur."
    },
    {
        "id": "scene_04_oceans",
        "badge": "🌊 OKYANUSLAR UÇUYOR",
        "timer": "03.0 SN",
        "script": "Daha kötüsü; Dünya'nın dönüş hızı yüzünden okyanuslar dev kütleler halinde havaya yükselir ve atmosfer uzaya doğru kaçmaya başlar!"
    },
    {
        "id": "scene_05_crash",
        "badge": "⚠️ YERÇEKİMİ AÇILDI!",
        "timer": "00.0 SN",
        "script": "Ama en büyük felaket, onuncu saniyede yerçekiminin aniden geri gelmesidir! Havaya fırlayan her şey yüz metreden yere çakılır. Neyse ki sadece on saniyeydi... değil mi?"
    }
]

def get_duration(p):
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", p]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return float(res.stdout.strip())

async def synthesize_all():
    print(f"--- 1. Synthesizing voice clips with {VOICE} ({RATE}, {PITCH}) ---")
    processed_clips = []
    for idx, sc in enumerate(SCENES):
        raw = os.path.join(PUBLIC_DIR, f"{sc['id']}_raw.mp3")
        proc = os.path.join(PUBLIC_DIR, f"{sc['id']}_proc.mp3")
        print(f"[{idx+1}/{len(SCENES)}] Synthesizing {sc['id']}...")
        comm = edge_tts.Communicate(sc["script"], VOICE, rate=RATE, pitch=PITCH)
        await comm.save(raw)
        
        # Professional warm podcast mastering
        cmd_ff = [
            "ffmpeg", "-y", "-i", raw,
            "-filter:a", "equalizer=f=80:t=h:width=1,equalizer=f=120:t=q:w=1:g=2.5,equalizer=f=450:t=q:w=1:g=-2.0,equalizer=f=3200:t=q:w=1.2:g=3.8,equalizer=f=10000:t=q:w=1:g=2.2,acompressor=threshold=-16dB:ratio=3.5:attack=5:release=50,volume=1.3",
            "-ar", "44100", "-b:a", "192k", proc
        ]
        subprocess.run(cmd_ff, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        dur = get_duration(proc)
        processed_clips.append({"path": proc, "dur": dur})
        print(f"  -> Duration: {dur:.2f}s")
    return processed_clips

processed_clips = asyncio.run(synthesize_all())

print("--- 2. Building Scene Timings & Word Metadata ---")
current_frame = 0
scene_metadata = []

for idx, sc in enumerate(SCENES):
    dur = processed_clips[idx]["dur"]
    scene_frames = int(math.ceil((dur + 0.6) * FPS))
    if sc["id"] == "scene_00_intro":
        scene_frames = max(scene_frames, 75) # 2.5s min for intro sting
        
    start_frame = current_frame
    end_frame = current_frame + scene_frames
    
    words = sc["script"].split()
    total_chars = sum(len(w) for w in words)
    speech_frames = int(dur * FPS)
    
    word_timings = []
    w_start = 0
    for w in words:
        w_dur = max(4, int((len(w) / total_chars) * speech_frames))
        w_end = min(speech_frames, w_start + w_dur)
        word_timings.append({
            "text": w,
            "startFrame": start_frame + w_start,
            "endFrame": start_frame + w_end
        })
        w_start = w_end
        
    scene_metadata.append({
        "id": sc["id"],
        "badge": sc["badge"],
        "timer": sc["timer"],
        "script": sc["script"],
        "startFrame": start_frame,
        "endFrame": end_frame,
        "durationFrames": scene_frames,
        "audioDurationSec": dur,
        "words": word_timings
    })
    current_frame = end_frame

total_frames = current_frame
total_seconds = total_frames / FPS
print(f"Total video duration: {total_seconds:.2f}s ({total_frames} frames)")

json_path = os.path.join(WORK_DIR, "src", "yercekimi_v2_metadata.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)
print(f"Saved metadata to {json_path}")

print("--- 3. Generating Cartoon Foley & Sound FX ---")
# 1. ROTA MEDYA intro boom
cmd_intro_boom = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "sine=frequency=55:duration=2.5",
    "-filter:a", "volume=2.0,lowpass=f=110,afade=t=out:st=0.3:d=2.2",
    os.path.join(SFX_DIR, "intro_boom.wav")
]
subprocess.run(cmd_intro_boom, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 2. Pop / Bubble (coffee floating)
cmd_pop = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "sine=frequency=950:duration=0.25",
    "-filter:a", "volume=1.6,afade=t=out:st=0.04:d=0.2",
    os.path.join(SFX_DIR, "pop.wav")
]
subprocess.run(cmd_pop, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 3. Whoosh / Riser
cmd_whoosh = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "anoisesrc=d=0.6:c=pink:r=44100:a=0.3",
    "-filter:a", "bandpass=f=1400:width_type=h:w=900,afade=t=in:st=0:d=0.3,afade=t=out:st=0.3:d=0.3,volume=1.4",
    os.path.join(SFX_DIR, "whoosh.wav")
]
subprocess.run(cmd_whoosh, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 4. Cartoon Bonk / Crash
cmd_bonk = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "sine=frequency=190:duration=1.2",
    "-filter:a", "volume=2.4,lowpass=f=450,afade=t=out:st=0.12:d=1.0",
    os.path.join(SFX_DIR, "bonk.wav")
]
subprocess.run(cmd_bonk, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 5. Playful Pizzicato Background Loop
cmd_music = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    f"sine=frequency=587.33:duration={total_seconds + 3.0}",
    "-filter:a", "volume=0.11,tremolo=f=6.5:d=0.85,bandpass=f=1100:w=350",
    os.path.join(SFX_DIR, "music.wav")
]
subprocess.run(cmd_music, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 6. Deep Space Drone
cmd_drone = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    f"sine=frequency=55:duration={total_seconds + 3.0}",
    "-filter:a", "volume=0.14,lowpass=f=100",
    os.path.join(SFX_DIR, "drone.wav")
]
subprocess.run(cmd_drone, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

print("--- 4. Mixing Master Audio Graph ---")
inputs = []
filter_parts = []

# Voice clips
for idx, sc in enumerate(scene_metadata):
    inputs.extend(["-i", processed_clips[idx]["path"]])
    start_sec = sc["startFrame"] / FPS
    delay_ms = int(start_sec * 1000)
    filter_parts.append(f"[{idx}]adelay={delay_ms}|{delay_ms},volume=1.4[v{idx}];")

base_idx = len(scene_metadata)

# Background music & drone
inputs.extend(["-i", os.path.join(SFX_DIR, "music.wav")])
filter_parts.append(f"[{base_idx}]volume=0.22[bg_music];")

inputs.extend(["-i", os.path.join(SFX_DIR, "drone.wav")])
filter_parts.append(f"[{base_idx+1}]volume=0.16[bg_drone];")

# SFX: Intro boom at start
inputs.extend(["-i", os.path.join(SFX_DIR, "intro_boom.wav")])
filter_parts.append(f"[{base_idx+2}]volume=1.5[sfx_intro];")

# Pop and whooshes
sfx_count = 3
sfx_outputs = ["[sfx_intro]"]

for idx, sc in enumerate(scene_metadata[1:], start=1):
    start_sec = sc["startFrame"] / FPS
    delay_ms = int(start_sec * 1000)
    
    curr_sfx = base_idx + sfx_count
    inputs.extend(["-i", os.path.join(SFX_DIR, "whoosh.wav")])
    filter_parts.append(f"[{curr_sfx}]adelay={delay_ms}|{delay_ms},volume=0.75[sfx_{idx}];")
    sfx_outputs.append(f"[sfx_{idx}]")
    sfx_count += 1

# Big BONK at crash scene
crash_start = int((scene_metadata[5]["startFrame"] / FPS) * 1000) + 1200
curr_bonk = base_idx + sfx_count
inputs.extend(["-i", os.path.join(SFX_DIR, "bonk.wav")])
filter_parts.append(f"[{curr_bonk}]adelay={crash_start}|{crash_start},volume=1.7[sfx_bonk];")
sfx_outputs.append("[sfx_bonk]")
sfx_count += 1

all_sources = "".join([f"[v{i}]" for i in range(len(scene_metadata))]) + "[bg_music][bg_drone]" + "".join(sfx_outputs)
total_sources = len(scene_metadata) + 2 + len(sfx_outputs)

filter_graph = "".join(filter_parts) + f"{all_sources}amix=inputs={total_sources}:duration=longest:dropout_transition=2,volume=1.4[outa]"

master_audio_path = os.path.join(PUBLIC_DIR, "yercekimi_v2_master_soundtrack.mp3")
cmd_mix = [
    "ffmpeg", "-y",
    *inputs,
    "-filter_complex", filter_graph,
    "-map", "[outa]",
    "-t", f"{total_seconds + 0.5:.2f}",
    "-ar", "44100",
    "-b:a", "256k",
    master_audio_path
]

print("Executing FFmpeg master audio mix...")
subprocess.run(cmd_mix, check=True)
master_dur = get_duration(master_audio_path)
print(f"Master soundtrack generated successfully! Duration: {master_dur:.2f}s -> {master_audio_path}")
