# -*- coding: utf-8 -*-
# TASK-08 v3 FINAL: hue-heuristic town collage from surt town_tiles.png + sprite-filtered chars + dialog
from PIL import Image, ImageDraw, ImageFont
import os

BASE = r"c:\Users\weixufeng\WorkBuddy\2026-08-29-05-48-48\design\art-bible\mockup"
SRC = os.path.join(BASE, "_src")
OUT = os.path.join(BASE, "town-street-mockup.png")
PAPER=(232,220,192,255); RED=(166,66,58,255); GOLD=(217,169,78,255); SHADOW=(74,59,82,255); WHITE=(255,255,255,255)
LOG=[]

def load(fn): return Image.open(os.path.join(SRC, fn)).convert("RGBA")
def opaque(im):
    h = im.getchannel("A").histogram(); return sum(h[129:])
def chroma_key(im, tol=10):
    px=im.load(); W,H=im.size
    if any(px[x,y][3]<255 for x,y in [(0,0),(W-1,0),(0,H-1),(W-1,H-1),(W//2,0)]): return im,"native-alpha"
    bg=px[0,0][:3]; n=0
    for y in range(H):
        for x in range(W):
            r,g,b,a=px[x,y]
            if abs(r-bg[0])<=tol and abs(g-bg[1])<=tol and abs(b-bg[2])<=tol: px[x,y]=(r,g,b,0); n+=1
    return im,"keyed n=%d"%n
def tile_stats(t):
    px=list(t.getdata()); n=len(px)
    op=[p for p in px if p[3]>128]
    if len(op) < n*0.8: return None
    r=sum(p[0] for p in op)/len(op); g=sum(p[1] for p in op)/len(op); b=sum(p[2] for p in op)/len(op)
    var=sum((p[0]-r)**2+(p[1]-g)**2+(p[2]-b)**2 for p in op)/len(op)
    dark=sum(1 for p in op if p[0]+p[1]+p[2]<210)/len(op)
    return (r,g,b,var,dark)

tilesheet = load("town_tiles.png")
TW,TH = tilesheet.size
cls = {"grass":[], "path":[], "roof":[], "wall":[], "tree":[], "stone":[], "water":[]}
for ty in range(0, TH-15, 16):
    for tx in range(0, TW-15, 16):
        st = tile_stats(tilesheet.crop((tx,ty,tx+16,ty+16)))
        if st is None: continue
        r,g,b,var,dark = st
        if b > r+15 and b > g+5: cls["water"].append((tx,ty))
        elif r > g+25 and r > b+25: cls["roof"].append((tx,ty))
        elif max(r,g,b)-min(r,g,b) < 20: cls["stone"].append((tx,ty))
        elif g > r+3 and g >= b+3:
            cls["tree" if (var>6000 or dark>0.3) else "grass"].append((tx,ty))
        elif r > b+12 and r >= g-2:
            cls["path" if (var<2500 and dark<0.15) else "wall"].append((tx,ty))
        else: cls["wall"].append((tx,ty))
for k,v in cls.items(): LOG.append("class %s: %d tiles %s" % (k, len(v), v[:6]))

from collections import Counter
def pick(k, prefer_common=True):
    if not cls[k]: return None
    c = Counter(cls[k])
    return (c.most_common(1)[0][0] if prefer_common else cls[k][0])

grass = pick("grass"); path = pick("path"); roof = pick("roof")
wall  = pick("wall"); tree = pick("tree"); stone = pick("stone")
door  = None
if cls["wall"]:
    best=None
    for (tx,ty) in cls["wall"]:
        t=tilesheet.crop((tx,ty,tx+16,ty+16)); px=list(t.getdata())
        bot=[p for p in px[128:] if p[3]>128]
        db=sum(1 for p in bot if p[0]+p[1]+p[2]<200)/max(1,len(bot))
        if db>0.3 and (best is None or db>best[0]): best=(db,tx,ty)
    if best: door=(best[1],best[2])
LOG.append("picked grass=%s path=%s roof=%s wall=%s tree=%s stone=%s door=%s" % (grass,path,roof,wall,tree,stone,door))

# ---------- build 40x23 scene ----------
S=16
canvas = Image.new("RGBA", (640,360), PAPER)
def put(tile, tx, ty):
    if tile: canvas.paste(tilesheet.crop((tile[0],tile[1],tile[0]+S,tile[1]+S)), (tx*S, ty*S))
def fill(tile, x0,x1,y0,y1):
    if not tile: return
    for ty in range(y0,y1+1):
        for tx in range(x0,x1+1): put(tile,tx,ty)

fill(grass, 0,39, 0,22)                      # grass base
street = path if path else stone             # cobble street fallback
if street: fill(street, 15,24, 0,22)         # vertical street
# buildings: roof rows + wall rows + door
if roof and wall:
    for bx,(x0,x1,ry0,wy0,wy1) in {0:(2,9,2,3,5), 1:(28,35,1,2,4)}.items():
        fill(roof, x0,x1, ry0,ry0+1)
        fill(wall, x0,x1, wy0,wy1)
        if door: put(door, (x0+x1)//2, wy1)
# trees flanking
if tree:
    for (tx,ty) in [(1,13),(2,13),(1,15),(37,11),(38,11),(37,13)]:
        put(tree,tx,ty)
if stone:
    for (tx,ty) in [(13,12),(26,12)]: put(stone,tx,ty)   # stone props by street

# ---------- characters (sprite-like opacity 60..250, distinct columns) ----------
chars = load("charsets_12_m-f_complete_by_antifarea.png")
chars, kinfo = chroma_key(chars)
LOG.append("charset %s %s" % (chars.size, kinfo))
cw,ch = chars.size
frames=[]
for yb in range(0, ch-18, 18):
    x=0
    while x < cw-16:
        n = opaque(chars.crop((x,yb,x+16,yb+18)))
        if 60 <= n <= 250: frames.append((x,yb,n)); x+=8
        else: x+=1
frames.sort(key=lambda f:-f[2])
picked=[]
for fx,fy,fn_ in frames:
    if fn_ < frames[0][2]*0.55: break
    if any(abs(fx-p[0])<48 for p in picked): continue
    picked.append((fx,fy,fn_))
    if len(picked)==3: break
LOG.append("char frames picked: %s (from %d candidates)" % (picked, len(frames)))
positions=[(296,214),(338,224),(262,228)]
for (px_,py_),(fx,fy,fn_) in zip(positions,picked):
    fr=chars.crop((fx,fy,fx+16,fy+18)); canvas.paste(fr,(px_,py_),fr)

# ---------- dialog sample ----------
d=ImageDraw.Draw(canvas)
d.rectangle([16,244,623,351], fill=PAPER, outline=SHADOW, width=2)
d.rectangle([19,247,620,348], outline=GOLD, width=1)
d.rectangle([24,224,119,243], fill=RED, outline=SHADOW, width=1)
faces=load("48x48_Faces_1st_Sheet_Update_CharlesGabriel_OGA.png")
faces,_=chroma_key(faces)
face=faces.crop((0,0,48,48))
d.rectangle([39,261,89,312], outline=SHADOW, width=1)
canvas.paste(face,(40,263),face)
font=ImageFont.truetype(r"C:\Windows\Fonts\simsun.ttc", 12)
d.text((128,270),"欢迎来到边陲小镇，旅行者。",font=font,fill=SHADOW)
d.text((128,292),"北边的遗迹最近不太平静……",font=font,fill=SHADOW)
d.text((30,227),"凯尔",font=font,fill=WHITE)
d.polygon([(600,330),(610,330),(605,338)], fill=GOLD, outline=SHADOW)

canvas=canvas.convert("RGB")
canvas.save(OUT, optimize=True)
LOG.append("saved=%s size=%s" % (OUT, canvas.size))
print("\n".join(LOG))
