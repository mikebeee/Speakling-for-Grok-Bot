# Speakling geo + weather helpers (Windows PowerShell 5.1). Dot-sourced by watch_speak.ps1, by its
# background weather job, and by the tests. Location comes ONLY from the Windows location service:
# no IP geolocation, no reverse-geocoding web service, no manual location file.

# Used only when the user has turned location off / denied it for desktop apps.
$SpringFallback=@{lat=30.08;lon=-95.42;st='TX';cc='US';city='Spring, TX (location blocked)';src='fallback'}

# ---------- Windows location ----------
# Every probe returns @{status='ok'|'denied'|'unavailable'|'noapi'; lat; lon; acc; api; detail}
#   ok          = a real position from Windows
#   denied      = Location services off, desktop-app access off, or this app was refused
#   unavailable = allowed (or not yet decided) but no fix yet: slow start, prompt pending, no signal
function Get-OsLocationWinRT([int]$TimeoutSec=45){
  try{ Add-Type -AssemblyName System.Runtime.WindowsRuntime
       $null=[Windows.Devices.Geolocation.Geolocator,Windows.Devices.Geolocation,ContentType=WindowsRuntime]
       $null=[Windows.Devices.Geolocation.Geoposition,Windows.Devices.Geolocation,ContentType=WindowsRuntime]
       $null=[Windows.Devices.Geolocation.GeolocationAccessStatus,Windows.Devices.Geolocation,ContentType=WindowsRuntime] }
  catch { return @{status='noapi';api='winrt';detail=$_.Exception.Message} }
  $asTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
  if(-not $asTask){ return @{status='noapi';api='winrt';detail='AsTask not found'} }
  $await={ param($op,[type]$t,[int]$ms) $task=$asTask.MakeGenericMethod($t).Invoke($null,@($op)); if(-not $task.Wait($ms)){ throw (New-Object TimeoutException 'timed out') }; $task.Result }
  $g=$null
  try{
    # Asks Windows for permission (Windows 11 shows its own prompt the first time); never a Speakling dialog.
    # (If the request itself errors, e.g. no UI thread in a background process, still try for a position.)
    $access='not asked'; try{ $access=[string](& $await ([Windows.Devices.Geolocation.Geolocator]::RequestAccessAsync()) ([Windows.Devices.Geolocation.GeolocationAccessStatus]) 60000) } catch { $access='request error: '+$_.Exception.Message }
    if($access -eq 'Denied'){ return @{status='denied';api='winrt';detail='access Denied (Location services or desktop-app access is off)'} }
    $g=New-Object Windows.Devices.Geolocation.Geolocator
    $pos=& $await ($g.GetGeopositionAsync([TimeSpan]::FromMinutes(10),[TimeSpan]::FromSeconds($TimeoutSec))) ([Windows.Devices.Geolocation.Geoposition]) (($TimeoutSec+15)*1000)
    $p=$pos.Coordinate.Point.Position
    return @{status='ok';api='winrt';lat=[double]$p.Latitude;lon=[double]$p.Longitude;acc=[double]$pos.Coordinate.Accuracy;detail="access $access"}
  } catch {
    $e=$_.Exception; while($e.InnerException){ $e=$e.InnerException }
    $ls=''; try{ if($g){ $ls=[string]$g.LocationStatus } } catch {}
    if($e -is [UnauthorizedAccessException] -or $e.HResult -eq -2147024891 -or $ls -eq 'Disabled'){ return @{status='denied';api='winrt';detail="$($e.GetType().Name): $($e.Message) status=$ls"} }
    return @{status='unavailable';api='winrt';detail="$($e.GetType().Name): $($e.Message) status=$ls"}
  }
}
function Get-OsLocationLegacy([int]$TimeoutSec=45){
  try{ Add-Type -AssemblyName System.Device } catch { return @{status='noapi';api='geowatcher';detail=$_.Exception.Message} }
  $w=$null
  try{
    $w=New-Object System.Device.Location.GeoCoordinateWatcher([System.Device.Location.GeoPositionAccuracy]::Default)
    $null=$w.TryStart($false,[TimeSpan]::FromSeconds($TimeoutSec))   # $false = let Windows ask for permission
    $end=(Get-Date).AddSeconds($TimeoutSec)
    while($w.Position.Location.IsUnknown -and (Get-Date) -lt $end -and [string]$w.Permission -ne 'Denied' -and [string]$w.Status -ne 'Disabled'){ Start-Sleep -Milliseconds 500 }
    $perm=[string]$w.Permission; $st=[string]$w.Status; $loc=$w.Position.Location
    if($perm -eq 'Denied' -or $st -eq 'Disabled'){ return @{status='denied';api='geowatcher';detail="permission=$perm status=$st"} }
    if(-not $loc.IsUnknown){ return @{status='ok';api='geowatcher';lat=[double]$loc.Latitude;lon=[double]$loc.Longitude;acc=[double]$loc.HorizontalAccuracy;detail="permission=$perm"} }
    return @{status='unavailable';api='geowatcher';detail="no fix after ${TimeoutSec}s permission=$perm status=$st"}
  } catch { return @{status='unavailable';api='geowatcher';detail=$_.Exception.Message} }
  finally { if($w){ try{ $w.Stop(); $w.Dispose() } catch {} } }
}
function Get-OsLocation([int]$TimeoutSec=45){
  # Modern WinRT Geolocator first; if it has no answer, ask the classic .NET watcher (same Windows service).
  $r=Get-OsLocationWinRT $TimeoutSec
  if($r.status -eq 'ok' -or $r.status -eq 'denied'){ return $r }
  $lt=$TimeoutSec; if($r.status -ne 'noapi'){ $lt=[Math]::Min(20,$TimeoutSec) }
  $r2=Get-OsLocationLegacy $lt; $r2.detail="winrt: $($r.detail); geowatcher: $($r2.detail)"
  if($r2.status -eq 'noapi'){ $r2.status='unavailable' }
  return $r2 }

