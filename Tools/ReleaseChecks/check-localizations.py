#!/usr/bin/env python3
"""Audit every declared UI language and literal UI key without treating fallback as translation."""
from pathlib import Path
import collections,json,re,sys
root=Path(__file__).resolve().parents[2]
catalog=json.loads((root/'Tally Tangle/Localizable.xcstrings').read_text())
strings=catalog['strings'];locales=sorted({l for e in strings.values() for l in e.get('localizations',{}) if l!='en'})
placeholder=re.compile(r'%(?:\d+\$)?(?:[-+0 #]*\d*(?:\.\d+)?)(lld|llu|ld|lu|d|u|@|f|g|s)')
def formats(s):return collections.Counter(placeholder.findall(s.replace('%%','')))
def units(v):
 if isinstance(v,dict):
  if 'stringUnit' in v:yield v['stringUnit']
  for k,item in v.items():
   if k!='stringUnit':yield from units(item)
issues=[];coverage={l:collections.Counter() for l in locales}
for key,e in strings.items():
 if e.get('shouldTranslate') is False:continue
 for locale in locales:
  us=list(units(e.get('localizations',{}).get(locale,{})))
  if not us:coverage[locale]['missing']+=1;issues.append({'key':key,'locale':locale,'problem':'missing'})
  elif any(u.get('state')!='translated' or not u.get('value','').strip() for u in us):
   coverage[locale]['incomplete']+=1;issues.append({'key':key,'locale':locale,'problem':'incomplete'})
  else:coverage[locale]['translated']+=1
  if us and 'variations' not in e:
   for u in us:
    if formats(u.get('value',''))!=formats(key):issues.append({'key':key,'locale':locale,'problem':'format placeholders differ','value':u.get('value')})
# This catches newly introduced literal labels that a total-key check would miss.
pattern=re.compile(r'(?:Text|Button|Label|Toggle|Picker|Section|TextField|CommandMenu|ContentUnavailableView|confirmationDialog|alert|navigationTitle|accessibilityLabel|accessibilityHint|help)\(\s*"([^"\n]*)"|String\(localized:\s*"([^"\n]*)"')
unknown=[]
for folder in ['Tally Tangle','Mac','Vision','Watch','Messages','TV']:
 for p in (root/folder).glob('*.swift'):
  source=p.read_text()
  for m in pattern.finditer(source):
   key=m.group(1) if m.group(1) is not None else m.group(2)
   if '\\(' in key or not re.search('[A-Za-z]',key):continue
   if key not in strings:unknown.append({'key':key,'file':str(p.relative_to(root)),'line':source.count('\n',0,m.start())+1})
report={'sourceLanguage':catalog['sourceLanguage'],'translatedLanguageCount':len(locales),'catalogKeyCount':len(strings),'translatableKeyCount':sum(e.get('shouldTranslate') is not False for e in strings.values()),'coverage':coverage,'issues':issues,'uncataloguedLiteralUI':unknown,'scopeNotes':['English is the source language. Regional variants use the closest supported language through Foundation fallback.','InfoPlist.xcstrings preserves the Tally Tangle brand across languages; UI coverage is verified independently.','Structural checks do not establish linguistic quality or rendered RTL, large-text, or physical-device usability.','App Store metadata is audited separately against app-store-metadata-localized.json and saved Connect fields. Shared primary-language marketing images are reused unless a locale has custom media.']}
out=root/'Release/Readiness/localization-audit.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f'{len(locales)} languages, {report["translatableKeyCount"]} translatable keys; {len(issues)} catalog issues; {len(unknown)} uncatalogued literal labels.')
for issue in (issues+unknown)[:15]:print(issue)
sys.exit(bool(issues or unknown))
