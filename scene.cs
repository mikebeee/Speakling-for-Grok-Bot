using System; using System.Collections.Generic; using System.IO; using System.Runtime.InteropServices;
public static class Scene {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern IntPtr LoadLibraryW(string p);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern IntPtr ZSTD_createCCtx();
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern UIntPtr ZSTD_freeCCtx(IntPtr c);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern UIntPtr ZSTD_CCtx_setParameter(IntPtr c,int p,int v);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern UIntPtr ZSTD_compress2(IntPtr c,byte[] d,UIntPtr dc,byte[] s,UIntPtr sz);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern UIntPtr ZSTD_compressBound(UIntPtr s);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern uint ZSTD_isError(UIntPtr r);
 [DllImport("libzstd.dll",CallingConvention=CallingConvention.Cdecl)] static extern uint ZSTD_versionNumber();
 public static uint Init(string dll){ if(LoadLibraryW(dll)==IntPtr.Zero) throw new Exception("LoadLibrary failed "+Marshal.GetLastWin32Error()); return ZSTD_versionNumber(); }
 public static byte[] Zstd(byte[] src,int level,int wlog){ IntPtr c=ZSTD_createCCtx(); try{ ZSTD_CCtx_setParameter(c,100,level); ZSTD_CCtx_setParameter(c,101,wlog);
   var dst=new byte[(int)ZSTD_compressBound((UIntPtr)src.Length)]; var r=ZSTD_compress2(c,dst,(UIntPtr)dst.Length,src,(UIntPtr)src.Length);
   if(ZSTD_isError(r)!=0) throw new Exception("zstd error"); var o=new byte[(int)r]; Array.Copy(dst,o,o.Length); return o; } finally { ZSTD_freeCCtx(c); } }
 static byte[] Frame(byte[] body){ var o=new byte[7+body.Length]; o[0]=1; int dl=o.Length-4; o[1]=(byte)dl; o[2]=(byte)(dl>>8); o[3]=0x8b; Array.Copy(body,0,o,4,body.Length);
   int s=0; for(int i=1;i<o.Length-3;i++) s+=o[i]; o[o.Length-3]=(byte)s; o[o.Length-2]=(byte)(s>>8); o[o.Length-1]=2; return o; }
 public static List<byte[]> Packets(byte[] raw,int n,int speed){ var z=Zstd(raw,17,17); var p=new byte[10+z.Length];
   p[0]=0x25; p[1]=(byte)n; p[2]=(byte)(speed>>8); p[3]=(byte)speed; p[4]=8; p[5]=8; p[6]=(byte)(z.Length>>24); p[7]=(byte)(z.Length>>16); p[8]=(byte)(z.Length>>8); p[9]=(byte)z.Length; Array.Copy(z,0,p,10,z.Length);
   var L=new List<byte[]>(); int T=p.Length; L.Add(Frame(new byte[]{0,(byte)T,(byte)(T>>8),(byte)(T>>16),(byte)(T>>24)}));
   for(int seq=0,off=0;off<T;seq++,off+=256){ int cl=Math.Min(256,T-off); var b=new byte[7+cl]; b[0]=1; b[1]=(byte)T;b[2]=(byte)(T>>8);b[3]=(byte)(T>>16);b[4]=(byte)(T>>24); b[5]=(byte)seq; b[6]=(byte)(seq>>8); Array.Copy(p,off,b,7,cl); L.Add(Frame(b)); }
   LastPayload=T; return L; }
 public static int LastPayload; public static int RainDrops=14; public static bool NoMotion=false; public static bool NoBirds=false; public static int DriftStep=2; public static string Holiday=""; static int RealF=0; public static string StateCol="60,80,160,240,200,90"; public static bool Costume{ set{ Holiday=value?"halloween":""; } get{ return Holiday=="halloween"; } }
 static void Pumpkin(int x0,int y0,int f){ for(int y=0;y<14;y++) for(int x=0;x<18;x++){ double dx=(x-8.5)/9.0, dy=(y-7.5)/7.0; if(dx*dx+dy*dy<=1){ bool rib=(x==5||x==12); Px(x0+x,y0+y+2, rib?200:225, rib?110:130, rib?50:60); } }
  for(int y=0;y<3;y++){ Px(x0+8,y0+y,110,150,80); Px(x0+9,y0+y,110,150,80); }
  bool hi=((f/8)%2)==0; int gr=hi?255:240, gg=hi?215:190, gb=hi?120:100;
  Px(x0+5,y0+7,gr,gg,gb); Px(x0+6,y0+7,gr,gg,gb); Px(x0+11,y0+7,gr,gg,gb); Px(x0+12,y0+7,gr,gg,gb);
  for(int x=5;x<=12;x++) Px(x0+x,y0+11,gr,gg,gb); Px(x0+4,y0+10,gr,gg,gb); Px(x0+13,y0+10,gr,gg,gb); }
 static void Lights(int f){ LightsC(f,new[]{245,165,80},new[]{185,140,225}); }
 static void LightsC(int f,params int[][] cs){ for(int x=40;x<=96;x++){ double u=(x-40)/56.0; int y=2+(int)Math.Round(6*4*u*(1-u)); PxBg(x,y,90,80,70); }
  int b=0; for(int x=43;x<=93;x+=7,b++){ double u=(x-40)/56.0; int y=3+(int)Math.Round(6*4*u*(1-u)); bool dim=((f/6)%8)==(b%8); int r1,g1,b1; int[] cc=cs[b%cs.Length]; r1=cc[0];g1=cc[1];b1=cc[2]; if(dim){ r1=r1*2/3; g1=g1*2/3; b1=b1*2/3; } PxBg(x,y,r1,g1,b1); PxBg(x+1,y,r1,g1,b1); PxBg(x,y+1,r1,g1,b1); PxBg(x+1,y+1,r1,g1,b1); } }

