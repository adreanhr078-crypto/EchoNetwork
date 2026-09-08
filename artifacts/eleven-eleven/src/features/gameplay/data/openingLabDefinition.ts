import type { RoomDefinition } from '../domain/RoomDefinition';

export const OPENING_LAB_DEFINITION: RoomDefinition = {
  id: 'opening-lab',
  name: 'Opening Lab',
  assetUrl: '/assets/environments/opening-lab.glb', // Future high-quality blender asset
  spawnPoints: {
    default: {
      id: 'default',
      position: [0, 0, 0],
      rotation: [0, Math.PI, 0],
    },
    bed: {
      id: 'bed',
      position: [-2.0, 0.5, 1.3],
      rotation: [0, Math.PI / 2, 0],
    },
  },
  interactables: [
    {
      id: 'opening-clock',
      type: 'puzzle',
      position: [0.65, 1.62, -3.31],
      radius: 2.0,
      prompt: 'E — افحص الساعة',
      targetMeshName: 'stopped-digital-clock',
    },
    {
      id: 'opening-photo',
      type: 'puzzle',
      position: [2.55, 1.08, -1.5],
      radius: 2.0,
      prompt: 'E — تفحص الصورة',
      targetMeshName: 'torn-photograph',
    },
    {
      id: 'opening-door',
      type: 'door',
      position: [-2.3, 1.48, -3.31],
      radius: 2.5,
      prompt: 'E — افتح الباب',
      targetMeshName: 'exit-door',
    },
  ],
  cinematics: [
    {
      id: 'awakening-scene',
      bounds: {
        min: [-3, 0, 0],
        max: [-1, 2, 3],
      },
      cinematicSequenceId: 'echo-awakes',
    },
  ],
  bounds: {
    min: [-4.6, 0, -3.6],
    max: [4.6, 3.4, 2.9],
  },
  fog: {
    color: '#01070a',
    near: 5.4,
    far: 12,
  },
};
