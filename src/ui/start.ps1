# Kotta Qani Diet - kompyuterda ishga tushirish (haqiqiy Firebase'ga ulanadi).
#   powershell -ExecutionPolicy Bypass -File .\start.ps1
# Telefon va kompyuter BITTA bazani ko'radi (kompyuterda kiritilgani telefonda ham ko'rinadi).
# Emulyator kerak emas - ilova to'g'ridan-to'g'ri Google'ga ulanadi.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "[X] flutter topilmadi: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Red
  exit 1
}
Write-Host 'flutter pub get...'
flutter pub get | Out-Null
Write-Host '[OK] Haqiqiy Firebase (kotta-qani-09111753). Trener: +998 90 000 00 00 (parol: PAROLLAR.md)'
Write-Host 'Ilova yuklab olish sahifasi: https://kotta-qani-09111753.web.app'
flutter run -d chrome --web-port 5173
