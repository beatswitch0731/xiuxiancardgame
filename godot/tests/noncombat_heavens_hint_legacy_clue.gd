extends "res://tests/noncombat_bazaar_vendor.gd"

func _run() -> void:
	var path := "user://tests/heavens_old_clue_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	game._ripple_flow.roll_override = 0.0
	game._hint_flow.roll_override = 0.875
	game._hint_flow.legacy_clue_sink = true
	if not game.start("sword") or not _reach_bazaar(game) \
			or not game.choose("left", game.issue_choice_token()) \
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
			or not game.resume_flow():
		return _fail("old hint clue route did not reach scheduled hint")
	if game.get_current_card().get("type") != "HEAVENS_HINT":
		return _fail("old hint clue expected prophecy, got " + String(
			game.get_current_card().get("id")))
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("noncombatFlow", {}).get("hintClues", []).size() != 1 \
			or game.state["noncombatFlow"]["hintClues"][0].get("id") != "ancient_prophecy_warning":
		return _fail("old hint did not write legacy clue")
	var saved: Dictionary = game.state.duplicate(true)
	var reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	reload._market_flow.roll_override = 0.0
	reload._destiny_wheel_flow.roll_override = 0.0
	reload._ripple_flow.roll_override = 0.0
	reload._hint_flow.roll_override = 0.875
	if not reload.restore() or not _same(reload.state, saved) \
			or reload._hint_flow.legacy_clue_sink:
		return _fail("old hint clue failed strict disk replay")
	print("NONCOMBAT_HEAVENS_HINT_LEGACY_CLUE_PASS clue=true disk=true")
	quit(0)
