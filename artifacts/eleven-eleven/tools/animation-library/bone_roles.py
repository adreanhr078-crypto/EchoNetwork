"""Shared explicit humanoid aliases; roll/helper bones never become primary joints."""
import re


def normalize(name):
    name = name.rsplit(":", 1)[-1].lower()
    name = re.sub(r"^character\d+[_-]", "", name)
    name = re.sub(r"[^a-z0-9]", "", name)
    return name.removeprefix("mixamorig")


ALIASES = {
    "hips": ("hips", "hip", "pelvis", "bip001pelvis"),
    "head": ("head", "bip001head"),
    "left_foot": ("leftfoot", "lfoot", "footl", "bip001lfoot"),
    "right_foot": ("rightfoot", "rfoot", "footr", "bip001rfoot"),
    "left_toe": ("lefttoebase", "ltoe", "balll", "bip001ltoe0"),
    "right_toe": ("righttoebase", "rtoe", "ballr", "bip001rtoe0"),
    "left_knee": ("leftleg", "lcalf", "calfl", "bip001lcalf"),
    "right_knee": ("rightleg", "rcalf", "calfr", "bip001rcalf"),
    "left_thigh": ("leftupleg", "lthigh", "thighl", "bip001lthigh"),
    "right_thigh": ("rightupleg", "rthigh", "thighr", "bip001rthigh"),
}
CRITICAL_ROLES = {"hips", "head", "left_foot", "right_foot", "left_knee", "right_knee"}


def role(name):
    normalized = normalize(name)
    return next((key for key, names in ALIASES.items() if normalized in names), None)


def role_indices(names):
    result = {}
    for index, name in enumerate(names):
        key = role(name)
        if key:
            if key in result:
                raise ValueError(f"Ambiguous primary humanoid role: {key}")
            result[key] = index
    return result
