"""Render an internal, silent panel edit with a separately labelled Omni motion study.

Source pages stay immutable. Derived plates/segments are content-keyed in .tmp.
Linear decision slates never stand in for the native tool's explicit choice.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps, __version__ as pillow_version

from build_signature_packet import APP, PACKET, sha

FONT = APP / "godot/assets/fonts/NotoSansArabic.ttf"
SIZE = (1280, 720)


def run(args: list[str], cwd: Path | None = None) -> None:
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr[-3000:])


def plate(shot: dict, overlay_only: bool) -> Image.Image:
    image = Image.new("RGBA" if overlay_only else "RGB", SIZE, (0, 0, 0, 0) if overlay_only else "#080b13")
    draw = ImageDraw.Draw(image)
    if not overlay_only:
        page = Image.open(APP / shot["page_path"]).convert("RGB")
        x1, y1, x2, y2 = shot["crop_normalized"]
        panel = page.crop((int(x1 * page.width), int(y1 * page.height), int(x2 * page.width), int(y2 * page.height)))
        panel = ImageOps.contain(panel, (1200, 540), Image.Resampling.LANCZOS)
        image.paste(panel, ((1280 - panel.width) // 2, 68 + (540 - panel.height) // 2))
    draw.rectangle((0, 0, 1280, 58), fill="#080b13")
    draw.rectangle((0, 610, 1280, 720), fill="#080b13")
    return image


def text_filters(cache: Path, shot: dict) -> str:
    # Reuse the installed FFmpeg's verified FriBidi shaping; local Pillow lacks
    # libraqm. UTF-8 text files avoid shell/filter interpolation of Arabic text.
    if shot.get("motion_reference"):
        note = "مرجع حركة عام؛ هوية إيكو غير معتمدة بهذه العينة"
    elif shot["gate"] == "explicit_preview_consent":
        note = "قرار بلا مؤقت في المعاينة التفاعلية؛ هذا القطع الخطي لا يقبل العقد"
    elif shot["event_id"] == "O06":
        note = "تأتي هذه اللقطة بعد اختيار قبول صريح فقط؛ لا حفظ أو تقدم من الفيديو"
    elif shot["gate"] == "gameplay_handoff":
        note = "هنا يلزم لعب حقيقي؛ القتال والتماس والمتعة قيد التأهيل"
    else:
        note = "لوحات مصدر مؤقتة • بلا صوت • التمثيل والتماس والتوقيت النهائي غير معتمدة"
    font = Path(os.path.relpath(FONT, cache)).as_posix()
    values = [("heading", "إيكو: من الرفض إلى القرار • مونتاج داخلي مؤقت", 23, "w-tw-40", 10, "white"),
              ("metadata", f"{shot['id']} / {shot['event_id']} / PDF {shot['global_pdf_page']}", 17, "30", 17, "0xa9bfd2"),
              ("title", shot["title_ar"], 30, "w-tw-40", 621, "white"),
              ("note", note, 17, "w-tw-40", 677, "0xe6c49b")]
    filters = []
    for role, value, size, x, y, color in values:
        filename = f"{shot['id']}-{role}.txt"
        (cache / filename).write_text(value, encoding="utf-8")
        filters.append(f"drawtext=fontfile='{font}':textfile='{filename}':text_shaping=1:fontsize={size}:fontcolor={color}:x={x}:y={y}")
    return ",".join(filters)


def main(output: Path) -> None:
    timeline = json.loads((PACKET / "editorial-timeline.json").read_text(encoding="utf-8"))
    locks = json.loads((PACKET / "source-lock.json").read_text(encoding="utf-8"))["files"]
    for relative, expected in locks.items():
        if sha(APP / relative) != expected:
            raise ValueError(f"Source lock changed: {relative}")
    ffmpeg_version = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    toolchain = {"ffmpeg": ffmpeg_version, "Pillow": pillow_version}
    key_inputs = [sha(Path(__file__)), sha(PACKET / "editorial-timeline.json"), sha(PACKET / "source-lock.json"), sha(FONT), json.dumps(toolchain, sort_keys=True)]
    key = hashlib.sha256("|".join(key_inputs).encode()).hexdigest()[:20]
    cache = APP / ".tmp/signature-animatic" / key
    cache.mkdir(parents=True, exist_ok=True)
    segments, total, hits = [], 0.0, 0
    ffmpeg = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    encoding = ["-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", "-r", "24"]
    for shot in timeline["shots"]:
        duration = shot["duration_seconds"] or 4.0
        total += duration
        segment = cache / (shot["id"] + ".mp4")
        image_path = cache / (shot["id"] + ".png")
        if not segment.is_file():
            reference = shot.get("motion_reference")
            plate(shot, bool(reference)).save(image_path)
            labels = text_filters(cache, shot)
            if reference:
                filters = "[0:v]scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=0x080b13,tpad=stop_mode=clone:stop_duration=1[base];[base][1:v]overlay=0:0:shortest=1," + labels + ",format=yuv420p[v]"
                args = ["-ss", str(reference["start_seconds"]), "-i", str(APP / reference["path"]),
                        "-loop", "1", "-framerate", "24", "-i", str(image_path), "-filter_complex", filters,
                        "-map", "[v]", "-t", str(duration)]
            else:
                args = ["-loop", "1", "-framerate", "24", "-i", str(image_path), "-vf", labels, "-t", str(duration)]
            run(ffmpeg + args + encoding + [str(segment)], cwd=cache)
        else:
            hits += 1
        segments.append(segment)
        print(f"{shot['id']} ready", flush=True)
    concat = cache / "concat.txt"
    concat.write_text("\n".join(f"file '{path.as_posix()}'" for path in segments) + "\n", encoding="utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.stem + ".pending.mp4")
    run(ffmpeg + ["-f", "concat", "-safe", "0", "-i", str(concat), "-c", "copy", "-movflags", "+faststart", str(temporary)])
    temporary.replace(output)
    manifest = {"status": "SILENT_INTERNAL_EDITORIAL_NOT_FINAL_CINEMATIC", "seconds": total,
                "source_key": key, "toolchain": toolchain, "cache_hits": hits, "segments": len(segments),
                "output": str(output), "sha256": sha(output), "bytes": output.stat().st_size,
                "decision_slates_seconds_each": 4, "interactive_consent": "ONLY_IN_NATIVE_REVIEW;linear export grants nothing",
                "audio": "No audio stream;Omni audio intentionally omitted pending audition",
                "generic_motion_reference": "SH06/SH07;not final Echo identity or approved runtime animation"}
    (PACKET / "editorial-export.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=PACKET / "signature-editorial-v1.mp4")
    main(parser.parse_args().output)
