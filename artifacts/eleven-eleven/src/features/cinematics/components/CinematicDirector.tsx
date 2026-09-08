import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

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
  const videoRef = useRef<HTMLVideoElement>(null);

  // If reduced motion is on, or no sequence, we might skip video and just fire onComplete
  useEffect(() => {
    if (!sequence) {
      setIsPlaying(false);
      return;
    }

    if (reducedMotion) {
      // In reduced motion, we could show the fallback image instead of playing video,
      // or just immediately complete the sequence.
      const timer = setTimeout(onComplete, sequence.durationMs ?? 2000);
      return () => clearTimeout(timer);
    }

    setIsPlaying(true);
    
    if (videoRef.current) {
      videoRef.current.currentTime = 0;
      videoRef.current.play().catch((err) => {
        console.warn('Cinematic autoplay failed, skipping:', err);
        onComplete();
      });
    }
    
    return undefined;
  }, [sequence, reducedMotion, onComplete]);

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
          muted // Muted to allow autoplay without interaction if needed
          onEnded={onComplete}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
          }}
        />
      )}
      {sequence && (!videoRef.current?.src || reducedMotion) && sequence.fallbackImageUrl && (
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
          SKIP
        </button>
      )}
    </div>
  );

  return createPortal(content, document.body);
}
