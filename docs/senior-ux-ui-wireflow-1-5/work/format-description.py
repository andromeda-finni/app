from pathlib import Path
import re
p=Path('outputs/tridevyatoe-quests.md');s=p.read_text(encoding='utf-8');s=re.sub(r'\|\n\n(?=\|)','|\n',s);p.write_text(s,encoding='utf-8')
print('Companion description formatted.')
