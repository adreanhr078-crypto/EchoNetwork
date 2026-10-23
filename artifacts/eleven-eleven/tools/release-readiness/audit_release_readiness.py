#!/usr/bin/env python3
"""11.11 release-readiness audit (read-only, no engine required).

Collects the facts a build/release decision needs, from the current checkout:

  * runtime character rig/animation inventory parsed straight out of the GLB files
  * audio + voice inventory
  * Git LFS completeness inside the Godot runtime and whether the missing
    binaries are actually referenced by runtime scenes/scripts
  * broken ``res://`` references
  * export presets: declared files, platform, Android permissions/versioning,
    local export-template availability
  * evidence/acceptance files present under ``audits/evidence``
  * entry-point routing (native vs web) and content/collection counts

It never edits the project, never touches Godot, and never imports assets.
Output is a JSON report plus a short Markdown summary.

Usage (from artifacts/eleven-eleven):
    python3 tools/release-readiness/audit_release_readiness.py \
        --json audits/release-readiness-20261023/baseline.json \
        --md   audits/release-readiness-20261023/baseline.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
import re
import shutil
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.path.join(ROOT, "godot")
LFS_MAGIC = b"version https://git-lfs.github.com/spec"
RES_RE = re.compile(r'res://([^"\'\)\s\],]+)')


# --------------------------------------------------------------------------- io
def read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except OSError:
        return ""


def walk(base: str, pattern: str):
    return [p for p in glob.glob(os.path.join(base, "**", pattern), recursive=True)
            if os.path.isfile(p)]


def rel(path: str) -> str:
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def is_lfs_pointer(path: str) -> bool:
    try:
        if os.path.getsize(path) > 300:
            return False
        with open(path, "rb") as fh:
            return fh.read(60).startswith(LFS_MAGIC)
    except OSError:
        return False


# ---------------------------------------------------------------------- GLB read
def glb_inventory(path: str) -> dict:
    info = {"file": rel(path), "mb": round(os.path.getsize(path) / 1e6, 2)}
    if is_lfs_pointer(path):
        info["status"] = "LFS_POINTER_ONLY"
        return info
    try:
        with open(path, "rb") as fh:
            data = fh.read()
        magic, _ver, length = struct.unpack("<III", data[:12])
        if magic != 0x46546C67:
            info["status"] = "NOT_GLB"
            return info
        off, doc = 12, None
        while off < length:
            clen, ctype = struct.unpack("<II", data[off:off + 8])
            off += 8
            chunk = data[off:off + clen]
            off += clen
            if ctype == 0x4E4F534A:
                doc = json.loads(chunk.decode("utf-8"))
        if doc is None:
            info["status"] = "NO_JSON_CHUNK"
            return info
    except Exception as exc:  # noqa: BLE001 - report, never crash the audit
        info["status"] = f"PARSE_ERROR:{type(exc).__name__}"
        return info

    nodes = doc.get("nodes", [])
    skins = doc.get("skins", [])
    meshes = doc.get("meshes", [])
    joints = []
    if skins:
        joints = [nodes[i].get("name", "") for i in skins[0].get("joints", []) if i < len(nodes)]
    finger_names = [j for j in joints if re.search(r"(Index|Middle|Ring|Pinky|Thumb)", j)]
    face_names = [j for j in joints if re.search(r"(?i)(eye|jaw|brow|lid|lip|face|mouth)", j)]
    info.update({
        "status": "OK",
        "nodes": len(nodes),
        "meshes": len(meshes),
        "primitives": sum(len(m.get("primitives", [])) for m in meshes),
        "materials": len(doc.get("materials", [])),
        "joints": max((len(s.get("joints", [])) for s in skins), default=0),
        "finger_joints": len(finger_names),
        "face_joints": len(face_names),
        "morph_targets": sum(len(p.get("targets", []))
                             for m in meshes for p in m.get("primitives", [])),
        "animations": [a.get("name") for a in doc.get("animations", [])],
    })
    return info


# ------------------------------------------------------------------- export cfg
def parse_export_presets(path: str) -> list[dict]:
    presets, current, section = [], None, None
    for raw in read_text(path).splitlines():
        line = raw.strip()
        if line.startswith("[preset.") and not line.startswith("[preset.0.options]"):
            if re.fullmatch(r"\[preset\.\d+\]", line):
                current = {"index": int(line.split(".")[1].rstrip("]"))}
                presets.append(current)
                section = "preset"
                continue
        if line.startswith("[preset.") and line.endswith(".options]"):
            section = "options"
            continue
        if current is None or "=" not in line:
            continue
        key, value = line.split("=", 1)
        store = current if section == "preset" else current.setdefault("options", {})
        store[key.strip()] = value.strip().strip('"')
    return presets


def parse_array(value: str) -> list[str]:
    inner = value[value.find("(") + 1:value.rfind(")")] if "(" in value else ""
    return [p.strip().strip('"') for p in inner.split(",") if p.strip()]


def export_templates_present() -> dict:
    candidates = [
        os.path.expanduser("~/.local/share/godot/export_templates"),
        os.path.expanduser("~/Library/Application Support/Godot/export_templates"),
        os.path.join(os.environ.get("APPDATA", ""), "Godot", "export_templates"),
    ]
    found = [p for p in candidates if p and os.path.isdir(p)]
    versions = []
    for base in found:
        versions += sorted(os.listdir(base))
    return {"searched": candidates, "found_dirs": found, "versions": versions}


# ---------------------------------------------------------------------- checks
def check_characters() -> dict:
    cast = {
        "Echo (player)": "godot/assets/characters/echo_v31_adopted_high.glb",
        "Kinja (antagonist)": "godot/assets/characters/kinja_revenge_rig_v1.glb",
        "Zero (contract entity)": "godot/assets/characters/zero_manifestation_idle_v1.glb",
    }
    out = {}
    for label, path in cast.items():
        full = os.path.join(ROOT, path)
        out[label] = glb_inventory(full) if os.path.exists(full) else {"file": path, "status": "MISSING"}
    return out


def check_runtime_animations() -> dict:
    files = sorted(walk(os.path.join(GODOT, "assets", "animations"), "*.res"))
    stems = [rel(f).split("assets/animations/")[-1] for f in files]
    names = {s.lower() for s in stems}
    required = {
        "walk": ["walk"],
        "idle": ["idle"],
        "run": ["run", "jog"],
        "jump": ["jump"],
        "wake_getup": ["wake", "getup", "stand_up", "rise"],
        "attack": ["attack", "slash", "strike"],
        "dodge": ["dodge", "roll", "evade"],
        "climb": ["climb", "mantle"],
        "hit_reaction": ["hit", "impact"],
        "interact_hand": ["interact", "press", "touch"],
    }
    found, missing = {}, []
    for need, keys in required.items():
        hit = [s for s in stems if any(k in s.lower() for k in keys)]
        found[need] = hit
        if not hit:
            missing.append(need)
    return {"count": len(stems), "files": stems, "coverage": found, "missing": missing}


def check_audio() -> dict:
    audio = [p for p in walk(os.path.join(GODOT, "assets"), "*.ogg") + walk(os.path.join(GODOT, "assets"), "*.wav")]
    size = sum(os.path.getsize(p) for p in audio)
    voice = [p for p in audio if re.search(r"(?i)(voice|vo_|dialogue|line_|jp_)", os.path.basename(p))]
    return {"files": len(audio), "mb": round(size / 1e6, 2),
            "voice_files": len(voice), "names": sorted(os.path.basename(p) for p in audio)}


def check_lfs() -> dict:
    runtime = [f for f in walk(os.path.join(GODOT, "assets"), "*") if is_lfs_pointer(f)]
    all_ptr = 0
    for f in walk(os.path.join(ROOT, "artifacts"), "*"):
        if is_lfs_pointer(f):
            all_ptr += 1
    text = ""
    for pattern in ("*.tscn", "*.tres", "*.gd"):
        for f in walk(os.path.join(GODOT), pattern):
            text += read_text(f)
    referenced = []
    for pointer in runtime:
        res_path = "res://" + rel(pointer).split("godot/", 1)[-1]
        if res_path in text:
            referenced.append({"asset": rel(pointer), "referenced": True})
    return {
        "runtime_pointers": len(runtime),
        "runtime_pointer_files": [rel(p) for p in runtime],
        "runtime_pointers_referenced_by_runtime": referenced,
        "artifacts_pointers_sample_count": all_ptr,
        "git_lfs_installed": bool(shutil.which("git-lfs")),
    }


def check_res_references() -> dict:
    refs: dict[str, set[str]] = {}
    for pattern in ("*.gd", "*.tscn"):
        for path in walk(GODOT, pattern):
            for match in RES_RE.finditer(read_text(path)):
                refs.setdefault(match.group(1), set()).add(rel(path))
    skip = ("%s", "%d", "../audits", "addons/", "dev_scenes/")
    asset_ext = (".tscn", ".gd", ".res", ".tres", ".glb", ".gltf", ".png", ".jpg", ".webp",
                 ".ogg", ".wav", ".ogv", ".json", ".ttf", ".gdshader", ".import", ".uid")
    missing = {}
    for target, users in refs.items():
        if any(s in target for s in skip):
            continue
        if not target.lower().endswith(asset_ext):
            # format-string fragments and dev scratch names, not real dependencies
            continue
        full = os.path.join(GODOT, target)
        if os.path.exists(full) or os.path.exists(full + ".import") or os.path.exists(full + ".uid"):
            continue
        missing[target] = sorted(users)[:5]
    return {"references": len(refs), "missing": missing, "missing_count": len(missing)}


def check_export_presets() -> dict:
    path = os.path.join(GODOT, "export_presets.cfg")
    presets = parse_export_presets(path) if os.path.exists(path) else []
    out = []
    for preset in presets:
        declared = parse_array(preset.get("export_files", ""))
        missing = [f for f in declared if not os.path.exists(os.path.join(GODOT, f.replace("res://", "")))]
        entry = {
            "name": preset.get("name"),
            "platform": preset.get("platform"),
            "export_path": preset.get("export_path"),
            "declared_files": len(declared),
            "declared_missing": missing[:10],
            "declared_missing_count": len(missing),
            "encrypt_pck": preset.get("encrypt_pck"),
            "options": preset.get("options", {}),
        }
        if preset.get("platform") == "Android":
            entry["android_gate"] = {
                "internet_permission": preset.get("options", {}).get("permissions/internet"),
                "gradle_build": preset.get("options", {}).get("gradle_build/use_gradle_build"),
                "version_name": preset.get("options", {}).get("version/name"),
                "version_code": preset.get("options", {}).get("version/code"),
                "package": preset.get("options", {}).get("package/unique_name"),
                "architectures": {k: v for k, v in preset.get("options", {}).items()
                                  if k.startswith("architectures/")},
                "has_aab_hint": "aab" in (preset.get("export_path") or "").lower(),
            }
        out.append(entry)
    return {"file_exists": os.path.exists(path), "presets": out,
            "templates": export_templates_present()}


def check_evidence() -> dict:
    base = os.path.join(ROOT, "audits", "evidence")
    items = []
    for path in walk(base, "*.json"):
        if not re.search(r"(verification|final|gate|readiness|diagnosis)", os.path.basename(path), re.I):
            continue
        match = re.search(r"(20\d{2}-?\d{2}-?\d{2})", rel(path))
        items.append({
            "file": rel(path),
            "date": match.group(1) if match else None,
            "local_content": "LFS_POINTER" if is_lfs_pointer(path) else "PRESENT",
            "kb": round(os.path.getsize(path) / 1024, 1),
        })
    items.sort(key=lambda x: (x["date"] or "", x["file"]))
    return {
        "count": len(items),
        "local_pointer_count": sum(1 for i in items if i["local_content"] == "LFS_POINTER"),
        "latest": items[-12:],
    }


def check_entry_and_content() -> dict:
    boot = read_text(os.path.join(GODOT, "scripts", "boot.gd"))
    routes = []
    if "native_journey" in boot:
        routes.append("native_journey.tscn")
    if "opening_web_room" in boot:
        routes.append("opening_web_room.tscn")
    collections = {}
    for name in ("chapters", "puzzles", "memories", "dialogues", "endings", "cinematics"):
        path = os.path.join(ROOT, "data", name, "index.json")
        if not os.path.exists(path):
            collections[name] = None
            continue
        try:
            items = json.load(open(path, encoding="utf-8")).get("items")
            collections[name] = len(items) if hasattr(items, "__len__") else None
        except Exception:  # noqa: BLE001
            collections[name] = "PARSE_ERROR"
    return {
        "boot_routes": routes,
        "godot_scenes": len(walk(os.path.join(GODOT, "scenes"), "*.tscn")),
        "godot_scripts": len(walk(os.path.join(GODOT, "scripts"), "*.gd")),
        "godot_tests": len([p for p in walk(os.path.join(GODOT, "tests"), "*.gd")]),
        "web_test_files": len(walk(os.path.join(ROOT, "src", "__tests__"), "*.test.ts")),
        "e2e_specs": len(walk(os.path.join(ROOT, "e2e"), "*.spec.ts")),
        "content_collections": collections,
    }


def check_environment() -> dict:
    godot = shutil.which("godot") or shutil.which("godot4") or shutil.which("godot4.8")
    blender = shutil.which("blender")
    bpy = None
    try:
        import importlib.util
        bpy = importlib.util.find_spec("bpy") is not None
    except Exception:  # noqa: BLE001
        bpy = False
    import_cache = os.path.join(GODOT, ".godot")
    templates = export_templates_present()
    return {
        "godot_binary": godot,
        "blender_binary": blender,
        "bpy_module": bool(bpy),
        "godot_import_cache": os.path.isdir(import_cache),
        "export_templates_installed": bool(templates["versions"]),
        "export_template_versions": templates["versions"],
        "python": sys.version.split()[0],
        "node": (shutil.which("node") or ""),
        "cpu_count": os.cpu_count(),
    }


# ------------------------------------------------------------------------ main
def main() -> int:
    ap = argparse.ArgumentParser(description="11.11 release-readiness audit (read-only)")
    ap.add_argument("--json", help="write JSON report to this path")
    ap.add_argument("--md", help="write Markdown summary to this path")
    args = ap.parse_args()

    report = {
        "generated": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "project_root": ROOT,
        "source_commit": subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                                        capture_output=True, text=True).stdout.strip(),
        "environment": check_environment(),
        "characters": check_characters(),
        "runtime_animations": check_runtime_animations(),
        "audio": check_audio(),
        "lfs": check_lfs(),
        "res_references": check_res_references(),
        "export": check_export_presets(),
        "evidence": check_evidence(),
        "entry_and_content": check_entry_and_content(),
    }

    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=2)

    env = report["environment"]
    chars = report["characters"]
    anim = report["runtime_animations"]
    audio = report["audio"]
    lfs = report["lfs"]
    exp = report["export"]
    entry = report["entry_and_content"]

    lines = [
        "# تدقيق جاهزية الإصدار — 11.11",
        "",
        f"_أُنتج آليًا: {report['generated']} · commit `{report['source_commit']}`_",
        "",
        "## البيئة الحالية",
        "",
        f"- Godot: `{env['godot_binary'] or 'غير مثبت'}` · Blender: `{env['blender_binary'] or 'غير مثبت'}`"
        f" · bpy: `{'نعم' if env['bpy_module'] else 'لا'}`",
        f"- كاش استيراد Godot: `{'موجود' if env['godot_import_cache'] else 'غير موجود'}`"
        f" · قوالب التصدير: `{env['export_template_versions'] or 'غير مثبتة'}`",
        f"- المعالج/الذاكرة المتاحة للأداء: {env['cpu_count']} نواة",
        "",
        "## الشخصيات (قراءة GLB مباشرة)",
        "",
        "| الشخصية | الحالة | مفاصل | أصابع | وجه/فك | Morph | حركات داخل الملف |",
        "|---|---|---|---|---|---|---|",
    ]
    for name, info in chars.items():
        if info.get("status") != "OK":
            lines.append(f"| {name} | {info.get('status')} | - | - | - | - | - |")
            continue
        lines.append(
            f"| {name} | OK | {info['joints']} | {info['finger_joints']} | {info['face_joints']} | "
            f"{info['morph_targets']} | {len(info['animations'])} |")

    lines += [
        "",
        "## تغطية الحركة في runtime",
        "",
        f"- ملفات الحركة: {anim['count']} · المفقود: {', '.join(anim['missing']) or 'لا شيء'}",
        "",
        "## الصوت",
        "",
        f"- ملفات: {audio['files']} ({audio['mb']} MB) · ملفات صوت شخصيات: {audio['voice_files']}",
        "",
        "## Git LFS",
        "",
        f"- أصول runtime غير موجودة فعليًا: {lfs['runtime_pointers']}"
        f" · منها مستخدمة فعليًا: {len(lfs['runtime_pointers_referenced_by_runtime'])}",
        f"- أداة git-lfs مثبتة: {'نعم' if lfs['git_lfs_installed'] else 'لا'}",
        "",
        "## التصدير",
        "",
        f"- `export_presets.cfg`: {'موجود' if exp['file_exists'] else 'مفقود'} · عدد presets: {len(exp['presets'])}",
    ]
    for preset in exp["presets"]:
        lines.append(f"- **{preset['name']}** ({preset['platform']}) → `{preset['export_path']}`"
                     f" · ملفات معلنة مفقودة: {preset['declared_missing_count']}")
        if "android_gate" in preset:
            gate = preset["android_gate"]
            lines.append(f"  - Android: internet={gate['internet_permission']},"
                         f" gradle={gate['gradle_build']}, version={gate['version_name']}"
                         f" ({gate['version_code']}), package={gate['package']}, AAB={gate['has_aab_hint']}")

    lines += [
        "",
        "## نقطة الدخول والمحتوى",
        "",
        f"- مسارات boot: {', '.join(entry['boot_routes']) or 'غير معروفة'}",
        f"- مشاهد Godot: {entry['godot_scenes']} · سكربتات: {entry['godot_scripts']}"
        f" · فحوص Godot: {entry['godot_tests']} · فحوص ويب: {entry['web_test_files']}"
        f" · e2e: {entry['e2e_specs']}",
        f"- مجموعات المحتوى في `data/`: {entry['content_collections']}",
        "",
        "## الأدلة",
        "",
        f"- ملفات دليل/تحقق: {report['evidence']['count']}"
        f" · منها غير موجود محليًا (LFS): {report['evidence']['local_pointer_count']}"
        f" (أحدث 12 في تقرير JSON)",
        "",
        "_هذا الملف يقيس الحالة فقط؛ لا يمنح PASS لأي بوابة._",
        "",
    ]
    if args.md:
        os.makedirs(os.path.dirname(os.path.abspath(args.md)), exist_ok=True)
        with open(args.md, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))

    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
