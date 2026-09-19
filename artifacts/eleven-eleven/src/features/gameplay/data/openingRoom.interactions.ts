import {
  canUnlockOpeningDoor,
  isOpeningDoorUnlocked,
  type OpeningRoomNarrativeFlags,
  type OpeningRoomPuzzleEvent,
} from '../systems/puzzleSystem';
import type {
  InteractionDefinition,
  NarrativeEffect,
} from '../types/gameplay.types';
import {
  OPENING_ROOM_MEMORY_ID,
  OPENING_ROOM_PUZZLE_ID,
} from './openingRoom.puzzles';
import { OPENING_ROOM_ANCHORS } from './openingRoom.anchors';

export interface OpeningRoomInteractionContext {
  readonly flags: Readonly<Partial<OpeningRoomNarrativeFlags>>;
}

export interface OpeningRoomEventEffect extends NarrativeEffect {
  readonly type: 'openingRoomEvent';
  readonly event: OpeningRoomPuzzleEvent;
}

export type OpeningRoomInteraction =
  InteractionDefinition<
    OpeningRoomInteractionContext,
    OpeningRoomEventEffect
  >;

function eventEffect(
  event: OpeningRoomPuzzleEvent,
): OpeningRoomEventEffect {
  return {
    type: 'openingRoomEvent',
    event,
  };
}

const CLOCK_INSPECTED_EFFECT = eventEffect({
  type: 'clockInspected',
});
const PHOTO_INSPECTED_EFFECT = eventEffect({
  type: 'photoInspected',
});

function clueEffects(
  ownEffect: OpeningRoomEventEffect,
  otherClueFound: boolean,
  memoryAlreadyRecovered: boolean,
): readonly OpeningRoomEventEffect[] {
  if (!otherClueFound || memoryAlreadyRecovered) return [ownEffect];

  return [
    ownEffect,
    eventEffect({
      type: 'memoryRecovered',
      memoryId: OPENING_ROOM_MEMORY_ID,
    }),
    eventEffect({ type: 'puzzleSolved' }),
  ];
}

export const OPENING_ROOM_INTERACTIONS:
readonly OpeningRoomInteraction[] = [
  {
    id: 'opening-clock',
    type: 'inspect',
    position: OPENING_ROOM_ANCHORS.clock,
    interactionDistance: 1.45,
    prompt: 'E — افحص الساعة',
    enabledCondition: ({ flags }) => (
      flags.openingClockInspected !== true
    ),
    onInteract: ({ flags }) => ({
      outcome: flags.openingPhotoInspected
        ? 'memory'
        : 'narration',
      message: (
        'عقارب الساعة ساكنة عند 11:11. '
        + 'الصمت حولها أثقل من أن يكون عاديًا.'
      ),
      effects: clueEffects(
        CLOCK_INSPECTED_EFFECT,
        flags.openingPhotoInspected === true,
        flags.openingMemoryRecovered === true,
      ),
    }),
    puzzleId: OPENING_ROOM_PUZZLE_ID,
    narrativeEffects: [CLOCK_INSPECTED_EFFECT],
  },
  {
    id: 'opening-photo',
    type: 'inspect',
    position: OPENING_ROOM_ANCHORS.photo,
    interactionDistance: 1.5,
    prompt: 'E — افحص الصورة الممزقة',
    enabledCondition: ({ flags }) => (
      flags.openingPhotoInspected !== true
    ),
    onInteract: ({ flags }) => ({
      outcome: flags.openingClockInspected
        ? 'memory'
        : 'narration',
      message: (
        'صورة ممزقة لشخص لا يظهر منه سوى ظل باهت. '
        + 'على ظهرها: «عندما تشعر بالخوف، عُدّ حتى أحد عشر.» '
        + 'وفوق الحافة الممزقة خُطّت جملة أخرى: '
        + '«لا أتذكر الوجه… فقط أنني لم أكن وحدي.»'
      ),
      effects: clueEffects(
        PHOTO_INSPECTED_EFFECT,
        flags.openingClockInspected === true,
        flags.openingMemoryRecovered === true,
      ),
    }),
    memoryId: OPENING_ROOM_MEMORY_ID,
    puzzleId: OPENING_ROOM_PUZZLE_ID,
    narrativeEffects: [PHOTO_INSPECTED_EFFECT],
  },
  {
    id: 'opening-door',
    type: 'door',
    position: OPENING_ROOM_ANCHORS.door,
    interactionDistance: 1.4,
    prompt: 'E — افحص الباب',
    enabledCondition: ({ flags }) => (
      flags.openingRoomCompleted !== true
    ),
    onInteract: ({ flags }) => {
      if (isOpeningDoorUnlocked(flags)) {
        return {
          outcome: 'unlocked',
          message: 'الباب مفتوح. يمتد خلفه ممر بلا ضوء.',
          effects: [],
        };
      }

      if (!canUnlockOpeningDoor(flags)) {
        return {
          outcome: 'locked',
          message: (
            'الباب مقفل. هناك شيء في الغرفة لم يُستعد بعد.'
          ),
          effects: [],
        };
      }

      return {
        outcome: 'unlocked',
        message: 'استجاب القفل أخيرًا، وانفتح الباب ببطء.',
        effects: [eventEffect({ type: 'doorUnlocked' })],
      };
    },
    puzzleId: OPENING_ROOM_PUZZLE_ID,
  },
];

// Preserve experimental encounters without adding them to the canonical clue loop.
export const EXPERIMENTAL_OPENING_INTERACTIONS: readonly OpeningRoomInteraction[] = [
  {
    id: 'opening-katana-chest',
    type: 'inspect',
    position: { x: 9.2, y: 0.9, z: -1.5 },
    interactionDistance: 2.2,
    prompt: 'E — افتح صندوق الكاتانا التكتيكية',
    enabledCondition: ({ flags }) => (
      flags.openingMemoryRecovered !== true && flags.openingPuzzleSolved !== true
    ),
    onInteract: () => ({
      outcome: 'narration',
      message: (
        'تم فتح صندوق التجهيزات التكتيكية! '
        + 'سيف الكاتana الإلكتروني عالي التردد أصبح جاهزًا للقتال.'
      ),
      effects: [],
    }),

  },
  {
    id: 'sublab-terminal',
    type: 'inspect',
    position: { x: 8.5, y: 1.2, z: 6.8 },
    interactionDistance: 1.8,
    prompt: 'E — افحص سجلات المختبر',
    enabledCondition: () => true,
    onInteract: () => ({
      outcome: 'narration',
      message: (
        'سجل المختبر // قطاع 11: '
        + '«العينة EX-000 أظهرت نموًا عضليًا شاذًا ومقاومة غير مسبوقة. '
        + 'تم عزلها في غرفة الاحتواء القصوى خلف البوابة الغربية. '
        + 'تحذير: لا تدخل دون سلاح حاد عالي التردد.»'
      ),
      effects: [],
    }),
  },
];

export const OPENING_CLOCK_INTERACTION =
  OPENING_ROOM_INTERACTIONS[0];
export const OPENING_PHOTO_INTERACTION =
  OPENING_ROOM_INTERACTIONS[1];
export const OPENING_DOOR_INTERACTION =
  OPENING_ROOM_INTERACTIONS[2];
