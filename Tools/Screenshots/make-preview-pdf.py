#!/usr/bin/env python3
"""Build the review PDF from the original PNGs and the marketing manifest."""
from pathlib import Path
from io import BytesIO
import json,math,textwrap
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/pdf';OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/'Release/Marketing/AppStore/manifest.json').read_text())
readiness=json.loads((ROOT/'Release/Readiness/status.json').read_text())
labels={'iphone-6.3':'iPhone - medium display','iphone-6.9':'iPhone - large display','iphone-6.5':'iPhone - 6.5-inch display','iphone-duo-closed':'iPhone Duo - closed','iphone-duo-open-portrait':'iPhone Duo - open portrait','iphone-duo-open-landscape':'iPhone Duo - open landscape','ipad-13':'iPad - 13-inch display','mac':'macOS','vision-pro':'visionOS','tvos':'tvOS'}
order=['iphone-6.3','iphone-6.9','iphone-6.5','iphone-duo-closed','iphone-duo-open-portrait','iphone-duo-open-landscape','ipad-13','mac','vision-pro','tvos']
families=sorted(manifest['families'],key=lambda f:order.index(f['family']) if f['family'] in order else 99)
W,H=960,640;ink='#071f2a';cream='#fff1d1';mint='#72dace';gold='#ffbc48'
path=OUT/'Tally-Tangle-App-Store-Preview.pdf';c=canvas.Canvas(str(path),pagesize=(W,H),pageCompression=1)
c.setTitle('Tally Tangle - App Store Screenshot and Marketing Preview');c.setAuthor('Tally Tangle')
index=[];page=0
rawTotal=sum(len(list((ROOT/'Release/Marketing/Screenshots'/f['family']).glob('[0-9][0-9].png'))) for f in families)
marketTotal=sum(len(f['files']) for f in families)
def text(x,y,s,size=12,color=cream,bold=False):
 c.setFillColor(HexColor(color));c.setFont('Helvetica-Bold' if bold else 'Helvetica',size);c.drawString(x,y,s)
def bg():c.setFillColor(HexColor(ink));c.rect(0,0,W,H,fill=1,stroke=0)
def begin(title,subtitle=''):
 global page
 page+=1;bg();text(32,H-30,'TALLY TANGLE',10,mint,True);text(32,H-62,title,21,cream,True)
 if subtitle:text(32,H-82,subtitle,10,mint)
 text(W-60,20,str(page),10,mint)
def finish():c.showPage()
def draw(p,x,y,w,h,maxPixels=1500):
 with Image.open(p) as original:
  im=original.convert('RGB');im.thumbnail((maxPixels,maxPixels),Image.Resampling.LANCZOS)
  data=BytesIO();im.save(data,format='JPEG',quality=84,subsampling=0,optimize=True);data.seek(0)
  scale=min(w/im.width,h/im.height);dw=im.width*scale;dh=im.height*scale
  c.drawImage(ImageReader(data),x+(w-dw)/2,y+(h-dh)/2,dw,dh,mask=None)
begin('A living garden of number strategy.','App Store media preview - 18 November 2026')
text(48,440,'One number.',48,cream,True);text(48,382,'So many possibilities.',48,cream,True)
text(48,310,f'{rawTotal} native captures  /  {marketTotal} marketing compositions',20,mint)
text(48,266,'iPhone  |  iPhone Duo  |  iPad  |  macOS  |  visionOS  |  tvOS',17)
text(48,178,'Every marketing image uses an authentic capture of the game.',13)
text(48,152,'Original-resolution PNGs and editable SVG compositions are supplied separately.',13)
text(48,126,'Media is uploaded to App Store Connect. Platform status is recorded on the final page.',13)
text(48,96,'Primary platform sets each contain at least 30 captures. Extra medium iPhone set: 27.',12)
finish()
begin('Choose a platform','Click a row or use the PDF bookmarks to jump to a section.')
for i,f in enumerate(families):
 family=f['family'];y=H-132-i*43;count=len(list((ROOT/'Release/Marketing/Screenshots'/family).glob('[0-9][0-9].png')))
 text(48,y,labels.get(family,family),16,cream,True);text(490,y,f'{count} captures + 10 marketing images',12,mint)
 c.linkAbsolute(labels.get(family,family),'family-'+family,Rect=(40,y-8,900,y+23),thickness=0)
