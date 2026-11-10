# Offline unit tests for geo.ps1 (location decision, state lookup, WMO mapping, weather state machine).
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_geo.ps1 [-Live]
# -Live also runs one real Open-Meteo fetch per location path using the developer test hook.
param([switch]$Live)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'geo.ps1')
$script:fail=0; $script:pass=0
function Eq($name,$got,$exp){ if("$got" -ceq "$exp"){ $script:pass++ } else { $script:fail++; Write-Host "FAIL $name : got '$got' expected '$exp'" } }

# --- WMO mapping: wet codes must never be clear/sunny
foreach($c in 0..99){ $m=WxMap $c
  if(($c -ge 51 -and $c -le 67) -or ($c -ge 80 -and $c -le 82)){ Eq "WxMap $c" $m 'rain' }
  elseif($c -ge 95){ Eq "WxMap $c" $m 'storm' }
  elseif(($c -ge 71 -and $c -le 77) -or $c -eq 85 -or $c -eq 86){ Eq "WxMap $c" $m 'snow' }
  elseif($c -eq 45 -or $c -eq 48){ Eq "WxMap $c" $m 'fog' }
  elseif($c -le 1){ Eq "WxMap $c" $m 'clear' }
  else { Eq "WxMap $c not clear" ($m -ne 'clear') $true } }
foreach($c in 51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99){ $w=(WxSum $c 70 50 'F' 1).Split('~')[0]; Eq "WxSum $c not sunny" ($w -ne 'SUNNY' -and $w -ne 'CLEAR') $true }
Eq 'WxSum 61' (WxSum 61 67.4 81 'F' 1) 'RAIN~67F 81%'
Eq 'WxSum 53' (WxSum 53 60 5 'F' 1) 'DRIZZLE~60F'
Eq 'WxSum 66' (WxSum 66 31 90 'F' 1) 'FRZ RAIN~31F 90%'
Eq 'WxSum 81' (WxSum 81 75 60 'F' 1) 'SHOWERS~75F 60%'
Eq 'WxSum 95' (WxSum 95 75 60 'F' 0) 'STORMS~75F 60%'
Eq 'WxSum 0 day' (WxSum 0 75 0 'F' 1) 'SUNNY~75F'
Eq 'WxSum 0 night' (WxSum 0 75 0 'F' 0) 'CLEAR~75F'
Eq 'precip overrides clear' (WxMap (Get-WxCode 0 0.4)) 'rain'
Eq 'precip overrides overcast' (WxMap (Get-WxCode 3 0.1)) 'rain'
Eq 'trace precip ignored' (WxMap (Get-WxCode 0 0.0)) 'clear'
Eq 'precip keeps storm' (Get-WxCode 95 2.0) 95
Eq 'precip keeps snow' (Get-WxCode 73 1.0) 73
Eq 'unit US state' (Get-TempUnit 'TX' 'DE') 'F'
Eq 'unit region' (Get-TempUnit '' 'DE') 'C'
Eq 'unit region US' (Get-TempUnit '' 'US') 'F'
Eq 'url' (Get-OpenMeteoUrl 30.0812 -95.4167 'F') 'https://api.open-meteo.com/v1/forecast?latitude=30.08&longitude=-95.42&current=weather_code,is_day,temperature_2m,precipitation&hourly=precipitation_probability&forecast_hours=1&timezone=auto&temperature_unit=fahrenheit'

# --- location decision
$p=Resolve-LocationPlan @{status='ok';api='winrt';lat=30.1;lon=-95.4}; Eq 'ok->real' $p.mode 'real'; Eq 'ok lat' $p.lat 30.1
$p=Resolve-LocationPlan @{status='denied';api='winrt';detail='x'}; Eq 'denied->fallback' $p.mode 'fallback'; Eq 'fallback lat' $p.lat 30.08; Eq 'fallback lon' $p.lon -95.42; Eq 'fallback st' $p.st 'TX'
foreach($s in 'unavailable','noapi','','weird'){ Eq "$s->wait" (Resolve-LocationPlan @{status=$s}).mode 'wait' }
Eq 'null->wait' (Resolve-LocationPlan $null).mode 'wait'
Eq '0,0->wait' (Resolve-LocationPlan @{status='ok';lat=0;lon=0}).mode 'wait'
Eq 'NaN->wait' (Resolve-LocationPlan @{status='ok';lat=[double]::NaN;lon=1}).mode 'wait'
Eq 'missing lat->wait' (Resolve-LocationPlan @{status='ok';lon=1}).mode 'wait'
Eq 'retry' ((0..7 | % { Get-RetryDelaySec $_ }) -join ',') '15,30,60,120,240,300,300,300'

