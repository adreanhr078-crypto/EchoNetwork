import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { useUiPreferencesStore } from '../../app/shell/shellStore';

interface ScreenBreakRuntimeProps {
  reducedMotion: boolean;
  onComplete: () => void;
  showFracture?: boolean;
  videoUrl?: string;
  posterUrl?: string;
}

export function ScreenBreakRuntime({
  reducedMotion,
  onComplete,
  showFracture = true,
  videoUrl = '/assets/cinematics/part-1-opening-v2.webm',
  posterUrl = '/assets/cinematics/part-1-opening-v2-poster.webp',
}: ScreenBreakRuntimeProps) {
  const completedRef = useRef(false);
  const onCompleteRef = useRef(onComplete);
  onCompleteRef.current = onComplete;
  const videoRef = useRef<HTMLVideoElement>(null);
  const [boardRect] = useState(() => document.querySelector('.opening-recovery__board')?.getBoundingClientRect());
  const [fracturing, setFracturing] = useState(showFracture && !reducedMotion);
  const [playback, setPlayback] = useState<'loading' | 'playing' | 'paused' | 'error'>('loading');
  const finish = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    videoRef.current?.pause();
    onCompleteRef.current();
  };

  const soundsEnabled = useUiPreferencesStore(state => state.audioEnabled);
  const locale = useUiPreferencesStore((state) => state.locale);
  const copy = locale === 'ar'
    ? { label: 'انتقال إلى عمق النظام', layer: 'طبقة الواجهة تتشظّى', channel: 'القناة العميقة مفتوحة', skip: 'تجاوز المشهد' }
    : { label: 'Transitioning into system depth', layer: 'Interface layer fracturing', channel: 'Depth channel open', skip: 'Skip cinematic' };

  useEffect(() => {
    const timer = window.setTimeout(() => setFracturing(false), reducedMotion ? 0 : 1500);
    return () => window.clearTimeout(timer);
  }, [reducedMotion]);

  useEffect(() => {
    if (fracturing || reducedMotion) return;
    let active = true;
    void videoRef.current?.play().catch(() => { if (active) setPlayback('paused'); });
    return () => { active = false; };
  }, [fracturing, reducedMotion]);

  useEffect(() => {
    if (fracturing || reducedMotion || playback !== 'loading') return;
    const timer = window.setTimeout(() => {
      videoRef.current?.pause();
      setPlayback('error');
    }, 20000);
    return () => window.clearTimeout(timer);
  }, [fracturing, reducedMotion, playback]);

  return (
    <div className="screen-break-runtime" role="dialog" aria-modal="true" aria-label={copy.label}
      onKeyDown={event => { if (event.key === 'Escape') { event.preventDefault(); finish(); } }}>
      {reducedMotion ? (
        <div
          className="screen-break-runtime__poster"
          style={{
            backgroundImage: `url("${posterUrl}")`,
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            position: 'absolute',
          }}
        />
      ) : (
        <video
          ref={videoRef}
          className="screen-break-runtime__video"
          src={videoUrl}
          poster={posterUrl}
          muted={!soundsEnabled}
          playsInline
          controls={!fracturing}
          onPlaying={() => setPlayback('playing')}
          onPause={() => setPlayback(current => current === 'error' ? current : 'paused')}
          onWaiting={() => setPlayback('loading')}
          onEnded={finish}
          onError={() => setPlayback('error')}
          style={{ width: '100%', height: '100%', objectFit: 'contain', position: 'absolute', top: 0, left: 0 }}
        />
      )}
      {fracturing && !reducedMotion && <div className="screen-break-runtime__fracture" aria-hidden="true" style={boardRect ? { inset: 'auto', left: boardRect.left, top: boardRect.top, width: boardRect.width, height: boardRect.height, overflow: 'visible' } : undefined}>
        {Array.from({ length: 24 }, (_, index) => {
          const cell = Math.floor(index / 2);
          const x = cell % 4;
          const y = Math.floor(cell / 4);
          const points = index % 2 === 0
            ? `${x * 25}% ${y * 100 / 3}%, ${(x + 1) * 25}% ${y * 100 / 3}%, ${x * 25}% ${(y + 1) * 100 / 3}%`
            : `${(x + 1) * 25}% ${y * 100 / 3}%, ${(x + 1) * 25}% ${(y + 1) * 100 / 3}%, ${x * 25}% ${(y + 1) * 100 / 3}%`;
          return <span key={index} style={{ clipPath: `polygon(${points})`, '--shard-x': `${(x - 1.5) * 35}vw`, '--shard-y': `${(y - 1) * 45 + 12}vh`, '--shard-turn': `${(index % 5 - 2) * 12}deg`, animationDelay: `${cell % 3 * 35}ms` } as CSSProperties} />;
        })}
      </div>}
      {!fracturing && playback === 'error' && <div className="screen-break-runtime__message" role="alert">
        <p>{locale === 'ar' ? 'تعذر تشغيل المشهد. أعد تحميله أو تابع إلى الغرفة.' : 'The cinematic could not play. Reload it or continue to the room.'}</p>
        <button type="button" onClick={() => {
          setPlayback('loading');
          videoRef.current?.load();
          void videoRef.current?.play().catch(() => setPlayback('paused'));
        }}>{locale === 'ar' ? 'إعادة تحميل المشهد' : 'Reload cinematic'}</button>
      </div>}
      <button autoFocus type="button" className="screen-break-runtime__skip" onClick={finish}>
        {reducedMotion ? locale === 'ar' ? 'المتابعة إلى إيكو' : 'Continue to Echo' : copy.skip}
      </button>
    </div>
  );
}
