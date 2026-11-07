import os
import json
import math
import subprocess
import numpy as np

FPS = 30
WORK_DIR = r"C:\Users\rirew\Downloads\gps-rota-app-repo\remotion-app"
PUBLIC_DIR = os.path.join(WORK_DIR, "public", "iki_gunes")
SFX_DIR = os.path.join(PUBLIC_DIR, "sfx")
os.makedirs(PUBLIC_DIR, exist_ok=True)

SCENES = [
    {
        "id": "scene_01_hook",
        "badge": "KOZMİK SİMÜLASYON",
        "top_title": "GÖKYÜZÜNDE 2 GÜNEŞ",
        "glow_title": "OLSAYDI NE OLURDU?",
        "tag": "İKİLİ YILDIZ SİSTEMİ // BARYCENTER",
        "script": "Gökyüzüne baktığınızda tek bir Güneş yerine iki devasa yıldız görseydiniz ne olurdu? Bilim kurgudaki Tatooine gibi huzurlu mu, yoksa tam bir kıyamet mi?",
        "type": "binary_stars"
    },
    {
        "id": "scene_02_orbit",
        "badge": "KÜTLEÇEKİM KRİZİ",
        "top_title": "ÜÇ CİSİM PROBLEMİ",
        "glow_title": "YÖRÜNGE PARÇALANIR!",
        "tag": "KAOTİK ORBİTAL ÇEKİM // 2X GRAVİTE",
        "script": "İlk büyük tehlike kütleçekimdir. Fizikteki üç cisim problemi yüzünden Dünya’nın kararlı yörüngesi bozulur; ya uzayın derinliklerine fırlar ya da Güneş'e çarpardık!",
        "type": "orbital_chaos"
    },
    {
        "id": "scene_03_daynight",
        "badge": "BİYOLOJİK İFLAS",
        "top_title": "GECE KAVRAMI SİLİNİR",
        "glow_title": "24 SAAT ARALIKSIZ GÜNDÜZ!",
        "tag": "SİRKADİYEN RİTİM ÇÖKÜŞÜ // 0 LUX KARANLIK",
        "script": "Eğer iki güneş gökyüzünde zıt yönlerde olsaydı, Dünya'da gece kavramı tamamen yok olurdu. 24 saat süren aralıksız gündüz, bitkileri ve tüm yaşamı yok ederdi.",
        "type": "daynight_loss"
    },
    {
        "id": "scene_04_temperature",
        "badge": "TERMAL ÇÖKÜŞ",
        "top_title": "KÜRESEL ISI 85 DERECE",
        "glow_title": "OKYANUSLAR KAYNAR!",
        "tag": "TERMAL ALARM // SU KAYBI %70",
        "script": "İki kat güneş ışınımı, gezegenin sıcaklığını anında 80 derecenin üzerine çıkarırdı. Göller buharlaşır, nehirler kurur ve okyanuslar kaynamaya başlardı.",
        "type": "thermal_collapse"
    },
    {
        "id": "scene_05_radiation",
        "badge": "RADYASYON BOMBARDIMANI",
        "top_title": "MANYETİK KALKAN EZİLİR",
        "glow_title": "ÖLÜMCÜL SOLAR FIRTINA!",
        "tag": "UV İNDEKSİ: 30+ // KORUYUCU OZON KAYBI",
        "script": "Çifte güneş rüzgarları Dünya'nın manyetik kalkanını ezer ve yeryüzünü ultraviyole radyasyon fırınına çevirerek tüm canlı hücreleri dakikalar içinde parçalardı.",
        "type": "radiation_storm"
    },
    {
        "id": "scene_06_outro",
        "badge": "BİLİMSEL GERÇEK",
        "top_title": "MÜKEMMEL DENGEDEYİZ",
        "glow_title": "TEK GÜNEŞİMİZ MUCİZE!",
        "tag": "ROTA BİLİM // ABONE OL & KEŞFET",
        "script": "Evrende milyarlarca çift yıldız var; ancak hayatın var olabilmesi, gökyüzündeki o tek ve mükemmel Güneş’e borçlu olduğumuz eşsiz bir mucizedir!",
        "type": "scientific_outro"
    }
]

