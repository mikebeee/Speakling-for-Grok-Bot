# Stops the watcher cleanly, removes the scheduled task, and (with -RemoveFiles) deletes the install folder.
param([string]$InstallDir=(Join-Path $env:LOCALAPPDATA 'Speakling'),[string]$TaskName='Speakling Watcher',[switch]$RemoveFiles)
if(Test-Path $InstallDir){ New-Item -ItemType File -Force -Path (Join-Path $InstallDir 'watch.stop') | Out-Null }
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($InstallDir,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and ($_.CommandLine -like '*watch_speak.ps1*' -or $_.CommandLine -like '*run_watch.ps1*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
if($RemoveFiles){ Remove-Item $InstallDir -Recurse -Force; Write-Host "Removed $InstallDir" } else { Write-Host "Task removed. Files kept in $InstallDir (use -RemoveFiles to delete)." }
