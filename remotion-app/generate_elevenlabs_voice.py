# -*- coding: utf-8 -*-
import os, json, urllib.request, subprocess

API_KEY = "sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064"
VOICE_ID = "IKne3meq5aSn9XLyUdCD" # Charlie (Energetic, Confident, Dynamic)
OUT_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/public/rotaplus/voice"
os.makedirs(OUT_DIR, exist_ok=True)

SCRIPTS = {
    "hook": "Şebeke sıfır, internet tamamen yok! Peki şimdi ne yapacaksın? ROTA PLUS, çalışmaya kesintisiz devam eder!",
    "s01": "Birincisi, Kokpit ekranı! Barometre, anlık irtifa, hava durumu ve pusula sensörleri, tek ekranda elinizin altında.",
    "s02": "İkincisi, Gerçek Zamanlı GPS Takibi! Adım adım katettiğiniz mesafeyi ve irtifayı haritaya işler, rotanızı asla kaybetmezsiniz.",
    "s03": "Üçüncüsü, Auto-SOS! Hareketsizlik sensörü, bayılma veya kaza anında devreye girer, acil durumu otomatik başlatır.",
    "s04": "Dördüncüsü, Topografik Rota Planlama! İnternet olmadan izohipsli sahra haritasında yeni rotalar çizin ve ara noktalar ekleyin.",
    "s05": "Beşincisi, Ekip Güvenlik Ağı! Sahadaki tüm ekip üyelerinin durumunu ve anlık yardım çağrılarını koordinatlarıyla görün.",
    "s06": "Altıncısı, Deprem ve Enkaz Modu! Tek dokunuşla Güvendeyim mesajı atın, hayatta kalma sayacı ve ses arama dedektörünü başlatın.",
    "s07": "Yedincisi, Çevrimdışı İlk Yardım! Turnike, kırık ve hipotermi gibi kritik durumlarda adım adım rehberlik sağlar.",
    "s08": "Sekizincisi, Dağcılık ve Düğümler Rehberi! Alpin kelebekten tam kazığa kadar hayati düğüm tekniklerini çevrimdışı öğrenin.",
    "s09": "Dokuzuncusu, Askeri Standartta Güvenlik! L-Band uydu uyumu ve minimum pil tüketimiyle en zorlu şartlarda yanınızda.",
    "outro": "Zorlu koşullarda hayatta kalmak için, ROTA PLUS! Google Play ve App Store'dan hemen indirin."
}

durations = {}

for key, text in SCRIPTS.items():
    mp3_path = os.path.join(OUT_DIR, f"{key}.mp3")
    wav_path = os.path.join(OUT_DIR, f"{key}.wav")
    
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    payload = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.38,
            "similarity_boost": 0.85,
            "style": 0.35,
            "use_speaker_boost": True
        }
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={
        "xi-api-key": API_KEY,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg"
    })
    
    try:
        with urllib.request.urlopen(req) as resp:
            audio_bytes = resp.read()
            with open(mp3_path, "wb") as f:
                f.write(audio_bytes)
        
        # Convert to 48kHz WAV
        subprocess.run(["ffmpeg", "-y", "-i", mp3_path, "-ar", "48000", "-ac", "2", wav_path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Get duration
        res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", wav_path], stdout=subprocess.PIPE, text=True)
        dur = float(res.stdout.strip())
        durations[key] = dur
        print(f"[{key}] generated: {dur:.2f}s ({len(audio_bytes)} bytes)")
    except Exception as e:
        print(f"[{key}] failed: {e}")

print("\n--- Summary of Durations ---")
print(json.dumps(durations, indent=2))

with open("C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/voice_durations.json", "w", encoding="utf-8") as f:
    json.dump(durations, f, indent=2)
