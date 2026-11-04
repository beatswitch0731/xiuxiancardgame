"""Build an isolated fitted-garment prototype on the native CC0 UAL rig.

The existing multiview sculpt is a surface/identity source. Anatomical parts
are fitted separately, with explicit influence domains. CC0 Blender human
hands replace the rig's mechanical mannequin. This is an anatomical prototype.
"""
from pathlib import Path
import json
import math
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/actor_wearable_v2'
SOURCE = ROOT / 'godot/art_source/actor_image3d_mvp'
WORK = ROOT / 'godot/art_source/actor_wearable_v2'
OUT.mkdir(parents=True, exist_ok=True)
WORK.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'godot/assets/third_party/quaternius_ual_standard/AnimationLibrary_Godot_Standard.glb'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
rig.name = 'YelingyunNativeRig'
native = bpy.data.objects['Mannequin']
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
native_positions = np.array([list(v.co) for v in native.data.vertices])
native_weights = [{native.vertex_groups[g.group].name: g.weight for g in v.groups}
                  for v in native.data.vertices]
tree = KDTree(len(native_positions))
for i, p in enumerate(native_positions):
    tree.insert(p, i)
tree.balance()
keep_actions = {'Idle_Loop', 'Sword_Idle', 'Sword_Attack', 'Crouch_Idle_Loop', 'Walk_Loop', 'Hit_Chest'}
for track in list(rig.animation_data.nla_tracks):
    if not any(s.action and s.action.name in keep_actions for s in track.strips):
        rig.animation_data.nla_tracks.remove(track)
    else:
        track.mute = False
for a in list(bpy.data.actions):
    if a.name not in keep_actions:
        bpy.data.actions.remove(a)
for obj in list(bpy.context.scene.objects):
    if obj not in (rig, native):
        bpy.data.objects.remove(obj, do_unlink=True)
for track in rig.animation_data.nla_tracks:
    track.mute = True


