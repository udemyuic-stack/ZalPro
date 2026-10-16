@echo off
chcp 65001 >nul
rem Diamond — do'kondagi hamma tovar narxiga ustama foiz qo'shadi. Bosh admin uchun.
cd /d "%~dp0"
set "PATH=%LOCALAPPDATA%\node;%APPDATA%\npm;%PATH%"
set /p FOIZ=Ustama foizi (masalan 20):
node tools\dokon\narx_ustama.mjs %FOIZ%
pause
