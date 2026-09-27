from pathlib import Path
p=Path('work/project.txt').read_text(encoding='utf-8').split('--- PAGE ')
for n in [7,8,9,10,26,27,28]: print('--- PAGE '+p[n])
