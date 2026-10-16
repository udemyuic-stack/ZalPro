# Telefonni USB orqali emulyatorga ulaydi (tarmoq/firewall yopiq bo'lsa).
# Telefonda: Sozlamalar -> Dasturchi uchun -> USB orqali tuzatish (USB debugging) yoqilgan bo'lsin.
# APK: flutter build apk --release --dart-define=EMULATOR_HOST=127.0.0.1
# Telefonni qayta ulaganda shu skriptni yana ishga tushiring.
# boshqa kompyuterda SDK boshqa joyda bo'lishi mumkin
$sdk = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) |
  Where-Object { $_ -and (Test-Path (Join-Path $_ 'platform-tools\adb.exe')) } | Select-Object -First 1
if (-not $sdk) { Write-Host '[X] adb topilmadi (Android SDK platform-tools kerak)' -ForegroundColor Red; exit 1 }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
& $adb devices
& $adb reverse tcp:9099 tcp:9099
& $adb reverse tcp:8085 tcp:8085
& $adb reverse --list
if ($args -contains 'install') {
  & $adb install -r (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk')
}