def get_duration(file_path):
    cmd = [
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration", "-of", "default=noprint_wrappers=1:nokey=1",
        file_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return float(res.stdout.strip())

print("--- 1. Generating Studio Neural Voice via Edge-TTS (tr-TR-EmelNeural) ---")
processed_clips = []

for idx, scene in enumerate(SCENES):
    raw_path = os.path.join(PUBLIC_DIR, f"{scene['id']}_neural.mp3")
    proc_path = os.path.join(PUBLIC_DIR, f"{scene['id']}_master.mp3")
    
    print(f"[{idx+1}/{len(SCENES)}] Synthesizing {scene['id']} with Neural Turkish Voice...")
    cmd_tts = [
        "python", "-m", "edge_tts",
        "--voice", "tr-TR-EmelNeural",
        "--rate=+4%",
        "--pitch=-15Hz",
        "--text", scene["script"],
        "--write-media", raw_path
    ]
    subprocess.run(cmd_tts, check=True)
    
    # Broadcast mastering filter: Warm low-end, crisp vocal presence, and optical broadcast compression
    cmd_ffmpeg = [
        "ffmpeg", "-y", "-i", raw_path,
        "-filter:a", "equalizer=f=110:t=q:w=1:g=2.5,equalizer=f=3400:t=q:w=1.2:g=3.0,acompressor=threshold=-18dB:ratio=3.5:attack=5:release=60,volume=1.2",
        "-ar", "44100", "-b:a", "192k",
        proc_path
    ]
    subprocess.run(cmd_ffmpeg, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    processed_clips.append(proc_path)

print("--- 2. Calculating Exact Timeline & Word Offsets ---")
current_frame = 0
scene_metadata = []

for idx, scene in enumerate(SCENES):
    clip_path = processed_clips[idx]
    dur = get_duration(clip_path)
    # Extra 0.5s pause for cinematic breathing room
    scene_frames = int(math.ceil((dur + 0.5) * FPS))
    
    words = scene["script"].split()
    total_chars = sum(len(w) for w in words)
    speech_frames = int(dur * FPS)
    
    word_timings = []
    w_start = 0
    for w in words:
        w_dur = max(6, int((len(w) / total_chars) * speech_frames))
        w_end = min(speech_frames, w_start + w_dur)
        word_timings.append({
            "text": w,
            "startFrame": current_frame + w_start,
            "endFrame": current_frame + w_end
        })
        w_start = w_end
        
    scene_data = {
        **scene,
        "startFrame": current_frame,
        "endFrame": current_frame + scene_frames,
        "durationInFrames": scene_frames,
        "audioDurationSec": dur,
        "words": word_timings
    }
    scene_metadata.append(scene_data)
    current_frame += scene_frames

total_frames = current_frame
total_sec = total_frames / FPS
print(f"Total Video Duration: {total_sec:.2f} seconds ({total_frames} frames @ {FPS} FPS)")

# Concat voice track with 500ms pads
voice_concat_txt = os.path.join(PUBLIC_DIR, "concat_list.txt")
pad_path = os.path.join(PUBLIC_DIR, "pad_500ms.mp3")
subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-t", "0.5", "-q:a", "9", "-acodec", "libmp3lame", pad_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

with open(voice_concat_txt, "w", encoding="utf-8") as f:
    for idx, sc in enumerate(scene_metadata):
        f.write(f"file '{sc['id']}_master.mp3'\n")
        f.write("file 'pad_500ms.mp3'\n")

master_voice_path = os.path.join(PUBLIC_DIR, "voice_track_neural.mp3")
subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", voice_concat_txt, "-c", "copy", master_voice_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("--- 3. Multi-Track Cinematic Sound Design & SFX Mixing ---")
# Build complex audio graph using actual SFX files:
# Inputs:
# 0: master voice
# 1: sfx/drone.wav (looped)
# 2: sfx/pulse.wav (looped)
# 3: sfx/braam.wav (placed at scene 1 and scene 4)
# 4: sfx/boom.wav (placed at scene 2 and scene 5)
# 5: sfx/swoosh.wav (placed at scene transitions)
# 6: sfx/alarm.wav (placed during scene 2 and 5)

drone_path = os.path.join(SFX_DIR, "drone.wav")
pulse_path = os.path.join(SFX_DIR, "pulse.wav")
braam_path = os.path.join(SFX_DIR, "braam.wav")
boom_path = os.path.join(SFX_DIR, "boom.wav")
swoosh_path = os.path.join(SFX_DIR, "swoosh.wav")
alarm_path = os.path.join(SFX_DIR, "alarm.wav")

# Delay times in ms for SFX
t_sc1 = int((scene_metadata[0]["startFrame"] / FPS) * 1000)
t_sc2 = int((scene_metadata[1]["startFrame"] / FPS) * 1000)
t_sc3 = int((scene_metadata[2]["startFrame"] / FPS) * 1000)
t_sc4 = int((scene_metadata[3]["startFrame"] / FPS) * 1000)
t_sc5 = int((scene_metadata[4]["startFrame"] / FPS) * 1000)
t_sc6 = int((scene_metadata[5]["startFrame"] / FPS) * 1000)

filter_complex = f"""
[1:a]aloop=loop=-1:size=2e+09,volume=0.30[bg_drone];
[2:a]aloop=loop=-1:size=2e+09,volume=0.22[bg_pulse];
[3:a]adelay={t_sc1}|{t_sc1},volume=0.45[braam1];
[3:a]adelay={t_sc4}|{t_sc4},volume=0.40[braam2];
[4:a]adelay={t_sc2}|{t_sc2},volume=0.45[boom1];
[4:a]adelay={t_sc5}|{t_sc5},volume=0.45[boom2];
[5:a]adelay={t_sc3}|{t_sc3},volume=0.35[swoosh1];
[5:a]adelay={t_sc6}|{t_sc6},volume=0.35[swoosh2];
[6:a]adelay={t_sc2 + 800}|{t_sc2 + 800},volume=0.25[alarm1];
[6:a]adelay={t_sc5 + 800}|{t_sc5 + 800},volume=0.25[alarm2];
[0:a]volume=1.4[vox];
[bg_drone][bg_pulse][braam1][braam2][boom1][boom2][swoosh1][swoosh2][alarm1][alarm2]amix=inputs=10:dropout_transition=2[sfx_bed];
[vox][sfx_bed]amix=inputs=2:duration=first:dropout_transition=2[out]
"""

final_soundtrack_mp3 = os.path.join(PUBLIC_DIR, "iki_gunes_master_soundtrack.mp3")

mix_cmd = [
    "ffmpeg", "-y",
    "-i", master_voice_path,
    "-i", drone_path,
    "-i", pulse_path,
    "-i", braam_path,
    "-i", boom_path,
    "-i", swoosh_path,
    "-i", alarm_path,
    "-filter_complex", filter_complex,
    "-map", "[out]",
    "-t", str(total_sec),
    "-b:a", "256k",
    final_soundtrack_mp3
]

subprocess.run(mix_cmd, check=True)

# Save master JSON
json_output_path = os.path.join(PUBLIC_DIR, "master_iki_gunes_scenes.json")
with open(json_output_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "durationSec": total_sec,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)

src_json_path = os.path.join(WORK_DIR, "src", "master_iki_gunes_scenes.json")
with open(src_json_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "durationSec": total_sec,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)

print("--- Complete! Master audio with studio neural voice and multi-track SFX ready! ---")
print(f"Output MP3: {final_soundtrack_mp3}")
print(f"Output JSON: {json_output_path}")
