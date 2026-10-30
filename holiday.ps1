# date -> theme name ('' = none). Ranges inclusive; overlap: nearest holiday day wins, tie -> list order.
function EasterSunday([int]$y){ $a=$y%19; $b=[Math]::Floor($y/100); $c=$y%100; $e=[Math]::Floor($b/4); $f=$b%4; $g=[Math]::Floor(($b+8)/25); $h=(19*$a+$b-$e-[Math]::Floor(($b-$g+1)/3)+15)%30; $i=[Math]::Floor($c/4); $k=$c%4; $l=(32+2*$f+2*$i-$h-$k)%7; $m=[Math]::Floor(($a+11*$h+22*$l)/451); $mo=[Math]::Floor(($h+$l-7*$m+114)/31); $da=(($h+$l-7*$m+114)%31)+1; return (New-Object DateTime $y,$mo,$da) }
function Thanksgiving([int]$y){ $n1=New-Object DateTime $y,11,1; return $n1.AddDays(((4-[int]$n1.DayOfWeek)+7)%7+21) }
function HolidayThemes([int]$y){ $D={ param($m,$d) New-Object DateTime $y,$m,$d }
  $e=EasterSunday $y; $t=Thanksgiving $y
  @( @('halloween',(& $D 10 18),(& $D 10 31),(& $D 10 31)),
     @('thanksgiving',$t.AddDays(-5),$t,$t),
     @('christmas',(& $D 11 28),(& $D 12 26),(& $D 12 25)),
     @('newyear',(& $D 12 27),(New-Object DateTime ($y+1),1,2),(New-Object DateTime ($y+1),1,1)),
     @('newyear',(New-Object DateTime ($y-1),12,27),(& $D 1 2),(& $D 1 1)),
     @('valentine',(& $D 2 7),(& $D 2 14),(& $D 2 14)),
     @('stpatricks',(& $D 3 10),(& $D 3 17),(& $D 3 17)),
     @('easter',$e.AddDays(-7),$e,$e),
     @('july4',(& $D 6 28),(& $D 7 4),(& $D 7 4)) ) }
function HolidayFor([datetime]$d,[string]$override='auto'){ if($override -and $override -ne 'auto'){ if($override -eq 'none'){ return '' }; return $override.ToLower() }
  $d=$d.Date; $best=''; $bd=999
  foreach($h in (HolidayThemes $d.Year)){ if($d -ge $h[1] -and $d -le $h[2]){ $dist=[Math]::Abs(($h[3]-$d).Days); if($dist -lt $bd){ $bd=$dist; $best=$h[0] } } }
  return $best }
