import React from 'react';
import { createRoot } from 'react-dom/client';
import { GameWorld } from '../../src/features/gameplay/components/GameWorld';
import '../../src/ui/design-system/styles/index.css';
import '../../src/features/gameplay/gameplay.css';
import { useGameStore } from '../../src/stores/gameStore';

// Direct-room mode is the stable movement fixture. `?cinematic` preserves the
// first-entry movie so the in-engine awakening handoff can be audited separately.
const includeCinematic = new URLSearchParams(window.location.search).has('cinematic');
const includeTutorial = new URLSearchParams(window.location.search).has('tutorial');
const reducedMotion = new URLSearchParams(window.location.search).has('reduced');
useGameStore.getState().actions.setNarrativeFlag('opening_room_cinematic_seen', !includeCinematic);
useGameStore.getState().actions.setNarrativeFlag('opening_room_controls_seen', !includeTutorial);

function Fixture() {
  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <GameWorld
        paused={false}
        quality="high"
        motion={reducedMotion ? 'reduced' : 'full'}
        onPause={() => {}}
        onRoomComplete={() => {
          console.log('ROOM_COMPLETED_EVENT');
        }}
      />
    </div>
  );
}

const root = createRoot(document.getElementById('root')!);
root.render(<Fixture />);