# Pure decision: probe result -> what to show. Testable without Windows.
#   mode 'real'     : use the probe coordinates
#   mode 'fallback' : permission denied -> Spring, TX
#   mode 'wait'     : no usable fix yet -> neutral sky, retry with backoff (never Spring, never a guess)
function Resolve-LocationPlan($probe){
  $s=''; if($probe){ $s=[string]$probe.status }
  if($s -eq 'ok'){
    $la=$probe.lat; $lo=$probe.lon
    if($null -ne $la -and $null -ne $lo -and -not [double]::IsNaN([double]$la) -and -not [double]::IsNaN([double]$lo) -and [Math]::Abs([double]$la) -le 90 -and [Math]::Abs([double]$lo) -le 180 -and -not ([double]$la -eq 0 -and [double]$lo -eq 0)){
      return @{mode='real';lat=[double]$la;lon=[double]$lo;src='windows';reason="windows location ($($probe.api))"} }
    return @{mode='wait';reason='windows returned an invalid position'} }
  if($s -eq 'denied'){ return @{mode='fallback';lat=$SpringFallback.lat;lon=$SpringFallback.lon;src='fallback';st=$SpringFallback.st;cc=$SpringFallback.cc;city=$SpringFallback.city;reason="location permission denied ($($probe.detail))"} }
  return @{mode='wait';reason="location not available yet ($s$(if($probe -and $probe.detail){': '+$probe.detail}))"} }

# Backoff for location / weather retries: 15 s, 30 s, 60 s, 120 s, 240 s, then every 5 min.
function Get-RetryDelaySec([int]$attempt){ $d=15*[Math]::Pow(2,[Math]::Max(0,$attempt)); return [int][Math]::Min(300,$d) }

# ---------- offline US state lookup ----------
$script:UsStates=$null
function Import-UsStates([string]$path){
  $t=@{}; foreach($line in [IO.File]::ReadAllLines($path)){ if(-not $line -or $line[0] -eq '#'){ continue }; $i=$line.IndexOf('='); $st=$line.Substring(0,$i); $rings=@()
    foreach($r in $line.Substring($i+1).Split('|')){ $pts=$r.Split(' '); $n=$pts.Count; $ys=New-Object double[] $n; $xs=New-Object double[] $n; $s=90.0; $no=-90.0; $w=180.0; $e=-180.0
      for($k=0;$k -lt $n;$k++){ $c=$pts[$k].Split(','); $y=[int]$c[0]/100.0; $x=[int]$c[1]/100.0; $ys[$k]=$y; $xs[$k]=$x; if($y -lt $s){$s=$y}; if($y -gt $no){$no=$y}; if($x -lt $w){$w=$x}; if($x -gt $e){$e=$x} }
      $rings+=,@($ys,$xs,$s,$no,$w,$e) }
    $t[$st]=$rings }
  $script:UsStates=$t }
