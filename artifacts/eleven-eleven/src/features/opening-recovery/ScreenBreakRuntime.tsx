import { useEffect, useRef } from 'react';
import { useUiPreferencesStore } from '../../app/shell/shellStore';

interface ScreenBreakRuntimeProps {
  reducedMotion: boolean;
  onComplete: () => void;
}
import { useEchoMindLivingStore } from '../../application/echo/echoMindLivingStore';

export function ScreenBreakRuntime({
  reducedMotion,
  onComplete,
}: ScreenBreakRuntimeProps) {
  const completedRef = useRef(false);
  const finish = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    onComplete();
  };

  const soundsEnabled = useEchoMindLivingStore(s => s.preferences.signalSoundsEnabled);
  const locale = useUiPreferencesStore((state) => state.locale);
  const copy = locale === 'ar'
    ? { label: 'انتقال إلى عمق النظام', layer: 'طبقة الواجهة تتشظّى', channel: 'القناة العميقة مفتوحة', skip: 'تجاوز المشهد' }
    : { label: 'Transitioning into system depth', layer: 'Interface layer fracturing', channel: 'Depth channel open', skip: 'Skip cinematic' };

  useEffect(() => {
    if (reducedMotion) {
      const timer = window.setTimeout(finish, 2000);
      return () => window.clearTimeout(timer);
    }
    // For non-reduced motion, the video onEnded event will trigger finish()
    // We add a safety timeout just in case the video fails to play or hangs.
    const fallbackTimer = window.setTimeout(finish, 28000);
    return () => window.clearTimeout(fallbackTimer);
  }, [reducedMotion]);

  return (
    <div className="screen-break-runtime" role="dialog" aria-modal="true" aria-label={copy.label}>
      {reducedMotion ? (
        <div
          className="screen-break-runtime__poster"
          style={{
            backgroundImage: 'url("/assets/cinematics/part-1-opening-v2-poster.webp")',
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            position: 'absolute',
          }}
        />
      ) : (
        <video
          className="screen-break-runtime__video"
          src="/assets/cinematics/part-1-opening-v2.webm"
          poster="/assets/cinematics/part-1-opening-v2-poster.webp"
          autoPlay
          muted={!soundsEnabled}
          playsInline
          onEnded={finish}
          onError={finish}
          style={{ width: '100%', height: '100%', objectFit: 'cover', position: 'absolute', top: 0, left: 0 }}
        />
      )}
      <div className="screen-break-runtime__hud" aria-hidden="true">
        <small>{copy.layer}</small>
        <strong>11:11</strong>
        <span>{copy.channel}</span>
      </div>
      <button type="button" className="screen-break-runtime__skip" onClick={finish}>
        {copy.skip}
      </button>
    </div>
  );
}
