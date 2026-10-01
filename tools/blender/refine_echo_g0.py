"""Create a non-destructive G0 Echo refinement candidate.

Focuses on the evidenced defects only: helper removal, material response,
outer coat-tail weighting, clean eye overlays, and a bounded runtime decimate.
The immutable Tripo 8K source is never modified.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--blend", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--decimate-ratio", type=float, default=0.79)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def mesh_triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def make_material(name, color, roughness, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    return mat


def tune_source_material(mesh):
    tuned = []
    for slot in mesh.material_slots:
        material = slot.material
        if material is None or not material.use_nodes:
            continue
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        # Preserve all Tripo maps. Scalars are conservative fallbacks; explicit
        # shader clamps improve Blender review without repainting the 8K source.
        # The source's maps carry good fabric-panel detail, but its material
        # response is much too wet under a cinematic key light. Keep the maps
        # and constrain only the physically implausible highlights.
        bsdf.inputs["Metallic"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 0.70
        for socket_name, value in (
            ("Specular IOR Level", 0.22),
            ("Coat Weight", 0.0),
            ("Sheen Weight", 0.0),
        ):
            socket = bsdf.inputs.get(socket_name)
            if socket is not None:
                socket.default_value = value
        roughness_input = bsdf.inputs["Roughness"]
        if roughness_input.is_linked:
            source = roughness_input.links[0].from_socket
            material.node_tree.links.remove(roughness_input.links[0])
            clamp = material.node_tree.nodes.new("ShaderNodeMath")
            clamp.name = "Echo_RoughnessFloor"
            clamp.operation = "MAXIMUM"
            clamp.inputs[1].default_value = 0.62
            material.node_tree.links.new(source, clamp.inputs[0])
            material.node_tree.links.new(clamp.outputs[0], roughness_input)
        metallic_input = bsdf.inputs["Metallic"]
        if metallic_input.is_linked:
            source = metallic_input.links[0].from_socket
            material.node_tree.links.remove(metallic_input.links[0])
            multiply = material.node_tree.nodes.new("ShaderNodeMath")
            multiply.name = "Echo_MetallicReduction"
            multiply.operation = "MULTIPLY"
            multiply.inputs[1].default_value = 0.05
            material.node_tree.links.new(source, multiply.inputs[0])
            material.node_tree.links.new(multiply.outputs[0], metallic_input)
        tuned.append(material.name)
    return tuned


def normalize_vertex_groups(mesh, vertex_index):
    assignments = []
    total = 0.0
    for group_element in mesh.data.vertices[vertex_index].groups:
        if group_element.weight > 0:
            assignments.append((group_element.group, group_element.weight))
            total += group_element.weight
    if total <= 1e-8:
        return
    for group_index, weight in assignments:
        mesh.vertex_groups[group_index].add([vertex_index], weight / total, "REPLACE")


def refine_coat_weights(mesh):
    names = {group.name: group for group in mesh.vertex_groups}
    needed = ("Pelvis", "Waist", "L_Thigh", "R_Thigh")
    if any(name not in names for name in needed):
        return {"adjusted": 0, "reason": "required groups missing"}

    bounds_z = [v.co.z for v in mesh.data.vertices]
    lo_z, hi_z = min(bounds_z), max(bounds_z)
    height = hi_z - lo_z
    adjusted = 0
    for vertex in mesh.data.vertices:
        normalized_z = (vertex.co.z - lo_z) / max(height, 1e-8)
        # Restrict correction to long outer coat panels. Central trousers and
        # torso deformation remain untouched.
        if not (0.12 <= normalized_z <= 0.58 and abs(vertex.co.x) >= 0.105):
            continue
        pelvis = 0.58
        waist = 0.12
        thigh_name = "L_Thigh" if vertex.co.x < 0 else "R_Thigh"
        opposite = "R_Thigh" if vertex.co.x < 0 else "L_Thigh"
        for name in needed:
            names[name].remove([vertex.index])
        names["Pelvis"].add([vertex.index], pelvis, "REPLACE")
        names["Waist"].add([vertex.index], waist, "REPLACE")
        names[thigh_name].add([vertex.index], 0.27, "REPLACE")
        names[opposite].add([vertex.index], 0.03, "REPLACE")
        normalize_vertex_groups(mesh, vertex.index)
        adjusted += 1
    return {"adjusted": adjusted, "reason": "outer-tail pelvis/thigh blend"}


def ray_eye_surface(mesh, x, z):
    # Mesh is close to origin and faces -Y in the imported Blender scene.
    origin = Vector((x, -1.0, z))
    hit, location, _normal, _face = mesh.ray_cast(origin, Vector((0.0, 1.0, 0.0)))
    return location if hit else Vector((x, -0.105, z))


def parent_to_head(obj, armature):
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = "Head"
    obj.matrix_world = world


def add_eye_layers(mesh, armature):
    xs = [v.co.x for v in mesh.data.vertices]
    zs = [v.co.z for v in mesh.data.vertices]
    min_x, max_x = min(xs), max(xs)
    min_z, max_z = min(zs), max(zs)
    center_x = (min_x + max_x) * 0.5
    height = max_z - min_z
    eye_z = min_z + height * 0.872
    eye_dx = (max_x - min_x) * 0.092
    white = make_material("M_Echo_EyeWhite", (0.82, 0.88, 0.92), 0.42)
    dark = make_material("M_Echo_Pupil", (0.004, 0.007, 0.012), 0.44)
    iris_mats = [
        make_material("M_Echo_IrisRed", (0.45, 0.006, 0.012), 0.40, emission=((1.0, 0.01, 0.015), 0.65)),
        make_material("M_Echo_IrisBlue", (0.004, 0.20, 0.55), 0.40, emission=((0.0, 0.42, 1.0), 0.70)),
    ]
    created = []
    for index, x in enumerate((center_x - eye_dx, center_x + eye_dx)):
        surface = ray_eye_surface(mesh, x, eye_z)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(surface.x, surface.y - 0.004, surface.z))
        sclera = bpy.context.object
        sclera.name = "EchoEyeSclera_L" if index == 0 else "EchoEyeSclera_R"
        sclera.scale = (0.0175, 0.0050, 0.0105)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        sclera.data.materials.append(white)
        parent_to_head(sclera, armature)
        created.append(sclera)

        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(surface.x, surface.y - 0.0092, surface.z))
        iris = bpy.context.object
        iris.name = "EchoIris_L_Red" if index == 0 else "EchoIris_R_Blue"
        iris.scale = (0.0064, 0.0017, 0.0064)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        iris.data.materials.append(iris_mats[index])
        parent_to_head(iris, armature)
        created.append(iris)

        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=(surface.x, surface.y - 0.0112, surface.z))
        pupil = bpy.context.object
        pupil.name = "EchoPupil_L" if index == 0 else "EchoPupil_R"
        pupil.scale = (0.0024, 0.0010, 0.0032)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        pupil.data.materials.append(dark)
        parent_to_head(pupil, armature)
        created.append(pupil)
    return created


def main():
    cfg = parse_args()
    source = Path(cfg.input).resolve()
    blend = Path(cfg.blend).resolve()
    output = Path(cfg.output).resolve()
    report_path = Path(cfg.report).resolve()
    for path in (blend.parent, output.parent, report_path.parent):
        path.mkdir(parents=True, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError("Echo armature missing")
    armature = armatures[0]
    weighted = [obj for obj in meshes if any(mod.type == "ARMATURE" for mod in obj.modifiers)]
    if not weighted:
        raise RuntimeError("Skinned Echo mesh missing")
    mesh = max(weighted, key=mesh_triangles)
    removed_helpers = []
    for obj in meshes:
        if obj != mesh:
            removed_helpers.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.context.scene.frame_set(1)
    tuned_materials = tune_source_material(mesh)
    coat_result = refine_coat_weights(mesh)
    eye_layers = add_eye_layers(mesh, armature)

    source_triangles = mesh_triangles(mesh)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    decimate = mesh.modifiers.new("G0_RuntimeBudget", "DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = cfg.decimate_ratio
    decimate.use_collapse_triangulate = True
    decimate.use_symmetry = True
    decimate.symmetry_axis = "X"
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    runtime_triangles = mesh_triangles(mesh) + sum(mesh_triangles(obj) for obj in eye_layers)

    for obj in [mesh, armature, *eye_layers]:
        obj["eleven_eleven_asset"] = "echo_g0_refinement"
        obj["eleven_eleven_status"] = "CANDIDATE_NOT_CANON_LOCK"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in [mesh, armature, *eye_layers]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(output), export_format="GLB", use_selection=True,
        export_animations=True, export_tangents=True, export_yup=True,
    )
    report = {
        "source": str(source), "blend": str(blend), "output": str(output),
        "removed_helpers": removed_helpers, "tuned_materials": tuned_materials,
        "coat_weight_correction": coat_result, "eye_layer_count": len(eye_layers),
        "body_triangles_before": source_triangles,
        "runtime_triangles_blender": runtime_triangles,
        "decimate_ratio": cfg.decimate_ratio,
        "bone_count": len(armature.data.bones),
        "actions": sorted(action.name for action in bpy.data.actions),
        "status": "REFINEMENT_CANDIDATE_REQUIRES_VISUAL_AND_DEFORMATION_GATE",
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("ECHO_G0_REFINEMENT=" + json.dumps(report), flush=True)


if __name__ == "__main__":
    main()
