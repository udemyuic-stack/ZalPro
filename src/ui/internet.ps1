# Emulyatorni internetga ochadi: telefon (mobil internet yoki istalgan Wi-Fi) APK orqali ulanadi.
# Akkaunt va admin huquqi kerak emas. Faqat Node va chiquvchi ulanish bore.pub:7835 kerak.
#   1) avval start.ps1 (yoki emulators.ps1) — emulyator ishlab tursin
#   2) powershell -ExecutionPolicy Bypass -File .\internet.ps1   (oyna ochiq tursin)
# APK shu portlarga yig'ilgan (o'zgartirsangiz APK ni qayta yig'ing):
#   flutter build apk --release --split-per-abi --dart-define=EMULATOR_HOST=bore.pub `
#     --dart-define=AUTH_PORT=47199 --dart-define=FIRESTORE_PORT=47185
# DIQQAT: tunnel ochiq ekan, emulyatordagi sinov ma'lumotlari internetdan ochiq bo'ladi.
#         Sinovdan keyin oynani yoping (Ctrl+C).
$authPort = 47199
$firestorePort = 47185
$tool = Join-Path $PSScriptRoot 'tools\bore-lite.mjs'

$auth = Start-Process node -ArgumentList "`"$tool`"", 9099, $authPort -NoNewWindow -PassThru
$fs = Start-Process node -ArgumentList "`"$tool`"", 8085, $firestorePort -NoNewWindow -PassThru
Write-Host "Tunnel: auth bore.pub:$authPort, firestore bore.pub:$firestorePort  (to'xtatish: Ctrl+C)"
try { Wait-Process -Id $auth.Id, $fs.Id }
finally { Stop-Process -Id $auth.Id, $fs.Id -ErrorAction SilentlyContinue }
