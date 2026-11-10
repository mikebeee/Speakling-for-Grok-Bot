param([string]$Holiday='auto',[string]$State='',[string]$AsOf='',[switch]$NoHoliday,[string]$Costume='auto',[int]$GagMinMinutes=60,[int]$GagMaxMinutes=180,[switch]$NoGag,[switch]$GagNow,[int]$Seconds=0,[switch]$Forever,[double]$On=0.02,[int]$OffMs=900,[switch]$Dry,[string]$Talk=(Join-Path $PSScriptRoot 'assets\talkloop.bin'),[string]$Idle=(Join-Path $PSScriptRoot 'assets\idle.bin'),[string]$Log=(Join-Path $PSScriptRoot 'watch.log'),[string]$Lock=(Join-Path $PSScriptRoot 'buddy.lock'),[int]$RetryMs=15000,[string]$Bored=(Join-Path $PSScriptRoot 'assets\boredloop.bin'),[int]$BoredAfterSeconds=300,[int]$StampMinutes=5,[switch]$NoScene,[switch]$NoStamp,[switch]$NoTod,[switch]$NoWeather,[int]$LocateMinutes=60,[int]$WeatherMinutes=15,[string]$ForceTod='',[string]$ForceWx,[string]$ForceSum='',[string]$Dir=$PSScriptRoot,[string]$BtAddress='',[string]$DevLocation='')
# Seconds<=0 or -Forever = run indefinitely
# -DevLocation is a DEVELOPER TEST HOOK ONLY (not a user setting, not documented for users): 'denied',
#   'unavailable' or 'lat,lon' replaces the Windows Location answer so the decision paths can be tested.
$SpeaklingVersion='1.0.1'
$ErrorActionPreference='Stop'
$mtx=New-Object System.Threading.Mutex($false,'Local\MiniTooSpeakWatcher')
if(-not $mtx.WaitOne(0)){ Write-Output 'another watcher is running, exiting'; exit 3 }
function L($m){ $line=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+'  [watch] '+$m; Write-Output $line
  try{ if((Test-Path $Log) -and (Get-Item $Log).Length -gt 1MB){ Move-Item $Log ($Log+'.1') -Force }; Add-Content -Path $Log -Value $line } catch {} }
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public static class Bt {
 [StructLayout(LayoutKind.Sequential,Pack=1)] public struct SA { public ushort f; public ulong a; public Guid g; public uint p; }
 [DllImport("ws2_32.dll")] static extern int WSAStartup(ushort v, byte[] d);
 [DllImport("ws2_32.dll",SetLastError=true)] static extern IntPtr socket(int a,int t,int p);
 [DllImport("ws2_32.dll",SetLastError=true)] static extern int connect(IntPtr s, ref SA a, int l);
 [DllImport("ws2_32.dll",SetLastError=true)] static extern int send(IntPtr s, byte[] b,int l,int f);
 [DllImport("ws2_32.dll",SetLastError=true)] static extern int recv(IntPtr s, byte[] b,int l,int f);
 [DllImport("ws2_32.dll",SetLastError=true)] static extern int setsockopt(IntPtr s,int lv,int o,ref int v,int l);
 [DllImport("ws2_32.dll")] static extern int closesocket(IntPtr s);
 [DllImport("ws2_32.dll")] static extern int WSAGetLastError();
 static IntPtr s;
 public static void Open(ulong addr,uint ch){ WSAStartup(0x202,new byte[512]); s=socket(32,1,3); if(s==(IntPtr)(-1)) throw new Exception("socket err "+WSAGetLastError());
  SA a=new SA(); a.f=32; a.a=addr; a.g=Guid.Empty; a.p=ch; if(connect(s,ref a,30)!=0){ int e=WSAGetLastError(); closesocket(s); throw new Exception("connect err "+e); }
  int t=300; setsockopt(s,0xffff,0x1006,ref t,4); }
 public static void Send(byte[] b){ if(send(s,b,b.Length,0)!=b.Length) throw new Exception("send err "+WSAGetLastError()); }
 public static string Read(int ms){ var sb=new StringBuilder(); var buf=new byte[1024]; var end=DateTime.Now.AddMilliseconds(ms);
  while(DateTime.Now<end){ int n=recv(s,buf,buf.Length,0); if(n>0) for(int i=0;i<n;i++) sb.Append(buf[i].ToString("x2")); else if(n==0) break; } return sb.ToString(); }
 public static string ReadUntil(string pat,int ms){ var sb=new StringBuilder(); var buf=new byte[1024]; var end=DateTime.Now.AddMilliseconds(ms);
  while(DateTime.Now<end){ int n=recv(s,buf,buf.Length,0); if(n>0){ for(int i=0;i<n;i++) sb.Append(buf[i].ToString("x2")); if(sb.ToString().Contains(pat)) break; } else if(n==0) break; } return sb.ToString(); }
 public static void Close(){ closesocket(s); }
}
'@
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
interface IMMDeviceEnumerator { int NotImpl1(); [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow,int role,out IMMDevice ep); }
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("D666063F-1587-4E43-81F1-B948E807363F")]
interface IMMDevice { [PreserveSig] int Activate(ref Guid iid,int ctx,IntPtr p,[MarshalAs(UnmanagedType.IUnknown)] out object o); }
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")]
interface IAudioMeterInformation { [PreserveSig] int GetPeakValue(out float p); }
public static class Meter { static IAudioMeterInformation m;
 public static void Init(){ var e=(IMMDeviceEnumerator)new MMDeviceEnumerator(); IMMDevice d; Marshal.ThrowExceptionForHR(e.GetDefaultAudioEndpoint(0,1,out d)); Guid g=typeof(IAudioMeterInformation).GUID; object o; Marshal.ThrowExceptionForHR(d.Activate(ref g,23,IntPtr.Zero,out o)); m=(IAudioMeterInformation)o; }
 public static float Peak(){ float p; m.GetPeakValue(out p); return p; } }
