import { useEffect, useState, type PointerEvent } from 'react';
import { GameButton } from '../../../ui/design-system';
import type {
  MovementDirection,
} from '../hooks/usePlayerControls';
import { InteractionPrompt } from './InteractionPrompt';

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
  isSprinting?: boolean;
  hasWeapon?: boolean;
  bossActive?: boolean;
  monsterHp?: number;
  maxMonsterHp?: number;
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
  isSprinting = false,
  hasWeapon = false,
  bossActive = false,
  monsterHp = 1000,
  maxMonsterHp = 1000,
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
            <span className="gameplay-hud__boss-warning">CRITICAL CONTAINMENT BREACH</span>
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
              }}
            />
          </div>
        </aside>
      )}

      <aside
        className={`gameplay-hud__status${glitchActive ? ' gameplay-hud__status--glitch' : ''}`}
        aria-live="polite"
      >
        <small>{headerLabel}</small>
        <strong>{objective}</strong>
        <span>{progressLabel}</span>
      </aside>

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
        {onPunch && <div className="gameplay-desktop-hints__item">
          <kbd>LMB / J</kbd>
          <span>لكم</span>
        </div>}
        {onKick && <div className="gameplay-desktop-hints__item">
          <kbd>RMB / K</kbd>
          <span>ركل</span>
        </div>}
        <div className="gameplay-desktop-hints__item">
          <kbd>Space</kbd>
          <span>{onDodge ? 'تفادي / قفز' : 'قفز'}</span>
        </div>
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
            اضغط Space للقفز، Shift للجري وE للفحص. يفتح Escape قائمة الإيقاف.
          </p>
          <p className="gameplay-controls-guide__touch">
            على الهاتف استخدم لوحة الاتجاهات الافتراضية وأزرار الحركة (ركض، قفز، تفاعل، هجوم).
          </p>
          <GameButton onClick={onDismissTutorial} autoFocus>
            ابدأ الاستكشاف
          </GameButton>
        </section>
      )}
    </div>
  );
}
