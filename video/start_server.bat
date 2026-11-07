@echo off
echo Starting VIDEO AI STUDIO Frontend Server...
start "" "http://127.0.0.1:8000"
start /B python -m http.server 8000
echo Starting AI Backend...
python server.py
pause
