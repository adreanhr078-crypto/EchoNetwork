import type { Vector3Tuple, EulerTuple } from 'three';

export type InteractableType = 'puzzle' | 'item' | 'cinematic' | 'door';

export interface RoomSpawnPoint {
  id: string;
  position: Vector3Tuple;
  rotation: EulerTuple;
}

export interface RoomInteractable {
  id: string;
  type: InteractableType;
  position: Vector3Tuple;
  radius: number;
  prompt: string;
  targetMeshName?: string; // Links this interaction to a specific mesh in the GLB
}

export interface RoomCinematicTrigger {
  id: string;
  bounds: {
    min: Vector3Tuple;
    max: Vector3Tuple;
  };
  cinematicSequenceId: string;
}

export interface RoomDefinition {
  id: string;
  name: string;
  assetUrl: string | null; // Null if using procedural fallback
  spawnPoints: Record<string, RoomSpawnPoint>;
  interactables: RoomInteractable[];
  cinematics: RoomCinematicTrigger[];
  bounds: {
    min: Vector3Tuple;
    max: Vector3Tuple;
  };
  fog: {
    color: string;
    near: number;
    far: number;
  };
}
