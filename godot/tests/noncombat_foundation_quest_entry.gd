extends "res://tests/noncombat_qi_gate_entry.gd"


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var gate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GATE_FIXTURE))
	var source: Dictionary = gate["arrivalResponses"][0]["followUp"]["arrival"]
	var path := "user://tests/foundation_quest_entry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third) or not _reach_gate(game) \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("foundation source route did not reach the qi gate: " + _problem)
	var request: Dictionary = game.battle_request()
	if request.get("sourceCardId") != "ch_qi_100" \
			or not game.submit_battle_result(_result(request, "victory")) \
			or game.get_current_card().get("id") != gate["arrivalResponses"][0][
				"resultCard"].get("id") \
			or not game.choose("left", game.issue_choice_token()) \
			or game.state.get("realm") != "foundation" \
			or game.get_current_card().get("id") != "epiphany_foundation" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("foundation victory and epiphany did not settle: " +
			JSON.stringify({"phase": game.state.get("phase"),
				"card": game.get_current_card().get("id"),
				"realm": game.state.get("realm")}))
	if game.state.get("phase") != "FLOW_PENDING" or not game.resume_flow():
		return _fail("foundation first quest did not enter the source flow: " +
			game.flow_failure_reason())
	var card: Dictionary = game.get_current_card()
	var expected: Dictionary = source["nextCard"]
	for field in ["id", "type", "title", "description", "sceneImage", "choices",
			"questId", "questStep"]:
		if not _expect(_canonical(card.get(field)), _canonical(expected.get(field)),
				"foundation source quest card/" + field):
			return _fail(_problem)
	if game.state.get("phase") != "QUEST_PENDING" \
			or game.state.get("questState", {}).get("activeQuests", []).size() != 1 \
			or game.state["questState"]["activeQuests"][0].get("questId") != "sword_legacy" \
			or _cold(game, "foundation quest entry") == null:
		return _fail("foundation quest was not a durable public decision: " + _problem)
	print("NONCOMBAT_FOUNDATION_QUEST_ENTRY_PASS natural=true quest=sword_legacy replay=true")
	quit(0)
