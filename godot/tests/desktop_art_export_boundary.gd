extends SceneTree


func _initialize() -> void:
	var required := [
		"res://art_direction/battlefield_art_catalog.json",
		"res://content/data/combat/action_presentations.json",
	]
	var rejected_source := "res://art_source/actor_v5_pixel_qa/yelingyun_idle_raw_v2.png"
	for path in required:
		if not FileAccess.file_exists(path):
			push_error("DESKTOP_ART_EXPORT_MISSING " + path)
			quit(1)
			return
	if FileAccess.file_exists(rejected_source):
		push_error("DESKTOP_ART_EXPORT_LEAK " + rejected_source)
		quit(1)
		return
	print("DESKTOP_ART_EXPORT_BOUNDARY_PASS runtime_json=2 rejected_source=excluded")
	quit()
