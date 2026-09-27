from pathlib import Path
p=Path('outputs/wireflow.html')
s=p.read_text(encoding='utf-8').replace('font-size:22px;white-space:pre;text-align:center','font-size:16px;white-space:pre-wrap;text-align:center')
s=s.replace("Удачных дней: ${S.goodDays}. Следующая стадия — после ${S.level===1?2:4} удачных дней.${S.level===3?' Все стадии открыты.':''}","Удачных дней: ${S.goodDays}. ${S.level===3?'Все стадии открыты.':'Следующая стадия — после '+(S.level===1?2:4)+' удачных дней.'}")
s=s.replace("${p.cat==='need'?'Купить и накормить':'Всё равно купить'}", "${p.cat==='need'?'Купить и накормить':'Купить'}")
p.write_text(s,encoding='utf-8')
