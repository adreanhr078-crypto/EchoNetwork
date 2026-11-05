"""Build a Japanese scratch timing preview from the verified animatic cache."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import wave

APP = Path(__file__).resolve().parents[2]
PACKET = APP / "art/production/signature-slice-20261104"
CASE = PACKET / "performance-20261105"
FPS = 24
RATE = 48000
HOLD_FRAMES = 137
FFMPEG = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]


def digest(path):
    with path.open("rb") as media:
        return hashlib.file_digest(media, "sha256").hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def probe(path):
    raw = subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)])
    return json.loads(raw)


def pcm(path, gain_db):
    encoded = subprocess.check_output(FFMPEG + [
        "-i", str(path), "-af", f"volume={gain_db}dB", "-ar", str(RATE), "-ac", "1", "-f", "s16le", "-",
    ])
    samples = array("h")
    samples.frombytes(encoded)
    return samples


def run(with_laugh=False):
    original = PACKET / "signature-editorial-v1.mp4"
    echo = CASE / "echo-ja-directed.mp3"
    zero = CASE / "zero-ja-directed.mp3"
    editorial = read_json(PACKET / "editorial-export.json")
    takes = {take["file"]: take for take in read_json(CASE / "voice-ledger.json")["takes"]}
    assert digest(original) == editorial["sha256"]
    assert all(digest(p) == takes[p.name]["sha256"] for p in (echo, zero))
    cache = APP / ".tmp/signature-animatic" / editorial["source_key"]
    shots = read_json(PACKET / "editorial-timeline.json")["shots"]
    segments = [cache / (shot["id"] + ".mp4") for shot in shots]
    original_frames = 1944
    holds = {"SH03": HOLD_FRAMES}
    if with_laugh:
        holds["SH19"] = 34
    shot_start_frames = {}
    elapsed_frames = 0
    for shot in shots:
        shot_id = shot["id"]
        shot_start_frames[shot_id] = elapsed_frames
        elapsed_frames += round((shot["duration_seconds"] or 4) * FPS) + holds.get(shot_id, 0)
    total_frames = original_frames + sum(holds.values())
    assert elapsed_frames == total_frames
    duration = total_frames / FPS
    gate = shot_start_frames["SH13"] / FPS
    suffix = "-with-laugh" if with_laugh else ""
    result = CASE / f"japanese-timing-preview{suffix}.mp4"
    pending = result.with_suffix(".pending.mp4")

    echo_audio = pcm(echo, 4)
    zero_audio = pcm(zero, 2)
    # The measured Zero take has a natural silence from 1.623 to 2.383 seconds.
    placements = [("echo", 8.5, echo_audio),
                  ("zero_offer", 39.958, zero_audio[:2 * RATE]),
                  ("zero_cost", 49.458, zero_audio[2 * RATE:])]
    sources = [original, echo, zero]
    if with_laugh:
        laugh_takes = read_json(CASE / "laugh-ledger.json")["takes"]
        laugh = CASE / "echo-ja-laugh.mp3"
        kinja = CASE / "kinja-ja-reaction.mp3"
        assert all(digest(p) == laugh_takes[p.name]["sha256"] for p in (laugh, kinja))
        response = pcm(laugh, -2)
        first_split = round(3.85 * RATE)
        second_split = round(7.85 * RATE)
        first_laugh_start = shot_start_frames["SH16"] / FPS - 1.5
        placements.extend([
            ("echo_laugh_first", first_laugh_start, response[:first_split]),
            ("kinja_reaction", shot_start_frames["SH17"] / FPS + 0.02, pcm(kinja, 5)),
            ("echo_laugh_second", shot_start_frames["SH18"] / FPS, response[first_split:second_split]),
            ("echo_return_of_control", shot_start_frames["SH19"] / FPS, response[second_split:]),
        ])
        for (_, start, samples), next_shot in zip(
                placements[3:], ("SH17", "SH18", "SH19", "SH20"), strict=True):
            assert round(start * RATE) + len(samples) <= shot_start_frames[next_shot] * RATE // FPS
        sources.extend((laugh, kinja))
    soundtrack = array("h", [0]) * (total_frames * RATE // FPS)
    windows = []
    last_end = 0
    for cue, start, samples in placements:
        first = round(start * RATE)
        end = first + len(samples)
        assert first >= last_end and end <= len(soundtrack)
        if cue in ("echo", "zero_offer", "zero_cost"):
            assert end / RATE < gate
        else:
            assert first / RATE >= gate + 4 and end / RATE < 73 + sum(holds.values()) / FPS + 4
        assert max(map(abs, samples)) < 32767
        soundtrack[first:end] = samples
        windows.append({"cue": cue, "start_s": first / RATE, "end_s": end / RATE})
        last_end = end

    with tempfile.TemporaryDirectory(prefix="japanese-review-", dir=cache) as temp:
        temp = Path(temp)
        concat = temp / "segments.txt"

        def list_segments(files):
            concat.write_text("\n".join(f"file '{path.as_posix()}'" for path in files) + "\n", encoding="utf-8")

        list_segments(segments)
        remux = temp / "cached-original.mp4"
        concat_input = ["-f", "concat", "-safe", "0", "-i", str(concat)]
        subprocess.run(FFMPEG + concat_input + ["-c", "copy", "-movflags", "+faststart", str(remux)], check=True)
        # Prove that the cache is the published silent review before adding the hold.
        assert digest(remux) == editorial["sha256"], "Cached segments differ from the verified silent review"
        if with_laugh:
            from render_signature_animatic import plate, text_filters

            index = next(i for i, shot in enumerate(shots) if shot["id"] == "SH19")
            seated = next(shot for shot in shots if shot["id"] == "SH15")
            scene = dict(shots[index], global_pdf_page=52,
                         page_path=seated["page_path"], crop_normalized=[.47, .065, .80, .225])
            page = APP / scene["page_path"]
            assert digest(page) == read_json(PACKET / "source-lock.json")["files"][scene["page_path"]]
            frame = temp / "SH19-return-look.png"
            plate(scene, False).save(frame)
            labels = text_filters(temp, scene)
            (temp / "SH19-note.txt").write_text("أداء صوتي ياباني تجريبي • قبل لقطة التحوّل", encoding="utf-8")
            replacement = temp / "SH19-source.mp4"
            subprocess.run(FFMPEG + [
                "-loop", "1", "-framerate", str(FPS), "-i", str(frame), "-vf", labels,
                "-frames:v", str(round(scene["duration_seconds"] * FPS)), "-an",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                "-pix_fmt", "yuv420p", "-r", str(FPS), str(replacement),
            ], cwd=temp, check=True)
            segments[index] = replacement
        for index, shot in enumerate(shots):
            frames = holds.get(shot["id"])
            if frames is None:
                continue
            extended = temp / f"{shot['id']}-extended.mp4"
            subprocess.run(FFMPEG + [
                "-i", str(segments[index]), "-vf", f"tpad=stop_mode=clone:stop={frames}", "-an",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
                "-pix_fmt", "yuv420p", "-r", str(FPS), str(extended),
            ], check=True)
            assert int(probe(extended)["streams"][0]["nb_frames"]) == round(shot["duration_seconds"] * FPS) + frames
            segments[index] = extended
        list_segments(segments)
        sound = temp / "timing.wav"
        with wave.open(str(sound), "wb") as wav:
            wav.setparams((1, 2, RATE, len(soundtrack), "NONE", "not compressed"))
            wav.writeframes(soundtrack.tobytes())
        subprocess.run(FFMPEG + concat_input + [
            "-i", str(sound), "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "aac", "-b:a", "128k",
            "-metadata", "comment=Internal Japanese timing study; scratch voices by ElevenLabs.",
            "-movflags", "+faststart", str(pending),
        ], check=True)

    media = probe(pending)
    video, audio = media["streams"]
    assert int(video["nb_frames"]) == total_frames and video["r_frame_rate"] == "24/1"
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == str(RATE)
    assert abs(float(media["format"]["duration"]) - duration) < 0.002
    pending.replace(result)
    record = {
        "status": "P06_INTERNAL_JAPANESE_TIMING_PREVIEW",
        "scope": "Cached pictures and scratch voices, linear review only. Full performance, rights and playing acceptance open.",
        "frame_rate": FPS, "frames": total_frames, "duration_s": duration, "hold_frames_added_to_sh03": HOLD_FRAMES,
        "audio": windows, "decision_slate": {"start_s": gate, "duration_s": 4, "grants_progression": False},
        "handoff_slate": {"start_s": duration - 4, "duration_s": 4},
        "source_hashes": {p.relative_to(APP).as_posix(): digest(p) for p in sources},
        "preview_sha256": digest(result),
    }
    if with_laugh:
        record["hold_frames_added_to_sh19"] = holds["SH19"]
        record["sh19_source_override"] = {"pdf_page": 52, "path": scene["page_path"],
                                           "sha256": digest(page), "crop_normalized": scene["crop_normalized"]}
        record["reaction_shot_starts_s"] = {
            shot_id: shot_start_frames[shot_id] / FPS for shot_id in ("SH15", "SH16", "SH17", "SH18", "SH19", "SH20")
        }
    (CASE / f"timing-review{suffix}.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS {total_frames} frames, {duration:.3f}s, {len(sources)-1} audio sources")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--with-laugh", action="store_true")
    run(parser.parse_args().with_laugh)
