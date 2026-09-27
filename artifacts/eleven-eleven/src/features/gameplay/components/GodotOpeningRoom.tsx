import { useCallback, useEffect, useRef, useState } from 'react';
import type { AuthoritativeStoryState } from '../../../domain/story/storyState';
import { OPENING_ROOM_EVENT_SEQUENCE, OPENING_ROOM_ID, type OpeningRoomEventId } from '../../../domain/opening/openingProgress';
import { advanceOpeningRoomTrace } from '../../../domain/opening/openingHandoff';
import { completeOpeningRoom, fetchAuthoritativeStoryState } from '../../../infrastructure/player-progression/playerProgressionApi';

interface Props {
  locale: 'ar' | 'en';
  muted: boolean;
  reducedMotion: boolean;
  onFallback: () => void;
  onRoomComplete: (storyState: AuthoritativeStoryState, awarded: boolean) => void;
}

interface BuildManifest {
  bridgeVersion: 1;
  sceneContract: 'opening-room-v1';
  playable: true;
  pckBytes: number;
  wasmBytes: number;
}

type Status = 'checking' | 'loading' | 'playing' | 'submitting' | 'error';
const BUILD_ROOT = '/godot/opening/';

function isBuildManifest(value: unknown): value is BuildManifest {
  if (typeof value !== 'object' || value === null) return false;
  const manifest = value as Partial<BuildManifest>;
  return manifest.bridgeVersion === 1
    && manifest.sceneContract === 'opening-room-v1'
    && manifest.playable === true
    && typeof manifest.pckBytes === 'number' && manifest.pckBytes > 0
    && typeof manifest.wasmBytes === 'number' && manifest.wasmBytes > 0;
}

export function GodotOpeningRoom({ locale, muted, reducedMotion, onFallback, onRoomComplete }: Props) {
  const [status, setStatus] = useState<Status>('checking');
  const [attempt, setAttempt] = useState(0);
  const frameRef = useRef<HTMLIFrameElement>(null);
  const nonceRef = useRef(crypto.randomUUID());
  const traceRef = useRef<readonly OpeningRoomEventId[]>([]);
  const pendingRef = useRef(false);
  const completedRef = useRef(false);

  const finishFromServer = useCallback(async () => {
    if (pendingRef.current || completedRef.current) return;
    pendingRef.current = true;
    setStatus('submitting');
    try {
      const response = await completeOpeningRoom(OPENING_ROOM_EVENT_SEQUENCE);
      if (response.storyState.openingRoomCompleted !== true
        || response.receipt.roomId !== OPENING_ROOM_ID
        || !response.receipt.receiptId) throw new Error('Unconfirmed opening room receipt');
      completedRef.current = true;
      setStatus('playing');
      onRoomComplete(response.storyState, response.receipt.awarded === true);
    } catch {
      // A lost response cannot justify a second reward request. Read the server.
      try {
        const confirmed = await fetchAuthoritativeStoryState();
        if (confirmed.openingRoomCompleted === true) {
          completedRef.current = true;
          setStatus('playing');
          onRoomComplete(confirmed, false);
          return;
        }
      } catch {
        // Keep the played room visible so the owner can retry verification.
      }
      setStatus('error');
    } finally {
      pendingRef.current = false;
    }
  }, [onRoomComplete]);

  useEffect(() => {
    let active = true;
    const fallback = () => { if (active) onFallback(); };
    if (!document.createElement('canvas').getContext('webgl2')) {
      fallback();
      return () => { active = false; };
    }
    void fetchAuthoritativeStoryState()
      .then((storyState) => {
        if (storyState.openingCoverPuzzleCompleted !== true) throw new Error('Cover receipt required');
        return fetch(`${BUILD_ROOT}manifest.json`, { cache: 'no-store' });
      })
      .then(async (response) => response.ok ? response.json() as Promise<unknown> : null)
      .then((value) => {
        if (!active) return;
        if (!isBuildManifest(value)) { fallback(); return; }
        setStatus('loading');
      })
      .catch(fallback);
    return () => { active = false; };
  }, [onFallback]);

  useEffect(() => {
    if (status !== 'loading') return undefined;
    const timeout = window.setTimeout(() => setStatus('error'), 60000);
    return () => window.clearTimeout(timeout);
  }, [status, attempt]);

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      if (event.source !== frameRef.current?.contentWindow || event.origin !== window.location.origin) return;
      if (typeof event.data !== 'string') return;
      let data: Record<string, unknown>;
      try { data = JSON.parse(event.data) as Record<string, unknown>; } catch { return; }
      if (typeof data !== 'object' || data === null || Array.isArray(data)) return;
      if (data.source !== '11-11-godot' || data.bridgeVersion !== 1) return;
      if (data.type === 'ready') {
        frameRef.current?.contentWindow?.postMessage(JSON.stringify({
          source: '11-11-web', bridgeVersion: 1, type: 'configure',
          nonce: nonceRef.current, coverVerified: true, muted, reducedMotion,
        }), window.location.origin);
        return;
      }
      if (data.nonce !== nonceRef.current) return;
      if (data.type === 'configured') {
        if (Array.isArray(data.milestones)) for (const milestone of data.milestones) {
          const next = advanceOpeningRoomTrace(traceRef.current, milestone);
          if (next === null) { setStatus('error'); return; }
          traceRef.current = next;
        }
        setStatus('playing');
      } else if (data.type === 'milestone' && typeof data.milestoneId === 'string') {
        const next = advanceOpeningRoomTrace(traceRef.current, data.milestoneId);
        if (next === null) { setStatus('error'); return; }
        traceRef.current = next;
      }
      if (traceRef.current.length === OPENING_ROOM_EVENT_SEQUENCE.length) {
        void finishFromServer();
      }
    };
    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [finishFromServer, muted, reducedMotion]);

  const retry = () => {
    if (traceRef.current.length === OPENING_ROOM_EVENT_SEQUENCE.length) {
      void finishFromServer();
      return;
    }
    nonceRef.current = crypto.randomUUID();
    traceRef.current = [];
    setAttempt((current) => current + 1);
    setStatus('loading');
  };

  return (
    <section className="godot-opening-room" dir={locale === 'ar' ? 'rtl' : 'ltr'}>
      {status !== 'checking' && (
        <iframe
          key={attempt}
          ref={frameRef}
          className="godot-opening-room__frame"
          title={locale === 'ar' ? 'غرفة Echo الافتتاحية' : 'Echo opening room'}
          src={`${BUILD_ROOT}index.html`}
          allow="autoplay; fullscreen; gamepad"
          onError={() => setStatus('error')}
        />
      )}
      {(status === 'checking' || status === 'loading' || status === 'submitting' || status === 'error') && (
        <div className="godot-opening-room__status" role={status === 'error' ? 'alert' : 'status'}>
          <p>{status === 'error'
            ? locale === 'ar' ? 'تعذر فتح الغرفة أو حفظ تقدمها.' : 'The room could not load or save progress.'
            : status === 'submitting'
              ? locale === 'ar' ? 'جارٍ تثبيت أثر الغرفة…' : 'Verifying the room…'
              : locale === 'ar' ? 'جارٍ فتح غرفة Echo…' : 'Opening Echo’s room…'}</p>
          {status === 'error' && <button type="button" onClick={retry}>{locale === 'ar' ? 'إعادة المحاولة' : 'Retry'}</button>}
          {status === 'error' && <button type="button" onClick={onFallback}>{locale === 'ar' ? 'المتابعة في الغرفة البديلة' : 'Continue in alternate room'}</button>}
        </div>
      )}
    </section>
  );
}