'@
function Pk($b){ $raw=[IO.File]::ReadAllBytes($b); $o=@(); $i=0; while($i -lt $raw.Length){ $l=[BitConverter]::ToUInt16($raw,$i); $p=$raw[($i+2)..($i+1+$l)]; if($p[0] -ne 1 -or $p[-1] -ne 2){throw 'bad frame'}; $o+=,([byte[]]$p); $i+=2+$l }; if($o.Count -lt 2){throw "bad packet count $b"}; ,$o }
function SendAnim($pk,$name){
  [Bt]::Send($pk[0]); $r=[Bt]::ReadUntil('8b550001ec',4000); if($r -notmatch '8b550001ec'){ throw "$name no request: $r" }
  for($j=1;$j -lt $pk.Count;$j++){ [Bt]::Send($pk[$j]); Start-Sleep -Milliseconds 15 }
  $r=[Bt]::ReadUntil('bd551301',5000); if($r -notmatch 'bd551301'){ throw "$name no final ack: $r" }; L "$name shown" }
function LockOn(){ if(-not (Test-Path $Lock)){ return $false }; try{ return ((Get-Date)-(Get-Item $Lock).LastWriteTime).TotalMinutes -lt 15 } catch { return $false } }
$sw=[Diagnostics.Stopwatch]::StartNew()
$talkPk=Pk $Talk; $idlePk=Pk $Idle; $boredPk=$null; if(Test-Path $Bored){ $boredPk=Pk $Bored }
[Meter]::Init(); $meterAt=0
$scene=$false; $sceneCache=@{}; $shownKey=''; $wx=''; $wxJob=$null; $wxJobAt=0; $wxNext=0; $wxSum=''; $usState=''; $gagRaw=$null; $gagAt=-1; $gagUntil=0; $gagNowPending=[bool]$GagNow
if(-not $NoScene){ try{ Add-Type -Path (Join-Path $Dir 'scene.cs'); $zv=[Scene]::Init((Join-Path $Dir 'libzstd.dll')); $idleRaw=[IO.File]::ReadAllBytes((Join-Path $Dir 'assets\idle_raw.bin')); $boredRaw=[IO.File]::ReadAllBytes((Join-Path $Dir 'assets\bored_raw.bin')); $talkRaw=[IO.File]::ReadAllBytes((Join-Path $Dir 'assets\talk_raw.bin')); $gp=Join-Path $Dir 'assets\gag_raw.bin'; if(-not $NoGag -and (Test-Path $gp)){ $gagRaw=[IO.File]::ReadAllBytes($gp) }; $scene=$true; L "scene on (zstd $zv) stamp=$(-not $NoStamp)/$StampMinutes min tod=$(-not $NoTod) weather=$(-not $NoWeather)" } catch { L ('scene unavailable, using static clips: '+$_.Exception.Message) } }
. (Join-Path $PSScriptRoot 'geo.ps1'); $wxS=New-WxState
# Weather: location from Windows Location only, a fresh Open-Meteo reading on every launch (nothing is
# loaded from disk), neutral sky until the first reading and whenever readings go stale.
function WxPoll($now){
  if($NoWeather -or -not $scene){ return }
  $t=Get-Date
  if($wxJob -and $wxJob.State -eq 'Running' -and ($now-$script:wxJobAt) -gt 180000){ L 'weather job hung > 3 min, stopping it'; Stop-Job $wxJob -ErrorAction SilentlyContinue }
  if($wxJob -and $wxJob.State -ne 'Running'){
    $r=$null; try{ $r=Receive-Job $wxJob -ErrorAction Stop | Select-Object -Last 1 } catch { $r=[pscustomobject]@{planMode='';err=('weather job error: '+$_.Exception.Message)} }
    Remove-Job $wxJob -Force; $script:wxJob=$null
    $d=Update-WxState $script:wxS $r $t $WeatherMinutes ([Math]::Max(30,2*$WeatherMinutes))
    foreach($m in $script:wxS.log){ L $m }; $script:wxS.log.Clear()
    $script:wx=$script:wxS.wx; $script:wxSum=$script:wxS.sum; $script:usState=$script:wxS.st
    $script:wxNext=$now+[int64]$d*1000 }
  if($script:wxS.at -and ($t-$script:wxS.at).TotalMinutes -gt [Math]::Max(30,2*$WeatherMinutes)){ Clear-WxReading $script:wxS 'last reading too old'; foreach($m in $script:wxS.log){ L $m }; $script:wxS.log.Clear(); $script:wx=''; $script:wxSum='' }
  if(-not $wxJob -and $now -ge $script:wxNext){
    $loc=Test-NeedLocate $script:wxS $t $LocateMinutes; $known=Get-KnownLocation $script:wxS $t
    $script:wxJob=Start-Job -ArgumentList (Join-Path $Dir 'geo.ps1'),(Join-Path $Dir 'assets\us_states.txt'),$known,$loc,$DevLocation -ScriptBlock { param($geo,$states,$known,$locate,$dev)
      $ErrorActionPreference='Stop'; . $geo; Invoke-WeatherCycle $known $locate $dev $states }
    $script:wxJobAt=$now; $script:wxNext=[int64]::MaxValue } }
