# -*- coding: utf-8 -*-
import urllib.request, json

key = 'sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064'
text = 'Kokpit ekranında hava durumu, barometre, irtifa ve pusula tek bakışta elinizin altında.'

for vid, name in [('IKne3meq5aSn9XLyUdCD', 'Charlie'), ('pNInz6obpgDQGcFmaJgB', 'Adam')]:
    url = f'https://api.elevenlabs.io/v1/text-to-speech/{vid}'
    payload = {
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
            'stability': 0.42,
            'similarity_boost': 0.85,
            'style': 0.30,
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
            print(f'{name} size:', len(audio))
            with open(f'C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/test_{name}_s01.mp3', 'wb') as f:
                f.write(audio)
    except Exception as e:
        print(f'{name} failed:', e)