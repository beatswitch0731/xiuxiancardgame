extends SceneTree

# A source-preserving motion study. It moves only upper-body pixel clusters;
# face, hands, weapons and the ground line must be reviewed before runtime use.
const OUTPUT := "res://assets/source_first_fight/breath_v17/"
const ACTORS := {
	"yelingyun": {
		"source": "res://content/assets/combat/protagonist/growth_matrix_agc_v6/S1_outer_novice/sword.png",
		"center": 160.0, "bottom": 181.0,
		"left": 107.0, "right": 207.0, "lift": 3.0, "spread": 0.060,
	},
	"quick_sword_dummy": {
		"source": "res://content/assets/combat/enemy/enc_trial_sword_swift_agc_m2/identity/intent-1.png",
		"center": 164.0, "bottom": 215.0,
		"left": 108.0, "right": 214.0, "lift": -2.3, "spread": -0.035,
	},
}
const PHASES := [0.0, 0.55, 1.0, -0.35]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for actor_id in ACTORS:
		var recipe: Dictionary = ACTORS[actor_id]
		var source := Image.load_from_file(String(recipe["source"]))
		if source == null or source.get_size() != Vector2i(320, 320):
			push_error("Breath source missing or wrong canvas: " + String(recipe["source"]))
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		for phase_index in PHASES.size():
			var frame := _bake(source, recipe, PHASES[phase_index])
			var path := ProjectSettings.globalize_path(OUTPUT + actor_id + "_%02d.png" % phase_index)
			if frame.save_png(path) != OK:
				push_error("Could not write breath frame: " + path)
				quit(1)
				return
			print("BREATH_FRAME_READY actor=", actor_id, " phase=", phase_index, " path=", path)
	quit(0)


func _bake(source: Image, recipe: Dictionary, amount: float) -> Image:
	var frame := Image.create_empty(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	frame.fill(Color.TRANSPARENT)
	var bottom := float(recipe["bottom"])
	var center := float(recipe["center"])
	for y in source.get_height():
		var vertical_influence := 1.0 - smoothstep(bottom - 62.0, bottom, float(y))
		for x in source.get_width():
			var horizontal_influence := smoothstep(float(recipe["left"]), float(recipe["left"]) + 9.0, float(x)) \
				* (1.0 - smoothstep(float(recipe["right"]) - 9.0, float(recipe["right"]), float(x)))
			var influence := vertical_influence * horizontal_influence
			var source_y := clampi(y + roundi(amount * float(recipe["lift"]) * influence), 0, source.get_height() - 1)
			var expansion := 1.0 + amount * float(recipe["spread"]) * influence
			var source_x := clampi(roundi(center + (float(x) - center) / expansion), 0, source.get_width() - 1)
			frame.set_pixel(x, y, source.get_pixel(source_x, source_y))
	return frame
