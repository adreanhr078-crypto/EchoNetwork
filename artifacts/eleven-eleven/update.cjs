const fs = require('fs');
let code = fs.readFileSync('src/features/gameplay/components/EchoPlayer.tsx', 'utf8');
code = code.replace(/cinematicLocked,\s+activeInteractionId,/, 'cinematicLocked,\n    cinematicPhase,\n    activeInteractionId,');
code = code.replace(/cinematicLocked,\s+paused,\s+\}\);/, "cinematicLocked,\n          paused,\n          cinematicPhase: cinematicPhase === 'awakening' ? 'wakeup' : null,\n        });");
fs.writeFileSync('src/features/gameplay/components/EchoPlayer.tsx', code);