 static void Rect(int x0,int y0,int x1,int y1,int r,int g,int b){ for(int y=y0;y<=y1;y++) for(int x=x0;x<=x1;x++) Px(x,y,r,g,b); }
 static void Heart(int cx,int cy,int s,int r,int g,int b){ string[] m={".11.11.","1111111","1111111",".11111.","..111..","...1..."}; int sc=s>=3?2:1; for(int y=0;y<6;y++) for(int x=0;x<7;x++) if(m[y][x]=='1') for(int a=0;a<sc;a++) for(int c=0;c<sc;c++) Px(cx-(7*sc)/2+x*sc+c,cy-3*sc+y*sc+a,r,g,b); }
 static void Glow(int f,out int r,out int g,out int b){ bool hi=((f/8)%2)==0; r=hi?255:240; g=hi?215:190; b=hi?120:100; }
 static void Tree(int x0,int y0,int f){ for(int y=0;y<15;y++){ int half=1+y*8/15; for(int x=-half;x<=half;x++) Px(x0+9+x,y0+2+y,(y+x)%5==0?40:30,(y+x)%5==0?110:95,(y+x)%5==0?60:55);} Rect(x0+8,y0+17,x0+10,y0+18,110,70,40); int gr,gg,gb; Glow(f,out gr,out gg,out gb); Px(x0+9,y0+1,gr,gg,gb); Px(x0+8,y0+2,gr,gg,gb); Px(x0+10,y0+2,gr,gg,gb); Px(x0+9,y0+0,gr,gg,gb);
  int[,] o={{7,7},{11,9},{6,12},{12,14},{9,11},{5,15}}; for(int k=0;k<6;k++){ bool on=((f/6)%6)!=k; int[] c= k%3==0? new[]{235,90,80}: k%3==1? new[]{250,210,120}: new[]{140,180,240}; if(!on){c=new[]{c[0]*2/3,c[1]*2/3,c[2]*2/3};} Px(x0+o[k,0],y0+o[k,1],c[0],c[1],c[2]); }
  for(int x=-2;x<21;x++) Px(x0+x,y0+19,235,240,250); }
 static void Gift(int x0,int y0,int r,int g,int b){ Rect(x0,y0+4,x0+13,y0+14,r,g,b); Rect(x0+6,y0+4,x0+7,y0+14,250,215,130); Rect(x0,y0+8,x0+13,y0+9,250,215,130); Px(x0+5,y0+3,250,215,130); Px(x0+4,y0+2,250,215,130); Px(x0+8,y0+3,250,215,130); Px(x0+9,y0+2,250,215,130); }
 static void Star(int cx,int cy,int r,int g,int b){ for(int k=-3;k<=3;k++){ Px(cx+k,cy,r,g,b); Px(cx,cy+k,r,g,b);} Px(cx-1,cy-1,r,g,b); Px(cx+1,cy-1,r,g,b); Px(cx-1,cy+1,r,g,b); Px(cx+1,cy+1,r,g,b); }
 static void Shamrock(int cx,int cy){ Disc(cx-3,cy-2,3,70,170,90,false); Disc(cx+3,cy-2,3,70,170,90,false); Disc(cx,cy-6,3,70,170,90,false); for(int y=0;y<6;y++) Px(cx+y/3,cy+y,60,140,70); }
 static void Egg(int cx,int cy,int r,int g,int b,int r2,int g2,int b2){ for(int y=-7;y<=7;y++) for(int x=-6;x<=6;x++){ double dx=x/5.0, dy=y/(y<0?7.0:6.0); if(dx*dx+dy*dy<=1) Px(cx+x,cy+y, (y==-1||y==3)?r2:r, (y==-1||y==3)?g2:g, (y==-1||y==3)?b2:b);} }
 static void Flag(int x0,int y0){ for(int y=0;y<12;y++) for(int x=0;x<18;x++){ bool red=(y/2)%2==0; Px(x0+x,y0+y, red?200:235, red?70:235, red?75:240);} Rect(x0,y0,x0+7,y0+6,60,80,160); for(int k=0;k<3;k++){ Px(x0+1+k*2,y0+1,240,240,250); Px(x0+2+k*2,y0+4,240,240,250);} Rect(x0-1,y0,x0-1,y0+18,180,170,150); }
 static void Leaf(int cx,int cy,int r,int g,int b){ for(int y=-5;y<=5;y++){ int half=4-Math.Abs(y)*4/5; for(int x=-half;x<=half;x++) Px(cx+x,cy+y,r,g,b);} Px(cx,cy+6,110,70,40); Px(cx,cy+7,110,70,40); }
 static void Glass(int x0,int y0,int f){ for(int y=0;y<7;y++){ int half=4-y/2; for(int x=-half;x<=half;x++) Px(x0+5+x,y0+y,y<2?245:235,y<2?235:205,y<2?200:110);} Rect(x0+5,y0+7,x0+5,y0+11,220,225,235); Rect(x0+2,y0+12,x0+8,y0+12,220,225,235); if(((f/6)%2)==0){ Px(x0+6,y0-2,250,230,160); Px(x0+3,y0-3,250,230,160);} else { Px(x0+5,y0-3,250,230,160); Px(x0+8,y0-2,250,230,160);} }
 static void Cone(int top,int r,int g,int b,int r2,int g2,int b2,bool santa){ int bx=64; int hh=santa?26:24; for(int y=-hh;y<=0;y++){ double k=(y+hh)/(double)hh; int half=(int)(2+(santa?22:18)*k); int cx=bx+(santa?(int)(14*(1-k)*(1-k)):0); for(int x=cx-half;x<=cx+half;x++){ bool st=!santa && ((x+y)/4)%2==0; Px(x,top+y-3,st?r2:r,st?g2:g,st?b2:b);} } if(santa){ Rect(bx-26,top-5,bx+26,top-1,240,240,245); Disc(bx+15,top-29,3,245,245,250,false); } else { Disc(bx,top-28,2,r2,g2,b2,false); } }
 static void TopHat(int top,int r,int g,int b,int br,int bg,int bb,bool buckle){ Rect(50,top-30,78,top-4,r,g,b); Rect(50,top-9,78,top-6,br,bg,bb); if(buckle){ Rect(61,top-10,67,top-5,240,200,90); Rect(63,top-8,65,top-7,br,bg,bb);} Rect(40,top-4,88,top-1,r,g,b); }
 static void Ears(int top){ foreach(int ex in new[]{50,78}){ for(int y=-24;y<=0;y++) for(int x=-5;x<=5;x++){ double dx=x/5.0, dy=(y+12)/12.0; if(dx*dx+dy*dy<=1){ bool inner=Math.Abs(x)<=2 && y>-21 && y<-3; Px(ex+x,top+y-2, inner?245:240, inner?175:240, inner?200:245);} } } }
 static void Ball(int cx,int cy,int len,int r,int g,int b,int f,int ph){ for(int y=0;y<len;y++) PxBg(cx,cy+y,200,190,160); int y0=cy+len; Rect(cx-1,y0,cx+1,y0,230,200,110); Disc(cx,y0+4,3,r,g,b,false); bool hi=((f/8+ph)%3)!=0; Px(cx-1,y0+3,hi?255:r+(255-r)/2,hi?250:g+(255-g)/2,hi?235:b+(255-b)/2); }
 static void Spiral(int cx,int y0,int y1,int f,int ph){ int[][] cs={new[]{225,80,75},new[]{110,190,120},new[]{250,205,130},new[]{120,160,235}}; for(int y=y0;y<=y1;y++){ double s=Math.Sin((y-y0)*0.45+ph); if(s>-0.2) Px(cx+(int)Math.Round(6*s),y,70,100,70); }
  int b=0; for(int y=y0+2;y<=y1;y+=5,b++){ int x=cx+(int)Math.Round(6*Math.Sin((y-y0)*0.45+ph)); int[] c=cs[(b+ph)%4]; int nb=(y1-y0)/5+1; bool dim=((f/6)%nb)==b; int r1=c[0],g1=c[1],b1=c[2]; if(dim){ r1=r1*2/3; g1=g1*2/3; b1=b1*2/3; } Px(x,y,r1,g1,b1); Px(x+1,y,r1,g1,b1); Px(x,y+1,r1,g1,b1); Px(x+1,y+1,r1,g1,b1); } }
 static void PotGold(int x0,int y0,int f){ for(int y=0;y<6;y++) for(int x=0;x<16;x++){ bool c=((x*3+y*5)%7)<3; Px(x0+2+x,y0+y-(x>3&&x<12?1:0),c?255:235,c?225:190,c?120:70); } bool hi=((f/8)%2)==0; Px(x0+8,y0-3,hi?255:240,hi?245:220,hi?200:150);
  for(int y=0;y<10;y++){ int half=9-(y>6?(y-6):0)-(y<1?1:0); for(int x=-half;x<=half;x++) Px(x0+10+x,y0+5+y,40,38,44);} Rect(x0,y0+4,x0+20,y0+5,60,58,64); }
 static void BPx(int x,int y,int r,int g,int b){ if((x<36&&y<16)||(x>90&&y<28)||(x>84&&y>116)) return; if(x>=22&&x<=106&&y>=30) { PxBg(x,y,r,g,b); return; } Px(x,y,r,g,b); }
 static void Burst(int cx,int cy,int f,int period,int ph,int r,int g,int b){ int a=((f+ph)%period); if(a>=14) return; if(a<3){ for(int k=0;k<3;k++) BPx(cx,cy+8-a*3-k,250,230,180); return; }
  int t=a-3; int rad=3+t*13/10; double fade=t<4?1.0:Math.Max(0,(11-t)/7.0); int rr=(int)(r*fade+20*(1-fade)), gg=(int)(g*fade+24*(1-fade)), bb=(int)(b*fade+48*(1-fade)); int tr=(rr+20)/2, tg=(gg+24)/2, tb=(bb+48)/2;
  for(int k=0;k<16;k++){ double an=k*Math.PI/8; double c=Math.Cos(an), s=Math.Sin(an); int dr=(k%2==0)?0:-2; int x=cx+(int)Math.Round((rad+dr)*c), y=cy+(int)Math.Round((rad+dr)*s+t*0.3); BPx(x,y,rr,gg,bb); BPx(cx+(int)Math.Round((rad+dr-3)*c),cy+(int)Math.Round((rad+dr-3)*s+t*0.3),tr,tg,tb); } }
 static void Pennants(int[] c1,int[] c2){ for(int x=38;x<=96;x++){ double u=(x-38)/58.0; int y=2+(int)Math.Round(5*4*u*(1-u)); PxBg(x,y,200,190,160); }
  int b=0; for(int x=40;x<=90;x+=7,b++){ double u=(x+3-38)/58.0; int y=3+(int)Math.Round(5*4*u*(1-u)); int[] c=b%2==0?c1:c2; for(int yy=0;yy<5;yy++) for(int xx=yy/2;xx<=6-yy/2-1;xx++) PxBg(x+xx,y+yy,c[0],c[1],c[2]); } }
 static void LoneStar(int cx,int cy,int r,int g,int b){ for(int y=-5;y<=5;y++) for(int x=-5;x<=5;x++){ double an=Math.Atan2(y,x)+Math.PI/2; double rr=Math.Sqrt(x*x+y*y); double lim=2.2+2.8*Math.Pow(Math.Abs(Math.Cos(2.5*an)),3); if(rr<=lim) Px(cx+x,cy+y,r,g,b);} }
 static void Bluebonnet(int cx,int cy){ for(int y=0;y<6;y++) Px(cx,cy+y,80,140,70); Px(cx-1,cy+4,80,140,70); Px(cx-2,cy+3,80,140,70); for(int k=0;k<5;k++){ Px(cx-1+(k%2),cy-1-k,80,110,215); Px(cx+(k%2),cy-1-k,100,130,230);} Px(cx,cy-6,240,240,250); }
 static void StateDeco(int f){ string[] p=StateCol.Split(','); int[] c1={int.Parse(p[0]),int.Parse(p[1]),int.Parse(p[2])}; int[] c2={int.Parse(p[3]),int.Parse(p[4]),int.Parse(p[5])}; string code=Holiday.Substring(3);
  Pennants(c1,c2);
  if(code=="TX"){ Rect(1,108,7,123,60,80,160); Rect(8,108,20,115,240,240,245); Rect(8,116,20,123,190,60,65); LoneStar(4,115,240,240,245); Bluebonnet(114,100); Bluebonnet(119,102); return; }
  Rect(1,113,17,123,c1[0],c1[1],c1[2]); Rect(1,113,17,113,c2[0],c2[1],c2[2]); Rect(1,123,17,123,c2[0],c2[1],c2[2]); Text(2+(code.Length<2?4:2)+1,116,code,c2[0],c2[1],c2[2]); Rect(0,110,0,125,180,170,150); }
 static void Holi(int f){ string h=Holiday; int htop=-1; foreach(int cxx in new[]{44,84}){ for(int y=26;y<60;y++){ if(!Bg[y*W+cxx]){ if(y>htop) htop=y; break; } } }
  if(h=="halloween"){ if(htop>0){ for(int y=86;y<124;y++){ for(int x=14;x<114;x++){ int edge=124-((x/8)%2==0?0:3); if(y<edge) PxBg(x,y,62,44,92);} } Hat(htop); } Lights(f); Pumpkin(1,108,f); Pumpkin(108,92,f+8); return; }
  if(h.StartsWith("st-")){ StateDeco(f); return; }
  if(h=="christmas"){ if(htop>0) Cone(htop,200,50,55,0,0,0,true); LightsC(f,new[]{250,205,130},new[]{225,80,75},new[]{110,190,120},new[]{120,160,235}); Ball(38,4,8,205,55,60,f,0); Ball(44,8,4,245,200,90,f,1); Ball(96,4,8,60,150,85,f,2); Ball(90,8,3,205,55,60,f,1); if(RainDrops>=0){ Spiral(15,50,98,f,0); Spiral(112,50,88,f+3,1); } Tree(1,106,f); Gift(110,94,70,140,90); Ball(22,112,0,245,200,90,f,0); Ball(104,100,0,205,55,60,f,2); return; }
  if(h=="newyear"){ if(htop>0) Cone(htop,235,190,90,120,90,200,false); LightsC(f,new[]{250,220,140},new[]{210,215,235}); Glass(4,112,f); Star(117,99,250,220,140); Burst(20,34,RainDrops<0?1:RealF,28,0,250,215,120); if(RainDrops>=0){ Burst(108,50,RealF,28,10,245,150,190); Burst(22,78,RealF,28,19,140,180,245); } return; }
  if(h=="valentine"){ if(htop>0){ Rect(44,htop-2,84,htop-1,220,90,120); for(int y=0;y<8;y++){ Px(48,htop-2-y,220,90,120); Px(80,htop-2-y,220,90,120);} Heart(48,htop-12,1,235,80,110); Heart(80,htop-12,1,235,80,110); } LightsC(f,new[]{245,150,175},new[]{230,80,100}); Heart(10,114,3,230,80,105); Heart(117,99,3,245,150,175); return; }
  if(h=="stpatricks"){ if(htop>0) TopHat(htop,50,130,70,30,30,30,true); LightsC(f,new[]{100,200,110},new[]{245,205,100}); PotGold(0,110,f); Shamrock(117,101); Shamrock(30,30); Shamrock(100,36); return; }
  if(h=="easter"){ if(htop>0) Ears(htop); LightsC(f,new[]{245,190,210},new[]{180,210,245}); Egg(9,116,170,215,245,250,230,140); Egg(117,100,245,190,210,190,235,190); return; }
  if(h=="july4"){ if(htop>0){ TopHat(htop,60,80,160,200,70,75,false); for(int k=0;k<4;k++) Px(54+k*7,htop-15,240,240,250);} LightsC(f,new[]{225,80,80},new[]{110,150,235}); Flag(3,108); Star(117,99,240,240,250); return; }
  if(h=="thanksgiving"){ if(htop>0) TopHat(htop,40,36,40,90,70,50,true); LightsC(f,new[]{240,160,70},new[]{200,110,60}); Pumpkin(1,108,f); Leaf(117,100,215,120,50); Leaf(110,104,190,80,50); return; } }
 static void Hat(int top){ int bx=64; for(int y=-26;y<=0;y++){ double k=(y+26)/26.0; int half=(int)(3+17*k); int cx=bx+(int)(10*(1-k)*(1-k)); for(int x=cx-half;x<=cx+half;x++) Px(x,top+y-3,88,62,120);} for(int x=bx-21;x<=bx+21;x++) for(int y=-2;y<=0;y++) Px(x,top+y-3,230,170,95); for(int x=bx-30;x<=bx+30;x++){ int dy=Math.Abs(x-bx)>24?1:0; Px(x,top-2+dy,74,52,104); Px(x,top-1+dy,74,52,104);} Px(70,top-18,240,225,150); Px(69,top-17,240,225,150); Px(71,top-17,240,225,150); Px(70,top-16,240,225,150); } public static string Clock="";
 public static byte[] Decimate(byte[] raw,int n){ int fl=W*W*3; int m=(n+1)/2; var o=new byte[m*fl]; for(int k=0;k<m;k++) Array.Copy(raw,(2*k)*fl,o,k*fl,fl); return o; }
 // ---------- drawing ----------
 const int W=128; static byte[] F; static bool[] Bg;
 static void Px(int x,int y,int r,int g,int b){ if(x<0||y<0||x>=W||y>=W) return; int i=(y*W+x)*3; F[i]=(byte)r; F[i+1]=(byte)g; F[i+2]=(byte)b; }
 static void PxBg(int x,int y,int r,int g,int b){ if(x<0||y<0||x>=W||y>=W||!Bg[y*W+x]) return; Px(x,y,r,g,b); }
 static void Disc(int cx,int cy,int rad,int r,int g,int b,bool bgOnly){ for(int y=-rad;y<=rad;y++) for(int x=-rad;x<=rad;x++) if(x*x+y*y<=rad*rad+rad){ if(bgOnly) PxBg(cx+x,cy+y,r,g,b); else Px(cx+x,cy+y,r,g,b);} }
 static readonly Dictionary<char,string> G=new Dictionary<char,string>{
  {'0',"111101101101111"},{'1',"010110010010111"},{'2',"111001111100111"},{'3',"111001111001111"},{'4',"101101111001001"},{'5',"111100111001111"},{'6',"111100111101111"},{'7',"111001010010010"},{'8',"111101111101111"},{'9',"111101111001111"},{':',"000010000010000"},{' ',"000000000000000"},
  {'A',"010101111101101"},{'B',"110101110101110"},{'C',"011100100100011"},{'D',"110101101101110"},{'E',"111100110100111"},{'F',"111100110100100"},{'G',"011100101101011"},{'H',"101101111101101"},{'I',"111010010010111"},{'J',"001001001101010"},{'L',"100100100100111"},{'M',"101111111101101"},{'N',"110101101101101"},{'O',"010101101101010"},{'P',"110101110100100"},{'R',"110101110101101"},{'S',"011100010001110"},{'T',"111010010010010"},{'U',"101101101101111"},{'V',"101101101101010"},{'W',"101101111111101"},{'Y',"101101010010010"},{'Z',"111001010100111"},{'%',"101001010100101"},{'K',"101101110101101"},{'X',"101101010101101"},{'Q',"010101101111011"},{'-',"000000111000000"},{'.',"000000000000010"}};
 static void Text(int x,int y,string s,int r,int g,int b){ foreach(char ch in s.ToUpper()){ string m; if(G.TryGetValue(ch,out m)) for(int k=0;k<15;k++) if(m[k]=='1'){ Px(x+k%3,y+k/3,r,g,b);} x+=4; } }
 static void Cloud(int x,int y,int r,int g,int b){ Disc(x+6,y+8,5,r,g,b,true); Disc(x+13,y+5,7,r,g,b,true); Disc(x+20,y+9,5,r,g,b,true); for(int yy=y+9;yy<=y+13;yy++) for(int xx=x+3;xx<=x+23;xx++) PxBg(xx,yy,r,g,b); }
 // tod: morning|day|evening|night ; wx: clear|cloudy|rain|storm|fog|snow|none
 static double Sm(double a,double b,double x){ double t=Math.Max(0,Math.Min(1,(x-a)/(b-a))); return t*t*(3-2*t); }
 static void Blob(byte[] img,int cx,int cy,int rx,int ry,int r,int g,int b,double a){ for(int y=Math.Max(0,cy-ry);y<=Math.Min(W-1,cy+ry);y++) for(int x=cx-rx;x<=cx+rx;x++){ double dx=(double)(x-cx)/rx, dy=(double)(y-cy)/ry; if(dx*dx+dy*dy<=1){ int xx=((x%W)+W)%W; int i=(y*W+xx)*3; img[i]=(byte)(img[i]*(1-a)+r*a); img[i+1]=(byte)(img[i+1]*(1-a)+g*a); img[i+2]=(byte)(img[i+2]*(1-a)+b*a);} } }
 static void CloudBand(byte[] img,int y,int sh,int seed,int cnt,int r,int g,int b,double a,int size){ var q=new Random(seed); for(int k=0;k<cnt;k++){ int cx=q.Next(W)+sh, cy=y+q.Next(-3,4), rx=size+q.Next(size/2+1); Blob(img,cx,cy,rx,rx/2+2,r,g,b,a); Blob(img,cx+rx/2,cy-rx/4,rx*2/3,rx/2,r,g,b,a);} }
 // tod: morning|day|evening|night ; wx: clear|cloudy|rain|storm|fog|snow|none
 public static byte[] Compose(byte[] raw,int n,string tod,string wx,string line1,string line2){
  var o=(byte[])raw.Clone(); int fl=W*W*3; var rnd=new Random(7);
  bool night=tod=="night"; bool noWx=wx=="none"||string.IsNullOrEmpty(wx); bool clearish=wx=="clear";
  if(noWx && string.IsNullOrEmpty(tod)){ // plain
  }
  int[] top,bot; // sky gradient
  if(night){ top=new[]{2,4,22}; bot=new[]{14,24,64}; }
  else switch(wx){ case "clear": top=new[]{30,96,200}; bot=new[]{120,180,240}; break;
   case "cloudy": top=new[]{88,98,116}; bot=new[]{150,160,176}; break;
   case "rain": top=new[]{30,36,50}; bot=new[]{70,80,98}; break;
   case "storm": top=new[]{10,12,20}; bot=new[]{36,40,56}; break;
   case "snow": top=new[]{150,166,190}; bot=new[]{215,222,234}; break;
   case "fog": top=new[]{120,124,130}; bot=new[]{190,192,196}; break;
   default: switch(tod){ case "morning": top=new[]{44,30,52}; break; case "day": top=new[]{16,38,74}; break; case "evening": top=new[]{54,22,34}; break; default: top=new[]{12,16,32}; break; } bot=top; break; }
  var drops=new int[48,2]; for(int i=0;i<48;i++){ drops[i,0]=rnd.Next(W); drops[i,1]=rnd.Next(W); }
  var stars=new int[24,2]; for(int i=0;i<24;i++){ stars[i,0]=rnd.Next(W); stars[i,1]=rnd.Next(60); }
  var br=new Random(Environment.TickCount); int nb=NoBirds?0:(wx=="clear"||wx=="cloudy"||noWx)?1+br.Next(2):0; var bs=new int[2,3]; for(int i=0;i<2;i++){ bs[i,0]=br.Next(n); bs[i,1]=17+br.Next(8); bs[i,2]=Math.Max(8,n*3/5); }
  bool clouds = wx=="cloudy"||wx=="rain"||wx=="storm"||(wx=="snow");
  int lastSh=int.MinValue; byte[] sky=null;
  for(int f=0;f<n;f++){ F=new byte[fl]; Array.Copy(o,f*fl,F,0,fl); Bg=new bool[W*W];
   int sh=NoMotion?0:(int)((long)((f/DriftStep)*DriftStep)*W/n); int fA=n/4, fB=(3*n)/4; bool flash = RainDrops>0 && ((wx=="storm" && (f==fA||f==fB)) || (wx=="rain" && f==n/3)); bool bolt = RainDrops>3 && (flash || (RainDrops>0 && ((wx=="storm" && (f==fA+1||f==fB+1)) || (wx=="rain" && f==n/3+1))));
   if(sky==null || sh!=lastSh || flash || (f==fA+1||f==fB+1||f==n/3+1)){ lastSh=sh; sky=new byte[fl];
    for(int y=0;y<W;y++){ double t=y/(double)(W-1); for(int x=0;x<W;x++){ int i=(y*W+x)*3; sky[i]=(byte)(top[0]+(bot[0]-top[0])*t); sky[i+1]=(byte)(top[1]+(bot[1]-top[1])*t); sky[i+2]=(byte)(top[2]+(bot[2]-top[2])*t);} }
    if(!night && tod=="morning" && !noWx) for(int y=118;y<W;y++) for(int x=0;x<W;x++){ int i=(y*W+x)*3; sky[i]=(byte)((sky[i]+230)/2); sky[i+1]=(byte)((sky[i+1]+150)/2); sky[i+2]=(byte)((sky[i+2]+120)/2);} 
    if(!night && tod=="evening" && !noWx) for(int y=116;y<W;y++) for(int x=0;x<W;x++){ int i=(y*W+x)*3; sky[i]=(byte)((sky[i]+240)/2); sky[i+1]=(byte)((sky[i+1]+110)/2); sky[i+2]=(byte)((sky[i+2]+70)/2);} 
    if(clouds){ double dk=night?0.45:1.0; Func<int,int> c=v=>(int)(v*dk);
      if(wx=="cloudy"){ CloudBand(sky,13,sh,11,4,c(180),c(186),c(198),0.55,14); CloudBand(sky,40,0,12,4,c(205),c(210),c(220),0.6,12); CloudBand(sky,110,0,13,5,c(225),c(228),c(235),0.7,12); }
      else if(wx=="rain"){ CloudBand(sky,8,sh,21,5,c(60),c(66),c(80),0.85,18); CloudBand(sky,28,0,22,5,c(80),c(86),c(100),0.8,15); }
      else if(wx=="storm"){ CloudBand(sky,6,sh,31,5,c(34),c(38),c(50),0.9,18); CloudBand(sky,26,0,32,5,c(50),c(54),c(68),0.85,15); }
      else { CloudBand(sky,10,sh,41,4,c(200),c(208),c(222),0.6,15); } }
    if(wx=="fog"){ for(int b=0;b<5;b++){ int y0=18+b*22; for(int y=y0;y<y0+7;y++) for(int x=0;x<W;x++){ int xx=((x+sh*(b%2==0?1:-1))%W+W)%W; double a=0.35*(0.5+0.5*Math.Sin(xx*0.09+b)); int i=(y*W+x)*3; if(y>=W) continue; sky[i]=(byte)(sky[i]*(1-a)+225*a); sky[i+1]=(byte)(sky[i+1]*(1-a)+226*a); sky[i+2]=(byte)(sky[i+2]*(1-a)+230*a);} } }
    if(flash){ int gl=RainDrops>3?28:14; for(int i=0;i<fl;i++) sky[i]=(byte)Math.Min(255,sky[i]+gl); }
    // keep head area darker/cleaner: vignette around face
    for(int y=0;y<W;y++) for(int x=0;x<W;x++){ double dx=(x-64)/52.0, dy=(y-74)/50.0; double d=Math.Sqrt(dx*dx+dy*dy); double a=d<0.98?1.0:(d<1.08?0.55:0); if(a<=0) continue; int i=(y*W+x)*3; sky[i]=(byte)(sky[i]*(1-a)+(night?6:14)*a); sky[i+1]=(byte)(sky[i+1]*(1-a)+(night?10:18)*a); sky[i+2]=(byte)(sky[i+2]*(1-a)+(night?30:34)*a);}  for(int i=0;i<fl;i++) sky[i]=(byte)((sky[i]&0xF0)|0x08); }
   for(int p=0;p<W*W;p++){ int i=p*3; if(F[i]==12&&F[i+1]==16&&F[i+2]==32){ Bg[p]=true; F[i]=sky[i]; F[i+1]=sky[i+1]; F[i+2]=sky[i+2]; } }
   if(night && (clearish||noWx||wx=="cloudy"||wx=="fog")) for(int i=0;i<24;i++){ int ph=NoMotion?(i%9):((f/8)+i*3)%9; if(ph==0) continue; int v=ph<3?140:230; PxBg(stars[i,0],stars[i,1],v,v,255); if(ph==5&&i%3==0){ PxBg(stars[i,0]+1,stars[i,1],120,120,200); PxBg(stars[i,0]-1,stars[i,1],120,120,200);} }
   // emblem top-right
   if(night){ if(!clouds || wx=="cloudy"){ Disc(112,13,8,235,235,200,true); Disc(116,10,7,sky[(10*W+116)*3],sky[(10*W+116)*3+1],sky[(10*W+116)*3+2],true); } }
   else if(clearish){ int sr=255, sg=tod=="day"?215:180, sb=60; int pu=(!NoMotion && (f*4/n)%2==1)?1:0; Disc(112,13,6+pu,sr,sg,sb,true);
       for(int a=0;a<8;a++){ double t=a*Math.PI/4; for(int k=9+pu;k<=11+pu;k++) PxBg(112+(int)Math.Round(Math.Cos(t)*k),13+(int)Math.Round(Math.Sin(t)*k),sr,sg,sb);} }
   for(int i=0;i<nb;i++){ int age=((f-bs[i,0])%n+n)%n; if(age>=bs[i,2]) continue; int bx=-4+(int)((long)age*136/bs[i,2]); int by=bs[i,1]+((age/4)%2); bool up=(f/2)%2==0; int cr=night?0:20, cg=night?0:24, cb=night?0:34;
     int[,] pts= night ? (up? new[,]{{0,0},{1,1},{2,1},{3,1},{4,0},{2,0}} : new[,]{{0,1},{1,1},{2,0},{3,1},{4,1},{2,1}}) : (up? new[,]{{0,0},{1,1},{2,0}} : new[,]{{0,1},{1,1},{2,1}});
     for(int k=0;k<pts.GetLength(0);k++){ int x=bx+pts[k,0], y=by+pts[k,1]; if(x>94 && y<28) continue; if(x<44 && y<16) continue; PxBg(x,y,cr,cg,cb);} }
   if(wx=="rain"||wx=="storm"){ int nd=wx=="storm"?RainDrops:RainDrops+4; for(int i=0;i<nd;i++){ int y=(int)((drops[i,1]+(f/2)*2*(W*2.0/n))%W); int x=drops[i,0]; for(int k=0;k<3;k++) PxBg(x,(y+k)%W,150,195,245); } }
   if(wx=="snow"){ for(int i=0;i<30;i++){ int y=(int)((drops[i,1]+(f/3)*3*((double)W/n))%W); int x=drops[i,0]+((f/6+i)%3-1); PxBg(x,y,255,255,255); } }
   if(bolt){ int[,] bp={{100,14},{96,24},{102,24},{94,40}}; for(int k=0;k<3;k++){ int x0=bp[k,0],y0=bp[k,1],x1=bp[k+1,0],y1=bp[k+1,1]; for(int s=0;s<=10;s++){ PxBg(x0+(x1-x0)*s/10,y0+(y1-y0)*s/10,240,225,170); PxBg(x0+(x1-x0)*s/10+1,y0+(y1-y0)*s/10,240,225,170);} } }
   if(!string.IsNullOrEmpty(line1)||!string.IsNullOrEmpty(line2)){ int tw=Math.Max((line1??"").Length,(line2??"").Length)*4+1; int th=string.IsNullOrEmpty(line2)?7:14; for(int y=0;y<th;y++) for(int x=0;x<tw;x++) PxBg(x,y,6,8,16); }
   if(Holiday!=""){ RealF=f; Holi(NoMotion?0:f); }
   if(!string.IsNullOrEmpty(Clock)){ int cw=Clock.Length*4+1; int cx=W-cw; for(int y=W-8;y<W;y++) for(int x=cx;x<W;x++) PxBg(x,y,6,8,16); Text(cx+1,W-6,Clock,240,244,255); }
   if(!string.IsNullOrEmpty(line1)) Text(1,1,line1,240,244,255);
   if(!string.IsNullOrEmpty(line2)) Text(1,8,line2,255,215,120);
   Array.Copy(F,0,o,f*fl,fl); }
  return o; }
}
