"""Validate actual P01/P06 sources, dependency boundaries and produced evidence."""
from __future__ import annotations

import json
import subprocess

from build_signature_packet import APP, PACKET, PRODUCTION, sha


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    checks = []

    def check(condition, name):
        checks.append({"name": name, "pass": bool(condition)})

    ledger = load(PRODUCTION / "CINEMATIC_EXPERIENCE_SCENE_LEDGER_2026-11-03.json")
    coverage = load(PRODUCTION / "PRODUCTION_COVERAGE_2026-11-04.json")
    matrix = load(PACKET / "event-source-matrix.json")
    timeline = load(PACKET / "editorial-timeline.json")
    lock = load(PACKET / "source-lock.json")["files"]
    expected = {s["id"]: s["event_ar"] for s in ledger["scenes"]}
    rows = matrix["events"]
    check(len(rows) == 53 and {r["event_id"]: r["event_ar"] for r in rows} == expected, "exact existing 53-event coverage and names")
    check(len(coverage["phases"]) == 40 and len(coverage["requirements"]) == 128, "40 phases and 128 requirements preserved")
    check(matrix["page_numbering"] == "GLOBAL_PDF_INCLUDING_COVER", "global page numbering includes cover")
    check(all(r["relation"] in ["direct", "support", "owner"] for r in rows), "source relationship explicit for every event")
    check(all(bool(r["global_pdf_pages"]) == (r["relation"] != "owner") for r in rows), "Owner expansions never receive invented direct page IDs")
    check(all(isinstance(n, int) and 1 <= n <= 70 for r in rows for n in r["global_pdf_pages"]), "all mapped pages in approved publication")
    check(all(r["runtime_exposure_authorized_by_this_file"] is False for r in rows), "mapping does not authorize early exposure")
    mismatches = []
    for relative, expected_hash in lock.items():
        path = (APP / relative).resolve()
        if not path.is_relative_to(APP) or not path.is_file() or sha(path) != expected_hash:
            mismatches.append(relative)
    check(not mismatches, f"all {len(lock)} source locks match")
    shots = timeline["shots"]
    decisions = [i for i, s in enumerate(shots) if s["gate"] == "explicit_preview_consent"]
    check(len(shots) == 23 and len({s["id"] for s in shots}) == 23, "23 distinct editorial shots")
    check(decisions == [12] and shots[12]["event_id"] == "O05" and shots[12]["duration_seconds"] == 0, "one explicit indefinite choice at existing O05")
    check(shots[-1]["gate"] == "gameplay_handoff" and shots[-1]["event_id"] == "C01", "edit ends at live gameplay dependency")
    check(all(s["event_id"] in expected for s in shots), "no new story event")
    check(all(s["earned_preview_only"] == (i > 12) for i, s in enumerate(shots)), "earned material only after decision")
    check(all(s["page_path"].endswith(f"page-{s['global_pdf_page']:03}.webp") and s["page_path"] in lock for s in shots), "every shot tied to actual locked page")
    check(all(0 <= s["crop_normalized"][0] < s["crop_normalized"][2] <= 1 and 0 <= s["crop_normalized"][1] < s["crop_normalized"][3] <= 1 for s in shots), "all panel crops valid")
    check(abs(sum(s["duration_seconds"] for s in shots) - timeline["timed_seconds_excluding_player_decisions"]) < 1e-6, "editorial clock consistent")
    check(all(s["duration_seconds"] >= 0 for s in shots), "no negative cut duration")
    check(all(s["motion_reference"]["path"] in lock and s["event_id"] in ["O01", "O02"] for s in shots if "motion_reference" in s), "generic Omni study limited to underwater reference")
    reports = []
    evidence = APP / "audits/evidence/signature-slice-20261104"
    for report_path in sorted(evidence.glob("native-review-*.json")):
        report = load(report_path)
        hashes = report.get("source_hashes", {})
        reports.append({"file": report_path.name, "checks": report["checks"], "failures": report["failures"],
                        "current_hashes": bool(hashes) and all(sha(APP / k) == h for k, h in hashes.items())})
    check(any(r["file"] == "native-review-headless.json" and r["current_hashes"] and not r["failures"] for r in reports), "headless evidence matches current sources")
    check(any(r["file"] != "native-review-headless.json" and r["current_hashes"] and not r["failures"] for r in reports), "rendered native evidence matches current sources")
    export_path = PACKET / "editorial-export.json"
    if export_path.is_file():
        export = load(export_path)
        path = PACKET / "signature-editorial-v1.mp4"
        check(path.is_file() and sha(path) == export["sha256"], "editorial export hash matches")
        probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type,width,height,r_frame_rate", "-of", "json", str(path)], capture_output=True, text=True, check=True)
        media = json.loads(probe.stdout)
        check(len(media["streams"]) == 1 and media["streams"][0]["codec_type"] == "video", "export has no unreviewed audio stream")
        check(abs(float(media["format"]["duration"]) - 81.0) < .1, "linear review includes two explicit four-second decision/handoff slates")
    result = {"status": "PASS_PACKET_INTEGRITY_ONLY" if all(c["pass"] for c in checks) else "FAIL",
              "checks": checks, "source_mismatches": mismatches, "native_evidence": reports,
              "acceptance_limits": "Not final dialogue,voice,acting,contact,gameplay,fun,device or chapter acceptance"}
    (evidence / "packet-validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "checks": len(checks), "failed": [c["name"] for c in checks if not c["pass"]], "native": reports}))
    return 0 if all(c["pass"] for c in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
