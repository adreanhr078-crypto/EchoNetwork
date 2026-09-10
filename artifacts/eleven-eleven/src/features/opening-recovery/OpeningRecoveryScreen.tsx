import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';
import { ArrowLeft, ArrowRight, RotateCcw, ShieldCheck, Sparkles } from 'lucide-react';
import { useShellStore, useUiPreferencesStore } from '../../app/shell/shellStore';
import { usePlayerProgressionStore } from '../player-progression/playerProgressionStore';
import { useGameStore } from '../../stores/gameStore';
import { completeOpeningRecovery, PlayerProgressionApiError } from '../../infrastructure/player-progression/playerProgressionApi';
import { OPENING_COVER_PUZZLE_ID } from '../../domain/opening/openingProgress';
import { GameButton, GlassPanel } from '../../ui/design-system';
import { ScreenBreakRuntime } from './ScreenBreakRuntime';
import './opening-recovery.css';

const COVER_IMAGE = '/manhwa/echo-network-final-2026-09-v1/page-001.webp';

const INTERACTION_COPY = {
  ar: {
    instruction: 'اسحب القطعة إلى موضعها، أو اختر قطعتين لتبديلهما. لا يوجد مؤقت أو عقوبة.',
    dragging: 'حرّك القطعة إلى موضعها الصحيح…',
    solved: 'اكتملت الصورة. جارٍ فتح الذاكرة…',
  },
  en: {
    instruction: 'Drag a piece into place, or select two pieces to swap. No timer, no penalty.',
    dragging: 'Move the piece into its correct position…',
    solved: 'Image aligned. Opening the memory…',
  },
} as const;

interface OpeningDragPreview {
  x: number;
  y: number;
  offsetX: number;
  offsetY: number;
  width: number;
  height: number;
  backgroundImage: string;
  backgroundSize: string;
  backgroundPosition: string;
}

const COPY = {
  ar: {
    eyebrow: 'بوابة الاستعادة // أثر 01',
    title: 'رتّب اللحظة الأولى',
    detail: 'الغلاف ليس صفحة للقراءة بعد. إنه ذاكرة متكسّرة؛ أعد بناء الصورة حتى تستجيب القناة.',
    instruction: 'اختر قطعتين لتبديل موضعهما. لا يوجد مؤقت ولا عقوبة.',
    mobile: 'وضع الهاتف · 12 قطعة',
    desktop: 'وضع الشاشة · 16 قطعة',
    selected: 'قطعة محددة',
    undo: 'تراجع عن الحركة',
    reset: 'إعادة الخلط',
    verify: 'تحقق من الإشارة',
    verifying: 'جارٍ تثبيت الإشارة…',
    receipt: 'استُعيدت الذاكرة',
    receiptDetail: 'انفتحت القناة. جارٍ الانتقال إلى إيكو…',
    retry: 'حاول مرة أخرى',
    error: 'تعذر تثبيت الحل على الخادم. ترتيبك محفوظ هنا؛ أعد المحاولة عندما يعود الاتصال.',
    alt: 'غلاف 11:11: Echo Network، يظهر أثناء إعادة تركيبه.',
    route: 'القناة الأولى',
  },
  en: {
    eyebrow: 'RECOVERY GATEWAY // TRACE 01',
    title: 'Reconstruct the first moment',
    detail: 'The cover is not a page to read yet. It is a broken memory; restore the image until the channel answers.',
    instruction: 'Select two pieces to swap. There is no timer and no penalty.',
    mobile: 'PHONE MODE · 12 PIECES',
    desktop: 'DESKTOP MODE · 16 PIECES',
    selected: 'Selected piece',
    undo: 'Undo last move',
    reset: 'Shuffle again',
    verify: 'Verify the signal',
    verifying: 'Anchoring the signal…',
    receipt: 'Memory restored',
    receiptDetail: 'The channel is open. Returning to Echo…',
    retry: 'Try again',
    error: 'The solution could not be anchored on the server. Your arrangement is kept here; retry when the connection returns.',
    alt: '11:11: Echo Network cover, shown while it is being reconstructed.',
    route: 'FIRST CHANNEL',
  },
} as const;

