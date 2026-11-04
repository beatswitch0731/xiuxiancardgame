extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/mentor_trusted_%d.json" % Time.get_ticks_usec()
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
			or not game.choose("right", game.issue_choice_token()):
		return _fail("source bazaar ripple right route was not reachable")
	var after_ripple: Dictionary = game.state.duplicate(true)
	if game.state.get("runClock", {}).get("decisionIndex") != 23 \
			or game.state.get("mentorArcState", {}).get("stage") != "TRUSTED" \
			or game.state.get("mentorArcState", {}).get("progression") != 40 \
			or game.state.get("mentorArcState", {}).get("enteredAtTurn") != 22 \
			or not game.resume_flow() \
			or game.get_current_card().get("id") != "mentor_bai_ren_stage_TRUSTED":
		return _fail("browser decision 23 TRUSTED mentor card absent; arc=%s phase=%s card=%s" % [
			after_ripple.get("mentorArcState", {}), game.state.get("phase"),
			game.get_current_card().get("id")])
	var card: Dictionary = game.get_current_card()
	if card.get("title") != "师尊·真相" or card.get("arcStage") != "TRUSTED" \
			or card.get("sceneImage") != "assets/characters/stages/bai_ren_sword_tomb_master.png" \
			or card.get("choices", {}).get("left", {}).get("effects", {}).get("karmaGood") != 15 \
			or card.get("choices", {}).get("right", {}).get("effects", {}).get("cultivation") != 10 \
			or Registry.new().texture_for(String(card.get("sceneImage", ""))) == null:
		return _fail("TRUSTED card was not projected from source prose, effects and portrait")
	var pending: Dictionary = game.state.duplicate(true)
	var pending_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	if game.can_choose_direction("right") or game.choose("right", game.issue_choice_token()) \
			or not _same(game.state, pending) \
			or FileAccess.get_file_as_string(game._store.v2_path) != pending_bytes:
		return _fail("fully capped TRUSTED right choice bypassed browser admission")
	var uncapped: Dictionary = pending.duplicate(true)
	uncapped["attributes"]["cultivation"] = 90
	if not game._mentor_flow.choice_available(uncapped, "right"):
		return _fail("TRUSTED right choice remained blocked with available cultivation")
	var right_projection: Dictionary = game._mentor_flow.settle(uncapped, "right")
	if right_projection.is_empty() \
			or right_projection.get("attributes", {}).get("cultivation") != 100 \
			or right_projection.get("attributes", {}).get("karmaGood") != \
				uncapped.get("attributes", {}).get("karmaGood") \
			or right_projection.get("choiceHistory", []).back().get("direction") != "right":
		return _fail("available TRUSTED right choice did not apply original effects")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var left_button: Button = row.get_node_or_null("Choice_left")
	var right_button: Button = row.get_node_or_null("Choice_right")
	if left_button == null or left_button.disabled or right_button == null \
			or not right_button.disabled or ui.art_rect.texture == null:
		return _fail("desktop TRUSTED card did not show art and capped-choice feedback")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	reload._market_flow.roll_override = 0.0
	reload._destiny_wheel_flow.roll_override = 0.0
	reload._ripple_flow.roll_override = 0.0
	reload._hint_flow.roll_override = 0.0
	if not reload.restore() or not _same(reload.state, pending):
		return _fail("TRUSTED mentor pending choice failed strict restart")
	var before_bytes := FileAccess.get_file_as_string(reload._store.v2_path)
	var token: int = reload.issue_choice_token()
	reload._store.fail_promotion_once = true
	if reload.choose("left", token) or not _same(reload.state, pending) \
			or FileAccess.get_file_as_string(reload._store.v2_path) != before_bytes:
		return _fail("failed TRUSTED choice changed source state or save bytes")
	var before_good := int(pending.get("attributes", {}).get("karmaGood", 0))
	if not reload.choose("left", token) \
			or reload.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or reload.state.get("runClock", {}).get("decisionIndex") != 24 \
			or reload.state.get("attributes", {}).get("karmaGood") != mini(100, before_good + 15) \
			or reload.state.get("mentorArcState", {}).get("pendingStages", []).has("TRUSTED") \
			or not reload.state.get("mentorArcState", {}).get("eventsTriggered", []).has(
				"mentor_bai_ren_stage_TRUSTED") \
			or reload.get_current_card().get("id") != "promise_result_c500a306" \
			or reload.get_current_card().get("originCardId") != \
				"mentor_bai_ren_stage_TRUSTED":
		return _fail("TRUSTED left choice did not settle source effects and response")
	var chosen: Dictionary = reload.state.duplicate(true)
	var chosen_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	chosen_reload._market_flow.roll_override = 0.0
	chosen_reload._destiny_wheel_flow.roll_override = 0.0
	chosen_reload._ripple_flow.roll_override = 0.0
	chosen_reload._hint_flow.roll_override = 0.0
	if not chosen_reload.restore() or not _same(chosen_reload.state, chosen):
		return _fail("TRUSTED response failed strict replay")
	if not chosen_reload.choose("left", chosen_reload.issue_choice_token()) \
			or chosen_reload.state.get("runClock", {}).get("decisionIndex") != 25 \
			or chosen_reload.state.get("noncombatFlow", {}).get("mentorPromise", {}).get(
				"status") != "resolved" \
			or chosen_reload.state.has("pendingNarrativeResult"):
		return _fail("TRUSTED response acknowledgement did not resolve mentor promise")
	var acknowledged: Dictionary = chosen_reload.state.duplicate(true)
	var ack_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	ack_reload._market_flow.roll_override = 0.0
	ack_reload._destiny_wheel_flow.roll_override = 0.0
	ack_reload._ripple_flow.roll_override = 0.0
	ack_reload._hint_flow.roll_override = 0.0
	if not ack_reload.restore() or not _same(ack_reload.state, acknowledged):
		return _fail("TRUSTED acknowledged promise failed strict replay")
	if not ack_reload.resume_flow() \
			or ack_reload.get_current_card().get("id") != "bazaar_encounter" \
			or ack_reload.state.get("runClock", {}).get("decisionIndex") != 25 \
			or ack_reload.state.get("marketState", {}).get("lastBazaarDecisionIndex") != 24 \
			or ack_reload.state.get("marketState", {}).get("nextBazaarDecisionIndex") != 30:
		return _fail("browser TRUSTED acknowledgement did not resume next bazaar at decision 25")
	var legacy_fixture := "res://tests/fixtures/legacy_n9m_ripple_decision23_v2.json"
	var legacy_path := "user://tests/mentor_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_store = RunSession.new(legacy_path, "slot_3")
	var fixture_bytes := FileAccess.get_file_as_bytes(legacy_fixture)
	var legacy_file := FileAccess.open(legacy_store.v2_path, FileAccess.WRITE)
	if legacy_file == null or fixture_bytes.is_empty():
		return _fail("authentic pre-N9n mentor fixture could not be staged")
	legacy_file.store_buffer(fixture_bytes)
	legacy_file.close()
	var authentic: Dictionary = JSON.parse_string(fixture_bytes.get_string_from_utf8())
	var pinned_battle_sha: String = authentic.get("state", {}).get("battleCardSourceSha", "")
	var current_battle_sha: String = load(
		"res://scripts/noncombat_content_repository.gd").new().source_sha256(
			"cards:battle_cards")
	if current_battle_sha.is_empty():
		return _fail("current battle-card source could not be verified")
	var old_game = Domain.new(Registry.new(), legacy_store, "slot_3")
	old_game._market_flow.roll_override = 0.0
	old_game._destiny_wheel_flow.roll_override = 0.0
	old_game._ripple_flow.roll_override = 0.0
	old_game._hint_flow.roll_override = 0.0
	var restored_old: bool = old_game.restore()
	if pinned_battle_sha != current_battle_sha:
		if restored_old or old_game._store.last_error != "SOURCE_MISMATCH" \
				or FileAccess.get_file_as_bytes(legacy_store.v2_path) != fixture_bytes:
			return _fail("source-drifted authentic save was accepted, mislabeled or modified")
	else:
		if not restored_old or old_game.state.get("mentorArcState", {}).get("version") != 1 \
				or old_game.state.get("phase") != "FLOW_PENDING" \
				or FileAccess.get_file_as_bytes(legacy_store.v2_path) != fixture_bytes:
			return _fail("authentic pre-N9n mentor save failed byte-preserving strict restore")
		if not old_game.resume_flow() \
				or old_game.get_current_card().get("id") != "mentor_bai_ren_stage_TRUSTED" \
				or old_game.state.get("mentorArcState", {}).get("version") != 2:
			return _fail("pre-N9n save did not upgrade TRUSTED at same decision")
		var upgraded: Dictionary = old_game.state.duplicate(true)
		var upgraded_reload = Domain.new(Registry.new(), RunSession.new(legacy_path, "slot_3"), "slot_3")
		upgraded_reload._market_flow.roll_override = 0.0
		upgraded_reload._destiny_wheel_flow.roll_override = 0.0
		upgraded_reload._ripple_flow.roll_override = 0.0
		upgraded_reload._hint_flow.roll_override = 0.0
		if not upgraded_reload.restore() or not _same(upgraded_reload.state, upgraded):
			return _fail("upgraded pre-N9n mentor save failed strict restart")
	# The historical fixture stays byte-for-byte authentic. A current-source v1
	# envelope separately proves that the stage migration still works after
	# authored battle-card content changes.
	var compatible: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		game._store.v2_path))
	compatible["state"] = after_ripple.duplicate(true)
	compatible["state"]["mentorArcState"] = authentic["state"]["mentorArcState"].duplicate(true)
	# Only the mentor rule is old in this constructed envelope. Its faction
	# progress came from the current run, so replay it with current tick order.
	compatible["state"]["factionCollectionNewActivationIndex"] = maxi(1,
		int(compatible["state"].get("factionEventState", {}).get("activationIndex", 1)))
	var compatible_path := "user://tests/mentor_v1_current_%d.json" % Time.get_ticks_usec()
	var compatible_store = RunSession.new(compatible_path, "slot_3")
	var compatible_file := FileAccess.open(compatible_store.v2_path, FileAccess.WRITE)
	if compatible_file == null:
		return _fail("current-source pre-N9n mentor fixture could not be staged")
	var compatible_bytes := JSON.stringify(compatible)
	compatible_file.store_string(compatible_bytes)
	compatible_file.close()
	var compatible_game = Domain.new(Registry.new(), compatible_store, "slot_3")
	compatible_game._market_flow.roll_override = 0.0
	compatible_game._destiny_wheel_flow.roll_override = 0.0
	compatible_game._ripple_flow.roll_override = 0.0
	compatible_game._hint_flow.roll_override = 0.0
	if not compatible_game.restore() \
			or compatible_game.state.get("mentorArcState", {}).get("version") != 1 \
			or compatible_game.state.get("phase") != "FLOW_PENDING" \
			or FileAccess.get_file_as_string(compatible_store.v2_path) != compatible_bytes:
		return _fail("current-source pre-N9n mentor save failed strict restore: %s" % [
			compatible_game._store.last_error])
	if not compatible_game.resume_flow() \
			or compatible_game.get_current_card().get("id") != "mentor_bai_ren_stage_TRUSTED" \
			or compatible_game.state.get("mentorArcState", {}).get("version") != 2:
		return _fail("current-source pre-N9n save did not upgrade at same decision: card=%s arc=%s reason=%s" % [
			compatible_game.get_current_card().get("id"),
			compatible_game.state.get("mentorArcState", {}),
			compatible_game.flow_failure_reason()])
	var compatible_upgraded: Dictionary = compatible_game.state.duplicate(true)
	var compatible_reload = Domain.new(Registry.new(), RunSession.new(compatible_path, "slot_3"), "slot_3")
	compatible_reload._market_flow.roll_override = 0.0
	compatible_reload._destiny_wheel_flow.roll_override = 0.0
	compatible_reload._ripple_flow.roll_override = 0.0
	compatible_reload._hint_flow.roll_override = 0.0
	if not compatible_reload.restore() \
			or not _same(compatible_reload.state, compatible_upgraded):
		return _fail("upgraded current-source mentor save failed strict restart")
	if not compatible_reload.choose("left", compatible_reload.issue_choice_token()) \
			or compatible_reload.state.get("mentorArcState", {}).get("version") != 4 \
			or compatible_reload.state.get("mentorArcState", {}).get(
				"heirActivationIndex") != 24 \
			or compatible_reload.state.get("mentorArcState", {}).get(
				"climaxActivationIndex") != 24:
		return _fail("v2 mentor did not enter v4 at the next real decision")
	var v3_chosen: Dictionary = compatible_reload.state.duplicate(true)
	var v3_reload = Domain.new(Registry.new(), RunSession.new(compatible_path, "slot_3"),
		"slot_3")
	v3_reload._market_flow.roll_override = 0.0
	v3_reload._destiny_wheel_flow.roll_override = 0.0
	v3_reload._ripple_flow.roll_override = 0.0
	v3_reload._hint_flow.roll_override = 0.0
	if not v3_reload.restore() or not _same(v3_reload.state, v3_chosen):
		return _fail("v4 mentor activation failed strict cold replay")
	var v3_envelope: Dictionary = compatible.duplicate(true)
	v3_envelope["state"] = after_ripple.duplicate(true)
	v3_envelope["state"]["mentorArcState"]["version"] = 3
	v3_envelope["state"]["mentorArcState"].erase("climaxActivationIndex")
	v3_envelope["state"]["mentorArcState"].erase("pendingClimaxes")
	v3_envelope["state"]["mentorArcState"].erase("climaxTriggered")
	# This v3 fixture also keeps current-source faction progress.
	v3_envelope["state"]["factionCollectionNewActivationIndex"] = maxi(1,
		int(v3_envelope["state"].get("factionEventState", {}).get("activationIndex", 1)))
	var v3_path := "user://tests/mentor_v3_current_%d.json" % Time.get_ticks_usec()
	var v3_store = RunSession.new(v3_path, "slot_3")
	var v3_file := FileAccess.open(v3_store.v2_path, FileAccess.WRITE)
	if v3_file == null:
		return _fail("v3 mentor fixture could not be staged")
	v3_file.store_string(JSON.stringify(v3_envelope))
	v3_file.close()
	var legacy_v3 = Domain.new(Registry.new(), v3_store, "slot_3")
	legacy_v3._market_flow.roll_override = 0.0
	legacy_v3._destiny_wheel_flow.roll_override = 0.0
	legacy_v3._ripple_flow.roll_override = 0.0
	legacy_v3._hint_flow.roll_override = 0.0
	if not legacy_v3.restore() or legacy_v3.state.get("mentorArcState", {}).get(
			"version") != 3:
		return _fail("v3 mentor historical save failed strict replay: %s" % [
			legacy_v3._store.last_error])
	if not legacy_v3.resume_flow() \
			or legacy_v3.get_current_card().get("id") != "mentor_bai_ren_stage_TRUSTED" \
			or not legacy_v3.choose("left", legacy_v3.issue_choice_token()) \
			or legacy_v3.state.get("mentorArcState", {}).get("version") != 4 \
			or legacy_v3.state.get("mentorArcState", {}).get("climaxActivationIndex") != 24:
		return _fail("v3 mentor did not activate v4 on the next real choice")
	var v3_upgraded: Dictionary = legacy_v3.state.duplicate(true)
	var legacy_v3_reload = Domain.new(Registry.new(), RunSession.new(v3_path, "slot_3"),
		"slot_3")
	legacy_v3_reload._market_flow.roll_override = 0.0
	legacy_v3_reload._destiny_wheel_flow.roll_override = 0.0
	legacy_v3_reload._ripple_flow.roll_override = 0.0
	legacy_v3_reload._hint_flow.roll_override = 0.0
	if not legacy_v3_reload.restore() or not _same(legacy_v3_reload.state,
			v3_upgraded):
		return _fail("v3 to v4 mentor transition failed strict cold replay")
	var malformed: Dictionary = compatible.duplicate(true)
	malformed["state"]["mentorArcState"]["version"] = {"unexpected": "object"}
	var malformed_store = RunSession.new(
		"user://tests/mentor_bad_version_%d.json" % Time.get_ticks_usec(), "slot_3")
	var malformed_file := FileAccess.open(malformed_store.v2_path, FileAccess.WRITE)
	if malformed_file == null:
		return _fail("malformed mentor version fixture could not be staged")
	var malformed_bytes := JSON.stringify(malformed)
	malformed_file.store_string(malformed_bytes)
	malformed_file.close()
	var malformed_game = Domain.new(Registry.new(), malformed_store, "slot_3")
	if malformed_game.restore() \
			or FileAccess.get_file_as_string(malformed_store.v2_path) != malformed_bytes:
		return _fail("malformed mentor stage version was accepted or changed on disk")
	print("NONCOMBAT_MENTOR_TRUSTED_PASS stage=true replay=true choice=true")
	quit(0)
