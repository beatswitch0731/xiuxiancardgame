"""Bake a restrained sword-ready loop on the unchanged UAL skeleton.

Call build_ready_action(rig) after importing/keeping Idle_Loop and Sword_Idle,
before the producer enables NLA tracks for export. No runtime bone offsets or
new skeleton/rest proportions are introduced. The result is a separate action
and NLA track named Sword_Ready; the native attack remains untouched.
"""
import math
import bpy
from mathutils import Matrix, Quaternion, Vector


def _select_action(rig, action):
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]


def _aim_bone(bone, direction):
    """Rotate the current pose's longitudinal Y axis without adding scale."""
    matrix = bone.matrix.copy()
    rotation = matrix.to_quaternion()
    correction = (rotation @ Vector((0, 1, 0))).rotation_difference(direction.normalized())
    bone.matrix = Matrix.LocRotScale(matrix.translation, correction @ rotation,
                                    Vector((1, 1, 1)))
    bpy.context.view_layer.update()


def _raise_gaze(bone, radians):
    """Small pose-space pitch correction about the character's lateral axis."""
    matrix = bone.matrix.copy()
    rotation = matrix.to_quaternion()
    forward = (rotation @ bone.bone.matrix_local.to_quaternion().inverted()) @ Vector((0, -1, 0))
    lateral = Vector((forward.y, -forward.x, 0)).normalized()
    bone.matrix = Matrix.LocRotScale(matrix.translation,
        Quaternion(lateral, radians) @ rotation, Vector((1, 1, 1)))
    bpy.context.view_layer.update()


def build_ready_action(rig):
    """Return Sword_Ready and append its muted export track to rig.

    All native bones (53 for the current UAL GLB, rather than a hardcoded
    subset) are sampled. Root, feet and pelvis retain native Idle_Loop motion.
    Chest/eye-line pitch receives a restrained correction, left arm remains
    relaxed, and right arm/wrist/fingers are authored for the low guard.
    Blender armature space is Z-up, character forward is -Y, right is -X.
    """
    idle = bpy.data.actions['Idle_Loop']
    sword_idle = bpy.data.actions['Sword_Idle']
    previous_action = rig.animation_data.action
    previous_slot = rig.animation_data.action_slot
    previous_frame = bpy.context.scene.frame_current
    track_mutes = [(track, track.mute) for track in rig.animation_data.nla_tracks]
    for track, _ in track_mutes:
        track.mute = True

    _select_action(rig, sword_idle)
    bpy.context.scene.frame_set(int(sword_idle.frame_range[0]))
    bpy.context.view_layer.update()
    finger_pose = {
        bone.name: bone.matrix_basis.copy()
        for bone in rig.pose.bones
        if bone.name.endswith('.R') and ('f_' in bone.name or 'thumb' in bone.name)
    }

    first, last = (int(round(x)) for x in idle.frame_range)
    snapshots = []
    reference_chest = None
    for frame in range(first, last + 1):
        _select_action(rig, idle)
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        # Native Idle itself looks down about fourteen degrees. Distribute
        # eleven degrees across chest and head; keep the neck's native relative
        # pose, the breathing cycle, and every lower-body/root track intact.
        _raise_gaze(rig.pose.bones['DEF-spine.003'], math.radians(6))
        _raise_gaze(rig.pose.bones['DEF-head'], math.radians(5))
        chest = rig.pose.bones['DEF-spine.003'].matrix.to_quaternion()
        if reference_chest is None:
            reference_chest = chest.copy()
        breathe_rotation = chest @ reference_chest.inverted()

        # Relaxed upper arm near the ribs, elbow gently flexed. The old
        # Sword_Idle spreads both hands behind the torso while crouching.
        # Lengths come from native bones, not fabricated joint translations.
        _aim_bone(rig.pose.bones['DEF-upper_arm.R'],
                  breathe_rotation @ Vector((-.085, -.015, -.260)))
        _aim_bone(rig.pose.bones['DEF-forearm.R'],
                  breathe_rotation @ Vector((-.035, -.065, -.263)))

        # Hand rest local Z points along the attached sword. Forward with an
        # eight-degree downward inclination leaves ample floor clearance and
        # avoids a sharply bent wrist. Local Y follows the metacarpals.
        blade_axis = Vector((0, -.9915, -.1300)).normalized()
        palm_axis = Vector((-.065, .13, -.989))
        palm_axis = (palm_axis - blade_axis * palm_axis.dot(blade_axis)).normalized()
        cross_axis = palm_axis.cross(blade_axis).normalized()
        hand_rotation = Matrix((cross_axis, palm_axis, blade_axis)).transposed()
        hand = rig.pose.bones['DEF-hand.R']
        position = hand.matrix.translation.copy()
        hand.matrix = Matrix.LocRotScale(position,
            breathe_rotation @ hand_rotation.to_quaternion(), Vector((1, 1, 1)))
        bpy.context.view_layer.update()
        for name, matrix in finger_pose.items():
            rig.pose.bones[name].matrix_basis = matrix
        bpy.context.view_layer.update()
        snapshots.append({bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones})

    # The first and last samples are identical, including the finger closure.
    snapshots[-1] = {name: matrix.copy() for name, matrix in snapshots[0].items()}
    ready = bpy.data.actions.new('Sword_Ready')
    rig.animation_data.action = ready
    for frame, pose in zip(range(first, last + 1), snapshots):
        for name, matrix in pose.items():
            bone = rig.pose.bones[name]
            bone.rotation_mode = 'QUATERNION'
            bone.matrix_basis = matrix
            for channel in ('location', 'rotation_quaternion', 'scale'):
                bone.keyframe_insert(channel, frame=frame, group=name)

    track = rig.animation_data.nla_tracks.new()
    track.name = 'Sword_Ready'
    strip = track.strips.new('Sword_Ready', first, ready)
    if ready.slots:
        strip.action_slot = ready.slots[0]
    track.mute = True
    for old_track, muted in track_mutes:
        old_track.mute = muted
    rig.animation_data.action = previous_action
    if previous_action and previous_slot:
        rig.animation_data.action_slot = previous_slot
    bpy.context.scene.frame_set(previous_frame)
    print('SWORD_READY_BAKED', len(rig.pose.bones), 'bones', len(snapshots), 'samples')
    return ready
