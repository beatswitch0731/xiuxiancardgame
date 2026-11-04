extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const SourceStage = preload("res://scripts/duel_stage_source_2d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry = Registry.new()
	var context: Dictionary = StageRouter.new(registry).resolve_encounter(
		"enc_patrol_qi_mountain_shadow")
	context["path"] = "sword"
	context["deck"] = ["sword_probe", "sword_followthrough", "sword_guard",
		"sword_sheath_guard", "sword_edge"]
	var stage = SourceStage.new()
	if not stage.bind_stage_context(context):
		return _fail("mountain sword stage could not mount authored data")
	var actions: Dictionary = registry.read_json("data/combat/action_presentations.json")
	for card_id in ["sword_edge", "sword_probe", "sword_followthrough",
			"sword_sheath_guard"]:
		var authored: Dictionary = actions["cardActions"][card_id]
		var clip_key: String = String(authored["actionFamily"]) + "@" + card_id
		var clip: Dictionary = stage._clips.get("player", {}).get(clip_key, {})
		var cue: Dictionary = actions["sfxCues"][authored["sfxCueId"]]
		if clip.is_empty() or clip.get("frames", []).is_empty() \
				or clip["frames"][0] != registry.texture_for(authored["animation"]["frames"][0]) \
				or clip.get("durations") != authored["animation"]["frameDurations"] \
				or clip.get("startSfx") != cue.get("actionStarted", "") \
				or clip.get("contactSfx") != cue.get("impact", cue.get("statusApplied", "")):
			return _fail(card_id + " did not use its authored frame and cue contract")
	root.add_child(stage)
	await process_frame
	var started: Array = []
	var contacts: Array = []
	stage.action_started.connect(func(side: String, clip: String) -> void:
		started.append({"side": side, "clip": clip}))
	stage.contact_frame.connect(func(side: String) -> void:
		contacts.append(side))
	if not stage.present_action({"type": "CARD_PLAY", "cardId": "sword_followthrough",
			"effects": [{"type": "damage", "hpLoss": 1}]}):
		return _fail("sword followthrough rejected by mounted presentation")
	var finished: String = await stage.presentation_finished
	if started.is_empty() or started[0] != {"side": "player",
			"clip": "attack@sword_followthrough"} or contacts != ["player"] \
			or finished != "CARD_PLAY":
		return _fail("sword followthrough did not start its authored action")
	stage.queue_free()
	await process_frame
	print("NONCOMBAT_MOUNTAIN_CARD_ACTIONS_PASS cards=4 authored_frames=true authored_cues=true action_started=true contact=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
