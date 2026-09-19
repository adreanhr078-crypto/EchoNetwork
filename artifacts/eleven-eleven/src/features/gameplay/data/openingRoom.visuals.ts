import type { QualityTier } from '../../../ui/design-system';
import { OPENING_ROOM_ANCHORS, anchorTuple } from './openingRoom.anchors';

export const OPENING_ROOM_PALETTE = {
  void: '#010407',
  wall: '#071117',
  wallRaised: '#0c1a21',
  floor: '#081116',
  floorRaised: '#111d23',
  metal: '#17242a',
  fabric: '#202c32',
  fabricHighlight: '#34464d',
  memory: '#55e7ff',
  memoryDim: '#0b5966',
  danger: '#ff4058',
  dangerDim: '#65131f',
  unknown: '#8d5bd6',
  evidence: '#caa94b',
} as const;

export interface RoomVisualEvent {
  readonly nonce: number;
  readonly interactionId: string;
  readonly outcome: string;
  readonly memoryGranted: boolean;
}

export interface OpeningRoomVisualQuality {
  readonly dustParticles: number;
  readonly glitchStrips: number;
  readonly floorDetails: number;
  readonly propDetails: boolean;
  readonly dynamicShadows: boolean;
}

export const OPENING_ROOM_VISUAL_QUALITY:
Record<QualityTier, OpeningRoomVisualQuality> = {
  high: {
    dustParticles: 28,
    glitchStrips: 5,
    floorDetails: 13,
    propDetails: true,
    dynamicShadows: true,
  },
  balanced: {
    dustParticles: 18,
    glitchStrips: 3,
    floorDetails: 9,
    propDetails: true,
    dynamicShadows: false,
  },
  mobile: {
    dustParticles: 8,
    glitchStrips: 2,
    floorDetails: 6,
    propDetails: false,
    dynamicShadows: false,
  },
};

export const OPENING_ROOM_INTERACTION_VISUALS = {
  'opening-clock': {
    position: anchorTuple(OPENING_ROOM_ANCHORS.clock),
    radius: 0.58,
  },
  'opening-photo': {
    position: anchorTuple(OPENING_ROOM_ANCHORS.photo),
    radius: 0.5,
  },
  'opening-door': {
    position: anchorTuple(OPENING_ROOM_ANCHORS.door),
    radius: 0.72,
  },
} as const;
