"""Original non-musical pact effects: air, heartbeats and physical impacts.

Offline rendering keeps synthesis out of the interactive cinematic frame budget.
Run from the active app; runtime uses the compressed OGG derivatives.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/production/pact-audio-20261009"
RUNTIME = ROOT / "godot/assets/audio/pact"
RATE = 48000
TAU = 2 * np.pi


def time(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def soften(x, seconds=0.025):
    n = min(round(seconds * RATE), len(x) // 2)
    if n:
        ramp = np.sin(np.linspace(0, np.pi / 2, n)) ** 2
        if x.ndim == 2:
            ramp = ramp[:, None]
        x[:n] *= ramp
        x[-n:] *= ramp[::-1]
    return x


def filtered_noise(t, seed, smoothing=48):
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, 1, len(t))
    kernel = np.hanning(smoothing)
    kernel /= kernel.sum()
    return np.convolve(noise, kernel, mode="same")


def impact(t, seed, decay, amplitude, smoothing=96):
    # A short broadband pressure transient, never a tuned drum/note oscillator.
    noise = filtered_noise(t, seed, smoothing)
    noise /= max(float(np.abs(noise).max()), 1e-6)
    return amplitude * noise * np.exp(-t * decay) * (1 - np.exp(-t * 900))


def stereo(dry, t, width=0.035):
    # Restrained unpitched air width; body impacts remain mono-compatible.
    air = width * filtered_noise(t, 601, 20)
    return np.stack((dry + air, dry - air), axis=1)


def loop_bed(revenge=False):
    t = time(16)
    swell = 0.65 + 0.25 * np.sin(TAU * t / 16)
    dry = filtered_noise(t, 77 if revenge else 76, 160) * 0.25 * swell
    # Heartbeat pairs have breathing space rather than an unbroken alarm.
    spacing = 1.0 if revenge else 2.0
    for onset in np.arange(0.2, 15, spacing):
        for offset, amount in ((0, 0.13), (0.17, 0.07)):
            local = t - onset - offset
            mask = (local >= 0) & (local < 0.36)
            dry[mask] += impact(local[mask], 120 + round(onset * 10) + round(offset * 100), 19, amount * 2)
    return soften(stereo(dry, t, 0.006), 0.055)


def acceptance():
    t = time(3.6)
    dry = np.zeros_like(t)
    # Vacuum intake, pressure seal and small settling cracks; no chord or melody.
    noise = filtered_noise(t, 1111, 80)
    dry += noise * 0.6 * np.exp(-((t - 0.38) / 0.2) ** 2)
    local = np.maximum(0, t - 0.55)
    gate = t >= 0.55
    dry += gate * impact(local, 1130, 6, 0.42, 160)
    for onset, seed in ((0.59, 1141), (0.78, 1142), (1.17, 1143)):
        local = np.maximum(0, t - onset)
        dry += (t >= onset) * impact(local, seed, 24, 0.14, 12)
    return soften(stereo(dry, t, 0.009), 0.045)


def contact(number):
    t = time(0.9)
    noise = filtered_noise(t, 1200 + number, 12)
    dry = impact(t, 1210 + number, 15, 0.42, 100 - number * 12)
    dry += noise * 0.24 * np.exp(-t * 38)
    # Small room reflections are baked and bounded; no global audio-bus changes.
    delay = round(0.071 * RATE)
    dry[delay:] += 0.16 * dry[:-delay].copy()
    return soften(stereo(dry, t, 0.0015), 0.004)


def stillness():
    t = time(1.8)
    dry = filtered_noise(t, 1301, 80) * 0.3 * np.exp(-t * 3.7)
    return soften(stereo(dry, t, 0.002), 0.015)


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    tracks = {"void_bed": loop_bed(), "revenge_bed": loop_bed(True),
              "contract_seal": acceptance(), "stasis_release": stillness()}
    tracks.update({f"contact_{n}": contact(n) for n in (1, 2, 3)})
    report = {"sample_rate": RATE, "channels": 2,
              "origin": "original offline environmental and physical effects; no voices or sampled performances",
              "audio_policy": "SFX_ONLY: no music, instruments, melody, arpeggio, chord or sustained pitched drone. Heartbeat/air/impact rhythms only.", "tracks": []}
    for name, samples in tracks.items():
        samples -= samples.mean(axis=0)
        samples = soften(samples, 0.003)
        peak = float(np.abs(samples).max())
        assert np.isfinite(samples).all() and 0.01 < peak < 0.65
        pcm = np.rint(samples * 32767).astype("<i2")
        wav = SOURCE / f"{name}.wav"
        with wave.open(str(wav), "wb") as stream:
            stream.setnchannels(2); stream.setsampwidth(2); stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        ogg = RUNTIME / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
        report["tracks"].append({"name": name, "seconds": len(samples) / RATE, "peak": peak,
                                 "rms": float(np.sqrt(np.mean(samples ** 2))),
                                 "max_pcm_step": int(np.max(np.abs(np.diff(pcm.astype(np.int32), axis=0)))),
                                 "source_sha256": hashlib.sha256(wav.read_bytes()).hexdigest(),
                                 "runtime_sha256": hashlib.sha256(ogg.read_bytes()).hexdigest(), "runtime_bytes": ogg.stat().st_size})
    report["listening_acceptance"] = "OPEN: objective headroom and continuity do not establish listening quality"
    (SOURCE / "soundscape-manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"tracks": len(tracks), "runtime_bytes": sum(x["runtime_bytes"] for x in report["tracks"])}))


if __name__ == "__main__":
    main()