function shuffledOrder(pieceCount: number): number[] {
  // Deterministic shuffle keeps refreshes calm and makes automated evidence
  // reproducible. The server still owns the final receipt.
  const order = Array.from({ length: pieceCount }, (_, index) => index);
  for (let index = pieceCount - 1; index > 0; index -= 1) {
    const swapIndex = (index * 7 + 3) % (index + 1);
    [order[index], order[swapIndex]] = [order[swapIndex]!, order[index]!];
  }
  if (order.every((piece, index) => piece === index)) {
    [order[0], order[1]] = [order[1]!, order[0]!];
  }
  return order;
}

function dimensionsFor(pieceCount: number): { rows: number; columns: number } {
  return pieceCount === 12
    ? { rows: 4, columns: 3 }
    : { rows: 4, columns: 4 };
}

export default function OpeningRecoveryScreen() {
  const locale = useUiPreferencesStore((state) => state.locale);
  const motion = useUiPreferencesStore((state) => state.motion);
  const copy = COPY[locale];
  const interactionCopy = INTERACTION_COPY[locale];
  const navigate = useShellStore((state) => state.navigate);
  const entitlements = useShellStore((state) => state.experienceEntitlements);
  const storyState = usePlayerProgressionStore((state) => state.storyState);
  const hydrateStoryState = usePlayerProgressionStore(
    (state) => state.actions.hydrateStoryState,
  );
  const syncAuthoritativeStoryState = useGameStore(
    (state) => state.actions.syncAuthoritativeStoryState,
  );
  const [pieceCount, setPieceCount] = useState(16);
  const [order, setOrder] = useState(() => shuffledOrder(16));
  const [past, setPast] = useState<number[][]>([]);
  const [selectedSlot, setSelectedSlot] = useState<number | null>(null);
  const [draggingSlot, setDraggingSlot] = useState<number | null>(null);
  const [dragOverSlot, setDragOverSlot] = useState<number | null>(null);
  const [dragPreview, setDragPreview] = useState<OpeningDragPreview | null>(null);
  const [status, setStatus] = useState<'idle' | 'verifying' | 'receipt' | 'error' | 'break'>('idle');
  const [hasSubmitted, setHasSubmitted] = useState(false);
  const [failureKind, setFailureKind] = useState<'connection' | 'alignment' | 'session'>('connection');
  const [transitionFinished, setTransitionFinished] = useState(false);
  const draggingSlotRef = useRef<number | null>(null);
  const dragOverSlotRef = useRef<number | null>(null);
  const dragMovedRef = useRef(false);
  const submissionPendingRef = useRef(false);

  const dimensions = useMemo(() => dimensionsFor(pieceCount), [pieceCount]);
  const solved = order.every((piece, index) => piece === index);
  const puzzleInteractive = status === 'idle' || status === 'error';
  const verifyDisabled = status === 'verifying'
    || status === 'receipt'
    || status === 'break'
    || (past.length === 0 && !solved);

  useEffect(() => {
    const media = window.matchMedia('(max-width: 700px)');
    const update = () => {
      const nextCount = media.matches ? 12 : 16;
      setPieceCount(nextCount);
      setOrder((current) => current.length === nextCount
        ? current
        : shuffledOrder(nextCount));
      setPast([]);
      setSelectedSlot(null);
      setDraggingSlot(null);
      setDragOverSlot(null);
      setDragPreview(null);
      draggingSlotRef.current = null;
      dragOverSlotRef.current = null;
      dragMovedRef.current = false;
    };
    update();
    // Keep this attempt's pieces stable when rotating or resizing the screen.
  }, []);

  useEffect(() => {
    if (
      status === 'idle'
      && storyState?.openingCoverPuzzleCompleted === true
      && storyState.openingRoomCompleted === false
    ) {
      setTransitionFinished(true);
      setStatus('receipt');
      return;
    }
    if (
      status === 'receipt'
      && transitionFinished
      && storyState?.openingCoverPuzzleCompleted === true
      && entitlements.accessibleScreens.includes('play')
    ) {
      navigate('play');
    }
  }, [entitlements.accessibleScreens, navigate, status, storyState, transitionFinished]);

  const swapPieceSlots = useCallback((fromSlot: number, toSlot: number) => {
    if ((status !== 'idle' && status !== 'error') || fromSlot === toSlot) return;
    setPast((history) => [...history.slice(-24), order]);
    setOrder((current) => {
      const next = [...current];
      [next[fromSlot], next[toSlot]] = [next[toSlot]!, next[fromSlot]!];
      return next;
    });
    setSelectedSlot(null);
  }, [order, status]);

  const selectOrSwapSlot = useCallback((slot: number) => {
    if (status !== 'idle' && status !== 'error') return;
    if (selectedSlot === null) {
      setSelectedSlot(slot);
      return;
    }
    if (selectedSlot === slot) {
      setSelectedSlot(null);
      return;
    }
    swapPieceSlots(selectedSlot, slot);
  }, [selectedSlot, status, swapPieceSlots]);

  const pieceAtPoint = useCallback((clientX: number, clientY: number) => {
    const element = document.elementFromPoint(clientX, clientY);
    const piece = element?.closest<HTMLElement>('[data-opening-piece-slot]');
    const value = piece?.dataset.openingPieceSlot;
    if (value === undefined) return null;
    const slot = Number(value);
    return Number.isInteger(slot) && slot >= 0 && slot < order.length ? slot : null;
  }, [order.length]);

  const handleDragMove = useCallback((event: PointerEvent) => {
    const fromSlot = draggingSlotRef.current;
    if (fromSlot === null) return;
    event.preventDefault();
    setDragPreview((current) => current
      ? { ...current, x: event.clientX, y: event.clientY }
      : current);
    const targetSlot = pieceAtPoint(event.clientX, event.clientY);
    if (targetSlot === null) return;
    if (targetSlot !== fromSlot) dragMovedRef.current = true;
    dragOverSlotRef.current = targetSlot;
    setDragOverSlot(targetSlot);
  }, [pieceAtPoint]);

  const finishDrag = useCallback(() => {
    const fromSlot = draggingSlotRef.current;
    const toSlot = dragOverSlotRef.current;
    if (fromSlot !== null) {
      if (dragMovedRef.current && toSlot !== null && toSlot !== fromSlot) {
        swapPieceSlots(fromSlot, toSlot);
      } else if (!dragMovedRef.current) {
        // A pointer tap remains a first-class accessible interaction: it selects
        // one piece, while a second tap swaps it with the next piece.
        selectOrSwapSlot(fromSlot);
      }
    }
    draggingSlotRef.current = null;
    dragOverSlotRef.current = null;
    dragMovedRef.current = false;
    setDraggingSlot(null);
    setDragOverSlot(null);
    setDragPreview(null);
  }, [selectOrSwapSlot, swapPieceSlots]);

  useEffect(() => {
    if (draggingSlot === null) return undefined;
    document.addEventListener('pointermove', handleDragMove, { passive: false });
    document.addEventListener('pointerup', finishDrag);
    document.addEventListener('pointercancel', finishDrag);
    return () => {
      document.removeEventListener('pointermove', handleDragMove);
      document.removeEventListener('pointerup', finishDrag);
      document.removeEventListener('pointercancel', finishDrag);
    };
  }, [draggingSlot, finishDrag, handleDragMove]);

  const handlePiecePointerDown = useCallback((event: ReactPointerEvent<HTMLButtonElement>, slot: number) => {
    if (status !== 'idle' && status !== 'error') return;
    event.preventDefault();
    draggingSlotRef.current = slot;
    dragOverSlotRef.current = slot;
    dragMovedRef.current = false;
    setDraggingSlot(slot);
    setDragOverSlot(slot);
    const rect = event.currentTarget.getBoundingClientRect();
    setDragPreview({
      x: event.clientX,
      y: event.clientY,
      offsetX: event.clientX - rect.left,
      offsetY: event.clientY - rect.top,
      width: rect.width,
      height: rect.height,
      backgroundImage: event.currentTarget.style.backgroundImage,
      backgroundSize: event.currentTarget.style.backgroundSize,
      backgroundPosition: event.currentTarget.style.backgroundPosition,
    });
  }, [status]);

  const undo = useCallback(() => {
    const previous = past.at(-1);
    if (!previous || (status !== 'idle' && status !== 'error')) return;
    setOrder(previous);
    setPast((history) => history.slice(0, -1));
    setSelectedSlot(null);
  }, [past, status]);

  const reset = useCallback(() => {
    if (status === 'verifying' || status === 'receipt' || status === 'break') return;
    setOrder(shuffledOrder(pieceCount));
    setPast([]);
    setSelectedSlot(null);
    setStatus('idle');
  }, [pieceCount, status]);

  const verify = useCallback(async () => {
    if (submissionPendingRef.current) return;
    if (status === 'verifying' || status === 'receipt' || status === 'break' || hasSubmitted) return;
    submissionPendingRef.current = true;
    setStatus('verifying');
    try {
      const response = await completeOpeningRecovery(order);
      if (response.storyState.openingCoverPuzzleCompleted !== true) {
        throw new Error('Opening recovery was not confirmed');
      }
      hydrateStoryState(response.storyState);
      syncAuthoritativeStoryState(response.storyState);
      setHasSubmitted(true);
      setStatus('break');
    } catch (error) {
      setFailureKind(error instanceof PlayerProgressionApiError && error.code === 'opening_solution_not_verified'
        ? 'alignment'
        : error instanceof PlayerProgressionApiError && (error.status === 401 || error.status === 403)
          ? 'session'
          : 'connection');
      setStatus('error');
    } finally {
      submissionPendingRef.current = false;
    }
  }, [hasSubmitted, hydrateStoryState, order, status, syncAuthoritativeStoryState]);

  useEffect(() => {
    // Alignment triggers a request, never a client-owned completion receipt.
    // Failures remain retryable without an automatic request loop.
    if (solved && status === 'idle' && !storyState?.openingCoverPuzzleCompleted) {
      void verify();
    }
  }, [solved, status, storyState?.openingCoverPuzzleCompleted, verify]);

  return (
    <main
      className="opening-recovery"
      dir={locale === 'ar' ? 'rtl' : 'ltr'}
      data-motion={motion}
      data-puzzle-id={OPENING_COVER_PUZZLE_ID}
      data-status={status}
    >
      {status === 'break' && (
        <ScreenBreakRuntime
          reducedMotion={motion === 'reduced'}
            onComplete={() => {
              // The transfer cinematic already ends with Echo's arrival.
              // Avoid replaying a second introduction on the 3D route.
              useGameStore.getState().actions.setNarrativeFlag(
                'opening_room_cinematic_seen',
                true,
              );
              setTransitionFinished(true);
              setStatus('receipt');
            }}
        />
      )}
      <div className="opening-recovery__backdrop" aria-hidden="true">
        <span />
        <i />
        <b />
      </div>
      {dragPreview && (
        <div
          className="opening-recovery__drag-ghost"
          aria-hidden="true"
          style={{
            left: dragPreview.x - dragPreview.offsetX,
            top: dragPreview.y - dragPreview.offsetY,
            width: dragPreview.width,
            height: dragPreview.height,
            backgroundImage: dragPreview.backgroundImage,
            backgroundSize: dragPreview.backgroundSize,
            backgroundPosition: dragPreview.backgroundPosition,
          }}
        />
      )}
      <section className="opening-recovery__layout" inert={status === 'break'}>
        <header className="opening-recovery__header">
          <div>
            <span className="opening-recovery__eyebrow"><Sparkles aria-hidden="true" /> {copy.eyebrow}</span>
            <h1>{copy.title}</h1>
            <p>{copy.detail}</p>
          </div>
          <div className="opening-recovery__route" aria-label={copy.route}>
            <ShieldCheck aria-hidden="true" />
            <span>{copy.route}</span>
            <strong>01</strong>
          </div>
        </header>

        <div className="opening-recovery__workspace">
          <GlassPanel className="opening-recovery__panel" tone="memory">
            <div className="opening-recovery__panel-head">
              <span>{pieceCount === 12 ? copy.mobile : copy.desktop}</span>
              <small>{interactionCopy.instruction}</small>
            </div>
            <div
              className="opening-recovery__board"
              dir="ltr"
              data-piece-count={pieceCount}
              data-solved={solved}
              data-dragging={draggingSlot !== null}
              aria-label={copy.alt}
              style={{ '--board-columns': dimensions.columns } as React.CSSProperties}
            >
              {order.map((piece, slot) => {
                const row = Math.floor(piece / dimensions.columns);
                const column = piece % dimensions.columns;
                const isSelected = selectedSlot === slot;
                return (
                  <button
                    key={`slot-${slot}`}
                    type="button"
                    className="opening-recovery__piece"
                    data-selected={isSelected || undefined}
                    data-opening-piece-slot={slot}
                    data-dragging={draggingSlot === slot || undefined}
                    data-drag-over={dragOverSlot === slot && draggingSlot !== null || undefined}
                    aria-label={`${copy.selected}: ${slot + 1}`}
                    aria-pressed={isSelected}
                    aria-grabbed={draggingSlot === slot}
                    onPointerDown={(event) => handlePiecePointerDown(event, slot)}
                    onClick={(event) => {
                      // Pointer interactions are committed on pointerup so a
                      // drag never receives a second click-triggered swap.
                      if (event.detail > 0) return;
                      selectOrSwapSlot(slot);
                    }}
                    style={{
                      backgroundImage: `url("${COVER_IMAGE}")`,
                      backgroundSize: `${dimensions.columns * 100}% ${dimensions.rows * 100}%`,
                      backgroundPosition: dimensions.columns === 1
                        ? '0% 0%'
                        : `${(column / (dimensions.columns - 1)) * 100}% ${(row / (dimensions.rows - 1)) * 100}%`,
                    }}
                  />
                );
              })}
            </div>
            <div className="opening-recovery__controls">
              <GameButton
                variant="ghost"
                leadingIcon={<RotateCcw aria-hidden="true" />}
                onClick={undo}
                disabled={past.length === 0 || !puzzleInteractive}
              >
                {copy.undo}
              </GameButton>
              <GameButton
                variant="secondary"
                leadingIcon={locale === 'ar'
                  ? <ArrowLeft aria-hidden="true" />
                  : <ArrowRight aria-hidden="true" />}
                onClick={reset}
                disabled={status === 'verifying' || status === 'receipt'}
              >
                {copy.reset}
              </GameButton>
            </div>
          </GlassPanel>

          <aside className="opening-recovery__side">
            <div className="opening-recovery__preview" aria-hidden="true">
              <img src={COVER_IMAGE} alt="" />
              <span />
              <small>MEMORY REFERENCE // 11:11</small>
            </div>
            <p className="opening-recovery__status" aria-live="polite">
              {solved
                ? interactionCopy.solved
                : draggingSlot !== null
                  ? interactionCopy.dragging
                  : selectedSlot === null
                    ? interactionCopy.instruction
                    : `${copy.selected}: ${selectedSlot + 1}`}
            </p>
            {status === 'error' && (
              <p className="opening-recovery__error" role="alert">
                {failureKind === 'alignment'
                  ? locale === 'ar' ? 'الصورة لم تتطابق بعد. راجع اتصال القطع ثم أعد المحاولة.' : 'The image is not aligned yet. Check the adjoining pieces and retry.'
                  : failureKind === 'session'
                    ? locale === 'ar' ? 'تعذر التحقق من جلسة الدخول. استعد اتصال حسابك ثم أعد المحاولة.' : 'Your session could not be verified. Restore your account connection and retry.'
                    : copy.error}
              </p>
            )}
            {status === 'receipt' || status === 'break' ? (
              <div className="opening-recovery__receipt" role="status">
                <ShieldCheck aria-hidden="true" />
                <strong>{copy.receipt}</strong>
                <span>{copy.receiptDetail}</span>
              </div>
            ) : (
              <GameButton
                size="lg"
                fullWidth
                onClick={verify}
                disabled={verifyDisabled}
              >
                {status === 'verifying' ? copy.verifying : status === 'error' ? copy.retry : copy.verify}
              </GameButton>
            )}
          </aside>
        </div>
      </section>
    </main>
  );
}
