# Finds the MiniToo's Bluetooth address. Order: -BtAddress parameter, config.json "bt_address",
# then auto-discovery of a paired device whose name starts with "Divoom MiniToo".
function ConvertTo-BtUInt64([string]$a){ $h=($a -replace '[^0-9A-Fa-f]',''); if($h.Length -ne 12){ throw "Bluetooth address '$a' is not 12 hex digits" }; return [UInt64]::Parse($h,[Globalization.NumberStyles]::HexNumber) }
function Resolve-MiniTooAddress([string]$Explicit='',[string]$Dir=$PSScriptRoot,[string]$NamePattern='Divoom MiniToo*'){
  if($Explicit){ return ConvertTo-BtUInt64 $Explicit }
  $cf=Join-Path $Dir 'config.json'
  if(Test-Path $cf){ try{ $c=Get-Content $cf -Raw | ConvertFrom-Json; if($c.bt_address){ return ConvertTo-BtUInt64 $c.bt_address }; if($c.device_name){ $NamePattern=[string]$c.device_name+'*' } } catch {} }
  $cache=Join-Path $Dir 'device.cache'
  if(Test-Path $cache){ try{ return ConvertTo-BtUInt64 (Get-Content $cache -Raw).Trim() } catch {} }
  $devs=@(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -like $NamePattern })
  foreach($d in $devs){ if($d.InstanceId -match 'DEV_([0-9A-F]{12})' -or $d.InstanceId -match '&([0-9A-F]{12})_'){ $m=$Matches[1]; Set-Content -Path $cache -Value $m; return ConvertTo-BtUInt64 $m } }
  throw "No paired Bluetooth device named '$NamePattern' found. Pair the MiniToo in Windows Settings, or set bt_address in config.json."
}
