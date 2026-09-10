import { useEffect, useRef } from 'react';
import { useUiPreferencesStore } from '../../../app/shell/shellStore';

interface OpeningMemoryBeatProps {
  reducedMotion: boolean;
  onComplete: () => void;
}

/** A short memory beat. It grants nothing; the room receipt still does that. */
export function OpeningMemoryBeat({
  reducedMotion,
  onComplete,
}: OpeningMemoryBeatProps) {
  const locale = useUiPreferencesStore(state => state.locale);
  const completeRef = useRef(onComplete);
  completeRef.current = onComplete;
  const completedRef = useRef(false);
  const finish = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    completeRef.current();
  };

  useEffect(() => {
    const timer = window.setTimeout(finish, reducedMotion ? 850 : 9_600);
    return () => window.clearTimeout(timer);
  }, [reducedMotion]);

  return (
    <section
      className={`opening-memory-beat ${reducedMotion ? 'is-reduced' : ''}`}
      role="dialog"
      aria-modal="true"
      aria-labelledby="opening-memory-beat-title"
    >
      <div className="opening-memory-beat__signal" aria-hidden="true">
        <span />
        <i />
        <b />
      </div>
      <small>{locale === 'ar' ? 'أثر من الذاكرة · 11:11' : 'Memory trace · 11:11'}</small>
      <h2 id="opening-memory-beat-title">{locale === 'ar' ? 'تعود الملامح قبل الاسم.' : 'A shape returns before a name.'}</h2>
      <p>{locale === 'ar' ? 'لا يفهم إيكو ما رآه بعد. لكن الغرفة تركت أثرًا.' : 'Echo cannot explain it yet. The room leaves a trace behind.'}</p>
      <button type="button" onClick={finish}>{locale === 'ar' ? 'متابعة' : 'Continue'}</button>
    </section>
  );
}
