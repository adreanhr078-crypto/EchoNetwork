"""Shortlist one motion per semantic action for visual review; not final approval."""
import collections
import json
from pathlib import Path


def main():
    base = Path.cwd() / "art/production/master-animation-library/manifests"
    records = json.loads((base / "CandidateReviews.json").read_text(encoding="utf-8"))["candidates"]
    measurements = {x["take_id"]:x for x in json.loads((base / "MotionMetrics.json").read_text(encoding="utf-8"))["takes"]}
    declared = json.loads((base / "SourceMetadata.json").read_text(encoding="utf-8"))["files"]
    groups = collections.defaultdict(list)
    seen = set()
    for item in records:
        action_id = item["proposed_action_id"]
        identity = (action_id, item.get("take_id") or item["file_sha256"])
        if identity in seen:
            continue
        seen.add(identity)
        metrics = measurements.get(item.get("take_id"), {})
        source = declared.get(item["file_sha256"], {})
        reasons = []
        issues = []
        score = 0
        if item.get("inspection_status") == "pending" or not metrics:
            issues.append("awaiting_complete_motion_inspection")
        else:
            missing = item.get("metrics",{}).get("missing_roles",[])
            critical = [r for r in missing if r in ("hips","head","left_foot","right_foot","left_knee","right_knee")]
            if critical:
                issues.append("missing_critical_bones:"+",".join(critical))
            else:
                score += 10
                reasons.append("critical_humanoid_roles_present")
            duration = metrics.get("duration_seconds",0)
            if 0.15 <= duration <= 180:
                score += 3
            else:
                issues.append("invalid_or_excessive_clip_duration")
            if metrics.get("bone_count",0) >= 22:
                score += 2
            fps = source.get("source_fps") or metrics.get("fps",0)
            if fps >= 30:
                score += 2
                reasons.append("source_fps_at_least_30")
            elif fps < 24:
                issues.append("low_source_fps")
            name = item["original_filename"].lower()
            if "mixamo" in name or item["source_pack"] == "Mixamo":
                score += 3
                reasons.append("target_compatible_mixamo_naming")
            if item["source_pack"] in ("Rokoko","Motus_MCO"):
                score += 2
                reasons.append("mocap_source_pack")
            if "_ue." in name or "_hik." in name or "_humanik" in name:
                score -= 1
            if "_ipc." in name or "in_place" in name:
                score += 1
            if item["gameplay_category"] in ("Locomotion","Jumping","Parkour","Climbing","Dodges","CrouchStealth"):
                contact = metrics.get("foot_contact",{})
                # V2 contacts are defined by low velocity. Giving a quality bonus
                # for that same threshold would make the ranking circular.
                if len(contact) == 2 and all(v.get("contact_samples", 0) >= 3 for v in contact.values()):
                    reasons.append("measured_stance_intervals_available_for_comparison")
                else:
                    issues.append("insufficient_stance_evidence_requires_visual_phase_review")
            if item.get("loop_filename_hint"):
                seam = metrics.get("loop_seam_median_relative_position_m")
                if seam is not None and seam < 0.08:
                    score += 3
                    reasons.append("good_measured_loop_seam")
                elif seam is not None and seam > 0.3:
                    issues.append("loop_seam_large")
        groups[action_id].append({"source_id":item["source_id"],"take_id":item.get("take_id"),
                                  "file_sha256":item["file_sha256"],"source_pack":item["source_pack"],
                                  "original_filename":item["original_filename"],"score":score,
                                  "measured_reasons":reasons,"review_flags":issues,
                                  "fps":source.get("source_fps") or metrics.get("fps"),
                                  "duration_seconds":metrics.get("duration_seconds")})
    shortlisted = []
    for action, choices in sorted(groups.items()):
        choices.sort(key=lambda c:(-c["score"],len(c["review_flags"]),c["original_filename"],c["source_id"]))
        shortlisted.append({"action_id":action,"status":"ranked_for_visual_comparison_not_approved",
                            "shortlist":choices[:5],"alternative_count":max(0,len(choices)-5),
                            "candidate_count":len(choices)})
    (base / "SelectionShortlist.json").write_text(json.dumps({"schema_version":1,
        "status":"measured_ranking_not_approval", "actions":shortlisted},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps({"semantic_actions":len(shortlisted),"with_multiple_candidates":sum(x["candidate_count"]>1 for x in shortlisted),
                      "ranked":len(shortlisted),"approved":0}))


if __name__ == "__main__":
    main()
