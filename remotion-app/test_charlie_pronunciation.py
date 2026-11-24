# -*- coding: utf-8 -*-
import urllib.request, json

key = 'sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064'
url = 'https://api.elevenlabs.io/v1/text-to-speech/IKne3meq5aSn9XLyUdCD'
payload = {
    'text': 'Şebeke sıfır, internet tamamen yok! Peki şimdi ne yapacaksın? Rota Plus, çalışmaya kesintisiz devam eder.',
    'model_id': 'eleven_multilingual_v2',
    'voice_settings': {
        'stability': 0.40,
        'similarity_boost': 0.85,
        'style': 0.35,
        'use_speaker_boost': True
    }
}
data = json.dumps(payload).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={
    'xi-api-key': key,
    'Content-Type': 'application/json',
    'Accept': 'audio/mpeg'
})
try:
    with urllib.request.urlopen(req) as resp:
        audio = resp.read()
        print('Charlie generated! Size:', len(audio))
        with open('C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/test_charlie_hook.mp3', 'wb') as f:
            f.write(audio)
except Exception as e:
    print('Failed:', e)