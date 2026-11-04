"""Read-only topology and skin audit for the isolated image-to-3D candidate."""

from collections import Counter
from pathlib import Path
import sys
import bpy

source = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
print("SKIN_AUDIT mesh_count", len(meshes), "armatures", len(armatures), flush=True)
for mesh in meshes:
    vertices = mesh.data.vertices
    parent = list(range(len(vertices)))

    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    first_by_position = {}
    for vertex in vertices:
        key = tuple(round(float(axis), 5) for axis in vertex.co)
        first = first_by_position.setdefault(key, vertex.index)
        parent[find(vertex.index)] = find(first)
    for edge in mesh.data.edges:
        a, b = map(int, edge.vertices)
        parent[find(a)] = find(b)
    components = Counter(find(index) for index in range(len(vertices)))
    no_weights = sum(not vertex.groups for vertex in vertices)
    top_groups = Counter()
    for vertex in vertices:
        if vertex.groups:
            strongest = max(vertex.groups, key=lambda entry: entry.weight)
            top_groups[mesh.vertex_groups[strongest.group].name] += 1
    print(
        "SKIN_AUDIT_MESH", mesh.name,
        "vertices", len(vertices), "triangles", len(mesh.data.polygons),
        "unique_positions", len(first_by_position),
        "welded_components", len(components), "largest", components.most_common(8),
        "zero_weight_vertices", no_weights,
        "dominant_groups", top_groups.most_common(12),
        flush=True,
    )
