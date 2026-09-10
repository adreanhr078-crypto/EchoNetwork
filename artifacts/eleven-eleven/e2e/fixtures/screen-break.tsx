import React, { StrictMode, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ScreenBreakRuntime } from '../../src/features/opening-recovery/ScreenBreakRuntime';
import { useUiPreferencesStore } from '../../src/app/shell/shellStore';
import '../../src/features/opening-recovery/opening-recovery.css';

// Isolated presentation fixture: no auth, receipts, or progression are seeded.
const params = new URLSearchParams(location.search);
useUiPreferencesStore.setState({ locale: params.get('locale') === 'ar' ? 'ar' : 'en', audioEnabled: false });
function Fixture() {
  const [open, setOpen] = useState(false);
  const [completions, setCompletions] = useState(0);
  return <>
    <h1>Cinematic component verification — not a gameplay completion</h1>
    <button onClick={() => setOpen(true)}>Open cinematic</button>
    <button>Background control</button>
    <output aria-label="Completions">{completions}</output>
    {open && <ScreenBreakRuntime reducedMotion={params.has('reduced')} showFracture={!params.has('noFracture')}
      videoUrl={params.has('missing') ? '/assets/cinematics/missing-test.webm' : undefined}
      onComplete={() => { setCompletions(value => value + 1); setOpen(false); }} />}
  </>;
}
createRoot(document.getElementById('root')!).render(<StrictMode><Fixture /></StrictMode>);
