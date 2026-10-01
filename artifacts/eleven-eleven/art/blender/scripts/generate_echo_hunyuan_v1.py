"""Generate Echo's first high-poly multiview candidate through Higgsfield."""

import json
import time
import urllib.request
from pathlib import Path

from higgsfield import Higgsfield
from bl_ext.user_default.higgsfield_blender.fnf.account import _auth_session_from_sdk
from bl_ext.user_default.higgsfield_blender import runtime_config
from bl_ext.user_default.higgsfield_blender.fnf.session import get_valid_access_token


SCRIPT_DIR = Path(__file__).resolve().parent
ART_DIR = SCRIPT_DIR.parents[1] / "production" / "echo-higgsfield-turnaround"
OUT_DIR = SCRIPT_DIR.parents[1] / "production" / "echo-hero-hunyuan-v1"
OUT_DIR.mkdir(parents=True, exist_ok=True)
STATUS = OUT_DIR / "generation-status.json"


def report(**payload):
    STATUS.write_text(json.dumps(payload, indent=2), encoding="utf-8")


refs = [
    ART_DIR / "echo-front-apose-higgsfield-v2.png",
    ART_DIR / "echo-back-apose-higgsfield-v2.png",
    ART_DIR / "echo-left-profile-higgsfield-v2.png",
]
for path in refs:
    if not path.is_file():
        raise FileNotFoundError(path)

session = _auth_session_from_sdk()
workspace_id = (session.get("user") or {}).get("workspace_id")
client = Higgsfield(
    api_key=get_valid_access_token(),
    base_url=runtime_config.sdk_base_url(),
    headers={
        "x-hf-mcp-client-name": "blender",
        "hf-workspace-id": str(workspace_id),
    },
)
report(status="uploading_references")
uploads = [client.media.upload(str(path), type="image", timeout=120).as_input() for path in refs]

params = {
    "image_references": uploads,
    "enable_pbr": True,
    "face_count": 1500000,
    "generate_type": "Normal",
    "polygon_type": "triangle",
}
estimate = client.jobs.estimate_cost(
    job_type="hunyuan3d_v3_image_to_3d", params=params, timeout=30
)
report(status="submitting", estimated_credits=estimate.credits_)
submission = client.models3d.create(
    job_type="hunyuan3d_v3_image_to_3d", params=params, timeout=60
)
job_id = str(submission.id)


def on_poll(job):
    report(
        status=str(job.status),
        job_id=job_id,
        estimated_credits=estimate.credits_,
        checked_at=time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    )


job = client.wait_for_job(job_id, interval=5, timeout=1200, on_poll=on_poll)
if not job.result_url:
    raise RuntimeError("Completed Higgsfield 3D job has no result URL")

model_path = OUT_DIR / "echo-hero-hunyuan-v1.glb"
urllib.request.urlretrieve(job.result_url, model_path)
thumbnail_path = None
thumbnail_url = getattr(job, "thumbnail_url", None)
if isinstance(thumbnail_url, str) and thumbnail_url:
    thumbnail_path = OUT_DIR / "echo-hero-hunyuan-v1-preview.png"
    urllib.request.urlretrieve(thumbnail_url, thumbnail_path)

report(
    status="downloaded",
    job_id=job_id,
    estimated_credits=estimate.credits_,
    model=str(model_path),
    model_bytes=model_path.stat().st_size,
    thumbnail=str(thumbnail_path) if thumbnail_path else None,
)
