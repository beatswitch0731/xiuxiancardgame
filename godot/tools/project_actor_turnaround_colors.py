"""Transfer reviewed turnaround colours onto a generated 3D candidate mesh.

This is a vertex-colour diagnostic, not a rig or approved production texture.
It samples front/back/left authored views by surface orientation. The resulting
GLB remains a real, lit triangle mesh and can be inspected from any camera.
"""

from pathlib import Path
import sys

import bpy
import numpy as np


argv = sys.argv[sys.argv.index("--") + 1:]
mesh_path, front_path, back_path, side_path, output_path = map(Path, argv)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(mesh_path.resolve()))
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
mesh = obj.data


def read_image(path):
    img = bpy.data.images.load(str(path.resolve()), check_existing=False)
    pixels = np.empty(img.size[0] * img.size[1] * 4, dtype=np.float32)
    img.pixels.foreach_get(pixels)
    # Blender pixel arrays begin at the bottom; supplied artwork is top-down.
    return pixels.reshape(img.size[1], img.size[0], 4)[::-1].copy()


front = read_image(front_path)
back = read_image(back_path)
side = read_image(side_path)
xyz = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
normals = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
mesh.vertices.foreach_get("co", xyz)
mesh.vertices.foreach_get("normal", normals)
xyz = xyz.reshape(-1, 3)
normals = normals.reshape(-1, 3)
minimum = xyz.min(axis=0)
maximum = xyz.max(axis=0)
span = np.maximum(maximum - minimum, 0.001)


def sample(image, bounds, x_fraction, z_fraction):
    x0, y0, x1, y1 = bounds
    ix = np.clip((x0 + x_fraction * (x1 - x0)).astype(np.int32), 0, image.shape[1] - 1)
    iy = np.clip((y0 + z_fraction * (y1 - y0)).astype(np.int32), 0, image.shape[0] - 1)
    return image[iy, ix]


height_fraction = (maximum[2] - xyz[:, 2]) / span[2]
width_fraction = (xyz[:, 0] - minimum[0]) / span[0]
depth_fraction = (maximum[1] - xyz[:, 1]) / span[1]
front_rgba = sample(front, (174, 61, 842, 1464), width_fraction, height_fraction)
back_rgba = sample(back, (181, 33, 831, 1470), 1 - width_fraction, height_fraction)
side_rgba = sample(side, (378, 38, 691, 1470), depth_fraction, height_fraction)

front_weight = np.maximum(-normals[:, 1], 0.0)
back_weight = np.maximum(normals[:, 1], 0.0)
side_weight = np.abs(normals[:, 0]) * 0.55
weights = np.stack([front_weight, back_weight, side_weight], axis=1)
weights *= np.stack([front_rgba[:, 3], back_rgba[:, 3], side_rgba[:, 3]], axis=1)
weights += 0.0001
weights /= weights.sum(axis=1, keepdims=True)
color = (front_rgba[:, :3] * weights[:, 0:1]
         + back_rgba[:, :3] * weights[:, 1:2]
         + side_rgba[:, :3] * weights[:, 2:3])
color = np.clip(color, 0.0, 1.0)
# Keep the indigo robe dark under the tutorial hall's warm key light. The old
# 0.84 gamma raised midtones and made the complete actor read as white clay.
color = np.power(color, 1.38)

attribute = mesh.color_attributes.get("TurnaroundColor")
if attribute is None:
    attribute = mesh.color_attributes.new(name="TurnaroundColor", type="FLOAT_COLOR", domain="POINT")
rgba = np.concatenate([color, np.ones((len(color), 1), dtype=np.float32)], axis=1)
attribute.data.foreach_set("color", rgba.ravel())
mesh.color_attributes.active_color = attribute

material = bpy.data.materials.new("YelingyunInkClothCandidate")
material.use_nodes = True
principled = material.node_tree.nodes.get("Principled BSDF")
principled.inputs["Roughness"].default_value = 0.88
attribute_node = material.node_tree.nodes.new("ShaderNodeVertexColor")
attribute_node.layer_name = "TurnaroundColor"
material.node_tree.links.new(attribute_node.outputs["Color"], principled.inputs["Base Color"])
mesh.materials.clear()
mesh.materials.append(material)

output_path.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=str(output_path.resolve()), export_format="GLB",
                          use_selection=True, export_materials="EXPORT")
print("IMAGE3D_COLOR_GLB", output_path.resolve(), "VERTICES", len(mesh.vertices),
      "MEAN_RGB", color.mean(axis=0).tolist(), flush=True)
