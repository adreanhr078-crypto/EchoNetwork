"""
Kimi K3 Autonomous Agent Runner for 11.11 - Echo Network
Model: moonshotai/kimi-k3 via NVIDIA NIM API
Streaming: text/event-stream (SSE)
"""

import sys
import json
import urllib.request
import ssl
import os

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

API_KEY = os.environ.get("NVIDIA_API_KEY", "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")
API_URL = "https://integrate.api.nvidia.com/v1/chat/completions"
MODEL = "moonshotai/kimi-k3"

def load_system_prompt():
    prompt_path = os.path.join(os.path.dirname(__file__), "MASTER_PROMPT_KIMI_K3.md")
    if os.path.exists(prompt_path):
        with open(prompt_path, "r", encoding="utf-8") as f:
            return f.read()
    return "You are Kimi K3, Executive Game Director and Lead Autonomous Engineer for 11.11 - Echo Network."

def stream_kimi(user_instruction: str):
    system_prompt = load_system_prompt()
    
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_instruction}
        ],
        "max_tokens": 16384,
        "temperature": 1,
        "stream": True,
        "reasoning_effort": "max"
    }

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "text/event-stream"
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(API_URL, data=data, headers=headers, method="POST")
    ctx = ssl.create_default_context()

    print("\n" + "="*60)
    print("🚀 [11.11] Kimi K3 Autonomous Director is Thinking & Planning...")
    print("="*60 + "\n", flush=True)

    in_reasoning = True

    try:
        with urllib.request.urlopen(req, context=ctx, timeout=300) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8").strip()
                if not line or not line.startswith("data:"):
                    continue
                
                content_str = line[5:].strip()
                if content_str == "[DONE]":
                    print("\n\n" + "="*60)
                    print("✅ [11.11] Kimi K3 Stream Complete.")
                    print("="*60 + "\n", flush=True)
                    break

                try:
                    chunk = json.loads(content_str)
                    choices = chunk.get("choices", [])
                    if not choices:
                        continue
                    
                    delta = choices[0].get("delta", {})
                    reasoning = delta.get("reasoning_content")
                    content = delta.get("content")

                    if reasoning:
                        if not in_reasoning:
                            in_reasoning = True
                            sys.stdout.write("\n\n🧠 [التفكير العميق / Reasoning]:\n")
                        sys.stdout.write(reasoning)
                        sys.stdout.flush()

                    if content:
                        if in_reasoning:
                            in_reasoning = False
                            sys.stdout.write("\n\n📋 [خطة وتنفيذ كيمي ك3 / Kimi Output]:\n")
                        sys.stdout.write(content)
                        sys.stdout.flush()

                except json.JSONDecodeError:
                    continue

    except Exception as e:
        print(f"\n❌ Error connecting to Kimi K3: {e}", file=sys.stderr)

if __name__ == "__main__":
    query = " " .join(sys.argv[1:]) if len(sys.argv) > 1 else "أنت الآن المستلم الفعلي لإدارة وتطوير مشروع 11.11 Echo Network. افحص المشروع، حدد موقع العمل الحالي، واعرض خطتك التنفيذية الدقيقة وابدأ العمل."
    stream_kimi(query)
