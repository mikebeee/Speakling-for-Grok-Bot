param([Parameter(Mandatory=$true)][string]$Job,[string]$Idle=(Join-Path $PSScriptRoot 'assets\idle.bin'),[switch]$Dry,[string]$BtAddress='')
$ErrorActionPreference='Stop'
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
  SA a=new SA(); a.f=32; a.a=addr; a.g=Guid.Empty; a.p=ch; if(connect(s,ref a,30)!=0) throw new Exception("connect err "+WSAGetLastError());
  int t=300; setsockopt(s,0xffff,0x1006,ref t,4); }
 public static void Send(byte[] b){ if(send(s,b,b.Length,0)!=b.Length) throw new Exception("send err "+WSAGetLastError()); }
 public static string Read(int ms){ var sb=new StringBuilder(); var buf=new byte[1024]; var end=DateTime.Now.AddMilliseconds(ms);
  while(DateTime.Now<end){ int n=recv(s,buf,buf.Length,0); if(n>0) for(int i=0;i<n;i++) sb.Append(buf[i].ToString("x2")); else if(n==0) break; } return sb.ToString(); }
 public static string ReadUntil(string pat,int ms){ var sb=new StringBuilder(); var buf=new byte[1024]; var end=DateTime.Now.AddMilliseconds(ms);
  while(DateTime.Now<end){ int n=recv(s,buf,buf.Length,0); if(n>0){ for(int i=0;i<n;i++) sb.Append(buf[i].ToString("x2")); if(sb.ToString().Contains(pat)) break; } else if(n==0) break; } return sb.ToString(); }
 public static void Close(){ closesocket(s); }
}
'@
Add-Type -AssemblyName PresentationCore
. (Join-Path $PSScriptRoot 'btaddr.ps1')
$addr=Resolve-MiniTooAddress $BtAddress $PSScriptRoot
function Pk($b){ $raw=[IO.File]::ReadAllBytes($b); $o=@(); $i=0; while($i -lt $raw.Length){ $l=[BitConverter]::ToUInt16($raw,$i); $p=$raw[($i+2)..($i+1+$l)]; if($p[0] -ne 1 -or $p[-1] -ne 2){throw 'bad frame'}; $o+=,([byte[]]$p); $i+=2+$l }; if($o.Count -lt 2){throw "bad packet count $b"}; ,$o }
$sw=[Diagnostics.Stopwatch]::StartNew()
function T($m){ Write-Output ('{0,6} ms  {1}' -f $sw.ElapsedMilliseconds,$m) }
function SendAnim($pk,$name){
  T "$name start"; [Bt]::Send($pk[0])
  $r=[Bt]::ReadUntil('8b550001ec',4000); if($r -notmatch '8b550001ec'){ throw "$name no request: $r" }
  for($j=1;$j -lt $pk.Count;$j++){ [Bt]::Send($pk[$j]); Start-Sleep -Milliseconds 15 }
  $r=[Bt]::ReadUntil('bd551301',5000); if($r -notmatch 'bd551301'){ throw "$name no final ack: $r" }; T "$name final ack" }
function PlayWait($mp3){
  $pl=New-Object System.Windows.Media.MediaPlayer; $pl.Open([Uri]$mp3); $pl.Volume=1
  $t=0; while(-not $pl.NaturalDuration.HasTimeSpan -and $t -lt 50){ Start-Sleep -Milliseconds 100; $t++ }
  $dur= if($pl.NaturalDuration.HasTimeSpan){[int]$pl.NaturalDuration.TimeSpan.TotalMilliseconds}else{5000}
  $pl.Play(); T "play $mp3 dur=$dur"; Start-Sleep -Milliseconds $dur; $pl.Stop(); $pl.Close() }
$dir=Join-Path $PSScriptRoot 'job'
if(Test-Path $dir){ Remove-Item $dir -Recurse -Force }
Expand-Archive -Path $Job -DestinationPath $dir -Force
$steps=@(Get-Content (Join-Path $dir 'job.txt') | Where-Object { $_ } | ForEach-Object { $f=$_.Split('|'); [pscustomobject]@{Kind=$f[0];Pk=(Pk (Join-Path $dir $f[1]));Mp3=(Join-Path $dir $f[2])} })
$idlePk=Pk $Idle
$restore = ($steps.Count -eq 0) -or ($steps[-1].Kind -eq 'talk')
foreach($s in $steps){ T ($s.Kind+' pk='+$s.Pk.Count+' '+$s.Mp3); if(-not (Test-Path $s.Mp3)){ throw 'missing mp3' } }
T ('idle pk='+$idlePk.Count+' restoreIdleAtEnd='+$restore)
if($Dry){ T 'dry run ok'; exit 0 }
$lock=Join-Path $PSScriptRoot 'buddy.lock'; Set-Content -Path $lock -Value $PID; Start-Sleep -Milliseconds 1500
try{
$done=$false; [Bt]::Open($addr,1); Start-Sleep -Milliseconds 600; T 'connected'
try{
  $k=0; foreach($s in $steps){ $k++; SendAnim $s.Pk ($s.Kind+$k); PlayWait $s.Mp3 }
  if($restore){ SendAnim $idlePk 'idle' }
  $done=$true
} finally { [Bt]::Close()
  if(-not $done){ T 'error: restoring idle on fresh connection'; Start-Sleep -Milliseconds 1500
    [Bt]::Open($addr,1); Start-Sleep -Milliseconds 600; try{ SendAnim $idlePk 'idle-restore' } finally { [Bt]::Close() } } }
} finally { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
