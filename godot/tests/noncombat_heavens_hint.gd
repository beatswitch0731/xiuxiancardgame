extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/heavens_hint_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	game._hint_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("type") != "KARMA_RIPPLE" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "mentor_bai_ren_stage_TRUSTED" \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "bazaar_encounter" \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow():
		return _fail("source second bazaar to pending heavens hint was not reachable")
	var card: Dictionary = game.get_current_card()
	var hint: Dictionary = game.state.get("heavensHintState", {})
	if card.get("id") != "heavens_hint:slot_3:life:0:16:0" \
			or card.get("type") != "HEAVENS_HINT" \
			or card.get("title") != "✨ 天机一闪 · 吉兆" \
			or not String(card.get("description", "")).contains("青鸾衔书至，云外有仙音。") \
			or card.get("choices", {}).get("left", {}).get("effects", {}).get("spiritStone") != 3 \
			or int(hint.get("totalTicks", -1)) != 26 \
			or int(hint.get("nextTrigger", -1)) != 31 \
			or hint.get("hintsRevealed", []) != [0] \
			or hint.get("issuedHints", []) != [{"turn": 16, "index": 0}] \
			or hint.get("seerRevelation") != 3:
		return _fail("heavens hint source card or delayed issued-state differs from browser")
	var pending: Dictionary = game.state.duplicate(true)
	var pending_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	var prophecy: Dictionary = pending.duplicate(true)
	prophecy["attributes"]["cultivation"] = 50
	prophecy["attributes"]["fortune"] = 50
	prophecy["attributes"]["daoHeart"] = 50
	prophecy["heavensHintState"]["hintsRevealed"].append(35)
	prophecy["heavensHintState"]["issuedHints"].append({"turn": 16, "index": 35})
	prophecy["pendingHintChoiceCard"] = game._hint_flow._project(prophecy, 16, 35,
		game._hint_flow._pool()[35])
	var remembered: Dictionary = game._hint_flow.settle_choice(prophecy, "left")
	if remembered.get("clues", []).size() != 1 \
			or remembered["clues"][0].get("id") != "ancient_prophecy_warning" \
			or remembered["clues"][0].get("source") != prophecy["pendingHintChoiceCard"]["id"] \
			or remembered.get("noncombatFlow", {}).has("hintClues"):
		return _fail("prophecy source clue did not enter character evidence state")
	game._hint_flow.legacy_clue_sink = true
	var old_remembered: Dictionary = game._hint_flow.settle_choice(prophecy, "left")
	game._hint_flow.legacy_clue_sink = false
	if old_remembered.get("clues", []).size() != 0 \
			or old_remembered.get("noncombatFlow", {}).get("hintClues", []).size() != 1 \
			or old_remembered["noncombatFlow"]["hintClues"][0].get(
				"sourceCardId") != prophecy["pendingHintChoiceCard"]["id"]:
		return _fail("old hint clue choice did not preserve strict replay shape")
	var collision_prior: Dictionary = pending.duplicate(true)
	collision_prior["heavensHintState"]["nextTrigger"] = 27
	collision_prior["marketState"]["nextBazaarDecisionIndex"] = 27
	var collision: Dictionary = collision_prior.duplicate(true)
	collision["phase"] = "FLOW_PENDING"
	collision["turn"] = 27
	collision["runClock"]["decisionIndex"] = 27
	if not game._hint_flow.settle(collision_prior, collision, false, -1, 0) \
			or collision.get("pendingHintCard", {}).get("hintTurn") != 27 \
			or not game._market_flow.settle(collision_prior, collision, false, -1, 0) \
			or collision["marketState"]["nextBazaarDecisionIndex"] != 27 \
			or collision.has("pendingMarketCard"):
		return _fail("new heavens hint did not suppress same-decision market cadence")
	var second_prior: Dictionary = JSON.parse_string(JSON.stringify(pending))
	second_prior["phase"] = "FLOW_PENDING"
	second_prior["runClock"]["decisionIndex"] = 31
	second_prior["heavensHintState"]["totalTicks"] = 31
	second_prior["heavensHintState"]["nextTrigger"] = 32
	second_prior.erase("pendingHintCard")
	second_prior.erase("pendingHintChoiceCard")
	var second: Dictionary = second_prior.duplicate(true)
	second["runClock"]["decisionIndex"] = 32
	if not game._hint_flow.settle(second_prior, second, false, -1, 0) \
			or second.get("pendingHintCard", {}).get("hintIndex") != 1 \
			or not game._hint_flow._valid(second):
		return _fail("second hint repeated serialized float index instead of first unseen source index")
	if not game.can_choose_direction("left") or game.can_choose_direction("right") \
			or game.choose("right", game.issue_choice_token()) \
			or not _same(game.state, pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != pending_bytes:
		return _fail("fully capped heavens hint right choice was accepted")
	var uncapped: Dictionary = pending.duplicate(true)
	uncapped["attributes"]["cultivation"] = 90
	if not game._hint_flow.choice_available(uncapped, "right") \
			or game._hint_flow.settle_choice(uncapped, "right").get(
				"attributes", {}).get("cultivation") != 91:
		return _fail("heavens hint right choice failed with uncapped reward")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var left_button: Button = row.get_node_or_null("Choice_left")
	var right_button: Button = row.get_node_or_null("Choice_right")
	if left_button == null or left_button.disabled or right_button == null or not right_button.disabled:
		return _fail("desktop heavens hint did not reflect source choice admission")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	reload._market_flow.roll_override = 0.0
	reload._destiny_wheel_flow.roll_override = 0.0
	reload._ripple_flow.roll_override = 0.0
	reload._hint_flow.roll_override = 0.0
	if not reload.restore() or not _same(reload.state, pending):
		return _fail("heavens hint pending card failed strict restart")
	var token: int = reload.issue_choice_token()
	reload._store.fail_promotion_once = true
	if reload.choose("left", token) or not _same(reload.state, pending) \
			or FileAccess.get_file_as_string(reload._store.v2_path) != pending_bytes:
		return _fail("failed heavens hint choice changed state or save bytes")
	var stones := int(pending.get("resources", {}).get("spiritStone", -1))
	if not reload.choose("left", token) \
			or reload.state.get("phase") != "FLOW_PENDING" \
			or reload.state.get("runClock", {}).get("decisionIndex") != 27 \
			or reload.state.get("resources", {}).get("spiritStone") != stones + 3 \
			or reload.state.has("pendingHintChoiceCard") \
			or reload.state.get("heavensHintState", {}).get("issuedHints", []).size() != 1:
		return _fail("heavens hint left choice did not settle source reward once")
	var chosen: Dictionary = reload.state.duplicate(true)
	var chosen_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	chosen_reload._market_flow.roll_override = 0.0
	chosen_reload._destiny_wheel_flow.roll_override = 0.0
	chosen_reload._ripple_flow.roll_override = 0.0
	chosen_reload._hint_flow.roll_override = 0.0
	if not chosen_reload.restore() or not _same(chosen_reload.state, chosen):
		return _fail("chosen heavens hint failed strict restart")
	var old_regen: Dictionary = JSON.parse_string(pending_bytes)
	old_regen.state.erase("passiveRegenExtensionIndex")
	var old_regen_store = RunSession.new(
		"user://tests/heavens_hint_old_regen_%d.json" % Time.get_ticks_usec(),
		"slot_3")
	var old_regen_file := FileAccess.open(old_regen_store.v2_path, FileAccess.WRITE)
	if old_regen_file == null:
		return _fail("old hint regeneration save could not be staged")
	old_regen_file.store_string(JSON.stringify(old_regen))
	old_regen_file.close()
	var old_regen_game = Domain.new(Registry.new(), old_regen_store, "slot_3")
	old_regen_game._market_flow.roll_override = 0.0
	old_regen_game._destiny_wheel_flow.roll_override = 0.0
	old_regen_game._ripple_flow.roll_override = 0.0
	old_regen_game._hint_flow.roll_override = 0.0
	if not old_regen_game.restore() \
			or old_regen_game.state.has("passiveRegenExtensionIndex") \
			or not old_regen_game.choose("left", old_regen_game.issue_choice_token()) \
			or old_regen_game.state.get("passiveRegenExtensionIndex") != 27:
		return _fail("old hint save did not activate regeneration on its next choice")
	var old_regen_cold = Domain.new(Registry.new(), old_regen_store, "slot_3")
	old_regen_cold._market_flow.roll_override = 0.0
	old_regen_cold._destiny_wheel_flow.roll_override = 0.0
	old_regen_cold._ripple_flow.roll_override = 0.0
	old_regen_cold._hint_flow.roll_override = 0.0
	if not old_regen_cold.restore() or not _same(
			old_regen_cold.state, old_regen_game.state):
		return _fail("activated old hint save failed strict cold replay")
	var bad: Dictionary = JSON.parse_string(pending_bytes)
	bad["state"]["hintRngState"]["initialSeed"] = {"invalid": "seed"}
	var bad_store = RunSession.new("user://tests/heavens_bad_seed_%d.json" % Time.get_ticks_usec(),
		"slot_3")
	var bad_file := FileAccess.open(bad_store.v2_path, FileAccess.WRITE)
	if bad_file == null:
		return _fail("bad heavens hint seed fixture could not be staged")
	var bad_bytes := JSON.stringify(bad)
	bad_file.store_string(bad_bytes)
	bad_file.close()
	var bad_game = Domain.new(Registry.new(), bad_store, "slot_3")
	if bad_game.restore() or FileAccess.get_file_as_string(bad_store.v2_path) != bad_bytes:
		return _fail("malformed heavens hint seed was accepted or changed on disk")
	bad["state"]["hintRngState"]["initialSeed"] = pending.get("hintRngState", {}).get("initialSeed")
	bad["state"]["hintActivationIndex"] = ["invalid"]
	var bad_activation_bytes := JSON.stringify(bad)
	var bad_activation_file := FileAccess.open(bad_store.v2_path, FileAccess.WRITE)
	bad_activation_file.store_string(bad_activation_bytes)
	bad_activation_file.close()
	var bad_activation_game = Domain.new(Registry.new(), bad_store, "slot_3")
	if bad_activation_game.restore() \
			or FileAccess.get_file_as_string(bad_store.v2_path) != bad_activation_bytes:
		return _fail("malformed heavens hint activation index was accepted or changed")
	print("NONCOMBAT_HEAVENS_HINT_PASS queue=true choice=true replay=true ui=true old_regen=true")
	quit(0)
