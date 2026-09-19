import {
  useCallback,
  useEffect,
  useRef,
} from 'react';

export type GameplayAudioCue =
  | 'ambient'
  | 'systemHum'
  | 'footstep'
  | 'cloth'
  | 'clock'
  | 'doorLocked'
  | 'doorOpen'
  | 'memoryGlitch'
  | 'slash'
  | 'whoosh'
  | 'punch'
  | 'kick'
  | 'hitImpact'
  | 'glassShatter'
  | 'monsterRoar'
  | 'dodge';

export const GAMEPLAY_AUDIO_ASSETS: Readonly<
  Record<GameplayAudioCue, string | null>
> = Object.freeze({
  ambient: null,
  systemHum: null,
  footstep: null,
  cloth: null,
  clock: null,
  doorLocked: null,
  doorOpen: null,
  memoryGlitch: null,
  slash: null,
  whoosh: null,
  punch: null,
  kick: null,
  hitImpact: null,
  glassShatter: null,
  monsterRoar: null,
  dodge: null,
});

interface PlayCueOptions {
  loop?: boolean;
  volume?: number;
}

// -------------------------------------------------------------
// COGNITIVE PSYCHOLOGY PROCEDURAL AUDIO SYNTHESIZER
// -------------------------------------------------------------
class CognitiveSoundEngine {
  private ctx: AudioContext | null = null;
  private ambientGain: GainNode | null = null;
  private ambientOsc1: OscillatorNode | null = null;
  private ambientOsc2: OscillatorNode | null = null;
  private isMuted = false;

