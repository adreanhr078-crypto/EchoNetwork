"""Check actual pact source PCM and frozen output provenance, not religious rulings."""
import hashlib
import json
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/production/pact-audio-20261009"
RUNTIME = ROOT / "godot/assets/audio/pact"

def main():
    manifest = json.loads((SOURCE / "soundscape-manifest.json").read_text())
    failures, rows = [], []
    for record in manifest["tracks"]:
        name = record["name"]
        wav_path = SOURCE / f"{name}.wav"
        ogg_path = RUNTIME / f"{name}.ogg"
        for path, key in ((wav_path, "source_sha256"), (ogg_path, "runtime_sha256")):
            if hashlib.sha256(path.read_bytes()).hexdigest() != record[key]:
                failures.append(f"{name}: {key} mismatch")
        with wave.open(str(wav_path), "rb") as wav:
            rate, channels = wav.getframerate(), wav.getnchannels()
            pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels).astype(float) / 32768
        mono = pcm.mean(axis=1)
        worst = 0.0
        width = min(rate // 2, len(mono))
        for start in range(0, len(mono) - width + 1, width):
            segment = mono[start:start + width]
            spectrum = np.abs(np.fft.rfft((segment - segment.mean()) * np.hanning(width))) ** 2
            spectrum[:10] = 0  # exclude inaudible envelope/DC, not audible low notes
            if spectrum.sum() > 1e-9:
                worst = max(worst, float(spectrum.max() / spectrum.sum()))
        if worst >= .16:
            failures.append(f"{name}: concentrated sustained-tone spectrum {worst:.3f}")
        rows.append({"name": name, "worst_single_spectral_line_fraction": worst, "peak": float(np.abs(pcm).max()), "channels": channels, "sample_rate": rate})
    result = {"status": "FAIL" if failures else "PASS", "failures": failures,
              "scope": "Actual original PCM + generated OGG fingerprints and sustained-tone regression only. Environmental noise/heartbeat/impact source equations contain no tuned notes, chords or instruments; listening quality remains separate.", "tracks": rows}
    (SOURCE / "sfx-only-review.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return bool(failures)

if __name__ == "__main__":
    raise SystemExit(main())
