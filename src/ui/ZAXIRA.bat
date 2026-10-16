@echo off
chcp 65001 >nul
rem Diamond — bazaning to'liq zaxirasini zaxira/ papkasiga yozadi (haftada 1 marta ishga tushiring).
cd /d "%~dp0"
set "PATH=%LOCALAPPDATA%\node;%APPDATA%\npm;%PATH%"
node tools\zaxira\zaxira.mjs
pause
