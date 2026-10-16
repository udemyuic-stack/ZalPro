@echo off
chcp 65001 >nul
rem Diamond — push bildirishnomalar serverini (Cloud Functions) joylash.
rem OLDIN: Firebase Console -> Loyiha -> Usage and billing -> "Upgrade" (Blaze tarifi).
rem Blaze'da oyiga 2 mln chaqiruv bepul — zal uchun odatda 0 so'm, lekin bank karta ulanishi shart.
cd /d "%~dp0"
set "PATH=%LOCALAPPDATA%\node;%APPDATA%\npm;%PATH%"
pushd functions && call npm install --no-audit --no-fund && popd
call firebase deploy --only functions --project kotta-qani-09111753
pause
