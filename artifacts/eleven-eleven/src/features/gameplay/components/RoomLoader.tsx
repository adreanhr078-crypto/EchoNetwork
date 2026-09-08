import { useGLTF } from '@react-three/drei';
import { Suspense, useMemo } from 'react';
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

function GLBRoom({ url }: { url: string }) {
  const { scene } = useGLTF(url);
  // Clone the scene so we can mutate it safely if needed
  const clonedScene = useMemo(() => scene.clone(), [scene]);
  return <primitive object={clonedScene} />;
}

/**
 * Dynamically loads a 3D environment based on a RoomDefinition.
 * Falls back to the procedural OpeningRoom if the GLB is not yet available,
 * allowing seamless transition as high-quality blender assets are delivered.
 */
export function RoomLoader({
  definition,
  flags,
  quality,
  focusedInteractionId,
  visualEvent,
}: RoomLoaderProps) {
  // If we have an asset URL, we attempt to load it. 
  // For Phase 3.0, since the AI-generated GLB is pending, we might catch errors
  // or fall back. Currently, the asset doesn't exist on disk, so we render the fallback.
  
  const hasValidGLB = false; // Toggle this when the asset is actually placed in public/assets/

  if (hasValidGLB && definition.assetUrl) {
    return (
      <Suspense fallback={null}>
        <GLBRoom url={definition.assetUrl} />
      </Suspense>
    );
  }

  // Fallback to procedural OpeningRoom for now
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
