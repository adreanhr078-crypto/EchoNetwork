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
  resetInput: () => void;
}

interface UsePlayerControlsOptions {
  enabled: boolean;
  pauseEnabled?: boolean;
  onInteract: () => void;
  onPause: () => void;
}

const INITIAL_CONTROLS: PlayerControlsSnapshot = {
  forward: false,
  backward: false,
  left: false,
  right: false,
  sprint: false,
  jump: false,
};

const KEY_DIRECTIONS: Partial<Record<string, MovementDirection>> = {
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
    || code === 'Escape';
}

export function usePlayerControls({
  enabled,
  pauseEnabled = enabled,
  onInteract,
  onPause,
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
      if (isGameplayKey(event.code)) event.preventDefault();

      const direction = KEY_DIRECTIONS[event.code];
      if (direction) {
        inputRef.current[direction] = true;
        return;
      }
      if (event.code === 'ShiftLeft' || event.code === 'ShiftRight') {
        inputRef.current.sprint = true;
        return;
      }
      if (event.code === 'Space') {
        inputRef.current.jump = true;
        return;
      }
      if (event.code === 'KeyE' && !event.repeat) {
        onInteract();
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

    const handleVisibilityChange = () => {
      if (document.hidden) resetInput();
    };

    window.addEventListener('keydown', handleKeyDown, { passive: false });
    window.addEventListener('keyup', handleKeyUp);
    window.addEventListener('blur', resetInput);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('keyup', handleKeyUp);
      window.removeEventListener('blur', resetInput);
      document.removeEventListener(
        'visibilitychange',
        handleVisibilityChange,
      );
    };
  }, [enabled, onInteract, onPause, pauseEnabled, resetInput]);

  return {
    inputRef,
    setTouchDirection,
    resetInput,
  };
}