function Test-InRing($ring,[double]$lat,[double]$lon){ $ys=$ring[0]; $xs=$ring[1]; $n=$ys.Length; $in=$false; $j=$n-1
  for($i=0;$i -lt $n;$i++){ if((($ys[$i] -gt $lat) -ne ($ys[$j] -gt $lat)) -and ($lon -lt ($xs[$j]-$xs[$i])*($lat-$ys[$i])/($ys[$j]-$ys[$i])+$xs[$i])){ $in=-not $in }; $j=$i }; return $in }
function Get-RingDistance($ring,[double]$lat,[double]$lon){ $ys=$ring[0]; $xs=$ring[1]; $n=$ys.Length; $best=1e9; $j=$n-1; $kx=[Math]::Cos($lat*0.0174533)
  for($i=0;$i -lt $n;$i++){ $ax=($xs[$j]-$lon)*$kx; $ay=$ys[$j]-$lat; $bx=($xs[$i]-$lon)*$kx; $by=$ys[$i]-$lat; $dx=$bx-$ax; $dy=$by-$ay; $l2=$dx*$dx+$dy*$dy
    $t=0.0; if($l2 -gt 0){ $t=[Math]::Max(0.0,[Math]::Min(1.0,-($ax*$dx+$ay*$dy)/$l2)) }; $px=$ax+$t*$dx; $py=$ay+$t*$dy; $d=[Math]::Sqrt($px*$px+$py*$py); if($d -lt $best){ $best=$d }; $j=$i }; return $best }
# Two-letter US state/DC/PR for a point, or '' if the point is not in the US (or the data file is missing).
# Points within ~1 km outside the simplified outline (coastline) still count.
function Get-UsState([double]$lat,[double]$lon,[string]$path=''){
  if(-not $script:UsStates){ if(-not $path){ $path=Join-Path $PSScriptRoot 'assets\us_states.txt' }; if(-not (Test-Path $path)){ return '' }; Import-UsStates $path }
  $buf=0.01; $near=''; $nd=$buf
  foreach($st in $script:UsStates.Keys){ foreach($r in $script:UsStates[$st]){
    if($lat -lt $r[2]-$buf -or $lat -gt $r[3]+$buf -or $lon -lt $r[4]-$buf -or $lon -gt $r[5]+$buf){ continue }
    if(Test-InRing $r $lat $lon){ return $st }
    $d=Get-RingDistance $r $lat $lon; if($d -lt $nd){ $nd=$d; $near=$st } } }
  return $near }

# ---------- WMO weather codes (Open-Meteo) ----------
# 0 clear, 1 mainly clear, 2 partly cloudy, 3 overcast, 45/48 fog, 51-55 drizzle, 56-57 freezing drizzle,
# 61-65 rain, 66-67 freezing rain, 71-77 snow, 80-82 rain showers, 85-86 snow showers, 95-99 thunderstorm.
# $precip = mm in the last 15 min; any measurable precipitation overrides a dry-sky code (never "sunny" while wet).
function Get-WxCode($code,$precip){ $c=[int]$code; if($null -ne $precip -and [double]$precip -ge 0.1 -and $c -le 48){ return 61 }; return $c }
function WxMap($c){ $c=[int]$c
  if($c -ge 95 -and $c -le 99){ return 'storm' }
  if(($c -ge 51 -and $c -le 67) -or ($c -ge 80 -and $c -le 82)){ return 'rain' }
  if(($c -ge 71 -and $c -le 77) -or $c -eq 85 -or $c -eq 86){ return 'snow' }
  if($c -eq 45 -or $c -eq 48){ return 'fog' }
  if($c -eq 0 -or $c -eq 1){ return 'clear' }
  return 'cloudy' }   # 2, 3 and any unknown code: never 'clear'
