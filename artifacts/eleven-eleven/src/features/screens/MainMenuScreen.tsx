import { useEffect, useMemo, useState } from 'react';
import {
  CinematicFrame,
  GameButton,
  GlassPanel,
} from '../../ui/design-system';
import { GameIcon } from '../../ui/icons';
import { useShellStore, useUiPreferencesStore } from '../../app/shell/shellStore';
import {
  EchoPresence,
  ENVIRONMENT_PRESENTATION_ASSETS,
} from '../../ui/presentation';
import { AuthStatusButton } from '../auth/AuthStatusButton';
import { AuthPanel } from '../auth/AuthPanel';
import { useAuthStore } from '../auth/authStore';
import { useStoryPuzzleStore } from '../story-puzzles/storyPuzzleStore';
import { deriveCorePlayerObjective } from '../../application/player-journey/corePlayerLoop';
import { usePlayerProgressionStore } from '../player-progression/playerProgressionStore';

const MAIN_MENU_COPY = {
  ar: {
    ariaLabel: 'القائمة الرئيسية',
    scene: 'القائمة الرئيسية',
    identity: 'أنت لست مجرد ذكريات.',
    identityStrong: 'أنت الحقيقة التي تحاول استعادتها.',
    resume: 'استعادة الاتصال',
    enterMissionControl: 'الذهاب إلى مركز المهمة',
    start: 'ابدأ الرحلة',
    identityFirst: 'ثبّت هويتك أولًا',
    signIn: 'سجّل الدخول وابدأ',
    memories: 'الذكريات',
    network: 'شبكة Echo',
    newGame: 'لعبة جديدة',
    nextStep: 'خطوتك التالية',
    signInExplainer: 'تسجيل الدخول يربط دليلك بحسابك',
    signInDetail: 'يمكنك إنشاء حساب أو متابعة كضيف، ثم ستقابل Echo قبل أول دليل.',
    interactiveAudio: 'مؤثرات تفاعلية متاحة · الصوت المؤلف قيد الإضافة',
    resetEyebrow: 'إعادة تهيئة الذاكرة',
    resetTitle: 'بدء رحلة جديدة؟',
    resetDescription: 'سيتم مسح التقدم المحلي الحالي بعد التأكيد. لا يمكن التراجع عن هذا الإجراء.',
    cancel: 'إلغاء',
    confirmReset: 'بدء لعبة جديدة',
    resetNote: 'هذا يعيد حالة اللاعب فقط ويحافظ على بنية المحتوى والأنظمة كما هي.',
  },
  en: {
    ariaLabel: 'Main menu',
    scene: 'Main menu',
    identity: 'You are not only memories.',
    identityStrong: 'You are the truth trying to return.',
    resume: 'Restore the connection',
    enterMissionControl: 'Open Mission Control',
    start: 'Begin the journey',
    identityFirst: 'Secure your identity first',
    signIn: 'Sign in and begin',
    memories: 'Memories',
    network: 'Echo Network',
    newGame: 'New game',
    nextStep: 'Your next step',
    signInExplainer: 'Sign-in connects your evidence to an account',
    signInDetail: 'Create an account or continue as a guest; then Echo will meet you before your first clue.',
    interactiveAudio: 'Interactive effects are available · composed music is coming',
    resetEyebrow: 'Memory reset',
    resetTitle: 'Begin a new journey?',
    resetDescription: 'Your current local progress will be cleared after confirmation. This cannot be undone.',
    cancel: 'Cancel',
    confirmReset: 'Start new game',
    resetNote: 'This resets player state only; it preserves content and system structure.',
  },
} as const;

