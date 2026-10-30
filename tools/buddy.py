# Speakling for Grok Bot - box-side builder.
# usage: buddy.py notify "message"   -> job zip: chime + alert face (waits for yes/no in chat)
#        buddy.py speak  "message"   -> job zip: segmented lip-synced speech, idle restored at end
#        buddy.py idle               -> job zip: just restore idle
# Output: tools/job.zip  (copy it to the Windows PC, then run buddy.ps1 -Job <path-to-job.zip>)
import sys,os,re,json,subprocess,zipfile,shutil,numpy as np
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw
import divoom_proto as dp
FMS=100; MAXF=100  # ~10 s per segment
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'out')
BG=(12,16,32); C=(120,220,255); D=(20,30,60)
def face(m,blink=False,alert=False,ring=0):
    im=Image.new('RGB',(128,128),BG); d=ImageDraw.Draw(im)
    d.line([(64,30),(64,14)],fill=(170,200,255),width=4); d.ellipse([57,6,71,20],fill=(255,200,60) if alert and ring%2 else C)
    d.rounded_rectangle([22,30,106,108],radius=20,fill=(225,235,255),outline=(255,190,60) if alert else (120,170,255),width=4)
    d.rounded_rectangle([32,42,96,96],radius=14,fill=D)
    for x in (48,80):
        if blink: d.line([(x-10,66),(x+10,66)],fill=C,width=3)
        else: d.ellipse([x-12,54,x+12,78],fill=(40,110,200)); d.ellipse([x-8,58,x+8,74],fill=C); d.ellipse([x-5,59,x+1,65],fill=(255,255,255))
    if m==0: d.arc([50,74,78,90],20,160,fill=C,width=3)
    elif m==1: d.rounded_rectangle([54,81,74,86],radius=2,fill=C)
    elif m==2: d.ellipse([54,79,74,90],fill=C); d.ellipse([58,82,70,87],fill=D)
    elif m==3: d.ellipse([56,77,72,93],fill=C); d.ellipse([60,80,68,90],fill=D)
    else: d.ellipse([50,77,78,94],fill=C); d.ellipse([54,80,74,91],fill=D)
    d.ellipse([12,60,24,78],fill=(120,170,255)); d.ellipse([104,60,116,78],fill=(120,170,255))
    if alert:  # envelope badge top-right, wiggles
        o=-2 if ring%2 else 2; x0,y0=92+o,4
        d.rectangle([x0,y0,x0+30,y0+20],fill=(255,200,60)); d.line([(x0,y0),(x0+15,y0+11),(x0+30,y0)],fill=(120,60,0),width=2)
        d.ellipse([4,4,18,18],fill=(255,80,80)); d.text((8,5),'!',fill=(255,255,255))
    return im.quantize(colors=16).convert('RGB')
def pack(fr,path,speed=FMS):
    assert len(fr)<=255,len(fr)
    pl=dp.write_packets([f.tobytes() for f in fr],speed,path,limit=11500)
    return pl,(pl+255)//256+1
def tts(text,mp3):
    subprocess.run(['edge-tts','--voice','en-US-AvaNeural','--rate=-10%','--text',text,'--write-media',mp3],check=True,capture_output=True)
    pcm=subprocess.run(['ffmpeg','-v','quiet','-i',mp3,'-f','s16le','-ac','1','-ar','16000','-'],capture_output=True,check=True).stdout
    return np.frombuffer(pcm,np.int16).astype(float)
def levels(a):
    hop=1600; n=int(np.ceil(len(a)/hop)); rms=np.array([np.sqrt(np.mean(a[i*hop:(i+1)*hop]**2)) for i in range(n)])
    ref=np.percentile(rms[rms>0],95) if (rms>0).any() else 1
    return [0 if v<0.08*ref else 1 if v<0.3*ref else 2 if v<0.55*ref else 3 if v<0.8*ref else 4 for v in rms]
