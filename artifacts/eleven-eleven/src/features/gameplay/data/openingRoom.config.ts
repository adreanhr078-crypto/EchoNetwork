import type { RoomConfig } from '../types/gameplay.types';

export const OPENING_ROOM_CONFIG: RoomConfig = {
  id: 'opening-room',
  dimensions: {
    width: 20,
    height: 6.2,
    depth: 34,
  },
  bounds: {
    min: { x: -5.0, y: 0, z: -15.0 },
    max: { x: 14.0, y: 6.2, z: 16.5 },
  },
  // Echo steps out onto the Dais in front of the Stasis Capsule in the first quarter of the corridor facing forward (-Z)
  spawnPosition: { x: 0, y: 0.88, z: 9.5 },
  camera: {
    positionOffset: { x: 0.38, y: 0.35, z: 2.5 }, // Genshin Impact 3rd person OTS framing
    targetOffset: { x: 0, y: 1.18, z: 0 },
    followSharpness: 14,
    rotationSharpness: 18,
    collisionPadding: 0.45,
  },
  movement: {
    walkSpeed: 2.4, // Genshin Impact responsive walk
    sprintSpeed: 5.2, // Genshin Impact responsive sprint dash
    halfExtents: { x: 0.35, y: 0.88, z: 0.35 },
  },
  // Interior dividers shaping the main corridor and the nested sub-chambers (Entrance 1 -> Entrance 2 -> Entrance 3)
  // All obstacles have thick collision hulls (>= 0.8m) to prevent tunneling under high sprint speed
  obstacles: [
    // Stasis Pod Framing (Safely behind spawn at z = 14.6, open front allows free step-out)
    {
      id: 'awakening-pod-back',
      min: { x: -1.8, y: 0, z: 13.8 },
      max: { x: 1.8, y: 3.8, z: 15.6 },
    },
    {
      id: 'awakening-pod-left',
      min: { x: -2.4, y: 0, z: 13.0 },
      max: { x: -1.1, y: 3.5, z: 15.0 },
    },
    {
      id: 'awakening-pod-right',
      min: { x: 1.1, y: 0, z: 13.0 },
      max: { x: 2.4, y: 3.5, z: 15.0 },
    },
    // Corridor Stasis Pods (Prevent clipping through glass tube cylinders)
    {
      id: 'stasis-pod-ex001',
      min: { x: -4.4, y: 0, z: 9.2 },
      max: { x: -2.8, y: 3.5, z: 10.8 },
    },
    {
      id: 'stasis-pod-ex002',
      min: { x: -4.4, y: 0, z: 4.2 },
      max: { x: -2.8, y: 3.5, z: 5.8 },
    },
    {
      id: 'stasis-pod-ex003',
      min: { x: -4.4, y: 0, z: -0.8 },
      max: { x: -2.8, y: 3.5, z: 0.8 },
    },
    {
      id: 'stasis-pod-ex004',
      min: { x: -4.4, y: 0, z: -5.8 },
      max: { x: -2.8, y: 3.5, z: -4.2 },
    },
    // Sub-Chamber Beta Ruptured Pods & Equipment
    {
      id: 'stasis-pod-ex007',
      min: { x: 10.7, y: 0, z: 1.2 },
      max: { x: 12.3, y: 3.5, z: 2.8 },
    },
    {
      id: 'stasis-pod-ex008',
      min: { x: 10.7, y: 0, z: -2.8 },
      max: { x: 12.3, y: 3.5, z: -1.2 },
    },
    {
      id: 'medical-equipment-beta-1',
      min: { x: 9.4, y: 0, z: 1.4 },
      max: { x: 10.6, y: 2.0, z: 2.6 },
    },
    {
      id: 'medical-equipment-beta-2',
      min: { x: 9.4, y: 0, z: -2.6 },
      max: { x: 10.6, y: 2.0, z: -1.4 },
    },
    // Tactical Katana Military Crate
    {
      id: 'katana-equipment-crate',
      min: { x: -2.1, y: 0, z: -13.1 },
      max: { x: -0.7, y: 1.5, z: -11.9 },
    },
    // Main Corridor West Wall Boundary
    {
      id: 'main-corridor-west-wall',
      min: { x: -6.5, y: 0, z: -16.0 },
      max: { x: -4.5, y: 6.5, z: 17.5 },
    },
    // Main Corridor North Wall Boundary (Behind Dais)
    {
      id: 'main-corridor-north-wall',
      min: { x: -6.0, y: 0, z: 15.8 },
      max: { x: 6.0, y: 6.5, z: 17.5 },
    },
    // End Quarantine Blast Vault Wall (South Barrier)
    {
      id: 'end-quarantine-blast-barrier',
      min: { x: -6.0, y: 0, z: -16.0 },
      max: { x: 6.0, y: 6.5, z: -14.0 },
    },
    // Main Corridor East Wall (Upper segment: z=8.5 to 17.0)
    {
      id: 'main-east-wall-upper',
      min: { x: 4.5, y: 0, z: 8.5 },
      max: { x: 5.8, y: 6.5, z: 17.5 },
    },
    // [ENTRANCE 1 is open between z=5.5 and 8.5 at x=4.5]
    // Main Corridor East Wall (Lower segment: z=-14.5 to 5.5)
    {
      id: 'main-east-wall-lower',
      min: { x: 4.5, y: 0, z: -15.0 },
      max: { x: 5.8, y: 6.5, z: 5.5 },
    },
    // Sub-Lab Alpha North Wall
    {
      id: 'sublab-alpha-north-wall',
      min: { x: 4.5, y: 0, z: 10.2 },
      max: { x: 15.0, y: 6.5, z: 11.5 },
    },
    // Sub-Lab Alpha East Wall
    {
      id: 'sublab-alpha-east-wall',
      min: { x: 13.5, y: 0, z: 3.2 },
      max: { x: 15.0, y: 6.5, z: 11.5 },
    },
    // Divider Wall between Sub-Lab Alpha and Sub-Chamber Beta (with ENTRANCE 2 at x=6.5 to 8.5)
    {
      id: 'divider-alpha-beta-left',
      min: { x: 4.5, y: 0, z: 3.2 },
      max: { x: 6.5, y: 6.5, z: 4.4 },
    },
    {
      id: 'divider-alpha-beta-right',
      min: { x: 8.5, y: 0, z: 3.2 },
      max: { x: 15.0, y: 6.5, z: 4.4 },
    },
    // Sub-Chamber Beta East Wall
    {
      id: 'subchamber-beta-east-wall',
      min: { x: 13.5, y: 0, z: -4.8 },
      max: { x: 15.0, y: 6.5, z: 4.0 },
    },
    // Divider Wall between Sub-Chamber Beta and Deep Containment Vault (with ENTRANCE 3 at x=9.0 to 11.2)
    {
      id: 'divider-beta-vault-left',
      min: { x: 4.5, y: 0, z: -4.8 },
      max: { x: 9.0, y: 6.5, z: -3.6 },
    },
    {
      id: 'divider-beta-vault-right',
      min: { x: 11.2, y: 0, z: -4.8 },
      max: { x: 15.0, y: 6.5, z: -3.6 },
    },
    // Deep Containment Vault West Wall (separates Vault from Main East Wall)
    {
      id: 'vault-west-wall',
      min: { x: 7.2, y: 0, z: -12.5 },
      max: { x: 8.4, y: 6.5, z: -3.6 },
    },
    // Deep Containment Vault South Wall
    {
      id: 'vault-south-wall',
      min: { x: 7.2, y: 0, z: -13.0 },
      max: { x: 15.0, y: 6.5, z: -11.6 },
    },
    // Deep Containment Vault East Wall
    {
      id: 'vault-east-wall',
      min: { x: 13.5, y: 0, z: -13.0 },
      max: { x: 15.0, y: 6.5, z: -3.6 },
    },
    // Specimen EX-000 Stasis Containment Tank Base in Vault
    {
      id: 'specimen-ex000-tank-base',
      min: { x: 9.8, y: 0, z: -9.8 },
      max: { x: 12.4, y: 3.5, z: -7.2 },
    },
  ],
};
