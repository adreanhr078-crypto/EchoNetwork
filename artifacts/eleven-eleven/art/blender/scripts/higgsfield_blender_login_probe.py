"""Start Higgsfield's official Blender device login and report safe status only."""

import time

from bl_ext.user_default.higgsfield_blender.fnf.account import auth_state, is_authenticated, start_auth_login


start_auth_login()
reported = False
for _ in range(240):
    url = auth_state.get("verification_url")
    code = auth_state.get("user_code")
    if url and not reported:
        print("HF_VERIFICATION_URL=" + str(url), flush=True)
        print("HF_USER_CODE=" + str(code or ""), flush=True)
        reported = True
    status = auth_state.get("status")
    if is_authenticated():
        print("HF_LOGIN_OK=1", flush=True)
        break
    if status == "error":
        print("HF_LOGIN_ERROR=" + str(auth_state.get("error")), flush=True)
        break
    time.sleep(1)
else:
    print("HF_LOGIN_TIMEOUT=1", flush=True)
