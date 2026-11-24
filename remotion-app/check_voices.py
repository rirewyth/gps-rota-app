import urllib.request, json

key = 'sk_d472e010ba320f5a7e3f0c770529a77e59050a32acf6d064'
req = urllib.request.Request('https://api.elevenlabs.io/v1/voices', headers={'xi-api-key': key})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        print('Total voices:', len(data['voices']))
        for v in data['voices']:
            print(f"{v['voice_id']}: {v['name']} ({v.get('category')})")
except Exception as e:
    print('Error:', e)