  private getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      void this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  public play(cue: GameplayAudioCue, volume = 0.5): void {
    const ctx = this.getContext();
    if (!ctx || this.isMuted) return;

    const now = ctx.currentTime;

    switch (cue) {
      case 'ambient':
      case 'systemHum': {
        if (this.ambientOsc1) return; // already active
        try {
          // Isochronic 52Hz + 65Hz deep calming sub-harmonic reactor drone
          const gain = ctx.createGain();
          gain.gain.setValueAtTime(0.001, now);
          gain.gain.exponentialRampToValueAtTime(Math.min(0.25, volume * 0.35), now + 3.0);

          const osc1 = ctx.createOscillator();
          osc1.type = 'sine';
          osc1.frequency.setValueAtTime(52.0, now);

          const osc2 = ctx.createOscillator();
          osc2.type = 'sine';
          osc2.frequency.setValueAtTime(65.0, now);

          const filter = ctx.createBiquadFilter();
          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(140, now);

          osc1.connect(filter);
          osc2.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);

          osc1.start(now);
          osc2.start(now);

          this.ambientGain = gain;
          this.ambientOsc1 = osc1;
          this.ambientOsc2 = osc2;
        } catch {
          // graceful fallback
        }
        break;
      }

      case 'footstep': {
        // Tactile wet puddle resonance: crisp acoustic floor tap + soft splash
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          const filter = ctx.createBiquadFilter();

          osc.type = 'sine';
          // Pitch drops rapidly simulating foot heel impact
          osc.frequency.setValueAtTime(110, now);
          osc.frequency.exponentialRampToValueAtTime(38, now + 0.09);

          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(260, now);

          gain.gain.setValueAtTime(volume * 0.45, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.11);

          osc.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);

          osc.start(now);
          osc.stop(now + 0.12);

          // Subtle wet sheen splash sparkle
          const noiseBuffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.06), ctx.sampleRate);
          const data = noiseBuffer.getChannelData(0);
          for (let i = 0; i < data.length; i++) {
            data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (data.length * 0.3));
          }
          const noise = ctx.createBufferSource();
          noise.buffer = noiseBuffer;

          const noiseFilter = ctx.createBiquadFilter();
          noiseFilter.type = 'bandpass';
          noiseFilter.frequency.setValueAtTime(1600, now);
          noiseFilter.Q.setValueAtTime(2.0, now);

          const noiseGain = ctx.createGain();
          noiseGain.gain.setValueAtTime(volume * 0.14, now);
          noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);

          noise.connect(noiseFilter);
          noiseFilter.connect(noiseGain);
          noiseGain.connect(ctx.destination);

          noise.start(now);
        } catch {}
        break;
      }

      case 'doorOpen': {
        // 528Hz Solfeggio Transformation Chord: pure dopamine feedback
        try {
          [528, 660, 792, 1056].forEach((freq, idx) => {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now + idx * 0.08);

            gain.gain.setValueAtTime(0.001, now + idx * 0.08);
            gain.gain.exponentialRampToValueAtTime(volume * 0.22, now + idx * 0.08 + 0.05);
            gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 1.2);

            osc.connect(gain);
            gain.connect(ctx.destination);

            osc.start(now + idx * 0.08);
            osc.stop(now + idx * 0.08 + 1.25);
          });
        } catch {}
        break;
      }

      case 'doorLocked': {
        // Soft low-rejection security buzz
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sawtooth';
          osc.frequency.setValueAtTime(92, now);

          gain.gain.setValueAtTime(volume * 0.25, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.28);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.3);
        } catch {}
        break;
      }

      case 'memoryGlitch': {
        // Cyber synapse awakening shimmer
        try {
          [440, 880, 1320, 1760].forEach((f, i) => {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(f, now + i * 0.04);
            osc.frequency.exponentialRampToValueAtTime(f * 1.5, now + i * 0.04 + 0.35);

            gain.gain.setValueAtTime(volume * 0.16, now + i * 0.04);
            gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.04 + 0.4);

            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now + i * 0.04);
            osc.stop(now + i * 0.04 + 0.45);
          });
        } catch {}
        break;
      }

      case 'whoosh':
      case 'slash': {
        // Aerodynamic katana strike sweep
        try {
          const noiseBuffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.2), ctx.sampleRate);
          const data = noiseBuffer.getChannelData(0);
          for (let i = 0; i < data.length; i++) {
            data[i] = (Math.random() * 2 - 1) * Math.sin((i / data.length) * Math.PI);
          }
          const noise = ctx.createBufferSource();
          noise.buffer = noiseBuffer;

          const filter = ctx.createBiquadFilter();
          filter.type = 'bandpass';
          filter.frequency.setValueAtTime(400, now);
          filter.frequency.exponentialRampToValueAtTime(2400, now + 0.1);
          filter.frequency.exponentialRampToValueAtTime(200, now + 0.2);

          const gain = ctx.createGain();
          gain.gain.setValueAtTime(volume * 0.45, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);

          noise.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);

          noise.start(now);
        } catch {}
        break;
      }

      case 'punch': {
        // Fast aerodynamic punch whoosh + body impact thud
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'triangle';
          osc.frequency.setValueAtTime(140, now);
          osc.frequency.exponentialRampToValueAtTime(45, now + 0.12);

          gain.gain.setValueAtTime(volume * 0.6, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.15);
        } catch {}
        break;
      }

      case 'kick': {
        // Heavy martial arts roundhouse sweep + sub bass kick resonance
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(180, now);
          osc.frequency.exponentialRampToValueAtTime(32, now + 0.22);

          gain.gain.setValueAtTime(volume * 0.75, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.24);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.25);
        } catch {}
        break;
      }

      case 'hitImpact': {
        // Crisp crunchy impact spark sound
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'square';
          osc.frequency.setValueAtTime(260, now);
          osc.frequency.exponentialRampToValueAtTime(60, now + 0.08);

          gain.gain.setValueAtTime(volume * 0.5, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.1);
        } catch {}
        break;
      }

      case 'glassShatter': {
        // High-impact glass fracture and explosive burst
        try {
          const noiseBuffer = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.5), ctx.sampleRate);
          const data = noiseBuffer.getChannelData(0);
          for (let i = 0; i < data.length; i++) {
            data[i] = (Math.random() * 2 - 1) * Math.exp(-i / (data.length * 0.2));
          }
          const noise = ctx.createBufferSource();
          noise.buffer = noiseBuffer;

          const filter = ctx.createBiquadFilter();
          filter.type = 'highpass';
          filter.frequency.setValueAtTime(1200, now);

          const gain = ctx.createGain();
          gain.gain.setValueAtTime(volume * 0.85, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.48);

          noise.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);
          noise.start(now);
        } catch {}
        break;
      }

      case 'monsterRoar': {
        // Guttural subterranean roar with pitch wobble
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sawtooth';
          osc.frequency.setValueAtTime(85, now);
          osc.frequency.linearRampToValueAtTime(110, now + 0.3);
          osc.frequency.exponentialRampToValueAtTime(35, now + 0.9);

          const filter = ctx.createBiquadFilter();
          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(380, now);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.8, now + 0.15);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.95);

          osc.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 1.0);
        } catch {}
        break;
      }

      case 'dodge': {
        // Rapid air displacement swoosh
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(300, now);
          osc.frequency.exponentialRampToValueAtTime(120, now + 0.15);

          gain.gain.setValueAtTime(volume * 0.4, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.16);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.18);
        } catch {}
        break;
      }

      default:
        break;
    }
  }

  public stopAmbient(): void {
    if (this.ambientGain && this.ctx) {
      try {
        this.ambientGain.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + 1.0);
        setTimeout(() => {
          this.ambientOsc1?.stop();
          this.ambientOsc2?.stop();
          this.ambientOsc1 = null;
          this.ambientOsc2 = null;
          this.ambientGain = null;
        }, 1100);
      } catch {}
    }
  }
}

const soundEngine = new CognitiveSoundEngine();

export function useGameplayAudio() {
  const activeAudioRef = useRef(new Set<HTMLAudioElement>());

  const playCue = useCallback((
    cue: GameplayAudioCue,
    options: PlayCueOptions = {},
  ) => {
    const source = GAMEPLAY_AUDIO_ASSETS[cue];
    const volume = Math.min(1, Math.max(0, options.volume ?? 0.55));

    if (source) {
      const audio = new Audio(source);
      audio.loop = options.loop ?? false;
      audio.volume = volume;
      activeAudioRef.current.add(audio);

      const release = () => activeAudioRef.current.delete(audio);
      audio.addEventListener('ended', release, { once: true });
      void audio.play().catch(() => {
        release();
        soundEngine.play(cue, volume);
      });
    } else {
      // Automatic Cognitive Sound Engine Procedural Audio
      soundEngine.play(cue, volume);
    }
  }, []);

  useEffect(() => () => {
    for (const audio of activeAudioRef.current) {
      audio.pause();
      audio.src = '';
    }
    activeAudioRef.current.clear();
    soundEngine.stopAmbient();
  }, []);

  return { playCue };
}
