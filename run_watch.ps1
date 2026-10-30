# Keeps watch_speak.ps1 running forever; restarts it 15 s after any exit.
$ErrorActionPreference='Continue'
$mtx=New-Object System.Threading.Mutex($false,'Local\MiniTooRunWatch')
if(-not $mtx.WaitOne(0)){ exit 0 }
$dir=$PSScriptRoot; $log=Join-Path $dir 'watch.log'
function L($m){ $line=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+'  [run] '+$m
  try{ if((Test-Path $log) -and (Get-Item $log).Length -gt 1MB){ Move-Item $log ($log+'.1') -Force }; Add-Content -Path $log -Value $line } catch {} }
L "wrapper start pid=$PID"
while($true){
  if(Test-Path (Join-Path $dir 'watch.stop')){ L 'watch.stop found, wrapper exiting'; break }
  $p=Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',(Join-Path $dir 'watch_speak.ps1'),'-Forever' -WindowStyle Hidden -PassThru -Wait
  L ('watcher exited code '+$p.ExitCode+'; restarting in 15 s')
  Start-Sleep -Seconds 15 }
