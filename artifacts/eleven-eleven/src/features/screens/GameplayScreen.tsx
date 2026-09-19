import { useCallback, useEffect, useState } from 'react';
import {
  useShellStore,
  useUiPreferencesStore,
} from '../../app/shell/shellStore';
import { useGameStore } from '../../stores/gameStore';
import { usePlayerProgressionStore } from '../player-progression/playerProgressionStore';
import type { AuthoritativeStoryState } from '../../domain/story/storyState';
import { GameButton, GameModal } from '../../ui/design-system';
import { GameWorld } from '../gameplay/components/GameWorld';
import {
  GameplayErrorBoundary,
} from '../gameplay/components/GameplayErrorBoundary';
import '../gameplay/gameplay.css';

export default function GameplayScreen() {
  const paused = useShellStore((shell) => shell.pauseOpen);
  const openPause = useShellStore((shell) => shell.openPause);
  const goBack = useShellStore((shell) => shell.goBack);
  const quality = useUiPreferencesStore(
    (preferences) => preferences.quality,
  );
  const motion = useUiPreferencesStore(
    (preferences) => preferences.motion,
  );
  const locale = useUiPreferencesStore(
    (preferences) => preferences.locale,
  );
  const experienceEntitlements = useShellStore(
    (shell) => shell.experienceEntitlements,
  );
  const requestManhwaReader = useShellStore(
    (shell) => shell.requestManhwaReader,
  );
  const [roomComplete, setRoomComplete] = useState(false);
  const [showCompletionModal, setShowCompletionModal] = useState(false);

  const handleRoomComplete = useCallback((storyState: AuthoritativeStoryState) => {
    usePlayerProgressionStore.getState().actions.hydrateStoryState(storyState);
    useGameStore.getState().actions.syncAuthoritativeStoryState(storyState);
    setRoomComplete(true);
    setShowCompletionModal(true);
  }, []);

  useEffect(() => {
    const game = useGameStore.getState();
    if (!game.narrative.activeFlags.opening_room_session_started) {
      game.actions.setNarrativeFlag(
        'opening_room_session_started',
        true,
      );
      game.actions.recordNarrativeDecision(
        'opening-room-session',
        'entered',
        'system',
      );
    }
  }, []);

  return (
    <GameplayErrorBoundary onExit={goBack}>
      <GameWorld
        paused={paused}
        quality={quality}
        motion={motion}
        onPause={openPause}
        onRoomComplete={handleRoomComplete}
      />
      {showCompletionModal && (
        <GameModal
          open={showCompletionModal}
          onClose={() => setShowCompletionModal(false)}
          eyebrow="11:11 // AWAKENING CLEAR"
          title={locale === 'ar' ? 'اكتملت الغرفة الافتتاحية // تم تحييد الطافر' : 'Opening Room Complete // Anomaly Neutralized'}
          description={
            locale === 'ar'
              ? 'تم فك تشفير الإشارة الأولى واعتماد تقدم Echo بنجاح. أصبحت صفحات المانهوا مفتوحة في الأرشيف.'
              : 'The first signal has been decoded and Echo progression verified. Manhwa pages are now unlocked in the archive.'
          }
          tone="memory"
          footer={(
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
              <GameButton
                variant="ghost"
                onClick={() => setShowCompletionModal(false)}
              >
                {locale === 'ar' ? 'البقاء واستكشاف الغرفة' : 'Stay and Explore Room'}
              </GameButton>
              {experienceEntitlements.accessibleScreens.includes('memories') && (
                <GameButton
                  variant="memory"
                  onClick={() => {
                    setShowCompletionModal(false);
                    requestManhwaReader();
                  }}
                >
                  {locale === 'ar' ? 'فتح قارئ المانهوا' : 'Open Manhwa Reader'}
                </GameButton>
              )}
            </div>
          )}
        >
          <div style={{ padding: '8px 0', fontSize: '14px', color: '#cbd5e1', lineHeight: '1.6' }}>
            {locale === 'ar'
              ? 'تهانينا! تم تحييد وحش الغرفة بنجاح وتجهيز سيف الكاتانا. يمكنك الآن استكمال الاستكشاف الحر وتجربة الكومبو القتالي أو الانتقال لقراءة أول فصل من المانهوا.'
              : 'Congratulations! The specimen has been neutralized. You can now freely explore the chamber, test martial arts combos, or proceed to the Manhwa reader.'}
          </div>
        </GameModal>
      )}
    </GameplayErrorBoundary>
  );
}
