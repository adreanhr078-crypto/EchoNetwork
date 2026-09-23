import React, { useEffect, useState, type PointerEvent } from 'react';
import { GameButton } from '../../../ui/design-system';
import type {
  MovementDirection,
} from '../hooks/usePlayerControls';
import { InteractionPrompt } from './InteractionPrompt';
import { EchoAvatarHUD, type EchoAvatarEmotion } from './EchoAvatarHUD';

interface GameplayHUDProps {
  prompt: string | null;
  objective: string;
  puzzleProgress: string;
  showTutorial: boolean;
  onDismissTutorial: () => void;
  onInteract: () => void;
  onPause: () => void;
  setTouchDirection: (
    direction: MovementDirection,
    active: boolean,
  ) => void;
  onSprintToggle?: () => void;
  onSprintHold?: (active: boolean) => void;
  onJumpHold?: (active: boolean) => void;
  onAttack?: () => void;
  onPunch?: () => void;
  onKick?: () => void;
  onDodge?: () => void;
  onResonancePulse?: () => void;
  pulseCooldown?: number;
  perfectDodgeSurgeActive?: boolean;
  stunBannerText?: string | null;
  isSprinting?: boolean;
  hasWeapon?: boolean;
  bossActive?: boolean;
  monsterHp?: number;
  maxMonsterHp?: number;
  /** Player vitals for Echo avatar HUD */
  playerHp?: number;
  maxPlayerHp?: number;
  playerStamina?: number;
  maxPlayerStamina?: number;
  /** Combo counter and multiplier */
  comboCount?: number;
  comboMultiplier?: number;
  /** Echo avatar emotion derived from game state */
  echoEmotion?: EchoAvatarEmotion;
  /** Whether the monster is in its enraged phase 2 */
  monsterPhase?: 1 | 2;
  /** Whether the monster is staggered (kinetic counter activated) */
  monsterStaggered?: boolean;
  /** Whether the monster is winding up a lethal ground slam */
  slamWarning?: boolean;
  reducedMotion?: boolean;
}

const DIRECTION_LABELS: Record<MovementDirection, string> = {
  forward: 'تحرك إلى الأمام (W / ▲)',
  backward: 'تحرك إلى الخلف (S / ▼)',
  left: 'تحرك إلى اليسار (A / ◀)',
  right: 'تحرك إلى اليمين (D / ▶)',
};

function directionGlyph(direction: MovementDirection): string {
  switch (direction) {
    case 'forward': return '▲';
    case 'backward': return '▼';
    case 'left': return '◀';
    case 'right': return '▶';
  }
}

