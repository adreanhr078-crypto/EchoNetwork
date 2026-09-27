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
import { GodotOpeningRoom } from '../gameplay/components/GodotOpeningRoom';
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
  const audioEnabled = useUiPreferencesStore((preferences) => preferences.audioEnabled);
  const locale = useUiPreferencesStore(
    (preferences) => preferences.locale,
  );
  const experienceEntitlements = useShellStore(
    (shell) => shell.experienceEntitlements,
  );
  const requestManhwaReader = useShellStore(
    (shell) => shell.requestManhwaReader,
  );
  const [useWebRoom, setUseWebRoom] = useState(false);
  const [showCompletionModal, setShowCompletionModal] = useState(false);

  const handleRoomComplete = useCallback((storyState: AuthoritativeStoryState, awarded = true) => {
    usePlayerProgressionStore.getState().actions.hydrateStoryState(storyState);
    useGameStore.getState().actions.syncAuthoritativeStoryState(storyState);
    setShowCompletionModal(awarded);
  }, []);
  const fallbackToWebRoom = useCallback(() => setUseWebRoom(true), []);

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
      {useWebRoom ? <GameWorld
        paused={paused}
        quality={quality}
        motion={motion}
        onPause={openPause}
        onRoomComplete={handleRoomComplete}
      /> : <GodotOpeningRoom
        locale={locale}
        muted={!audioEnabled}
        reducedMotion={motion === 'reduced'}
        onFallback={fallbackToWebRoom}
        onRoomComplete={handleRoomComplete}
      />}
      {showCompletionModal && (
        <GameModal
          open={showCompletionModal}
          onClose={() => setShowCompletionModal(false)}
          eyebrow="11:11 // AWAKENING CLEAR"
          title={locale === 'ar' ? 'اكتملت الغرفة الافتتاحية' : 'Opening Room Complete'}
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
              ? 'استعدت أثر البداية وفتحت الطريق إلى ما وراء البوابة. يمكنك العودة إلى الغرفة أو قراءة الصفحات التي أتاحها الخادم.'
              : 'You recovered the first trace and opened the threshold. You can return to the room or read the pages unlocked by the server.'}
          </div>
        </GameModal>
      )}
    </GameplayErrorBoundary>
  );
}