export default function MainMenuScreen() {
  const navigate = useShellStore((shell) => shell.navigate);
  const locale = useUiPreferencesStore((preferences) => preferences.locale);
  const copy = MAIN_MENU_COPY[locale];
  const storyPuzzleSnapshot = useStoryPuzzleStore((store) => store.snapshot);
  const authoritativeStoryState = usePlayerProgressionStore(
    (store) => store.storyState,
  );
  const authStatus = useAuthStore((store) => store.status);
  const authConfigured = useAuthStore((store) => store.configured);
  const [authOpen, setAuthOpen] = useState(false);
  const objective = useMemo(
    // Legacy two-argument signature remains supported for non-authenticated
    // shell previews: deriveCorePlayerObjective(storyPuzzleSnapshot, locale)
    () => deriveCorePlayerObjective(
      storyPuzzleSnapshot,
      locale,
      authoritativeStoryState,
    ),
    [authoritativeStoryState, locale, storyPuzzleSnapshot],
  );
  const signedIn = authStatus === 'signed-in';

  useEffect(() => {
    if (signedIn) setAuthOpen(false);
  }, [signedIn]);

  const continueJourney = () => {
  if (!signedIn) {
    if (import.meta.env.DEV && !authConfigured) {
      navigate('play');
      return;
    }
    setAuthOpen(true);
    return;
  }
  navigate('psychological-state');
};

  return (
    <CinematicFrame
      className="shell-main-menu"
      overlay="strong"
      safeContent
      aria-label={copy.ariaLabel}
      dir={locale === 'ar' ? 'rtl' : 'ltr'}
    >
      <div
        className="shell-main-menu__world"
        style={{
          backgroundImage: `url("${ENVIRONMENT_PRESENTATION_ASSETS.mainMenuWorld}")`,
        }}
        aria-hidden="true"
      >
        <span className="shell-main-menu__world-drift" />
        <span className="shell-main-menu__world-light" />
        <span className="shell-main-menu__world-foreground" />
      </div>

      <div className="shell-main-menu__atmosphere" aria-hidden="true">
        <span className="shell-main-menu__orbit shell-main-menu__orbit--one" />
        <span className="shell-main-menu__orbit shell-main-menu__orbit--two" />
        <span className="shell-main-menu__embers">
          {Array.from({ length: 16 }, (_, index) => (
            <i key={index} />
          ))}
        </span>
      </div>

      <EchoPresence
        className="shell-main-menu__echo"
        variant="hero"
        eager
      />

      <header className="shell-main-menu__utility shell-main-menu__utility--minimal">
        <span className="shell-main-menu__scene-title">
          <span className="shell-screen-code">00</span>
          <strong>{copy.scene}</strong>
        </span>
        <AuthStatusButton
          variant="ghost"
          className="shell-main-menu__auth-control"
        />
      </header>

      <section className="shell-main-menu__identity">
        <small>PROJECT</small>
        <h1>11:11</h1>
        <p>ECHOES OF THE FORGOTTEN</p>
        <span className="shell-main-menu__line" aria-hidden="true" />
        <blockquote>
          {copy.identity}
          <strong> {copy.identityStrong}</strong>
        </blockquote>
      </section>

      <div className="shell-main-menu__action-anchor">
        <GlassPanel
          className="shell-main-menu__actions"
          tone="danger"
          eyebrow="Echo Channel"
          title={signedIn
            ? copy.resume
            : copy.identityFirst}
        >
          <GameButton
            size="lg"
            fullWidth
            leadingIcon={<GameIcon id={signedIn
              ? 'screen-psychological-state'
              : 'category-characters'} />}
            onClick={continueJourney}
          >
            {signedIn ? copy.enterMissionControl : copy.signIn}
          </GameButton>
          <div className="shell-main-menu__checkpoint">
            <span>{copy.nextStep}</span>
            <strong>{signedIn ? objective.title : copy.signInExplainer}</strong>
            <small>{signedIn ? objective.detail : copy.signInDetail}</small>
          </div>
        </GlassPanel>
      </div>

      <footer className="shell-main-menu__footer">
        <span>{locale === 'en' ? 'Browser Interface Ready' : 'واجهة المتصفح جاهزة'}</span>
        <span className="shell-main-menu__audio-signal">
          <i /><i /><i /><i /><i /><i /><i /><i />
          {copy.interactiveAudio}
        </span>
      </footer>

      <AuthPanel open={authOpen} onClose={() => setAuthOpen(false)} />
    </CinematicFrame>
  );
}