export function GameplayHUD({
  prompt,
  objective,
  puzzleProgress,
  showTutorial,
  onDismissTutorial,
  onInteract,
  onPause,
  setTouchDirection,
  onSprintToggle,
  onSprintHold,
  onJumpHold,
  onAttack,
  onPunch,
  onKick,
  onDodge,
  onResonancePulse,
  pulseCooldown = 0,
  perfectDodgeSurgeActive = false,
  stunBannerText = null,
  isSprinting = false,
  hasWeapon = false,
  bossActive = false,
  monsterHp = 1000,
  maxMonsterHp = 1000,
  playerHp = 200,
  maxPlayerHp = 200,
  playerStamina = 100,
  maxPlayerStamina = 100,
  comboCount = 0,
  comboMultiplier = 1,
  echoEmotion = 'calm',
  monsterPhase = 1,
  monsterStaggered = false,
  slamWarning = false,
  reducedMotion = false,
}: GameplayHUDProps) {
  const [glitchActive, setGlitchActive] = useState(false);
  const [glitchIndex, setGlitchIndex] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setGlitchActive(true);
      setGlitchIndex((prev) => (prev + 1) % 2);
      const timeout = setTimeout(() => {
        setGlitchActive(false);
      }, 480);
      return () => clearTimeout(timeout);
    }, 6200);

    return () => clearInterval(interval);
  }, []);

  const bindDirection = (direction: MovementDirection) => ({
    onPointerDown: (event: PointerEvent<HTMLButtonElement>) => {
      event.preventDefault();
      event.currentTarget.setPointerCapture(event.pointerId);
      setTouchDirection(direction, true);
    },
    onPointerUp: (event: PointerEvent<HTMLButtonElement>) => {
      setTouchDirection(direction, false);
      if (event.currentTarget.hasPointerCapture(event.pointerId)) {
        event.currentTarget.releasePointerCapture(event.pointerId);
      }
    },
    onPointerCancel: () => setTouchDirection(direction, false),
    onPointerLeave: () => setTouchDirection(direction, false),
  });

  const headerLabel = glitchActive
    ? 'CONTAINMENT SECTOR 11 // SUBJECT EX-011'
    : 'OPENING ROOM // 11:11';

  const progressLabel = glitchActive
    ? (glitchIndex === 0
      ? '[KINJA OVERRIDE]: SYNAPSE COGNITION RISING'
      : 'PROTOCOL CRITICAL // RECOVER MEMORY')
    : puzzleProgress;

  return (
    <div className="gameplay-hud">
      {/* ─── Echo Player Vitals HUD (bottom-left) ─────────────────── */}
      <div
        style={{
          position: 'absolute',
          bottom: '90px',
          left: '12px',
          zIndex: 35,
          pointerEvents: 'none',
        }}
      >
        <EchoAvatarHUD
          emotion={echoEmotion}
          hp={playerHp}
          maxHp={maxPlayerHp}
          stamina={playerStamina}
          maxStamina={maxPlayerStamina}
          isSprinting={isSprinting}
          perfectDodgeSurgeActive={perfectDodgeSurgeActive}
          reducedMotion={reducedMotion}
        />
      </div>

      {/* ─── Combo Counter (top-right, cinematic) ───────────────────── */}
      {bossActive && comboCount >= 2 && (
        <div
          role="status"
          aria-live="polite"
          aria-label={`كومبو ${comboCount} ضربة`}
          style={{
            position: 'absolute',
            top: '80px',
            right: '18px',
            zIndex: 44,
            pointerEvents: 'none',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'flex-end',
            gap: '2px',
            animation: reducedMotion ? 'none' : 'comboPopIn 0.18s cubic-bezier(0.22,1,0.36,1)',
          }}
        >
          <span style={{
            fontSize: `${Math.min(3.6, 1.6 + comboCount * 0.08)}rem`,
            fontWeight: 900,
            fontFamily: "'Space Grotesk', system-ui, sans-serif",
            letterSpacing: '-0.03em',
            color: comboMultiplier >= 3 ? '#ffaa00' : comboMultiplier >= 2 ? '#55ffcc' : '#e8fbff',
            textShadow: comboMultiplier >= 3
              ? '0 0 18px rgba(255,170,0,0.8), 0 0 40px rgba(255,120,0,0.5)'
              : comboMultiplier >= 2
                ? '0 0 12px rgba(85,255,200,0.7)'
                : '0 0 8px rgba(87,231,255,0.4)',
            lineHeight: 1,
          }}>
            {comboCount}
          </span>
          <span style={{
            fontSize: '0.65rem',
            fontWeight: 700,
            letterSpacing: '0.12em',
            color: comboMultiplier >= 3 ? '#ffaa00' : comboMultiplier >= 2 ? '#55ffcc' : 'rgba(200,245,255,0.65)',
            textTransform: 'uppercase',
          }}>
            {comboMultiplier >= 3 ? '✦ MAX CHAIN ×3' : comboMultiplier >= 2 ? '✦ CHAIN ×2' : 'HIT CHAIN'}
          </span>
        </div>
      )}

      {/* ─── Boss Phase 2 Enrage Banner ────────────────────────────── */}
      {bossActive && monsterPhase === 2 && (
        <div
          role="status"
          aria-live="assertive"
          style={{
            position: 'absolute',
            top: '58px',
            left: '50%',
            transform: 'translateX(-50%)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '5px 14px',
            background: 'rgba(180, 0, 30, 0.2)',
            border: '1.5px solid #ff2244',
            borderRadius: '4px',
            color: '#ff8899',
            fontFamily: "'Space Grotesk', system-ui, sans-serif",
            fontSize: '12px',
            fontWeight: 700,
            letterSpacing: '0.07em',
            backdropFilter: 'blur(8px)',
            boxShadow: '0 0 18px rgba(255, 34, 68, 0.45)',
            zIndex: 42,
            pointerEvents: 'none',
          }}
        >
          <span style={{ color: '#ffffff', background: '#cc0022', padding: '1px 5px', borderRadius: '3px' }}>
            ⚠ PHASE II
          </span>
          <span>EX-000 انتقل إلى المرحلة الثانية // طاقة حيوية حرجة</span>
        </div>
      )}

      {/* ─── Kinetic Counter / Stagger Window Banner ──────────────── */}
      {bossActive && monsterStaggered && (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: 'absolute',
            top: bossActive && monsterPhase === 2 ? '98px' : '58px',
            left: '50%',
            transform: 'translateX(-50%)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '5px 14px',
            background: 'rgba(0, 200, 120, 0.16)',
            border: '1.5px solid #00e87a',
            borderRadius: '4px',
            color: '#6effc4',
            fontFamily: "'Space Grotesk', system-ui, sans-serif",
            fontSize: '12px',
            fontWeight: 700,
            letterSpacing: '0.07em',
            backdropFilter: 'blur(8px)',
            boxShadow: '0 0 16px rgba(0, 232, 122, 0.4)',
            zIndex: 42,
            pointerEvents: 'none',
          }}
        >
          <span style={{ color: '#002a17', background: '#00e87a', padding: '1px 5px', borderRadius: '3px' }}>
            ✦ STAGGER
          </span>
          <span>نافذة عداد الحركية — ضرر مضاعف نشط!</span>
        </div>
      )}

      {/* ─── Ground Slam Danger Telegraph Warning Banner ───────────── */}
      {slamWarning && (
        <div
          role="alert"
          aria-live="assertive"
          style={{
            position: 'absolute',
            top: '128px',
            left: '50%',
            transform: 'translateX(-50%)',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            padding: '8px 18px',
            background: 'rgba(255, 0, 40, 0.35)',
            border: '2px solid #ff0044',
            borderRadius: '6px',
            color: '#fff',
            fontFamily: "'Space Grotesk', system-ui, sans-serif",
            fontSize: '13px',
            fontWeight: 800,
            letterSpacing: '0.08em',
            backdropFilter: 'blur(10px)',
            boxShadow: '0 0 30px rgba(255, 0, 68, 0.75)',
            zIndex: 48,
            pointerEvents: 'none',
            animation: reducedMotion ? 'none' : 'slamWarningPulse 0.3s ease-in-out infinite alternate',
          }}
        >
          <span style={{ color: '#fff', background: '#ff0033', padding: '2px 7px', borderRadius: '3px' }}>
            ⚡ DANGER
          </span>
          <span>ضربة أرضية ساحقة قادمة — تفادَ أو اقفز فوراً! // EVADE SLAM</span>
        </div>
      )}

      {/* Boss Health Bar for SPECIMEN EX-000 */}
      {bossActive && (
        <aside
          className="gameplay-hud__boss-container"
          role="progressbar"
          aria-valuenow={monsterHp}
          aria-valuemin={0}
          aria-valuemax={maxMonsterHp}
          aria-label="SPECIMEN EX-000 // ABERRANT SYNAPSE"
        >
          <div className="gameplay-hud__boss-meta">
            <span className="gameplay-hud__boss-warning">
              {monsterPhase === 2 ? '⚠ مرحلة الهياج الكاملة' : 'CRITICAL CONTAINMENT BREACH'}
            </span>
            <strong className="gameplay-hud__boss-name">SPECIMEN EX-000 // ABERRANT SYNAPSE</strong>
            <span className="gameplay-hud__boss-hp-val">
              {monsterHp} / {maxMonsterHp} HP
            </span>
          </div>
          <div className="gameplay-hud__boss-bar">
            <div
              className="gameplay-hud__boss-fill"
              style={{
                width: `${Math.max(0, Math.min(100, (monsterHp / maxMonsterHp) * 100))}%`,
                background: monsterPhase === 2
                  ? 'linear-gradient(90deg, #ff0044, #ff6600)'
                  : undefined,
                boxShadow: monsterPhase === 2 ? '0 0 10px #ff0044' : undefined,
              }}
            />
          </div>
        </aside>
      )}

      {/* Narrative & Mission Objective Status */}
      <aside
        className={`gameplay-hud__status${glitchActive ? ' gameplay-hud__status--glitch' : ''}`}
        aria-live="polite"
      >
        <small>{headerLabel}</small>
        <strong>{objective}</strong>
        <span>{progressLabel}</span>
      </aside>

      {/* Dynamic Resonance Critical Surge Notice */}
      {perfectDodgeSurgeActive && (
        <div className="gameplay-hud__surge-banner" role="status" style={{
          position: 'absolute',
          top: '82px',
          left: '50%',
          transform: 'translateX(-50%)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 14px',
          background: 'rgba(255, 170, 0, 0.18)',
          border: '1px solid #ffaa00',
          borderRadius: '4px',
          color: '#ffdd66',
          fontFamily: "'Space Grotesk', system-ui, sans-serif",
          fontSize: '13px',
          fontWeight: 700,
          letterSpacing: '0.06em',
          backdropFilter: 'blur(8px)',
          boxShadow: '0 0 16px rgba(255, 170, 0, 0.35)',
          zIndex: 40,
          pointerEvents: 'none',
        }}>
          <span style={{ color: '#ffffff', background: '#ff9900', padding: '1px 5px', borderRadius: '3px' }}>
            ⚡ PERFECT DODGE
          </span>
          <span>طفرة رنين قتالية نشطة // الضربة القادمة 3x</span>
        </div>
      )}

      {/* Sonar Scan Stun Notification */}
      {stunBannerText && (
        <div className="gameplay-hud__stun-banner" role="status" style={{
          position: 'absolute',
          top: perfectDodgeSurgeActive ? '122px' : '82px',
          left: '50%',
          transform: 'translateX(-50%)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 14px',
          background: 'rgba(0, 240, 255, 0.16)',
          border: '1px solid #00f0ff',
          borderRadius: '4px',
          color: '#bbf7fd',
          fontFamily: "'Space Grotesk', system-ui, sans-serif",
          fontSize: '13px',
          fontWeight: 700,
          letterSpacing: '0.06em',
          backdropFilter: 'blur(8px)',
          boxShadow: '0 0 16px rgba(0, 240, 255, 0.35)',
          zIndex: 40,
          pointerEvents: 'none',
        }}>
          <span style={{ color: '#001a24', background: '#00f0ff', padding: '1px 5px', borderRadius: '3px' }}>
            ◎ SONAR STUN
          </span>
          <span>{stunBannerText}</span>
        </div>
      )}

      <button
        type="button"
        className="gameplay-hud__pause"
        onClick={onPause}
        aria-label="إيقاف اللعبة"
      >
        <span aria-hidden="true">Ⅱ</span>
        إيقاف
      </button>

      {onSprintToggle && (
        <button
          type="button"
          className={`gameplay-hud__sprint${isSprinting ? ' is-active' : ''}`}
          onClick={onSprintToggle}
          aria-label="تبديل وضع الركض"
          title="ركض (Shift / زر الفأرة الأيمن)"
        >
          <span aria-hidden="true">⚡</span>
          {isSprinting ? 'ركض سريع (Shift)' : 'مشي عادي (Shift)'}
        </button>
      )}

      <InteractionPrompt
        prompt={prompt}
        onInteract={onInteract}
      />

      {/* Touch Screen Virtual Controls (Cyberpunk Gamepad) */}
      <div
        className="gameplay-touch-controls"
        aria-label="عناصر تحكم اللمس"
      >
        {/* Left Hand: Cyber Virtual D-Pad / Thumbstick */}
        <div className="gameplay-touch-controls__dpad" role="group" aria-label="لوحة الاتجاهات">
          <div className="gameplay-touch-controls__center-hub" aria-hidden="true" />
          {(
            ['forward', 'left', 'right', 'backward'] as const
          ).map((direction) => (
            <button
              key={direction}
              type="button"
              data-direction={direction}
              aria-label={DIRECTION_LABELS[direction]}
              {...bindDirection(direction)}
            >
              {directionGlyph(direction)}
            </button>
          ))}
        </div>

        {/* Right Hand: Action Buttons Cluster */}
        <div className="gameplay-touch-controls__actions" role="group" aria-label="أزرار الحركة">
          {/* Punch Button */}
          {onPunch && (
            <button
              type="button"
              className="gameplay-touch-controls__btn gameplay-touch-controls__btn--punch"
              onClick={(e) => {
                e.preventDefault();
                onPunch();
              }}
              aria-label="لكمة (LMB / J)"
              title="لكمة"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">🥊</span>
              <span className="gameplay-touch-controls__label">لكمة</span>
            </button>
          )}

          {/* Kick Button */}
          {onKick && (
            <button
              type="button"
              className="gameplay-touch-controls__btn gameplay-touch-controls__btn--kick"
              onClick={(e) => {
                e.preventDefault();
                onKick();
              }}
              aria-label="ركلة (RMB / K)"
              title="ركلة"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">🦵</span>
              <span className="gameplay-touch-controls__label">ركلة</span>
            </button>
          )}

          {/* Dodge Button */}
          {onDodge && (
            <button
              type="button"
              className="gameplay-touch-controls__btn gameplay-touch-controls__btn--dodge"
              onClick={(e) => {
                e.preventDefault();
                onDodge();
              }}
              aria-label="تفادي (Space)"
              title="تفادي"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">💨</span>
              <span className="gameplay-touch-controls__label">تفادي</span>
            </button>
          )}

          {/* Companion Resonance Pulse Button */}
          {onResonancePulse && (
            <button
              type="button"
              className={`gameplay-touch-controls__btn gameplay-touch-controls__btn--pulse${pulseCooldown > 0 ? ' is-cooldown' : ''}`}
              onClick={(e) => {
                e.preventDefault();
                if (pulseCooldown <= 0) {
                  onResonancePulse();
                }
              }}
              disabled={pulseCooldown > 0}
              aria-label="نبض رنين المرافق (Q)"
              title="نبض الرنين"
              style={{
                borderColor: pulseCooldown > 0 ? '#4a5568' : '#00f0ff',
                color: pulseCooldown > 0 ? '#718096' : '#00f0ff',
              }}
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">
                {pulseCooldown > 0 ? `${Math.ceil(pulseCooldown)}s` : '◎'}
              </span>
              <span className="gameplay-touch-controls__label">رنين</span>
            </button>
          )}

          {/* Jump Button */}
          {onJumpHold && (
            <button
              type="button"
              className="gameplay-touch-controls__btn gameplay-touch-controls__btn--jump"
              onPointerDown={(e) => {
                e.preventDefault();
                e.currentTarget.setPointerCapture(e.pointerId);
                onJumpHold(true);
              }}
              onPointerUp={(e) => {
                onJumpHold(false);
                if (e.currentTarget.hasPointerCapture(e.pointerId)) {
                  e.currentTarget.releasePointerCapture(e.pointerId);
                }
              }}
              onPointerCancel={() => onJumpHold(false)}
              aria-label="قفز (Space)"
              title="قفز"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">⤊</span>
              <span className="gameplay-touch-controls__label">قفز</span>
            </button>
          )}

          {/* Katana Attack Button */}
          {hasWeapon && onAttack && (
            <button
              type="button"
              className="gameplay-touch-controls__btn gameplay-touch-controls__btn--attack"
              onClick={(e) => {
                e.preventDefault();
                onAttack();
              }}
              aria-label="هجوم بسلاح الكاتانا"
              title="هجوم بالكاتانا"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">⚔</span>
              <span className="gameplay-touch-controls__label">كاتانا</span>
            </button>
          )}

          {/* Sprint Hold Button */}
          {onSprintHold && (
            <button
              type="button"
              className={`gameplay-touch-controls__btn gameplay-touch-controls__btn--sprint${isSprinting ? ' is-active' : ''}`}
              onPointerDown={(e) => {
                e.preventDefault();
                e.currentTarget.setPointerCapture(e.pointerId);
                onSprintHold(true);
              }}
              onPointerUp={(e) => {
                onSprintHold(false);
                if (e.currentTarget.hasPointerCapture(e.pointerId)) {
                  e.currentTarget.releasePointerCapture(e.pointerId);
                }
              }}
              onPointerCancel={() => onSprintHold(false)}
              aria-label="ركض سريع (Shift)"
              title="ركض سريع"
            >
              <span className="gameplay-touch-controls__glyph" aria-hidden="true">⚡</span>
              <span className="gameplay-touch-controls__label">ركض</span>
            </button>
          )}

          {/* Interact / Inspect Button */}
          <button
            type="button"
            className={`gameplay-touch-controls__btn gameplay-touch-controls__btn--interact${prompt ? ' is-ready' : ''}`}
            onClick={onInteract}
            disabled={!prompt}
            aria-label={prompt ? `تفاعل: ${prompt}` : 'فحص'}
            title="تفاعل (E)"
          >
            <span className="gameplay-touch-controls__glyph" aria-hidden="true">⬡</span>
            <span className="gameplay-touch-controls__label">{prompt ? 'تفاعل' : 'فحص'}</span>
          </button>
        </div>
      </div>

      {/* Desktop / Keyboard HUD Keybinding Hints */}
      <div className="gameplay-desktop-hints" aria-hidden="true">
        <div className="gameplay-desktop-hints__item">
          <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd>
          <span>تحرك</span>
        </div>
        {onPunch && (
          <div className="gameplay-desktop-hints__item">
            <kbd>LMB / J</kbd>
            <span>لكم</span>
          </div>
        )}
        {onKick && (
          <div className="gameplay-desktop-hints__item">
            <kbd>RMB / K</kbd>
            <span>ركل</span>
          </div>
        )}
        <div className="gameplay-desktop-hints__item">
          <kbd>Space</kbd>
          <span>{onDodge ? 'تفادي / قفز' : 'قفز'}</span>
        </div>
        {onResonancePulse && (
          <div className="gameplay-desktop-hints__item gameplay-desktop-hints__item--pulse">
            <kbd>Q</kbd>
            <span>{pulseCooldown > 0 ? `${Math.ceil(pulseCooldown)}s` : 'نبض الرنين'}</span>
          </div>
        )}
        <div className="gameplay-desktop-hints__item">
          <kbd>Shift</kbd>
          <span>ركض</span>
        </div>
        <div className="gameplay-desktop-hints__item">
          <kbd>E</kbd>
          <span>تفاعل</span>
        </div>
        {hasWeapon && (
          <div className="gameplay-desktop-hints__item gameplay-desktop-hints__item--weapon">
            <kbd>F</kbd>
            <span>كاتانا</span>
          </div>
        )}
      </div>

      {showTutorial && (
        <section
          className="gameplay-controls-guide"
          role="dialog"
          aria-modal="true"
          aria-labelledby="gameplay-controls-title"
        >
          <small>CONTROL LINK // FIRST ENTRY</small>
          <h2 id="gameplay-controls-title">تحكم بـEcho</h2>
          <p>
            تحرّك بـWASD أو الأسهم، اسحب بالفأرة لتوجيه الكاميرا،
            اضغط Space للقفز والتفادي، Q لنبض رنين المرافق، Shift للجري وE للفحص. يفتح Escape قائمة الإيقاف.
          </p>
          <p className="gameplay-controls-guide__touch">
            على الهاتف استخدم لوحة الاتجاهات الافتراضية وأزرار الحركة (لكم، ركل، تفادي، رنين، ركض، قفز، تفاعل).
          </p>
          <GameButton onClick={onDismissTutorial} autoFocus>
            ابدأ الاستكشاف
          </GameButton>
        </section>
      )}
    </div>
  );
}
