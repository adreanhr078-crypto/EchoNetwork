#!/usr/bin/env python3
"""Validate room evidence integrity. Does not judge pixels, gameplay or art."""
import argparse
import hashlib
import json
import math
import re
import struct
import sys
import zlib
from pathlib import Path

STAGES = ["draft", "references-reviewed", "cinematic-reviewed", "assets-reviewed", "native-reviewed"]
ROLES = {"entry", "reverse", "lateral", "hero-detail"}


def number(value):
    """JSON booleans are not measured dimensions, durations or credit costs."""
    return type(value) in (int, float) and math.isfinite(value)


def media_file(raw, path, kind):
    """Check local media container structure; this is not playback/art review."""
    extension = path.suffix.lower()
    if kind == "image":
        if extension == ".png" and raw.startswith(b"\x89PNG\r\n\x1a\n"):
            offset, kinds, compressed = 8, [], bytearray()
            while offset + 12 <= len(raw):
                size = struct.unpack_from(">I", raw, offset)[0]
                end = offset + 12 + size
                if end > len(raw):
                    return False
                chunk = raw[offset + 4:offset + 8]
                payload = raw[offset + 8:offset + 8 + size]
                crc = struct.unpack_from(">I", raw, offset + 8 + size)[0]
                if zlib.crc32(chunk + payload) & 0xffffffff != crc:
                    return False
                kinds.append(chunk)
                if chunk == b"IHDR":
                    if size != 13 or not all(struct.unpack_from(">II", payload)):
                        return False
                if chunk == b"IDAT":
                    compressed.extend(payload)
                offset = end
                if chunk == b"IEND":
                    return kinds[0] == b"IHDR" and size == 0 and offset == len(raw) and bool(zlib.decompress(compressed))
            return False
        if extension in (".jpg", ".jpeg"):
            return len(raw) > 20 and raw.startswith(b"\xff\xd8\xff") and raw.endswith(b"\xff\xd9")
        if extension == ".webp":
            return len(raw) > 20 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP" and struct.unpack_from("<I", raw, 4)[0] + 8 == len(raw)
        return False
    if kind == "video":
        if extension in (".mp4", ".mov"):
            offset, boxes = 0, {}
            while offset + 8 <= len(raw):
                size, box = struct.unpack_from(">I4s", raw, offset)
                header = 8
                if size == 1:
                    if offset + 16 > len(raw):
                        return False
                    size = struct.unpack_from(">Q", raw, offset + 8)[0]
                    header = 16
                if size == 0:
                    size = len(raw) - offset
                if size < header or offset + size > len(raw):
                    return False
                boxes.setdefault(box, []).append(raw[offset + header:offset + size])
                offset += size
            return offset == len(raw) and all(k in boxes for k in (b"ftyp", b"moov", b"mdat")) and any(b"vide" in b for b in boxes[b"moov"])
        if extension == ".webm":
            return raw.startswith(b"\x1aE\xdf\xa3") and b"webm" in raw[:4096] and b"V_" in raw
        if extension in (".ogv", ".ogg"):
            return raw.startswith(b"OggS") and b"\x80theora" in raw[:65536]
        return False
    if kind in ("model", "editable"):
        if extension == ".glb":
            if len(raw) < 20 or struct.unpack_from("<4sII", raw) != (b"glTF", 2, len(raw)):
                return False
            size, chunk = struct.unpack_from("<I4s", raw, 12)
            if chunk != b"JSON" or size > len(raw) - 20:
                return False
            document = json.loads(raw[20:20 + size])
            return document.get("asset", {}).get("version") == "2.0" and bool(document.get("meshes"))
        if extension == ".gltf":
            document = json.loads(raw)
            return document.get("asset", {}).get("version") == "2.0" and bool(document.get("meshes"))
        if extension == ".obj":
            return bool(re.search(rb"(?m)^v\s+[-0-9.]", raw)) and bool(re.search(rb"(?m)^f\s+[0-9]", raw))
        if extension == ".fbx":
            return raw.startswith(b"Kaydara FBX Binary  \x00") or raw.startswith(b"; FBX")
        if kind == "editable" and extension == ".blend":
            # Blender also writes concatenated Zstandard frames. Without an
            # optional decoder this checks that container header only; opening
            # the actual editable file remains an independent review gate.
            return len(raw) > 12 and (raw.startswith(b"BLENDER") or (raw.startswith(b"\x28\xb5\x2f\xfd") and raw[4] & 0x18 == 0))
        if kind == "editable" and extension == ".tscn":
            return raw.lstrip().startswith(b"[gd_scene")
        return False
    return True