function SceneKey($state){ $d=Get-Date
  $tod=''; if(-not $NoTod){ $h=$d.Hour; $tod= if($h -ge 5 -and $h -lt 11){'morning'} elseif($h -lt 17 -and $h -ge 11){'day'} elseif($h -ge 17 -and $h -lt 20){'evening'} else {'night'}; if($script:wxS -and $null -ne $script:wxS.isDay -and "$($script:wxS.isDay)" -ne ''){ if([int]$script:wxS.isDay -eq 0){ $tod='night' } elseif($tod -eq 'night'){ $tod='evening' } }; if($ForceTod){$tod=$ForceTod} }
  $w=''; if(-not $NoWeather){ $w=$script:wx; if($ForceWx){$w=$ForceWx} }
  $l1=''; $l2=''; if(-not $NoStamp -and $w -and $script:wxSum){ $s=$script:wxSum.Split('~'); $l1=$s[0]; $l2=$s[1] }; if($ForceSum){ $s=$ForceSum.Split('~'); $l1=$s[0]; $l2=$s[1] }
  $ck=''; if(-not $NoStamp){ $ck=$d.ToString('h:mm tt',[Globalization.CultureInfo]::InvariantCulture) }
  $cos=ThemeNow $d
  "$state|$tod|$w|$l1|$l2|$ck|$cos" }
