extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Session = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe = Domain.new(Registry.new())
	if not probe.has_method("submit_battle_result"):
		return _fail("persisted teaching battle has no result settlement consumer")
	var count := 0
	for path_id in ["sword", "spell", "body", "pill"]:
		for outcome in ["defeat", "flee"]:
			var path := "user://tests/battle_return_%s_%s_%d.json" % [path_id, outcome, Time.get_ticks_usec()]
			var store = Session.new(path, "slot_2")
			var game = Domain.new(Registry.new(), store, "slot_2")
			if not game.start(path_id):
				return _fail("opening failed")
			var preparation := "right" if path_id == "pill" and outcome == "defeat" else "left"
			for direction in ["right", "right", "left", "left", preparation]:
				if not game.choose(direction, game.issue_choice_token()):
					return _fail("natural route failed: " + path_id + "/" + str(game.state.get("phase")))
			var before: Dictionary = game.state.duplicate(true)
			var request: Dictionary = game.battle_request()
			if request.is_empty() or not _reopens(game):
				return _fail("pending request did not strictly reopen")
			var result := _result(request, outcome)
			var bytes := FileAccess.get_file_as_bytes(store.v2_path)
			for field in ["encounterInstanceId", "sourceCardId", "sourceContentHash"]:
				var wrong: Dictionary = result.duplicate(true)
				wrong[field] = "foreign"
				if game.submit_battle_result(wrong) or not _same(game.state, before) \
						or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
					return _fail("foreign result mutated run")
			var partial := _result(request, "victory")
			partial.postBattleState.terminal = false
			if game.submit_battle_result(partial) or not _same(game.state, before):
				return _fail("nonterminal victory was silently settled")
			store.fail_promotion_once = true
			if game.submit_battle_result(result) or not _same(game.state, before) \
					or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
				return _fail("failed result write was not atomic")
			if not game.submit_battle_result(result):
				return _fail("valid terminal retry failed: " + game.flow_failure_reason())
			var after: Dictionary = game.state.duplicate(true)
			var before_pulse: Dictionary = before.worldPulseState.state
			var after_pulse: Dictionary = after.worldPulseState.state
			if int(after_pulse.instability) != int(before_pulse.instability) + (
				3 if outcome == "defeat" else 1) \
					or int(after_pulse.hope) != int(before_pulse.hope) + (
					-2 if outcome == "defeat" else 0):
				return _fail("battle source choice and outcome did not update world pulse once")
			var injury := 1 if outcome == "defeat" else 0
			var burns: bool = int(before.attributes.health) == 1 and outcome == "defeat"
			if int(after.attributes.health) != (1 if burns else int(before.attributes.health) - injury) \
					or int(after.maxHealth) != int(before.maxHealth) - int(burns) \
					or int(after.maxDaoHeart) != int(before.maxDaoHeart) - int(burns) \
					or after.resources.spiritStone != before.resources.spiritStone \
					or after.attributes.cultivation != before.attributes.cultivation \
					or int(after.resources.lifespan) != int(before.resources.lifespan) - int(outcome == "flee") \
					or after.deck != before.deck or int(after.turn) != int(before.turn) + 1:
				return _fail("source injury/burn-blood/lifespan/reward values differ: " + path_id + "/" + outcome)
			var card: Dictionary = game.get_current_card()
			var oracle: Dictionary = _oracle(path_id, outcome)
			if not oracle.is_empty() and (not _same(_source_snapshot(before), oracle.before) \
					or not _same(_source_snapshot(after), oracle.after) \
					or not _same(card, oracle.resultCard) \
					or not _same(after.noncombatFlow.encounterDirectorState, oracle.director)):
				return _fail("Godot differs from actual browser combat oracle")
			if card.get("type") != "NORMAL" or card.get("choices", {}).keys() != ["down"] \
					or not card.get("tags", []).is_empty() or not _reopens(game):
				return _fail("original result card or settled replay invalid: " + store.last_error)
			var receipt: Dictionary = after.battleResultHistory[0]
			if receipt.get("defeatHealthLoss") != injury:
				return _fail("injury receipt lost actual damage before blood rescue")
			var settled_bytes := FileAccess.get_file_as_bytes(store.v2_path)
			if game.submit_battle_result(result) or not _same(game.state, after) \
					or FileAccess.get_file_as_bytes(store.v2_path) != settled_bytes:
				return _fail("duplicate outcome accepted")
			if path_id == "sword" and outcome == "defeat":
				var screen: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
				screen.save_path = ""
				root.add_child(screen)
				await process_frame
				screen.opening = game
				screen._render()
				var button := screen.find_child("Choice_down", true, false)
				if screen.art_rect.texture == null or button == null or button.disabled \
						or screen.title_label.text != "重伤退却":
					return _fail("desktop outcome card not rendered")
				screen.queue_free()
				await process_frame
			if not game.choose("down", game.issue_choice_token()) or not _reopens(game) \
					or not game.resume_flow() or not _reopens(game):
				return _fail("outcome acknowledgement did not resume/reopen original story")
			if game.state.get("phase") != "MILESTONE_PENDING":
				return _fail("original cultivation milestone did not take priority")
			if not oracle.is_empty() and not _same(_source_snapshot(game.state), oracle.afterDown):
				return _fail("down acknowledgement clock or seed differs from browser")
			if path_id == "sword":
				if not game.choose("left", game.issue_choice_token()) \
						or not _reopens(game):
					return _fail("returned milestone choice did not persist/reopen")
			count += 1
	print("NONCOMBAT_BATTLE_RETURN_PASS paths=4 outcomes=2 atomic=true replay=true blood=true ui=true cases=" + str(count))
	quit(0)

func _oracle(path_id: String, outcome: String) -> Dictionary:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/battle_return_source.json"))
	for row in source.rows:
		if row.path == path_id and row.outcome == outcome:
			return row
	return {}

func _source_snapshot(snapshot: Dictionary) -> Dictionary:
	return {"turn": snapshot.turn, "health": snapshot.attributes.health,
		"daoHeart": snapshot.attributes.daoHeart, "maxHealth": snapshot.maxHealth,
		"maxDaoHeart": snapshot.maxDaoHeart, "lifespan": snapshot.resources.lifespan,
		"spiritStone": snapshot.resources.spiritStone, "cultivation": snapshot.attributes.cultivation,
		"seedDelay": snapshot.karmaSeeds[0].delay}

func _result(request: Dictionary, outcome: String) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": outcome,
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": outcome.to_upper()}}

func _reopens(game: RefCounted) -> bool:
	var next = Domain.new(Registry.new(), Session.new(game._store.legacy_path, "slot_2"), "slot_2")
	return next.restore() and _same(next.state, game.state)

func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
