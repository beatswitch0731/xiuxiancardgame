extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const SOURCE_PATH := "res://../artifacts/godot-migration/noncombat-mortal/mortal-qi-browser.json"


func _initialize() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		ProjectSettings.globalize_path(SOURCE_PATH)))
	if not source is Dictionary or source.get("pathId") != "body" \
			or source.get("constant") != 0.45 or source.get("route", []).size() < 34:
		return _fail("current body 0.45 browser route is unavailable")
	var game = Domain.new(Registry.new(), null, "slot_2")
	game._normal_roll_override = 0.45
	game._market_flow.roll_override = 0.45
	game._destiny_wheel_flow.roll_override = 0.45
	game._ripple_flow.roll_override = 0.45
	game._hint_flow.roll_override = 0.45
	game._companion_events.roll_override = 0.45
	if not game.start("body"):
		return _fail("body start failed")
	for index in 34:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _fail("flow stopped before browser decision %d" % index)
		var expected: Dictionary = source.route[index]
		var actual_card: Dictionary = game.get_current_card()
		# Browser wheel has a type but no ID; its trace uses the type label.
		var actual_id := "DESTINY_WHEEL" if expected.cardId == "DESTINY_WHEEL" \
			and game.state.phase == "DESTINY_WHEEL_PENDING" \
			and actual_card.get("type") == "DESTINY_WHEEL" else String(actual_card.get("id",
			game.state.get("currentCardId", "")))
		if actual_id != expected.cardId or int(game.state.runClock.decisionIndex) \
				!= int(expected.decisionIndex):
			return _fail("browser decision %d expected %s/%d got %s/%d" % [index,
				expected.cardId, expected.decisionIndex, actual_id,
				game.state.runClock.decisionIndex])
		if not game.choose(String(expected.direction), game.issue_choice_token()):
			return _fail("browser choice rejected at decision %d" % index)
	var after: Dictionary = source.after
	var next_card: Dictionary = game.get_current_card()
	if next_card.get("id") != after.cardId or int(game.state.runClock.decisionIndex) \
			!= int(after.decisionIndex):
		return _fail("browser after crisis expected %s/%d got %s/%d" % [
			after.cardId, after.decisionIndex, next_card.get("id", ""),
			game.state.runClock.decisionIndex])
	print("NONCOMBAT_N4_QUEST_SOURCE_ORDER_PASS decisions=0..33 post_crisis=true milestone=14")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
