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
  onPhaseChange?: (phase: 1 | 2) => void;
  onShockwave?: (pos: Vector3, radius: number) => void;
  onStaggerChange?: (isStaggered: boolean) => void;
  onSlamWindup?: (isWindup: boolean) => void;
  lastHitNonce?: number;
  lastHitDamage?: number;
  stunNonce?: number;
  stunDuration?: number;
  combatStudyEnabled?: boolean;
  capsuleOpen?: boolean;
  substationOverridden?: boolean;
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
  onPhaseChange,
  onShockwave,
  onStaggerChange,
  onSlamWindup,
  lastHitNonce,
  lastHitDamage,
  stunNonce,
  stunDuration,
  combatStudyEnabled = true,
  capsuleOpen,
  substationOverridden = false,
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
        onPhaseChange={onPhaseChange}
        onShockwave={onShockwave}
        onStaggerChange={onStaggerChange}
        onSlamWindup={onSlamWindup}
        lastHitNonce={lastHitNonce}
        lastHitDamage={lastHitDamage}
        stunNonce={stunNonce}
        stunDuration={stunDuration}
        combatStudyEnabled={combatStudyEnabled}
        capsuleOpen={capsuleOpen}
        substationOverridden={substationOverridden}
      />
    );
  }

  return null;
}
