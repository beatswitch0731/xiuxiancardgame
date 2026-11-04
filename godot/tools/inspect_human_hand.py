import bpy
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
with bpy.data.libraries.load(str(ROOT/'.godot-toolchain/art-tools/human-base-meshes/human_base_meshes_bundle.blend')) as (source,target):
    print('ASSET_NAMES',source.objects)
    target.objects=[name for name in source.objects if 'hand' in name.lower() or name=='GEO-body_male_stylized']
for obj in target.objects:
    if obj is None or obj.type!='MESH':continue
    bpy.context.collection.objects.link(obj)
    v=np.array([list(v.co) for v in obj.data.vertices])
    print('HAND',obj.name,'verts',len(v),'min',v.min(axis=0),'max',v.max(axis=0),'matrix',obj.matrix_world)
    print('ASSET_METADATA',obj.asset_data.description if obj.asset_data else '',obj.asset_data.license if obj.asset_data else '')
    print('GROUPS',[g.name for g in obj.vertex_groups])
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'artifacts/godot-migration/wearable-v2/hand_sources.blend'))
