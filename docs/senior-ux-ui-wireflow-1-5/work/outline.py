from pathlib import Path
for name in ['brief','project']:
 t=Path('work/'+name+'.txt').read_text(encoding='utf-8')
 pages=t.split('--- PAGE ')
 for p in pages[1:]:
  lines=p.splitlines()
  print(name,lines[0], ' '.join(lines[1:])[:240])
