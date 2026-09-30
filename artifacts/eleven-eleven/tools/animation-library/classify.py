"""Conservative semantic proposals. Never grants quality approval.

Explicit human-reviewed overrides may merge synonyms, split compound takes, or
identify protected variants. Unknown motion remains needs_semantic_review.
"""
import collections
import json
from pathlib import Path
import re

from inventory import write_json, ANIMATION_EXTENSIONS

CATEGORIES = ["Locomotion", "Jumping", "Parkour", "Climbing", "Combat", "Katana",
              "UnarmedCombat", "Dodges", "HitReactions", "Deaths", "Interaction",
              "Social", "DailyLife", "NPC", "Cinematic", "Weapons", "CrouchStealth",
              "Swimming", "Miscellaneous"]


def words(filename):
    stem = Path(filename).stem
    stem = re.sub(r"(?<=[a-z])(?=[A-Z])", "_", stem)
    stem = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", "_", stem)
    stem = stem.lower()
    stem = re.sub(r"(?:_mixamo|_humanik|_hik|_ue|_unreal|_unity|_769|_whs|_ftc|_tf1|_ipc|_in_place|_root_motion|_segment)(?=\b|_)", "", stem)
    return re.sub(r"[^a-z0-9]+", "_", stem).strip("_")


def suggest(file, take=None):
    name = words(file["original_filename"])
    name = re.sub(r"^(?:mob1|motusman)_", "", name)
    path = file["source_entry"].lower()
    category = "Miscellaneous"
    rules = [
        ("Swimming", r"swim|dive|drown"), ("Deaths", r"death|dying|die|knock_out_loser"),
        ("HitReactions", r"react|impact|hurt|hit_reaction|stumble|knockout|knock_out"),
        ("Climbing", r"climb|hang|ledge|mantle"), ("CrouchStealth", r"crouch|crawl|stealth|tiptoe"),
        ("Dodges", r"dodge|roll|evade|backflip"), ("Parkour", r"vault|wall_run|obstacle|parkour|swing_to_land"),
        ("Jumping", r"jump|land|fall"), ("Katana", r"katana|iaido|iai_"),
        ("Weapons", r"rifle|pistol|gun|shoot|aim|bow|torch|blaster"),
        ("UnarmedCombat", r"punch|kick|box|unarmed|shoulder_throw|melee"),
        ("Combat", r"sword|fight|attack|slash|combat|takedown"),
        ("Locomotion", r"walk|run|jog|sprint|strafe|turn|idle|skid|stop|direction_change"),
        ("Social", r"chat|convo|conversation|argu|wave|clap|greet|laugh|celebrat|dance|dancing"),
        ("Interaction", r"open|close|door|pick_up|push|pull|interact|lever|button|carry|equip"),
        ("DailyLife", r"sit|seat|desk|sleep|eat|drink|phone|dress|drive|driving|guitar|music|drum|fish|cricket|sport"),
        ("NPC", r"zombie|mummy|npc|crowd"),
        ("Cinematic", r"cinematic|force|superman|iron_man|batman|vader|trooper|wookie"),
    ]
    for candidate, pattern in rules:
        if re.search(pattern, name):
            category = candidate
            break
    plain_walk = {"walking", "walk", "standard_walk", "walk_forward", "walkforward", "walk_cycle_01", "walk_cycle01", "walk_cycle", "walkcycle_01", "walk_f", "walk_f_loop"}
    plain_run = {"running", "run", "run_forward", "standing_run_forward", "running_treadmill", "run_cycle"}
    plain_jog = {"jog", "jog_f", "jog_forward", "run_jog"}
    if name in plain_walk:
        action = "walk_forward"
    elif name in plain_run:
        action = "run_forward"
    elif name in plain_jog:
        action = "jog_forward"
    else:
        # Keep direction/intensity/context tokens until explicitly reviewed.
        # Version/take numbers are alternatives, not new gameplay semantics.
        action = re.sub(r"(?:_v(?:er)?_?\d+|_\d{2})$", "", name)
    status = "needs_semantic_review"
    if action in ("walk_forward", "walk_backward", "walk_strafe_left", "walk_strafe_right", "run_forward", "run_backward", "land_soft", "land_hard_roll"):
        status = "explicit_name_proposal_needs_visual_confirmation"
    root_hint = "in_place" if re.search(r"ipc|in.?place|_ip(?:\.|_|/)", file["source_entry"], re.I) else "unknown"
    return {"proposed_action_id": action, "gameplay_category": category, "semantic_status": status,
            "root_motion_filename_hint": root_hint, "loop_filename_hint": bool(re.search(r"loop|cycle", name)),
            "source_path_context": path, "do_not_auto_merge": category == "Miscellaneous"}


