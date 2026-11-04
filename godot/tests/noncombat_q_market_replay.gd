extends "res://tests/noncombat_regulated_replay.gd"

func _run() -> void:
	var path := "user://tests/q_market_replay_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()):
		return _fail("q_market route did not produce the source flow number")
	var fact_at_production: Dictionary = game.state.duplicate(true)
	if fact_at_production.get("noncombatFlow", {}).get("spineFacts", {}).get(
			"fact:0:rumor_rusted_sword_origin", {}).get("status") != "active":
		return _fail("ask_luo fact was not active at its production point")
	if not game.close_vendor(game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("q_market natural source route halted before ordinary draw")
	if game.state.has("normalFlow"):
		return _fail("q_market probe expected the first ordinary draw")
	var clock_index := int(game.state.get("runClock", {}).get("decisionIndex", -1))
	var clock_fact: Dictionary = game.state.get("noncombatFlow", {}).get(
		"spineFacts", {}).get("fact:0:rumor_rusted_sword_origin", {})
	if clock_index >= 27 and (clock_fact.get("status") != "closed" \
			or int(clock_fact.get("closedDecisionIndex", -1)) != 27):
		return _fail("source fact failed to close on decision 27 before official visit: %s / %s" % [
			clock_index, clock_fact])
	var roll := -1.0
	for n in range(11, 96):
		var candidate_roll := float(n) / 100.0
		var probe = Domain.new(Registry.new(), null, "slot_3")
		_set_zero_rolls(probe)
		if not probe.start("sword"):
			return _fail("q_market probe could not initialize")
		probe.state = game.state.duplicate(true)
		probe._normal_roll_override = candidate_roll
		if probe.resume_flow() and probe.get_current_card().get("id") == "q_market":
			roll = candidate_roll
			break
	if roll < 0.0:
		return _fail("natural qi lottery did not draw q_market in the fixed-roll grid")
	game._normal_roll_override = roll
	if not game.resume_flow() or game.get_current_card().get("id") != "q_market" \
			or game.state.get("phase") != "SHOP_PENDING":
		return _fail("natural ordinary draw did not admit q_market")
	var pending: Dictionary = game.state.duplicate(true)
	var reloaded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reloaded)
	if not reloaded.restore() or not _same(reloaded.state, pending):
		return _fail("natural q_market card failed strict restore")
	var legacy_path := "user://tests/q_market_legacy_%d.json" % Time.get_ticks_usec()
	var legacy_store = RunSession.new(legacy_path, "slot_3")
	if not legacy_store.commit_snapshot(pending, -1).get("ok", false):
		return _fail("legacy q_market fixture could not persist")
	var legacy = Domain.new(Registry.new(), legacy_store, "slot_3")
	_set_zero_rolls(legacy)
	if not legacy.restore():
		return _fail("legacy q_market source card could not restore")
	legacy._q_market_choice_activation_index = int(pending.get(
		"runClock", {}).get("decisionIndex", 0)) + 2
	if not legacy.choose("right", legacy.issue_choice_token()) \
			or legacy.state.get("phase") != "FLOW_PENDING" \
			or legacy.state.has("qMarketChoiceVersion"):
		return _fail("pre-upgrade q_market choice fixture was not preserved")
	var legacy_snapshot: Dictionary = legacy.state.duplicate(true)
	var legacy_reload = Domain.new(Registry.new(), RunSession.new(
		legacy_path, "slot_3"), "slot_3")
	_set_zero_rolls(legacy_reload)
	if not legacy_reload.restore() or not _same(
			legacy_reload.state, legacy_snapshot):
		return _fail("pre-upgrade q_market choice failed strict restore")
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var choices: HBoxContainer = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if ui.art_rect.texture == null or ui.title_label.text != "坊市三门" \
			or choices.get_node_or_null("Choice_left") == null \
			or choices.get_node_or_null("Choice_right") == null \
			or choices.get_node_or_null("Choice_down") == null \
			or choices.get_node("Choice_left").disabled \
			or choices.get_node("Choice_right").disabled \
			or choices.get_node("Choice_down").disabled:
		return _fail("natural q_market source art or three desktop choices missing")
	for direction in ["right", "down"]:
		var alternate_path := "user://tests/q_market_%s_%d.json" % [direction,
			Time.get_ticks_usec()]
		var alternate_store = RunSession.new(alternate_path, "slot_3")
		if not alternate_store.commit_snapshot(pending, -1).get("ok", false):
			return _fail("natural q_market alternate choice fixture could not persist")
		var alternate = Domain.new(Registry.new(), alternate_store, "slot_3")
		_set_zero_rolls(alternate)
		if not alternate.restore() or not alternate.choose(direction,
				alternate.issue_choice_token()):
			return _fail("natural q_market %s choice could not settle" % direction)
		if direction == "right":
			var response: Dictionary = alternate.get_current_card()
			var authored_text: String = String(game.get_current_card().get(
				"choices", {}).get("right", {}).get("narrativeBlock", ""))
			if alternate.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
					or response.get("description") != authored_text \
					or response.get("originCardId") != "q_market" \
					or response.get("originChoice") != "right" \
					or alternate.state.get("flags", {}).get("choice:q_market:right") != true \
					or alternate.state.get("noncombatFlow", {}).get(
						"qMarketPromise", {}).get("status") != "pending":
				return _fail("natural q_market right lost source response or flag")
		elif alternate.state.get("phase") != "FLOW_PENDING" \
				or alternate.state.get("flags", {}).has("choice:q_market:right"):
			return _fail("natural q_market down unexpectedly created response")
		var alternate_result: Dictionary = alternate.state.duplicate(true)
		var alternate_reload = Domain.new(Registry.new(), RunSession.new(
			alternate_path, "slot_3"), "slot_3")
		_set_zero_rolls(alternate_reload)
		if not alternate_reload.restore() or not _same(
				alternate_reload.state, alternate_result):
			return _fail("natural q_market %s choice failed strict restore" % direction)
		if direction == "right":
			if not alternate.choose("left", alternate.issue_choice_token()) \
					or alternate.state.get("noncombatFlow", {}).get(
						"qMarketPromise", {}).get("status") != "resolved":
				return _fail("natural q_market response could not resolve")
			var resolved: Dictionary = alternate.state.duplicate(true)
			var resolved_reload = Domain.new(Registry.new(), RunSession.new(
				alternate_path, "slot_3"), "slot_3")
			_set_zero_rolls(resolved_reload)
			if not resolved_reload.restore() or not _same(
					resolved_reload.state, resolved):
				return _fail("natural q_market response failed strict restore")
	if not game.choose("left", game.issue_choice_token()):
		return _fail("natural q_market could not enter official venue")
	var opened: Dictionary = game.state.duplicate(true)
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	var fact: Dictionary = opened.get("noncombatFlow", {}).get("spineFacts", {}).get(
		fact_id, {})
	var service: Dictionary = {}
	for row in opened.get("marketState", {}).get("activeSession", {}).get(
			"services", []):
		if row is Dictionary and row.get("consumerId") == "regulated_rusted_sword_order":
			service = row
			break
	var due_index := int(opened.get("marketState", {}).get(
		"activeSession", {}).get("openedAtDecisionIndex", -1))
	var within_window := due_index >= int(fact.get("createdDecisionIndex", -10)) + 1 \
		and due_index <= int(fact.get("createdDecisionIndex", -10)) + 4
	if fact.is_empty() or service.is_empty() \
			or service.get("kind") != ("causal_fact_consumer" if within_window \
				else "causal_fact_closed") \
			or opened.get("regulatedCausalServiceVersion") != 1:
		return _fail("natural q_market source fact window was not materialized")
	if within_window and (service.get("costSpec", []).size() != 1 \
			or int(service["costSpec"][0].get("amount", -1)) != 12 \
			or service.get("available") != true):
		return _fail("natural q_market live flow number cost/source mismatch")
	var live: Dictionary = fact_at_production.duplicate(true)
	var live_services: Array = game._regulated_vendor._materialize_causal_services(
		live, int(fact.get("createdDecisionIndex", -10)) + 1)
	if live_services.size() != 1 or live_services[0].get(
			"kind") != "causal_fact_consumer" or live_services[0].get(
				"costSpec", []).size() != 1 or int(live_services[0][
				"costSpec"][0].get("amount", -1)) != 12 or live.get("noncombatFlow", {}).get(
					"spineFacts", {}).get(fact_id, {}).get("status") != "active":
		return _fail("authentic fact was not eligible at the first source decision: %s / %s / %s" % [
			live_services, live.get("noncombatFlow", {}).get(
				"spineFacts", {}).get(fact_id, {}), game._regulated_vendor.last_error])
	ui._render()
	var service_button: Button = ui.get_node_or_null(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices/VendorAction_" \
		+ String(service.get("actionId", "")).replace(":", "_"))
	if service_button == null or not service_button.disabled \
			or not ui.body_label.text.contains(String(service.get("description", ""))) \
			or within_window and not ui.body_label.text.contains("需 12 灵石"):
		return _fail("desktop q_market causal service or closure is not visible")
	var expired: Dictionary = fact_at_production.duplicate(true)
	var closed_services: Array = game._regulated_vendor._materialize_causal_services(
		expired, int(fact.get("createdDecisionIndex", -10)) + 5)
	if closed_services.size() != 1 or closed_services[0].get(
			"kind") != "causal_fact_closed" or expired.get(
				"noncombatFlow", {}).get("spineFacts", {}).get(fact_id, {}).get(
					"status") != "closed":
		return _fail("source flow number did not close after the fourth decision")
	var reload_open = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload_open)
	if not reload_open.restore() or not _same(reload_open.state, opened):
		return _fail("natural q_market official quote failed strict restore")
	if not game.purchase_vendor_offer("shop_pill_foundation",
			game.issue_choice_token()):
		return _fail("natural q_market guaranteed source pill could not be bought")
	var purchased: Dictionary = game.state.duplicate(true)
	var reload_purchased = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload_purchased)
	if not reload_purchased.restore() or not _same(reload_purchased.state, purchased):
		return _fail("natural q_market purchase failed strict restore")
	if not game.close_vendor(game.issue_choice_token()):
		return _fail("natural q_market official session could not close")
	var settled: Dictionary = game.state.duplicate(true)
	var reload_settled = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload_settled)
	if not reload_settled.restore() or not _same(reload_settled.state, settled):
		return _fail("natural q_market result failed strict restore")
	print("NONCOMBAT_Q_MARKET_REPLAY_PASS natural=true roll=%.2f right=true down=true pending=true open=true purchase=true result=true" % roll)
	quit(0)
