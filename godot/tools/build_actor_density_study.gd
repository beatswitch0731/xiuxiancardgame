extends SceneTree

# Make an isolated density comparison from the existing full-resolution key art.
# These are review stills, not approved animation frames or replacement sprites.
const OUT := "res://assets/characters/actor_candidates/density_v1/"
const SAMPLES := [
	{
		"name": "yelingyun_idle_512",
		"source": "res://art_source/actor_v8_keypose_qa/yelingyun_idle_inhale_raw_v1.png",
		"source_body": Rect2i(425, 93, 424, 1109),
		"body_height": 450,
		"foot_y": 486,
	},
	{
		"name": "quick_sword_dummy_idle_512",
		"source": "res://art_source/actor_v8_keypose_qa/quick_sword_dummy_idle_compression_raw_v1.png",
		"source_body": Rect2i(447, 600, 416, 556),
		"body_height": 420,
		"foot_y": 486,
	},
	{
		"name": "yelingyun_identity_detail_512",
		"source": "res://art_source/actor_v19_density_qa/yelingyun_identity_detail_raw_v1.png",
		"source_body": Rect2i(418, 51, 450, 1148),
		"body_height": 450,
		"foot_y": 486,
	},
	{
		"name": "yelingyun_micro_pixel_512",
		"source": "res://art_source/actor_v19_density_qa/yelingyun_micro_pixel_raw_v2.png",
		"source_body": Rect2i(395, 23, 472, 1196),
		"body_height": 450,
		"foot_y": 486,
	},
	{
		"name": "yelingyun_pen_ink_512",
		"source": "res://art_source/actor_v19_density_qa/yelingyun_pen_ink_raw_v3.png",
		"source_body": Rect2i(415, 33, 468, 1184),
		"body_height": 450,
		"foot_y": 486,
	},
	{
		"name": "quick_sword_dummy_pen_ink_512",
		"source": "res://art_source/actor_v19_density_qa/quick_sword_dummy_pen_ink_raw_v1.png",
		"source_body": Rect2i(210, 74, 848, 1104),
		"body_height": 420,
		"foot_y": 486,
	},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sample in SAMPLES:
		var source: Image = Image.load_from_file(ProjectSettings.globalize_path(String(sample.source)))
		if source == null or source.is_empty():
			push_error("Density study source missing: " + String(sample.source))
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var body: Image = source.get_region(sample.source_body)
		# The raw key art carries a near-transparent generation halo. Keep real
		# edge antialiasing while discarding alpha <= 16/255 before downsampling.
		for y in body.get_height():
			for x in body.get_width():
				var color := body.get_pixel(x, y)
				if color.a <= 16.0 / 255.0:
					body.set_pixel(x, y, Color.TRANSPARENT)
		var target_height: int = sample.body_height
		var target_width := roundi(float(body.get_width()) * target_height / body.get_height())
		body.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create_empty(512, 512, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var origin := Vector2i((512 - target_width) / 2, int(sample.foot_y) - target_height)
		canvas.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), origin)
		var output := OUT + String(sample.name) + ".png"
		if canvas.save_png(ProjectSettings.globalize_path(output)) != OK:
			push_error("Could not save density study: " + output)
			quit(1)
			return
		print("ACTOR_DENSITY_STUDY name=", sample.name, " canvas=512x512 body_height=",
			target_height, " body_width=", target_width, " foot_y=", sample.foot_y,
			" source=", sample.source, " output=", output)
	quit(0)
