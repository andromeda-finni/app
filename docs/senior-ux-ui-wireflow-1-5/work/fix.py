from pathlib import Path
p=Path('outputs/wireflow.html')
s=p.read_text(encoding='utf-8')
s=s.replace("function go(next,data={}){message='';context=data;", "function go(next,data={}){if(S.lastSummary&&!['summary','reset'].includes(next))next='summary';message='';context=data;")
s=s.replace("const ids=S.created?['home'", "const ids=S.lastSummary?['summary']:S.created?['home'")
s=s.replace("returnTo=screen==='reset'?'home':screen;go('reset');", "returnTo=screen==='reset'?'home':screen==='parent'?'gate':screen;go('reset');")
s=s.replace("${S.level===3?' Все стадии открыты.':''}", "${S.level===3?' Все стадии открыты.':''}")
p.write_text(s,encoding='utf-8')
