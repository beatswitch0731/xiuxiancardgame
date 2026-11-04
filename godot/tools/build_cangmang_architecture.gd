extends SceneTree

# The first-fight source image already has a detailed mountain gate and trial
# ring. These native 3D posts sit over matching painted posts; a camera-space
# projection of the source art keeps their colors and pixel density coherent.

const OUT := "res://scenes/cangmang_trial_architecture.tscn"
const PROJECTED_SURFACE := preload("res://shaders/cangmang_projected_court.gdshader")

var _root: Node3D
var _projected_material: ShaderMaterial


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "CangmangTrialArchitecture"
	_projected_material = ShaderMaterial.new()
	_projected_material.shader = PROJECTED_SURFACE
	_training_post("LeftTrialPost", -7.25)
	_training_post("RightTrialPost", 7.25)
	var scene := PackedScene.new()
	var packed := scene.pack(_root)
	var saved := ResourceSaver.save(scene, OUT) if packed == OK else FAILED
	if saved != OK:
		push_error("Cannot build source-aligned 3D trial posts: " + str(saved))
		quit(1)
		return
	print("CANGMANG_ARCHITECTURE_READY nodes=", _root.get_child_count(), " scene=", OUT)
	_root.free()
	quit()


func _training_post(name: String, x: float) -> void:
	var post := Node3D.new()
	post.name = name
	post.position = Vector3(x, 0.0, -0.6)
	_root.add_child(post)
	post.owner = _root
	_cylinder(post, "StoneFoot", Vector3(0, 0.16, 0), 0.43, 0.32)
	_cylinder(post, "StoneInset", Vector3(0, 0.34, 0), 0.32, 0.08)
	_cylinder(post, "MainTimber", Vector3(0, 1.30, 0), 0.18, 1.88)
	_cylinder(post, "CappedHead", Vector3(0, 2.26, 0), 0.22, 0.13)
	_cylinder(post, "LeftPracticeArm", Vector3(-0.46, 1.63, 0), 0.09, 0.92, PI * 0.5)
	_cylinder(post, "RightPracticeArm", Vector3(0.46, 1.63, 0), 0.09, 0.92, PI * 0.5)
	_cylinder(post, "LowIronCollar", Vector3(0, 0.63, 0), 0.205, 0.075)
	_cylinder(post, "UpperIronCollar", Vector3(0, 2.02, 0), 0.205, 0.075)
	for band in 3:
		_cylinder(post, "RopeWrap_%d" % band,
			Vector3(0, 1.35 + 0.057 * band, 0), 0.205, 0.025)


func _cylinder(parent: Node3D, name: String, where: Vector3,
		radius: float, height: float, z_rotation: float = 0.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var piece := MeshInstance3D.new()
	piece.name = name
	piece.mesh = mesh
	piece.material_override = _projected_material
	piece.position = where
	piece.rotation.z = z_rotation
	parent.add_child(piece)
	piece.owner = _root