def main():
    root = Path.cwd()
    base = root / "art/production/master-animation-library/manifests"
    inventory = json.loads((base / "SourceInventory.json").read_text(encoding="utf-8"))
    overrides_path = base / "SemanticOverrides.json"
    overrides = json.loads(overrides_path.read_text(encoding="utf-8")) if overrides_path.exists() else {}
    candidates, unsupported = [], []
    for file in inventory["files"]:
        if file["extension"] not in ANIMATION_EXTENSIONS or not file["working_copy"]:
            if file["extension"] in (".bip", ".i_caf", ".rlmotion", ".uasset", ".max", ".ma"):
                unsupported.append({"source_id": file["source_id"], "source_entry": file["source_entry"],
                                    "sha256": file["sha256"], "status": "format_adapter_or_equivalent_take_verification_required"})
            continue
        inspection_path = base / "inspections" / (file["sha256"] + ".json")
        inspection = json.loads(inspection_path.read_text(encoding="utf-8")) if inspection_path.exists() else None
        takes = inspection["takes"] if inspection else []
        if inspection and not takes:
            unsupported.append({"source_id": file["source_id"], "source_entry": file["source_entry"],
                                "sha256": file["sha256"], "status": inspection["status"]})
            continue
        if not takes:
            candidates.append({"source_id": file["source_id"], "source_pack": file["source_pack"],
                               "original_filename": file["original_filename"],
                               "source_entry": file["source_entry"], "file_sha256": file["sha256"],
                               **suggest(file), "inspection_status": inspection["status"] if inspection else "pending",
                               "approval_status": "not_approved"})
        for take in takes:
            semantic = suggest(file, take)
            if take["take_id"] in overrides:
                semantic.update(overrides[take["take_id"]])
            candidates.append({"source_id": file["source_id"], "source_pack": file["source_pack"],
                               "original_filename": file["original_filename"], "source_entry": file["source_entry"],
                               "file_sha256": file["sha256"], **take, **semantic,
                               "inspection_status": inspection["status"]})
    groups = collections.defaultdict(list)
    for c in candidates:
        groups[c["proposed_action_id"]].append(c.get("take_id", c["source_id"]))
    write_json(base / "SemanticActions.json", {"schema_version": 1, "status": "proposals_not_final_classification",
               "categories": CATEGORIES, "actions": [{"action_id": k, "candidate_ids": v,
               "status": "needs_comparison_and_semantic_confirmation"} for k, v in sorted(groups.items())]})
    write_json(base / "CandidateReviews.json", {"schema_version": 1, "status": "source_inspected_quality_review_pending",
               "candidates": candidates, "unsupported_source_entries": unsupported})
    write_json(base / "AlternativesManifest.json", {"schema_version": 1,
               "status": "recovery_inventory_before_selection", "source_inventory": "SourceInventory.json",
               "entries": [{"source_id": f["source_id"], "source_pack": f["source_pack"],
               "archive_path": f["archive_path"], "entry_index": f["entry_index"], "source_entry": f["source_entry"],
               "original_filename": f["original_filename"], "sha256": f["sha256"],
               "reason": "unreviewed_not_rejected", "winner_action_id": None} for f in inventory["files"]]})
    print(json.dumps({"semantic_proposals": len(groups), "candidate_records": len(candidates),
                      "unsupported_entries": len(unsupported), "approved": 0}))


if __name__ == "__main__":
    main()
