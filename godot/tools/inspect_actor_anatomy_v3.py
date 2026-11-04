import bpy, json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/'.godot-toolchain/art-tools/human-base-meshes/human_base_meshes_bundle.blend')) as (src,dst):
    dst.objects=['GEO-body_male_stylized']
o=dst.objects[0]
bpy.context.collection.objects.link(o)
v=np.array([tuple(v.co) for v in o.data.vertices])
for z in np.arange(.75,1.55,.05):
    row=v[(abs(v[:,2]-z)<.025)&(v[:,0]>.22)]
    if len(row):print('ARM_SLICE',round(z,3),len(row),row.min(axis=0).round(4).tolist(),row.max(axis=0).round(4).tolist())
# Inspect source hand/arm topology before choosing a cut and joint fit.
o.animation_data_clear()
for m in list(o.modifiers):o.modifiers.remove(m)
mat=bpy.data.materials.new('Clay');mat.diffuse_color=(.55,.55,.55,1);o.data.materials.clear();o.data.materials.append(mat)
bpy.ops.object.camera_add(location=(0,-4,1.1));cam=bpy.context.object
from mathutils import Vector
cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=2.1;bpy.context.scene.camera=cam
bpy.context.scene.render.engine='BLENDER_WORKBENCH'
bpy.context.scene.display.shading.light='STUDIO'
bpy.context.scene.display.shading.color_type='MATERIAL'
bpy.context.scene.render.resolution_x=900;bpy.context.scene.render.resolution_y=900
bpy.context.scene.render.filepath=str(ROOT/'artifacts/godot-migration/wearable-v2/donor_anatomy.png')
bpy.ops.render.render(write_still=True)
