@tool
extends Node3D

# Source-identity 3D figures for the first Cangmang sword trial. Every visible
# body, garment and weapon part is a lit volume mesh. Card art stays in the UI.
signal action_finished(clip: String)
signal contact_key(clip: String)

@export_enum("hero", "dummy") var fighter_kind := "hero"

const HERO_CONTACT := {"sword_probe": 0.31, "sword_followthrough": 0.42, "attack": 0.38}
const DUMMY_CONTACT := {"attack": 0.38, "sword_probe": 0.38, "sword_followthrough": 0.38}

var _rig: Node3D
var _body: Node3D
var _head: Node3D
var _arm_right: Node3D
var _arm_left: Node3D
var _leg_right: Node3D
var _leg_left: Node3D
var _hem: Node3D
var _sword_grip: Node3D
var _player: AnimationPlayer
var _library: AnimationLibrary
var _materials: Dictionary = {}
var _contact_emitted := false


func _ready() -> void:
	if get_node_or_null("Rig") != null:
		_bind_existing_rig()
		return
	_build_palette()
	_build_rig()
	if fighter_kind == "dummy":
		_build_dummy()
	else:
		_build_hero()
	_build_animations()
	if not Engine.is_editor_hint():
		_player.play("idle")


func rebuild_model() -> void:
	# Authoring entry point: rebuild the editable scene from the source identity
	# recipe, then use the baker to persist MeshInstance3D and AnimationPlayer.
	if _player != null:
		_player.stop()
	for node_name in ["AnimationPlayer", "Rig"]:
		var old_node := get_node_or_null(node_name)
		if old_node != null:
			remove_child(old_node)
			old_node.free()
	_materials.clear()
	_build_palette()
	_build_rig()
	if fighter_kind == "dummy":
		_build_dummy()
	else:
		_build_hero()
	_build_animations()
	if not Engine.is_editor_hint():
		_player.play("idle")


func _bind_existing_rig() -> void:
	_rig = get_node("Rig") as Node3D
	_body = get_node("Rig/BodyPivot") as Node3D
	_head = get_node("Rig/BodyPivot/HeadPivot") as Node3D
	_arm_right = get_node("Rig/BodyPivot/RightArmPivot") as Node3D
	_arm_left = get_node("Rig/BodyPivot/LeftArmPivot") as Node3D
	_leg_right = get_node("Rig/RightLegPivot") as Node3D
	_leg_left = get_node("Rig/LeftLegPivot") as Node3D
	_hem = get_node("Rig/BodyPivot/HemPivot") as Node3D
	_sword_grip = get_node("Rig/BodyPivot/RightArmPivot/SwordGrip") as Node3D
	_player = get_node("AnimationPlayer") as AnimationPlayer
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	if not Engine.is_editor_hint():
		_player.play("idle")


func has_action(clip: String) -> bool:
	return _player != null and _player.has_animation(clip)


func play_action(clip: String) -> bool:
	if not has_action(clip):
		return false
	_contact_emitted = false
	_player.play(clip)
	return true


func get_contact_time(clip: String) -> float:
	var table: Dictionary = DUMMY_CONTACT if fighter_kind == "dummy" else HERO_CONTACT
	return float(table.get(clip, -1.0))


func get_action_duration(clip: String) -> float:
	if not has_action(clip):
		return -1.0
	return _player.get_animation(clip).length


func get_sword_tip() -> Marker3D:
	return get_node_or_null("Rig/BodyPivot/RightArmPivot/SwordGrip/SwordTip") as Marker3D


func get_chest_hit() -> Marker3D:
	return get_node_or_null("Rig/BodyPivot/ChestHit") as Marker3D


func get_animation_player() -> AnimationPlayer:
	return _player


func mesh_count() -> int:
	return _count_meshes(self)


func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


func _build_palette() -> void:
	var colors := {
		"robe": Color("465b64"), "robe_light": Color("617984"),
		"robe_shadow": Color("2c3d47"), "inner": Color("292e31"),
		"seam": Color("77878b"), "belt": Color("6a4b39"),
		"belt_edge": Color("937458"), "skin": Color("ac8973"),
		"skin_shadow": Color("826557"), "hair": Color("202528"),
		"hair_light": Color("374044"), "iron": Color("657078"),
		"iron_edge": Color("a7a9a0"), "iron_dark": Color("3a4147"),
		"shoe": Color("292d2b"), "wood": Color("715431"),
		"wood_light": Color("957347"), "wood_dark": Color("3e3328"),
		"wood_end": Color("b79766"), "bronze": Color("99845b"),
		"bronze_light": Color("c1ad7a"), "joint": Color("414748"),
		"eye": Color("151a1c"), "wrap": Color("777067")
	}
	for key in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 0.88
		material.metallic = 0.35 if key in ["iron", "iron_edge", "iron_dark", "bronze", "bronze_light", "joint"] else 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material


