"""Author the residual sword and scabbard at a consistent grip origin."""
from pathlib import Path
import math
import bpy

OUT=Path(__file__).resolve().parents[1]/'assets/characters/actor_wearable_v2'
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name,color,metal=0,rough=.7):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m

steel=mat('Tempered_steel',(.28,.32,.33),.8,.35)
edge=mat('Sharpened_edge',(.56,.58,.55),.85,.25)
brass=mat('Aged_brass',(.28,.19,.08),.7,.45)
wrap=mat('Indigo_grip',(.028,.047,.054),0,.9)
wood=mat('Scabbard_lacquer',(.058,.025,.015),0,.56)

def mesh(name,verts,faces,material):
    d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);d.materials.append(material)
    return o

def bar(name,zs,widths,depth,material):
    v=[];f=[]
    for z,w in zip(zs,widths):v.extend([(-w,0,z),(0,-depth,z),(w,0,z),(0,depth,z)])
    for j in range(len(zs)-1):
        for i in range(4):a=j*4+i;f.append((a,j*4+(i+1)%4,(j+1)*4+(i+1)%4,a+4))
    f.extend([(3,2,1,0),tuple(range(len(v)-4,len(v)))])
    return mesh(name,v,f,material)

def cylinder(name,radius,depth,z,material,vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(0,0,z))
    o=bpy.context.object;o.name=name;o.data.materials.append(material)
    return o

blade=bar('Blade',[.09,.15,.65,.81,.88],[.022,.029,.023,.018,.0005],.006,steel)
blade.data.materials.append(edge)
for f in blade.data.polygons:
    if f.index%4 in [1,2]:f.material_index=1
bar('Quillon',[.073,.086,.10],[.095,.103,.080],.013,brass)
cylinder('Grip',.019,.16,-.007,wrap)
cylinder('Pommel',.027,.027,-.102,brass)
for i in range(8):
    cylinder('Grip_binding',.020,.005,-.075+i*.019,brass)
bpy.ops.export_scene.gltf(filepath=str(OUT/'traded_rusted_sword_v2.glb'),export_format='GLB',export_animations=False)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bar('Scabbard',[.085,.12,.69,.87,.90],[.033,.034,.028,.023,.015],.018,wood)
for z in [.11,.22,.78,.87]:
    bar('Scabbard_fitting',[z-.011,z+.011],[.035 if z<.5 else .027]*2,.019,brass)
bpy.ops.export_scene.gltf(filepath=str(OUT/'residual_scabbard_v2.glb'),export_format='GLB',export_animations=False)
print('WEARABLE_SWORD_BUILT')
