extends "res://tests/noncombat_bazaar_vendor.gd"

class MissingRippleArtContent extends "res://scripts/noncombat_content_repository.gd":
	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if path == "assets/cards/events/scene_karma_k_echo_karma_chain.png":
			result["fileExists"] = false
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

class BadRippleArtContent extends "res://scripts/noncombat_content_repository.gd":
	func asset_status(path: String) -> Dictionary:
		var result: Dictionary = super.asset_status(path)
		if path == "assets/cards/events/scene_karma_k_echo_karma_chain.png":
			result["shaVerified"] = false
			result["textureLoadable"] = false
		return result

func _run() -> void:
	var path := "user://tests/karma_ripple_%d_%d.json" % [
		OS.get_process_id(), Time.get_ticks_usec()]
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	var ripple_flow: Variant = game.get("_ripple_flow")
	if ripple_flow != null:
		ripple_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("real source route did not finish Luo inquiry and bazaar result")
	var ripple: Dictionary = game.state.get("karmaRippleState", {})
	var history: Array = ripple.get("history", [])
	if ripple.get("lastRippleTurn") != 13 or ripple.get("totalTicks") != 21 \
			or history.size() != 2 or history[0].get("turn") != 5 \
			or history[1].get("turn") != 13 \
			or game.state.get("pendingRippleCard", {}).get("id") != \
				"karma_ripple:slot_3:life:0:13:causal:qi_sword_attune":
		return _fail("source ripple ticks or P15 replacement differed before bazaar close")
	if game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("runClock", {}).get("decisionIndex") != 22:
		return _fail("source result dismissal did not leave decision 22 pending")
	var dismissed: Dictionary = game.state.duplicate(true)
	var edge_prior: Dictionary = dismissed.duplicate(true)
	edge_prior["karmaSeeds"] = [{"id": "edge:one_remaining", "seedType": "karma",
		"delay": 1}]
	var edge_candidate: Dictionary = edge_prior.duplicate(true)
	edge_candidate["runClock"]["decisionIndex"] = 30
	edge_candidate["karmaSeeds"][0]["delay"] = 0
	edge_candidate.erase("pendingRippleCard")
	var edge_ok: bool = game._ripple_flow.settle(edge_prior, edge_candidate, false, -1, 0)
	if not edge_ok or edge_candidate.get("pendingRippleCard", {}).get("seedId") != \
			"edge:one_remaining":
		return _fail("delay-one seed was lost before browser ripple tick")
	var expired_prior: Dictionary = edge_prior.duplicate(true)
	expired_prior["karmaSeeds"][0]["delay"] = 0
	var expired_candidate: Dictionary = expired_prior.duplicate(true)
	expired_candidate["runClock"]["decisionIndex"] = 30
	expired_candidate.erase("pendingRippleCard")
	if not game._ripple_flow.settle(expired_prior, expired_candidate, false, -1, 0) \
			or expired_candidate.has("pendingRippleCard"):
		return _fail("expired seed incorrectly generated a browser ripple")
	var market_due_prior: Dictionary = edge_prior.duplicate(true)
	market_due_prior["marketState"]["nextBazaarDecisionIndex"] = 30
	market_due_prior["marketState"]["nextGhostDecisionIndex"] = 99
	var market_due_candidate: Dictionary = market_due_prior.duplicate(true)
	market_due_candidate["runClock"]["decisionIndex"] = 30
	market_due_candidate["karmaSeeds"][0]["delay"] = 0
	market_due_candidate.erase("pendingRippleCard")
	market_due_candidate.erase("pendingMarketCard")
	if not game._ripple_flow.settle(market_due_prior, market_due_candidate, false, -1, 0) \
			or not game._market_flow.settle(market_due_prior, market_due_candidate,
				false, -1, 0) or market_due_candidate.has("pendingMarketCard") \
			or market_due_candidate.get("marketState", {}).get("nextBazaarDecisionIndex") != 30:
		return _fail("same-decision ripple did not defer ambient market cadence")
	var blood_prior: Dictionary = edge_prior.duplicate(true)
	blood_prior["karmaSeeds"] = [{"id": "edge:blood", "seedType": "bloodline",
		"delay": 1}]
	var blood_candidate: Dictionary = blood_prior.duplicate(true)
	blood_candidate["runClock"]["decisionIndex"] = 30
	blood_candidate["karmaSeeds"][0]["delay"] = 0
	blood_candidate.erase("pendingRippleCard")
	if not game._ripple_flow.settle(blood_prior, blood_candidate, false, -1, 0):
		return _fail("source bloodline ripple did not queue")
	var blood_ready: Dictionary = game._ripple_flow.resume(blood_candidate)
	var blood_chosen: Dictionary = game._ripple_flow.settle_choice(blood_ready, "left")
	if blood_ready.is_empty() or blood_chosen.is_empty() \
			or blood_chosen.get("maxHealth") != int(blood_ready.get("maxHealth", 0)) + 1 \
			or blood_chosen.get("attributes", {}).get("health") != \
				mini(int(blood_ready.get("attributes", {}).get("health", 0)) + 1,
					int(blood_chosen.get("maxHealth", 0))):
		return _fail("bloodline maxHealth did not restore current health like browser")
	var replay = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay._market_flow.roll_override = 0.0
	replay._destiny_wheel_flow.roll_override = 0.0
	replay._ripple_flow.roll_override = 0.0
	if not replay.restore() or not _same(replay.state, dismissed):
		return _fail("dismissed bazaar lost P15 ripple on strict restore")
	var missing = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	missing._market_flow.roll_override = 0.0
	missing._destiny_wheel_flow.roll_override = 0.0
	missing._ripple_flow.roll_override = 0.0
	if not missing.restore():
		return _fail("missing-art test could not restore valid source state")
	missing._ripple_flow._content = MissingRippleArtContent.new()
	var before_missing_bytes := FileAccess.get_file_as_string(missing._store.v2_path)
	if missing.resume_flow() or not _same(missing.state, dismissed) \
			or FileAccess.get_file_as_string(missing._store.v2_path) != before_missing_bytes \
			or missing._store.last_error != "SOURCE_UNAVAILABLE" \
			or missing.flow_failure_reason().is_empty():
		return _fail("missing ripple art scheduled a choice or changed saved bytes")
	var delivered: bool = replay.resume_flow()
	if not delivered or replay.get_current_card().get("id") != \
			"karma_ripple:slot_3:life:0:13:causal:qi_sword_attune":
		return _fail("P15 source ripple was not delivered after bazaar: %s %s %s" % [
			delivered, replay._ripple_flow.last_error, replay.get_current_card().get("id")])
	var card: Dictionary = replay.get_current_card()
	if card.get("title") != "因果微澜" \
			or card.get("imagePath") != "assets/cards/events/scene_karma_k_echo_karma_chain.png" \
			or card.get("choices", {}).get("right", {}).get("effects", {}).get("cultivation") != 4 \
			or Registry.new().texture_for(String(card.get("imagePath", ""))) == null:
		return _fail("ripple card text/effects/image were not source-authenticated")
	var pending: Dictionary = replay.state.duplicate(true)
	var replay_pending = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_pending._market_flow.roll_override = 0.0
	replay_pending._destiny_wheel_flow.roll_override = 0.0
	replay_pending._ripple_flow.roll_override = 0.0
	if not replay_pending.restore() or not _same(replay_pending.state, pending):
		return _fail("source ripple card was not strictly rebuilt after restart")
	var token: int = replay_pending.issue_choice_token()
	var before_bytes := FileAccess.get_file_as_string(replay_pending._store.v2_path)
	replay_pending._store.fail_promotion_once = true
	if replay_pending.choose("right", token) \
			or not _same(replay_pending.state, pending) \
			or FileAccess.get_file_as_string(replay_pending._store.v2_path) != before_bytes:
		return _fail("failed ripple choice changed save or pending card")
	var chosen_ok: bool = replay_pending.choose("right", token)
	if not chosen_ok \
			or replay_pending.state.get("phase") != "FLOW_PENDING" \
			or replay_pending.state.get("runClock", {}).get("decisionIndex") != 23 \
			or replay_pending.state.get("attributes", {}).get("cultivation") != 100 \
			or replay_pending.state.get("attributes", {}).get("daoHeart") != 4 \
			or replay_pending.state.has("pendingRippleChoiceCard"):
		return _fail("ripple right choice did not match source capped attributes: %s %s %s" % [
			chosen_ok, replay_pending.state.get("phase"), replay_pending.state.get("attributes")])
	var chosen: Dictionary = replay_pending.state.duplicate(true)
	var replay_chosen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_chosen._market_flow.roll_override = 0.0
	replay_chosen._destiny_wheel_flow.roll_override = 0.0
	replay_chosen._ripple_flow.roll_override = 0.0
	if not replay_chosen.restore() or not _same(replay_chosen.state, chosen):
		return _fail("ripple right choice did not strictly replay")
	var chosen_bytes := FileAccess.get_file_as_string(replay_chosen._store.v2_path)
	var absent_chosen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3", MissingRippleArtContent.new())
	absent_chosen._market_flow.roll_override = 0.0
	absent_chosen._destiny_wheel_flow.roll_override = 0.0
	absent_chosen._ripple_flow.roll_override = 0.0
	var absent_restored: bool = absent_chosen.restore()
	var absent_bytes_changed := FileAccess.get_file_as_string(
		replay_chosen._store.v2_path) != chosen_bytes
	if absent_restored or absent_chosen._store.last_error != "SOURCE_UNAVAILABLE" \
			or absent_bytes_changed:
		return _fail("chosen ripple replay accepted missing art or rewrote saved bytes: " +
			JSON.stringify({"restored": absent_restored,
				"storeError": absent_chosen._store.last_error,
				"rippleError": absent_chosen._ripple_flow.last_error,
				"rippleMissing": absent_chosen._ripple_flow.source_missing(),
				"sourceErrors": absent_chosen._content.errors(),
				"bytesChanged": absent_bytes_changed}))
	var drift_chosen = Domain.new(Registry.new(), RunSession.new(path, "slot_3"),
		"slot_3", BadRippleArtContent.new())
	drift_chosen._market_flow.roll_override = 0.0
	drift_chosen._destiny_wheel_flow.roll_override = 0.0
	drift_chosen._ripple_flow.roll_override = 0.0
	if drift_chosen.restore() or drift_chosen._store.last_error != "SOURCE_MISMATCH" \
			or FileAccess.get_file_as_string(replay_chosen._store.v2_path) != chosen_bytes:
		return _fail("chosen ripple replay accepted changed art SHA or rewrote bytes")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	ui.opening._ripple_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()) \
			or not ui.opening.perform_vendor_action("ask_luo", ui.opening.issue_choice_token()) \
			or not ui.opening.close_vendor(ui.opening.issue_choice_token()) \
			or not ui.opening.choose("right", ui.opening.issue_choice_token()):
		return _fail("desktop real route could not reach pending ripple")
	if ui.opening.state.get("phase") == "FLOW_PENDING" and not ui.opening.resume_flow():
		return _fail("desktop source ripple did not resume")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var button: Button = row.get_node_or_null("Choice_right")
	if ui.opening.state.get("phase") != "RIPPLE_PENDING" or button == null \
			or button.disabled or ui.art_rect.texture == null:
		return _fail("desktop ripple did not show source art and choice")
	button.pressed.emit()
	await process_frame
	if ui.opening.state.get("runClock", {}).get("decisionIndex") != 23:
		return _fail("desktop ripple choice did not commit")
	print("NONCOMBAT_KARMA_RIPPLE_PASS pending=true replay=true choice=true ui=true")
	quit(0)
