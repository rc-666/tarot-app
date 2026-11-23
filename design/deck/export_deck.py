# Exports the deck layers from the design canvas SVGs (card-deck-spec.md).
import re, json, io, sys, os
import cairosvg
from PIL import Image
OUT=sys.argv[1]; SRC='/home/claude/deck-src'
for d in ['art','frame','back','svg','preview/en']: os.makedirs(f'{OUT}/{d}',exist_ok=True)

def split(c):
    i=c.index('<g clip-path'); depth=0
    for m in re.finditer(r'<g\b|</g>',c[i:]):
        depth+= 1 if m.group()=='<g' else -1
        if depth==0: j=i+m.end(); break
    head=c[:i]; art=c[i:j]; rest=c[j:]
    return head, art, rest

def body(svg):  # inner markup without the outer <svg ...> and </svg>
    return svg[svg.index('>')+1: svg.rindex('</svg>')]

def png(svg, w, h):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h))).convert('RGBA')

W='<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{w}" height="{h}">{b}</svg>'
pages=[('fsax8e','m',0),('nngpxs','w',1),('ya9byi','c',1),('qlppec','s',1),('heu64b','p',1)]
manifest=[]; frame_rest=None
courts={11:'Page',12:'Knight',13:'Queen',14:'King'}
for f,prefix,start in pages:
    s=open(f'{SRC}/{f}.html').read()
    cards=re.findall(r'<svg width="160" height="269".*?</svg>',s,flags=re.S)
    for k,c in enumerate(cards):
        num=k+start; cid=f'{prefix}{num:02d}'
        name=re.search(r'aria-label="([^"]+)"',c).group(1)
        texts=re.findall(r'<text[^>]*>([^<]*)</text>',c)
        numeral, title = (texts+['',''])[:2] if len(texts)==2 else ('', texts[0] if texts else '')
        head,art,rest=split(c)
        inner=head[head.index('>')+1:]  # defs + background rect before the art group
        # 1) art: background + scene, cropped to the art box (x24 y52 192x298), 2.5x
        art_svg=W.format(vb='24 52 192 298',w=480,h=745,b=inner+art)
        png(art_svg,480,745).convert('RGB').save(f'{OUT}/art/{cid}.webp','WEBP',quality=82,method=6)
        open(f'{OUT}/svg/{cid}.svg','w').write(c.replace('width="160" height="269" ',''))
        if frame_rest is None: frame_rest=re.sub(r'<text.*?</text>','',rest.replace('</svg>',''))
        manifest.append({'id':cid,'numeral':numeral,'name':name,'title':title,
            'arcana':'major' if prefix=='m' else 'minor','suit':None if prefix=='m' else {'w':'wands','c':'cups','s':'swords','p':'pentacles'}[prefix],
            'number':num})
        # preview with English title (review / store / landing)
        png(c.replace('width="160" height="269" ','width="600" height="1008" '),600,1008).convert('RGB').save(f'{OUT}/preview/en/{cid}.webp','WEBP',quality=82)
# 2) frame: one for all, transparent window
frame_svg=W.format(vb='0 0 240 403',w=600,h=1008,b=frame_rest)
png(frame_svg,600,1008).save(f'{OUT}/frame/frame.png',optimize=True)
open(f'{OUT}/svg/frame.svg','w').write(frame_svg)
# 3) back, thumbnail frame from the layers page
L=open(f'{SRC}/dbofj5.html').read()
ls=re.findall(r'<svg [^>]*viewBox="0 0 240 403".*?</svg>',L,flags=re.S)
back, back_thumb, thumb_card = ls[0], ls[1], ls[6]
for svg,name,w,h in [(back,'back',600,1008),(back_thumb,'back_thumb',240,403)]:
    png(re.sub(r'width="\d+" height="\d+" ','',svg,count=1),w,h).save(f'{OUT}/back/{name}.webp','WEBP',quality=85)
open(f'{OUT}/svg/back.svg','w').write(back)
_,_,trest=split(thumb_card)
tf=W.format(vb='0 0 240 403',w=240,h=403,b=re.sub(r'<text.*?</text>','',trest.replace('</svg>','')))
png(tf,240,403).save(f'{OUT}/frame/frame_thumb.png',optimize=True)
layout={'card':{'width':240,'height':403},'art':{'x':24,'y':52,'w':192,'h':298},
 'numeral':{'font':'Playfair Display','weight':600,'size':17,'color':'#3A2412','letterSpacing':1,'baselineY':38},
 'title':{'font':'Playfair Display','weight':600,'size':15,'color':'#E6CB98','letterSpacing':2,'baselineY':373,'maxWidth':172,'uppercase':True,'trailingStop':True}}
json.dump({'layout':layout,'cards':manifest},open(f'{OUT}/manifest.json','w'),indent=1,ensure_ascii=False)
print(len(manifest),'cards')
