"""Run Higgsfield's official Blender device authorization flow headlessly.

Only non-secret, short-lived UI state is written to the status file. OAuth
tokens remain exclusively in the add-on's own persistent session storage.
"""

import contextlib
import json
import time
import webbrowser
from pathlib import Path

from bl_ext.user_default.higgsfield_blender.fnf.account import _auth_session_from_sdk
from bl_ext.user_default.higgsfield_blender.fnf.session import (
    DEVICE_AUTH_CLIENT_ID,
    DEVICE_AUTH_SCOPE,
    OAuthResponseError,
    _authorization_server,
    _normalize_oauth_token,
    _oauth_form_request,
    _save_oauth_token,
)


STATUS = Path(__file__).with_name("higgsfield-auth-status.json")


def report(**payload):
    STATUS.write_text(json.dumps(payload, indent=2), encoding="utf-8")


device_endpoint, token_endpoint = _authorization_server()
authorization = _oauth_form_request(
    device_endpoint,
    {"client_id": DEVICE_AUTH_CLIENT_ID, "scope": DEVICE_AUTH_SCOPE},
)
device_code = authorization.get("device_code")
user_code = authorization.get("user_code")
verification_url = authorization.get("verification_uri_complete") or authorization.get(
    "verification_uri"
)
if not device_code or not user_code or not verification_url:
    raise RuntimeError("Higgsfield device authorization response was incomplete")

report(status="waiting", verification_url=verification_url, user_code=user_code)
with contextlib.suppress(Exception):
    webbrowser.open(verification_url)

interval = float(authorization.get("interval") or 5)
expires_at = time.time() + float(authorization.get("expires_in") or 600)
while time.time() < expires_at:
    time.sleep(interval)
    try:
        data = _oauth_form_request(
            token_endpoint,
            {
                "client_id": DEVICE_AUTH_CLIENT_ID,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            },
        )
    except OAuthResponseError as error:
        oauth_error = error.body.get("error")
        if oauth_error == "authorization_pending":
            continue
        if oauth_error == "slow_down":
            interval = float(error.body.get("interval") or interval + 5)
            continue
        report(status="error", error=str(oauth_error or error))
        raise

    token = _normalize_oauth_token(data)
    if not token.get("access_token"):
        raise RuntimeError("Higgsfield OAuth response did not include an access token")
    _save_oauth_token(token)
    payload = _auth_session_from_sdk()
    balance = (payload or {}).get("balance") or {}
    report(
        status="authenticated",
        email=((payload or {}).get("user") or {}).get("email"),
        credits=balance.get("credits"),
        plan=balance.get("plan"),
    )
    break
else:
    report(status="expired")

