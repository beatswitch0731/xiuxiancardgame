extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingNextArtContent extends "res://scripts/noncombat_content_repository.gd":
	func card_scene_image_status(card_id: String) -> Dictionary:
		var result: Dictionary = super.card_scene_image_status(card_id)
		if card_id in ["q_whiteFox_2", "q_whiteFox_3"]:
			result["fileExists"] = false
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for first_choice in ["left", "right"]:
		var save_path := "user://tests/whitefox_choices_%s_%d.json" % [
			first_choice, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not _reach_quest(game):
			_fail("quest first card unreachable")
			return
		if first_choice == "right":
			var scene = load("res://scenes/noncombat_opening.tscn")
			var view: Control = scene.instantiate()
			view.save_path = ""
			root.add_child(view)
			await process_frame
			view.opening = game
			view._render()
			if view.art_rect.texture == null or view.choice_row.get_node_or_null(
					"Choice_left") == null or view.choice_row.get_node_or_null("Choice_right") == null:
				_fail("source white-fox card/art/choices are absent in desktop UI")
				return
			root.remove_child(view)
			view.queue_free()
		var before: Dictionary = game.state.duplicate(true)
		var token := game.issue_choice_token()
		if token <= 0:
			_fail("source quest choices are not connected")
			return
		if first_choice == "right":
			var bytes := FileAccess.get_file_as_string(game._store.v2_path)
			game._store.fail_promotion_once = true
			if game.choose(first_choice, token) or not _same(game.state, before) \
					or FileAccess.get_file_as_string(game._store.v2_path) != bytes:
				_fail("failed first quest write leaked state")
				return
		if not game.choose(first_choice, token) or game.choose(first_choice, token):
			_fail("quest first choice did not settle exactly once")
			return
		var quest_state: Dictionary = game.state.get("questState", {})
		var fox: Dictionary = game.state.get("worldContinuityState", {}).get(
			"npcs", {}).get("bai_luoxuan", {})
		if int(game.state.get("worldContinuityState", {}).get("revision", -1)) != \
			(17 if first_choice == "left" else 16):
			_fail("source NPC registry revision differs: " + String(
				game.state.get("worldContinuityState", {}).get("revision", -1)))
			return
		if first_choice == "left":
			if game.state.get("phase") != "FLOW_PENDING" \
					or int(game.state["attributes"]["cultivation"]) != 55 \
					or int(game.state["attributes"]["health"]) != 2 \
					or int(game.state["attributes"]["karmaBad"]) != 23 \
					or int(game.state["resources"]["lifespan"]) != 77 \
					or quest_state.get("closedQuests") != ["white_fox_line"] \
					or quest_state.get("questOutcomes", {}).get("white_fox_line") != "failed" \
					or fox.get("lifecycle") != "DEAD" \
					or fox.get("manifestation") != "ECHO_ONLY" \
					or int(fox.get("changedAtTurn", -1)) != 9:
				_fail("kill branch differs from browser")
				return
			var failed_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
			if not failed_reload.restore() or failed_reload.state.get("questState", {}).get(
					"questOutcomes", {}).get("white_fox_line") != "failed":
				_fail("failed quest did not reload")
				return
		else:
			if game.get_current_card().get("id") != "q_whiteFox_2" \
					or int(game.state["attributes"]["cultivation"]) != 40 \
					or int(game.state["attributes"]["karmaGood"]) != 20 \
					or int(game.state["attributes"]["fortune"]) != 60 \
					or quest_state.get("activeQuests", [])[0].get("step") != 1 \
					or not game.state.get("flags", {}).get("bai_luoxuan_met", false) \
					or fox.get("lifecycle") != "ACTIVE" \
					or Registry.new().texture_for(String(game.get_current_card().get("sceneImage", ""))) == null:
				_fail("rescue branch differs from browser")
				return
			var q2_before: Dictionary = game.state.duplicate(true)
			var q2_bytes := FileAccess.get_file_as_string(game._store.v2_path)
			var q2_art_store = RunSession.new(save_path, "slot_3")
			var q2_art_fail = Domain.new(Registry.new(), q2_art_store, "slot_3",
				MissingNextArtContent.new())
			if q2_art_fail.restore() or q2_art_store.last_error != "SOURCE_MISMATCH" \
					or FileAccess.get_file_as_string(game._store.v2_path) != q2_bytes:
				_fail("missing q2 art archived a valid quest save")
				return
			var q2_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
			if not q2_reload.restore() or not _same(q2_reload.state, q2_before):
				_fail("rescue branch did not reload")
				return
			if not q2_reload.choose("left", q2_reload.issue_choice_token()) \
					or q2_reload.get_current_card().get("id") != "q_whiteFox_3" \
					or q2_reload.issue_choice_token() <= 0 \
					or int(q2_reload.state["attributes"]["cultivation"]) != 58 \
					or int(q2_reload.state["attributes"]["karmaGood"]) != 25 \
					or int(q2_reload.state["attributes"]["fortune"]) != 70 \
					or q2_reload.state.get("questState", {}).get("activeQuests", [])[0].get("step") != 2:
				_fail("herb branch or third-card boundary differs from browser")
				return
			var q3_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
			if not q3_reload.restore() or q3_reload.get_current_card().get("id") != "q_whiteFox_3":
				_fail("third card did not reload")
				return
	var thanks_path := "user://tests/whitefox_choices_thanks_%d.json" % Time.get_ticks_usec()
	var thanks = Domain.new(Registry.new(), RunSession.new(thanks_path, "slot_3"), "slot_3")
	if not _reach_quest(thanks) or not thanks.choose("right", thanks.issue_choice_token()) \
			or not thanks.choose("right", thanks.issue_choice_token()) \
			or thanks.get_current_card().get("id") != "q_whiteFox_3" \
			or int(thanks.state["attributes"]["cultivation"]) != 40 \
			or int(thanks.state["attributes"]["daoHeart"]) != 4 \
			or int(thanks.state["attributes"]["karmaGood"]) != 28 \
			or int(thanks.state["attributes"]["fortune"]) != 75:
		_fail("thanks branch differs from live browser")
		return
	if not _check_legacy_entry():
		return
	print("NONCOMBAT_WHITEFOX_CHOICES_PASS first=2 second=2 npc=true replay=true")
	quit(0)


func _check_legacy_entry() -> bool:
	var save_path := "user://tests/whitefox_n4b_legacy_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not _reach_quest(game):
		_fail("legacy fixture source route unreachable")
		return false
	var old: Dictionary = game.state.duplicate(true)
	old.erase("worldContinuityState")
	old.erase("worldContinuityActivationIndex")
	old.erase("worldContinuitySourceSha")
	old["noncombatFlow"].erase("npcSourceSha")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game._store.v2_path))
	envelope["state"] = old
	var file := FileAccess.open(game._store.v2_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	var old_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var restored = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not restored.restore() or not _same(restored.state, old) \
			or FileAccess.get_file_as_string(restored._store.v2_path) != old_bytes:
		_fail("N4b entry save was archived or rewritten on reload")
		return false
	if not restored.choose("right", restored.issue_choice_token()) \
			or restored.get_current_card().get("id") != "q_whiteFox_2" \
			or not restored.state.has("worldContinuityState") \
			or not restored.state.get("noncombatFlow", {}).has("npcSourceSha"):
		_fail("N4b entry did not upgrade atomically on next decision")
		return false
	var upgraded = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
	if not upgraded.restore() or upgraded.get_current_card().get("id") != "q_whiteFox_2":
		_fail("upgraded N4b entry did not reload")
		return false
	return true


func _reach_quest(game: RefCounted) -> bool:
	if not game.start("sword"):
		return false
	for step in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() \
		and game.get_current_card().get("id") == "q_whiteFox_quest"


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
