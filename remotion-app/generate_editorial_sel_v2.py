import os
import json
import math
import asyncio
import subprocess
import edge_tts

WORK_DIR = r"C:\Users\rirew\Downloads\gps-rota-app-repo\remotion-app"
PUBLIC_DIR = os.path.join(WORK_DIR, "public", "editorial_sel")
SFX_DIR = os.path.join(PUBLIC_DIR, "sfx")
os.makedirs(PUBLIC_DIR, exist_ok=True)
os.makedirs(SFX_DIR, exist_ok=True)

FPS = 30
VOICE = "tr-TR-EmelNeural"
RATE = "+18%"

SCENES = [
    {
        "id": "scene_00_intro",
        "fig": "FIG. 00",
        "fig_title": "ROTA MEDYA ÖZEL DOSYA",
        "coords": "41.01°K  028.98°D",
        "scale": "1000 km",
        "script": "Rota Medya Özel Dosya. İstanbul Afet Raporu."
    },
    {
        "id": "scene_01_rekor",
        "fig": "FIG. 01",
        "fig_title": "84 YILIN REKORU",
        "coords": "41.13°K  029.10°D",
        "scale": "500 km",
        "script": "14 Ekim gecesi İstanbul, 84 yılın en büyük yağış rekoruna uyandı. Beykoz ve Sarıyer'de metrekareye tam 272 kilogram su indi. Peki aylar süren şiddetli kuraklıktan sonra nasıl oldu da tek bir günde bu felaket yaşandı?"
    },
    {
        "id": "scene_02_toprak",
        "fig": "FIG. 02",
        "fig_title": "TOPRAK PARADOKSU",
        "coords": "41.11°K  029.08°D",
        "scale": "10 m (KESİT)",
        "script": "Çoğu insan kurak toprağın suyu sünger gibi çekeceğini düşünür; oysa zemin fiziğinde durum tam tersidir. Aylarca kavrulan toprak gözeneklerini kapatır ve hidrofobik bir taşa dönüşür. Yağan su toprağa sızamaz, camdan akar gibi doğrudan sele dönüşür."
    },
    {
        "id": "scene_03_meteoroloji",
        "fig": "FIG. 03",
        "fig_title": "SÜPERHÜCRE VE TREN ETKİSİ",
        "coords": "41.20°K  029.05°D",
        "scale": "14 km (TROPOSFER)",
        "script": "İkinci darbe gökyüzünden geldi. Karadeniz'in mevsim normallerinden 4 derece sıcak suları, kuzeyden inen eksi 25 derecelik kutup havasıyla Boğaz üzerinde çarpıştı. Oluşan süperhücre, tren etkisiyle hareket etmeden saatlerce aynı ilçelerin üzerine boşaldı."
    },
    {
        "id": "scene_04_beton",
        "fig": "FIG. 04",
        "fig_title": "BETON ZIRH VE DERELER",
        "coords": "41.08°K  028.97°D",
        "scale": "50 m (KENTSEL)",
        "script": "Megakent ise bu suyu karşılayacak durumda değildi. İstanbul'un yüzde 80'i beton ve asfaltla kaplı. Üstelik geçmişte suyu denize taşıyan doğal derelerin üzeri binalarla kapatıldı. Menfezlere sığmayan su, kendi eski yatağını zorla geri aldı."
    },
    {
        "id": "scene_05_sunger",
        "fig": "FIG. 05",
        "fig_title": "ÇÖZÜM: SÜNGER ŞEHİR",
        "coords": "41.00°K  029.00°D",
        "scale": "MİMARİ TASARIM",
        "script": "Peki çare ne? Klasik yağmur boruları artık yetersiz. İklim krizinde tek kurtuluş; suyu hızla tahliye etmek yerine sünger gibi emen geçirimli kaldırımlar, yağmur bahçeleri ve yeraltı sarnıçlarına sahip Sünger Şehir modelidir."
    },
    {
        "id": "scene_06_sonuc",
        "fig": "FIG. 06",
        "fig_title": "SONUÇ VE TARTIŞMA",
        "coords": "41.01°K  028.98°D",
        "scale": "RAPOR SONU",
        "script": "Unutmayın: Doğa, kendisine ait olanı eninde sonunda geri alır. Sizce şehirlerimiz bu yeni iklim çağına hazır mı? Yorumlarda tartışalım."
    }
]