func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_body = _pivot(_rig, "BodyPivot", Vector3(0, 0.86, 0))
	_marker(_body, "ChestHit", Vector3(.20, .28, 0))
	_head = _pivot(_body, "HeadPivot", Vector3(0, 0.61, 0))
	_arm_right = _pivot(_body, "RightArmPivot", Vector3(0.015, 0.51, 0.26))
	_arm_left = _pivot(_body, "LeftArmPivot", Vector3(0.015, 0.51, -0.26))
	_leg_right = _pivot(_rig, "RightLegPivot", Vector3(0, 0.85, 0.125))
	_leg_left = _pivot(_rig, "LeftLegPivot", Vector3(0, 0.85, -0.125))
	_hem = _pivot(_body, "HemPivot", Vector3(0, 0.0, 0))
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.root_node = NodePath("..")
	_library = AnimationLibrary.new()
	_player.add_animation_library("", _library)
	_player.animation_finished.connect(_on_animation_finished)


func _pivot(parent: Node3D, node_name: String, local_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = local_position
	parent.add_child(pivot)
	return pivot


func _marker(parent: Node3D, node_name: String, local_position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = local_position
	parent.add_child(marker)
	return marker


func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3,
		material_name: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = mesh
	piece.material_override = _materials[material_name]
	piece.position = pos
	piece.rotation = rot
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(piece)
	return piece


func _loft(parent: Node3D, node_name: String, rings: Array, material_name: String,
		sides: int = 8) -> MeshInstance3D:
	# Each ring: [y, center_x, center_z, x_radius, z_radius]. Distinct ring
	# sizes make a sewn silhouette rather than a stack of engine primitives.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rings.size() - 1):
		for side in range(sides):
			var a := _ring_point(rings[r], side, sides)
			var b := _ring_point(rings[r], side + 1, sides)
			var c := _ring_point(rings[r + 1], side + 1, sides)
			var d := _ring_point(rings[r + 1], side, sides)
			for vertex in [a, d, b, b, d, c]:
				tool.add_vertex(vertex)
	for side in range(1, sides - 1):
		for vertex in [_ring_point(rings[0], 0, sides), _ring_point(rings[0], side + 1, sides), _ring_point(rings[0], side, sides)]:
			tool.add_vertex(vertex)
		for vertex in [_ring_point(rings[-1], 0, sides), _ring_point(rings[-1], side, sides), _ring_point(rings[-1], side + 1, sides)]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = tool.commit()
	piece.material_override = _materials[material_name]
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(piece)
	return piece


func _ring_point(ring: Array, side: int, sides: int) -> Vector3:
	var angle := TAU * float(side) / float(sides)
	return Vector3(float(ring[1]) + cos(angle) * float(ring[3]),
		float(ring[0]), float(ring[2]) + sin(angle) * float(ring[4]))


func _pointed_panel(parent: Node3D, node_name: String, points: PackedVector3Array,
		thickness: float, material_name: String) -> MeshInstance3D:
	# Extrude a four-corner cloth or plate panel in its normal direction.
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized() * thickness
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertices in [[points[0], points[1], points[2]], [points[0], points[2], points[3]]]:
		for vertex in vertices:
			tool.add_vertex(vertex)
		for vertex in vertices:
			tool.add_vertex(vertex + normal)
	for i in range(4):
		var j := (i + 1) % 4
		for vertex in [points[i], points[j], points[j] + normal,
			points[i], points[j] + normal, points[i] + normal]:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.mesh = tool.commit()
	piece.material_override = _materials[material_name]
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(piece)
	return piece


func _bar(parent: Node3D, node_name: String, a: Vector3, b: Vector3,
		width: float, depth: float, material_name: String) -> MeshInstance3D:
	var piece := _box(parent, node_name, (a + b) * 0.5,
		Vector3(width, a.distance_to(b), depth), material_name)
	piece.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return piece


func _build_hero() -> void:
	# Source S1: sixteen-year-old narrow-shouldered sword novice. Clean recut
	# workwear, smoke-blue unequal hems, worn leather, no shining hero armor.
	_loft(_body, "CharcoalInnerTunic", [[0.03, 0, 0, .16, .18], [.50, 0, 0, .14, .18]], "inner")
	_loft(_body, "SmokeBlueShortCoat", [[-.13, -.02, 0, .20, .225],
		[.11, -.01, 0, .18, .20], [.52, 0, 0, .155, .26]], "robe")
	_loft(_body, "SoftShoulderSeam", [[.45, -.015, 0, .15, .255],
		[.54, -.01, 0, .135, .235]], "robe_light")
	_loft(_hem, "LongerLeftCoatTail", [[-.42, -.07, -.13, .12, .11],
		[-.23, -.025, -.13, .16, .14], [.04, -.015, -.12, .15, .13]], "robe_shadow")
	_pointed_panel(_hem, "DiagonalFrontHem", PackedVector3Array([
		Vector3(.18, .11, -.23), Vector3(.22, .10, .20),
		Vector3(.20, -.21, .15), Vector3(.23, -.39, -.17)]), .024, "robe_light")
	_pointed_panel(_body, "OpenInnerLap", PackedVector3Array([
		Vector3(.18, .38, -.075), Vector3(.17, .38, .07),
		Vector3(.22, -.10, .045), Vector3(.20, -.15, -.08)]), .012, "inner")
	_pointed_panel(_body, "TailoredLeftFront", PackedVector3Array([
		Vector3(.164, .46, -.18), Vector3(.211, .34, -.017),
		Vector3(.227, .13, -.045), Vector3(.204, .06, -.18)]), .025, "robe_light")
	_pointed_panel(_body, "TailoredRightFront", PackedVector3Array([
		Vector3(.210, .34, .022), Vector3(.160, .47, .18),
		Vector3(.204, .06, .18), Vector3(.227, .13, .050)]), .025, "robe")
	_box(_body, "CrossedCollarLeft", Vector3(.152, .43, -.06), Vector3(.04, .25, .055), "seam", Vector3(.38, 0, -.23))
	_box(_body, "CrossedCollarRight", Vector3(.16, .42, .06), Vector3(.04, .22, .06), "inner", Vector3(-.33, 0, .20))
	_box(_body, "ShortCoatFrontPlacket", Vector3(.194, .25, -.13),
		Vector3(.021, .31, .026), "robe_light", Vector3(.0, .0, -.06))
	_box(_body, "TailoredRightSideSeam", Vector3(.075, .18, .218),
		Vector3(.020, .34, .015), "robe_shadow")
	_loft(_body, "OldLeatherWaistTie", [[.105, 0, 0, .205, .215],
		[.17, 0, 0, .201, .211]], "belt")
	_box(_body, "SingleFlatIronUtilityRing", Vector3(.213, .123, -.12), Vector3(.018, .072, .075), "iron_dark")
	_box(_body, "SashKnot", Vector3(.223, .11, .16), Vector3(.033, .070, .075), "belt_edge")
	_box(_body, "SashHangingEnd", Vector3(.22, -.02, .17), Vector3(.03, .21, .055), "belt")
	_build_hero_leg(_leg_right, true)
	_build_hero_leg(_leg_left, false)
	_build_hero_arm(_arm_right, true)
	_build_hero_arm(_arm_left, false)
	_build_hero_head()
	_build_old_iron_sword(_arm_right)


func _build_hero_leg(parent: Node3D, right: bool) -> void:
	var side := 1.0 if right else -1.0
	_loft(parent, "PleatedTrouser", [[-.49, .01, 0, .105, .098],
		[-.25, .005, 0, .12, .11], [.02, 0, 0, .15, .115]], "inner")
	_loft(parent, "CalfWrappedCloth", [[-.71, 0, 0, .077, .080],
		[-.48, 0, 0, .085, .089]], "wrap")
	_box(parent, "WrapTopBand", Vector3(.002, -.50, 0), Vector3(.16, .045, .175), "belt_edge")
	_box(parent, "WrapBottomBand", Vector3(.005, -.67, 0), Vector3(.15, .040, .165), "belt")
	_box(parent, "PracticalCompleteShoe", Vector3(.055, -.78, side * .005),
		Vector3(.29, .135, .18), "shoe")
	_box(parent, "ShoeToeWear", Vector3(.178, -.81, side * .005),
		Vector3(.048, .042, .15), "hair_light")


func _build_hero_arm(parent: Node3D, right: bool) -> void:
	var sleeve := "robe" if right else "robe_shadow"
	_loft(parent, "Sleeve", [[-.29, .015, 0, .083, .082],
		[-.14, .005, 0, .093, .096], [.03, 0, 0, .105, .112]], sleeve)
	if right:
		# Rolled right sleeve, old forearm heat scar, simple leather bracer.
		_loft(parent, "ExposedRightForearm", [[-.43, .024, 0, .053, .058],
			[-.28, .015, 0, .065, .068]], "skin")
		_box(parent, "OldHeatScar", Vector3(.077, -.35, .028),
			Vector3(.014, .095, .026), "skin_shadow", Vector3(.23, 0, .16))
		_box(parent, "RolledCuff", Vector3(.016, -.27, 0),
			Vector3(.17, .052, .17), "robe_light")
		_box(parent, "LeatherBracer", Vector3(.012, -.38, 0),
			Vector3(.135, .095, .14), "belt")
	else:
		_loft(parent, "LongerLeftSleeve", [[-.43, .02, 0, .077, .075],
			[-.27, .01, 0, .086, .088]], "robe")
		_box(parent, "LeftFinishedCuff", Vector3(.020, -.41, 0),
			Vector3(.16, .048, .15), "robe_light")
	_loft(parent, "WorkHardenedHand", [[-.505, .025, 0, .054, .055],
		[-.43, .025, 0, .061, .061]], "skin")


func _build_hero_head() -> void:
	_loft(_head, "NarrowSquareFace", [[.015, .017, 0, .105, .103],
		[.09, .035, 0, .119, .115], [.22, .010, 0, .103, .106],
		[.28, -.002, 0, .078, .085]], "skin")
	_loft(_head, "UnevenBlackHairCrown", [[.215, -.02, 0, .112, .12],
		[.31, -.01, 0, .104, .105], [.355, -.01, 0, .04, .06]], "hair")
	_box(_head, "FringeLeftLong", Vector3(.132, .247, -.060),
		Vector3(.082, .095, .058), "hair", Vector3(.04, .11, -.28))
	_box(_head, "FringeRightShort", Vector3(.130, .269, .070),
		Vector3(.076, .056, .067), "hair_light", Vector3(0, -.06, .15))
	_pointed_panel(_head, "ForeheadHairLockLeft", PackedVector3Array([
		Vector3(.112, .303, -.101), Vector3(.149, .295, -.035),
		Vector3(.157, .174, -.046), Vector3(.115, .229, -.109)]), .022, "hair")
	_pointed_panel(_head, "ForeheadHairLockRight", PackedVector3Array([
		Vector3(.149, .304, .009), Vector3(.103, .299, .103),
		Vector3(.132, .218, .080), Vector3(.170, .235, .017)]), .022, "hair_light")
	_box(_head, "LowNapeHairTie", Vector3(-.097, .056, 0),
		Vector3(.080, .093, .075), "hair")
	_box(_head, "LowNapeTieBand", Vector3(-.13, .052, 0),
		Vector3(.025, .028, .083), "belt")
	_box(_head, "NoseBridge", Vector3(.145, .147, 0),
		Vector3(.037, .082, .027), "skin_shadow")
	_box(_head, "LeftEar", Vector3(.01, .139, -.112),
		Vector3(.045, .065, .022), "skin_shadow")
	_box(_head, "RightEar", Vector3(.01, .139, .112),
		Vector3(.045, .065, .022), "skin_shadow")
	_box(_head, "LeftEye", Vector3(.170, .172, -.059),
		Vector3(.018, .021, .038), "eye")
	_box(_head, "RightNarrowEye", Vector3(.170, .170, .060),
		Vector3(.018, .014, .031), "eye")
	_box(_head, "LeftBrowBeforeGap", Vector3(.172, .208, -.083),
		Vector3(.018, .015, .027), "hair")
	_box(_head, "LeftBrowAfterGap", Vector3(.172, .208, -.032),
		Vector3(.018, .015, .024), "hair")
	_box(_head, "RightBrow", Vector3(.172, .207, .060),
		Vector3(.018, .014, .050), "hair")
	_box(_head, "ClosedThinMouth", Vector3(.157, .080, 0),
		Vector3(.014, .007, .050), "skin_shadow")


func _build_old_iron_sword(parent: Node3D) -> void:
	var hand := _pivot(parent, "SwordGrip", Vector3(.135, -.48, .01))
	_sword_grip = hand
	hand.rotation.z = -.35
	_marker(hand, "SwordTip", Vector3(.99, 0, 0))
	_box(hand, "OldBrownWrappedGrip", Vector3(.09, 0, 0),
		Vector3(.19, .035, .043), "belt")
	_box(hand, "FlatIronPommel", Vector3(-.015, 0, 0),
		Vector3(.045, .073, .055), "iron_dark")
	_box(hand, "PlainCrossGuard", Vector3(.20, 0, 0),
		Vector3(.035, .13, .095), "iron_dark")
	# A dark forged diamond-section blade; no self-emission or magical glow.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(.22, 0, 0), Vector3(.25, .033, 0),
		Vector3(.25, 0, .024), Vector3(.25, -.033, 0), Vector3(.25, 0, -.024),
		Vector3(.84, .027, 0), Vector3(.84, 0, .019),
		Vector3(.84, -.027, 0), Vector3(.84, 0, -.019), Vector3(.99, 0, 0)]
	for quad in [[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 8, 4], [4, 8, 5, 1]]:
		for index in [0, 1, 2, 0, 2, 3]:
			tool.add_vertex(points[quad[index]])
	for triangle in [[5, 9, 6], [6, 9, 7], [7, 9, 8], [8, 9, 5]]:
		for point_index in triangle:
			tool.add_vertex(points[point_index])
	tool.generate_normals()
	var blade := MeshInstance3D.new()
	blade.name = "ForgedOldIronStraightBlade"
	blade.mesh = tool.commit()
	blade.material_override = _materials["iron"]
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hand.add_child(blade)
	_box(hand, "UnpolishedBladeRidge", Vector3(.54, .014, 0),
		Vector3(.48, .004, .008), "iron_edge")


func _build_dummy() -> void:
	# Source silhouette: a slightly taller, narrower rigid sword puppet with
	# real wood end grain and exposed bronze/iron pins, not an armored knight.
	# Pull the support hand across the chest to the same physical sword grip.
	_arm_left.position = Vector3(.08, .51, -.22)
	_loft(_body, "JointedWoodenChest", [[.0, 0, 0, .19, .18],
		[.45, 0, 0, .15, .185], [.55, -.01, 0, .13, .17]], "wood")
	_loft(_body, "FrontBronzeChassis", [[.04, .022, 0, .19, .19],
		[.13, .018, 0, .20, .20]], "bronze")
	_box(_body, "ChestFrontGrain", Vector3(.19, .32, 0),
		Vector3(.013, .30, .06), "wood_light", Vector3(.0, .0, .07))
	_box(_body, "ChestJointPlate", Vector3(.189, .24, 0),
		Vector3(.016, .095, .20), "wood_dark")
	_loft(_body, "WaistIronHinge", [[-.07, 0, 0, .16, .16],
		[.03, 0, 0, .17, .175]], "joint")
	_loft(_body, "CarvedWoodenHip", [[-.20, 0, 0, .16, .19],
		[-.07, 0, 0, .17, .19]], "wood_dark")
	_build_dummy_leg(_leg_right)
	_build_dummy_leg(_leg_left)
	_build_dummy_arm(_arm_right, true)
	_build_dummy_arm(_arm_left, false)
	_build_dummy_head()
	_build_training_sword(_arm_right)


func _build_dummy_leg(parent: Node3D) -> void:
	_loft(parent, "CarvedThigh", [[-.33, 0, 0, .095, .087],
		[-.02, 0, 0, .115, .105]], "wood")
	_box(parent, "LowerHipBronzeCollar", Vector3(0, -.045, 0),
		Vector3(.20, .054, .20), "bronze")
	_loft(parent, "IronPinKnee", [[-.39, 0, 0, .085, .083],
		[-.31, 0, 0, .084, .081]], "joint")
	_box(parent, "KneeFaceStud", Vector3(.084, -.35, 0),
		Vector3(.025, .058, .074), "bronze_light")
	_loft(parent, "TaperedWoodShin", [[-.70, .01, 0, .07, .072],
		[-.39, 0, 0, .086, .082]], "wood_light")
	_box(parent, "ShinIronBand", Vector3(.0, -.56, 0),
		Vector3(.16, .045, .15), "bronze")
	_box(parent, "GroundedWoodFoot", Vector3(.05, -.775, 0),
		Vector3(.29, .13, .18), "wood_dark")
	_box(parent, "FootBronzeEdge", Vector3(.17, -.79, 0),
		Vector3(.045, .075, .18), "bronze")


func _build_dummy_arm(parent: Node3D, right: bool) -> void:
	_loft(parent, "NarrowWoodUpperArm", [[-.23, .0, 0, .075, .075],
		[-.04, 0, 0, .095, .09]], "wood_light")
	_loft(parent, "RoundBronzeShoulderSocket", [[-.05, 0, 0, .105, .104],
		[.055, 0, 0, .10, .10]], "bronze")
	_loft(parent, "DarkHingedElbow", [[-.31, 0, 0, .070, .070],
		[-.23, 0, 0, .071, .071]], "joint")
	_loft(parent, "CarvedWoodForearm", [[-.48, .025, 0, .064, .07],
		[-.31, .0, 0, .07, .072]], "wood")
	_box(parent, "ForearmBronzeBand", Vector3(.018, -.40, 0),
		Vector3(.14, .040, .15), "bronze")
	_box(parent, "WoodenGripHand", Vector3(.037, -.50, 0),
		Vector3(.13, .105, .12), "wood_dark")
	if not right:
		_box(parent, "LeftArmGrain", Vector3(.093, -.18, 0),
			Vector3(.012, .12, .026), "wood_dark")


func _build_dummy_head() -> void:
	_loft(_head, "VerticalCarvedMask", [[.0, 0, 0, .107, .11],
		[.29, 0, 0, .112, .114], [.32, 0, 0, .09, .092]], "wood")
	_loft(_head, "BronzeCapRim", [[.26, 0, 0, .121, .12],
		[.31, 0, 0, .12, .12]], "bronze")
	_box(_head, "MaskBrowLedge", Vector3(.112, .205, 0),
		Vector3(.05, .045, .20), "wood_light")
	_box(_head, "LeftDarkEyeSlot", Vector3(.133, .173, -.06),
		Vector3(.025, .052, .030), "eye")
	_box(_head, "RightDarkEyeSlot", Vector3(.133, .173, .06),
		Vector3(.025, .052, .030), "eye")
	_box(_head, "StraightNoseGrain", Vector3(.126, .111, 0),
		Vector3(.025, .09, .025), "wood_light")
	_box(_head, "IronJawBand", Vector3(.101, .027, 0),
		Vector3(.032, .038, .19), "joint")
	_box(_head, "CapTopPin", Vector3(0, .335, 0),
		Vector3(.055, .030, .05), "bronze_light")


func _build_training_sword(parent: Node3D) -> void:
	var grip := _pivot(parent, "SwordGrip", Vector3(.125, -.52, .015))
	_sword_grip = grip
	grip.rotation.z = -.45
	_marker(grip, "SwordTip", Vector3(.925, 0, 0))
	_box(grip, "WornWoodGrip", Vector3(.09, 0, 0),
		Vector3(.18, .05, .05), "wood_dark")
	_box(grip, "BronzeGuard", Vector3(.21, 0, 0),
		Vector3(.045, .115, .10), "bronze")
	# The source puppet carries a short, blunt ironwood practice sword.
	_box(grip, "IronwoodPracticeBlade", Vector3(.55, 0, 0),
		Vector3(.68, .042, .052), "wood_dark")
	_box(grip, "ForgedEdgeWear", Vector3(.54, .026, 0),
		Vector3(.62, .008, .04), "iron_dark")
	_box(grip, "BluntPracticeTip", Vector3(.90, 0, 0),
		Vector3(.055, .038, .052), "wood")


func _build_animations() -> void:
	var idle := [
		{"t": 0.0},
		{"t": 0.54, "body_y": Vector3(0, .872, 0), "head": Vector3(.012, 0, 0),
			"arm_r": Vector3(0, 0, .025), "arm_l": Vector3(0, 0, -.02)},
		{"t": 1.15, "body_y": Vector3(0, .862, 0), "head": Vector3(-.008, 0, 0)},
		{"t": 1.80}
	]
	_add_animation("idle", 1.8, idle, true)
	_add_animation("sword_probe", .72, [
		{"t": 0.0},
		{"t": .12, "body_y": Vector3(-.05, .80, 0), "body": Vector3(0, 0, .12),
			"arm_r": Vector3(0, 0, -.30), "sword": Vector3(0, 0, -.55),
			"leg_r": Vector3(0, 0, -.15), "leg_l": Vector3(0, 0, .18)},
		{"t": .31, "body_y": Vector3(.12, .80, 0), "body": Vector3(0, 0, -.25),
			"head": Vector3(0, 0, .06), "arm_r": Vector3(0, 0, 1.12),
			"sword": Vector3(0, 0, -.82),
			"arm_l": Vector3(0, 0, .22), "leg_r": Vector3(0, 0, .45), "leg_l": Vector3(0, 0, -.32),
			"hem": Vector3(0, 0, -.15)},
		{"t": .42, "body_y": Vector3(.12, .80, 0), "body": Vector3(0, 0, -.25),
			"arm_r": Vector3(0, 0, 1.12), "sword": Vector3(0, 0, -.82)},
		{"t": .72}
	])
	_add_animation("sword_followthrough", .86, [
		{"t": 0.0},
		{"t": .17, "body": Vector3(0, -.18, .13), "arm_r": Vector3(0, 0, 1.38),
			"sword": Vector3(0, 0, .25),
			"arm_l": Vector3(0, 0, -.35), "hem": Vector3(0, 0, -.12)},
		{"t": .42, "body_y": Vector3(.16, .79, 0), "body": Vector3(0, .22, -.30),
			"arm_r": Vector3(0, 0, -.38), "arm_l": Vector3(0, 0, .26),
			"sword": Vector3(0, 0, -.14),
			"leg_r": Vector3(0, 0, .33), "leg_l": Vector3(0, 0, -.30),
			"hem": Vector3(0, 0, .19)},
		{"t": .54, "body_y": Vector3(.15, .79, 0), "body": Vector3(0, .22, -.25),
			"arm_r": Vector3(0, 0, -.48), "sword": Vector3(0, 0, -.20)},
		{"t": .86}
	])
	_add_animation("sword_guard", .55, [
		{"t": 0.0},
		{"t": .20, "body_y": Vector3(0, .82, 0), "body": Vector3(0, -.08, .07),
			"arm_r": Vector3(0, 0, 1.08), "arm_l": Vector3(0, 0, .64),
			"sword": Vector3(0, 0, .36),
			"leg_r": Vector3(0, 0, .10), "leg_l": Vector3(0, 0, -.10)},
		{"t": .38, "body_y": Vector3(0, .82, 0), "arm_r": Vector3(0, 0, 1.08),
			"sword": Vector3(0, 0, .36),
			"arm_l": Vector3(0, 0, .64)},
		{"t": .55}
	])
	_add_animation("attack", .78, [
		{"t": 0.0},
		{"t": .16, "body_y": Vector3(-.06, .79, 0), "body": Vector3(0, -.10, .13),
			"arm_r": Vector3(0, 0, -.36), "arm_l": Vector3(0, 0, .35),
			"sword": Vector3(0, 0, -.55)},
		{"t": .38, "body_y": Vector3(.12, .78, 0), "body": Vector3(0, .11, -.27),
			"arm_r": Vector3(0, 0, 1.20), "arm_l": Vector3(0, 0, .13),
			"sword": Vector3(0, 0, -.88),
			"leg_r": Vector3(0, 0, .33), "leg_l": Vector3(0, 0, -.29)},
		{"t": .47, "body_y": Vector3(.12, .78, 0), "body": Vector3(0, .11, -.27),
			"arm_r": Vector3(0, 0, 1.20), "sword": Vector3(0, 0, -.88)},
		{"t": .78}
	])
	_add_animation("hurt", .51, [
		{"t": 0.0},
		{"t": .09, "body_y": Vector3(-.065, .81, 0), "body": Vector3(0, 0, .25),
			"head": Vector3(0, 0, .18), "arm_r": Vector3(0, 0, -.30),
			"arm_l": Vector3(0, 0, -.45), "hem": Vector3(0, 0, -.22)},
		{"t": .24, "body_y": Vector3(-.04, .79, 0), "body": Vector3(0, 0, .17),
			"head": Vector3(0, 0, .12)},
		{"t": .51}
	])
	_add_animation("reaction", .50, [
		{"t": 0.0},
		{"t": .16, "body_y": Vector3(-.065, .82, 0), "body": Vector3(0, 0, .10),
			"arm_r": Vector3(0, 0, .95), "arm_l": Vector3(0, 0, .42),
			"sword": Vector3(0, 0, .28)},
		{"t": .34, "arm_r": Vector3(0, 0, .95), "arm_l": Vector3(0, 0, .42),
			"sword": Vector3(0, 0, .28)},
		{"t": .50}
	])
	_add_animation("guard", .55, [
		{"t": 0.0},
		{"t": .18, "body_y": Vector3(0, .82, 0),
			"arm_r": Vector3(0, 0, 1.04), "arm_l": Vector3(0, 0, .65),
			"sword": Vector3(0, 0, .36)},
		{"t": .39, "arm_r": Vector3(0, 0, 1.04), "arm_l": Vector3(0, 0, .65),
			"sword": Vector3(0, 0, .36)},
		{"t": .55}
	])
	_add_animation("defeat", 1.05, [
		{"t": 0.0},
		{"t": .27, "body_y": Vector3(-.14, .69, 0), "body": Vector3(0, 0, -.28),
			"head": Vector3(0, 0, .22), "arm_r": Vector3(0, 0, -.35),
			"sword": Vector3(0, 0, -.90)},
		{"t": .65, "body_y": Vector3(-.30, .35, 0), "body": Vector3(0, 0, -.98),
			"arm_r": Vector3(0, 0, -1.14), "arm_l": Vector3(0, 0, .55),
			"leg_r": Vector3(0, 0, -.53), "leg_l": Vector3(0, 0, .38),
			"hem": Vector3(0, 0, -.24), "sword": Vector3(0, 0, -1.35)},
		{"t": 1.05, "body_y": Vector3(-.30, .35, 0), "body": Vector3(0, 0, -.98),
			"arm_r": Vector3(0, 0, -1.14), "arm_l": Vector3(0, 0, .55),
			"leg_r": Vector3(0, 0, -.53), "leg_l": Vector3(0, 0, .38)}
	])


func _add_animation(clip: String, duration: float, keyframes: Array, loop: bool = false) -> void:
	var paths := {
		"body_y": "Rig/BodyPivot:position", "body": "Rig/BodyPivot:rotation",
		"head": "Rig/BodyPivot/HeadPivot:rotation",
		"arm_r": "Rig/BodyPivot/RightArmPivot:rotation",
		"arm_l": "Rig/BodyPivot/LeftArmPivot:rotation",
		"leg_r": "Rig/RightLegPivot:rotation",
		"leg_l": "Rig/LeftLegPivot:rotation",
		"hem": "Rig/BodyPivot/HemPivot:rotation",
		"sword": "Rig/BodyPivot/RightArmPivot/SwordGrip:rotation"
	}
	var defaults := {
		"body_y": Vector3(0, .86, 0), "body": Vector3.ZERO,
		"head": Vector3.ZERO,
		"arm_r": Vector3(.35, 0, 0) if fighter_kind == "dummy" else Vector3.ZERO,
		"arm_l": Vector3(-.60, 0, 0) if fighter_kind == "dummy" else Vector3.ZERO,
		"leg_r": Vector3.ZERO, "leg_l": Vector3.ZERO, "hem": Vector3.ZERO,
		"sword": Vector3(0, 0, -.45 if fighter_kind == "dummy" else -.35)
	}
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for key in paths:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(paths[key]))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for frame in keyframes:
			var value: Vector3 = frame.get(key, defaults[key])
			if fighter_kind == "dummy" and key == "arm_r":
				value.x = .35
			elif fighter_kind == "dummy" and key == "arm_l":
				value.x = -.60
			animation.track_insert_key(track, float(frame["t"]), value)
	var contact := get_contact_time(clip)
	if contact >= 0.0:
		var contact_track := animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(contact_track, NodePath("."))
		animation.track_insert_key(contact_track, contact,
			{"method": "_emit_contact_key", "args": [clip]})
	_library.add_animation(clip, animation)


func _emit_contact_key(clip: String) -> void:
	# `seek(..., true)` may queue a method-track call for the next frame. The
	# authoring sampler seeks the live actor, then restarts the clip; reject that
	# stale call by checking the active animation clock before emitting.
	if _contact_emitted or _player.current_animation != clip \
			or _player.current_animation_position + .025 < get_contact_time(clip):
		return
	_contact_emitted = true
	contact_key.emit(clip)


func _on_animation_finished(clip: StringName) -> void:
	if clip != &"defeat":
		_player.play("idle")
	action_finished.emit(String(clip))
