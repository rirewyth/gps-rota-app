import requests

invoke_url = "https://integrate.api.nvidia.com/v1/chat/completions"
stream = False

headers = {
    "Authorization": "Bearer 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",
    "Accept": "application/json",
}

payload = {
  "messages": [
    {
      "role": "user",
      "content": "What is in this image?"
    }
  ],
  "model": "moonshotai/kimi-k3",
  "max_tokens": 100,
  "seed": 0,
  "stream": stream,
  "temperature": 1
}

response = requests.post(invoke_url, headers=headers, json=payload, stream=stream)
print(response.status_code)
print(response.text)
