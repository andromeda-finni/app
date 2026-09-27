from pathlib import Path
import json,re
p=Path('outputs/wireflow.html')
s=p.read_text(encoding='utf-8')
Path('work/wireflow-v01.html').write_text(s,encoding='utf-8')
d=json.loads(Path('work/content-v02.json').read_text(encoding='utf-8'))
def replace(old,new):
    global s
    assert old in s,old[:150]
    s=s.replace(old,new)
s=re.sub(r'const goals=\[.*?\];', 'const goals='+json.dumps(d['artifacts'],ensure_ascii=False)+';\nconst stories='+json.dumps(d['quests'],ensure_ascii=False)+';',s,count=1)
replace('Wireflow v0.1','Wireflow v0.2')
replace('>v0.1<','>v0.2<')
replace('Числа и правила v0.1','Числа и правила v0.2')
replace('<button class="small" onclick="requestReset()">','<button class="small" onclick="openPreview(\'kingdom\')">Тридевятое · обзор</button><button class="small" onclick="openPreview(\'catalog\')">Артефакты</button><button class="small" onclick="requestReset()">')
replace("!['summary','reset'].includes(next)","!['summary','reset',...previewScreens].includes(next)")
replace('const meta={',"const meta={\n catalog:['20','Витрина артефактов','Семь целей, цены, статусы и назначение.','Подробнее → карточка; выбор цели → план или копилка.'],\n artifactDetail:['21','Карточка артефакта','Эффект, цена, условия, связанный квест.','Выбрать целью → копилка; связанный герой → описание квеста.'],\n kingdom:['22','Тридевятое царство','Пять мест и пять персонажей; обзор доступен до покупки сапог.','Герой → о квесте → шаги → исход → карта.'],\n questBrief:['23','О квесте','Герой, тема, ситуация, маршрут задания.','Посмотреть прохождение → первый шаг; назад → карта.'],\n questWalk:['24','Шаг квеста','Ситуация, действие ребёнка и будущий UI.','Следующий шаг → выбор исхода; назад → предыдущий шаг.'],\n questBranch:['25','Исход квеста','Удачный выбор или затруднение с восстановлением.','Повтор → шаг выбора; другая ветка → альтернативный исход; карта → персонажи.'],")
replace("S.created&&!['summary','reset','create'].includes(screen)","S.created&&!S.lastSummary&&!['summary','reset','create'].includes(screen)")
replace("['home','plan','forest','shop','savings','finish','progress','gate']","['home','plan','forest','kingdom','shop','catalog','savings','finish','progress','gate']")
replace("case 'welcome':return", "case 'catalog':return drawCatalog();\ncase 'artifactDetail':return drawArtifactDetail();\ncase 'kingdom':return drawKingdom();\ncase 'questBrief':return drawQuestBrief();\ncase 'questWalk':return drawQuestWalk();\ncase 'questBranch':return drawQuestBranch();\ncase 'welcome':return")
replace('Все три артефакта собраны','Все семь артефактов собраны')
replace("${button('Завершить день',\"go('finish')\")}</div><div class=\"row wrap\">", "${button('Витрина артефактов',\"go('catalog')\")}${button(S.owned.includes('boots')?'Путешествие в Тридевятое':'Посмотреть Тридевятое','openKingdom()')}${button('Завершить день',\"go('finish')\")}</div><div class=\"row wrap\">")
replace("case 'forest':return `<h1>","case 'forest':if(S.location==='Тридевятое царство')return drawKingdom();return `<h1>")
replace("Локация открыта. Здесь новые сюжеты с теми же тремя темами.","Локация открыта: Рыбка, Морозко, Раджа, Мужик и Купец ждут тебя.")
replace("Откроется, когда получишь Сапоги-скороходы.","Путешествие откроют Сапоги-скороходы. Карту пяти приключений можно посмотреть уже сейчас.")
replace("${button(S.location==='Лес'?'Перейти в царство':'Вернуться в лес','changeLocation()',false,!S.owned.includes('boots'))}","${button(S.owned.includes('boots')?'Перейти в царство':'Посмотреть карту','openKingdom()')}")
replace('<label for="goalSelect">Твоя цель</label>',"<div class=\"stack\">${button('Открыть витрину артефактов',\"go('catalog')\")}</div><label for=\"goalSelect\">Твоя цель</label>")
replace('<div class="box">${g.effect}</div><div class="stack">', '<div class="box">${g.effect}</div>${!g.live?info(\'Артефакт появится в коллекции. Особый эффект пока показан только описанием.\'):\'\'}<div class="stack">')
replace("button('Получить и применить','claimArtifact()'", "button(g.live?'Получить и применить':'Получить в коллекцию','claimArtifact()'")
replace("message=`Ты получил «${g.name}»! ${g.effect}`;render();", "message=`Ты получил «${g.name}»! ${g.live?g.effect:'Артефакт в коллекции; особый эффект пока не включён.'}`;render();")
replace('Допущения v0.1','Допущения текущего демо')
replace('Артефакты стоят 30 / 50 / 70 для быстрого теста.', 'В витрине семь артефактов. Демо-цены: скатерть 20, вода 25, клубок 35, щит 40, гусли 30, терем 50, сапоги 70. Полные цены из наработок видны в пояснении карточки.')
replace('Новая локация пока меняет сюжет задач, не добавляет отдельную механику.', 'Тридевятое содержит пять отдельных сценариев с персонажами и ветками; их полноценные мини-игры пока не реализованы.')
replace('три товара, три цели и неограниченное число дней', 'три товара, семь целей и неограниченное число дней')
replace("['Карта заданий','Заголовок: Лес / Царство','Контент: три темы, выполненные задания, локация','CTA: Открыть задание','Нет плана → [План бюджета]; задание → [Задание]; есть сапоги → новая локация']", "['Карта заданий','Заголовок: Лес','Контент: три коротких задания и вход в Тридевятое','CTA: Открыть задание / карту царства','Нет плана → [План бюджета]; задание → [Задание]; царство → [Пять персонажей]']")
css='''
.artifact-card{display:grid;grid-template-columns:86px 1fr;gap:14px;border:1px solid #aaa;padding:14px;margin:14px 0}.artifact-mark{border:1px dashed #999;display:flex;align-items:center;justify-content:center;text-align:center;font-size:12px;overflow-wrap:anywhere;background:#f3f3f3}.artifact-card h2{margin:6px 0;font-size:17px}.artifact-card button{width:100%}.kingdom-path{border-left:2px dashed #999;margin:22px 0 22px 15px;padding-left:22px}.quest-stop{position:relative;border:1px solid #aaa;background:#fafafa;margin:0 0 18px;padding:14px}.stop-number{position:absolute;left:-40px;top:18px;width:28px;height:28px;border:1px solid #777;border-radius:50%;text-align:center;line-height:26px;background:white;font-size:13px}.quest-stop h2{margin:7px 0}.quest-stop p{font-size:14px}.quest-stop button{width:100%;text-align:left}.pet{overflow-wrap:anywhere;padding:10px}.tabs{max-width:750px} .rules h2{font-size:20px}
'''
replace('</style>',css+'</style>')
replace('render();\n</script>',Path('work/views-v02.js').read_text(encoding='utf-8')+'\nrender();\n</script>')
p.write_text(s,encoding='utf-8')
md=['# Тридевятое царство и витрина артефактов','Версия 0.2. Дополнение к кликабельному wireflow.','Источник: «Лучше Црезвоньте Толу 2026.pdf», игровые механики на страницах PDF 8–9, цели на 26–28. Персонажи, темы и артефакты взяты из файла; конкретные шаги, числа учебных сцен и безопасные ветки восстановления — предложения для согласования.','## Путь в локацию','[Лес / Домик] -- (посмотреть карту) --> [Тридевятое: пять персонажей] -- (выбрать героя) --> [О квесте] -- (посмотреть прохождение) --> [Шаги] -- (выбрать ветку) --> [Удачный исход / Затруднение] -- (вернуться) --> [Карта].','До получения сапог доступен обзор. Сапоги открывают путешествие. Сюжетные мини-игры пока представлены пошаговыми описаниями; учебные суммы и предполагаемые награды не меняют кошелёк.','## Витрина','[Витрина] -- (подробнее) --> [Карточка артефакта] -- (выбрать целью) --> [План / Копилка] -- (накоплена сумма и подтверждено получение) --> [Артефакт в коллекции].','Демо-цены сокращены для быстрой проверки. Цены из файла сохранены отдельно; прежние монеты и полученные артефакты не сбрасываются.','| Артефакт | Цена в демо | Цена в файле | Назначение |','|---|---:|---:|---|']
for a in d['artifacts']:md.append(f"| {a['name']} | {a['cost']} | {a['sourceCost']} | {a['theme']} |")
for a in d['artifacts']:md += [f"### {a['name']}",a['effect'],a['note']]
for q in d['quests']:
 md += [f"## {q['hero']} — {q['title']}",f"**Тема:** {q['theme']}.",f"**Роль:** {q['role']}",f"**Происхождение:** {q['source']}",f"> {q['quote']}"]
 for i,st in enumerate(q['steps'],1):md += [f"### Шаг {i}. {st['title']}",st['body'],f"**Действие:** {st['action']}",f"**UI:** {st['ui']}"]
 md += ['**Удачный исход:** '+q['good'],'**Затруднение:** '+q['bad'],'**Исправление:** '+q['recovery'],'**Награда:** '+q['reward'],'**Адаптация:** '+q['adapt']]
md += ['## UX-риски','1. Обзор можно принять за готовую мини-игру. Вход, шаги и исходы помечены как просмотр, награды не начисляются.','2. Скатерть и автоматический щит могут убрать учебный выбор. Бесплатная еда не включена до согласования, для щита предложена подсказка вместо автоматического отказа.','3. Учебные суммы можно спутать с основным балансом. Сценарии используют отдельный условный бюджет, основная экономика не меняется.']
Path('outputs/tridevyatoe-quests.md').write_text('\n\n'.join(md),encoding='utf-8')
print('Updated wireflow v0.2; 7 artifacts, 5 quest storyboards; saved companion description.')
