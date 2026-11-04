extends "res://tests/noncombat_cadence_second_outcomes.gd"

const THIRD_FIXTURE := "res://tests/fixtures/third_cadence_source.json"
const ALT_ROUTE := [
	["promise_result_eee72bc7", "left"],
	["mentor_bai_ren_stage_INNER_DISCIPLE", "left"],
	["promise_result_3b3a1690", "left"],
	["bazaar_encounter", "right"],
	["bazaar_encounter", "right"],
	["HEAVENS_HINT", "left"],
	["mentor_bai_ren_stage_TRUSTED", "left"],
	["promise_result_c500a306", "left"],
]

func _quiet_ambient(game: RefCounted) -> void:
	super._quiet_ambient(game)
	game._normal_roll_override = 0.5
	# Keep the elite route stable while the NPC encounter has its own source
	# replay suite; both draws still pass through the public flow scheduler.
	var quiet_npc_rolls := []
	for i in 64:
		quiet_npc_rolls.append(0.999)
	game._npc_encounter_flow.roll_override_sequence = quiet_npc_rolls


func _run() -> void:
	var first: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var second: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_FIXTURE))
	var third: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(THIRD_FIXTURE))
	var file := "user://tests/cadence_third_alt_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not _open_third_alt(game, first, second, third):
		return _fail(_problem)
	if _cold(game, "third cadence alternate offer") == null:
		return _fail("third cadence alternate offer failed strict cold restore")
	print("NONCOMBAT_CADENCE_THIRD_ALT_ENTRY_PASS public=true source_card=true director=true replay=true")
	quit(0)


func _open_third_alt(game: RefCounted, first: Dictionary, second: Dictionary,
		third: Dictionary) -> bool:
	if not _open_second(game, first, second) \
			or not game.choose("right", game.issue_choice_token()):
		return _bad("third cadence alternate prefix did not avoid second catalog card")
	for input in ALT_ROUTE:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			return _bad("third cadence alternate route did not resume")
		var card: Dictionary = game.get_current_card()
		if input[0] == "ordinary_interlude":
			if game.state.phase != "NORMAL_PENDING" or not game.can_choose_direction("left"):
				return _bad("third cadence alternate ordinary interlude changed: " +
					String(card.get("id")))
		elif card.get("id") != input[0] and card.get("type") != input[0]:
			return _bad("third cadence alternate route card differs: expected=%s got=%s/%s" % [
				input[0], card.get("id"), card.get("type")])
		if not game.choose(String(input[1]), game.issue_choice_token()):
			return _bad("third cadence alternate route choice failed: " + String(input[0]))
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		return _bad("third cadence alternate offer did not resume")
	var source: Dictionary = third.rows[0].sourceCard
	var director: Dictionary = game.state.noncombatFlow.encounterDirectorState
	var pending: Dictionary = director.get("pending", {})
	return game.state.phase == "COMBAT_HANDOFF" \
		and _expect(_canonical(game.get_current_card()), _canonical(source), "third alternate source card") \
		and _expect(pending.get("encounterId"), third.rows[0].offered.director.pending.encounterId,
			"third alternate director encounter") \
		and _expect(director.get("realmProgress", {}).get("qi", {}).get("seenCounts", {}).get("elite"),
			third.rows[0].offered.director.realmProgress.qi.seenCounts.elite,
			"third alternate elite quota")