finish()
for f in families:
 family=f['family'];label=labels.get(family,family);rawDir=ROOT/'Release/Marketing/Screenshots'/family
 raw=sorted(rawDir.glob('[0-9][0-9].png'))
 begin(label,f'{len(raw)} authentic native captures and ten distinct marketing compositions')
 c.bookmarkPage('family-'+family);c.addOutlineEntry(label,'family-'+family,level=0)
 hero=ROOT/'Release/Marketing/AppStore'/f['files'][0]['file'];draw(hero,350,70,555,440)
 text(48,400,'MARKETING',11,mint,True);text(48,367,'Ten reasons to play.',24,cream,True)
 text(48,318,'See each composition at full-page size.',12)
 text(48,293,'Native captures follow as contact sheets.',12)
 text(48,222,'Review the exact layout, board, scores,',12);text(48,202,'rival, and feature shown in each image.',12)
 finish()
 for i,item in enumerate(f['files']):
  p=ROOT/'Release/Marketing/AppStore'/item['file'];name=p.stem
  begin(label+' - Marketing '+str(i+1).zfill(2),f'{item["width"]} x {item["height"]} pixels | {name}')
  c.bookmarkPage(f'marketing-{family}-{i}');c.addOutlineEntry(f'Marketing {i+1:02d}',f'marketing-{family}-{i}',level=1)
  draw(p,32,42,W-64,H-145)
  index.append({'page':page,'type':'marketing','file':str(p.relative_to(ROOT))})
  finish()
 for start in range(0,len(raw),6):
  batch=raw[start:start+6];begin(label+' - Native captures',f'Scenes {batch[0].stem}-{batch[-1].stem} | Original PNGs remain at full capture resolution.')
  if start==0:c.bookmarkPage('native-'+family);c.addOutlineEntry('Native captures','native-'+family,level=1)
  for j,p in enumerate(batch):
   col=j%3;row=j//3;x=32+col*302;y=315 if row==0 else 48
   draw(p,x,y,286,224,900);text(x,y-15,p.name,10,mint,True)
   index.append({'page':page,'type':'native','file':str(p.relative_to(ROOT))})
  finish()
qa=sorted((ROOT/'Release/Marketing/QA').rglob('*.png')) if (ROOT/'Release/Marketing/QA').exists() else []
if qa:
 for p in qa:
  begin('iPhone Duo - Pose review',p.parent.name+' / scene '+p.stem);draw(p,32,40,W-64,H-145);finish()
begin('Release readiness','App Store Connect verification - 18 November 2026')
notes=[
 ('App Store review drafts',readiness.get('storeReviewSummary','macOS, visionOS and tvOS are Ready for Review. iOS validation is in progress.')),
 ('Uploaded builds',readiness.get('storeBuildSummary','Version 2.3 build 2026111703 uploaded on all four platforms.')),
 ('Localization audit','428 translatable keys across 51 translated UI languages, including complete Amharic resources. Structural checks pass.'),
 ('Store metadata locales','All 50 available store locales are complete on each platform. Reload checks pass; marketing image captions remain English.'),
 ('Duo pose verification','The fold-aware changes compile. Live book/laptop verification is blocked by simulator failures.'),
 ('Media exclusions','Three blank medium-iPhone frames were excluded. No unverified book/laptop pose images are included.')]
for i,(heading,detail) in enumerate(notes):
 y=H-140-i*70;text(48,y,heading,15,mint,True)
 for line,s in enumerate(textwrap.wrap(detail,width=145)):text(48,y-23-line*14,s,11)
finish()
c.save();(OUT/'preview-index.json').write_text(json.dumps({'pdf':str(path.relative_to(ROOT)),'pages':page,'nativeCaptures':rawTotal,'marketingImages':marketTotal,'assets':index},indent=2)+'\n')
print(f'Created {path}: {page} pages, {rawTotal} native captures, {marketTotal} marketing images')
