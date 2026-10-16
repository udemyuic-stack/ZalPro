@echo off
chcp 65001 >nul
rem Diamond — parolni unutgan foydalanuvchiga yangi parol o'rnatish (bosh admin uchun)
cd /d "%~dp0"
set "PATH=%LOCALAPPDATA%\node;%APPDATA%\npm;%PATH%"
if not exist "tools\parol_tiklash\node_modules" (
  echo Birinchi marta: kutubxona o'rnatilmoqda...
  pushd tools\parol_tiklash && call npm install --no-audit --no-fund >nul && popd
)
set /p PHONE=Telefon raqam (masalan 901234567):
set /p PASS=Yangi vaqtinchalik parol (kamida 6 belgi):
node tools\parol_tiklash\tiklash.mjs %PHONE% %PASS%
pause