. (Join-Path $PSScriptRoot 'holiday.ps1')
. (Join-Path $PSScriptRoot 'btaddr.ps1')
function ThemeNow($d){ if($NoHoliday){ return '' }; $ov=$Holiday; if($ov -eq 'auto'){ if($Costume -eq 'on'){ $ov='halloween' } elseif($Costume -eq 'off'){ $ov='none' } }; $dd=$d; if($AsOf){ $dd=[datetime]$AsOf }; $st=$script:usState; if($script:State){ $st=$script:State }; $r=ThemeFor $dd $ov $st; return $r[0] }
function GetPk($state,$mark=$true){ if(-not $scene){ if($state -eq 'bored'){ return ,$boredPk } elseif($state -eq 'talk'){ return ,$talkPk } else { return ,$idlePk } }
  $k=SceneKey $state; if($state -ne 'talk'){ $tk=SceneKey 'talk'; if(-not $sceneCache.ContainsKey($tk)){ $null=GetPk 'talk' $false } }
  if($sceneCache.ContainsKey($k)){ if($mark){ $script:shownKey=$k }; return ,$sceneCache[$k] }
  $p=$k.Split('|'); if($state -eq 'bored'){ $raw=$boredRaw; $nf=47; $sp=150 } elseif($state -eq 'talk'){ $raw=$talkRaw; $nf=40; $sp=100 } elseif($state -eq 'gag'){ $raw=$gagRaw; $nf=[int]($gagRaw.Length/49152); $sp=200 } else { $raw=$idleRaw; $nf=58; $sp=125 }
  [Scene]::NoBirds=($state -eq 'gag') -or ($gagRaw -and $gagAt -ge 0 -and ($sw.ElapsedMilliseconds+120000) -ge $gagAt); [Scene]::Clock=$p[5]; [Scene]::Holiday=$p[6]; if($p[6] -like 'st-*'){ $sc=$p[6].Substring(3); $e=$StateHol[$sc]; if($StateHol2.ContainsKey($sc) -and ((ThemeFor $(if($AsOf){[datetime]$AsOf}else{Get-Date}) 'auto' $sc)[1] -eq ($StateHol2[$sc].Split('|')[1]))){ $e=$StateHol2[$sc] }; if($e){ [Scene]::StateCol=$e.Split('|')[2] } }; $budget= if($state -eq 'talk'){7000}elseif($state -eq 'idle' -and $p[6] -eq 'christmas' -and $p[2] -eq 'cloudy'){13000}else{13500}; foreach($cf in @(@('drift2',2,$false,$false,14),@('drift4',4,$false,$false,14),@('still-sky',1,$true,$false,14),@('still-lite',1,$true,$false,4),@('half-drift4',4,$false,$true,10),@('half-still',1,$true,$true,8),@('half-still-lite',1,$true,$true,3),@('half-still-soft',1,$true,$true,2),@('half-still-dry',1,$true,$true,0),@('half-still-plain',1,$true,$true,-1),@('half-still-calm',1,$true,$true,-2))){ $fit=$cf[0]; [Scene]::DriftStep=$cf[1]; [Scene]::NoMotion=$cf[2]; [Scene]::RainDrops=$cf[4]; $m=$nf; $sq=$sp; $rr=$raw; if($cf[3]){ $m=[int][Math]::Floor(($nf+1)/2); $sq=$sp*2; $rr=[Scene]::Decimate($raw,$nf) }; $c=[Scene]::Compose($rr,$m,$p[1],$p[2],$p[3],$p[4]); $pk=[Scene]::Packets($c,$m,$sq); if([Scene]::LastPayload -le $budget){ break } }
  [Scene]::NoMotion=$false; [Scene]::DriftStep=2; [Scene]::RainDrops=14; $l=New-Object 'System.Collections.Generic.List[byte[]]'; foreach($q in $pk){$l.Add($q)}; $arr=$l.ToArray()
  if($sceneCache.Count -gt 30){ $sceneCache.Clear() }; $sceneCache[$k]=$arr; if($mark){ $script:shownKey=$k }; L ("scene $k payload="+[Scene]::LastPayload+" fit="+$fit) | Out-Null; return ,$arr }
