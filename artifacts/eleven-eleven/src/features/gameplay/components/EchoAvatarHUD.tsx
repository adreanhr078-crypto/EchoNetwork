import React, { useMemo } from 'react';

export type EchoAvatarEmotion =
  | 'calm'
  | 'combat'
  | 'hurt'
  | 'surge'
  | 'stealth'
  | 'triumph';

export interface EchoAvatarHUDProps {
  emotion?: EchoAvatarEmotion;
  hp?: number;
  maxHp?: number;
  stamina?: number;
  maxStamina?: number;
  isSprinting?: boolean;
  isStealth?: boolean;
  perfectDodgeSurgeActive?: boolean;
  reducedMotion?: boolean;
  characterNameAr?: string;
  characterCode?: string;
}

export function EchoAvatarHUD({
  emotion = 'calm',
  hp = 100,
  maxHp = 100,
  stamina = 100,
  maxStamina = 100,
  isSprinting = false,
  isStealth = false,
  perfectDodgeSurgeActive = false,
  reducedMotion = false,
  characterNameAr = 'إيكو // ECHO',
  characterCode = 'SUBJECT EX-011',
}: EchoAvatarHUDProps) {
  // Determine effective visual state
  const effectiveEmotion: EchoAvatarEmotion = useMemo(() => {
    if (perfectDodgeSurgeActive) return 'surge';
    if (isStealth) return 'stealth';
    if (emotion === 'triumph') return 'triumph';
    if (emotion === 'hurt' || hp < 35) return 'hurt';
    if (emotion === 'combat' || isSprinting) return 'combat';
    return 'calm';
  }, [emotion, hp, isSprinting, isStealth, perfectDodgeSurgeActive]);

  const hpPercent = Math.max(0, Math.min(100, (hp / maxHp) * 100));
  const staminaPercent = Math.max(0, Math.min(100, (stamina / maxStamina) * 100));

  // Color schemes based on emotion
  const theme = useMemo(() => {
    switch (effectiveEmotion) {
      case 'surge':
        return {
          primary: '#ffaa00',
          secondary: '#ffe066',
          bgGlow: 'rgba(255, 170, 0, 0.22)',
          border: '#ffaa00',
          badge: 'SURGE // 3x POWER',
          eyeColor: '#ffbb00',
          irisGlow: '#ffeedd',
        };
      case 'stealth':
        return {
          primary: '#6b7280',
          secondary: '#9ca3af',
          bgGlow: 'rgba(55, 65, 81, 0.28)',
          border: '#4b5563',
          badge: 'STEALTH // CONCEALED',
          eyeColor: '#94a3b8',
          irisGlow: '#cbd5e1',
        };
      case 'hurt':
        return {
          primary: '#ff3355',
          secondary: '#ff8899',
          bgGlow: 'rgba(255, 51, 85, 0.25)',
          border: '#ff3355',
          badge: 'VITAL // CRITICAL',
          eyeColor: '#ff2244',
          irisGlow: '#ffaabb',
        };
      case 'combat':
        return {
          primary: '#00f0ff',
          secondary: '#70f7ff',
          bgGlow: 'rgba(0, 240, 255, 0.18)',
          border: '#00f0ff',
          badge: 'COMBAT // ENGAGED',
          eyeColor: '#00e5ff',
          irisGlow: '#ffffff',
        };
      case 'triumph':
        return {
          primary: '#10b981',
          secondary: '#6ee7b7',
          bgGlow: 'rgba(16, 185, 129, 0.22)',
          border: '#10b981',
          badge: 'VICTORY // CLEAR',
          eyeColor: '#34d399',
          irisGlow: '#ecfdf5',
        };
      default:
        return {
          primary: '#00f0ff',
          secondary: '#94a3b8',
          bgGlow: 'rgba(0, 240, 255, 0.08)',
          border: 'rgba(0, 240, 255, 0.45)',
          badge: 'SYNAPSE // STABLE',
          eyeColor: '#00f0ff',
          irisGlow: '#e0f7fa',
        };
    }
  }, [effectiveEmotion]);

  return (
    <div
      className={`echo-avatar-hud echo-avatar-hud--${effectiveEmotion}`}
      data-emotion={effectiveEmotion}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        padding: '6px 12px',
        background: `radial-gradient(ellipse at top left, ${theme.bgGlow} 0%, rgba(2, 6, 11, 0.92) 80%)`,
        border: `1.5px solid ${theme.border}`,
        borderRadius: '6px',
        boxShadow: `0 4px 20px rgba(0, 0, 0, 0.75), 0 0 14px ${theme.bgGlow}`,
        backdropFilter: 'blur(10px)',
        userSelect: 'none',
        pointerEvents: 'none',
      }}
      role="region"
      aria-label="الحالة الحيوية لـ Echo"
    >
      {/* Anime Face Portrait Frame (SVG Vector Character Art) */}
      <div
        className="echo-avatar-hud__frame"
        style={{
          position: 'relative',
          width: '54px',
          height: '54px',
          borderRadius: '50%',
          overflow: 'hidden',
          border: `2px solid ${theme.primary}`,
          background: '#040912',
          flexShrink: 0,
          boxShadow: `0 0 10px ${theme.primary}`,
        }}
      >
        <svg
          viewBox="0 0 100 100"
          width="100%"
          height="100%"
          style={{
            display: 'block',
            animation: !reducedMotion ? 'echoBreathe 3.6s ease-in-out infinite' : undefined,
          }}
        >
          <defs>
            <linearGradient id="hairGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#d1d5db" />
              <stop offset="45%" stopColor="#6b7280" />
              <stop offset="100%" stopColor="#1f2937" />
            </linearGradient>
            <linearGradient id="skinGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#fdf2e9" />
              <stop offset="100%" stopColor="#ecd5c1" />
            </linearGradient>
            <linearGradient id="shadowSkin" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#ecd5c1" />
              <stop offset="100%" stopColor="#c5a890" />
            </linearGradient>
            <radialGradient id="pupilGlow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor={theme.irisGlow} />
              <stop offset="55%" stopColor={theme.eyeColor} />
              <stop offset="100%" stopColor="#082f49" />
            </radialGradient>
          </defs>

          {/* Background Neural Matrix Grid */}
          <rect width="100" height="100" fill="#040912" />
          <path
            d="M0 25 H100 M0 50 H100 M0 75 H100 M25 0 V100 M50 0 V100 M75 0 V100"
            stroke="rgba(0, 240, 255, 0.08)"
            strokeWidth="0.8"
          />

          {/* Cybernetic Neck & Collar */}
          <path d="M40 76 L40 92 L60 92 L60 76 Z" fill="url(#shadowSkin)" />
          <path d="M35 88 L65 88 L62 98 L38 98 Z" fill="#111827" stroke={theme.primary} strokeWidth="1" />
          {/* Collar LED */}
          <circle cx="50" cy="93" r="1.8" fill={theme.primary}>
            {!reducedMotion && (
              <animate
                attributeName="opacity"
                values="0.4;1;0.4"
                dur="1.8s"
                repeatCount="indefinite"
              />
            )}
          </circle>

          {/* Head & Face Contour */}
          <path
            d="M32 40 C32 26, 68 26, 68 40 C68 56, 58 74, 50 78 C42 74, 32 56, 32 40 Z"
            fill="url(#skinGrad)"
          />

          {/* Synaptic Cheek Circuit Lines */}
          <path
            d="M34 52 L39 55 L38 60"
            fill="none"
            stroke={theme.primary}
            strokeWidth="0.9"
            opacity={effectiveEmotion === 'combat' || effectiveEmotion === 'surge' ? 0.9 : 0.3}
          />
          <path
            d="M66 52 L61 55 L62 60"
            fill="none"
            stroke={theme.primary}
            strokeWidth="0.9"
            opacity={effectiveEmotion === 'combat' || effectiveEmotion === 'surge' ? 0.9 : 0.3}
          />

          {/* Anime Eyes & Eyebrows */}
          {/* Left Eye */}
          <g transform="translate(37, 46)">
            {/* Eyebrow */}
            <path
              d={effectiveEmotion === 'combat' || effectiveEmotion === 'hurt'
                ? "M -2 -5 L 8 -2"
                : effectiveEmotion === 'triumph'
                  ? "M -2 -4 Q 3 -7 8 -4"
                  : "M -2 -4 L 8 -4"}
              stroke="#374151"
              strokeWidth="1.4"
              strokeLinecap="round"
            />
            {/* Sclera & Eyelid */}
            <path d="M -1 0 Q 3.5 -3 8 0 Q 3.5 3.5 -1 0 Z" fill="#ffffff" />
            {/* Iris & Glowing Pupil */}
            <circle cx="3.5" cy="0" r="2.4" fill="url(#pupilGlow)" />
            <circle cx="2.6" cy="-0.8" r="0.8" fill="#ffffff" opacity="0.9" />
            {/* Ocular reticle ring */}
            <circle
              cx="3.5"
              cy="0"
              r="2.8"
              fill="none"
              stroke={theme.primary}
              strokeWidth="0.4"
              strokeDasharray="1.5 1.5"
            />
          </g>

          {/* Right Eye */}
          <g transform="translate(55, 46)">
            {/* Eyebrow */}
            <path
              d={effectiveEmotion === 'combat' || effectiveEmotion === 'hurt'
                ? "M 10 -5 L 0 -2"
                : effectiveEmotion === 'triumph'
                  ? "M 10 -4 Q 5 -7 0 -4"
                  : "M 10 -4 L 0 -4"}
              stroke="#374151"
              strokeWidth="1.4"
              strokeLinecap="round"
            />
            {/* Sclera & Eyelid */}
            <path d="M 9 0 Q 4.5 -3 0 0 Q 4.5 3.5 9 0 Z" fill="#ffffff" />
            {/* Iris & Glowing Pupil */}
            <circle cx="4.5" cy="0" r="2.4" fill="url(#pupilGlow)" />
            <circle cx="3.6" cy="-0.8" r="0.8" fill="#ffffff" opacity="0.9" />
            {/* Ocular reticle ring */}
            <circle
              cx="4.5"
              cy="0"
              r="2.8"
              fill="none"
              stroke={theme.primary}
              strokeWidth="0.4"
              strokeDasharray="1.5 1.5"
            />
          </g>

          {/* Nose & Mouth */}
          <path d="M50 54 L51 58 L49.5 58" fill="none" stroke="#b49176" strokeWidth="0.8" />
          <path
            d={effectiveEmotion === 'triumph'
              ? "M 46 65 Q 50 68 54 64"
              : effectiveEmotion === 'hurt'
                ? "M 46 66 L 54 65"
                : effectiveEmotion === 'combat'
                  ? "M 47 65 L 53 65"
                  : "M 47 64 Q 50 65 53 64"}
            fill="none"
            stroke="#6b4c38"
            strokeWidth="1.1"
            strokeLinecap="round"
          />

          {/* Anime Hair (Layered Silver/Charcoal Locks) */}
          {/* Back hair volume */}
          <path
            d="M26 38 C22 55, 25 65, 30 72 C32 60, 30 48, 32 38 Z"
            fill="#1f2937"
          />
          <path
            d="M74 38 C78 55, 75 65, 70 72 C68 60, 70 48, 68 38 Z"
            fill="#1f2937"
          />
          {/* Top hair spikes & bangs */}
          <path
            d="M28 36 C25 20, 42 12, 50 12 C58 12, 75 20, 72 36 C66 28, 55 24, 50 24 C45 24, 34 28, 28 36 Z"
            fill="url(#hairGrad)"
          />
          {/* Front fringe strands */}
          <path d="M36 28 L40 46 L43 32 L47 48 L50 30 L54 47 L58 32 L62 44 L65 28 Z" fill="url(#hairGrad)" />
          {/* Signature highlighted lock */}
          <path d="M46 22 L48 42 L51 28 Z" fill="#f3f4f6" opacity="0.85" />
          <path d="M38 26 L41 38 L42 28 Z" fill="#e5e7eb" opacity="0.65" />

          {/* Surge Aura Sparks (Active in Surge mode) */}
          {effectiveEmotion === 'surge' && !reducedMotion && (
            <g stroke="#ffe066" strokeWidth="1" opacity="0.9">
              <path d="M18 35 L22 30 L20 24" />
              <path d="M82 35 L78 30 L80 24" />
              <path d="M50 8 L52 3 L48 0" />
            </g>
          )}
        </svg>

        {/* Status Indicator Pip */}
        <div
          style={{
            position: 'absolute',
            bottom: '2px',
            right: '2px',
            width: '8px',
            height: '8px',
            borderRadius: '50%',
            background: theme.primary,
            boxShadow: `0 0 6px ${theme.primary}`,
          }}
        />
      </div>

      {/* Vitals & Identity Column */}
      <div
        className="echo-avatar-hud__vitals"
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '3px',
          minWidth: '130px',
        }}
      >
        {/* Name & Badge Row */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '8px',
            lineHeight: 1,
          }}
        >
          <strong
            style={{
              fontFamily: "'Space Grotesk', system-ui, sans-serif",
              fontSize: '11px',
              fontWeight: 800,
              color: '#ffffff',
              letterSpacing: '0.04em',
            }}
          >
            {characterNameAr}
          </strong>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: '8px',
              fontWeight: 700,
              color: theme.primary,
              letterSpacing: '0.06em',
              textTransform: 'uppercase',
            }}
          >
            {theme.badge}
          </span>
        </div>

        {/* Biometric Integrity (HP Bar) */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: '8px',
              color: '#94a3b8',
              width: '18px',
            }}
          >
            HP
          </span>
          <div
            style={{
              flex: 1,
              height: '5px',
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '2px',
              overflow: 'hidden',
            }}
          >
            <div
              style={{
                width: `${hpPercent}%`,
                height: '100%',
                background:
                  hpPercent < 35
                    ? 'linear-gradient(90deg, #ff0044, #ff3366)'
                    : 'linear-gradient(90deg, #00f0ff, #38bdf8)',
                boxShadow: hpPercent < 35 ? '0 0 6px #ff0044' : '0 0 6px #00f0ff',
                transition: 'width 0.25s ease-out',
              }}
            />
          </div>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: '8px',
              color: '#e2e8f0',
              fontWeight: 600,
            }}
          >
            {Math.round(hp)}
          </span>
        </div>

        {/* Neural Stamina Bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: '8px',
              color: '#94a3b8',
              width: '18px',
            }}
          >
            STM
          </span>
          <div
            style={{
              flex: 1,
              height: '4px',
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '2px',
              overflow: 'hidden',
            }}
          >
            <div
              style={{
                width: `${staminaPercent}%`,
                height: '100%',
                background: 'linear-gradient(90deg, #eab308, #facc15)',
                boxShadow: '0 0 5px #eab308',
                transition: 'width 0.15s ease-out',
              }}
            />
          </div>
          <span
            style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: '8px',
              color: '#cbd5e1',
            }}
          >
            {characterCode}
          </span>
        </div>
      </div>
    </div>
  );
}
