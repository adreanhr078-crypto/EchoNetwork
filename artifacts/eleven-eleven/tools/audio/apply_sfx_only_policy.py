"""Replace existing musical notification implementations, preserving their APIs.

Only the named function bodies and their adjacent descriptions are rewritten.
This is an idempotent migration; environmental/medical/dialogue SFX stay intact.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
FILE = ROOT / "godot/scripts/audio/procedural_cinematic_audio.gd"
REPLACEMENTS = {
    "create_abyss_drone": ('', 'return create_pressure_air(1.5, 1101)'),
    "create_covenant_chime": ('', 'return create_physical_signal(1.2, [0.04, 0.21, 0.45], 1102)'),
    "create_doorbell_chime": ('', 'return create_physical_signal(0.65, [0.02, 0.2], 1103)'),
    "create_konbini_chime": ('', 'return create_physical_signal(0.55, [0.02, 0.19], 1104)'),
    "create_shrine_crystal_bell": ('', 'return create_physical_signal(0.7, [0.02], 1105)'),
    "create_quest_complete_fanfare": ('', 'return create_physical_signal(0.7, [0.02, 0.17, 0.34], 1106)'),
    "create_chest_open_chime": ('rarity: int = 0', 'return create_physical_signal(0.8, [0.02, 0.15], 1107, 0.30 + 0.025 * clampi(rarity, 0, 3))'),
    "create_loot_toast_chime": ('', 'return create_physical_signal(0.4, [0.015, 0.13], 1108)'),
    "create_school_chime_bell": ('', 'return create_physical_signal(0.8, [0.03, 0.3], 1109)'),
    "create_bond_up_jingle": ('', 'return create_physical_signal(0.65, [0.02, 0.18, 0.32], 1110)'),
}
HELPERS = '''
## Owner audio policy: environmental and physical effects only; no musical score.
const AUDIO_POLICY := "SFX_ONLY"

## Unpitched latch/pressure clicks. Timing changes emphasis; no pitched notes.
static func create_physical_signal(duration: float, onsets: Array, noise_seed: int, amount := 0.35) -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(int(duration * rate))
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var body := 0.0
	for i in samples.size():
		var t := float(i) / rate
		var raw := rng.randf_range(-1.0, 1.0)
		body = lerpf(body, raw, 0.10)
		var envelope := 0.0
		for onset in onsets:
			var local := t - float(onset)
			if local >= 0.0:
				envelope += exp(-local * 24.0) * (1.0 - exp(-local * 900.0))
		samples[i] = (body * 0.8 + raw * 0.2) * minf(envelope, 1.0) * amount
	return generate_wav(samples, rate)

## Broad air pressure, without a sustained pitched drone or musical harmonics.
static func create_pressure_air(duration: float, noise_seed: int) -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(int(duration * rate))
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var air := 0.0
	for i in samples.size():
		var t := float(i) / rate
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.08)
		var envelope := minf(t / 0.04, 1.0) * minf((duration - t) / 0.12, 1.0)
		samples[i] = air * envelope * 0.42
	return generate_wav(samples, rate)

'''

def main():
    text = FILE.read_text(encoding="utf-8")
    for name, (arguments, body) in REPLACEMENTS.items():
        # Do not consume other function descriptions or variable declarations.
        pattern = rf"(?m)^(?:##[^\n]*\n)*static func {name}\([^\n]*\) -> AudioStreamWAV:\n(?:\t[^\n]*\n|\n)*"
        replacement = f"## Non-musical physical cue; legacy method name retained for callers.\nstatic func {name}({arguments}) -> AudioStreamWAV:\n\t{body}\n\n"
        text, count = re.subn(pattern, replacement, text)
        if count != 1:
            raise ValueError(f"Expected one source function {name}, found {count}")
    if 'const AUDIO_POLICY := "SFX_ONLY"' not in text:
        text = text.replace("static func generate_wav(", HELPERS + "static func generate_wav(", 1)
    FILE.write_text(text, encoding="utf-8", newline="\n")
    print({"replaced_notifications": len(REPLACEMENTS), "policy": "SFX_ONLY"})

if __name__ == "__main__":
    main()
