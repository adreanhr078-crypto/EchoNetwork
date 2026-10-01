"""Write a safe Higgsfield 3D capability report without exposing credentials."""

import json
from pathlib import Path

from bl_ext.user_default.higgsfield_blender.fnf.account import _auth_session_from_sdk
from bl_ext.user_default.higgsfield_blender.fnf.session import get_sdk_client


OUT = Path(__file__).with_name("higgsfield-3d-catalog.json")

try:
    session = _auth_session_from_sdk()
    if not session:
        raise RuntimeError("Higgsfield Blender session is not authenticated")
    workspace_id = (session.get("user") or {}).get("workspace_id")
    client = get_sdk_client(workspace_id)
    page = client.job_types.list(type="3d", size=100, timeout=30)
    target_models = {
        "tripo_h3_1_image_to_3d",
        "tripo_h3_1_multiview_to_3d",
        "hunyuan3d_v3_image_to_3d",
        "meshy_v7_image_to_3d",
        "multi_image_to_3d",
        "image_to_3d",
    }
    models = []
    for item in page.items or ():
        job_type = getattr(item, "job_type", None)
        row = {
            "job_type": job_type,
            "display_name": getattr(item, "display_name", None),
            "label": getattr(item, "label", None),
        }
        if job_type in target_models:
            detail = item.to_dict()
            schema = detail.get("json_schema") or {}
            row["required"] = schema.get("required") or []
            row["properties"] = schema.get("properties") or {}
        models.append(row)
    balance = session.get("balance") or {}
    OUT.write_text(
        json.dumps(
            {
                "authenticated": True,
                "credits": balance.get("credits"),
                "plan": balance.get("plan"),
                "models": models,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
except Exception as error:
    OUT.write_text(
        json.dumps({"authenticated": False, "error": str(error)}, indent=2),
        encoding="utf-8",
    )
    raise
