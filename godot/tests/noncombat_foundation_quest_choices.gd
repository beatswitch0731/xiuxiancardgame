extends "res://tests/noncombat_foundation_quest_entry.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var path := "user://tests/foundation_quest_choices_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("foundation quest prefix failed: " + _problem)
	var request: Dictionary = game.battle_request()
	if not game.submit_battle_result(_result(request, "victory")) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() or game.get_current_card().get("id") != "q_sword_1":
		return _fail("foundation quest did not enter after epiphany")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/quests/sword_legacy.json"))
	var entry_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var refusal_path := "user://tests/foundation_quest_refusal_%d.json" % Time.get_ticks_usec()
	var copy := FileAccess.open(refusal_path.trim_suffix(".json") + "_v2.json", FileAccess.WRITE)
	copy.store_buffer(entry_bytes)
	copy.close()
	var refused = Domain.new(Registry.new(), Session.new(refusal_path, "slot_2"), "slot_2")
	_quiet_ambient(refused)
	if not refused.restore() or not refused.choose("right", refused.issue_choice_token()) \
			or refused.state.get("phase") != "FLOW_PENDING" \
			or refused.state.questState.get("questOutcomes", {}).get("sword_legacy") != "abandoned" \
			or refused.state.questState.get("completedQuests", []).has("sword_legacy") \
			or _cold(refused, "sword quest refused") == null:
		return _fail("refusal did not close the task without a success reward: " +
			JSON.stringify({"phase": refused.state.get("phase"),
				"card": refused.get_current_card().get("id"),
				"outcomes": refused.state.get("questState", {}).get("questOutcomes"),
				"completed": refused.state.get("questState", {}).get("completedQuests"),
				"reason": refused.flow_failure_reason(), "test": _problem}))
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var accept_token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose("left", accept_token) or not _expect(game.state, before,
			"foundation quest failed write/state") or FileAccess.get_file_as_bytes(
			game._store.v2_path) != before_bytes:
		return _fail("failed quest write changed the public decision or save")
	var accepted: bool = game.choose("left", accept_token)
	var accepted_cold: RefCounted = _cold(game, "sword quest second node") if accepted else null
	if not accepted \
			or game.get_current_card().get("id") != "q_sword_2" \
			or game.state.questState.activeQuests[0].step != 1 \
			or game.state.attributes.daoHeart != mini(int(before.maxDaoHeart),
			int(before.attributes.daoHeart) + 1) \
			or accepted_cold == null:
		return _fail("accepted quest did not advance once: " + JSON.stringify({
			"accepted": accepted, "cold": accepted_cold != null,
			"phase": game.state.get("phase"), "card": game.get_current_card().get("id"),
			"step": game.state.get("questState", {}).get("activeQuests"),
			"daoHeart": game.state.get("attributes", {}).get("daoHeart"),
			"expectedHeart": mini(int(before.maxDaoHeart), int(before.attributes.daoHeart) + 1),
			"reason": game.flow_failure_reason(), "test": _problem}))
	var heart_path := "user://tests/foundation_quest_heart_%d.json" % Time.get_ticks_usec()
	copy = FileAccess.open(heart_path.trim_suffix(".json") + "_v2.json", FileAccess.WRITE)
	copy.store_buffer(FileAccess.get_file_as_bytes(game._store.v2_path))
	copy.close()
	var heart = Domain.new(Registry.new(), Session.new(heart_path, "slot_2"), "slot_2")
	_quiet_ambient(heart)
	if not heart.restore() or not heart.choose("left", heart.issue_choice_token()) \
			or heart.get_current_card().get("id") != "q_sword_3" \
			or not heart.state.flags.get("sword_legacy_forged_heart", false) \
			or not heart.state.get("knowledge", {}).get("sword", 0) > 0 \
			or _cold(heart, "heart sword trial") == null:
		return _fail("heart sword choice did not persist: " + _problem)
	if not game.choose("right", game.issue_choice_token()) \
			or game.get_current_card().get("id") != "q_sword_3" \
			or not game.state.flags.get("sword_legacy_forged_iron", false) \
			or game.get_current_card().get("description") != source.cards[2].stateVariants[0].description \
			or _cold(game, "iron sword trial") == null:
		return _fail("iron sword variant did not persist: " + _problem)
	var view: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = game
	view._render()
	var left_button: Button = view.choice_row.get_node_or_null("Choice_left")
	var right_button: Button = view.choice_row.get_node_or_null("Choice_right")
	var down_button: Button = view.choice_row.get_node_or_null("Choice_down")
	if view.art_rect.texture == null or left_button == null or right_button == null \
			or down_button == null or left_button.disabled or right_button.disabled \
			or down_button.disabled or view.body_label.text != source.cards[2].stateVariants[0].description:
		return _fail("sword trial desktop card did not expose its battle and refusal choices")
	root.remove_child(view)
	view.queue_free()
	if not game.can_choose_direction("left") or not game.can_choose_direction("right") \
			or not game.can_choose_direction("down"):
		return _fail("sword trial did not offer both battle directions and refusal")
	var down_ok: bool = game.choose("down", game.issue_choice_token())
	var down_cold: RefCounted = _cold(game, "sword quest trial refusal") if down_ok else null
	if not down_ok \
			or game.state.questState.get("questOutcomes", {}).get("sword_legacy") != "abandoned" \
			or game.state.questState.get("completedQuests", []).has("sword_legacy") \
			or down_cold == null:
		return _fail("trial refusal did not close without rewards: " + JSON.stringify({
			"down": down_ok, "cold": down_cold != null,
			"phase": game.state.get("phase"),
			"outcomes": game.state.get("questState", {}).get("questOutcomes"),
			"reason": game.flow_failure_reason(), "test": _problem}))
	print("NONCOMBAT_FOUNDATION_QUEST_CHOICES_PASS entry=true refusal=true heart=true iron=true replay=true")
	quit(0)
