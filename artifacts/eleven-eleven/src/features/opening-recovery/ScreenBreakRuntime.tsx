import { useEffect, useRef } from 'react';

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
    <div className="screen-break-runtime" role="dialog" aria-modal="true" aria-label="Screen break">
      {reducedMotion ? (
        <div
          className="screen-break-runtime__poster"
          style={{
            backgroundImage: 'url("/assets/cinematics/part-1-opening-poster.webp")',
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
          src="/assets/cinematics/part-1-opening.webm"
          poster="/assets/cinematics/part-1-opening-poster.webp"
          autoPlay
          muted={!soundsEnabled}
          playsInline
          onEnded={finish}
          style={{ width: '100%', height: '100%', objectFit: 'cover', position: 'absolute', top: 0, left: 0 }}
        />
      )}
      <div className="screen-break-runtime__hud" aria-hidden="true">
        <small>INTERFACE LAYER // FAILURE</small>
        <strong>11:11</strong>
        <span>DEPTH CHANNEL OPEN</span>
      </div>
      <button type="button" className="screen-break-runtime__skip" onClick={finish}>
        Skip transition
      </button>
    </div>
  );
}
