"""Experimental shared skeleton for the image-to-3D Ye Lingyun sculpt.

This rig probes whether the generated mesh can become a deforming actor. It
does not certify topology, skin weights, facial fidelity or production art.
"""

from pathlib import Path
import sys
import bpy
import numpy as np


source, destination = map(lambda p: Path(p).resolve(), sys.argv[sys.argv.index("--") + 1:])
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
actor = next(o for o in bpy.context.scene.objects if o.type == "MESH")
actor.name = "YeLingyunScannedSculpt"
# glTF splits triangle corners during colour export. Weld coincident positions
# before skinning so one sleeve seam does not become hundreds of loose islands.
bpy.context.view_layer.objects.active = actor
actor.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00001)
bpy.ops.object.mode_set(mode="OBJECT")
print("IMAGE3D_WELDED_VERTICES", len(actor.data.vertices), flush=True)

armature_data = bpy.data.armatures.new("YeLingyunSharedArmature")
armature = bpy.data.objects.new("YeLingyunRig", armature_data)
bpy.context.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")


def bone(name, head, tail, parent=None):
    item = armature_data.edit_bones.new(name)
    item.head = head
    item.tail = tail
    if parent:
        item.parent = armature_data.edit_bones[parent]
    return item


bone("root", (0, 0, -0.18), (0, 0, -0.05))
bone("pelvis", (0, 0, -0.13), (0, 0, 0.04), "root")
bone("spine", (0, 0, 0.03), (0, 0, 0.36), "pelvis")
bone("chest", (0, 0, 0.34), (0, 0, 0.54), "spine")
bone("neck", (0, 0, 0.53), (0, -0.005, 0.66), "chest")
bone("head", (0, -0.005, 0.65), (0, -0.01, 0.91), "neck")
for side, sign in (("L", 1), ("R", -1)):
    bone(f"clavicle_{side}", (0.09 * sign, 0, 0.48),
         (0.22 * sign, 0, 0.43), "chest")
    bone(f"upper_arm_{side}", (0.22 * sign, 0, 0.43),
         (0.35 * sign, 0, 0.13), f"clavicle_{side}")
    bone(f"forearm_{side}", (0.35 * sign, 0, 0.13),
         (0.43 * sign, 0, -0.14), f"upper_arm_{side}")
    bone(f"hand_{side}", (0.43 * sign, 0, -0.14),
         (0.45 * sign, -0.02, -0.25), f"forearm_{side}")
    bone(f"thigh_{side}", (0.125 * sign, 0, -0.16),
         (0.17 * sign, 0, -0.56), "pelvis")
    bone(f"shin_{side}", (0.17 * sign, 0, -0.56),
         (0.16 * sign, 0, -0.86), f"thigh_{side}")
    bone(f"foot_{side}", (0.16 * sign, 0, -0.86),
         (0.16 * sign, -0.13, -0.94), f"shin_{side}")
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="DESELECT")
actor.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
except RuntimeError as exc:
    print("IMAGE3D_AUTO_WEIGHT_FAILED", str(exc), flush=True)

weighted = sum(bool(vertex.groups) for vertex in actor.data.vertices)
print("IMAGE3D_AUTO_WEIGHT_COVERAGE", weighted, len(actor.data.vertices), flush=True)
if weighted < len(actor.data.vertices) * 0.99:
    # Bone heat cannot solve this sculpt's disconnected robe folds. A bounded
    # nearest-segment skin only proves that the model can drive a shared rig;
    # it is not deformation quality acceptable for combat animation.
    actor.vertex_groups.clear()
    bone_list = [item for item in armature_data.bones if item.name != "root"]
    groups = [actor.vertex_groups.new(name=item.name) for item in bone_list]
    verts = np.empty(len(actor.data.vertices) * 3, dtype=np.float32)
    actor.data.vertices.foreach_get("co", verts)
    verts = verts.reshape(-1, 3)
    scores = []
    for item in bone_list:
        head = np.array(item.head_local, dtype=np.float32)
        tail = np.array(item.tail_local, dtype=np.float32)
        direction = tail - head
        t = np.clip(((verts - head) @ direction) /
                    max(float(direction @ direction), 0.0001), 0, 1)
        distance = np.linalg.norm(verts - (head + t[:, None] * direction), axis=1)
        radius = 0.22 if item.name in ("pelvis", "spine", "chest") else 0.13
        scores.append(distance / radius)
    scores = np.stack(scores, axis=1)
    nearest = np.argpartition(scores, 3, axis=1)[:, :3]
    values = 1 / np.power(np.take_along_axis(scores, nearest, axis=1) + 0.12, 4)
    values /= values.sum(axis=1, keepdims=True)
    for vertex_index in range(len(verts)):
        for influence in range(3):
            groups[int(nearest[vertex_index, influence])].add(
                [vertex_index], float(values[vertex_index, influence]), "REPLACE"
            )
    method = "nearest_bone_diagnostic"
else:
    method = "automatic_bone_heat"

groups = [group.name for group in actor.vertex_groups]
if "hand_R" not in groups or not any(
    item.type == "ARMATURE" and item.object == armature for item in actor.modifiers
):
    raise RuntimeError("Generated actor lacks a usable weighted armature")

destination.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
actor.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(
    filepath=str(destination), export_format="GLB", use_selection=True,
    export_materials="EXPORT", export_skins=True,
)
print("IMAGE3D_RIGGED", destination, "bones", len(armature_data.bones),
      "vertices", len(actor.data.vertices), "method", method, flush=True)
