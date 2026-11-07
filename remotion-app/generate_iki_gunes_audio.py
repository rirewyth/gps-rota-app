import os
import json
import math
import subprocess
import numpy as np
from scipy.io import wavfile
from gtts import gTTS

FPS = 30
WORK_DIR = r"C:\Users\rirew\Downloads\gps-rota-app-repo\remotion-app"
PUBLIC_DIR = os.path.join(WORK_DIR, "public", "iki_gunes")
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

print("--- 1. Generating Voiceover Clips via gTTS ---")
raw_clips = []
processed_clips = []

for idx, scene in enumerate(SCENES):
    raw_path = os.path.join(PUBLIC_DIR, f"{scene['id']}_raw.mp3")
    proc_path = os.path.join(PUBLIC_DIR, f"{scene['id']}.mp3")
    
    print(f"[{idx+1}/{len(SCENES)}] Synthesizing {scene['id']}...")
    tts = gTTS(scene["script"], lang="tr", slow=False)
    tts.save(raw_path)
    
    # Process audio: slight speedup (atempo=1.06) + crisp vocal EQ + gentle compressor
    cmd = [
        "ffmpeg", "-y", "-i", raw_path,
        "-filter:a", "atempo=1.06,equalizer=f=120:t=q:w=1:g=2,equalizer=f=3200:t=q:w=1:g=2.5,acompressor=threshold=-16dB:ratio=3:attack=5:release=50",
        "-ar", "44100", "-b:a", "192k",
        proc_path
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    processed_clips.append(proc_path)

print("--- 2. Calculating Timings & Word Alignments ---")
current_frame = 0
scene_metadata = []

for idx, scene in enumerate(SCENES):
    clip_path = processed_clips[idx]
    dur = get_duration(clip_path)
    # Extra 0.5s pause between scenes for visual breathing room
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

# Concat voice track
voice_concat_txt = os.path.join(PUBLIC_DIR, "concat_list.txt")
with open(voice_concat_txt, "w", encoding="utf-8") as f:
    for idx, sc in enumerate(scene_metadata):
        f.write(f"file '{sc['id']}.mp3'\n")
        # Add 0.5s pad
        pad_path = os.path.join(PUBLIC_DIR, "pad_500ms.mp3")
        subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-t", "0.5", "-q:a", "9", "-acodec", "libmp3lame", pad_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        f.write("file 'pad_500ms.mp3'\n")

master_voice_path = os.path.join(PUBLIC_DIR, "voice_track_master.mp3")
subprocess.run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", voice_concat_txt, "-c", "copy", master_voice_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

print("--- 3. Synthesizing High-Tech Sci-Fi Soundtrack & SFX ---")
sr = 44100
dur_samples = int(total_sec * sr)
t = np.linspace(0, total_sec, dur_samples, endpoint=False)

# Deep space sub-bass drone (55 Hz fundamental + 110 Hz harmonic with slow 0.2Hz LFO filter sweep)
lfo = 0.5 * (1.0 + np.sin(2 * np.pi * 0.2 * t))
bass = 0.25 * np.sin(2 * np.pi * 55 * t) + 0.15 * lfo * np.sin(2 * np.pi * 110 * t)

# Subtle pulsing synth pad chords (D minor: D3=146.8, F3=174.6, A3=220.0 with 2Hz tremolo)
tremolo = 0.7 + 0.3 * np.sin(2 * np.pi * 2.0 * t)
pad = 0.08 * tremolo * (np.sin(2 * np.pi * 146.83 * t) + np.sin(2 * np.pi * 174.61 * t) + np.sin(2 * np.pi * 220.00 * t))

# Cybernetic beat pulse every 0.5 seconds (120 BPM subtle heartbeat thump)
pulse = np.zeros(dur_samples)
pulse_interval = int(0.5 * sr)
for p in range(0, dur_samples, pulse_interval):
    k_len = int(0.12 * sr)
    if p + k_len < dur_samples:
        kt = np.linspace(0, 0.12, k_len, endpoint=False)
        k_env = np.exp(-kt * 35)
        pulse[p:p+k_len] += 0.22 * k_env * np.sin(2 * np.pi * (65 - 30 * (kt / 0.12)) * kt)

# Add impact whooshes at scene transitions
for sc in scene_metadata:
    sf = sc["startFrame"]
    sample_idx = int((sf / FPS) * sr)
    w_len = int(0.8 * sr)
    if sample_idx + w_len < dur_samples:
        wt = np.linspace(0, 0.8, w_len, endpoint=False)
        w_env = np.sin(np.pi * (wt / 0.8)) ** 2
        # White noise burst filtered
        noise = np.random.uniform(-1, 1, w_len)
        pulse[sample_idx:sample_idx+w_len] += 0.18 * w_env * noise

soundtrack = bass + pad + pulse
# Normalize
soundtrack = soundtrack / (np.max(np.abs(soundtrack)) + 1e-6) * 0.45

soundtrack_wav = os.path.join(PUBLIC_DIR, "synth_drone.wav")
wavfile.write(soundtrack_wav, sr, (soundtrack * 32767).astype(np.int16))

# Final mix: Voice track + Background soundtrack with sidechain ducking
final_soundtrack_mp3 = os.path.join(PUBLIC_DIR, "iki_gunes_master_soundtrack.mp3")
mix_cmd = [
    "ffmpeg", "-y",
    "-i", master_voice_path,
    "-i", soundtrack_wav,
    "-filter_complex",
    "[1:a]volume=0.35[bg];[0:a]volume=1.3[vox];[vox][bg]amix=inputs=2:duration=first:dropout_transition=2[out]",
    "-map", "[out]",
    "-b:a", "256k",
    final_soundtrack_mp3
]
subprocess.run(mix_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Save master JSON metadata
json_output_path = os.path.join(PUBLIC_DIR, "master_iki_gunes_scenes.json")
with open(json_output_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "durationSec": total_sec,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)

# Copy json also to src for clean import
src_json_path = os.path.join(WORK_DIR, "src", "master_iki_gunes_scenes.json")
with open(src_json_path, "w", encoding="utf-8") as f:
    json.dump({
        "totalFrames": total_frames,
        "fps": FPS,
        "durationSec": total_sec,
        "scenes": scene_metadata
    }, f, ensure_ascii=False, indent=2)

print("--- Complete! Master audio and metadata generated successfully! ---")
print(f"Output MP3: {final_soundtrack_mp3}")
print(f"Output JSON: {json_output_path}")
