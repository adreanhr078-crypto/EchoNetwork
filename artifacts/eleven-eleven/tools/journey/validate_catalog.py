"""Guard the authored Echo-to-hospital sequence against premature story reveals."""
import json
from pathlib import Path


def validate(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    beats = data["beats"]
    assert data["voice_language"] == "ja"
    assert set(data["subtitle_languages"]) == {"ar", "en"}
    assert len({beat["id"] for beat in beats}) == len(beats)
    assert len({beat["quest"] for beat in beats}) == len(beats)
    assert sum(beat["minutes"] for beat in beats) == 108
    assert beats[0]["phase_before"] == "human"
    assert beats[-1]["id"] == "hospital_awakening"
    assert beats[-1]["phase_after"] == "hospital"
    assert "EX-011" in beats[-1]["reveal"]
    phase = "human"
    zero_revealed = False
    for beat in beats:
        assert beat["minutes"] > 0
        assert beat["phase_before"] == phase, f"broken phase before {beat['id']}"
        assert beat["scene_mode"] == "godot_interactive", f"non-interactive main beat {beat['id']}"
        assert beat["save_point"], f"no recovery checkpoint at {beat['id']}"
        if beat["full_zero_visible"]:
            assert phase in ("breakdown", "contract"), f"premature Zero at {beat['id']}"
            zero_revealed = True
        if beat["zero_ability"]:
            assert zero_revealed and phase == "contract", f"premature ability at {beat['id']}"
        phase = beat["phase_after"]
    assert phase == "hospital"
    return {"beats": len(beats), "planned_minutes": sum(beat["minutes"] for beat in beats),
            "zero_first_full_reveal": next(beat["id"] for beat in beats if beat["full_zero_visible"]),
            "hospital_reveal": beats[-1]["reveal"]}


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    path = root / "art/production/echo-to-hospital-v2/JourneyCatalog.json"
    print("JOURNEY_CATALOG_VALID " + json.dumps(validate(path), ensure_ascii=False))