# --- offline state lookup (no network)
$sp=Join-Path $root 'assets\us_states.txt'
foreach($t in @(@('Spring TX',30.08,-95.42,'TX'),@('San Antonio',29.42,-98.49,'TX'),@('El Paso',31.76,-106.49,'TX'),@('Kansas City MO',39.10,-94.58,'MO'),@('Kansas City KS',39.11,-94.63,'KS'),@('NYC',40.71,-74.01,'NY'),@('Jersey City',40.72,-74.08,'NJ'),@('Honolulu',21.31,-157.86,'HI'),@('Anchorage',61.22,-149.90,'AK'),@('Juneau',58.30,-134.42,'AK'),@('Key West',24.56,-81.78,'FL'),@('Miami Beach',25.79,-80.13,'FL'),@('Seattle',47.61,-122.33,'WA'),@('Washington DC',38.90,-77.04,'DC'),@('Chicago',41.88,-87.63,'IL'),@('Providence',41.82,-71.41,'RI'),@('Portland ME',43.66,-70.26,'ME'),@('Denver',39.74,-104.99,'CO'),@('Toronto',43.65,-79.38,''),@('Vancouver',49.28,-123.12,''),@('Tijuana',32.51,-117.04,''),@('Ciudad Juarez',31.69,-106.42,''),@('London',51.5,-0.12,''),@('Mid-Atlantic',35.0,-50.0,''))){
  Eq "state $($t[0])" (Get-UsState $t[1] $t[2] $sp) $t[3] }

# --- weather state machine (times are simulated)
$t0=Get-Date '2026-11-10T08:00:00'
$S=New-WxState
Eq 'startup locate' (Test-NeedLocate $S $t0) $true
Eq 'startup neutral' $S.wx ''
$d=Update-WxState $S ([pscustomobject]@{planMode='wait';planReason='location not available yet (unavailable)';locSrc='';err='no location yet'}) $t0
Eq 'wait stays neutral' $S.wx ''; Eq 'wait sum empty' $S.sum ''; Eq 'wait retry 15' $d 15
$d=Update-WxState $S ([pscustomobject]@{planMode='wait';planReason='x';locSrc='';err='no location yet'}) $t0.AddSeconds(15)
Eq 'wait retry 30' $d 30; Eq 'wait still neutral' $S.wx ''
$ok=[pscustomobject]@{planMode='real';planReason='windows location (winrt)';locSrc='windows';probeApi='winrt';lat=30.08;lon=-95.42;acc=40;st='TX';unit='F';code=61;rawCode=61;precip=0.5;isDay=1;temp=67;pop=81;err=''}
$d=Update-WxState $S $ok $t0.AddMinutes(1)
Eq 'real rain' $S.wx 'rain'; Eq 'real sum' $S.sum 'RAIN~67F 81%'; Eq 'real st' $S.st 'TX'; Eq 'next 15 min' $d 900; Eq 'known kept' $S.known.lat 30.08
Eq 'no relocate at 30 min' (Test-NeedLocate $S $t0.AddMinutes(31)) $false
Eq 'relocate at 61 min' (Test-NeedLocate $S $t0.AddMinutes(62)) $true
$d=Update-WxState $S ([pscustomobject]@{planMode='';locSrc='windows(session)';err='weather fetch failed: timeout'}) $t0.AddMinutes(16)
Eq 'short outage keeps fresh reading' $S.wx 'rain'; Eq 'fetch retry 15' $d 15
$d=Update-WxState $S ([pscustomobject]@{planMode='';locSrc='windows(session)';err='weather fetch failed: timeout'}) $t0.AddMinutes(40)
Eq 'long outage -> neutral' $S.wx ''; Eq 'long outage sum' $S.sum ''; Eq 'retry backoff 30' $d 30
$d=Update-WxState $S $ok $t0.AddMinutes(41); Eq 'recovers' $S.wx 'rain'
# relocation fails later: reuse this session's fix (fresh weather), retry location with backoff
Eq 'known reusable' ((Get-KnownLocation $S $t0.AddMinutes(70)).lat) 30.08
$w=$ok.PSObject.Copy(); $w.planMode='wait'; $w.planReason='slow'; $w.locSrc='windows(session)'; $w.code=0; $w.rawCode=0; $w.precip=0
$d=Update-WxState $S $w $t0.AddMinutes(70); Eq 'wait+session uses fresh weather' $S.wx 'clear'; Eq 'wait+session retry 15' $d 15
Eq 'known expires after 6h' (Get-KnownLocation $S $t0.AddHours(8)) ''
# permission denied -> Spring only then
$S2=New-WxState
$fb=[pscustomobject]@{planMode='fallback';planReason='location permission denied';locSrc='fallback';lat=30.08;lon=-95.42;st='TX';unit='F';code=3;rawCode=3;precip=0;isDay=1;temp=60;pop=0;err=''}
$d=Update-WxState $S2 $fb $t0; Eq 'fallback cloudy' $S2.wx 'cloudy'; Eq 'fallback st' $S2.st 'TX'; Eq 'fallback re-checks permission' (Test-NeedLocate $S2 $t0.AddMinutes(15)) $true
Eq 'fallback logged' (($S2.log -join ' ') -like '*permission denied -> Spring, TX fallback*') $true
# denied then location becomes merely unavailable: neutral, never Spring
$d=Update-WxState $S2 ([pscustomobject]@{planMode='wait';planReason='x';locSrc='';err='no location yet'}) $t0.AddMinutes(15)
$d=Update-WxState $S2 ([pscustomobject]@{planMode='wait';planReason='x';locSrc='';err='no location yet'}) $t0.AddMinutes(46)
Eq 'unavailable after denied -> neutral' $S2.wx ''

