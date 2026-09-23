/**
 * sectorStoryTasks.ts
 *
 * Story-driven mission progression for Sector 11 (The Stasis Laboratory & Containment Perimeter).
 * Replaces generic puzzle tropes with contextual, high-stakes narrative action-adventure tasks
 * faithful to the approved Manhwa Canon.
 */

import type { OpeningRoomNarrativeFlags } from '../systems/puzzleSystem';
import type { FloatingCompanionEmotion } from './floatingCompanionState';

export type SectorTaskId =
  | '11.1-wake-stasis'
  | '11.2-digital-clock'
  | '11.3-torn-photo'
  | '11.4-substation-reroute'
  | '11.5-containment-breach'
  | '11.6-quarantine-escape';

export type TaskCategory =
  | 'exploration'
  | 'forensic'
  | 'technical'
  | 'survival_combat'
  | 'escape';

export type TaskThreatLevel =
  | 'safe'
  | 'caution'
  | 'critical'
  | 'extreme'
  | 'resolved';

export interface SectorStoryTask {
  id: SectorTaskId;
  sector: number;
  stageCode: string;
  titleAr: string;
  titleEn: string;
  objectiveAr: string;
  objectiveEn: string;
  loreContextAr: string;
  loreContextEn: string;
  category: TaskCategory;
  threatLevel: TaskThreatLevel;
  requiredCompanionEmotion: FloatingCompanionEmotion;
  isCompleted: (flags: OpeningRoomNarrativeFlags, combatState: SectorCombatState) => boolean;
  isAvailable: (flags: OpeningRoomNarrativeFlags, combatState: SectorCombatState) => boolean;
}

export interface SectorCombatState {
  breachTriggered: boolean;
  bossActive: boolean;
  monsterHp: number;
  maxMonsterHp: number;
  monsterDefeated: boolean;
  substationOverridden: boolean;
}

export const INITIAL_SECTOR_COMBAT_STATE: SectorCombatState = {
  breachTriggered: false,
  bossActive: false,
  monsterHp: 1000,
  maxMonsterHp: 1000,
  monsterDefeated: false,
  substationOverridden: false,
};

