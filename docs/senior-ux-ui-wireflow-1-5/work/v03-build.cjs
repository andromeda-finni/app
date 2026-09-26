const fs = require('fs');

if (!fs.existsSync('work/wireflow-v02.html')) {
  throw new Error('work/wireflow-v02.html must exist as base for v0.2');
}
const baseV02 = fs.readFileSync('work/wireflow-v02.html', 'utf8');
const cssMatch = baseV02.match(/<style>([\s\S]*?)<\/style>/);
const baseCss = cssMatch ? cssMatch[1] : '';

const content = JSON.parse(fs.readFileSync('work/content-v02.json', 'utf8'));
const goals = content.artifacts;
const stories = content.quests;
const fox = stories.find(q => q.id === 'merchant');
fox.hero = 'Хитрый лис';
fox.source = 'Проект, с. 9: тема 5, защита от мошенничества. По решению команды возвращён Хитрый лис.';
for (const step of fox.steps) {
  step.body = step.body.replaceAll('Купец', 'Лис').replaceAll('Купца', 'Лиса').replaceAll('купец', 'лис');
  step.action = step.action.replaceAll('Купца', 'Лиса');
}
fox.bad = fox.bad.replaceAll('Купец', 'Лис');
stories.find(q => q.id === 'raja').artifact = 'water';
for (const q of stories) q.reward = 'За прохождение: 10 / 20 / 30 монет по сложности, один раз в день. Связанный артефакт выдаётся один раз.';
for (const a of goals) {
  a.quest = stories.find(q => q.artifact === a.id)?.id || null;
  if (a.id === 'clew') {
    a.effect = 'В задумке: помогает осваивать более сложные задания.';
    a.note = 'Эффект клубка пока описан. Сложность заданий в демо выбирается в настройках.';
  }
  if (a.id === 'boots') {
    a.effect = 'В задумке: открывают новые области карты.';
    a.note = 'Пять квестов доступны сразу. Новая область за сапоги — следующая итерация.';
    a.live = false;
  }
}

const switcherCss = `.version-switch{display:inline-flex;align-items:center;gap:4px;background:#e7e7e4;border:1px solid #c2c2bf;padding:3px 6px;border-radius:7px}
.version-label{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.6px;color:#555;margin-right:3px}
.version-pill{display:inline-flex;align-items:center;gap:5px;padding:5px 11px;border-radius:4px;font-size:13px;font-weight:600;text-decoration:none;border:1px solid transparent;color:#333;background:transparent;cursor:pointer;line-height:1.2;transition:all .15s ease}
.version-pill:hover{background:#d8d8d3;color:#111}
.version-pill.active{background:#2b2b2b;color:#fff;border-color:#2b2b2b;cursor:default}
.badge-new{display:inline-block;background:#2e7d32;color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:1px 5px;text-transform:uppercase;letter-spacing:.3px;line-height:1.1}
.version-pill.active .badge-new{background:#4ade80;color:#064e3b}
@media(max-width:850px){.top{flex-wrap:wrap;gap:14px}}
@media(max-width:660px){.version-switch{order:2;width:100%;justify-content:center}.tabs{order:3;width:100%;justify-content:center}}`;

const extraV03Css = `.money{display:block;font-size:25px;margin-top:5px}.pet-button{width:100%;flex-direction:column}.stat-bar{margin:20px 0}.stat-bar>div:first-child{display:flex;justify-content:space-between;font-size:14px}.stat-bar .progress{height:14px}.quest-hero{height:410px;border:1px dashed #888;background:#f2f2f2;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;text-align:center;padding:24px}.spotlight{outline:3px solid #444;outline-offset:2px;background:white}.tour-preview{padding:10px;background:#f2f2f2}.screen .switch-row{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #ccc;padding:12px 0}.screen .switch-row input{width:24px;min-height:24px;height:24px}.large-text .screen p,.large-text .screen label,.large-text .screen button,.large-text .screen input,.large-text .screen select{font-size:18px}.screen table{table-layout:fixed;overflow-wrap:anywhere}.screen .row h1{flex:2}.nav:empty{display:none}.screen button{overflow-wrap:anywhere}.phone-head{gap:12px}.phone-head span:last-child{white-space:nowrap}@media(max-width:660px){.quest-hero{height:370px}.screen{padding:18px}.large-text .nav button{font-size:13px}}`;

