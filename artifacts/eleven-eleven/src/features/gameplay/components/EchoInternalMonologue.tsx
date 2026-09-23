import React, { useEffect } from 'react';
import { useGameplayAudio } from '../audio/useGameplayAudio';

export interface MonologueEntry {
  id: string;
  textAr: string;
  textEn: string;
  speaker?: string;
  duration?: number;
}

export interface EchoInternalMonologueProps {
  monologue: MonologueEntry | null;
  onDismiss: () => void;
  reducedMotion?: boolean;
}

export const EchoInternalMonologue: React.FC<EchoInternalMonologueProps> = ({
  monologue,
  onDismiss,
  reducedMotion = false,
}) => {
  const { playCue } = useGameplayAudio();

  useEffect(() => {
    if (!monologue) return undefined;
    playCue('thoughtWhisper', { volume: 0.65 });
    const duration = monologue.duration ?? 5200;
    const timer = setTimeout(() => {
      onDismiss();
    }, duration);
    return () => clearTimeout(timer);
  }, [monologue, onDismiss, playCue]);

  if (!monologue) return null;

  return (
    <div
      role="status"
      aria-live="polite"
      onClick={onDismiss}
      style={{
        position: 'fixed',
        bottom: '88px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 8500,
        width: '90%',
        maxWidth: '680px',
        cursor: 'pointer',
        userSelect: 'none',
      }}
    >
      <div
        style={{
          background: 'linear-gradient(135deg, rgba(6, 14, 22, 0.94) 0%, rgba(12, 22, 34, 0.88) 100%)',
          backdropFilter: 'blur(10px)',
          WebkitBackdropFilter: 'blur(10px)',
          border: '1px solid rgba(0, 240, 255, 0.35)',
          borderLeft: '4px solid #00f0ff',
          borderRadius: '8px',
          padding: '14px 20px',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.65), 0 0 16px rgba(0, 240, 255, 0.15)',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px',
          transition: reducedMotion ? 'none' : 'opacity 0.35s ease, transform 0.35s cubic-bezier(0.16, 1, 0.3, 1)',
        }}
      >
        {/* Monologue Tag */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            fontSize: '11px',
            letterSpacing: '1.5px',
            color: '#00f0ff',
            fontWeight: 700,
            textTransform: 'uppercase',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span
              style={{
                width: '6px',
                height: '6px',
                borderRadius: '50%',
                background: '#00f0ff',
                boxShadow: '0 0 6px #00f0ff',
              }}
            />
            <span>{monologue.speaker ?? 'ECHO // المونولوج الداخلي'}</span>
          </div>
          <span style={{ color: 'rgba(255, 255, 255, 0.4)', fontSize: '10px' }}>
            [انقر للمتابعة]
          </span>
        </div>

        {/* Monologue Psychological Quote */}
        <div
          style={{
            fontSize: '16px',
            lineHeight: '1.6',
            color: '#eef8fc',
            fontStyle: 'italic',
            fontWeight: 500,
            textShadow: '0 2px 4px rgba(0,0,0,0.8)',
          }}
        >
          «{monologue.textAr}»
        </div>

        {/* English Canon Reference */}
        <div
          style={{
            fontSize: '12px',
            color: '#7e9aa8',
            fontStyle: 'normal',
            letterSpacing: '0.2px',
          }}
        >
          {monologue.textEn}
        </div>
      </div>
    </div>
  );
};
