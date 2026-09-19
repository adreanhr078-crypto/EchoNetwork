import React from 'react';
import { createRoot } from 'react-dom/client';
import { GameWorld } from '../../src/features/gameplay/components/GameWorld';
import '../../src/ui/design-system/styles/index.css';
import '../../src/features/gameplay/gameplay.css';
import { useGameStore } from '../../src/stores/gameStore';

// Mark cinematic seen so gameplay enters directly
useGameStore.getState().actions.setNarrativeFlag('opening_room_cinematic_seen', true);
useGameStore.getState().actions.setNarrativeFlag('opening_room_controls_seen', true);

function Fixture() {
  return (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <GameWorld
        paused={false}
        quality="high"
        motion="full"
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
