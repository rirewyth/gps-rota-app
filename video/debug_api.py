import requests
import json

invoke_url = "https://integrate.api.nvidia.com/v1/chat/completions"

# OLD KEY
KEY = "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"
# NEW KEY
# KEY = "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"

headers = {
    "Authorization": f"Bearer {KEY}",
    "Accept": "application/json",
}

payload = {
  "messages": [
    {
      "role": "user",
      "content": "Hello, this is a test."
    }
  ],
  "model": "moonshotai/kimi-k3",
  "max_tokens": 100,
  "temperature": 0.7
}

response = requests.post(invoke_url, headers=headers, json=payload)
print(response.status_code)
print(response.text)