export const SECTOR_11_STORY_TASKS: readonly SectorStoryTask[] = [
  {
    id: '11.1-wake-stasis',
    sector: 11,
    stageCode: 'SEC11-STG01',
    titleAr: 'صحوة السبات وانقطاع القياس',
    titleEn: 'Stasis Awakening & Telemetry Blackout',
    objectiveAr: 'افحص وحدة السبات EX-001 وتأكد من استقرار الإشارات الحيوية لـ Echo',
    objectiveEn: 'Inspect Stasis Pod EX-001 and confirm Echo biometric stabilization',
    loreContextAr: 'استيقظ Echo داخل كبسولة سداسية معزولة في منشأة مهجورة. لا أثر للطاقم، ومؤشرات الطاقة متذبذبة.',
    loreContextEn: 'Echo awakens inside an isolated hexagonal capsule in a ruined facility. No personnel trace remains.',
    category: 'exploration',
    threatLevel: 'safe',
    requiredCompanionEmotion: 'observing',
    isCompleted: (flags) => flags.openingRoomEntered === true,
    isAvailable: () => true,
  },
  {
    id: '11.2-digital-clock',
    sector: 11,
    stageCode: 'SEC11-STG02',
    titleAr: 'الأثر الزمني المجمد (11:11)',
    titleEn: 'Frozen Temporal Anchor (11:11)',
    objectiveAr: 'افحص الساعة الرقمية المتوقفة واسترجع التردد الزمني الأول',
    objectiveEn: 'Examine stopped digital clock and recover initial temporal resonance',
    loreContextAr: 'شاشة فلورية متجمدة عند 11:11. تشير إلى لحظة انهيار المحطة المركزية وتفعيل بروتوكول العزل التلقائي.',
    loreContextEn: 'Fluorescent display frozen at 11:11. Marks the moment of central core collapse and automatic isolation.',
    category: 'forensic',
    threatLevel: 'caution',
    requiredCompanionEmotion: 'scanning',
    isCompleted: (flags) => flags.openingClockInspected === true,
    isAvailable: (flags) => flags.openingRoomEntered === true,
  },
  {
    id: '11.3-torn-photo',
    sector: 11,
    stageCode: 'SEC11-STG03',
    titleAr: 'بصمة الذاكرة الممزقة',
    titleEn: 'Torn Memory Fragment',
    objectiveAr: 'افحص شظايا الصورة واستعد ذكرى الرفيق المفقود',
    objectiveEn: 'Inspect torn photo shards and recover the memory of the lost companion',
    loreContextAr: 'صورة متآكلة تحمل عبارة «عندما تشعر بالخوف، عُدّ حتى أحد عشر». نبضات الذاكرة تعيد إيقاظ الرفيق الطائر.',
    loreContextEn: 'Corroded photo reading "When afraid, count to eleven." Memory pulses awaken the floating companion.',
    category: 'forensic',
    threatLevel: 'caution',
    requiredCompanionEmotion: 'scanning',
    isCompleted: (flags) => flags.openingPhotoInspected === true && flags.openingMemoryRecovered === true,
    isAvailable: (flags) => flags.openingClockInspected === true,
  },
  {
    id: '11.4-substation-reroute',
    sector: 11,
    stageCode: 'SEC11-STG04',
    titleAr: 'محطة الصيانة والتحويل الطارئ',
    titleEn: 'Maintenance Substation Power Reroute',
    objectiveAr: 'تجاوز قفل وحدة التحكم الفرعية لإعادة توجيه الطاقة الهيدروليكية نحو بوابة الحجر',
    objectiveEn: 'Override auxiliary terminal to reroute hydraulic conduit power to the quarantine blast door',
    loreContextAr: 'البوابة الرئيسية مغلقة لعدم كفاية التيار. تحويل الطاقة عبر الخط الاحتياطي سيعيد تيار الباب ولكنه سيزعزع استقرار أقفال حجرة العينات.',
    loreContextEn: 'Main blast gate unpowered. Rerouting emergency auxiliary lines restores gate power but destabilizes containment pod locks.',
    category: 'technical',
    threatLevel: 'critical',
    requiredCompanionEmotion: 'alert',
    isCompleted: (_flags, combatState) => combatState.substationOverridden || combatState.breachTriggered,
    isAvailable: (flags) => flags.openingMemoryRecovered === true,
  },
  {
    id: '11.5-containment-breach',
    sector: 11,
    stageCode: 'SEC11-STG05',
    titleAr: 'اختراق الاحتواء: العينة المشوهة EX-004',
    titleEn: 'Containment Breach: Aberrant Specimen EX-004',
    objectiveAr: 'اصمد أمام هجوم الكيان المتحور، تفادَ ضرباته القاتلة واستخدم الدفاع الحركي لإخضاعه',
    objectiveEn: 'Survive mutated entity assault, dodge lethal strikes, and utilize physical counters to neutralize the threat',
    loreContextAr: 'انهيار زجاج حجرة الاحتواء القصوى أطلق عينة تجارب فاشلة ذات طفرات عضلية هائلة. Echo غير مجهز بقدرات خارقة، النجاة تعتمد على الرشاقة البشرية والتفادي المحكم.',
    loreContextEn: 'Shattered stasis glass releases an aberrant failed experiment. Echo has no divine power yet; survival demands raw agility and precise dodges.',
    category: 'survival_combat',
    threatLevel: 'extreme',
    requiredCompanionEmotion: 'distressed',
    isCompleted: (_flags, combatState) => combatState.monsterDefeated === true,
    isAvailable: (_flags, combatState) => combatState.breachTriggered === true,
  },
  {
    id: '11.6-quarantine-escape',
    sector: 11,
    stageCode: 'SEC11-STG06',
    titleAr: 'تفريغ الضغط والهروب إلى القطاع 03',
    titleEn: 'Quarantine Decompression & Sector 03 Escape',
    objectiveAr: 'اعبر بوابة الحجر الصحي الهيدروليكية المفتوحة وانطلق نحو نفق العبور',
    objectiveEn: 'Pass through the depressurized quarantine blast door into the transit tunnel of Sector 03',
    loreContextAr: 'مع عودة استقرار الضغط وسقوط الكيان، انفتحت بوابة الحجر الضخمة لتكشف عن ممرات القطاع 03 الغارقة في الظلام.',
    loreContextEn: 'With pressure stabilized and the entity fallen, the massive blast door slides open, unveiling dark Sector 03 transit corridors.',
    category: 'escape',
    threatLevel: 'resolved',
    requiredCompanionEmotion: 'celebrating',
    isCompleted: (flags) => flags.openingDoorUnlocked === true && flags.openingRoomCompleted === true,
    isAvailable: (_flags, combatState) => combatState.monsterDefeated === true || combatState.substationOverridden === true,
  },
];

/**
 * Returns the currently active high-priority story task based on narrative and combat state.
 */
export function getActiveSectorTask(
  flags: OpeningRoomNarrativeFlags,
  combatState: SectorCombatState,
): SectorStoryTask {
  for (const task of SECTOR_11_STORY_TASKS) {
    if (!task.isCompleted(flags, combatState) && task.isAvailable(flags, combatState)) {
      return task;
    }
  }
  // Fallback to the final task if all complete
  return SECTOR_11_STORY_TASKS[SECTOR_11_STORY_TASKS.length - 1];
}

/**
 * Calculates sector completion percentage (0 - 100).
 */
export function calculateSector11Progress(
  flags: OpeningRoomNarrativeFlags,
  combatState: SectorCombatState,
): number {
  const completedCount = SECTOR_11_STORY_TASKS.filter((task) =>
    task.isCompleted(flags, combatState),
  ).length;
  return Math.round((completedCount / SECTOR_11_STORY_TASKS.length) * 100);
}
