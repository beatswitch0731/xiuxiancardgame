"""Read-only Blender inventory for the isolated wearable prototype."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
paths = [
    ROOT / 'godot/assets/third_party/quaternius_ual_standard/AnimationLibrary_Godot_Standard.glb',
    ROOT / 'godot/assets/characters/actor_image3d_mvp/yelingyun_image3d_rig_candidate.glb',
]
report = []
for path in paths:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    entry = {'source': str(path), 'objects': [], 'actions': []}
    for obj in bpy.context.scene.objects:
        row = {'name': obj.name, 'type': obj.type, 'dimensions': list(obj.dimensions),
               'matrix': [list(r) for r in obj.matrix_world]}
        if obj.type == 'ARMATURE':
            row['bones'] = [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                             'head': list(b.head_local), 'tail': list(b.tail_local),
                             'matrix': [list(r) for r in b.matrix_local]} for b in obj.data.bones]
        if obj.type == 'MESH':
            row.update(vertices=len(obj.data.vertices), faces=len(obj.data.polygons),
                       materials=[m.name for m in obj.data.materials],
                       uvs=[u.name for u in obj.data.uv_layers])
        entry['objects'].append(row)
    for a in bpy.data.actions:
        entry['actions'].append({'name': a.name, 'frames': list(a.frame_range)})
    report.append(entry)
output = ROOT / 'artifacts/godot-migration/wearable-v2/source_inventory.json'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2), encoding='utf-8')
print('WEARABLE_SOURCE_INVENTORY', output)
