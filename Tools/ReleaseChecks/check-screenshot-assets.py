#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageStat
import hashlib,json,collections,sys
root=Path(__file__).resolve().parents[2]
sizes={'iphone-6.3':(1206,2622),'iphone-6.5':(1242,2688),'iphone-6.9':(1320,2868),'iphone-duo-closed':(1398,2034),'iphone-duo-open-landscape':(2853,2007),'iphone-duo-open-portrait':(2007,2853),'ipad-13':(2064,2752),'mac':(2560,1600),'vision-pro':(3840,2160),'tvos':(1920,1080)}
required={'iphone-6.9','iphone-duo-closed','ipad-13','mac','vision-pro','tvos'}
report={'families':[],'issues':[],'additionalIncompleteFamilies':[]}
for family,size in sizes.items():
 files=sorted((root/'Release/Marketing/Screenshots'/family).glob('[0-9][0-9].png'));rows=[];hashes=collections.defaultdict(list)
 for p in files:
  with Image.open(p) as im:
   actual=im.size;mode=im.mode;im=im.convert('RGB');im.thumbnail((96,96));stats=ImageStat.Stat(im);thumbHash=hashlib.sha256(im.tobytes()).hexdigest()
  digest=hashlib.sha256(p.read_bytes()).hexdigest();hashes[thumbHash].append(p.name)
  if actual!=size:report['issues'].append({'file':str(p.relative_to(root)),'issue':'unexpected dimensions','actual':actual,'expected':size})
  if sum(stats.mean)/3<8:report['issues'].append({'file':str(p.relative_to(root)),'issue':'suspected blank frame','mean':stats.mean})
  rows.append({'file':str(p.relative_to(root)),'width':actual[0],'height':actual[1],'mode':mode,'sha256':digest})
 missing=[f'{n:02}.png' for n in range(1,31) if not any(p.name==f'{n:02}.png' for p in files)]
 if missing:
  entry={'family':family,'issue':'missing scenes','scenes':missing}
  (report['issues'] if family in required else report['additionalIncompleteFamilies']).append(entry)
 duplicates=[v for v in hashes.values() if len(v)>1]
 if duplicates:report['issues'].append({'family':family,'issue':'identical preview pixels','files':duplicates})
 report['families'].append({'family':family,'count':len(files),'files':rows})
 print(f'{family}: {len(files)} captures',flush=True)
report['nativeCaptureCount']=sum(f['count'] for f in report['families']);report['passed']=not report['issues'];report['allDisplayVariantsComplete']=not report['additionalIncompleteFamilies']
(root/'Release/Readiness/screenshot-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['issues'],indent=2));sys.exit(not report['passed'])