def validate(packet):
    root = packet.parent.resolve()
    data = json.loads(packet.read_text(encoding="utf-8-sig"))
    errors = []
    verified = []
    def check(ok, message):
        if not ok:
            errors.append(message)
    if not isinstance(data, dict):
        return {"status": "FAIL", "errors": ["Evidence packet must be a JSON object"]}
    def rows(value, label):
        if not isinstance(value, list):
            check(False, label + ": expected array")
            return []
        result = []
        for row in value:
            if not isinstance(row, dict):
                check(False, label + ": expected object rows")
            else:
                result.append(row)
        return result
    def mapping(value, label):
        if not isinstance(value, dict):
            check(False, label + ": expected object")
            return {}
        return value
    stage = data.get("stage")
    check(stage in STAGES, "Unknown evidence stage")
    rank = STAGES.index(stage) if stage in STAGES else 0
    check(type(data.get("schema_version")) is int and data.get("schema_version") == 1, "Expected schema_version integer 1")
    check(isinstance(data.get("room_id"), str) and bool(data.get("room_id", "").strip()), "Missing string room_id")
    serialized = json.dumps(data)
    check(not re.search(r"tsk_[A-Za-z0-9_-]{24,}|Bearer\s+[A-Za-z0-9._-]{20,}", serialized), "Credential-like content in evidence packet")
    def artifact(record, label, kind=None):
        if not isinstance(record, dict):
            check(False, label + ": expected path/hash record")
            return None
        relative = record.get("path")
        if not isinstance(relative, str) or not relative:
            check(False, label + ": missing file path")
            return None
        path = Path(relative)
        if path.is_absolute():
            check(False, label + ": packet files must use contained relative paths")
            return None
        path = (root / path).resolve()
        try:
            path.relative_to(root)
        except ValueError:
            check(False, label + ": file escapes packet root")
            return None
        if not path.is_file() or path.stat().st_size == 0:
            check(False, label + ": file missing or empty")
            return None
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        expected = record.get("sha256")
        matched = isinstance(expected, str) and digest == expected.lower()
        check(matched, label + ": SHA256 missing or mismatched")
        media_ok = True
        if kind:
            try:
                media_ok = media_file(raw, path, kind)
            except (ValueError, TypeError, struct.error, zlib.error, AttributeError):
                media_ok = False
            check(media_ok, label + ": invalid or unsupported " + kind + " media container")
        verified.append({"label": label, "path": relative, "sha256": digest})
        return digest if matched and media_ok else None
    refs = rows(data.get("references", []), "references")
    ids = [r.get("id") for r in refs]
    check(all(isinstance(i, str) and bool(i.strip()) for i in ids), "Reference IDs must be nonempty strings")
    check(len(ids) == len(set(ids)), "Reference IDs must be unique")
    if rank >= 1:
        dimensions = mapping(data.get("room_contract", {}), "room_contract").get("dimensions_m", [])
        check(isinstance(dimensions, list) and len(dimensions) == 3 and all(number(n) and n > 0 for n in dimensions), "Measured room dimensions required")
        check(len(refs) == 4 and {r.get("role") for r in refs} == ROLES, "Exactly four references with entry/reverse/lateral/hero-detail roles required")
    hashes = []
    for row in refs:
        digest = artifact(row.get("file"), "reference " + str(row.get("id")), "image")
        if digest:
            hashes.append(digest)
        if rank >= 1:
            check(row.get("review") == "accepted", "Reference visual review is still open")
    if rank >= 1:
        check(len(hashes) == 4 and len(set(hashes)) == 4, "Four separate distinct reference images required")
    cinematic = mapping(data.get("cinematic", {}), "cinematic")
    frames = rows(data.get("frames", []), "frames")
    frame_ids = [r.get("id") for r in frames]
    check(all(isinstance(i, str) and bool(i.strip()) for i in frame_ids) and len(frame_ids) == len(set(frame_ids)), "Frame IDs must be unique nonempty strings")
    if rank >= 2:
        check(cinematic.get("status") == "success" and cinematic.get("review") == "accepted", "Successful fully reviewed cinematic required")
        video_digest = artifact(cinematic.get("file"), "cinematic video", "video")
        artifact(cinematic.get("prompt_file"), "submitted cinematic prompt")
        artifact(cinematic.get("submission_evidence"), "actual four-reference submission evidence")
        check(set(cinematic.get("submitted_reference_ids", [])) == set(ids), "Actual cinematic packet must include all four reference IDs")
        duration = cinematic.get("duration_s")
        check(number(duration) and duration > 0, "Actual video duration required")
        check(len(frames) >= 4, "At least four extracted frames required")
        times = []
        for row in frames:
            artifact(row.get("file"), "frame " + str(row.get("id")), "image")
            check(video_digest is not None and row.get("source_video_sha256") == video_digest, "Extracted frame must identify the actual source video SHA256")
            timestamp = row.get("timestamp_s")
            valid_time = number(timestamp) and timestamp >= 0 and number(duration) and timestamp <= duration
            check(valid_time, "Extracted frame timestamp outside actual video")
            check(row.get("review") == "accepted", "Frame sharpness/continuity review remains open")
            if valid_time:
                times.append(timestamp)
        check(len(set(times)) >= 4, "Four distinct actual frame timestamps required")
    assets = rows(data.get("assets", []), "assets")
    if rank >= 3:
        check(bool(assets), "Accepted asset kit required")
        for row in assets:
            label = "asset " + str(row.get("id"))
            for key in ["raw", "model", "editable"]:
                artifact(row.get(key), label + " " + key, "editable" if key == "editable" else "model")
            check(row.get("source_frame_id") in frame_ids, label + ": missing actual cinematic frame provenance")
            check(row.get("geometry_review") == "accepted" and row.get("native_review") == "accepted", label + ": geometry/native review remains open")
            check(bool(row.get("provider_task_id")), label + ": actual provider task ID required")
    jobs = rows(data.get("generation_jobs", []), "generation_jobs")
    budgets = mapping(data.get("budgets", {}), "budgets")
    completed = set()
    for job in jobs:
        check(job.get("status") in ("not_submitted", "submitted", "pending", "running", "success", "failed", "blocked", "cancelled"), "Unknown generation job status")
        provider = job.get("provider")
        check(isinstance(provider, str) and bool(provider), "Generation provider required")
        if not isinstance(provider, str):
            continue
        budget = mapping(budgets.get(provider, {}), "budget " + provider)
        charge = job.get("charged_credits")
        if charge is not None:
            check(number(charge) and charge >= 0, "Invalid actual generation charge")
        if job.get("status") == "success":
            task = job.get("task_id")
            valid_task = isinstance(task, str) and bool(task.strip())
            valid_charge = number(charge) and charge >= 0
            check(valid_task and valid_charge, "Completed paid job needs actual task ID and charge")
            if valid_task and valid_charge:
                check((provider, task) not in completed, "Duplicate completed provider task ID")
                completed.add((provider, task))
        check("authorized_credits" in budget, "Missing provider-specific authorized budget")
    for provider, value in budgets.items():
        budget = mapping(value, "budget " + str(provider))
        authorized = budget.get("authorized_credits")
        charges = [j.get("charged_credits") for j in jobs if j.get("provider") == provider]
        known = [n for n in charges if number(n) and n >= 0]
        check(number(authorized) and authorized >= 0 and sum(known) <= authorized, "Provider budget exceeded: " + str(provider))
    if rank >= 2:
        check((cinematic.get("provider", "flow"), cinematic.get("provider_task_id")) in completed, "Reviewed cinematic requires its successful provider job and actual charge in the shared ledger")
    if rank >= 3:
        for row in assets:
            check((row.get("provider", "tripo"), row.get("provider_task_id")) in completed, "Reviewed asset requires its successful provider job and actual charge in the shared ledger")
    if rank >= 4:
        reviews = mapping(data.get("native_reviews", {}), "native_reviews")
        for key in ["visual", "traversal", "pause", "reduced_motion", "mute", "performance"]:
            check(reviews.get(key) == "PASS", "Native room review open: " + key)
        evidence = rows(data.get("native_evidence", []), "native_evidence")
        check(bool(evidence), "Actual native evidence required")
        for row in evidence:
            artifact(row, "native evidence")
    return {"status": "FAIL" if errors else "PASS", "scope": "Packet schema, contained files, SHA256, media container checks and declared stage/ledger links only; pixel continuity, full decoding, playback, authenticity, gameplay and performance require independent review.", "stage": stage, "verified_files": verified, "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        result = validate(args.manifest.resolve())
    except (OSError, ValueError, TypeError, KeyError, AttributeError, OverflowError) as exc:
        result = {"status": "FAIL", "errors": [str(exc)]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
