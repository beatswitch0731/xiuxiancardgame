"""Model a separate 3D equipment proxy from the traded sword illustration.

The image-to-3D sword generated a split, melted blade, so it was rejected.
This Blender mesh is a measured equipment/socket test, not final item art.
"""

from pathlib import Path
import sys
import bpy


output = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, metallic, roughness):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1)
    item.use_nodes = True
    shader = item.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return item


steel = material("OldSteel", (.39, .43, .43), .76, .35)
edge = material("WornEdge", (.68, .70, .66), .68, .30)
rust = material("PatchyRust", (.20, .13, .08), .44, .77)
bronze = material("OxidizedGuard", (.32, .23, .12), .58, .54)
leather = material("DarkGrip", (.17, .11, .075), .04, .83)

# A tapered diamond section reads as steel when lit from either side.
rings = [(-.075, .040, .011), (-.13, .047, .014),
         (-.52, .035, .012), (-.82, .019, .008), (-.94, .001, .001)]
verts = []
for z, half_width, half_thickness in rings:
    verts.extend([(-half_width, 0, z), (0, half_thickness, z),
                  (half_width, 0, z), (0, -half_thickness, z)])
faces = []
for index in range(len(rings) - 1):
    for face in range(4):
        a = index * 4 + face
        b = index * 4 + (face + 1) % 4
        faces.append((a, b, b + 4, a + 4))
faces.append((0, 3, 2, 1))
mesh = bpy.data.meshes.new("ForgedJianBladeMesh")
mesh.from_pydata(verts, [], faces)
mesh.materials.append(steel)
mesh.materials.append(edge)
mesh.materials.append(rust)
blade = bpy.data.objects.new("ForgedJianBlade", mesh)
bpy.context.collection.objects.link(blade)
for polygon in mesh.polygons:
    polygon.material_index = 1 if polygon.index % 4 in (0, 2) else 0


def bevel_cube(name, location, scale, mat, bevel_width=.005):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("SoftForgingEdges", "BEVEL")
    modifier.width = bevel_width
    modifier.segments = 2
    obj.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
    obj.data.materials.append(mat)
    return obj


bevel_cube("UnevenOldGuard", (0, 0, -.055), (.19, .038, .035), bronze, .009)
bevel_cube("BladeRootRust", (.009, -.013, -.145), (.027, .003, .041), rust, .003)
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.023, depth=.225,
                                    location=(0, 0, .09))
grip = bpy.context.object
grip.name = "WrappedDarkGrip"
grip.data.materials.append(leather)

for index in range(7):
    z = -.008 + index * .029
    bpy.ops.mesh.primitive_torus_add(major_segments=14, minor_segments=4,
                                    location=(0, 0, z),
                                    major_radius=.023, minor_radius=.003)
    obj = bpy.context.object
    obj.name = f"LeatherWrap_{index:02d}"
    obj.data.materials.append(bronze if index == 0 else leather)

bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6,
                                     radius=.036, location=(0, 0, .222))
pommel = bpy.context.object
pommel.name = "OldPommel"
pommel.scale.z = .55
pommel.data.materials.append(bronze)

output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                          export_materials="EXPORT")
print("IMAGE3D_SWORD_MODEL", output, flush=True)
