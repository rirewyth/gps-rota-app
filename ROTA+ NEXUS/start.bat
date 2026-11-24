@echo off
title ROTA+ NEXUS Komuta Merkezi
echo ========================================================
echo       ROTA+ NEXUS - AFET & OPERASYON KOMUTA MERKEZI     
echo ========================================================
echo.
echo Push Relay baslatiliyor (Port 5175)...
start /b node push-server.mjs
echo Sunucu baslatiliyor (Port 5174)...
echo Tarayici aciliyor: http://localhost:5174/
echo.
start http://localhost:5174/
npm run dev
pause
