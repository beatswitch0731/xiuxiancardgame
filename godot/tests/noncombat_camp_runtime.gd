extends "res://tests/noncombat_priority_order.gd"

func _run() -> void:
	var path := "user://tests/camp_runtime_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	game._echo_activation_index = 1000
	if not game.start("sword") or not _reach_bazaar(game):
		return _fail("camp source route could not reach the bazaar")
	if not game.choose("left", game.issue_choice_token()) \
			or not game.perform_vendor_action("ask_luo", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()) \
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
		return _fail("camp source route stopped before ordinary draw")
	for n in 16:
		if game.state.get("turn") == 30 and game.state.get("phase") == "FLOW_PENDING":
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("camp route could not issue card: " + game.flow_failure_reason())
		else:
			var direction := ""
			for candidate in ["right", "left", "down", "up"]:
				if game.can_choose_direction(candidate):
					direction = candidate
					break
			if direction.is_empty() or not game.choose(direction, game.issue_choice_token()):
				return _fail("camp route could not settle card")
	if game.state.get("turn") != 30 or not game.resume_flow() \
			or game.get_current_card().get("id") != "camp_meditation":
		return _fail("P24 camp did not issue the original source card")
	var source: Variant = game._content.read_module("cards:camp")
	var original: Dictionary = source[0] if source is Array and source.size() == 1 else {}
	if not _same(game.get_current_card(), original) \
			or not FileAccess.file_exists("res://content/assets/cards/events/scene_camp.png") \
			or game.can_choose_direction("left") or game.can_choose_direction("right") \
			or game.can_choose_direction("down") or not game.can_choose_direction("up"):
		return _fail("camp source text, image or six-stone admission differs")
	var pending: Dictionary = game.state.duplicate(true)
	var ui: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	ui.opening = game
	ui._render()
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	if ui.title_label.text != original["title"] or ui.art_rect.texture == null \
			or not ui.status_label.text.contains("20 + 6") \
			or row.get_node_or_null("Choice_left") == null \
			or not row.get_node("Choice_left").disabled \
			or row.get_node_or_null("Choice_up") == null \
			or row.get_node("Choice_up").disabled:
		return _fail("desktop camp art or choice admission differs")
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(reload)
	reload._echo_activation_index = 1000
	if not reload.restore() or not _same(reload.state, pending):
		return _fail("pending source camp did not strictly restore")
	if not game.choose("up", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("resources", {}).get("spiritStone") != 6:
		return _fail("camp departure did not settle exactly once")
	var departed = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(departed)
	departed._echo_activation_index = 1000
	if not departed.restore() or not _same(departed.state, game.state):
		return _fail("departed camp did not strictly restore")
	if not _verify_synthetic_choices(pending, ui):
		return
	print("NONCOMBAT_CAMP_RUNTIME_PASS original=true four_choices=true target=true pending_departure_replay=true")
	quit(0)


func _synthetic_camp(pending: Dictionary) -> RefCounted:
	var game = Domain.new(Registry.new(), null, "slot_3")
	game._echo_activation_index = 1000
	if not game.start("sword"):
		return null
	game.state = pending.duplicate(true)
	game.state["resources"]["spiritStone"] = 80
	game._flow_card_count = int(pending.get("normalFlow", {}).get("cardCount", 0))
	return game


func _verify_synthetic_choices(pending: Dictionary, ui: Control) -> bool:
	var healing = _synthetic_camp(pending)
	if healing == null or not healing.can_choose_direction("left") \
			or not healing.choose("left", healing.issue_choice_token()) \
			or healing.state["resources"]["spiritStone"] != 65 \
			or healing.state["attributes"]["health"] != 3:
		return _reject("15-stone source healing settlement differs")
	var removal = _synthetic_camp(pending)
	if removal == null or not removal.choose("right", removal.issue_choice_token()) \
			or removal.state.get("phase") != "CAMP_TARGET_PENDING" \
			or removal.state["resources"]["spiritStone"] != 60:
		return _reject("camp remove entry did not charge original 20 stones")
	var removal_deck: Array = removal.state["deck"].duplicate(true)
	ui.opening = removal
	ui._render()
	var targets: Control = ui.get_node_or_null(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices/CampTargets")
	if targets == null or targets.get_node_or_null("CampTarget_5") == null \
			or targets.get_node("CampTarget_5").disabled \
			or targets.get_node_or_null("CampTargetCancel") == null \
			or not ui.body_label.text.contains("另扣来源规则费用"):
		return _reject("desktop target panel did not expose deck target and second fee")
	if removal.resolve_camp_target(5, "wrong_card", removal.issue_choice_token()) \
			or not removal.resolve_camp_target(5, String(removal_deck[5]),
				removal.issue_choice_token()) \
			or removal.state["resources"]["spiritStone"] != 54 \
			or removal.state["deck"].size() != removal_deck.size() - 1 \
			or removal.state["deck"][4] != removal_deck[4] \
			or removal.state["deckOperations"].back().get("path") != "sword" \
			or removal.state["deckOperations"].back().get("realm") != "qi" \
			or removal.state.get("phase") != "FLOW_PENDING":
		return _reject("targeted removal did not charge 20+6 or preserve duplicate identity")
	var upgrading = _synthetic_camp(pending)
	if upgrading == null or not upgrading.choose("down", upgrading.issue_choice_token()) \
			or upgrading.state["resources"]["spiritStone"] != 50 \
			or not upgrading.resolve_camp_target(0, String(upgrading.state["deck"][0]),
				upgrading.issue_choice_token()) \
			or upgrading.state["resources"]["spiritStone"] != 42 \
			or upgrading.state["deckOperations"].back().get("path") != "sword" \
			or upgrading.state["deckOperations"].back().get("realm") != "qi" \
			or not String(upgrading.state["deck"][0]).ends_with("+"):
		return _reject("targeted upgrade did not charge 30+8 and replace one deck ID")
	var cancelled = _synthetic_camp(pending)
	if cancelled == null or not cancelled.choose("right", cancelled.issue_choice_token()) \
			or not cancelled.cancel_camp_target(cancelled.issue_choice_token()) \
			or cancelled.state["resources"]["spiritStone"] != 60 \
			or cancelled.state["deck"] != pending["deck"]:
		return _reject("closing target choice did not preserve browser's spent entry fee")
	var exact_entry = _synthetic_camp(pending)
	exact_entry.state["resources"]["spiritStone"] = 20
	if not exact_entry.choose("right", exact_entry.issue_choice_token()) \
			or exact_entry.state["resources"]["spiritStone"] != 0 \
			or exact_entry.camp_targets().any(func(item: Variant) -> bool:
				return item.get("allowed", false)):
		return _reject("source entry affordability was incorrectly conflated with target fee")
	var minimum = _synthetic_camp(pending)
	if not minimum.choose("right", minimum.issue_choice_token()):
		return _reject("minimum-deck target fixture failed")
	minimum.state["deck"] = minimum.state["deck"].slice(0, 4)
	if minimum.camp_targets().any(func(item: Variant) -> bool:
		return item.get("allowed", false)):
		return _reject("minimum four-card deck allowed removal")
	var already_upgraded = _synthetic_camp(pending)
	if not already_upgraded.choose("down", already_upgraded.issue_choice_token()):
		return _reject("upgraded-target fixture failed")
	already_upgraded.state["deck"][0] = String(already_upgraded.state["deck"][0]) + "+"
	if already_upgraded.camp_targets()[0].get("allowed", true):
		return _reject("already upgraded card remained a legal target")
	var atomic_path := "user://tests/camp_atomic_%d.json" % Time.get_ticks_usec()
	var atomic = Domain.new(Registry.new(), RunSession.new(atomic_path, "slot_3"), "slot_3")
	if not atomic.start("sword"):
		return _reject("atomic target fixture could not start")
	atomic.state = pending.duplicate(true)
	atomic.state["resources"]["spiritStone"] = 80
	atomic._flow_card_count = int(pending.get("normalFlow", {}).get("cardCount", 0))
	if not atomic.choose("down", atomic.issue_choice_token()):
		return _reject("atomic target fixture could not enter camp target")
	var before: Dictionary = atomic.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(atomic._store.v2_path)
	atomic._store.fail_promotion_once = true
	if atomic.resolve_camp_target(0, String(atomic.state["deck"][0]),
			atomic.issue_choice_token()) or not _same(atomic.state, before) \
			or FileAccess.get_file_as_string(atomic._store.v2_path) != bytes:
		return _reject("failed target save changed deck, stones or save bytes")
	if not atomic.resolve_camp_target(0, String(atomic.state["deck"][0]),
			atomic.issue_choice_token()):
		return _reject("target did not recover after failed promotion")
	return true