# ---- US state observances: code = rule|name|colors(r,g,b,r,g,b). rule: M-D fixed, N:month:dow:n (n=-1 last), E:offset (Easter)
$StateHol=@{
 AL='12-14|Alabama Statehood Day|180,40,50,240,240,245'; AK='N:3:1:-1|Seward''s Day|40,70,150,240,200,80'; AZ='2-14|Arizona Statehood Day|190,70,50,240,190,80'; AR='6-15|Arkansas Admission Day|190,50,60,60,80,160'
 CA='3-31|Cesar Chavez Day|180,60,50,240,230,200'; CO='8-1|Colorado Day|60,80,160,240,200,60'; CT='1-9|Connecticut Statehood Day|50,70,150,240,240,245'; DE='12-7|Delaware Day|90,140,200,240,210,140'
 FL='4-2|Pascua Florida Day|200,60,60,245,240,235'; GA='1-2|Georgia Statehood Day|190,50,60,60,80,160'; HI='6-11|Kamehameha Day|240,200,80,200,60,70'; ID='7-3|Idaho Admission Day|50,70,150,240,200,80'
 IL='N:3:1:1|Casimir Pulaski Day|240,240,245,200,60,70'; IN='12-11|Indiana Statehood Day|50,70,150,240,200,80'; IA='12-28|Iowa Statehood Day|60,80,160,200,60,70'; KS='1-29|Kansas Day|50,70,150,240,200,80'
 KY='6-1|Kentucky Statehood Day|50,70,150,240,200,80'; LA='E:-47|Mardi Gras|130,70,170,240,200,80'; ME='N:4:1:3|Patriots'' Day|50,70,150,240,200,80'; MD='3-25|Maryland Day|240,200,60,40,40,40'
 MA='N:4:1:3|Patriots'' Day|50,70,150,240,240,245'; MI='1-26|Michigan Statehood Day|50,70,150,240,200,80'; MN='5-11|Minnesota Statehood Day|50,70,150,240,200,80'; MS='12-10|Mississippi Statehood Day|60,80,160,200,60,70'
 MO='8-10|Missouri Day|200,60,70,60,80,160'; MT='11-8|Montana Statehood Day|50,70,150,240,200,80'; NE='N:4:5:-1|Arbor Day|80,150,80,240,220,160'; NV='N:10:5:-1|Nevada Day|50,70,150,240,200,80'
 NH='6-21|New Hampshire Statehood Day|50,70,150,240,200,80'; NJ='12-18|New Jersey Statehood Day|230,200,140,70,120,180'; NM='1-6|New Mexico Statehood Day|245,210,60,200,50,50'; NY='7-26|New York Statehood Day|50,70,150,240,200,80'
 NC='4-12|Halifax Day|200,60,70,60,80,160'; ND='11-2|North Dakota Statehood Day|50,70,150,240,200,80'; OH='3-1|Ohio Statehood Day|200,60,70,60,80,160'; OK='11-16|Oklahoma Statehood Day|90,150,210,240,240,245'
 OR='2-14|Oregon Statehood Day|40,60,120,240,200,80'; PA='12-12|Pennsylvania Statehood Day|50,70,150,240,200,80'; RI='5-4|Rhode Island Independence Day|240,200,80,60,80,160'; SC='5-23|South Carolina Statehood Day|40,60,120,240,240,245'
 SD='11-2|South Dakota Statehood Day|90,150,210,240,200,80'; TN='6-1|Tennessee Statehood Day|200,60,70,60,80,160'; TX='3-2|Texas Independence Day|60,80,160,190,60,65'; UT='7-24|Pioneer Day|60,80,160,240,200,80'
 VT='8-16|Bennington Battle Day|40,100,70,240,200,80'; VA='6-25|Virginia Statehood Day|50,70,150,240,240,245'; WA='11-11|Washington Admission Day|60,120,80,240,200,80'; WV='6-20|West Virginia Day|50,70,150,240,200,80'
 WI='5-29|Wisconsin Statehood Day|50,70,150,240,200,80'; WY='12-10|Wyoming Day|60,80,160,200,60,70'
}
$StateHol2=@{ TX='6-19|Juneteenth|60,80,160,190,60,65' }
function RuleDate([string]$rule,[int]$y){ if($rule -like 'E:*'){ return (EasterSunday $y).AddDays([int]$rule.Substring(2)) }
  if($rule -like 'N:*'){ $p=$rule.Split(':'); $m=[int]$p[1]; $dw=[int]$p[2]; $n=[int]$p[3]; if($n -gt 0){ $d1=New-Object DateTime $y,$m,1; return $d1.AddDays((($dw-[int]$d1.DayOfWeek)+7)%7+7*($n-1)) } else { $dl=(New-Object DateTime $y,$m,1).AddMonths(1).AddDays(-1); return $dl.AddDays(-((([int]$dl.DayOfWeek)-$dw+7)%7)) } }
  $p=$rule.Split('-'); return (New-Object DateTime $y,([int]$p[0]),([int]$p[1])) }
function StateHolidayFor([datetime]$d,[string]$st){ if(-not $st){ return '' }; $st=$st.ToUpper(); $d=$d.Date
  foreach($tb in $StateHol,$StateHol2){ if($tb.ContainsKey($st)){ $e=$tb[$st].Split('|'); foreach($yy in ($d.Year),($d.Year+1)){ $hd=RuleDate $e[0] $yy; if($d -ge $hd.AddDays(-3) -and $d -le $hd){ return @("st-$st",$e[1],$e[2]) } } } }
  return '' }
