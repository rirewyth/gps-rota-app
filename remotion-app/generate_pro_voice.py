# -*- coding: utf-8 -*-
import os, json, urllib.request, subprocess

API_KEY = "sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064"
VOICE_ID = "IKne3meq5aSn9XLyUdCD" # Charlie
OUT_DIR = "C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/public/rotaplus/pro_voice"
os.makedirs(OUT_DIR, exist_ok=True)

PRO_SCRIPTS = {
    "pro_hook": "Şebeke sıfır! Telefonun çekmiyor, internet tamamen kesik! Peki şimdi ne yapacaksın? Panik yok, çünkü ROTA PLUS yanında!",
    "pro_mesh": "Hiçbir baz istasyonuna ihtiyaç duymadan, Doğa Mesh Ağıyla telefonlar arasında doğrudan bağlantı kur! Ekibinle internetsiz kesintisiz haberleş!",
    "pro_deprem": "Büyük bir afette sesin kısılsa bile, ROTA PLUS akustik ses tanıma ve B L E radarıyla enkaz altından sinyal yayar, yerini kurtarma ekiplerine anında bildirir!",
    "pro_gps": "Doğrudan uydu bağlantısıyla, internet olmadan izohipsli sahra haritasında rotanı çiz! Anlık koordinatını ve irtifanı asla kaybetme!",
    "pro_autosos": "Yalnızken düştün veya bayıldın mı? Hareketsizlik sensörü hareketsiz kaldığın an otomatik sireni patlatır ve ekibine acil durum çağrısı fırlatır!",
    "pro_ilkyardim": "Turnike, kanama ve teknik dağcılık düğümleri! Hayat kurtaran tüm kritik ilk yardım adımları internetsiz cebinde hazır!",
    "pro_outro": "Acil durum kapını çalmadan önce telefonunda mutlaka olmalı! ROTA PLUS'ı Google Play ve App Store'dan hemen indir!"
}

durations = {}

for key, text in PRO_SCRIPTS.items():
    mp3_path = os.path.join(OUT_DIR, f"{key}.mp3")
    wav_path = os.path.join(OUT_DIR, f"{key}.wav")
    
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    # High energy, dynamic emphasis, passionate delivery
    payload = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.28,
            "similarity_boost": 0.82,
            "style": 0.55,
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
        
        res = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", wav_path], stdout=subprocess.PIPE, text=True)
        dur = float(res.stdout.strip())
        durations[key] = dur
        print(f"[{key}] generated: {dur:.2f}s ({len(audio_bytes)} bytes)")
    except Exception as e:
        print(f"[{key}] failed: {e}")

print("\n--- Pro Voice Durations ---")
print(json.dumps(durations, indent=2))

with open("C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/pro_voice_durations.json", "w", encoding="utf-8") as f:
    json.dump(durations, f, indent=2)