def get_duration(p):
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", p]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return float(res.stdout.strip())

async def synthesize_all():
    print(f"--- 1. Synthesizing voice clips with {VOICE} at {RATE} ---")
    processed_clips = []
    for idx, sc in enumerate(SCENES):
        raw = os.path.join(PUBLIC_DIR, f"{sc['id']}_raw.mp3")
        proc = os.path.join(PUBLIC_DIR, f"{sc['id']}_proc.mp3")
        print(f"[{idx+1}/{len(SCENES)}] Synthesizing {sc['id']}...")
        comm = edge_tts.Communicate(sc["script"], VOICE, rate=RATE)
        await comm.save(raw)
        
        # Broadcast dialogue mastering: warm bass, presence boost, gentle compression
        cmd_ff = [
            "ffmpeg", "-y", "-i", raw,
            "-filter:a", "equalizer=f=120:t=q:w=1:g=2.5,equalizer=f=3400:t=q:w=1.2:g=3.2,equalizer=f=8000:t=q:w=1:g=2.0,acompressor=threshold=-16dB:ratio=3.5:attack=5:release=50,volume=1.25",
            "-ar", "44100", "-b:a", "192k", proc
        ]
        subprocess.run(cmd_ff, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        dur = get_duration(proc)
        processed_clips.append({"path": proc, "dur": dur})
        print(f"  -> Duration: {dur:.2f}s")
    return processed_clips

processed_clips = asyncio.run(synthesize_all())

print("--- 2. Building Scene Timings & Metadata ---")
current_frame = 0
scene_metadata = []

for idx, sc in enumerate(SCENES):
    dur = processed_clips[idx]["dur"]
    scene_frames = int(math.ceil((dur + 0.6) * FPS))
    if sc["id"] == "scene_00_intro":
        scene_frames = max(scene_frames, 75) # 2.5s min for intro sting
        
    start_frame = current_frame
    end_frame = current_frame + scene_frames
    
    scene_metadata.append({
        "id": sc["id"],
        "fig": sc["fig"],
        "fig_title": sc["fig_title"],
        "coords": sc["coords"],
        "scale": sc["scale"],
        "script": sc["script"],
        "startFrame": start_frame,
        "endFrame": end_frame,
        "durationFrames": scene_frames,
        "audioDurationSec": dur
    })
    current_frame = end_frame

total_frames = current_frame
total_seconds = total_frames / FPS
print(f"Total video duration: {total_seconds:.2f}s ({total_frames} frames)")

# Save scene metadata
json_path = os.path.join(WORK_DIR, "src", "editorial_sel_metadata.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)
print(f"Saved metadata to {json_path}")

print("--- 3. Generating Sound Effects & Foley ---")
# 1. Sub-bass boom
cmd_boom = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "sine=frequency=65:duration=2.5",
    "-filter:a", "volume=1.8,lowpass=f=120,afade=t=out:st=0.3:d=2.2",
    os.path.join(SFX_DIR, "boom.wav")
]
subprocess.run(cmd_boom, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 2. Cinematic riser / whoosh
cmd_swoosh = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "anoisesrc=d=0.7:c=pink:r=44100:a=0.3",
    "-filter:a", "bandpass=f=1200:width_type=h:w=800,afade=t=in:st=0:d=0.35,afade=t=out:st=0.35:d=0.35,volume=1.4",
    os.path.join(SFX_DIR, "swoosh.wav")
]
subprocess.run(cmd_swoosh, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 3. Ambient documentary drone
cmd_drone = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    f"sine=frequency=55:duration={total_seconds + 3.0}",
    "-filter:a", "volume=0.18,lowpass=f=110",
    os.path.join(SFX_DIR, "drone.wav")
]
subprocess.run(cmd_drone, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 4. Tension clock tick / pulse
cmd_pulse = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    f"sine=frequency=440:duration={total_seconds + 3.0}",
    "-filter:a", "volume=0.08,tremolo=f=4:d=0.9,bandpass=f=900:w=300",
    os.path.join(SFX_DIR, "pulse.wav")
]
subprocess.run(cmd_pulse, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

# 5. Thunder rumble
cmd_thunder = [
    "ffmpeg", "-y", "-f", "lavfi", "-i",
    "anoisesrc=d=3.0:c=brown:r=44100:a=0.5",
    "-filter:a", "lowpass=f=220,afade=t=in:st=0:d=0.4,afade=t=out:st=1.2:d=1.8,volume=1.6",
    os.path.join(SFX_DIR, "thunder.wav")
]
subprocess.run(cmd_thunder, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

print("--- 4. Mixing Master Audio Graph ---")
inputs = []
filter_parts = []

# Voice clips
for idx, sc in enumerate(scene_metadata):
    inputs.extend(["-i", processed_clips[idx]["path"]])
    start_sec = sc["startFrame"] / FPS
    delay_ms = int(start_sec * 1000)
    filter_parts.append(f"[{idx}]adelay={delay_ms}|{delay_ms},volume=1.35[v{idx}];")

base_idx = len(scene_metadata)

# Background drone & pulse
inputs.extend(["-i", os.path.join(SFX_DIR, "drone.wav")])
filter_parts.append(f"[{base_idx}]volume=0.22[bg_drone];")

inputs.extend(["-i", os.path.join(SFX_DIR, "pulse.wav")])
filter_parts.append(f"[{base_idx+1}]volume=0.15[bg_pulse];")

# Transitions: booms and swooshes at each scene change
sfx_count = 0
sfx_outputs = []

for idx, sc in enumerate(scene_metadata):
    start_sec = sc["startFrame"] / FPS
    delay_ms = int(start_sec * 1000)
    
    # Boom at scene start
    curr_boom = base_idx + 2 + sfx_count
    inputs.extend(["-i", os.path.join(SFX_DIR, "boom.wav")])
    filter_parts.append(f"[{curr_boom}]adelay={delay_ms}|{delay_ms},volume=0.85[sfx_b{idx}];")
    sfx_outputs.append(f"[sfx_b{idx}]")
    sfx_count += 1
    
    # Swoosh
    curr_swoosh = base_idx + 2 + sfx_count
    inputs.extend(["-i", os.path.join(SFX_DIR, "swoosh.wav")])
    swoosh_delay = max(0, delay_ms - 150)
    filter_parts.append(f"[{curr_swoosh}]adelay={swoosh_delay}|{swoosh_delay},volume=0.75[sfx_sw{idx}];")
    sfx_outputs.append(f"[sfx_sw{idx}]")
    sfx_count += 1

# Thunder at scene 3 (meteoroloji)
sc3_delay = int((scene_metadata[3]["startFrame"] / FPS) * 1000)
curr_thunder = base_idx + 2 + sfx_count
inputs.extend(["-i", os.path.join(SFX_DIR, "thunder.wav")])
filter_parts.append(f"[{curr_thunder}]adelay={sc3_delay}|{sc3_delay},volume=1.2[sfx_th];")
sfx_outputs.append("[sfx_th]")
sfx_count += 1

all_sources = "".join([f"[v{i}]" for i in range(len(scene_metadata))]) + "[bg_drone][bg_pulse]" + "".join(sfx_outputs)
total_sources = len(scene_metadata) + 2 + len(sfx_outputs)

filter_graph = "".join(filter_parts) + f"{all_sources}amix=inputs={total_sources}:duration=longest:dropout_transition=2,volume=1.4[outa]"

master_audio_path = os.path.join(PUBLIC_DIR, "editorial_sel_master_soundtrack.mp3")
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
