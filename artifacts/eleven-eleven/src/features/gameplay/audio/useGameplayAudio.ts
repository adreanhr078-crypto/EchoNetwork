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
  | 'capsuleRelease'
  | 'memoryGlitch'
  | 'slash'
  | 'whoosh'
  | 'punch'
  | 'kick'
  | 'hitImpact'
  | 'glassShatter'
  | 'monsterRoar'
  | 'dodge'
  | 'resonanceBurst'
  | 'sonarPulse'
  | 'circuitClick'
  | 'circuitSpark'
  | 'powerSurge'
  | 'thoughtWhisper'
  | 'bossEnrage'
  | 'groundSlam'
  | 'shockwavePass'
  | 'watcherAlert'
  | 'airlockVent';

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
  capsuleRelease: null,
  memoryGlitch: null,
  slash: null,
  whoosh: null,
  punch: null,
  kick: null,
  hitImpact: null,
  glassShatter: null,
  monsterRoar: null,
  dodge: null,
  resonanceBurst: null,
  sonarPulse: null,
  circuitClick: null,
  circuitSpark: null,
  powerSurge: null,
  thoughtWhisper: null,
  bossEnrage: null,
  groundSlam: null,
  shockwavePass: null,
  watcherAlert: null,
  airlockVent: null,
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

      case 'capsuleRelease': {
        // Pneumatic seal break: cold-gas hiss over a short hydraulic motor fall.
        try {
          const noiseBuffer = ctx.createBuffer(
            1,
            Math.floor(ctx.sampleRate * 1.45),
            ctx.sampleRate,
          );
          const noiseData = noiseBuffer.getChannelData(0);
          for (let index = 0; index < noiseData.length; index += 1) {
            const life = index / noiseData.length;
            noiseData[index] = (Math.random() * 2 - 1)
              * Math.sin(Math.min(1, life * 16) * Math.PI * 0.5)
              * Math.pow(1 - life, 1.65);
          }
          const hiss = ctx.createBufferSource();
          const hissFilter = ctx.createBiquadFilter();
          const hissGain = ctx.createGain();
          hiss.buffer = noiseBuffer;
          hissFilter.type = 'bandpass';
          hissFilter.frequency.setValueAtTime(1450, now);
          hissFilter.frequency.exponentialRampToValueAtTime(310, now + 1.35);
          hissFilter.Q.setValueAtTime(0.7, now);
          hissGain.gain.setValueAtTime(0.001, now);
          hissGain.gain.linearRampToValueAtTime(volume * 0.38, now + 0.045);
          hissGain.gain.exponentialRampToValueAtTime(0.001, now + 1.42);
          hiss.connect(hissFilter);
          hissFilter.connect(hissGain);
          hissGain.connect(ctx.destination);
          hiss.start(now);

          const motor = ctx.createOscillator();
          const motorFilter = ctx.createBiquadFilter();
          const motorGain = ctx.createGain();
          motor.type = 'sawtooth';
          motor.frequency.setValueAtTime(92, now);
          motor.frequency.exponentialRampToValueAtTime(34, now + 1.1);
          motorFilter.type = 'lowpass';
          motorFilter.frequency.setValueAtTime(190, now);
          motorGain.gain.setValueAtTime(0.001, now);
          motorGain.gain.linearRampToValueAtTime(volume * 0.22, now + 0.08);
          motorGain.gain.exponentialRampToValueAtTime(0.001, now + 1.18);
          motor.connect(motorFilter);
          motorFilter.connect(motorGain);
          motorGain.connect(ctx.destination);
          motor.start(now);
          motor.stop(now + 1.2);
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

      case 'resonanceBurst': {
        // 432Hz crystal harmonic counter chime + sub-bass punch
        try {
          const sub = ctx.createOscillator();
          const subGain = ctx.createGain();
          sub.type = 'sine';
          sub.frequency.setValueAtTime(120, now);
          sub.frequency.exponentialRampToValueAtTime(36, now + 0.45);
          subGain.gain.setValueAtTime(volume * 0.6, now);
          subGain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);
          sub.connect(subGain);
          subGain.connect(ctx.destination);
          sub.start(now);
          sub.stop(now + 0.52);

          [432, 864, 1296].forEach((freq, i) => {
            const chime = ctx.createOscillator();
            const chimeGain = ctx.createGain();
            chime.type = 'triangle';
            chime.frequency.setValueAtTime(freq, now + i * 0.04);
            chimeGain.gain.setValueAtTime(0.001, now + i * 0.04);
            chimeGain.gain.exponentialRampToValueAtTime(volume * 0.28, now + i * 0.04 + 0.03);
            chimeGain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.04 + 0.65);
            chime.connect(chimeGain);
            chimeGain.connect(ctx.destination);
            chime.start(now + i * 0.04);
            chime.stop(now + i * 0.04 + 0.7);
          });
        } catch {}
        break;
      }

      case 'sonarPulse': {
        // High-tech companion radar sonar chirp (1200Hz -> 2800Hz)
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(1200, now);
          osc.frequency.exponentialRampToValueAtTime(2800, now + 0.22);
          osc.frequency.exponentialRampToValueAtTime(600, now + 0.55);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.45, now + 0.04);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.58);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.6);
        } catch {}
        break;
      }

      case 'circuitClick': {
        // Crisp tactile mechanical breaker switch click
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'triangle';
          osc.frequency.setValueAtTime(1800, now);
          osc.frequency.exponentialRampToValueAtTime(450, now + 0.025);

          gain.gain.setValueAtTime(volume * 0.55, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.035);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.04);
        } catch {}
        break;
      }

      case 'circuitSpark': {
        // High-frequency electrical discharge sizzle
        try {
          const osc1 = ctx.createOscillator();
          const osc2 = ctx.createOscillator();
          const gain = ctx.createGain();
          osc1.type = 'sawtooth';
          osc2.type = 'square';
          osc1.frequency.setValueAtTime(2800, now);
          osc1.frequency.linearRampToValueAtTime(3600, now + 0.08);
          osc2.frequency.setValueAtTime(1900, now);
          osc2.frequency.linearRampToValueAtTime(4200, now + 0.08);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.42, now + 0.02);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.12);

          osc1.connect(gain);
          osc2.connect(gain);
          gain.connect(ctx.destination);
          osc1.start(now);
          osc2.start(now);
          osc1.stop(now + 0.13);
          osc2.stop(now + 0.13);
        } catch {}
        break;
      }

      case 'powerSurge': {
        // Deep resonant auxiliary power restoration swell
        try {
          const sub = ctx.createOscillator();
          const subGain = ctx.createGain();
          sub.type = 'sine';
          sub.frequency.setValueAtTime(48, now);
          sub.frequency.exponentialRampToValueAtTime(96, now + 0.8);
          subGain.gain.setValueAtTime(0.001, now);
          subGain.gain.linearRampToValueAtTime(volume * 0.7, now + 0.2);
          subGain.gain.exponentialRampToValueAtTime(0.001, now + 1.6);
          sub.connect(subGain);
          subGain.connect(ctx.destination);
          sub.start(now);
          sub.stop(now + 1.7);

          [144, 288, 576, 864].forEach((freq, i) => {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(freq * 0.85, now + i * 0.06);
            osc.frequency.exponentialRampToValueAtTime(freq, now + i * 0.06 + 0.6);
            gain.gain.setValueAtTime(0.001, now + i * 0.06);
            gain.gain.linearRampToValueAtTime(volume * 0.25, now + i * 0.06 + 0.15);
            gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.06 + 1.4);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(now + i * 0.06);
            osc.stop(now + i * 0.06 + 1.5);
          });
        } catch {}
        break;
      }

      case 'thoughtWhisper': {
        // 528Hz Solfeggio frequency + delicate cognitive shimmer
        try {
          const osc = ctx.createOscillator();
          const oscHarmonic = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(528, now);
          oscHarmonic.type = 'sine';
          oscHarmonic.frequency.setValueAtTime(1056, now);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.35, now + 0.12);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 1.3);

          osc.connect(gain);
          oscHarmonic.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          oscHarmonic.start(now);
          osc.stop(now + 1.4);
          oscHarmonic.stop(now + 1.4);
        } catch {}
        break;
      }

      case 'bossEnrage': {
        // Terrifying sub-bass roar with distortion and chaotic harmonic screech
        try {
          const osc1 = ctx.createOscillator();
          const osc2 = ctx.createOscillator();
          const gain = ctx.createGain();
          const filter = ctx.createBiquadFilter();

          osc1.type = 'sawtooth';
          osc1.frequency.setValueAtTime(65, now);
          osc1.frequency.exponentialRampToValueAtTime(38, now + 1.8);

          osc2.type = 'triangle';
          osc2.frequency.setValueAtTime(140, now);
          osc2.frequency.exponentialRampToValueAtTime(75, now + 1.8);

          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(550, now);
          filter.frequency.linearRampToValueAtTime(180, now + 1.8);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.95, now + 0.1);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 2.0);

          osc1.connect(filter);
          osc2.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);

          osc1.start(now);
          osc2.start(now);
          osc1.stop(now + 2.1);
          osc2.stop(now + 2.1);
        } catch {}
        break;
      }

      case 'groundSlam': {
        // Heavy crushing seismic ground impact with sub-bass compression
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(120, now);
          osc.frequency.exponentialRampToValueAtTime(28, now + 0.6);

          gain.gain.setValueAtTime(volume * 1.0, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.85);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.9);
        } catch {}
        break;
      }

      case 'shockwavePass': {
        // Whooshing high-speed kinetic air distortion
        try {
          const bufferSize = ctx.sampleRate * 0.5;
          const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
          const data = buffer.getChannelData(0);
          for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * 0.4;
          }
          const noise = ctx.createBufferSource();
          noise.buffer = buffer;

          const filter = ctx.createBiquadFilter();
          filter.type = 'bandpass';
          filter.frequency.setValueAtTime(320, now);
          filter.frequency.exponentialRampToValueAtTime(1200, now + 0.25);
          filter.frequency.exponentialRampToValueAtTime(220, now + 0.5);

          const gain = ctx.createGain();
          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(volume * 0.7, now + 0.15);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5);

          noise.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);
          noise.start(now);
        } catch {}
        break;
      }

      case 'watcherAlert': {
        // High-tension mechanical click and urgent two-tone surveillance siren
        try {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'square';
          osc.frequency.setValueAtTime(880, now);
          osc.frequency.setValueAtTime(1320, now + 0.12);
          osc.frequency.setValueAtTime(880, now + 0.24);
          osc.frequency.setValueAtTime(1320, now + 0.36);

          gain.gain.setValueAtTime(volume * 0.5, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);

          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.65);
        } catch {}
        break;
      }

      case 'airlockVent': {
        // High-pressure pneumatic steam release hiss
        try {
          const bufferSize = ctx.sampleRate * 1.5;
          const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
          const data = buffer.getChannelData(0);
          for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * 0.35;
          }
          const noise = ctx.createBufferSource();
          noise.buffer = buffer;

          const filter = ctx.createBiquadFilter();
          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(1800, now);
          filter.frequency.exponentialRampToValueAtTime(450, now + 1.4);

          const gain = ctx.createGain();
          gain.gain.setValueAtTime(volume * 0.65, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 1.5);

          noise.connect(filter);
          filter.connect(gain);
          gain.connect(ctx.destination);
          noise.start(now);
        } catch {}
        break;
      }

      default:
        break;
    }
  }

  private masterFilter: BiquadFilterNode | null = null;
  private ostMode: 'ambient' | 'tension' | 'combat' | 'victory' = 'ambient';
  private ostTimer: ReturnType<typeof setInterval> | null = null;
  private ostStep = 0;

  private getMasterOutput(): AudioNode {
    const ctx = this.getContext();
    if (!ctx) throw new Error('AudioContext unavailable');
    if (!this.masterFilter) {
      this.masterFilter = ctx.createBiquadFilter();
      this.masterFilter.type = 'lowpass';
      this.masterFilter.frequency.setValueAtTime(20000, ctx.currentTime);
      this.masterFilter.Q.setValueAtTime(0.7, ctx.currentTime);
      this.masterFilter.connect(ctx.destination);
    }
    return this.masterFilter;
  }

  public setBulletTime(active: boolean): void {
    const ctx = this.getContext();
    if (!ctx) return;
    try {
      const output = this.getMasterOutput();
      if (this.masterFilter) {
        const now = ctx.currentTime;
        if (active) {
          this.masterFilter.frequency.cancelScheduledValues(now);
          this.masterFilter.frequency.exponentialRampToValueAtTime(360, now + 0.08);
          this.masterFilter.Q.cancelScheduledValues(now);
          this.masterFilter.Q.linearRampToValueAtTime(5.5, now + 0.08);
        } else {
          this.masterFilter.frequency.cancelScheduledValues(now);
          this.masterFilter.frequency.exponentialRampToValueAtTime(20000, now + 0.18);
          this.masterFilter.Q.cancelScheduledValues(now);
          this.masterFilter.Q.linearRampToValueAtTime(0.7, now + 0.18);
        }
      }
    } catch {}
  }

  public setAdaptiveOST(mode: 'ambient' | 'tension' | 'combat' | 'victory'): void {
    if (this.ostMode === mode && this.ostTimer) return;
    this.ostMode = mode;
    const ctx = this.getContext();
    if (!ctx) return;

    if (this.ostTimer) {
      clearInterval(this.ostTimer);
      this.ostTimer = null;
    }

    if (mode === 'victory') {
      try {
        const now = ctx.currentTime;
        [220, 277.18, 329.63, 415.3, 554.37].forEach((freq, i) => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'triangle';
          osc.frequency.setValueAtTime(freq, now);
          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(0.18, now + 0.4 + i * 0.08);
          gain.gain.exponentialRampToValueAtTime(0.0001, now + 3.8);
          osc.connect(gain);
          gain.connect(this.getMasterOutput());
          osc.start(now);
          osc.stop(now + 4.0);
        });
      } catch {}
      return;
    }

    if (mode === 'ambient') {
      return; // Standard ambient drone already handles this
    }

    // Sequenced rhythm loop for 'tension' and 'combat'
    const stepInterval = mode === 'combat' ? 220 : 440; // 136 BPM eighth notes in combat
    this.ostStep = 0;

    this.ostTimer = setInterval(() => {
      try {
        const now = ctx.currentTime;
        const step = this.ostStep % 16;
        this.ostStep = (this.ostStep + 1) % 16;

        if (this.ostMode === 'combat') {
          // Cyber kick drum on beats 0, 4, 8, 12
          if (step % 4 === 0) {
            const kick = ctx.createOscillator();
            const kickGain = ctx.createGain();
            kick.type = 'sine';
            kick.frequency.setValueAtTime(120, now);
            kick.frequency.exponentialRampToValueAtTime(38, now + 0.12);
            kickGain.gain.setValueAtTime(0.35, now);
            kickGain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
            kick.connect(kickGain);
            kickGain.connect(this.getMasterOutput());
            kick.start(now);
            kick.stop(now + 0.2);
          }

          // Driving syncopated cyber bass on steps 0, 3, 6, 8, 11, 14
          if ([0, 3, 6, 8, 11, 14].includes(step)) {
            const bass = ctx.createOscillator();
            const bassGain = ctx.createGain();
            bass.type = 'sawtooth';
            const bassFreq = step === 6 || step === 14 ? 65.4 : step === 8 ? 58.27 : 55.0; // A / C / A#
            bass.frequency.setValueAtTime(bassFreq, now);
            bassGain.gain.setValueAtTime(0.18, now);
            bassGain.gain.exponentialRampToValueAtTime(0.001, now + 0.19);
            bass.connect(bassGain);
            bassGain.connect(this.getMasterOutput());
            bass.start(now);
            bass.stop(now + 0.2);
          }

          // Electronic hi-hat on off-beats
          if (step % 2 === 1) {
            const hat = ctx.createOscillator();
            const hatGain = ctx.createGain();
            hat.type = 'square';
            hat.frequency.setValueAtTime(3200, now);
            hatGain.gain.setValueAtTime(0.04, now);
            hatGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.04);
            hat.connect(hatGain);
            hatGain.connect(this.getMasterOutput());
            hat.start(now);
            hat.stop(now + 0.05);
          }
        } else if (this.ostMode === 'tension') {
          // Low tension pulse heartbeat on steps 0 and 8
          if (step === 0 || step === 8) {
            const pulse = ctx.createOscillator();
            const pulseGain = ctx.createGain();
            pulse.type = 'sine';
            pulse.frequency.setValueAtTime(52, now);
            pulse.frequency.exponentialRampToValueAtTime(38, now + 0.25);
            pulseGain.gain.setValueAtTime(0.18, now);
            pulseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
            pulse.connect(pulseGain);
            pulseGain.connect(this.getMasterOutput());
            pulse.start(now);
            pulse.stop(now + 0.36);
          }
        }
      } catch {}
    }, stepInterval);
  }

  public stopAmbient(): void {
    if (this.ostTimer) {
      clearInterval(this.ostTimer);
      this.ostTimer = null;
    }
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

  const setBulletTimeAudio = useCallback((active: boolean) => {
    soundEngine.setBulletTime(active);
  }, []);

  const setAdaptiveMusic = useCallback((mode: 'ambient' | 'tension' | 'combat' | 'victory') => {
    soundEngine.setAdaptiveOST(mode);
  }, []);

  useEffect(() => () => {
    for (const audio of activeAudioRef.current) {
      audio.pause();
      audio.src = '';
    }
    activeAudioRef.current.clear();
    soundEngine.stopAmbient();
  }, []);

  return { playCue, setBulletTimeAudio, setAdaptiveMusic };
}
