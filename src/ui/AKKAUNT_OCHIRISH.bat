@echo off
chcp 65001 >nul
rem Diamond — shogird akkauntini to'liq o'chirish (ma'lumotlar + kirish). Bosh admin uchun.
cd /d "%~dp0"
set "PATH=%LOCALAPPDATA%\node;%APPDATA%\npm;%PATH%"
if not exist "tools\parol_tiklash\node_modules" (
  pushd tools\parol_tiklash && call npm install --no-audit --no-fund >nul && popd
)
set /p PHONE=O'chiriladigan telefon raqam (masalan 901234567):
set /p SURE=Rostdan ham +998%PHONE% ni butunlay o'chirasizmi? (ha/yo'q):
if /i not "%SURE%"=="ha" (
  echo Bekor qilindi.
  pause
  exit /b
)
node tools\parol_tiklash\ochirish.mjs %PHONE%
pause
