# -*- coding: utf-8 -*-
import urllib.request, json

key = 'sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064'
url = 'https://api.elevenlabs.io/v1/text-to-speech/uxXY4QvpsdWFe6Yigtlq'
payload = {
    'text': 'Şebeke yok, internet yok. Peki şimdi? ROTA+ çalışmaya devam eder.',
    'model_id': 'eleven_multilingual_v2',
    'voice_settings': {
        'stability': 0.45,
        'similarity_boost': 0.85
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
        print('Success! Audio size:', len(audio))
        with open('C:/Users/rirew/Downloads/gps-rota-app-repo/remotion-app/test_mustafa.mp3', 'wb') as f:
            f.write(audio)
except urllib.error.HTTPError as e:
    print('HTTPError:', e.code, e.read().decode())
except Exception as e:
    print('Error:', e)