@echo off
title ROTA+ NEXUS Komuta Merkezi
echo ========================================================
echo       ROTA+ NEXUS - AFET & OPERASYON KOMUTA MERKEZI     
echo ========================================================
echo.
echo Sunucu baslatiliyor (Port 5174)...
echo Tarayici aciliyor: http://localhost:5174/
echo.
start http://localhost:5174/
npm run dev
pause
