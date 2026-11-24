# -*- coding: utf-8 -*-
import urllib.request, json

key = 'sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064'
voices = [
    ('IKne3meq5aSn9XLyUdCD', 'Charlie'),
    ('TX3LPaxmHKxFdv7VOQHJ', 'Liam'),
    ('onwK4e9ZLuTAKqWW03F9', 'Daniel'),
    ('pNInz6obpgDQGcFmaJgB', 'Adam')
]

for vid, name in voices:
    url = f'https://api.elevenlabs.io/v1/text-to-speech/{vid}'
    payload = {
        'text': 'Şebeke yok, internet yok! Peki şimdi? ROTA+ çalışmaya devam eder.',
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
            'stability': 0.38,
            'similarity_boost': 0.85,
            'style': 0.25,
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
            print(f'Voice {name} success! Size: {len(audio)}')
            with open(f'C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/test_{name}.mp3', 'wb') as f:
                f.write(audio)
    except Exception as e:
        print(f'Voice {name} failed: {e}')