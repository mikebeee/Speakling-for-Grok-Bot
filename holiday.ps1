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
