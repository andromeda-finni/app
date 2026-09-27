const fs=require('fs'),vm=require('vm'),assert=require('assert'),{webcrypto}=require('crypto');
const html=fs.readFileSync('outputs/wireflow.html','utf8'),code=html.match(/<script>([\s\S]*)<\/script>/)[1];
const els={},storage={};
const el=id=>els[id]??={value:'',innerHTML:'',textContent:'',classList:{toggle(){}}};
const ctx=vm.createContext({document:{getElementById:el,body:{classList:{toggle(){}}},addEventListener(){}},localStorage:{getItem:k=>storage[k],setItem:(k,v)=>storage[k]=v},crypto:webcrypto,TextEncoder,console});
vm.runInContext(code,ctx);const run=c=>vm.runInContext(c,ctx);let n=0;
const check=(c,x)=>{assert.strictEqual(run(c),x,c);n++};const fill=(id,v)=>el(id).value=String(v);
function init(level='low'){run('reset()');run(`chooseDifficulty('${level}')`);fill('petName','Тест');fill('fur','Серый');fill('scarf','Светлый');run('createPet();nextTour();nextTour();nextTour()');}
function plan(need=15,want=0,save=15){run("go('plan')");fill('need',need);fill('want',want);fill('plannedSave',save);run('confirmPlan()');}
function quest(id='fish'){run(`startStory('${id}');nextStoryStep();nextStoryStep();answerStory(challenge(context.id,context.difficulty).correct)`);}
function food(){run("go('purchase',{id:'food'});buy()");}
(async()=>{
 check('screen','welcome');run("go('difficulty')");check('screen','difficulty');
 run("chooseDifficulty('medium')");check('screen','create');fill('petName','Тест');fill('fur','Серый');fill('scarf','Светлый');run('createPet()');
 check('screen','onboarding');run("go('plan')");check('screen','onboarding');run('nextTour();nextTour();nextTour()');check('screen','home');
 check("draw().includes('Сытость')",false);check("draw().includes('В копилке')",false);
 plan(9,0,21);check('S.plan',null);check("$('planError').innerHTML.includes('хотя бы 10')",true);
 plan(15,20,10);check('S.plan',null);plan();check('S.plan.need',15);
 run('endDay()');check('S.history.length',0);food();run('endDay()');check('S.history.length',0);
 run("startStory('fish');nextStoryStep();nextStoryStep();answerStory(1)");check('S.wallet',20);check('S.completed.length',0);
 run('answerStory(0)');check('S.wallet',40);check('S.owned.includes("house")',true);check('screen','result');run('answerStory(0)');check('S.wallet',40);
 run("startStory('fish')");check('screen','result');run('endDay()');check('S.history.length',1);run('endDay()');check('S.history.length',1);
 run('nextDay()');check('S.day',2);check('S.sick',true);check('S.health',60);check('S.wallet',50);run('recover()');check('S.health',100);check('S.wallet',50);
 plan(10,0,0);quest();check('S.wallet',70);check('S.owned.length',1);check('S.claimedQuests.length',1);
 // Insured branch, reserve for food and policy expiry.
 init();plan();run("go('insurance');buyInsurance();buyInsurance();buyInsurance()");check('S.wallet',25);check('S.insured',true);check('S.fact.need',5);
 quest();food();run('endDay();nextDay()');check('S.health',100);check('S.sick',false);check('S.insured',false);check('S.wallet',35);
 // Savings transfers, goal purchase and one-time collection; deviations allowed.
 init();plan(10,0,20);run("go('savings')");fill('amount',21);run('deposit()');check('S.savings',0);
 fill('amount',20);run('deposit()');check('S.savings',20);check('S.wallet',10);
 run("selectGoal('cloth');go('goalClaim');claimGoal();claimGoal()");check('S.owned.includes("cloth")',true);check('S.savings',0);check('S.wallet',10);
 food();quest();run("go('purchase',{id:'ribbon'})");check("draw().includes('превысит план')",true);run('buy();buy()');check('S.wallet',5);check('S.fact.want',5);
 init();plan();run("go('savings')");fill('amount',10);run('deposit()');fill('amount',4);run('prepareWithdraw();withdraw();withdraw()');check('S.savings',6);check('S.fact.save',6);check('S.wallet',24);
 // Quest artifact replaces current goal without spending the savings.
 run("selectGoal('house')");quest();check('S.savings',6);check('S.goal!=="house"',true);
 // Every quest at every difficulty, wrong answer and max reward.
 for(const level of ['low','medium','high']){init(level);plan();for(const id of ['fish','morozko','raja','peasant','merchant']){const before=run('S.wallet');quest(id);check('S.wallet-before'.replace('before',String(before)),{low:10,medium:20,high:30}[level]);}check('new Set(S.owned).size',5);}
 // PIN and max parent reward use isolated test state, never the browser profile.
 init();run("go('gate')");fill('pinInput','1234');fill('pinConfirm','4321');await run('submitPin()');check('S.pin',null);
 fill('pinConfirm','1234');await run('submitPin()');check('screen','parent');check('S.pin.hash.length',64);check('S.pin.salt.length',32);check('S.pin.hash==="1234"',false);
 fill('taskTitle','Составить список покупок');fill('taskReward',51);run('addParentTask()');check('S.parentTasks.length',0);
 fill('taskReward',50);run('addParentTask()');check('S.parentTasks.length',1);
 run('changePin()');check('S.pin!==null',true);run("go('settings');go('gate')");fill('pinInput','0000');await run('submitPin()');check('adultOpen',false);
 fill('pinInput','1234');await run('submitPin()');check('adultOpen',true);run('changePin()');fill('pinInput','4321');fill('pinConfirm','4321');await run('submitPin()');check('screen','parent');
 run('submitParentTask(S.parentTasks[0].id);approveTask(S.parentTasks[0].id);approveTask(S.parentTasks[0].id)');check('S.wallet',80);check('S.completed.length',0);
 run("go('home')");check('adultOpen',false);run('approveTask(S.parentTasks[0].id)');check('S.wallet',80);
 // Old profile migration preserves balances and restarts only new onboarding.
 check("migrate({v:1,created:true,wallet:77,savings:22,owned:['gusli'],completed:[0]}).wallet",77);
 check("migrate({v:1,owned:[],completed:[0]}).completed[0]",'legacy:0');check("migrate({v:1,owned:[]}).onboarded",false);
 run("setSetting('largeText',true);changeDifficulty('high')");check('JSON.parse(localStorage.getItem(KEY)).settings.largeText',true);check('S.difficulty','high');
 // All views and all inline handlers are syntactically renderable.
 init();plan();quest();food();run('endDay()');
 for(const id of run('Object.keys(descriptions)')){run(`screen='${id}';context={id:'fish',step:0,difficulty:'low',reward:10,amount:1};render()`);for(const m of el('screen').innerHTML.matchAll(/onclick="([^"]*)"/g)){new vm.Script(m[1]);n++;}}
 run('renderFlow()');check("$('flowView').innerHTML.includes('Страхование: оба пути')",true);
 check("stories[4].hero",'Хитрый лис');check('goals.length',7);
 console.log('PASS '+n+' checks: onboarding, all quests/difficulties, budgets, savings, both health branches, PIN, reward cap, migration and screen handlers.');
})().catch(e=>{console.error(e);process.exitCode=1});