# --- no IP geolocation / caches / manual location in shipped runtime code
foreach($f in 'watch_speak.ps1','geo.ps1','holiday.ps1','run_watch.ps1'){ $txt=Get-Content (Join-Path $root $f) -Raw
  foreach($bad in 'ipwho','bigdatacloud','ip-api','ipinfo','location_override','weather.json','location.json','StateFromLatLon'){ Eq "$f has no $bad" ($txt -like "*$bad*") $false } }

# --- dev-hook cycles (offline except Open-Meteo when -Live)
$r=Invoke-WeatherCycle $null $true 'unavailable' $sp; Eq 'cycle unavailable err' $r.err 'no location yet'; Eq 'cycle unavailable mode' $r.planMode 'wait'; Eq 'cycle unavailable no coords' "$($r.lat)" ''
if($Live){
  $r=Invoke-WeatherCycle $null $true 'denied' $sp; Eq 'live denied mode' $r.planMode 'fallback'; Eq 'live denied st' $r.st 'TX'; Eq 'live denied err' $r.err ''; Eq 'live denied has code' ($null -ne $r.code) $true
  Write-Host ("  live Spring fallback: code={0} precip={1} is_day={2} temp={3}{4} pop={5} -> {6} '{7}'" -f $r.code,$r.precip,$r.isDay,$r.temp,$r.unit,$r.pop,(WxMap $r.code),(WxSum $r.code $r.temp $r.pop $r.unit $r.isDay))
  $r=Invoke-WeatherCycle $null $true '47.61,-122.33' $sp; Eq 'live real mode' $r.planMode 'real'; Eq 'live real st' $r.st 'WA'; Eq 'live real unit' $r.unit 'F'; Eq 'live real err' $r.err ''
  $r=Invoke-WeatherCycle $null $true '48.86,2.35' $sp; Eq 'live Paris st' $r.st ''; Eq 'live Paris err' $r.err ''
  $r=Invoke-WeatherCycle @{lat=30.08;lon=-95.42} $false '' $sp; Eq 'live session src' $r.locSrc 'windows(session)'; Eq 'live session err' $r.err ''
}
Write-Host "$script:pass passed, $script:fail failed"
exit $script:fail