def material(name, rgb, roughness=0.7, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*rgb, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metallic
    return mat


skin_mat = material('Skin_warm_ochre', (0.48, 0.275, 0.15), 0.83)
cloth_mat = material('Indigo_weave', (.065, .085, .105), .90)
linen_mat = material('Linen_weave', (.38, .34, .265), .94)
collar_mat = material('Charcoal_collar', (.055, .048, .039), .91)
wrap_mat = material('Leg_wrap_linen', (.42, .38, .30), .94)
seam_mat = material('Cloth_seam_indigo', (.037, .048, .065), .92)
iron = material('XuanTie_blued_iron', (0.065, 0.082, 0.081), 0.64, 0.60)
edge = material('XuanTie_worn_edges', (0.24, 0.27, 0.25), 0.45, 0.65)
bronze = material('Muted_brass_fittings', (0.31, 0.22, 0.095), 0.42, 0.7)
leather = material('Oxide_leather', (0.075, 0.035, 0.025), 0.88)
blade_mat = material('Residual_sword_steel', (0.29, 0.34, 0.35), 0.34, 0.82)
blade_edge = material('Residual_sword_edge', (0.48, 0.51, 0.48), 0.28, 0.85)


def bind(obj, weights):
    obj.parent = rig
    mod = obj.modifiers.new('Shared_native_deform', 'ARMATURE')
    mod.object = rig
    # Linear skinning matches the game exporter; no Blender-only DQ claim.
    mod.use_deform_preserve_volume = False
    group_names = set(k for w in weights for k in w)
    groups = {name: obj.vertex_groups.new(name=name) for name in group_names}
    for i, w in enumerate(weights):
        total = sum(w.values())
        for k, value in w.items():
            if value > 0.0001:
                groups[k].add([i], value / total, 'REPLACE')


def nearest_weights(p, allowed=None):
    weights = {}
    for _, idx, distance in tree.find_n(p, 4):
        factor = 1.0 / max(distance, 0.005) ** 2
        for name, w in native_weights[idx].items():
            if allowed is None or name in allowed:
                weights[name] = weights.get(name, 0) + w * factor
    if not weights:
        return {next(iter(allowed)) if allowed else 'DEF-spine.002': 1.0}
    result = dict(sorted(weights.items(), key=lambda x: -x[1])[:4])
    total = sum(result.values())
    return {k: v / total for k, v in result.items()}


def new_mesh(name, vertices, faces, mat, weights=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    if mat:
        data.materials.append(mat)
    for p in data.polygons:
        p.use_smooth = True
    if weights is not None:
        bind(obj, weights)
    return obj


# Retain only the neck under the collar. The source animation mannequin's
# segmented mechanical hands must not appear on the human character.
selected = []
for face in native.data.polygons:
    coords = native_positions[list(face.vertices)]
    if (
            np.all(coords[:, 2] > 1.46) and np.all(coords[:, 2] < 1.585)
            and np.all(np.abs(coords[:, 0]) < .105)):
        selected.append(list(face.vertices))
used = sorted({i for face in selected for i in face})
remap = {old: new for new, old in enumerate(used)}
neck = new_mesh('Body_neck', [native_positions[i] for i in used],
                 [[remap[i] for i in f] for f in selected], skin_mat,
                 [native_weights[i] for i in used])
bpy.data.objects.remove(native, do_unlink=True)

# Official Blender CC0 human mesh: continuous palm, thumb web and fingers.
# The donor wrist includes a short forearm extension under the sleeve mesh.
human_bundle = ROOT/'.godot-toolchain/art-tools/human-base-meshes/human_base_meshes_bundle.blend'
with bpy.data.libraries.load(str(human_bundle)) as (source, target):
    target.objects = ['Hand  - Realistic']
donor = target.objects[0]
bpy.context.collection.objects.link(donor)
donor.animation_data_clear()
for mod in list(donor.modifiers):
    donor.modifiers.remove(mod)
sub = donor.modifiers.new('Anatomical_surface', 'SUBSURF')
sub.levels = 1
bpy.context.view_layer.objects.active = donor
bpy.ops.object.modifier_apply(modifier=sub.name)
# Continue the donor's actual wrist boundary into an anatomical forearm.
# This keeps the hand/wrist continuous instead of intersecting two tubes.
bm = bmesh.new()
bm.from_mesh(donor.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                      dist=.00001,plane_co=(0,0,.045),plane_no=(0,0,1),
                      clear_outer=True,clear_inner=False)
boundary = [e for e in bm.edges if e.is_boundary and all(v.co.z > .04 for v in e.verts)]
original = list({v for e in boundary for v in e.verts})
center = sum((v.co for v in original), Vector()) / len(original)
base_coords = {v: v.co.copy() for v in original}
previous = {v: v for v in original}
for z, widen in [(.10,1.10),(.14,1.35),(.19,1.65),(.23,1.75),(.26,1.60)]:
    current = {}
    for v in original:
        p = base_coords[v]-center
        # Slight pronation and elliptical muscle volume, tapering to wrist.
        angle = (z-center.z)*.8
        x = (p.x*math.cos(angle)-p.y*math.sin(angle))*widen
        y = (p.x*math.sin(angle)+p.y*math.cos(angle))*widen
        current[v] = bm.verts.new((center.x+x,center.y+y,z))
    for e in boundary:
        a,b = e.verts
        bm.faces.new((previous[a],previous[b],current[b],current[a]))
    previous = current
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(donor.data)
bm.free()
human_hands = []
for sign, side in [(1, 'L'), (-1, 'R')]:
    vertices = [(sign*(.7389-v.co.z*1.10), .066-v.co.x*.80,
                 1.441+v.co.y*.90) for v in donor.data.vertices]
    faces = [list(p.vertices) if sign == 1 else list(reversed(p.vertices))
             for p in donor.data.polygons]
    allowed = {b.name for b in rig.data.bones if b.name.endswith('.'+side)
               and ('hand' in b.name or 'forearm' in b.name or
                    'finger' in b.name or 'thumb' in b.name or
                    'palm' in b.name or 'f_' in b.name)}
    obj = new_mesh('Body_anatomical_hand_'+side, vertices, faces, skin_mat,
                   [nearest_weights(Vector(p), allowed) for p in vertices])
    human_hands.append(obj)
bpy.data.objects.remove(donor, do_unlink=True)

# Import sculpt, weld export-split corners, and use original rest geometry.
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'godot/assets/actor_image3d_mvp/yelingyun_image3d_color_candidate.glb'))
sculpt = max((o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH'), key=lambda o: len(o.data.vertices))
bpy.context.view_layer.objects.active = sculpt
bpy.ops.object.select_all(action='DESELECT')
sculpt.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00002)
bpy.ops.object.mode_set(mode='OBJECT')
sculpt.data.update()
xyz = np.array([list(v.co) for v in sculpt.data.vertices])
surface = BVHTree.FromPolygons([Vector(v) for v in xyz], [list(p.vertices) for p in sculpt.data.polygons])
minv, maxv = xyz.min(axis=0), xyz.max(axis=0)
span = maxv - minv
zsrc = [-1.0, -.86, -.56, -.16, .03, .34, .43, .55, .65, 1.0]
zdst = [0.0, .104, .532, .932, 1.07, 1.315, 1.441, 1.52, 1.57, 1.87]


def classification(p):
    x, y, z = p
    a = abs(x)
    if z > .565 and a < .28:
        return 'Head'
    if a > .20 + max(0, .43-z) * .255 and z > -.26:
        return 'SleeveL' if x > 0 else 'SleeveR'
    if z < -.29:
        return 'LegL' if x > 0 else 'LegR'
    return 'Coat'


def segment_warp(p, src_head, src_tail, dst_head, dst_tail, radius=.84):
    sh, st, dh, dt = map(Vector, (src_head, src_tail, dst_head, dst_tail))
    direction, target = st-sh, dt-dh
    fraction = (Vector(p)-sh).dot(direction) / direction.length_squared
    radial = Vector(p)-sh-direction*fraction
    rotated = direction.rotation_difference(target) @ radial
    return dh + target*fraction + rotated*radius


def fit(p, part):
    x, y, z = p
    side = 'L' if x > 0 else 'R'
    sign = 1 if x > 0 else -1
    if part.startswith('Sleeve'):
        shoulder = (.22*sign, 0, .43)
        elbow = (.35*sign, 0, .13)
        wrist = (.43*sign, 0, -.14)
        u = rig.data.bones['DEF-upper_arm.'+side]
        f = rig.data.bones['DEF-forearm.'+side]
        upper = segment_warp(p, shoulder, elbow, u.head_local, f.head_local)
        lower = segment_warp(p, elbow, wrist, f.head_local, rig.data.bones['DEF-hand.'+side].head_local)
        t = float(np.clip((.19-z)/.12, 0, 1))
        t = t*t*(3-2*t)
        result = upper.lerp(lower, t)
        return result
    if part.startswith('Leg'):
        result = Vector((x*.80, y*.83, float(np.interp(z, zsrc, zdst))))
        centre = float(np.interp(z, [-1, -.86, -.56, -.16], [.16, .16, .17, .125]))
        result.x = sign*.089 + (x-sign*centre)*.70
        result.y *= .88
        result.y += float(np.interp(z, [-1, -.86, -.56, -.16], [0, .0358, .0014, -.0014]))
        return result
    result = Vector((x*.84, y*.84 + .006, float(np.interp(z, zsrc, zdst))))
    if part=='Head':
        result.x *= .88
        result.y *= .92
        result.z = 1.535+(result.z-1.535)*.90
    elif part.startswith('Coat'):
        result.x *= .95
    return result


texture_mats = []
for view in ['front', 'back', 'left']:
    mat = material('Ink_cloth_'+view, (1, 1, 1), .89)
    img = bpy.data.images.load(str(SOURCE / ('source_'+view+'.png')))
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    mat.node_tree.links.new(tex.outputs['Color'], mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    texture_mats.append(mat)


def uv_at(p, view):
    x, y, z = p
    xf, hf = (x-minv[0])/span[0], (maxv[2]-z)/span[2]
    if view == 0:
        px, py = 174+xf*668, 61+hf*1403
    elif view == 1:
        px, py = 181+(1-xf)*650, 33+hf*1437
    else:
        df = (maxv[1]-y)/span[1]
        px, py = 378+df*313, 38+hf*1432
    return (px/1024, 1-py/1536)


parts = {p: [] for p in ['Head', 'Coat', 'CoatCovered', 'LegL', 'LegR','SleeveL','SleeveR']}
for face in sculpt.data.polygons:
    center = xyz[list(face.vertices)].mean(axis=0)
    part = classification(center)
    # Native deforming hands replace fused/generated fingers.
    if part.startswith('Sleeve') and center[2] < (.10 if part.endswith('R') else -.02):
        continue
    if part == 'Coat':
        p=fit(center,part)
        angle=math.degrees(math.atan2(p.x/.22,-(p.y-.006)/.16))
        if 1.075 < p.z < 1.435 and (abs(angle)<64 or abs(angle)>116):
            part='CoatCovered'
    parts[part].append(face)

model_parts = [neck, *human_hands]
for part, faces in parts.items():
    used = sorted({i for f in faces for i in f.vertices})
    remap = {old: new for new, old in enumerate(used)}
    fitted = [fit(xyz[i], part) for i in used]
    weights = []
    for p in fitted:
        if part == 'Head':
            weights.append({'DEF-head': 1})
        elif part.startswith('Coat'):
            levels = [(.98,'DEF-hips'), (1.10,'DEF-spine.001'), (1.25,'DEF-spine.002'), (1.40,'DEF-spine.003')]
            if p.z < levels[0][0]:
                weights.append({'DEF-hips': 1})
            elif p.z > levels[-1][0]:
                weights.append({'DEF-spine.003': 1})
            else:
                for a, b in zip(levels, levels[1:]):
                    if a[0] <= p.z <= b[0]:
                        t = (p.z-a[0])/(b[0]-a[0])
                        weights.append({a[1]:1-t,b[1]:t})
                        break
        elif part.startswith('Sleeve'):
            side=part[-1]
            t=float(np.clip((abs(p.x)-.41)/.115,0,1));t=t*t*(3-2*t)
            shoulder=float(np.clip((abs(p.x)-.16)/.095,0,1))
            weights.append({'DEF-spine.003':1-shoulder,'DEF-upper_arm.'+side:shoulder*(1-t),'DEF-forearm.'+side:shoulder*t})
        else:
            side = part[-1]
            if p.z<.15:
                weights.append(nearest_weights(p,{'DEF-shin.'+side,'DEF-foot.'+side,'DEF-toe.'+side}))
            else:
                t=float(np.clip((p.z-.47)/.13,0,1));t=t*t*(3-2*t)
                weights.append({'DEF-shin.'+side:1-t,'DEF-thigh.'+side:t})
    obj = new_mesh('Yelingyun_'+part, fitted,
                   [[remap[i] for i in f.vertices] for f in faces], None, weights)
    for mat in texture_mats:
        obj.data.materials.append(mat)
    uv = obj.data.uv_layers.new(name='Authored_turnaround_projection')
    for i, face in enumerate(faces):
        center = xyz[list(face.vertices)].mean(axis=0)
        # Consistent islands avoid per-triangle front/side projections that
        # produced dirty mosaics on the previous sample's cloth and face.
        view = 0 if center[1] < .015 else 1
        if part == 'Head' and abs(center[0]) > abs(center[1]-.015)*1.3:
            view=2
        obj.data.polygons[i].material_index = view
        for loop_id, old_id in zip(obj.data.polygons[i].loop_indices, face.vertices):
            uv.data[loop_id].uv = uv_at(xyz[old_id], view)
    if part.startswith(('Coat','Leg','Sleeve')):
        obj.data.materials.clear()
        for mat in [cloth_mat,linen_mat,leather,collar_mat,skin_mat,wrap_mat]:
            obj.data.materials.append(mat)
        for face in obj.data.polygons:
            p = np.mean([xyz[used[i]] for i in face.vertices],axis=0)
            x,y,z = p
            mi=0
            if part.startswith('Leg'):
                zfit=float(np.interp(z,zsrc,zdst))
                if zfit<.145:mi=2
                elif zfit<.425:mi=5
            elif part.startswith('Sleeve'):
                if z<(.15 if part.endswith('R') else .03):mi=1
            elif .12 < z < .215:
                mi=2
            elif y<.015 and abs(x)<.125 and z<.52:
                mi=1
                if .25<z<.52 and abs(x-(.04+(.43-z)*.25))<.016:
                    mi=3
            if part.startswith('Coat') and z>.455 and abs(x)<.065 and y<.015:
                mi=4
            face.material_index=mi
            for li,vi in zip(face.loop_indices,face.vertices):
                p=obj.data.vertices[vi].co
                uv.data[li].uv=(p.x*2.5+p.y*.7,p.z*2.5)
    # Preserve source sculpt in .blend; export a bounded surface density.
    dec = obj.modifiers.new('Surface_density_reduction', 'DECIMATE')
    dec.ratio = .40 if part == 'Head' else .35
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_move_up(modifier=dec.name)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    obj.data.validate(verbose=False)
    model_parts.append(obj)


def surface_radius(center, direction, default, max_radius):
    hit, normal, _, distance = surface.ray_cast(Vector(center), Vector(direction), max_radius)
    if hit is not None and distance > .015:
        return float(np.clip(distance, default*.65, max_radius))
    return default


def garment_grid(name, vertices, source_points, weights, ring_count, sides=32, skin_start=None):
    faces=[]
    for j in range(ring_count-1):
        for i in range(sides):
            face=(j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i)
            faces.append(tuple(reversed(face)) if name.endswith('Sleeve_L') else face)
    obj=new_mesh(name,vertices,faces,None,weights)
    for mat in [cloth_mat,linen_mat,wrap_mat,leather,seam_mat]:obj.data.materials.append(mat)
    uv=obj.data.uv_layers.new(name='Garment_surface_reference')
    for face in obj.data.polygons:
        center=np.mean([vertices[i] for i in face.vertices],axis=0)
        sleeve='Sleeve' in name
        row=min(face.vertices)//sides
        face.material_index=0
        if sleeve and row>=ring_count-4:
            face.material_index=1
        elif not sleeve and center[2]<.425:
            face.material_index=2
        for loop_id,vertex_id in zip(face.loop_indices,face.vertices):
            row,col=divmod(vertex_id,sides)
            # Cylindrical islands use a fabric tile only. Pixel coordinates
            # never enter a face, hand, backdrop or painted lighting region.
            u=col/sides
            if col==0 and any(v%sides==sides-1 for v in face.vertices):u=1
            v=abs(vertices[vertex_id][0])*3 if sleeve else vertices[vertex_id][2]*3
            uv.data[loop_id].uv=(u*1.3,v)
    model_parts.append(obj)
    return obj


# Joint-oriented quad rings replace the scanned arm/leg topology. Ring centres
# follow the native rig; radial measurements come from the identity sculpt.
for sign,side in []: # V3 uses the source garment's folded surfaces with constrained weights.
    cuff=.545 if side=='L' else .475
    xs=sorted(set([x for x in np.linspace(.16,cuff+.008,25).tolist()+[.43,.45,.4663,.48,.50,cuff-.008,cuff,cuff+.008] if x<=cuff+.008]))
    vertices,source_points,weights=[],[],[]
    for x in xs:
        if x<=.4663:
            t=(x-.1919)/(.4663-.1919)
            sh=Vector((.22*sign,0,.43));st=Vector((.35*sign,0,.13))
        else:
            t=(x-.4663)/(.7389-.4663)
            sh=Vector((.35*sign,0,.13));st=Vector((.43*sign,0,-.14))
        center=sh+(st-sh)*t
        axis=(st-sh).normalized()
        radial=Vector((axis.z*sign,0,-axis.x*sign))
        radii=[]
        for i in range(32):
            a=2*math.pi*i/32
            direction=Vector((0,math.cos(a),0))+radial*math.sin(a)
            default=.105 if x<.52 else .057
            radii.append(surface_radius(center,direction,default,.15 if x<.55 else .09))
        # A single low-pass pass retains broad authored folds while removing
        # scan spikes that would make cloth edges crawl during animation.
        smooth=[sum(radii[(i+j)%32] for j in range(-2,3))/5 for i in range(32)]
        for i,r in enumerate(smooth):
            a=2*math.pi*i/32
            direction=Vector((0,math.cos(a),0))+radial*math.sin(a)
            source_points.append(center+direction*r)
            if x>cuff:
                radius=float(np.interp(x,[cuff,.60,.70],[.047,.045,.034]))
            else:
                profile=float(np.interp(x,[.16,.24,.38,cuff],[.080,.084,.074,.064]))
                radius=float(np.clip(r*.84,profile*.9,profile*1.10))
            vertices.append((x*sign,.066+math.cos(a)*radius,1.441-math.sin(a)*radius))
            t=float(np.clip((x-.41)/.115,0,1));t=t*t*(3-2*t)
            weights.append({'DEF-upper_arm.'+side:1-t,'DEF-forearm.'+side:t})
    garment_grid('Yelingyun_Sleeve_'+side,vertices,source_points,weights,len(xs))
    zs=sorted(set(np.linspace(.104,.968,33).tolist()+[.49,.51,.532,.55,.57]))
    vertices,source_points,weights=[],[],[]
    for z in zs:
        source_z=float(np.interp(z,zdst,zsrc))
        cx=float(np.interp(source_z,[-1,-.86,-.56,-.16],[.16,.16,.17,.125]))*sign
        center=Vector((cx,0,source_z))
        native_y=float(np.interp(z,[.104,.532,.932],[.0358,.0014,-.0014]))
        radii=[]
        for i in range(32):
            a=2*math.pi*i/32;direction=Vector((math.cos(a),math.sin(a),0))
            default=.075 if z<.43 else .115
            radii.append(surface_radius(center,direction,default,.15 if z>.43 else .095))
        smooth=[(radii[(i-1)%32]+2*radii[i]+radii[(i+1)%32])/4 for i in range(32)]
        for i,r in enumerate(smooth):
            a=2*math.pi*i/32;direction=Vector((math.cos(a),math.sin(a),0))
            source_points.append(center+direction*r)
            vertices.append((sign*.089+direction.x*r*.86,native_y+direction.y*r*.86,z))
            t=float(np.clip((z-.47)/.13,0,1));t=t*t*(3-2*t)
            h=float(np.clip((z-.87)/.10,0,1))
            weights.append({'DEF-shin.'+side:(1-t)*(1-h),'DEF-thigh.'+side:t*(1-h),'DEF-hips':h})
    garment_grid('Yelingyun_Trouser_'+side,vertices,source_points,weights,len(zs))
for o in list(bpy.context.scene.objects):
    if o not in before and o not in model_parts and o != rig:
        bpy.data.objects.remove(o, do_unlink=True)

# Articulated armor: curved breast/back, leather straps, shallow overlapping
# waist lames, separate shoulder shells. Every part uses the SAME armature.
armor_parts = []


def skin_rigid(obj, bone):
    bind(obj, [{bone: 1.0} for _ in obj.data.vertices])
    armor_parts.append(obj)
    return obj


def shell(name, rings, start, end, mat, bone=None, steps=18):
    verts, faces = [], []
    for z, width, depth in rings:
        for i in range(steps+1):
            a = math.radians(start+(end-start)*i/steps)
            verts.append((math.sin(a)*width, -math.cos(a)*depth+.006, z))
    for j in range(len(rings)-1):
        for i in range(steps):
            a=j*(steps+1)+i
            faces.append((a,a+1,a+steps+2,a+steps+1))
    obj = new_mesh(name, verts, faces, mat)
    solid=obj.modifiers.new('Forged_thickness','SOLIDIFY')
    solid.thickness=.007
    bevel=obj.modifiers.new('Soft_forged_edge','BEVEL')
    bevel.width=.0025
    bevel.segments=2
    bpy.context.view_layer.objects.active=obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if bone:
        skin_rigid(obj,bone)
    else:
        bind(obj,[nearest_weights(v.co,{'DEF-spine.001','DEF-spine.002','DEF-spine.003'}) for v in obj.data.vertices])
        armor_parts.append(obj)
    return obj


shell('Armor_breast',[(1.09,.188,.14),(1.20,.220,.163),(1.32,.234,.155),(1.42,.194,.134)],-65,65,iron)
shell('Armor_back',[(1.09,.188,.14),(1.22,.221,.151),(1.34,.23,.142),(1.43,.175,.112)],115,245,iron)
for z,w,d in [(1.09,.19,.145),(1.20,.224,.167),(1.42,.196,.138)]:
    shell('Armor_breast_lip',[(z,w,d),(z+.008,w,d)],-65,65,edge)
for row in range(4):
    z=1.145+row*.060
    w=float(np.interp(z,[1.09,1.2,1.32,1.42],[.19,.224,.238,.198]))
    d=float(np.interp(z,[1.09,1.2,1.32,1.42],[.145,.168,.160,.139]))
    for col in range(6):
        a=-60+col*20
        shell('Armor_lamellar_tile',[(z-.032,w+.005,d+.005),(z+.030,w+.003,d+.003)],a+1,a+19,iron,None,3)
for row in range(3):
    z=1.085-row*.065
    for start,end in [(-72,-8),(8,72),(118,172),(188,242)]:
        shell('Armor_waist_lame',[(z-.079,.22+row*.013,.163+row*.005),(z,.204+row*.013,.151+row*.005)],start,end,iron,'DEF-hips',10)
for sign,side in [(1,'L'),(-1,'R')]:
    verts,faces=[],[]
    for x,r in [(.195,.103),(.24,.114),(.29,.111),(.33,.097)]:
        for i in range(13):
            a=math.pi*i/12
            verts.append((sign*x,.065+math.cos(a)*r,1.445+math.sin(a)*r))
    for j in range(3):
        for i in range(12):
            a=j*13+i
            faces.append((a,a+1,a+14,a+13))
    shoulder=new_mesh('Armor_shoulder_'+side,verts,faces,iron)
    solid=shoulder.modifiers.new('Shoulder_thickness','SOLIDIFY');solid.thickness=.007
    bpy.context.view_layer.objects.active=shoulder;bpy.ops.object.modifier_apply(modifier=solid.name)
    skin_rigid(shoulder,'DEF-upper_arm.'+side)
    # Rivets are actual small metal pieces, attached to the plate's influence.
    for x in [.23,.30]:
        for y in [-.009,.139]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.005,location=(sign*x,y,1.515))
            rivet=bpy.context.object;rivet.name='Armor_rivet_'+side
            bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
            rivet.data.materials.append(bronze);skin_rigid(rivet,'DEF-upper_arm.'+side)
    # A visible side strap closes the front/back cuirass around the ribs.
    shell('Armor_side_strap_'+side,[(1.14,.222,.164),(1.17,.225,.166)],55 if sign>0 else -125,125 if sign>0 else -55,leather)

# Export fitted actor and clothing parts together. Equipment remains separable
# MeshInstance3D nodes; the demo toggles assembly by stable part prefix.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from wearable_ready_pose_v3 import build_ready_action
build_ready_action(rig)
keep_actions.add('Sword_Ready')
for track in rig.animation_data.nla_tracks:
    track.mute=False
rig.animation_data.action=None
bpy.context.scene.render.fps=24
bpy.context.scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'yelingyun_native_fitted_v2.blend'))
bpy.ops.object.select_all(action='SELECT')
params={'filepath':str(OUT/'yelingyun_wearable_v2.glb'),'export_format':'GLB',
        'export_skins':True,'export_materials':'EXPORT','export_animations':True,
        'export_animation_mode':'NLA_TRACKS'}
bpy.ops.export_scene.gltf(**params)
report={'source_rig':'Quaternius UAL Standard CC0, native bones and clips',
        'hand_source':'Blender Human Base Meshes v1.0.0 / Hand - Realistic, CC0',
        'identity_source':'existing Hunyuan multiview sculpt + authored turnaround',
        'limitations':['surface decimation is NOT production manual retopology',
                        'clothing intersections require live pose review',
                        'projected turnaround UVs remain a prototype texture'],
        'parts':[{'name':o.name,'vertices':len(o.data.vertices)} for o in model_parts+armor_parts],
        'bones':len(rig.data.bones),'clips':sorted(keep_actions)}
(WORK/'build_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('WEARABLE_V2_BUILT',len(model_parts),'body parts',len(armor_parts),'armor parts',flush=True)
