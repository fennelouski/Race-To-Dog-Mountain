from pathlib import Path
import subprocess,json,hashlib,datetime,traceback,plistlib,signal,time,shutil
root=Path('/Users/nathan/Documents/GitHub/Race-To-Dog-Mountain');leaf=Path(__file__).resolve().parent
udid='4051F719-157D-4697-AED1-FEFBB7E99CA1';bundle='com.nathanfennel.RacetoDogMountain'
app=Path('/tmp/racedog-native-finish-20261004/Build/Products/Debug-iphonesimulator/Race to Dog Mountain.app')
runfile=Path('/tmp/racedog-private-ui-products-20261004/Build/Products/PrivateRunner-isolated.xctestrun')
freeze=json.loads((leaf/'full-native-source-freeze.json').read_text());session=json.loads((leaf/'private-ui-session.json').read_text())
status={'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'deviceUUID':udid,'headless':True,'nativeSourceFreeze':freeze['aggregateSHA256'],'privateQA':session,'runtimeTests':[]}
def cmd(args,timeout=60):
 r=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=timeout)
 return {'command':args,'exitCode':r.returncode,'stdout':r.stdout.strip(),'stderr':r.stderr.strip()}
def write(): (leaf/'phone-runtime-status.json').write_text(json.dumps(status,indent=2)+'\n')
def verify():
 changed=[p for p,h in freeze['files'].items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=h]
 assert not changed,changed
 return True
