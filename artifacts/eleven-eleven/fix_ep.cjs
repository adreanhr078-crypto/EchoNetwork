const fs = require('fs');
let code = fs.readFileSync('src/features/gameplay/components/EchoPlayer.tsx', 'utf8');

code = code.replace(/cinematicPhase\?: 'awakening' \| 'monster-breach' \| null;/, "cinematicPhase?: 'awakening' | 'monster-breach' | 'wakeup' | 'standup' | 'idle' | null;");
code = code.replace(/cinematicPhase: cinematicPhase === 'awakening' \? 'wakeup' : null,/, "cinematicPhase: (cinematicPhase === 'wakeup' || cinematicPhase === 'standup' || cinematicPhase === 'idle') ? cinematicPhase : null,");

fs.writeFileSync('src/features/gameplay/components/EchoPlayer.tsx', code);
