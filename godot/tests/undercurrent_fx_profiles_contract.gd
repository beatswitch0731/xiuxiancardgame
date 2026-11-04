extends SceneTree

const EXPECTED := {
	"sword_probe": "probe_opening",
	"sword_edge": "edge_intent",
	"sword_followthrough": "followthrough",
	"sword_guard": "guard_aegis",
	"sword_sheath_guard": "sheath_guard",
}
const CONTACT_MS := {
	"sword_probe": 235,
	"sword_edge": 210,
	"sword_followthrough": 220,
	"sword_guard": 180,
	"sword_sheath_guard": 210,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for card_id in EXPECTED:
		var battle: Control = load("res://scenes/main.tscn").instantiate()
		root.add_child(battle)
		await process_frame
		var stage: Node = battle.duel_stage
		if stage == null or stage.name != "QingyunPixelStage":
			_fail("first fight did not mount the pixel stage")
			return
		var card_button: Button
		for child in battle.hand_row.get_children():
			if child is Button and child.get_meta("source_card_id", "") == card_id:
				card_button = child
				break
		if card_button == null:
			_fail("starter card missing: " + card_id)
			return
		var hero: AnimatedSprite2D = stage.get_actor_sprite("player")
		var clip_duration: float = stage.call("_clip_duration", hero.sprite_frames, card_id)
		var contact_time: float = stage.call("_contact_time", hero.sprite_frames, card_id, clip_duration)
		if absf(contact_time * 1000.0 - CONTACT_MS[card_id]) > 25.0:
			_fail("contact timing differs from source action for " + card_id + ": " + str(contact_time))
			return
		var contacts: Array[String] = []
		stage.contact_frame.connect(func(side: String) -> void: contacts.append(side))
		card_button.pressed.emit()
		for _sample in 120:
			if "player" in contacts:
				break
			await create_timer(0.02).timeout
		if not "player" in contacts:
			_fail("contact missing: " + card_id)
			return
		await process_frame
		var fx: Node = stage.get_node("Viewport/World/HitFX")
		if fx.get("last_profile") != card_id or fx.get("last_style") != EXPECTED[card_id]:
			_fail("wrong effect at contact for " + card_id + ": " + str(fx.get("last_profile")) + "/" + str(fx.get("last_style")))
			return
		for _sample in 100:
			if battle.pending_presentations == 0 and not battle.combat.input_locked:
				break
			await create_timer(0.02).timeout
		if battle.pending_presentations != 0 or battle.combat.input_locked:
			_fail("presentation did not settle for " + card_id)
			return
		battle.queue_free()
		await process_frame
	print("UNDERCURRENT_FX_PROFILES_PASS cards=5 distinct=true guard_feedback=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