function ThemeFor([datetime]$d,[string]$override='auto',[string]$st=''){ $n=HolidayFor $d $override; if($n -or ($override -and $override -ne 'auto')){ return @($n,'','') }; $s=StateHolidayFor $d $st; if($s){ return $s }; return @('','','') }
# rough state bounding boxes (S,W,N,E); point in several -> nearest box centre
$StateBox=@{AL='30.1,-88.5,35.0,-84.9';AK='51.2,-180,71.4,-129.9';AZ='31.3,-114.8,37.0,-109.0';AR='33.0,-94.6,36.5,-89.6';CA='32.5,-124.4,42.0,-114.1';CO='37.0,-109.1,41.0,-102.0';CT='40.9,-73.7,42.1,-71.8';DE='38.4,-75.8,39.8,-75.0';FL='24.5,-87.6,31.0,-80.0';GA='30.4,-85.6,35.0,-80.8';HI='18.9,-160.3,22.3,-154.8';ID='42.0,-117.2,49.0,-111.0';IL='37.0,-91.5,42.5,-87.5';IN='37.8,-88.1,41.8,-84.8';IA='40.4,-96.6,43.5,-90.1';KS='37.0,-102.1,40.0,-94.6';KY='36.5,-89.6,39.1,-82.0';LA='29.0,-94.0,33.0,-89.0';ME='43.1,-71.1,47.5,-66.9';MD='37.9,-79.5,39.7,-75.0';MA='41.2,-73.5,42.9,-69.9';MI='41.7,-90.4,48.3,-82.4';MN='43.5,-97.2,49.4,-89.5';MS='30.2,-91.7,35.0,-88.1';MO='36.0,-95.8,40.6,-89.1';MT='44.4,-116.1,49.0,-104.0';NE='40.0,-104.1,43.0,-95.3';NV='35.0,-120.0,42.0,-114.0';NH='42.7,-72.6,45.3,-70.6';NJ='38.9,-75.6,41.4,-73.9';NM='31.3,-109.1,37.0,-103.0';NY='40.5,-79.8,45.0,-71.9';NC='33.8,-84.3,36.6,-75.5';ND='45.9,-104.1,49.0,-96.6';OH='38.4,-84.8,42.0,-80.5';OK='33.6,-103.0,37.0,-94.4';OR='42.0,-124.6,46.3,-116.5';PA='39.7,-80.5,42.3,-74.7';RI='41.1,-71.9,42.0,-71.1';SC='32.0,-83.4,35.2,-78.5';SD='42.5,-104.1,45.9,-96.4';TN='35.0,-90.3,36.7,-81.6';TX='25.8,-106.6,36.5,-93.5';UT='37.0,-114.1,42.0,-109.0';VT='42.7,-73.4,45.0,-71.5';VA='36.5,-83.7,39.5,-75.2';WA='45.5,-124.8,49.0,-116.9';WV='37.2,-82.6,40.6,-77.7';WI='42.5,-92.9,47.1,-86.8';WY='41.0,-111.1,45.0,-104.0'}
function StateFromLatLon([double]$lat,[double]$lon){ $best=''; $bd=1e9; foreach($k in $StateBox.Keys){ $b=$StateBox[$k].Split(',') | % {[double]$_}; if($lat -ge $b[0] -and $lat -le $b[2] -and $lon -ge $b[1] -and $lon -le $b[3]){ $cy=($b[0]+$b[2])/2; $cx=($b[1]+$b[3])/2; $dd=[Math]::Pow($lat-$cy,2)+[Math]::Pow(($lon-$cx)*[Math]::Cos($lat*0.01745),2); if($dd -lt $bd){ $bd=$dd; $best=$k } } }; return $best }
