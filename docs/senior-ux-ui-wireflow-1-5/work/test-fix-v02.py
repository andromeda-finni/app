from pathlib import Path
p=Path('work/tests-v02.cjs');s=p.read_text(encoding='utf-8');s=s.replace("run(\"go('catalog');go('artifactDetail',{id:'cloth'});setArtifactGoal('cloth')\");check('S.goal',null);", "const previousGoal=run('S.goal');run(\"go('catalog');go('artifactDetail',{id:'cloth'});setArtifactGoal('cloth')\");check('S.goal',previousGoal);");p.write_text(s,encoding='utf-8')
