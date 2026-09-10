import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useUiPreferencesStore } from '../../../app/shell/shellStore';

export interface CinematicSequence {
  id: string;
  videoUrl: string; // The AI-generated WebM/MP4
  fallbackImageUrl?: string; // High quality AI-generated poster
  durationMs?: number; // Optional duration override
}

interface CinematicDirectorProps {
  sequence: CinematicSequence | null;
  onComplete: () => void;
  onSkip?: () => void;
  reducedMotion: boolean;
}

/**
 * Handles the playback of high-fidelity AI-generated cinematic video cuts.
 * Overlays the entire screen smoothly and restores control gracefully.
 */
export function CinematicDirector({
  sequence,
  onComplete,
  onSkip,
  reducedMotion,
}: CinematicDirectorProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [failed, setFailed] = useState(false);
  const locale = useUiPreferencesStore(state => state.locale);
  const audioEnabled = useUiPreferencesStore(state => state.audioEnabled);
  const completionRef = useRef(onComplete);
  completionRef.current = onComplete;
  const videoRef = useRef<HTMLVideoElement>(null);

  // If reduced motion is on, or no sequence, we might skip video and just fire onComplete
  useEffect(() => {
    if (!sequence) {
      setIsPlaying(false);
      return;
    }

    if (reducedMotion) {
      // Preserve the key frame long enough to orient the player, without making
      // Reduced Motion wait through the full cinematic duration.
      const timer = setTimeout(() => completionRef.current(), 2000);
      return () => clearTimeout(timer);
    }

    setIsPlaying(true);
    setFailed(false);
    
    if (videoRef.current) {
      videoRef.current.currentTime = 0;
      videoRef.current.play().catch(() => {
        setIsPlaying(false);
      });
    }
    
    return undefined;
  }, [sequence?.id, sequence?.videoUrl, reducedMotion]);

  if (!sequence && !isPlaying) return null;

  const content = (
    <div
      className="cinematic-director-overlay"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 9999,
        backgroundColor: '#000',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        opacity: sequence ? 1 : 0,
        transition: 'opacity 0.8s ease-in-out',
        pointerEvents: sequence ? 'auto' : 'none',
      }}
    >
      {sequence && !reducedMotion && (
        <video
          ref={videoRef}
          src={sequence.videoUrl}
          poster={sequence.fallbackImageUrl}
          playsInline
          muted={!audioEnabled}
          controls
          onEnded={onComplete}
          onError={() => { setFailed(true); setIsPlaying(false); }}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'contain',
          }}
        />
      )}
      {sequence && reducedMotion && sequence.fallbackImageUrl && (
        <img
          src={sequence.fallbackImageUrl}
          alt="Cinematic sequence frame"
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            transform: isPlaying && !reducedMotion ? 'scale(1.08) translate(1%, 1%)' : 'scale(1)',
            transition: `transform ${sequence.durationMs ?? 4500}ms ease-out`,
          }}
        />
      )}
      {sequence && failed && <div role="alert" style={{ position: 'absolute', top: '40%', padding: '1rem', background: '#101018', color: '#f1ede6' }}>
        <p>{locale === 'ar' ? 'تعذر تحميل المشهد. يمكنك إعادة المحاولة أو تجاوزه.' : 'The cinematic could not load. Retry or skip it.'}</p>
        <button type="button" onClick={() => { setFailed(false); videoRef.current?.load(); void videoRef.current?.play().catch(() => setFailed(true)); }}>
          {locale === 'ar' ? 'إعادة المحاولة' : 'Retry'}
        </button>
      </div>}
      
      {sequence && onSkip && (
        <button
          type="button"
          onClick={onSkip}
          className="cinematic-skip-button"
          style={{
            position: 'absolute',
            bottom: 'env(safe-area-inset-bottom, 24px)',
            right: 'env(safe-area-inset-right, 24px)',
            padding: '12px 24px',
            backgroundColor: 'rgba(0,0,0,0.5)',
            color: '#fff',
            border: '1px solid rgba(255,255,255,0.2)',
            borderRadius: '4px',
            fontFamily: 'monospace',
            cursor: 'pointer',
            backdropFilter: 'blur(4px)',
          }}
        >
          {locale === 'ar' ? 'تجاوز المشهد' : 'Skip cinematic'}
        </button>
      )}
    </div>
  );

  return createPortal(content, document.body);
}