def devices():return [dict(d,runtime=r) for r,ds in json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))['devices'].items() for d in ds if d['udid']==udid]
def production():
 container=cmd(['xcrun','simctl','get_app_container',udid,bundle,'data'])
 if container['exitCode']!=0:return {'installed':False}
 base=Path(container['stdout']);files={}
 for rel in ['Library/Preferences/'+bundle+'.plist','Library/Application Support']:
  p=base/rel
  files[rel]=hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else ({str(f.relative_to(p)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(p.rglob('*')) if f.is_file()} if p.is_dir() else None)
 return {'installed':True,'container':str(base),'files':files}
video=None;stream=None
try:
 status['sourceBeforeVerified']=verify();d=devices();assert len(d)==1 and d[0]['state']=='Shutdown' and d[0]['isAvailable'] and d[0]['name']=='Games Math QA Phone 20261003';status['beforeDevice']=d[0]
 info=plistlib.loads((app/'Info.plist').read_bytes());assert info['CFBundleIdentifier']==bundle and info['CFBundleShortVersionString']=='2.1' and info['CFBundleVersion']=='8'
 binaries=[app/'Info.plist',app/'Race to Dog Mountain',Path('/tmp/racedog-private-ui-products-20261004/Build/Products/Debug-iphonesimulator/NativeFinishUITests-Runner.app/PlugIns/NativeFinishUITests.xctest/NativeFinishUITests')]
 status['executedInputs']=[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in binaries]
 status['boot']=cmd(['xcrun','simctl','boot',udid]);assert status['boot']['exitCode']==0
 status['bootstatus']=cmd(['xcrun','simctl','bootstatus',udid,'-b']);assert status['bootstatus']['exitCode']==0
 status['appearanceBefore']=cmd(['xcrun','simctl','ui',udid,'appearance']);assert status['appearanceBefore']['stdout'].lower() in ['light','dark']
 status['productionBeforeInstall']=production()
 status['install']=cmd(['xcrun','simctl','install',udid,str(app)]);assert status['install']['exitCode']==0,status['install']
 status['productionBeforeRuntime']=production()
 base=Path(status['productionBeforeRuntime']['container']);qa=base/('Library/Preferences/'+session['suite']+'.plist');assert qa.exists(),'Must reuse genuine completed private UUID session'; existing=plistlib.loads(qa.read_bytes()); saved=json.loads(existing['mountainGames.v1']); completed=[g for g in saved if g['id']=='C7D6F881-5AB4-4BDB-84BB-3340310BB357']; assert len(completed)==1 and len(completed[0]['history']['choices'])==16 and completed[0]['game']['scores']==[69,67], 'Actual completed transcript must exist'; status['actualCompletedTranscriptBefore']=completed[0]; status['privatePreferencesBeforeSHA256']=hashlib.sha256(qa.read_bytes()).hexdigest()
 enum=['xcodebuild','test-without-building','-xctestrun',str(runfile),'-destination','platform=iOS Simulator,id='+udid,'-enumerate-tests','-test-enumeration-style','flat','-test-enumeration-format','json','-test-enumeration-output-path',str(leaf/'ui-method-enumeration.json'),'-parallel-testing-enabled','NO','-jobs','2']
 with (leaf/'ui-method-enumeration.log').open('w') as f:r=subprocess.run(enum,stdout=f,stderr=subprocess.STDOUT,timeout=60)
 status['enumerationExitCode']=r.returncode;assert r.returncode==0,'Enumeration process must succeed before reading any output'; enumerated=json.loads((leaf/'ui-method-enumeration.json').read_text());status['enumeration']=enumerated
 text=json.dumps(enumerated);assert r.returncode==0 and not enumerated.get('errors') and 'testActualNativeChooserAndObservedDismissalOnly' in text,enumerated
 status['recordingPath']=str(leaf/'phone-native-chooser-actual-ui.mp4');stream=(leaf/'phone-native-chooser-video.log').open('w');video=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=h264',status['recordingPath']],stdout=stream,stderr=subprocess.STDOUT);time.sleep(0.5)
 for name in ['testActualNativeChooserAndObservedDismissalOnly']:
  result=Path('/tmp/racedog-'+name+'-native-chooser-20261004.xcresult');assert not result.exists()
  args=['xcodebuild','test-without-building','-xctestrun',str(runfile),'-destination','platform=iOS Simulator,id='+udid,'-parallel-testing-enabled','NO','-maximum-concurrent-test-simulator-destinations','1','-maximum-parallel-testing-workers','1','-jobs','2','-only-testing:NativeFinishUITests/NativeFinishUITests/'+name,'-resultBundlePath',str(result),'-quiet']
  item={'method':name,'command':args,'resultBundle':str(result),'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()};status['runtimeTests'].append(item);write();print('START',name,flush=True)
  with (leaf/(name+'.log')).open('w') as f:
   try:item['exitCode']=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,timeout=240).returncode
   except subprocess.TimeoutExpired:item['exitCode']='timeout'
  item['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat();write();print('END',name,item['exitCode'],flush=True)
  if item['exitCode']!=0:break
 status['sourceAfterVerified']=verify();status['productionAfterRuntime']=production()
 assert status['productionBeforeRuntime']['files']==status['productionAfterRuntime']['files'],'Production storage changed'
 if qa.exists():
  shutil.copy2(qa,leaf/'actual-private-QA-preferences.plist');status['privatePreferencesSHA256']=hashlib.sha256(qa.read_bytes()).hexdigest()
 exports=[]
 for f in base.glob('tmp/mountain-share-*/*'):
  if f.is_file():
   target=leaf/f.parent.name/f.name;target.parent.mkdir(exist_ok=True);shutil.copy2(f,target);exports.append({'path':str(target),'size':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
 status['actualExportFiles']=exports
except Exception as e:
 status['exception']=str(e);status['traceback']=traceback.format_exc();print('ERROR',str(e),flush=True)
finally:
 if video:
  video.send_signal(signal.SIGINT)
  try:status['videoExitCode']=video.wait(timeout=15)
  except subprocess.TimeoutExpired:status['videoStopTimeout']=True
  stream.close()
 status['appearanceBeforeShutdown']=cmd(['xcrun','simctl','ui',udid,'appearance'])
 status['appearancePreserved']=status['appearanceBeforeShutdown']['stdout']==status.get('appearanceBefore',{}).get('stdout')
 status['shutdown']=cmd(['xcrun','simctl','shutdown',udid]);status['afterDevice']=devices()[0]
 status['appearanceAfterShutdown']=cmd(['xcrun','simctl','ui',udid,'appearance']);status['finishedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat();write()
 print('FINAL',status['afterDevice']['state'],status['appearanceBeforeShutdown']['stdout'],flush=True)
