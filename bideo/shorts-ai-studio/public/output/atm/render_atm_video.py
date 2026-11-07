import os
import subprocess
import json

atm_dir = r"c:\Users\rirew\Downloads\gps-rota-app-repo\bideo\shorts-ai-studio\public\output\atm"
os.chdir(atm_dir)

scenes = [
    {
        "index": 1,
        "title": "ADIM 1: KART VE ÇİP OKUMA",
        "subtitle": "Kartınızı taktığınızda mikroçipteki\\nşifreli veriler anında taranır.",
        "img": "scene_1.jpg",
        "audio": "scene_1.mp3"
    },
    {
        "index": 2,
        "title": "ADIM 2: PIN ŞİFRELEME (HSM)",
        "subtitle": "Girdiğiniz 4 haneli PIN şifresi\\ndonanımsal modülle şifrelenir.",
        "img": "scene_2.jpg",
        "audio": "scene_2.mp3"
    },
    {
        "index": 3,
        "title": "ADIM 3: BANKA MERKEZİ ONAYI",
        "subtitle": "ATM, güvenli ağdan bankaya bağlanıp\\nbakiyenizi ve limitinizi doğrular.",
        "img": "scene_3.jpg",
        "audio": "scene_3.mp3"
    },
    {
        "index": 4,
        "title": "ADIM 4: ZIRHLI KASA VE KASETLER",
        "subtitle": "Zırhlı kasadaki para kasetleri devreye girer,\\nbanknotlar tek tek çekilir.",
        "img": "scene_4.jpg",
        "audio": "scene_4.mp3"
    },
    {
        "index": 5,
        "title": "ADIM 5: OPTİK & SAHTE PARA KONTROLÜ",
        "subtitle": "Optik ve manyetik sensörler sahte\\nve yapışık paraları anında ayırır.",
        "img": "scene_5.jpg",
        "audio": "scene_5.mp3"
    },
    {
        "index": 6,
        "title": "ADIM 6: TESLİMAT & 30 SANİYE KURALI",
        "subtitle": "Paranız sunulur! 30 saniyede almazsanız\\ngüvenlik için kasaya geri çeker!",
        "img": "scene_6.jpg",
        "audio": "scene_6.mp3"
    }
]

def format_ass_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    cs = int((seconds - int(seconds)) * 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"

# 1. Get audio durations
durations = []
for sc in scenes:
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", sc["audio"]]
    res = subprocess.run(cmd, capture_output=True, text=True)
    dur = float(json.loads(res.stdout)["format"]["duration"])
    # Add 0.3s padding so speech has a natural breath
    pad_dur = dur + 0.3
    durations.append(pad_dur)
    sc["dur"] = pad_dur
    print(f"Scene {sc['index']}: {pad_dur:.2f}s")

# 2. Render each clip with zoompan
clip_files = []
for sc in scenes:
    dur = sc["dur"]
    frames = int(dur * 25)
    clip_name = f"clip_{sc['index']}.mp4"
    clip_files.append(clip_name)
    
    # Alternate zoom directions for cinematic feel:
    # Odd scenes: zoom in slowly
    # Even scenes: slight zoom out
    if sc['index'] % 2 == 1:
        zp = f"zoompan=z='min(zoom+0.0006,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s=1080x1920:fps=25"
    else:
        zp = f"zoompan=z='if(lte(zoom,1.0),1.06,max(1.001,zoom-0.0006))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s=1080x1920:fps=25"
        
    cmd = [
        "ffmpeg", "-y", "-loop", "1", "-i", sc["img"],
        "-t", str(dur),
        "-vf", f"scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,{zp}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", clip_name
    ]
    print(f"Rendering {clip_name}...")
    subprocess.run(cmd, check=True)

# 3. Concatenate video clips
with open("clips.txt", "w") as f:
    for c in clip_files:
        f.write(f"file '{c}'\n")

cmd_cat_video = [
    "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", "clips.txt",
    "-c", "copy", "visuals_master.mp4"
]
print("Concatenating video clips...")
subprocess.run(cmd_cat_video, check=True)

# 4. Concatenate audio clips with pad
with open("audios.txt", "w") as f:
    for sc in scenes:
        f.write(f"file '{sc['audio']}'\n")

cmd_cat_audio = [
    "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", "audios.txt",
    "-c:a", "libmp3lame", "audio_master.mp3"
]
print("Concatenating audio clips...")
subprocess.run(cmd_cat_audio, check=True)

# 5. Build ASS Subtitle file
total_time = sum(durations)
ass_header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: MainHeader, Arial, 42, &H0000FFFF, &H00000000, &H00000000, &HD00A0A0A, 1, 0, 0, 0, 100, 100, 1, 0, 3, 3, 0, 8, 40, 40, 150, 1
Style: StepBadge, Arial, 38, &H00FFFFFF, &H00000000, &H00202020, &HD0202060, 1, 0, 0, 0, 100, 100, 1, 0, 3, 3, 0, 8, 50, 50, 230, 1
Style: Subtitle, Arial, 52, &H00FFFFFF, &H00000000, &H00000000, &HE00A0A0A, 1, 0, 0, 0, 100, 100, 1, 0, 3, 4, 0, 2, 70, 70, 260, 1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

events = []
current_time = 0.0

# Permanent Main Header across entire video
events.append(f"Dialogue: 0,0:00:00.00,{format_ass_time(total_time)},MainHeader,,0,0,0,,💳 BANKAMATİK NASIL ÇALIŞIR?")

for sc in scenes:
    start_t = current_time
    end_t = current_time + sc["dur"]
    current_time = end_t
    
    start_str = format_ass_time(start_t)
    end_str = format_ass_time(end_t)
    
    events.append(f"Dialogue: 0,{start_str},{end_str},StepBadge,,0,0,0,,{sc['title']}")
    events.append(f"Dialogue: 0,{start_str},{end_str},Subtitle,,0,0,0,,{sc['subtitle']}")

with open("subtitles_master.ass", "w", encoding="utf-8") as f:
    f.write(ass_header + "\n".join(events) + "\n")

print("Created subtitles_master.ass")

# 6. Burn subtitles, combine audio and video, add subtle ambient background
output_final = "bankamatik-nasil-calisir.mp4"

# Generate subtle ambient synth bed (-26dB) and mix with speech
cmd_final = [
    "ffmpeg", "-y",
    "-i", "visuals_master.mp4",
    "-i", "audio_master.mp3",
    "-f", "lavfi", "-t", str(total_time), "-i", "anoisesrc=c=pink:r=44100:a=0.003",
    "-filter_complex", 
    "[1:a][2:a]amix=inputs=2:duration=first:dropout_transition=2[aout];"
    "[0:v]subtitles=subtitles_master.ass[vout]",
    "-map", "[vout]",
    "-map", "[aout]",
    "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "192k",
    output_final
]

print("Rendering master video with subtitles and sound mixing...")
subprocess.run(cmd_final, check=True)
print(f"Master video rendered: {output_final}")
