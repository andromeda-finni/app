from pathlib import Path
p=Path('outputs/wireflow.html')
s=p.read_text(encoding='utf-8')
s=s.replace("}catch(e){}\nconst $=", "}catch(e){}\nif(!goals.some(g=>g.id===S.goal&&!S.owned.includes(g.id)))S.goal=goals.find(g=>!S.owned.includes(g.id))?.id||null;\nconst $=")
p.write_text(s,encoding='utf-8')
t=Path('work/model-tests.cjs').read_text(encoding='utf-8-sig')
t=t.replace("classList:{toggle(){}}", "classList:{toggle(){}},prepend(node){this.innerHTML=node.innerHTML+this.innerHTML}")
t=t.replace("getElementById:el,addEventListener(){}", "getElementById:el,addEventListener(){},createElement(){return {className:'',innerHTML:''}}")
t=t.replace("for(let d=1;d<=5;d++){", "for(let d=1;d<=5;d++){\n run(\"S.goal=['gusli','house','boots'].find(id=>!S.owned.includes(id))||null\");")
t=t.replace("console.log('PASS:", "console.log('Regression PASS:")
t+='''
check('goals.length',7);check('stories.length',5);
const frozen=run('JSON.stringify(S)');
for(const q of run('stories.map(q=>q.id)')){
 run(`go('questBrief',{id:'${q}'})`);check('screen','questBrief');
 for(let step=0;step<3;step++){run(`go('questWalk',{id:'${q}',step:${step}})`);check("draw().includes('Действие ребёнка')",true);}
 for(const outcome of ['good','bad']){run(`go('questBranch',{id:'${q}',outcome:'${outcome}'})`);check("draw().includes('баланс не меняется')",true);}
}
check('JSON.stringify(S)',frozen);
run("go('catalog');go('artifactDetail',{id:'cloth'});setArtifactGoal('cloth')");check('S.goal',null);check("message.includes('следующий день')",true);
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
'''
Path('work/tests-v02.cjs').write_text(t,encoding='utf-8')
