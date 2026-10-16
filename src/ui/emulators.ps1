# Lokal Firebase (Auth + Firestore) emulyatorlarini ishga tushiradi. Akkaunt kerak emas.
# Ma'lumotlar .emulator-data papkasida saqlanadi (Ctrl+C bosganda yoziladi).
# UI: http://localhost:4000
# Java 21+ kerak: JAVA_HOME -> %LOCALAPPDATA%\jdk21\* -> PATH; topilmasa portativ JDK yuklab olinadi.

function Get-JavaMajor($javaExe) {
  # cmd orqali: PowerShell 5.1 stderr'ni xato deb o'rab olmasligi uchun
  $v = cmd /c "`"$javaExe`" -version 2>&1" | Select-Object -First 1
  if ("$v" -match '"(\d+)') { [int]$Matches[1] } else { 0 }
}

function Find-Java21 {
  $candidates = @()
  if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
  $candidates += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'jdk21') -Directory -ErrorAction SilentlyContinue |
    ForEach-Object FullName
  $onPath = Get-Command java -ErrorAction SilentlyContinue
  if ($onPath) { $candidates += Split-Path (Split-Path $onPath.Source) }
  foreach ($c in $candidates) {
    $exe = Join-Path $c 'bin\java.exe'
    if ((Test-Path $exe) -and (Get-JavaMajor $exe) -ge 21) { return $c }
  }
  return $null
}

function Install-Java21 {
  $dst = Join-Path $env:LOCALAPPDATA 'jdk21'
  $work = Join-Path $env:TEMP ('jdk21-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $work, $dst | Out-Null
  Write-Host 'Java 21 yuklab olinmoqda (~190 MB, admin huquqi kerak emas)...'
  $ProgressPreference = 'SilentlyContinue'
  $zip = Join-Path $work 'jdk.zip'
  Invoke-WebRequest -UseBasicParsing 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jdk/hotspot/normal/eclipse' -OutFile $zip
  Expand-Archive $zip $dst -Force
  Find-Java21
}

$java = Find-Java21
if (-not $java) { $java = Install-Java21 }
if (-not $java) { Write-Host "[X] Java 21 topilmadi va o'rnatib bo'lmadi" -ForegroundColor Red; exit 1 }
$env:JAVA_HOME = $java
$env:Path = "$java\bin;$env:Path"
Write-Host "[OK] Java: $java"

$data = Join-Path $PSScriptRoot '.emulator-data'
$fbArgs = @('emulators:start', '--project', 'demo-kotta-qani', "--export-on-exit=$data")
if (Test-Path (Join-Path $data 'firebase-export-metadata.json')) { $fbArgs += "--import=$data" }
firebase @fbArgs