const buildV02Html = (v03Target) => {
  let h = baseV02;
  h = h.replace('</style>', `${switcherCss}\n</style>`);
  const oldHeader = /<header class="top">[\s\S]*?<\/header>/;
  const newHeader = `<header class="top"><div><div class="brand">Грошик / Wireflow <span class="muted">v0.2</span></div><div class="muted">Черновая логика · деморежим · без ожидания времени</div></div><div class="version-switch" role="group" aria-label="Выбор версии wireflow"><span class="version-label">Версия:</span><span class="version-pill active" aria-current="page">v0.2</span><a href="${v03Target}" class="version-pill" onclick="switchWireflowVersion('0.3', event)" title="Перейти к новой версии 0.3">v0.3 <span class="badge-new">новая</span></a></div><div class="tabs"><button id="prototypeTab" class="small active" onclick="view('prototype')">Прототип</button><button id="flowTab" class="small" onclick="view('flow')">Схема и правила</button><button class="small" onclick="openPreview('kingdom')">Тридевятое · обзор</button><button class="small" onclick="openPreview('catalog')">Артефакты</button><button class="small" onclick="requestReset()">Начать заново</button></div></header>`;
  h = h.replace(oldHeader, newHeader);
  h = h.replace('Прогресс сохраняется в этом браузере.', '<strong>Версия 0.2:</strong> базовый интерактивный wireflow. В шапке доступен переключатель на <strong>v0.3</strong> с новыми сценариями команды. Прогресс сохраняется в этом браузере.');
  const switcherJsV02 = `const CURRENT_VERSION='0.2';\nfunction switchWireflowVersion(targetVer,e){if(e&&e.preventDefault)e.preventDefault();if(typeof window==='undefined')return;const p=window.location.pathname;const isOut=p.includes('/outputs/')||p.endsWith('wireflow.html')||p.endsWith('wireflow-v02.html')||p.endsWith('wireflow-v03.html');if(targetVer==='0.2'){window.location.href=isOut?'wireflow-v02.html':'index-v02.html';}else{window.location.href=isOut?'wireflow.html':'index.html';}}\nif(typeof window!=='undefined'){try{const v=new URLSearchParams(window.location.search).get('v');const path=window.location.pathname;const isOut=path.includes('/outputs/')||path.endsWith('wireflow.html')||path.endsWith('wireflow-v02.html')||path.endsWith('wireflow-v03.html');if(v==='0.3'||v==='3')window.location.replace(isOut?'wireflow.html':'index.html');}catch(e){}}\n`;
  h = h.replace("<script>\n'use strict';", `<script>\n'use strict';\n${switcherJsV02}`);
  return h;
};

const buildV03Html = (v02Target) => {
  const scriptContent = `const goals=${JSON.stringify(goals)};\nconst stories=${JSON.stringify(stories)};\n` + fs.readFileSync('work/v03-app.js', 'utf8');
  return `<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Грошик — Wireflow v0.3</title><style>${baseCss}\n${extraV03Css}\n${switcherCss}</style></head>
<body><header class="top"><div><div class="brand">Грошик / Wireflow <span class="muted">v0.3</span></div><div class="muted">Изменения команды · демонстрационный режим</div></div><div class="version-switch" role="group" aria-label="Выбор версии wireflow"><span class="version-label">Версия:</span><a href="${v02Target}" class="version-pill" onclick="switchWireflowVersion('0.2', event)" title="Перейти к предыдущей версии 0.2">v0.2</a><span class="version-pill active" aria-current="page">v0.3 <span class="badge-new">новая</span></span></div><div class="tabs"><button id="prototypeTab" class="small active" onclick="view('prototype')">Прототип</button><button id="flowTab" class="small" onclick="view('flow')">Схема и правила</button><button class="small" onclick="requestReset()">Начать заново</button></div></header>
<main id="prototypeView" class="workspace"><aside class="panel map-panel"><h2>Экраны</h2><div id="routes"></div><details open><summary>Как смотреть</summary><p>В центре — приложение. Здесь и справа — пояснения для команды. Переходы сохраняют условия игры.</p><p><strong>Версия 0.3 (новая):</strong> добавлены выбор сложности, онбординг, экран персонажа со шкалами, единая карта заданий с Хитрым Лисом, стол подорожника и кабинет взрослого с PIN. Чтобы сравнить с исходной версией, нажмите <strong>v0.2</strong> в переключателе вверху.</p><p>Чтобы пройти новый вход, нажмите «Начать заново»: это удалит только локальный демонстрационный профиль.</p></details></aside><section class="phone" aria-label="Прототип приложения"><div class="phone-head"><span id="screenCode"></span><span id="dayLabel"></span></div><div id="screen" class="screen"></div><nav id="nav" class="nav" aria-label="Разделы приложения"></nav></section><aside class="panel inspector"><h2>Логика экрана</h2><div id="inspector"></div><h2>Последние действия</h2><div id="events" class="history"></div></aside></main>
<section id="flowView" class="flow-wrap hidden"></section><footer class="footer">Интерактивные вайрфреймы. Монеты, покупки, квесты и переходы дней считаются локально. Никаких ожиданий по времени.</footer><script>${scriptContent}</script></body></html>`;
};

// 1. Build outputs/
const v03OutputsHtml = buildV03Html('wireflow-v02.html');
fs.writeFileSync('outputs/wireflow.html', v03OutputsHtml);
fs.writeFileSync('outputs/wireflow-v03.html', v03OutputsHtml);

const v02OutputsHtml = buildV02Html('wireflow.html');
fs.writeFileSync('outputs/wireflow-v02.html', v02OutputsHtml);

// 2. Build root files
const v03RootHtml = buildV03Html('index-v02.html');
fs.writeFileSync('index.html', v03RootHtml);
fs.writeFileSync('index-v03.html', v03RootHtml);

const v02RootHtml = buildV02Html('index.html');
fs.writeFileSync('index-v02.html', v02RootHtml);

console.log('Build complete:');
console.log('- outputs/wireflow.html (v0.3): ' + Buffer.byteLength(v03OutputsHtml) + ' bytes');
console.log('- outputs/wireflow-v03.html (v0.3): ' + Buffer.byteLength(v03OutputsHtml) + ' bytes');
console.log('- outputs/wireflow-v02.html (v0.2): ' + Buffer.byteLength(v02OutputsHtml) + ' bytes');
console.log('- index.html (v0.3): ' + Buffer.byteLength(v03RootHtml) + ' bytes');
console.log('- index-v03.html (v0.3): ' + Buffer.byteLength(v03RootHtml) + ' bytes');
console.log('- index-v02.html (v0.2): ' + Buffer.byteLength(v02RootHtml) + ' bytes');
