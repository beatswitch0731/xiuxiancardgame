extends SceneTree

# Native, editable mesh world for the Cangmang Sect sword trial.  No scene
# painting, screen projection, imported illustration, or textured billboard.
const OUT := "res://scenes/cangmang_real_3d_world.tscn"
const STONE_SHADER := preload("res://shaders/cangmang_real_3d_stone.gdshader")

var _root: Node3D
var _material: Dictionary = {}
var _piece_count := 0


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "CangmangReal3DWorld"
	_make_materials()
	_ground_and_court()
	_mountain_gate()
	_side_gallery(-1)
	_side_gallery(1)
	_training_equipment(-7.05)
	_training_equipment(7.05)
	_lantern(-5.55, -3.55)
	_lantern(5.55, -3.55)
	_hills_and_trees()
	_lighting()
	_weather()
	var scene := PackedScene.new()
	var packed := scene.pack(_root)
	var saved := ResourceSaver.save(scene, OUT) if packed == OK else FAILED
	if saved != OK:
		push_error("Cannot save real Cangmang world: %s" % saved)
		quit(1)
		return
	print("CANGMANG_REAL_3D_READY pieces=%d scene=%s" % [_piece_count, OUT])
	_root.free()
	quit()


func _make_materials() -> void:
	_material["earth"] = _mat(Color("17232b"), 0.95)
	_material["stone_dark"] = _stone_mat(Color("394d57"), 0.32)
	_material["stone_mid"] = _stone_mat(Color("66757c"), 0.48)
	_material["stone_blue"] = _stone_mat(Color("657d89"), 0.44)
	_material["stone_light"] = _stone_mat(Color("939b9b"), 0.28)
	_material["stone_warm"] = _stone_mat(Color("85867d"), 0.37)
	_material["wet_stone"] = _stone_mat(Color("607782"), 0.85)
	_material["wet_highlight"] = _stone_mat(Color("7d8d8d"), 0.91)
	_material["mortar"] = _mat(Color("19272f"), 0.92)
	_material["timber"] = _mat(Color("463f37"), 0.72)
	_material["timber_edge"] = _mat(Color("796b4c"), 0.57)
	_material["roof"] = _mat(Color("263943"), 0.65)
	_material["roof_tile"] = _mat(Color("49606a"), 0.48)
	_material["roof_ridge"] = _mat(Color("172932"), 0.72)
	_material["bronze"] = _mat(Color("9b8051"), 0.38, 0.44)
	_material["bronze_dark"] = _mat(Color("5f563e"), 0.44, 0.35)
	_material["sect_cloth"] = _mat(Color("704541"), 0.93)
	_material["sect_cloth"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_material["iron"] = _mat(Color("394448"), 0.44, 0.56)
	_material["rope"] = _mat(Color("94846b"), 0.85)
	_material["foliage"] = _mat(Color("263e3e"), 0.92)
	_material["foliage_lit"] = _mat(Color("385450"), 0.92)
	_material["distant_rock"] = _mat(Color("455f6b"), 0.96)
	_material["distant_rock_mid"] = _mat(Color("374e59"), 0.96)
	_material["distant_rock_far"] = _mat(Color("67808a"), 0.96)
	for ridge_key in ["distant_rock", "distant_rock_mid", "distant_rock_far"]:
		_material[ridge_key].shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material[ridge_key].cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := _mat(Color("e6af55"), 0.7)
	glow.emission_enabled = true
	glow.emission = Color("e9a856")
	glow.emission_energy_multiplier = 2.0
	_material["fire"] = glow


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	result.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return result


func _stone_mat(color: Color, wetness: float) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = STONE_SHADER
	result.set_shader_parameter("base_tint", color)
	result.set_shader_parameter("wetness", wetness)
	return result


func _group(name: String, parent: Node3D = null) -> Node3D:
	var node := Node3D.new()
	node.name = name
	var target := parent if parent != null else _root
	target.add_child(node)
	node.owner = _root
	return node


func _mesh(name: String, mesh: Mesh, material: Material, at: Vector3,
		parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.material_override = material
	node.position = at
	var target := parent if parent != null else _root
	target.add_child(node)
	node.owner = _root
	_piece_count += 1
	return node


func _box(name: String, size: Vector3, material: Material, at: Vector3,
		parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(name, shape, material, at, parent)


func _cylinder(name: String, radius: float, height: float, material: Material,
		at: Vector3, parent: Node3D = null, sides: int = 16) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	return _mesh(name, shape, material, at, parent)


func _beam(name: String, a: Vector3, b: Vector3, radius: float,
		material: Material, parent: Node3D = null, sides: int = 10) -> MeshInstance3D:
	var center := (a + b) * 0.5
	var beam := _cylinder(name, radius, a.distance_to(b), material, center, parent, sides)
	beam.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return beam


func _beveled_slab(name: String, at: Vector3, size: Vector3,
		material: Material, parent: Node3D = null, bevel: float = 0.045) -> void:
	_mesh(name, _beveled_mesh(size, bevel), material, at, parent)


func _beveled_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	# Eight points per height band yield clipped corners and sloped rim, so each
	# floor paver has actual mesh depth instead of looking like a flat texture.
	var x := size.x * 0.5
	var z := size.z * 0.5
	var b := minf(bevel, minf(x, z) * 0.24)
	var shoulder := PackedVector3Array([
		Vector3(-x+b, 0, -z), Vector3(x-b, 0, -z),
		Vector3(x, 0, -z+b), Vector3(x, 0, z-b),
		Vector3(x-b, 0, z), Vector3(-x+b, 0, z),
		Vector3(-x, 0, z-b), Vector3(-x, 0, -z+b)])
	var top: Array[Vector3] = []
	var edge: Array[Vector3] = []
	var base: Array[Vector3] = []
	for point in shoulder:
		top.append(Vector3(point.x * (1.0-b/maxf(x,0.01)), size.y*0.5, point.z * (1.0-b/maxf(z,0.01))))
		edge.append(Vector3(point.x, size.y*0.5-b, point.z))
		base.append(Vector3(point.x, -size.y*0.5, point.z))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 8:
		var next := (index + 1) % 8
		_tri(surface, Vector3(0, size.y*0.5, 0), top[next], top[index])
		_quad(surface, top[index], top[next], edge[next], edge[index])
		_quad(surface, edge[index], edge[next], base[next], base[index])
	surface.generate_normals()
	return surface.commit()


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)


func _ground_and_court() -> void:
	var court := _group("StoneTrialCourt")
	_box("EarthFoundation", Vector3(22.0, 0.42, 17.0), _material["earth"], Vector3(0, -0.35, -1.0), court)
	_box("MortarBed", Vector3(17.7, 0.12, 12.2), _material["mortar"], Vector3(0, -0.11, -0.9), court)
	var paver_groups := {"wet_stone": [], "stone_mid": [], "wet_highlight": []}
	for row in 14:
		for column in 20:
			# Alternating joints, irregular but deterministic lengths and wet color.
			var x := (float(column) - 9.5) * 0.86 + (0.43 if row % 2 == 1 else 0.0)
			var z := (float(row) - 6.5) * 0.83 - 0.9
			if absf(x) > 8.68:
				continue
			var mark := (row * 17 + column * 11) % 13
			var material_key := "wet_stone" if mark < 5 else "stone_mid"
			if mark == 12:
				material_key = "wet_highlight"
			var height := 0.059 + float(mark % 3) * 0.006
			var length_variation := 0.965 + float((row*3+column*7)%5)*0.009
			var basis := Basis().scaled(Vector3(length_variation, height/0.065,
				0.98+float((row*9+column)%3)*0.009))
			paver_groups[material_key].append(Transform3D(basis,
				Vector3(x, -0.003+height*0.5, z)))
	var shared_paver := _beveled_mesh(Vector3(0.846,0.065,0.813),0.018)
	for key in paver_groups:
		var transforms: Array = paver_groups[key]
		_mesh("BeveledPavers_%s" % key,
			_combined_pavers(shared_paver, transforms), _material[key],
			Vector3.ZERO, court)
		_piece_count += transforms.size()
	# The ceremonial border is a thin cut-stone geometry frame, not a decal.
	for side in [-1, 1]:
		for index in 14:
			_beveled_slab("SideCoping_%s_%02d" % [side, index],
				Vector3(float(side) * 8.86, 0.105, -6.35 + float(index) * 0.84),
				Vector3(0.36, 0.21, 0.78), _material["stone_light"], court, 0.034)
	# The ring is lightly carved into the floor and leaves fighters unobstructed.
	for index in 48:
		var angle_a := TAU * float(index) / 48.0
		var angle_b := TAU * float(index + 1) / 48.0
		var a := Vector3(cos(angle_a) * 3.85, 0.061, sin(angle_a) * 2.25 - 0.15)
		var b := Vector3(cos(angle_b) * 3.85, 0.061, sin(angle_b) * 2.25 - 0.15)
		_beam("TrialRing_Inlay_%02d" % index, a, b, 0.017, _material["bronze_dark"], court, 6)


func _combined_pavers(prototype: ArrayMesh, transforms: Array) -> ArrayMesh:
	# One ArrayMesh per wet-stone palette. Each stone retains bevel geometry and
	# independently calculated position, but only three court draw calls remain.
	var source_arrays := prototype.surface_get_arrays(0)
	var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for transform in transforms:
		for vertex in vertices:
			surface.add_vertex(transform * vertex)
	surface.generate_normals()
	return surface.commit()


func _mountain_gate() -> void:
	var gate := _group("SectMountainGate")
	# Stone terrace rises behind the combat floor; its five full-width steps
	# disclose depth when the camera shifts, without blocking the battle lane.
	for level in 5:
		var height := 0.12 * float(level + 1)
		var z := -4.60 - 0.34 * float(level)
		_beveled_slab("TrialStep_%02d" % level, Vector3(0, height * 0.5, z),
			Vector3(6.6, height, 0.36), _material["stone_warm"], gate, 0.055)
	_beveled_slab("UpperLanding", Vector3(0, 0.33, -7.14),
		Vector3(7.55, 0.62, 2.75), _material["stone_mid"], gate, 0.09)
	for side in [-1, 1]:
		var x := float(side) * 2.73
		_beveled_slab("ColumnFoot_%s" % side, Vector3(x, 0.80, -6.72),
			Vector3(0.94, 0.34, 0.94), _material["stone_light"], gate, 0.06)
		_cylinder("TimberPillar_%s" % side, 0.235, 3.47,
			_material["timber"], Vector3(x, 2.73, -6.72), gate, 20)
		for y in [1.11, 4.28]:
			_cylinder("BronzeColumnBand_%s_%s" % [side, y], 0.252, 0.078,
				_material["bronze_dark"], Vector3(x, y, -6.72), gate, 20)
		_beveled_slab("BracketFoot_%s" % side, Vector3(x, 4.55, -6.72),
			Vector3(0.91, 0.20, 0.92), _material["timber_edge"], gate, 0.045)
		# Dou-gong brackets visibly carry the cantilevered tiled roof.
		for depth in [-0.72, 0.72]:
			_beam("SplayedBracket_%s_%s" % [side, depth],
				Vector3(x, 4.47, -6.72), Vector3(x + float(side) * 0.49, 4.86, -6.72 + depth),
				0.092, _material["timber_edge"], gate, 8)
	_box("GateLintel", Vector3(6.03, 0.31, 0.61), _material["timber"],
		Vector3(0, 4.46, -6.72), gate)
	_box("LintelBronzeTrim", Vector3(6.20, 0.045, 0.67), _material["bronze_dark"],
		Vector3(0, 4.62, -6.72), gate)
	_build_roof(gate, "MainCurvedEave", Vector3(0, 4.82, -6.72), 4.13, 1.40, 0.0)
	# A small carved dimensional sword emblem takes the place of a blank sign.
	_beveled_slab("SectTablet", Vector3(0, 3.58, -6.17),
		Vector3(1.48, 0.79, 0.12), _material["timber"], gate, 0.08)
	_beam("EmblemBladeA", Vector3(-0.36, 3.38, -6.09), Vector3(0.32, 3.84, -6.09),
		0.033, _material["bronze"], gate, 6)
	_beam("EmblemBladeB", Vector3(0.36, 3.38, -6.09), Vector3(-0.32, 3.84, -6.09),
		0.033, _material["bronze"], gate, 6)
	for side in [-1, 1]:
		var x := float(side) * 3.56
		_beveled_slab("GateEndStone_%s" % side, Vector3(x, 0.58, -6.72),
			Vector3(0.50, 1.16, 0.88), _material["stone_mid"], gate, 0.07)
		_cylinder("EndFinial_%s" % side, 0.17, 0.30,
			_material["bronze_dark"], Vector3(x, 1.28, -6.72), gate, 14)
		_hanging_banner(gate, side)


func _hanging_banner(parent: Node3D, side: int) -> void:
	# Thin cloth has sculpted waves and a torn lower edge.  It is an object in
	# the world, seen from the side when the camera moves, never screen-aligned.
	var banner := _group("SwordTrialBanner_%s" % side, parent)
	banner.position = Vector3(float(side)*3.40, 3.99, -6.38)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 12:
		for column in 4:
			var a := _banner_vertex(row,column,side)
			var b := _banner_vertex(row,column+1,side)
			var c := _banner_vertex(row+1,column+1,side)
			var d := _banner_vertex(row+1,column,side)
			_quad(surface,a,b,c,d)
	surface.generate_normals()
	_mesh("FoldedCrimsonCloth",surface.commit(),_material["sect_cloth"],Vector3.ZERO,banner)
	_beam("UpperBronzeRod",Vector3(-0.32,0.01,0),Vector3(0.32,0.01,0),
		0.035,_material["bronze_dark"],banner,8)
	_beam("SwordStitch",Vector3(-0.14,-0.53,0.067),Vector3(0.13,-1.02,0.067),
		0.016,_material["bronze"],banner,6)
	_beam("SwordGuard",Vector3(-0.09,-0.91,0.070),Vector3(0.14,-0.77,0.070),
		0.012,_material["bronze"],banner,6)


func _banner_vertex(row: int, column: int, side: int) -> Vector3:
	var u := float(column)/4.0
	var v := float(row)/12.0
	var flutter := sin(v*7.2+float(side)*0.7)*0.055*v
	var fray := (0.14 if column==3 else 0.02 if column==1 else 0.0)*pow(v,7.0)
	return Vector3((u-0.5)*0.47+flutter,-v*2.04+fray,
		0.035*sin(u*PI*4.0+v*3.0)+0.018*u)


func _roof_y(x: float, half_width: float) -> float:
	var u := absf(x) / half_width
	# Shallow sag with lifted ends, characteristic of Chinese tiled eaves.
	return -0.60 * pow(u, 1.40) + 0.27 * pow(u, 9.0)


func _build_roof(parent: Node3D, name: String, origin: Vector3,
		half_width: float, half_depth: float, pitch_shift: float) -> void:
	var roof := _group(name, parent)
	roof.position = origin
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 32:
		var x0 := -half_width + 2.0 * half_width * float(column) / 32.0
		var x1 := -half_width + 2.0 * half_width * float(column + 1) / 32.0
		for side in [-1, 1]:
			var z0 := 0.0
			var z1 := float(side) * half_depth
			var front_drop := -0.29 + 0.11 * pow(absf(x0) / half_width, 8.0)
			var end_drop := -0.29 + 0.11 * pow(absf(x1) / half_width, 8.0)
			var a := Vector3(x0, _roof_y(x0, half_width), z0)
			var b := Vector3(x1, _roof_y(x1, half_width), z0)
			var c := Vector3(x1, _roof_y(x1, half_width) + end_drop + pitch_shift, z1)
			var d := Vector3(x0, _roof_y(x0, half_width) + front_drop + pitch_shift, z1)
			if side < 0:
				_quad(tool, a, b, c, d)
				_quad(tool, d + Vector3(0,-0.12,0), c + Vector3(0,-0.12,0),
					b + Vector3(0,-0.12,0), a + Vector3(0,-0.12,0))
				_quad(tool, d, c, c + Vector3(0,-0.12,0), d + Vector3(0,-0.12,0))
			else:
				_quad(tool, b, a, d, c)
				_quad(tool, c + Vector3(0,-0.12,0), d + Vector3(0,-0.12,0),
					a + Vector3(0,-0.12,0), b + Vector3(0,-0.12,0))
				_quad(tool, c, d, d + Vector3(0,-0.12,0), c + Vector3(0,-0.12,0))
	tool.generate_normals()
	_mesh("CurvedSlateRoofMesh", tool.commit(), _material["roof"], Vector3.ZERO, roof)
	# Individual convex tile ribs and cross seams catch light as true geometry.
	for column in 31:
		var x := -half_width + 2.0 * half_width * float(column + 1) / 32.0
		for side in [-1, 1]:
			var z_end := float(side) * half_depth
			var y_center := _roof_y(x, half_width)
			var y_edge := y_center - 0.29 + 0.11 * pow(absf(x)/half_width, 8.0) + pitch_shift
			_beam("TileRib_%02d_%s" % [column, side],
				Vector3(x, y_center + 0.045, 0), Vector3(x, y_edge + 0.047, z_end),
				0.033, _material["roof_tile"], roof, 8)
	for side in [-1, 1]:
		var z_edge := float(side) * half_depth
		for column in 32:
			var x0 := -half_width + 2.0 * half_width * float(column) / 32.0
			var x1 := -half_width + 2.0 * half_width * float(column + 1) / 32.0
			var p0 := Vector3(x0, _roof_y(x0, half_width)-0.29+0.11*pow(absf(x0)/half_width,8.0)+pitch_shift, z_edge)
			var p1 := Vector3(x1, _roof_y(x1, half_width)-0.29+0.11*pow(absf(x1)/half_width,8.0)+pitch_shift, z_edge)
			_beam("EaveLip_%s_%02d" % [side,column], p0, p1,
				0.085, _material["roof_ridge"], roof, 10)
	_beam("RoofCrest", Vector3(-half_width*0.86,0.075,0),
		Vector3(half_width*0.86,0.075,0), 0.10, _material["roof_ridge"], roof, 12)
	for side in [-1, 1]:
		var x := float(side) * half_width
		var y := _roof_y(x, half_width)
		_cylinder("BronzeRoofFinial_%s" % side, 0.10, 0.30,
			_material["bronze_dark"], Vector3(x, y + 0.15, 0), roof, 12)


func _side_gallery(side: int) -> void:
	var gallery := _group("WestGallery" if side < 0 else "EastGallery")
	var x := float(side) * 8.2
	_beveled_slab("GalleryPlatform", Vector3(x, 0.18, -6.72),
		Vector3(4.55, 0.36, 3.35), _material["stone_dark"], gallery, 0.075)
	for index in 3:
		var cx := x + float(index - 1) * 1.65
		for depth in [-1, 1]:
			var z := -6.72 + float(depth) * 1.15
			_beveled_slab("Foot_%d_%s" % [index,depth], Vector3(cx,0.53,z),
				Vector3(0.49,0.31,0.49), _material["stone_mid"],gallery,0.04)
			_cylinder("TimberCol_%d_%s" % [index,depth],0.135,2.30,
				_material["timber"],Vector3(cx,1.83,z),gallery,12)
			_cylinder("ColumnCap_%d_%s" % [index,depth],0.19,0.08,
				_material["bronze_dark"],Vector3(cx,2.95,z),gallery,12)
	_build_roof(gallery,"TiledGalleryEave",Vector3(x,3.17,-6.72),2.54,1.93,-0.12)
	for index in 5:
		var cx := x + float(index - 2) * 0.93
		_beveled_slab("RearStoneRail_%02d" % index,
			Vector3(cx,0.95,-8.13),Vector3(0.78,1.12,0.26),
			_material["stone_mid"],gallery,0.045)
		_beveled_slab("RearRailCap_%02d" % index,
			Vector3(cx,1.54,-8.13),Vector3(0.84,0.12,0.35),
			_material["stone_light"],gallery,0.025)
	# Thin ties give the pavilion a constructed silhouette rather than a cube.
	for depth in [-1,1]:
		_beam("LongTie_%s" % depth,
			Vector3(x-1.7,2.92,-6.72+float(depth)*1.15),
			Vector3(x+1.7,2.92,-6.72+float(depth)*1.15),
			0.08,_material["timber_edge"],gallery,8)


func _training_equipment(x: float) -> void:
	var setup := _group("PracticeStation_%s" % x)
	setup.position = Vector3(x, 0.0, -1.72)
	_beveled_slab("AnchorStone",Vector3(0,0.10,0),Vector3(1.23,0.19,1.17),
		_material["stone_mid"],setup,0.055)
	_cylinder("RoundTimberCore",0.16,1.83,_material["timber"],Vector3(0,1.03,0),setup,18)
	_cylinder("UpperFerrule",0.20,0.10,_material["iron"],Vector3(0,1.82,0),setup,18)
	_cylinder("LowerFerrule",0.20,0.10,_material["iron"],Vector3(0,0.54,0),setup,18)
	for side in [-1,1]:
		_beam("PracticeArm_%s" % side,Vector3(0,1.48,0),
			Vector3(float(side)*0.56,1.38,0.03),0.072,
			_material["timber_edge"],setup,10)
		_beam("DiagonalBrace_%s" % side,Vector3(0,0.62,0),
			Vector3(float(side)*0.37,0.11,0.30),0.070,
			_material["timber"],setup,8)
	for band in 4:
		_cylinder("RopeCollar_%02d" % band,0.18,0.025,
			_material["rope"],Vector3(0,1.07+float(band)*0.045,0),setup,18)
	# The sword rack sits behind the dummy, not across the fighters.
	for side in [-1,1]:
		_cylinder("RackPost_%s" % side,0.066,0.76,
			_material["timber"],Vector3(float(side)*0.70,0.38,-0.65),setup,10)
	_beam("RackCrossbar",Vector3(-0.70,0.70,-0.65),Vector3(0.70,0.70,-0.65),
		0.055,_material["timber_edge"],setup,10)
	for index in 3:
		var sx := -0.38+float(index)*0.38
		_beam("WoodSword_%02d" % index,Vector3(sx,0.73,-0.64),
			Vector3(sx+0.04,0.99,-0.84),0.025,_material["timber_edge"],setup,6)


func _lantern(x: float, z: float) -> void:
	var lamp := _group("CourtyardLantern_%s" % x)
	lamp.position = Vector3(x,0,z)
	_beveled_slab("StonePlinth",Vector3(0,0.27,0),Vector3(0.73,0.53,0.73),
		_material["stone_mid"],lamp,0.065)
	_cylinder("CarvedShaft",0.19,1.52,_material["stone_warm"],Vector3(0,1.26,0),lamp,12)
	_beveled_slab("LampFoot",Vector3(0,2.07,0),Vector3(0.70,0.13,0.70),
		_material["stone_light"],lamp,0.03)
	for side_x in [-1,1]:
		for side_z in [-1,1]:
			_cylinder("LanternPier_%s_%s" % [side_x,side_z],0.042,0.57,
				_material["stone_light"],Vector3(float(side_x)*0.25,2.42,float(side_z)*0.25),lamp,8)
	_cylinder("ContainedFlame",0.11,0.30,_material["fire"],Vector3(0,2.39,0),lamp,9)
	_beveled_slab("LampRoof",Vector3(0,2.77,0),Vector3(0.84,0.15,0.84),
		_material["stone_dark"],lamp,0.035)
	_cylinder("RoofTip",0.095,0.18,_material["bronze_dark"],Vector3(0,2.91,0),lamp,10)
	var glow := OmniLight3D.new()
	glow.name = "WarmLanternLight"
	glow.light_color = Color("efb371")
	glow.light_energy = 1.65
	glow.omni_range = 6.1
	# The directional rain key casts the scene shadow; two omni shadow maps
	# multiplied geometry passes without a visible gain in the battle viewport.
	glow.shadow_enabled = false
	glow.position = Vector3(0,2.43,0)
	lamp.add_child(glow)
	glow.owner = _root


func _hills_and_trees() -> void:
	var distant := _group("DimensionalMountainHorizon")
	# Three contiguous sculpted ridges replace the toy-like stack of cones.
	# Their front-to-back slopes are true triangulated terrain and show parallax.
	_ridge(distant,"NearWetRidge",-12.3,0,_material["distant_rock_mid"])
	_ridge(distant,"MiddleFogRidge",-18.0,1,_material["distant_rock"])
	_ridge(distant,"FarHorizon",-25.0,2,_material["distant_rock_far"])
	for side in [-1,1]:
		for index in 4:
			var tx := float(side)*(11.0+float(index%2)*1.20)
			var tz := -9.5+float(index)*1.9
			var tree := _group("WindBentPine_%s_%02d" % [side,index],distant)
			tree.position=Vector3(tx,0,tz)
			var bend := float(side)*0.28
			_beam("TwistedTrunk",Vector3(0,0,0),Vector3(bend,2.45,0.12),
				0.105,_material["timber"],tree,9)
			for layer in 3:
				var y := 1.39+float(layer)*0.49
				var scale := 0.56-float(layer)*0.11
				var crown := SphereMesh.new()
				crown.radius = scale
				crown.height = 0.88-float(layer)*0.14
				crown.radial_segments = 11
				crown.rings = 6
				_mesh("PineCanopy_%02d" % layer,crown,
					_material["foliage_lit"] if layer==2 else _material["foliage"],
					Vector3(bend*0.8+float(layer%2)*0.24,y,0.02),tree)


func _ridge(parent: Node3D, name: String, depth: float, layer: int,
		material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 72:
		for strip in 3:
			var a := _ridge_vertex(column,strip,depth,layer)
			var b := _ridge_vertex(column+1,strip,depth,layer)
			var c := _ridge_vertex(column+1,strip+1,depth,layer)
			var d := _ridge_vertex(column,strip+1,depth,layer)
			_quad(surface,b,a,d,c)
	surface.generate_normals()
	_mesh(name,surface.commit(),material,Vector3.ZERO,parent)


func _ridge_vertex(column: int, strip: int, depth: float, layer: int) -> Vector3:
	var x := -25.0+float(column)*0.69
	var phase := float(layer)*1.73
	var ridge_height := 3.25+sin(x*0.17+phase)*1.13+sin(x*0.43+phase*1.91)*0.69
	ridge_height += sin(x*0.88+phase*3.1)*0.28+sin(x*1.72+phase*2.0)*0.11
	ridge_height += float(layer)*0.74
	var z_offsets := [-3.2,-1.2,0.5,2.3]
	var heights := [0.57,1.0,0.61,-0.20]
	var depth_noise := sin(x*0.62+float(strip)*1.7+phase)*0.35
	return Vector3(x, ridge_height*heights[strip]-0.55,
		depth+z_offsets[strip]+depth_noise)


func _lighting() -> void:
	var key := DirectionalLight3D.new()
	key.name = "CoolRainKey"
	key.rotation_degrees = Vector3(-53.0,-24.0,0.0)
	key.light_color = Color("a3bec4")
	key.light_energy = 0.92
	key.shadow_enabled = true
	_root.add_child(key)
	key.owner = _root
	var floor_glint := OmniLight3D.new()
	floor_glint.name = "WetFloorCoolGlint"
	floor_glint.position = Vector3(0,5.4,2.1)
	floor_glint.light_color = Color("65889c")
	floor_glint.light_energy = 0.85
	floor_glint.omni_range = 14.0
	_root.add_child(floor_glint)
	floor_glint.owner = _root


func _weather() -> void:
	var rain := CPUParticles3D.new()
	rain.name = "SustainedMountainRain"
	rain.position = Vector3(0, 4.6, -1.3)
	rain.amount = 72
	rain.lifetime = 1.25
	rain.preprocess = 1.25
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(9.4, 2.6, 6.7)
	rain.direction = Vector3(-0.12, -1.0, 0.0)
	rain.spread = 6.0
	rain.gravity = Vector3(-0.55, -2.0, 0.0)
	rain.initial_velocity_min = 5.9
	rain.initial_velocity_max = 7.1
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.012, 0.19, 0.012)
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rain_material.albedo_color = Color(0.58, 0.75, 0.79, 0.31)
	drop_mesh.material = rain_material
	rain.mesh = drop_mesh
	_root.add_child(rain)
	rain.owner = _root
