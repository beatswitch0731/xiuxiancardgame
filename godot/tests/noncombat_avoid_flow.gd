extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases := [
		["sword", "world", 1, 15, "promise_result_8f87a81d"],
		["spell", "world", 1, 14, "promise_result_0105e2c0"],
		["body", "health", 1, 15, "promise_result_2aae4ec5"],
		["pill", "fortune", 1, 15, "promise_result_799e44eb"],
	]
	for case in cases:
		var path_id: String = case[0]
		var save_path := "user://tests/avoid_%s_%d_v1.json" % [path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not game.start(path_id) or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()):
			_fail("source opening did not reach the teaching offer: " + path_id)
			return
		var offer_id := String(game.state.get("currentCardId", ""))
		var before: Dictionary = game.state.duplicate(true)
		var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var token := game.issue_choice_token()
		if path_id == "sword":
			game._store.fail_promotion_once = true
			if game.choose("right", token) or game.state != before \
					or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
				_fail("failed avoidance write changed the durable or visible decision")
				return
		if not game.choose("right", token) or game.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
				or int(game.state["runClock"]["decisionIndex"]) != 6 \
				or int(game.state["turn"]) != 6 \
				or game.state["cardsPlayed"].has(offer_id) \
				or game.state["choiceHistory"].back().get("cardId") != offer_id \
				or game.state["choiceHistory"].back().get("direction") != "right":
			_fail("avoidance did not settle exactly one source decision: " + path_id)
			return
		var effect_key: String = case[1]
		var before_value := int(before.get("knowledge", {}).get("world", 0)) if effect_key == "world" \
			else int(before["attributes"].get(effect_key, 0))
		var after_value := int(game.state.get("knowledge", {}).get("world", 0)) if effect_key == "world" \
			else int(game.state["attributes"].get(effect_key, 0))
		if after_value != before_value + int(case[2]):
			_fail("avoidance applied the wrong path-specific effect: " + path_id)
			return
		if int(game.state["resources"].get("lifespan", -1)) != \
				int(before["resources"].get("lifespan", -1)) - 1 \
				or game.state.get("noncombatFlow", {}).get("lifespanCostVersion") != 1:
			_fail("COMBAT avoidance did not charge the authored lifespan cost: " + path_id)
			return
		var director: Dictionary = game.state.get("noncombatFlow", {}).get("encounterDirectorState", {})
		var progress: Dictionary = director.get("realmProgress", {}).get("qi", {})
		if director.get("firstTeachingStatus") != "avoided" \
				or director.get("cooldownUntilDecision") != 8 \
				or director.get("nextDueDecision") != case[3] \
				or not progress.get("avoidedIds", []).has(offer_id.trim_prefix("encounter_card_")) \
				or not progress.get("resolvedIds", []).is_empty():
			_fail("source encounter was resolved instead of cooled for later scheduling: " + path_id)
			return
		var result: Dictionary = game.get_current_card()
		if result.get("type") != "NARRATIVE_RESULT" \
				or result.get("id") != case[4] \
				or result.get("originCardId") != offer_id \
				or result.get("semanticKey") != "promise-result:" + result.get("promiseId", "") \
				or result.get("choices", {}).get("left", {}).get("resolution", {}).get("kind") != "promise_resolved" \
				or game.state.get("noncombatFlow", {}).get("promise", {}).get("status") != "pending":
			_fail("avoidance did not display the authored response card: " + path_id)
			return
		var committed_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		var interstitial_bad_manifest := ""
		if path_id == "sword":
			var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://content/source_manifest.json"))
			for row in manifest.get("data", []):
				if row is Dictionary and row.get("path") == "data/combat/encounter_director.json":
					row["sha256"] = "0".repeat(64)
					break
			var bad_manifest := "user://tests/avoid_bad_source_%d.json" % Time.get_ticks_usec()
			interstitial_bad_manifest = bad_manifest
			var bad_file := FileAccess.open(bad_manifest, FileAccess.WRITE)
			bad_file.store_string(JSON.stringify(manifest))
			bad_file.close()
			var mismatched_store = RunSession.new(save_path, "slot_3")
			var mismatched = Domain.new(Registry.new(), mismatched_store, "slot_3",
				ContentRepository.new(bad_manifest))
			if mismatched.restore() or mismatched_store.last_error != "SOURCE_MISMATCH" \
					or not mismatched_store.archive_unrestorable().is_empty() \
					or FileAccess.get_file_as_string(game._store.v2_path) != committed_bytes:
				_fail("source drift silently resumed or discarded pending avoid result")
				return
		var reopened = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not reopened.restore() or not _same(reopened.state, game.state) \
				or reopened.get_current_card().get("id") != result["id"] \
				or reopened.choose("right", token) \
				or FileAccess.get_file_as_string(reopened._store.v2_path) != committed_bytes:
			_fail("avoidance response or cooldown failed to survive reload: " + path_id)
			return
		var result_token := reopened.issue_choice_token()
		if path_id == "sword":
			var original_gateway: RefCounted = reopened._battle_gateway
			var unchanged: Dictionary = reopened.state.duplicate(true)
			reopened._battle_gateway = BattleGateway.new(Registry.new(),
				ContentRepository.new(interstitial_bad_manifest))
			if reopened.choose("left", result_token) or not _same(reopened.state, unchanged) \
					or FileAccess.get_file_as_string(reopened._store.v2_path) != committed_bytes:
				_fail("acknowledgement committed against changed encounter rules")
				return
			reopened._battle_gateway = original_gateway
			DirAccess.remove_absolute(ProjectSettings.globalize_path(interstitial_bad_manifest))
		if path_id == "pill":
			var before_failed_ack: Dictionary = reopened.state.duplicate(true)
			reopened._store.fail_promotion_once = true
			if reopened.choose("left", result_token) \
					or not _same(reopened.state, before_failed_ack) \
					or FileAccess.get_file_as_string(reopened._store.v2_path) != committed_bytes:
				_fail("failed response acknowledgement changed durable state")
				return
		if not reopened.choose("left", result_token) \
				or reopened.state.get("phase") != "FLOW_PENDING" \
				or reopened.state.get("currentCardId") != "" \
				or int(reopened.state["runClock"]["decisionIndex"]) != 7 \
				or not reopened.state["cardsPlayed"].has(result["id"]) \
				or reopened.state["cardsPlayed"].has(offer_id) \
				or reopened.state["noncombatFlow"]["promise"].get("status") != "resolved" \
				or reopened.state["noncombatFlow"]["promise"].get("resolvedDecisionIndex") != 7 \
				or reopened.issue_choice_token() != 0:
			_fail("response acknowledgement did not preserve the true Flow boundary")
			return
		var flow_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_3"), "slot_3")
		if not flow_reload.restore() or not _same(flow_reload.state, reopened.state) \
				or flow_reload.choose("left", result_token):
			_fail("acknowledged result or encounter cooldown did not survive reload")
			return
	print("NONCOMBAT_AVOID_FLOW_PASS paths=4 source_effects=true cooldown_reload=true")
	quit(0)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
