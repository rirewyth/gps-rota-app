# -*- coding: utf-8 -*-
import os, json, urllib.request, subprocess

API_KEY = "sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064"
VOICE_ID = "IKne3meq5aSn9XLyUdCD" # Charlie
OUT_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/public/rotaplus/ad_voice"
os.makedirs(OUT_DIR, exist_ok=True)

AD_SCRIPTS = {
    "ad_hook": "Büyük bir depremde veya doğada şebeke tamamen çöktüğünde... Ne yapacaksın? ROTA PLUS, internetsiz çalışmaya devam eder.",
    "ad_deprem": "Enkaz altında sesin kısılsa bile, ROTA PLUS akustik ses tanıma ve B L E radarıyla yerini kurtarma ekiplerine bildirir. Tek tuşla ailene Güvendeyim mesajı atar.",
    "ad_gps": "İnternet veya baz istasyonu olmadan, doğrudan uydulardan anlık koordinatını al, izohipsli sahra haritasında rotanı çiz.",
    "ad_autosos": "Yalnızken düştün veya bayıldın mı? Hareketsizlik sensörü devreye girer, yüksek sesli siren çalar ve ekibine anlık acil durum çağrısı gönderir.",
    "ad_ilkyardim": "Kanamalardan turnikeye, kırıklardan dağcılık düğümlerine kadar hayat kurtaran tüm kritik ilk yardım adımları internetsiz elinin altında.",
    "ad_outro": "Acil durum kapını çaldığında indirmek için çok geç olacak. ROTA PLUS'ı hemen indir, daima hazırlıklı ol."
}

durations = {}

for key, text in AD_SCRIPTS.items():
    mp3_path = os.path.join(OUT_DIR, f"{key}.mp3")
    wav_path = os.path.join(OUT_DIR, f"{key}.wav")
    
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    payload = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.36,
            "similarity_boost": 0.85,
            "style": 0.40,
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

print("\n--- Ad Voice Durations ---")
print(json.dumps(durations, indent=2))

with open("C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/ad_voice_durations.json", "w", encoding="utf-8") as f:
    json.dump(durations, f, indent=2)
