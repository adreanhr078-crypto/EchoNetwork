"""Estimate high-quality Echo reconstruction variants; no generation occurs."""

import json
from pathlib import Path

from bl_ext.user_default.higgsfield_blender.fnf.account import _auth_session_from_sdk
from bl_ext.user_default.higgsfield_blender.fnf.session import get_sdk_client


SCRIPT_DIR = Path(__file__).resolve().parent
ART_DIR = SCRIPT_DIR.parents[1] / "production" / "echo-higgsfield-turnaround"
OUT = SCRIPT_DIR / "higgsfield-3d-estimates.json"

front = ART_DIR / "echo-front-apose-higgsfield-v2.png"
back = ART_DIR / "echo-back-apose-higgsfield-v2.png"
left = ART_DIR / "echo-left-profile-higgsfield-v2.png"
for path in (front, back, left):
    if not path.is_file():
        raise FileNotFoundError(path)

session = _auth_session_from_sdk()
workspace_id = (session.get("user") or {}).get("workspace_id")
client = get_sdk_client(workspace_id)

uploaded = {
    "front": client.media.upload(str(front), type="image", timeout=120).as_input(),
    "back": client.media.upload(str(back), type="image", timeout=120).as_input(),
    "left": client.media.upload(str(left), type="image", timeout=120).as_input(),
}

variants = {
    "tripo_multiview_detailed": (
        "tripo_h3_1_multiview_to_3d",
        {
            "image_references": [uploaded["front"], uploaded["left"], uploaded["back"]],
            "face_limit": 500000,
            "texture": True,
            "pbr": True,
            "texture_quality": "detailed",
            "geometry_quality": "detailed",
            "quad": True,
            "texture_alignment": "original_image",
            "auto_size": True,
            "orientation": "align_image",
        },
    ),
    "hunyuan_multiview_max": (
        "hunyuan3d_v3_image_to_3d",
        {
            "image_references": [uploaded["front"], uploaded["back"], uploaded["left"]],
            "enable_pbr": True,
            "face_count": 1500000,
            "generate_type": "Normal",
            "polygon_type": "triangle",
        },
    ),
    "multi_image_game_ready": (
        "multi_image_to_3d",
        {
            "image_references": [uploaded["front"], uploaded["back"], uploaded["left"]],
            "should_texture": True,
            "should_remesh": True,
            "target_polycount": 300000,
            "topology": "quad",
            "symmetry_mode": "on",
            "enable_pbr": True,
            "pose_mode": "a-pose",
            "enable_rigging": True,
            "rigging_height_meters": 1.72,
            "enable_animation": False,
            "enable_safety_checker": True,
        },
    ),
    "meshy7_ultra_single": (
        "meshy_v7_image_to_3d",
        {
            "image_references": [uploaded["front"]],
            "model_type": "standard",
            "topology": "quad",
            "target_polycount": 300000,
            "symmetry_mode": "on",
            "should_remesh": True,
            "should_texture": True,
            "enable_pbr": True,
            "pose_mode": "a-pose",
            "enable_rigging": True,
            "rigging_height_meters": 1.72,
            "enable_animation": False,
            "enable_safety_checker": True,
            "ultra_mode": True,
        },
    ),
}

results = {}
for name, (job_type, params) in variants.items():
    try:
        estimate = client.jobs.estimate_cost(job_type=job_type, params=params, timeout=30)
        results[name] = {"job_type": job_type, "credits": estimate.credits_}
    except Exception as error:
        results[name] = {"job_type": job_type, "error": str(error)}

balance = session.get("balance") or {}
OUT.write_text(
    json.dumps(
        {"available_credits": balance.get("credits"), "estimates": results},
        indent=2,
    ),
    encoding="utf-8",
)

