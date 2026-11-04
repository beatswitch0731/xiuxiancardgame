import bpy
import sys

if "--" in sys.argv:
    bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])

for obj in bpy.data.objects:
    if obj.type == 'ARMATURE':
        print('MVP_ARMATURE', obj.name, 'bones=', len(obj.data.bones))
        print('MVP_BONES', ','.join(b.name for b in obj.data.bones))
    elif obj.type == 'MESH':
        print('MVP_MESH', obj.name, 'verts=', len(obj.data.vertices),
              'groups=', len(obj.vertex_groups), 'materials=',
              ','.join(m.name for m in obj.data.materials if m))
        print('MVP_COLORS', [(a.name, a.domain, a.data_type) for a in obj.data.color_attributes])
        for material in obj.data.materials:
            if material and material.use_nodes:
                print('MVP_MATERIAL_NODES', material.name,
                      [(n.name, n.type) for n in material.node_tree.nodes],
                      [(l.from_node.name, l.to_node.name, l.to_socket.name)
                       for l in material.node_tree.links])
