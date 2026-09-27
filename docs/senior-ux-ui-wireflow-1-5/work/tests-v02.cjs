const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(fs.existsSync('outputs/wireflow-v02.html')?'outputs/wireflow-v02.html':'work/wireflow-v02.html','utf8'),code=html.match(/<script>([\s\S]*)<\/script>/)[1];
const els={},storage={};const el=id=>els[id]??={value:'',innerHTML:'',textContent:'',classList:{toggle(){}},prepend(node){this.innerHTML=node.innerHTML+this.innerHTML}};
const ctx=vm.createContext({document:{getElementById:el,addEventListener(){},createElement(){return {className:'',innerHTML:''}}},localStorage:{getItem:k=>storage[k],setItem:(k,v)=>storage[k]=v},console});
vm.runInContext(code,ctx);const run=c=>vm.runInContext(c,ctx);let n=0;const check=(c,expected)=>{assert.deepStrictEqual(run(c),expected,c);n++};const fill=(id,v)=>el(id).value=String(v);
fill('petName','Тест');fill('fur','Серый');fill('scarf','Светлый');run('createPet()');check('S.wallet',30);
run("go('plan')");fill('need',0);fill('want',10);fill('plannedSave',20);run('confirmPlan()');check('S.plan===null',true);check("$('planError').innerHTML.includes('На еду нужно')",true);
fill('need',10);fill('want',30);run('confirmPlan()');check('S.plan===null',true);
fill('want',5);fill('plannedSave',15);run('confirmPlan()');check('S.plan.need',10);
run('startQuest(0)');fill('questValue',99);run('answerQuest()');check('S.wallet',30);check('context.ok',false);
run('startQuest(0,true)');fill('questValue',10);run('answerQuest()');check('S.wallet',40);run('answerQuest()');check('S.wallet',40);
run("go('purchase',{id:'toy'})");check("drawPurchase().includes('выше плана на 10')",true);run('buy()');check('S.wallet',25);check('S.fact.want',15);
run("go('purchase',{id:'food'});buy()");check('S.fed',true);check('S.wallet',15);
run("go('savings')");fill('amount',10);run('deposit()');check('S.wallet',5);check('S.savings',10);check('S.fact.save',10);
fill('amount',3);run('prepareWithdraw()');check('S.savings',10);run('withdraw()');check('S.wallet',8);check('S.savings',7);check('S.fact.save',7);
run("go('purchase',{id:'toy'})");check("purchaseReason(goods[1])",'money');run('buy()');check('S.wallet',8);
run('endDay()');check('S.history.length',1);run("go('home')");check('screen','summary');run('endDay()');check('S.history.length',1);run('nextDay()');check('S.day',2);check('S.wallet',18);check('S.savings',7);run('nextDay()');check('S.day',2);
// Five full periods, progression, goals and new location with actual actions.
run('reset();S.created=true');
for(let d=1;d<=5;d++){
 run("S.goal=['gusli','house','boots'].find(id=>!S.owned.includes(id))||null");
 run("go('plan')");fill('need',10);fill('want',0);fill('plannedSave',0);run('confirmPlan()');
 run("go('purchase',{id:'toy'})");if(d>1&&run('S.wallet')<25)check("purchaseReason(goods[1])",run('S.wallet')<15?'money':'food');
 for(let id=0;id<3;id++){run(`startQuest(${id})`);const hard=run('context.hard');const expected=id===0?(hard?25:10):id===1?(hard?30:20):(hard?20:5);fill('questValue',expected);run(`answerQuest(${expected})`);}
 run("go('purchase',{id:'food'});buy();go('savings')");fill('amount',run('S.wallet'));run('deposit()');
 if(run('currentGoal()&&S.savings>=currentGoal().cost'))run("go('artifact');claimArtifact()");
 run('endDay()');check('S.history.length',d);check('S.lastSummary.good',true);if(d<5)run('nextDay()');
}
check('S.level',3);check('S.owned.length',3);run('nextDay();go("forest");changeLocation()');check('S.location','Тридевятое царство');
// Optional parent task and one-time reward, direct controller test (no UI barrier automation).
run("parentOpen=true;screen='parent'");fill('taskTitle','Список покупок');fill('taskReward',10);run('addParentTask()');check('S.parentTasks.length',1);run('submitParentTask(S.parentTasks[0].id)');const before=run('S.wallet');run('approveTask(S.parentTasks[0].id)');check('S.wallet',before+10);run('approveTask(S.parentTasks[0].id)');check('S.wallet',before+10);
// Every view renders without an exception.
run("S.lastSummary=S.history[4]");for(const id of ['welcome','create','home','plan','forest','shop','savings','finish','summary','progress','gate','parent','help','reset'])run(`screen='${id}';render()`);
check('JSON.parse(localStorage.getItem(KEY)).wallet',run('S.wallet'));
console.log('Regression PASS: '+n+' assertions; five periods, three artifacts, progression, adaptation, savings, budget deviations and one-time rewards.');


check('goals.length',7);check('stories.length',5);
const frozen=run('JSON.stringify(S)');
for(const q of run('stories.map(q=>q.id)')){
 run(`go('questBrief',{id:'${q}'})`);check('screen','questBrief');
 for(let step=0;step<3;step++){run(`go('questWalk',{id:'${q}',step:${step}})`);check("draw().includes('Действие ребёнка')",true);}
 for(const outcome of ['good','bad']){run(`go('questBranch',{id:'${q}',outcome:'${outcome}'})`);check("draw().includes('баланс не меняется')",true);}
}
check('JSON.stringify(S)',frozen);
const previousGoal=run('S.goal');run("go('catalog');go('artifactDetail',{id:'cloth'});setArtifactGoal('cloth')");check('S.goal',previousGoal);check("message.includes('следующий день')",true);
run('renderFlow()');check("$('flowView').innerHTML.includes('Добавлено в v0.2')",true);
run("nextDay();go('artifactDetail',{id:'cloth'});setArtifactGoal('cloth')");check('S.goal','cloth');check('screen','plan');
// Choosing a new goal never consumes saved funds.
const funds=run('S.wallet+S.savings');run("setArtifactGoal('water')");check('S.wallet+S.savings',funds);
// Reload an old complete collection and migrate to an available new goal.
run("S.owned=['gusli','house','boots'];S.goal=null;save()");
const oldData=JSON.parse(storage['groshik-wireflow-v01']);
const reload=vm.createContext({document:{getElementById:el,addEventListener(){},createElement(){return {className:'',innerHTML:''}}},localStorage:{getItem:k=>storage[k],setItem:(k,v)=>storage[k]=v},console});vm.runInContext(code,reload);
assert.equal(vm.runInContext('S.goal',reload),'cloth');assert.equal(vm.runInContext('S.wallet',reload),oldData.wallet);
assert.equal(vm.runInContext('S.owned.length',reload),3);
console.log('v0.2 PASS: '+n+' assertions, all 5 scenarios and both branches, 7 catalog items, non-mutating preview, goal selection and saved-progress migration.');