# Summary text for the top-left stamp. $isDay from Open-Meteo (1 = sun up); falls back to the clock if missing.
function WxSum($c,$tp,$pp,$u,$isDay=$null){ $c=[int]$c
  $day= if($null -ne $isDay -and "$isDay" -ne ''){ [int]$isDay -eq 1 } else { $h=(Get-Date).Hour; $h -ge 6 -and $h -lt 19 }
  $w= if($c -eq 0 -or $c -eq 1){ if($day){'SUNNY'}else{'CLEAR'} } elseif($c -eq 2){'PT CLOUDY'} elseif($c -eq 3){'CLOUDY'} elseif($c -eq 45 -or $c -eq 48){'FOG'} elseif($c -ge 51 -and $c -le 55){'DRIZZLE'} elseif($c -eq 56 -or $c -eq 57 -or $c -eq 66 -or $c -eq 67){'FRZ RAIN'} elseif($c -ge 61 -and $c -le 65){'RAIN'} elseif($c -ge 80 -and $c -le 82){'SHOWERS'} elseif(($c -ge 71 -and $c -le 77) -or $c -eq 85 -or $c -eq 86){'SNOW'} elseif($c -ge 95 -and $c -le 99){'STORMS'} else {'CLOUDY'}
  $l2=''; if($null -ne $tp -and "$tp" -ne ''){ $l2=([string][Math]::Round([double]$tp))+$u }; if($null -ne $pp -and "$pp" -ne '' -and [int]$pp -ge 10){ $l2=($l2+' '+[int]$pp+'%').Trim() }
  $w+'~'+$l2 }
# Fahrenheit for US locations; otherwise follow the PC's region (US, Liberia, Myanmar use F).
function Get-TempUnit([string]$st,[string]$region){ if($st){ return 'F' }; if($region -in 'US','LR','MM'){ return 'F' }; return 'C' }
function Get-OpenMeteoUrl([double]$lat,[double]$lon,[string]$unit){ $ic=[Globalization.CultureInfo]::InvariantCulture
  'https://api.open-meteo.com/v1/forecast?latitude='+[Math]::Round($lat,2).ToString($ic)+'&longitude='+[Math]::Round($lon,2).ToString($ic)+'&current=weather_code,is_day,temperature_2m,precipitation&hourly=precipitation_probability&forecast_hours=1&timezone=auto'+$(if($unit -eq 'F'){'&temperature_unit=fahrenheit'}else{''}) }

