import type { Vector3 } from 'three';
import type { RoomDefinition } from '../domain/RoomDefinition';
import { OpeningRoom } from './OpeningRoom';
import type { OpeningRoomNarrativeFlags } from '../systems/puzzleSystem';
import type { QualityTier } from '../../../ui/design-system';
import type { OpeningRoomVisualEvent } from './OpeningRoom';

interface RoomLoaderProps {
  definition: RoomDefinition;
  flags: OpeningRoomNarrativeFlags;
  quality: QualityTier;
  focusedInteractionId?: string | null;
  visualEvent?: OpeningRoomVisualEvent | null;
  breachProgress?: number;
  isAgitated?: boolean;
  hasWeapon?: boolean;
  onPickupWeapon?: () => void;
  playerPos?: Vector3;
  onMonsterHpChange?: (currentHp: number, maxHp: number) => void;
  onMonsterAttack?: (damage: number) => void;
  onMonsterDefeated?: () => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
}

/**
 * The authored room is both the environment and the interaction surface.
 * A decorative GLB cannot replace it until every named interaction has a
 * validated mesh binding, collision, lighting, and accessibility fallback.
 */
export function RoomLoader({
  definition,
  flags,
  quality,
  focusedInteractionId,
  visualEvent,
  breachProgress,
  isAgitated,
  hasWeapon,
  onPickupWeapon,
  playerPos,
  onMonsterHpChange,
  onMonsterAttack,
  onMonsterDefeated,
  lastHitNonce,
  lastHitDamage,
}: RoomLoaderProps) {
  if (definition.id === 'opening-lab') {
    return (
      <OpeningRoom
        flags={flags}
        quality={quality}
        focusedInteractionId={focusedInteractionId}
        visualEvent={visualEvent}
        breachProgress={breachProgress}
        isAgitated={isAgitated}
        hasWeapon={hasWeapon}
        onPickupWeapon={onPickupWeapon}
        playerPos={playerPos}
        onMonsterHpChange={onMonsterHpChange}
        onMonsterAttack={onMonsterAttack}
        onMonsterDefeated={onMonsterDefeated}
        lastHitNonce={lastHitNonce}
        lastHitDamage={lastHitDamage}
      />
    );
  }

  return null;
}