def segments(text):
    # sentence split, then pack sentences into chunks of ~<=22 words (~8-9 s at -10% rate); split long sentences on commas/words
    sents=[x for x in re.split(r'(?<=[.!?])\s+',text.strip()) if x]; out=[]; cur=''
    for snt in sents:
        w=snt.split()
        if len(w)>22 and cur: out.append(cur); cur=''
        while len(w)>22:
            k=max([i+1 for i,x in enumerate(w[:22]) if x.endswith((',',';',':'))] or [22]); out.append(' '.join(w[:k])); w=w[k:]
        snt=' '.join(w)
        if cur and len((cur+' '+snt).split())>22: out.append(cur); cur=snt
        else: cur=(cur+' '+snt).strip()
    if cur: out.append(cur)
    return out
def speak_seg(text,base):
    a=tts(text,base+'.mp3'); lv=levels(a)
    if len(lv)+15>MAXF+40: return None
    cache={}; fr=[]
    for i,m in enumerate(lv+[0]*15):
        fr.append(cache.setdefault((m,(i%40) in (30,31) and m<=1),face(m,(i%40) in (30,31) and m<=1)))
    pl,pk=pack(fr,base+'.bin'); return dict(mp3=os.path.basename(base)+'.mp3',bin=os.path.basename(base)+'.bin',ms=int(len(a)/16),frames=len(fr),payload=pl,packets=pk,text=text)
def chime(path):
    sr=22050; t=np.arange(int(sr*0.9))/sr; y=np.zeros_like(t)
    for f0,st in ((880,0),(1318.5,0.18)):
        tt=np.clip(t-st,0,None); y+=np.where(t>=st,np.sin(2*np.pi*f0*tt)*np.exp(-tt*5),0)
    pcm=(y/np.abs(y).max()*0.6*32767).astype(np.int16).tobytes()
    subprocess.run(['ffmpeg','-v','quiet','-y','-f','s16le','-ar',str(sr),'-ac','1','-i','-','-b:a','96k',path],input=pcm,check=True)
def main():
    mode=sys.argv[1]; text=sys.argv[2] if len(sys.argv)>2 else ''
    shutil.rmtree(OUT,ignore_errors=True); os.makedirs(OUT); job=dict(mode=mode,steps=[])
    if mode=='notify':
        chime(OUT+'/chime.mp3')
        fr=[face(0,b,True,r) for r,b in ((i,i in (14,15)) for i in range(20))]; pl,pk=pack(fr,OUT+'/alert.bin',150)
        job['steps']=[dict(kind='alert',bin='alert.bin',mp3='chime.mp3',payload=pl,packets=pk)]
    elif mode=='speak':
        segs=[]
        for i,t in enumerate(segments(text)):
            r=speak_seg(t,f'{OUT}/seg{i:02d}')
            if r is None:  # too long: split in half by words
                w=t.split(); h=len(w)//2
                for j,tt in enumerate((' '.join(w[:h]),' '.join(w[h:]))): segs.append(speak_seg(tt,f'{OUT}/seg{i:02d}{"ab"[j]}'))
            else: segs.append(r)
        job['steps']=[dict(kind='talk',**g) for g in segs]
    elif mode!='idle': sys.exit('mode must be notify|speak|idle')
    json.dump(job,open(OUT+'/job.json','w'),indent=1)
    # PowerShell-friendly manifest: kind|bin|mp3|ms per line
    open(OUT+'/job.txt','w').write(''.join(f"{st['kind']}|{st['bin']}|{st['mp3']}|{st.get('ms',0)}\n" for st in job['steps']))
    z=os.path.join(os.path.dirname(OUT),'job.zip')
    with zipfile.ZipFile(z,'w') as zf:
        for f in os.listdir(OUT): zf.write(os.path.join(OUT,f),f)
    print(json.dumps(job,indent=1)); print('zip',z,os.path.getsize(z))
if __name__=='__main__': main()
