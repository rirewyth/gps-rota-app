@echo off
title ROTA+ ADMIN Panel
cd /d "%~dp0"
if not exist node_modules call npm install
start "" "http://localhost:5176"
npm run dev