$indef = $Forever -or ($Seconds -le 0); $end=[int64]$Seconds*1000
L ("Speakling v$SpeaklingVersion start pid=$PID indefinite=$indef dry=$Dry talk pk="+$talkPk.Count+" idle pk="+$idlePk.Count+" bored pk="+$(if($boredPk){$boredPk.Count}else{0})+" boredAfter=$BoredAfterSeconds"+" peak="+[Meter]::Peak())
$conn=$false; $nextTry=0; $lastErr=''; $lastErrAt=-1000000; $paused=$false
$talking=$false; $lastLoud=0; $loudSince=-1; $isBored=$false; $idleAt=0
try{
 while($indef -or $sw.ElapsedMilliseconds -lt $end){
  $now=$sw.ElapsedMilliseconds
  if(LockOn){
    if(-not $paused){ $paused=$true; if($conn){ [Bt]::Close(); $conn=$false }; $talking=$false; $isBored=$false; L 'buddy.lock present: released Bluetooth, paused' }
    Start-Sleep -Milliseconds 300; continue }
  if($paused){ $paused=$false; $nextTry=$now+1500; L 'buddy.lock gone: resuming' }
  WxPoll $now
  if($now-$meterAt -gt 30000){ try{ [Meter]::Init() } catch { L ('meter init failed: '+$_.Exception.Message) }; $meterAt=$now }
  if(-not $Dry -and -not $conn){
    if($now -ge $nextTry){
      try{ [Bt]::Open((Resolve-MiniTooAddress $BtAddress $Dir),1); Start-Sleep -Milliseconds 600; $conn=$true; L 'connected to MiniToo'; $lastErr=''
           SendAnim (GetPk 'idle') 'idle(restore)'; $talking=$false; $isBored=$false; $gagUntil=0; $idleAt=$sw.ElapsedMilliseconds }
      catch { $msg=$_.Exception.Message; if($conn){ [Bt]::Close(); $conn=$false }
           if($msg -ne $lastErr -or ($now-$lastErrAt) -gt 600000){ L ("MiniToo not reachable ($msg); retrying every "+($RetryMs/1000)+' s (off, out of range, or held by phone)'); $lastErr=$msg; $lastErrAt=$now }
           $nextTry=$sw.ElapsedMilliseconds+$RetryMs }
    }
    Start-Sleep -Milliseconds 200; continue }
  $pv=0; try{ $pv=[Meter]::Peak() } catch { $meterAt=0 }
  if($pv -gt $On){ $lastLoud=$now; if($loudSince -lt 0){$loudSince=$now} } else { $loudSince=-1 }
  if($gagRaw -and $scene -and $gagAt -lt 0){ if($gagNowPending){ $gagAt=$now+5000; $gagNowPending=$false } else { $gagAt=$now+(Get-Random -Minimum ([int64]$GagMinMinutes*60000) -Maximum ([int64]$GagMaxMinutes*60000+1)) }; L ('next gag in '+[int](($gagAt-$now)/60000)+' min') }
  try{
   if(-not $talking -and $loudSince -ge 0 -and ($now-$loudSince) -ge 150){ $talking=$true; $isBored=$false; if($gagUntil -gt 0){ $gagUntil=0; $gagAt=-1; L 'gag interrupted by sound' }; if($Dry){L 'would show talk'} else { $lat0=$now-$loudSince; $tp=GetPk 'talk' $false; SendAnim $tp 'talk'; L ('talk latency: onset->ack '+($sw.ElapsedMilliseconds-$loudSince)+' ms (detect '+$lat0+' ms, clip '+$(if($scene){SceneKey 'talk'}else{'static'})+')') } }
   elseif($talking -and ($now-$lastLoud) -ge $OffMs){ $talking=$false; if($Dry){L 'would show idle'} else {SendAnim (GetPk 'idle') 'idle'}; $idleAt=$sw.ElapsedMilliseconds }
   elseif($gagUntil -gt 0){ if($now -ge $gagUntil){ $gagUntil=0; $gagAt=-1; $st= if($isBored){'bored'} else {'idle'}; if($Dry){L 'would end gag'} else { SendAnim (GetPk $st) ($st+'(after gag)') } } }
   elseif($gagRaw -and $scene -and $gagAt -ge 0 -and $now -ge $gagAt -and -not $talking -and $loudSince -lt 0 -and ($now-$lastLoud) -ge 3000){ if($Dry){ L 'would show gag'; $gagAt=-1 } else { SendAnim (GetPk 'gag' $false) 'gag'; L ('gag shown (clip '+(SceneKey 'gag')+')'); $gagUntil=$sw.ElapsedMilliseconds+[int]($gagRaw.Length/49152)*200+400 } }
   elseif(-not $talking -and -not $isBored -and $boredPk -and $loudSince -lt 0 -and ($now-$idleAt) -ge ($BoredAfterSeconds*1000) -and ($now-$lastLoud) -ge ($BoredAfterSeconds*1000)){ $isBored=$true; if($Dry){L 'would show bored'} else {SendAnim (GetPk 'bored') 'bored'} }
   elseif($scene -and -not $talking -and $loudSince -lt 0 -and ($now-$lastLoud) -ge 3000){ $st= if($isBored){'bored'} else {'idle'}; if((SceneKey $st) -ne $shownKey){ if($Dry){ L ('would refresh '+(SceneKey $st)); $shownKey=(SceneKey $st) } else { SendAnim (GetPk $st) ($st+'(refresh)') } } }
  } catch { L ('send failed: '+$_.Exception.Message+' - reconnecting'); try{[Bt]::Close()}catch{}; $conn=$false; $talking=$false; $isBored=$false; $nextTry=$sw.ElapsedMilliseconds+2000 }
  Start-Sleep -Milliseconds 40 }
} finally {
  if($conn){ if($talking -or $isBored){ try{ SendAnim (GetPk 'idle') 'idle' } catch {} }; [Bt]::Close() }
  if($wxJob){ Remove-Job $wxJob -Force -ErrorAction SilentlyContinue }; L 'watcher exiting'; $mtx.ReleaseMutex() }
