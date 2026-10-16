# Diamond — Firebase'ga joylash (qoidalar + yuklab olish sahifasi).
#   powershell -ExecutionPolicy Bypass -File .\deploy.ps1
#
# Birinchi marta brauzer ochilib, Google akkauntingizni so'raydi (loyiha egasining akkaunti).
# Keyingi safar so'ramaydi.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Hamma natija joylash-log.txt ga ham yoziladi — ishlamasa, shu faylni ko'rsating
Start-Transcript -Path (Join-Path $PSScriptRoot 'joylash-log.txt') -Force | Out-Null
trap {
  Write-Host "[X] Kutilmagan xato: $_" -ForegroundColor Red
  Stop-Transcript | Out-Null
  exit 1
}

# Bu kompyuterda Node va Java foydalanuvchi papkasiga o'rnatilgan
$env:Path = "$env:LOCALAPPDATA\node;$env:APPDATA\npm;$env:USERPROFILE\flutter\bin;$env:Path"
$env:JAVA_HOME = "$env:LOCALAPPDATA\jdk21"

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host '[X] firebase topilmadi. Avval: npm install -g firebase-tools' -ForegroundColor Red
  exit 1
}

# --- kirish ---
$who = (firebase login:list 2>&1 | Out-String)
if ($who -notmatch '@') {
  Write-Host 'Google akkauntingizga kirish kerak. Brauzer ochiladi...' -ForegroundColor Yellow
  firebase login
  if ($LASTEXITCODE -ne 0) { Write-Host '[X] Kirish bajarilmadi' -ForegroundColor Red; exit 1 }
} else {
  Write-Host "[OK] Kirgan: $(($who -split "`n" | Where-Object { $_ -match '@' } | Select-Object -First 1).Trim())"
}

$apk = 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'
$bin = 'public/app/kq.bin'
if ((Test-Path $apk) -and (Test-Path $bin)) {
  if ((Get-Item $apk).LastWriteTime -gt (Get-Item $bin).LastWriteTime) {
    Write-Host 'Yangi APK topildi - public/app ga kochirilmoqda...' -ForegroundColor Yellow
    Copy-Item $apk $bin -Force
    Copy-Item 'build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk' 'public/app/kq-eski.bin' -Force
  }
}

# --- qoidalar ---
Write-Host ''
Write-Host 'Xavfsizlik qoidalari joylanmoqda...' -ForegroundColor Cyan
firebase deploy --only firestore:rules
if ($LASTEXITCODE -ne 0) { Write-Host '[X] Qoidalar joylanmadi' -ForegroundColor Red; exit 1 }

# --- yuklab olish sahifasi (APK) ---
Write-Host ''
Write-Host 'Yuklab olish sahifasi joylanmoqda...' -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host '[X] Hosting joylanmadi' -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '=== TAYYOR ===' -ForegroundColor Green
Write-Host 'Yuklab olish: https://kotta-qani-09111753.web.app'
Stop-Transcript | Out-Null
