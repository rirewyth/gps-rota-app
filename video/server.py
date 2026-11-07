from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json
import re

app = Flask(__name__)
CORS(app)

NVIDIA_API_KEY = "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"

@app.route('/api/director', methods=['POST'])
def ai_director():
    data = request.json
    idea = data.get('idea', '')
    style = data.get('style', 'Realistic')
    
    if not idea:
        return jsonify({"error": "No idea provided"}), 400

    invoke_url = "https://integrate.api.nvidia.com/v1/chat/completions"
    
    headers = {
        "Authorization": f"Bearer {NVIDIA_API_KEY}",
        "Accept": "application/json",
    }
    
    system_prompt = f"""You are the AI Creative Director for a Video Generation Studio.
The user wants a video with the following idea: '{idea}'
Style requested: {style}

Your task is to analyze this idea and return a JSON object with the following parameters. DO NOT return any markdown formatting or extra text, just raw JSON.
{{
  "mode": "...",
  "duration": "10 sec",
  "camera": "...",
  "lighting": "...",
  "prompt": "An English detailed prompt for an image/video generation AI describing the scene, lighting, camera, and style. Keep it under 500 characters."
}}
"""
    
    payload = {
      "messages": [
        {
          "role": "user",
          "content": system_prompt
        }
      ],
      "model": "moonshotai/kimi-k3",
      "max_tokens": 512,
      "seed": 0,
      "temperature": 0.7,
      "stream": False
    }

    try:
        response = requests.post(invoke_url, headers=headers, json=payload)
        response.raise_for_status()
        result = response.json()
        
        content = result['choices'][0]['message']['content']
        
        # Clean markdown code blocks if any
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].strip()
            
        director_data = json.loads(content)
        
        # Generate an image url using pollinations AI based on the prompt
        prompt = director_data.get('prompt', 'Cinematic view')
        safe_prompt = requests.utils.quote(prompt)
        image_url = f"https://image.pollinations.ai/prompt/{safe_prompt}?width=1280&height=720&nologo=true"
        director_data['image_url'] = image_url
        
        return jsonify(director_data)
        
    except Exception as e:
        print("Error:", e)
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(port=5000, debug=True)
