extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const RebirthFlow = preload("res://scripts/noncombat_rebirth_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/companion_portrait_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not game.has_method("portrait_options") or not game.has_method("select_portrait"):
		return _fail("desktop companion portrait selection is unavailable")
	if not game.start("sword") or not game.choose("right", game.issue_choice_token()):
		return _fail("source run did not enter a saved decision")
	var options: Array = game.portrait_options("bai_luoxuan")
	if options.size() != 2 or options[0].get("id") != "bai_luoxuan_trapped" \
			or options[1].get("id") != "bai_luoxuan_meet":
		return _fail("source affection gate did not return the unlocked stage")
	if game.select_portrait("bai_luoxuan", "bai_luoxuan_bonded"):
		return _fail("locked portrait was accepted")
	var prior: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.select_portrait("bai_luoxuan", "bai_luoxuan_trapped") \
			or game.state != prior \
			or FileAccess.get_file_as_string(game._store.v2_path) != bytes:
		return _fail("failed portrait write leaked into the run")
	if not game.select_portrait("bai_luoxuan", "bai_luoxuan_trapped"):
		return _fail("unlocked stage was rejected")
	game = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not game.restore() or game.state.get("companionCosmetics", {}).get(
			"selectedPortraitByNpc", {}).get("bai_luoxuan") != "bai_luoxuan_trapped":
		return _fail("selected portrait did not survive strict cold replay")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("portrait selection blocked the next source decision")
	game = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not game.restore():
		return _fail("selected portrait was lost after another decision")
	if game.portrait_options("jiuwei").is_empty() \
			or not game.select_portrait("jiuwei", "jiuwei_suyue_regal") \
			or game.state.get("companionCosmetics", {}).get(
				"selectedPortraitByNpc", {}).get("jiuwei_suyue") != "jiuwei_suyue_regal":
		return _fail("source NPC portrait alias did not resolve to the canonical ID")
	game = Domain.new(Registry.new(), Session.new(path, "slot_1"), "slot_1")
	if not game.restore():
		return _fail("canonical portrait alias did not survive strict replay")
	var other_path := "user://tests/companion_portrait_other_%d.json" % Time.get_ticks_usec()
	var other = Domain.new(Registry.new(), Session.new(other_path, "slot_3"), "slot_3")
	if not other.start("sword") or other.state.has("companionCosmetics"):
		return _fail("a different save slot inherited the selected portrait")
	var terminal: Dictionary = game.state.duplicate(true)
	terminal["phase"] = "DEATH_PENDING"
	terminal["lifePhase"] = "DYING_NARRATIVE"
	terminal["dead"] = true
	terminal["deathCauseId"] = "death_dao_collapse"
	terminal["currentCardId"] = "death_dao_collapse"
	terminal["lifeCount"] = 0
	terminal["lifeJournal"] = []
	var death_card: Dictionary = ContentRepository.new().find(
		"card", "death_dao_collapse").get("data", {})
	var rebirth = RebirthFlow.new()
	var newborn: Dictionary = rebirth.new_life(
		terminal, death_card, "left", "slot_1")
	if newborn.is_empty() or newborn.get("companionCosmetics", {}) != \
			game.state.get("companionCosmetics", {}) \
			or newborn.has("companionPortraitHistory"):
		return _fail("portrait cosmetics did not cross lives without old-life actions: "
			+ rebirth.last_error + " newborn=" + JSON.stringify(newborn.get(
				"companionCosmetics", {})))
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = path
	root.add_child(ui)
	await process_frame
	if ui.opening.state.is_empty():
		return _fail("desktop slot did not restore for portrait UI")
	ui.opening.state.resources.companions = ["bai_luoxuan"]
	ui.opening.state.companionProgress.states["bai_luoxuan"] = {}
	ui.opening.state.npcAffection = {"bai_luoxuan": 80}
	ui._render()
	if not ui.companion_portrait_button.visible:
		return _fail("owned companion has no visible portrait entry")
	ui.companion_portrait_button.emit_signal("pressed")
	if ui.companion_portrait_dialog == null or not ui.companion_portrait_dialog.visible:
		return _fail("portrait entry did not open source stage choices")
	var clicked := false
	for button in ui.companion_portrait_dialog.find_children("*", "Button", true, false):
		if button.text.begins_with("初见报恩") and not button.disabled:
			button.emit_signal("pressed")
			clicked = true
			break
	if not clicked or ui.opening.state.get("companionCosmetics", {}).get(
			"selectedPortraitByNpc", {}).get("bai_luoxuan") != "bai_luoxuan_meet" \
			or ui.companion_portrait_rect.texture != ui.registry.texture_for(
				"assets/characters/stages/bai_luoxuan_meet.png"):
		return _fail("source stage click did not update the persistent HUD portrait")
	print("NONCOMBAT_COMPANION_PORTRAIT_PASS gate=true rollback=true replay=true slots=true rebirth=true ui=true alias=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
