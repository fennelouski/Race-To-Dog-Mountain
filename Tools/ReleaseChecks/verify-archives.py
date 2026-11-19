#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,plistlib,subprocess,sys
root=Path(__file__).resolve().parents[2];base=root/'build/release-20261117';results=[];failed=False
parser=argparse.ArgumentParser()
parser.add_argument('--variant')
parser.add_argument('--build')
args=parser.parse_args()
catalog=json.loads((root/'Tally Tangle/Localizable.xcstrings').read_text())['strings']
required={k for k,v in catalog.items() if v.get('shouldTranslate') is not False}
for name in ['iOS','Mac','Vision','TV']:
 variant=args.variant or ('watch-gc' if name=='iOS' else 'localized')
 expected_build=args.build or ('2026111803' if name=='iOS' else '2026111802')
 archive=base/f'Tally-{name}-{variant}.xcarchive'
 if not (archive/'Info.plist').exists():
  results.append({'platform':name,'archive':str(archive.relative_to(root)),'ready':False,'reason':'Archive not available'});failed=True;continue
 info=plistlib.loads((archive/'Info.plist').read_bytes());app=archive/'Products'/info['ApplicationProperties']['ApplicationPath'];resources=app/'Contents/Resources' if (app/'Contents').exists() else app
 pl=app/'Contents/Info.plist' if (app/'Contents').exists() else app/'Info.plist';d=plistlib.loads(pl.read_bytes())
 signature=subprocess.run(['codesign','--verify','--deep','--strict',str(app)],capture_output=True).returncode==0
 languages=sorted(p.stem for p in resources.glob('*.lproj') if p.stem!='Base')
 binary=app/('Contents/MacOS' if (app/'Contents').exists() else '')/d['CFBundleExecutable']
 symbols=sorted(p.name for p in (archive/'dSYMs').glob('*.dSYM'))
 am_file=resources/'am.lproj/Localizable.strings'
 am=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(am_file)])) if am_file.exists() else {}
 am_complete=all(am.get(k)==catalog[k]['localizations']['am']['stringUnit']['value'] for k in required)
 ready=signature and d.get('CFBundleShortVersionString')=='2.3' and d.get('CFBundleVersion')==expected_build and d.get('ITSAppUsesNonExemptEncryption') is False and am_complete
 entitlements=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(app)],stderr=subprocess.DEVNULL))
 game_center=entitlements.get('com.apple.developer.game-center') is True
 ready=ready and (not game_center if name=='TV' else game_center)
 watch_gc=None;watch_gamekit=None
 if name=='iOS':
  watch=next((app/'Watch').glob('*.app'))
  watch_info=plistlib.loads((watch/'Info.plist').read_bytes())
  watch_entitlements=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements',':-',str(watch)],stderr=subprocess.DEVNULL))
  watch_gc=watch_entitlements.get('com.apple.developer.game-center') is True
  watch_gamekit='/GameKit.framework/GameKit' in subprocess.check_output(['otool','-L',str(watch/watch_info['CFBundleExecutable'])],text=True)
  ready=ready and watch_gc and watch_gamekit
 if name=='TV':ready=ready and bool(d.get('TVTopShelfImage',{}).get('TVTopShelfPrimaryImageWide'))
 upload_log=base/f'{name.lower()}-{variant}-upload.log'
 uploaded=upload_log.exists() and '** EXPORT SUCCEEDED **' in upload_log.read_text()
 results.append({'platform':name,'archive':str(archive.relative_to(root)),'ready':ready,'version':d.get('CFBundleShortVersionString'),'build':d.get('CFBundleVersion'),'signatureVerified':signature,'nonExemptEncryption':d.get('ITSAppUsesNonExemptEncryption'),'gameCenterEntitlement':game_center,'watchGameCenterEntitlement':watch_gc,'watchLinksGameKit':watch_gamekit,'compiledLocales':languages,'compiledAmharicKeys':len(am),'compiledAmharicMatchesCatalog':am_complete,'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'dSYMs':symbols,'topShelf':d.get('TVTopShelfImage'),'uploadSucceeded':uploaded});failed|=not ready
(root/'Release/Readiness/archive-audit.json').write_text(json.dumps(results,indent=2)+'\n')
for r in results:print(r['platform'], 'READY' if r['ready'] else 'NOT READY')
sys.exit(failed)