# ---------- one weather cycle (runs inside the background job) ----------
# $known  = last good Windows fix from THIS session (in memory only; nothing is read from disk).
# $locate = ask Windows for a fresh fix this cycle.  $dev = developer test hook (see watch_speak.ps1).
function Invoke-WeatherCycle($known,[bool]$locate,[string]$dev='',[string]$statesPath='',[int]$LocTimeoutSec=45){
  $o=[ordered]@{planMode='';planReason='';probeStatus='';probeApi='';acc=$null;locSrc='';lat=$null;lon=$null;st='';unit='';code=$null;rawCode=$null;precip=$null;isDay=$null;temp=$null;pop=$null;err=''}
  $use=$null
  if($locate){
    if($dev){ $ic=[Globalization.CultureInfo]::InvariantCulture
      if($dev -eq 'denied'){ $probe=@{status='denied';api='dev';detail='dev hook'} } elseif($dev -eq 'unavailable'){ $probe=@{status='unavailable';api='dev';detail='dev hook'} }
      else { $pp=$dev.Split(','); $probe=@{status='ok';api='dev';lat=[double]::Parse($pp[0],$ic);lon=[double]::Parse($pp[1],$ic);acc=0} } }
    else { $probe=Get-OsLocation $LocTimeoutSec }
    $plan=Resolve-LocationPlan $probe
    $o.planMode=$plan.mode; $o.planReason=$plan.reason; $o.probeStatus=[string]$probe.status; $o.probeApi=[string]$probe.api; $o.acc=$probe.acc
    if($plan.mode -ne 'wait'){ $use=$plan } }
  if(-not $use -and $known -and $known.lat -ne $null){ $use=@{mode='session';lat=[double]$known.lat;lon=[double]$known.lon;src='windows(session)'} }
  if(-not $use){ $o.err='no location yet'; return [pscustomobject]$o }
  $o.locSrc=$use.src; $o.lat=[Math]::Round([double]$use.lat,2); $o.lon=[Math]::Round([double]$use.lon,2)
  if($use.mode -eq 'fallback'){ $o.st=$use.st } else { try{ $o.st=Get-UsState $use.lat $use.lon $statesPath } catch { $o.st='' } }
  $o.unit=Get-TempUnit $o.st ([Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName)
  try{
    $res=Invoke-RestMethod -Uri (Get-OpenMeteoUrl $use.lat $use.lon $o.unit) -TimeoutSec 15
    if($null -eq $res.current -or $null -eq $res.current.weather_code){ throw 'Open-Meteo response had no weather_code' }
    $o.rawCode=[int]$res.current.weather_code; $o.precip=$res.current.precipitation; $o.code=Get-WxCode $o.rawCode $o.precip
    $o.isDay=$res.current.is_day; $o.temp=$res.current.temperature_2m; try{ $o.pop=$res.hourly.precipitation_probability[0] } catch {}
  } catch { $o.err='weather fetch failed: '+$_.Exception.Message }
  return [pscustomobject]$o }

# ---------- applying a cycle result to the watcher state (pure; unit-tested) ----------
# $S is a hashtable: wx, sum, isDay, st, at (datetime of last good reading), wxAttempt, locAttempt, known, knownAt, locKey, log (list)
# Returns seconds until the next cycle. Readings never come from disk; on failure the face goes neutral
# once the last good reading from this session is older than $MaxAgeMin.
function New-WxState(){ @{wx='';sum='';isDay=$null;st='';at=$null;wxAttempt=0;locAttempt=0;known=$null;knownAt=$null;locKey='';mode='';log=(New-Object System.Collections.ArrayList)} }
function Clear-WxReading($S,[string]$why){ if($S.wx -or $S.sum){ [void]$S.log.Add("weather: neutral sky ($why)") }; $S.wx=''; $S.sum=''; $S.isDay=$null; $S.at=$null }
function Update-WxState($S,$r,[datetime]$now,[int]$WeatherMinutes=15,[int]$MaxAgeMin=30){
  if(-not $r){ $r=[pscustomobject]@{planMode='';err='weather job returned nothing'} }
  if($r.planMode){
    $k=$r.planMode+'|'+$r.locSrc
    if($r.planMode -eq 'real'){ $S.known=@{lat=$r.lat;lon=$r.lon}; $S.knownAt=$now; $S.locAttempt=0 }
    elseif($r.planMode -eq 'fallback'){ $S.known=$null; $S.knownAt=$null; $S.locAttempt=0 }
    else { $S.locAttempt++ }
    if($k -ne $S.locKey -or $r.planMode -eq 'wait'){
      $msg= if($r.planMode -eq 'real'){ "location: Windows Location ($($r.probeApi)) $($r.lat),$($r.lon) +/-$([int]$r.acc) m state=$($r.st)" }
            elseif($r.planMode -eq 'fallback'){ "location: permission denied -> Spring, TX fallback ($($r.planReason))" }
            else { "location: $($r.planReason); retry #$($S.locAttempt) in $(Get-RetryDelaySec ($S.locAttempt-1)) s"+$(if($r.locSrc){" (using this session's earlier fix)"}else{' (neutral sky until then)'}) }
      [void]$S.log.Add($msg); $S.locKey=$k }
    $S.mode=$r.planMode }
  if($r.err){
    $S.wxAttempt++
    if(-not $S.at -or ($now-$S.at).TotalMinutes -gt $MaxAgeMin){ Clear-WxReading $S $r.err }
    $d=Get-RetryDelaySec ($S.wxAttempt-1); if($r.planMode -eq 'wait'){ $d=Get-RetryDelaySec ($S.locAttempt-1) }
    [void]$S.log.Add("weather: $($r.err); retry in $d s"); return $d }
  $S.wxAttempt=0
  $new=WxMap $r.code; $sum=WxSum $r.code $r.temp $r.pop $r.unit $r.isDay
  if($new -ne $S.wx -or $sum -ne $S.sum){ [void]$S.log.Add("weather: $new '$sum' (code $($r.code), raw $($r.rawCode), precip $($r.precip) mm, is_day $($r.isDay), via $($r.locSrc))") }
  $S.wx=$new; $S.sum=$sum; $S.isDay=$r.isDay; $S.st=$r.st; $S.at=$now
  if($r.planMode -eq 'wait'){ return [Math]::Min($WeatherMinutes*60,(Get-RetryDelaySec ($S.locAttempt-1))) }
  return $WeatherMinutes*60 }
# Should this cycle ask Windows for a fresh fix?  Yes until we have a real fix, while on the Spring fallback
# (so turning location back on is picked up), and every $LocateMinutes after that.
function Test-NeedLocate($S,[datetime]$now,[int]$LocateMinutes=60){ if(-not $S.known -or -not $S.knownAt){ return $true }; return ($now-$S.knownAt).TotalMinutes -ge $LocateMinutes }
# An earlier fix from this session is reused (for fresh weather) only while relocation is failing, up to 6 h.
function Get-KnownLocation($S,[datetime]$now){ if($S.known -and $S.knownAt -and ($now-$S.knownAt).TotalHours -lt 6){ return $S.known }; return $null }
