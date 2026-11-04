"""Render geometry-only Hunyuan candidate from three views for visual QA."""

from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector


source = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
output = Path(sys.argv[sys.argv.index("--") + 2]).resolve()
output.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError("No mesh imported")
corners = [o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
minimum = Vector(tuple(min(v[i] for v in corners) for i in range(3)))
maximum = Vector(tuple(max(v[i] for v in corners) for i in range(3)))
center = (minimum + maximum) / 2
dimensions = maximum - minimum
print("IMAGE3D_BOUNDS", tuple(round(v, 3) for v in minimum),
      tuple(round(v, 3) for v in maximum), "MESHES", len(meshes), flush=True)

world = bpy.context.scene.world
world.color = (0.20, 0.20, 0.20)
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.31, .34, .36, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55

for name, location, energy, size in [
    ("Key", center + Vector((-2.6, -3.4, 4.0)), 850, 2.2),
    ("Rim", center + Vector((2.0, 2.1, 3.0)), 600, 2.8),
]:
    bpy.ops.object.light_add(type="AREA", location=location)
    light = bpy.context.object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = max(dimensions.z * 1.28, dimensions.x * 1.45)
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

distance = max(dimensions.z * 2.1, 3.0)
for label, angle in [("front", 0), ("side", math.pi / 2), ("back", math.pi)]:
    camera.location = center + Vector((distance * math.sin(angle),
                                       -distance * math.cos(angle),
                                       dimensions.z * .18))
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(output / f"yelingyun_shape_{label}.png")
    bpy.ops.render.render(write_still=True)
    print("IMAGE3D_RENDER", scene.render.filepath, flush=True)
