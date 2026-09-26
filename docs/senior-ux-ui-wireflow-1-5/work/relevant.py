from pathlib import Path
for name,nums in [('brief',[6,7,8,17]),('project',[20,21,22,23,24,25,26,27,28])]:
 pages=Path('work/'+name+'.txt').read_text(encoding='utf-8').split('--- PAGE ')
 for n in nums: print(name+' PAGE '+pages[n])
