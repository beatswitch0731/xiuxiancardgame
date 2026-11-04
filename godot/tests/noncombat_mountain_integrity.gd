extends "res://tests/noncombat_battle_return.gd"

class BrokenArt extends "res://scripts/noncombat_content_repository.gd":
	var mode := ""
	var target := ""
	func source_sha256(module_id: String) -> String:
		if not mode.is_empty() and target == "module:" + module_id:
			return ""
		return super.source_sha256(module_id)
	func module_path(module_id: String) -> String:
		if mode == "missing" and target == "module:" + module_id:
			return ""
		return super.module_path(module_id)
	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if not mode.is_empty() and path.ends_with(target):
			result.shaVerified = false
			result.textureLoadable = false
			if mode == "missing":
				result.fileExists = false
		return result

func _run() -> void:
	var file := "user://tests/mountain_integrity_%d.json" % Time.get_ticks_usec()
	var store = Session.new(file, "slot_2")
	var content := BrokenArt.new()
	var game = Domain.new(Registry.new(), store, "slot_2", content)
	if not game.start("sword"):
		return _fail("start")
	for direction in ["right", "right", "left", "left", "left"]:
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("teaching")
	if not game.submit_battle_result(_result(game.battle_request(), "victory")) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("first reward")
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		return _fail("inserted flow")
	if game.state.phase == "MILESTONE_PENDING" and not game.choose("left", game.issue_choice_token()):
		return _fail("chapter")
	var screen: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	screen.save_path = ""
	root.add_child(screen)
	await process_frame
	screen.opening = game
	screen._render()
	var button := screen.find_child("Choice_left", true, false)
	if game.state.currentCardId != "q_mountain_shadow_approach" or button == null \
			or button.disabled or screen.art_rect.texture == null:
		return _fail("desktop route left/image unavailable")
	button.pressed.emit()
	await process_frame
	if game.state.phase != "WARNING_PENDING":
		return _fail("desktop route click did not open warning")
	screen._render()
	for direction in ["left", "right"]:
		button = screen.find_child("Choice_" + direction, true, false)
		if button == null or button.disabled or screen.art_rect.texture == null:
			return _fail("desktop warning choices/image missing")
	screen.queue_free()
	await process_frame
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var token: int = game.issue_choice_token()
	for target in ["scene_qi_mountain_shadow_path_agc_v1.png", "battlefield_enc_patrol_qi_mountain_shadow_agc_v2.png", "module:combat:encounter_director"]:
		content.target = target
		for mode in ["missing", "changed"]:
			content.mode = mode
			if not game.get_current_card().is_empty() or game.choose("right", token) \
					or store.last_error != ("SOURCE_UNAVAILABLE" if mode == "missing" else "SOURCE_MISMATCH") \
					or not _same(game.state, before) or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
				return _fail("live warning source failure lost classification/atomicity: " + target + "/" + mode + "/" + store.last_error)
	content.mode = ""
	store.fail_promotion_once = true
	if game.choose("right", token) or not _same(game.state, before) \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("paid preparation failed-save rollback")
	if not game.choose("right", token) or game.choose("right", token) \
			or game.state.turn != before.turn or not _reopens(game) \
			or int(game.state.resources.spiritStone) != int(before.resources.spiritStone) - 10 \
			or int(game.state.attributes.health) != mini(int(before.maxHealth), int(before.attributes.health) + 1):
		return _fail("second paid preparation not once/replayable")
	var request: Dictionary = game.battle_request()
	if request.is_empty() or not _same(request.playerSnapshot.attributes, game.state.attributes) \
			or not _same(request.playerSnapshot.resources, game.state.resources):
		return _fail("snapshot taken before preparation cost/healing")
	var result := _result(request, "victory")
	before = game.state.duplicate(true)
	bytes = FileAccess.get_file_as_bytes(store.v2_path)
	for target in ["scene_qi_mountain_shadow_path_agc_v1.png", "battlefield_enc_patrol_qi_mountain_shadow_agc_v2.png", "module:combat:encounter_director"]:
		content.target = target
		for mode in ["missing", "changed"]:
			content.mode = mode
			if not game.battle_request().is_empty() or game.submit_battle_result(result) \
					or store.last_error != ("SOURCE_UNAVAILABLE" if mode == "missing" else "SOURCE_MISMATCH") \
					or not _same(game.state, before) or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
				return _fail("live pending source failure lost classification/atomicity: " + target + "/" + mode + "/" + store.last_error)
			var recovered_store = Session.new(file, "slot_2")
			var recovered = Domain.new(Registry.new(), recovered_store, "slot_2", content)
			if recovered.restore() or not recovered.state.is_empty() \
					or recovered_store.last_error != store.last_error or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
				return _fail("pending broken source cold restore lost classification")
	content.mode = ""
	if not _reopens(game) or not game.submit_battle_result(result):
		return _fail("repaired source retry")
	var settled: Dictionary = game.state.duplicate(true)
	for kind in ["duplicate_index", "missing_first", "foreign_receipt", "forged_reward", "paid_warning"]:
		var forged: Dictionary = settled.duplicate(true)
		match kind:
			"duplicate_index":
				forged.battleResultHistory.append(forged.battleResultHistory.back().duplicate(true))
			"missing_first":
				forged.battleResultHistory.pop_front()
			"foreign_receipt":
				forged.battleResultHistory[1].result.encounterInstanceId = forged.battleResultHistory[0].result.encounterInstanceId
			"forged_reward":
				forged.battleResultHistory[1].victoryRewards.fortune = 100
			"paid_warning":
				forged.battleResultHistory[1].warningDirection = "left"
		var forged_store = Session.new("user://tests/mountain_forged_%s_%d.json" % [kind, Time.get_ticks_usec()], "slot_2")
		if forged_store.commit_snapshot(forged, -1).get("ok") != true:
			return _fail("could not stage envelope")
		var forged_bytes := FileAccess.get_file_as_bytes(forged_store.v2_path)
		var rejected = Domain.new(Registry.new(), forged_store, "slot_2")
		if rejected.restore() or FileAccess.get_file_as_bytes(forged_store.v2_path) != forged_bytes:
			return _fail("multi-battle forged save accepted: " + kind)
	var card_id: String = game.get_current_card().choices.left.effects.deckCard.cardId
	if settled.deck.has(card_id):
		return _fail("second reward repeated first acquisition")
	token = game.issue_choice_token()
	bytes = FileAccess.get_file_as_bytes(store.v2_path)
	store.fail_promotion_once = true
	if game.choose("left", token) or not _same(game.state, settled) or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		return _fail("second reward failed save mutated state")
	if not game.choose("left", token) or game.choose("left", token) \
			or game.state.deck.size() != 8 or not game.state.deck.has(card_id) or not _reopens(game):
		return _fail("second reward acquisition/replay failed")
	print("NONCOMBAT_MOUNTAIN_INTEGRITY_PASS desktop=true paid=true source=true cross_battle=true reward=true replay=true")
	quit(0)
