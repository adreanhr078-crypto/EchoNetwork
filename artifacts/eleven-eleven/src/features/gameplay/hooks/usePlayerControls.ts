import {
  useCallback,
  useEffect,
  useRef,
  type MutableRefObject,
} from 'react';

export type MovementDirection =
  | 'forward'
  | 'backward'
  | 'left'
  | 'right';

export interface PlayerControlsSnapshot {
  forward: boolean;
  backward: boolean;
  left: boolean;
  right: boolean;
  sprint: boolean;
  jump: boolean;
}

export interface PlayerControlsApi {
  inputRef: MutableRefObject<PlayerControlsSnapshot>;
  setTouchDirection: (
    direction: MovementDirection,
    active: boolean,
  ) => void;
  setSprint: (active: boolean) => void;
  toggleSprint: () => void;
  setJump: (active: boolean) => void;
  triggerPunch: () => void;
  triggerKick: () => void;
  triggerDodge: () => void;
  triggerResonancePulse: () => void;
  resetInput: () => void;
}

interface UsePlayerControlsOptions {
  enabled: boolean;
  pauseEnabled?: boolean;
  onInteract: () => void;
  onPause: () => void;
  onAttack?: () => void;
  onPunch?: () => void;
  onKick?: () => void;
  onDodge?: () => void;
  onResonancePulse?: () => void;
}

const INITIAL_CONTROLS: PlayerControlsSnapshot = {
  forward: false,
  backward: false,
  left: false,
  right: false,
  sprint: false,
  jump: false,
};

const KEY_DIRECTIONS: Partial<Record<MovementDirection | string, MovementDirection>> = {
  KeyW: 'forward',
  ArrowUp: 'forward',
  KeyS: 'backward',
  ArrowDown: 'backward',
  KeyA: 'left',
  ArrowLeft: 'left',
  KeyD: 'right',
  ArrowRight: 'right',
};

function isGameplayKey(code: string): boolean {
  return code in KEY_DIRECTIONS
    || code === 'ShiftLeft'
    || code === 'ShiftRight'
    || code === 'Space'
    || code === 'KeyE'
    || code === 'KeyF'
    || code === 'KeyQ'
    || code === 'Escape';
}

export function usePlayerControls({
  enabled,
  pauseEnabled = enabled,
  onInteract,
  onPause,
  onAttack,
  onPunch,
  onKick,
  onDodge,
  onResonancePulse,
}: UsePlayerControlsOptions): PlayerControlsApi {
  const inputRef = useRef<PlayerControlsSnapshot>({
    ...INITIAL_CONTROLS,
  });

  const resetInput = useCallback(() => {
    inputRef.current = { ...INITIAL_CONTROLS };
  }, []);

  const setTouchDirection = useCallback((
    direction: MovementDirection,
    active: boolean,
  ) => {
    inputRef.current[direction] = enabled && active;
  }, [enabled]);

  const setSprint = useCallback((active: boolean) => {
    inputRef.current.sprint = enabled && active;
  }, [enabled]);

  const toggleSprint = useCallback(() => {
    if (enabled) {
      inputRef.current.sprint = !inputRef.current.sprint;
    }
  }, [enabled]);

  const setJump = useCallback((active: boolean) => {
    inputRef.current.jump = enabled && active;
  }, [enabled]);

  const triggerPunch = useCallback(() => {
    if (!enabled) return;
    if (onPunch) onPunch();
    else onAttack?.();
  }, [enabled, onAttack, onPunch]);

  const triggerKick = useCallback(() => {
    if (!enabled) return;
    if (onKick) onKick();
    else onAttack?.();
  }, [enabled, onAttack, onKick]);

  const triggerDodge = useCallback(() => {
    if (!enabled) return;
    if (onDodge) onDodge();
  }, [enabled, onDodge]);

  const triggerResonancePulse = useCallback(() => {
    if (!enabled) return;
    onResonancePulse?.();
  }, [enabled, onResonancePulse]);

  useEffect(() => {
    if (!enabled) resetInput();
  }, [enabled, resetInput]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.code === 'Escape' && pauseEnabled && !event.repeat) {
        event.preventDefault();
        resetInput();
        onPause();
        return;
      }
      if (!enabled) return;

      const direction = KEY_DIRECTIONS[event.code];
      if (direction) {
        inputRef.current[direction] = true;
        return;
      }
      if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') {
        inputRef.current.sprint = true;
        return;
      }
      if (event.code === 'Space' && !event.repeat) {
        inputRef.current.jump = true;
        triggerDodge();
        return;
      }
      if (event.code === 'KeyE' && !event.repeat) {
        onInteract();
        return;
      }
      if (event.code === 'KeyQ' && !event.repeat) {
        triggerResonancePulse();
        return;
      }
      if ((event.code === 'KeyF' || event.code === 'KeyJ' || event.code === 'KeyZ') && !event.repeat) {
        triggerPunch();
        return;
      }
      if ((event.code === 'KeyK' || event.code === 'KeyX') && !event.repeat) {
        triggerKick();
        return;
      }
    };

    const handleKeyUp = (event: KeyboardEvent) => {
      const direction = KEY_DIRECTIONS[event.code];
      if (direction) inputRef.current[direction] = false;
      if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') {
        inputRef.current.sprint = false;
      }
      if (event.code === 'Space') {
        inputRef.current.jump = false;
      }
    };

    const handleMouseDown = (event: MouseEvent) => {
      if (!enabled) return;
      // If clicking inside canvas/gameplay, allow combat clicks
      const target = event.target as HTMLElement | null;
      const isUiButton = target?.closest('button, input, select, a, [role="button"]');
      if (isUiButton) return;

      if (event.button === 0) {
        // Left click = Punch Combo
        triggerPunch();
      } else if (event.button === 2) {
        // Right click = Heavy Kick
        event.preventDefault();
        triggerKick();
      }
    };

    const handleContextMenu = (event: MouseEvent) => {
      if (enabled) event.preventDefault();
    };

    const handleVisibilityChange = () => {
      if (document.hidden) resetInput();
    };

    window.addEventListener('keydown', handleKeyDown, { passive: false });
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('mousedown', handleMouseDown);
    window.addEventListener('contextmenu', handleContextMenu);
    window.addEventListener('blur', resetInput);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      window.removeEventListener('mousedown', handleMouseDown);
      window.removeEventListener('contextmenu', handleContextMenu);
      window.removeEventListener('blur', resetInput);
      document.removeEventListener(
        'visibilitychange',
        handleVisibilityChange,
      );
    };
  }, [enabled, onAttack, onDodge, onInteract, onKick, onPause, onPunch, pauseEnabled, resetInput, triggerDodge, triggerKick, triggerPunch, triggerResonancePulse]);

  return {
    inputRef,
    setTouchDirection,
    setSprint,
    toggleSprint,
    setJump,
    triggerPunch,
    triggerKick,
    triggerDodge,
    triggerResonancePulse,
    resetInput,
  };
}
