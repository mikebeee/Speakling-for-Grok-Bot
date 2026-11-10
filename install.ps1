# Speakling for Grok Bot - installer. Run in PowerShell from the unzipped folder:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-InstallDir <path>] [-NoTask] [-NoStart] [-TaskName <name>]
param([string]$InstallDir=(Join-Path $env:LOCALAPPDATA 'Speakling'),[switch]$NoTask,[switch]$NoStart,[string]$TaskName='Speakling Watcher')
$ErrorActionPreference='Stop'
$src=$PSScriptRoot
$SpeaklingVersion='1.0.1'
# Upgrade: stop a running copy first (its libzstd.dll is locked while it runs).
if(Test-Path $InstallDir){ New-Item -ItemType File -Force -Path (Join-Path $InstallDir 'watch.stop') | Out-Null
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($InstallDir,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and ($_.CommandLine -like '*watch_speak.ps1*' -or $_.CommandLine -like '*run_watch.ps1*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 500 }
New-Item -ItemType Directory -Force -Path $InstallDir,(Join-Path $InstallDir 'assets') | Out-Null
$files='watch_speak.ps1','run_watch.ps1','buddy.ps1','holiday.ps1','btaddr.ps1','geo.ps1','scene.cs','libzstd.dll','config.example.json'
foreach($f in $files){ Copy-Item (Join-Path $src $f) $InstallDir -Force }
Copy-Item (Join-Path $src 'assets\*') (Join-Path $InstallDir 'assets') -Force
Get-ChildItem $InstallDir -Recurse -File | Unblock-File
$cfg=Join-Path $InstallDir 'config.json'; if(-not (Test-Path $cfg)){ Copy-Item (Join-Path $InstallDir 'config.example.json') $cfg }
Remove-Item (Join-Path $InstallDir 'watch.stop'),(Join-Path $InstallDir 'device.cache') -Force -ErrorAction SilentlyContinue
# v1.0.1: location comes only from Windows Location and weather is fetched fresh at every start, so remove
# the manual location file and the location/weather caches left by older versions.
foreach($f in 'location_override.json','location_override.example.json','location.json','weather.json'){ $p=Join-Path $InstallDir $f; if(Test-Path $p){ Remove-Item $p -Force -ErrorAction SilentlyContinue; Write-Host "Removed old $f" } }
. (Join-Path $InstallDir 'btaddr.ps1')
try{ $a=Resolve-MiniTooAddress '' $InstallDir; Write-Host ('Found MiniToo at {0:X12}' -f $a) } catch { Write-Warning $_.Exception.Message }
if(-not $NoTask){
  $act=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $InstallDir 'run_watch.ps1')+'"')
  $trg=New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
  $set=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
  Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $trg -Settings $set -Description 'Speakling for Grok Bot (unofficial)' -Force | Out-Null
  if($NoStart){ Write-Host "Scheduled task '$TaskName' registered (not started)." }
  else { Start-ScheduledTask -TaskName $TaskName; Write-Host "Scheduled task '$TaskName' registered and started." }
}
Write-Host "Speakling v$SpeaklingVersion installed to $InstallDir. Log: $(Join-Path $InstallDir 'watch.log')"
Write-Host 'For local weather, allow location if Windows asks (Settings > Privacy & security > Location: Location services and Let desktop apps access your location).'
