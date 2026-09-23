const fs = require('fs');
let code = fs.readFileSync('src/features/gameplay/components/OpeningCinematic.tsx', 'utf8');

code = code.replace(/onComplete:\s*\(\)\s*=>\s*void;/, "onComplete: () => void;\n  onAwakeningSubPhase?: (subPhase: 'wakeup' | 'standup' | 'idle') => void;");
code = code.replace(/onBreachProgress,\n\}:\s*OpeningCinematicProps\)/, "onBreachProgress,\n  onAwakeningSubPhase,\n}: OpeningCinematicProps)");

const replaceUseFrame = `
    if (reducedMotion) {
      onAwakeningSubPhase?.('standup');
      desired.lerpVectors(awakeFaceCloseUp, awakeThirdPerson, MathUtils.smoothstep(progress, 0, 1));
      lookTarget.copy(targetPosition);
    } else if (progress < 0.42) {
      onAwakeningSubPhase?.('wakeup');
      // Stage 1: Close-up through stasis glass as Echo's eyes open inside pod
`;
code = code.replace(/if\s*\(reducedMotion\)\s*\{\s*desired\.lerpVectors[^}]+}\s*else\s*if\s*\(progress\s*<\s*0\.42\)\s*\{/g, replaceUseFrame);

const replaceStage2 = `    } else if (progress < 0.82) {
      onAwakeningSubPhase?.('standup');
      // Stage 2: Pod opens!`;
code = code.replace(/\}\s*else\s*if\s*\(progress\s*<\s*0\.82\)\s*\{\s*\/\/\s*Stage 2:\s*Pod opens!/g, replaceStage2);

const replaceStage3 = `    } else {
      onAwakeningSubPhase?.('idle');
      // Stage 3: Lock behind`;
code = code.replace(/\}\s*else\s*\{\s*\/\/\s*Stage 3:\s*Lock behind/g, replaceStage3);

fs.writeFileSync('src/features/gameplay/components/OpeningCinematic.tsx', code);
