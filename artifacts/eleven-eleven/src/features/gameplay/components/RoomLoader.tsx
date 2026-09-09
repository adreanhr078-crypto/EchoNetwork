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
}: RoomLoaderProps) {
  if (definition.id === 'opening-lab') {
    return (
      <OpeningRoom
        flags={flags}
        quality={quality}
        focusedInteractionId={focusedInteractionId}
        visualEvent={visualEvent}
      />
    );
  }

  return null;
}
