const fs = require('fs');
let code = fs.readFileSync('src/features/gameplay/components/GameWorld.tsx', 'utf8');

code = code.replace(/const \[cinematicPhase, setCinematicPhase\] = useState<CinematicPhase>\('awakening'\);/, "const [cinematicPhase, setCinematicPhase] = useState<CinematicPhase>('awakening');\n  const [awakeningSubPhase, setAwakeningSubPhase] = useState<'wakeup' | 'standup' | 'idle' | null>('wakeup');");

code = code.replace(/cinematicPhase=\{inEngineCinematicActive \? cinematicPhase : null\}/, "cinematicPhase={inEngineCinematicActive ? (cinematicPhase === 'awakening' ? awakeningSubPhase : cinematicPhase) : null}");

code = code.replace(/onBreachProgress=\{setBreachProgress\}/, "onBreachProgress={setBreachProgress}\n            onAwakeningSubPhase={setAwakeningSubPhase}");

fs.writeFileSync('src/features/gameplay/components/GameWorld.tsx', code);
