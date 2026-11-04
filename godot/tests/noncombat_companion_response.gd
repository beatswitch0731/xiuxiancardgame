extends SceneTree

const Domain = preload("res://scripts/noncombat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_1")
	if not game.start("spell"):
		return _fail("source opening unavailable")
	var base: Dictionary = game.state.duplicate(true)
	base.phase = "FLOW_PENDING"
	base.realm = "foundation"
	base.turn = 12
	base.runClock.decisionIndex = 12
	base.runClock.lifeId = "companion:response:0"
	base.resources.companions = ["bai_luoxuan"]
	base.npcAffection = {"bai_luoxuan": 35}
	base.noncombatFlow = {"sourceContentHash": game._battle_gateway.source_content_hash()}
	base.decisionCheckpoint = {"sourceCardId": "before"}
	var pending := {}
	for i in range(1000):
		base.runClock.lifeId = "companion:response:%d" % i
		var candidate: Dictionary = game._companion_events.take(base)
		if candidate.get("phase") == "COMPANION_PENDING":
			pending = candidate
			break
	if pending.is_empty():
		return _fail("no P50 event selected for response test")
	game.state = pending
	game._current_card_id = String(pending.currentCardId)
	game._choice_token = 1
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or game.get_current_card().get("originCardId") != pending.currentCardId:
		return _fail("companion event did not commit its immediate response")
	var response_id := String(game.state.currentCardId)
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.get("phase") != "FLOW_PENDING" \
			or game.state.get("noncombatFlow", {}).get("promise", {}).get(
				"status") != "resolved" \
			or game.state.get("cardsPlayed", []).count(response_id) != 1:
		return _fail("companion response was not acknowledged once")
	print("NONCOMBAT_COMPANION_RESPONSE_PASS pending=true chosen=true response=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
