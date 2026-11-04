extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const Gateway = preload("res://scripts/noncombat_battle_gateway.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases := [
		["sword", "left", "left"], ["sword", "right", "right"],
		["spell", "left", "right"], ["body", "left", "left"],
		["pill", "left", "right"],
	]
	for case in cases:
		var path_id: String = case[0]
		var origin_direction: String = case[1]
		var warning_direction: String = case[2]
		var save_path := "user://tests/warning_%s_%s_%d.json" % [
			path_id, origin_direction, Time.get_ticks_usec()]
		var registry = Registry.new()
		var game = Domain.new(registry, RunSession.new(save_path, "slot_2"), "slot_2")
		if not game.start(path_id) or not game.choose("right", game.issue_choice_token()) \
				or not game.choose("left", game.issue_choice_token()) \
				or not game.choose(origin_direction, game.issue_choice_token()):
			_fail("source opening did not reach an encounter: " + path_id)
			return
		var gateway = Gateway.new(registry)
		var offer: Dictionary = gateway.offer_from_state(game.state)
		var base_state: Dictionary = game.state.duplicate(true)
		var base_index := int(game.state["runClock"]["decisionIndex"])
		var offer_token := game.issue_choice_token()
		if offer.is_empty() or offer_token <= 0 or game.state != base_state:
			_fail("source offer was unavailable before challenge: " + path_id)
			return
		if path_id == "sword" and origin_direction == "left":
			var before_failed_write := FileAccess.get_file_as_string(game._store.v2_path)
			game._store.fail_promotion_once = true
			if game.choose("left", offer_token) or game.state != base_state \
					or FileAccess.get_file_as_string(game._store.v2_path) != before_failed_write:
				_fail("failed warning save exposed a decision or changed the stable file")
				return
		if not game.choose("left", offer_token) \
				or game.state.get("phase") != "WARNING_PENDING" \
				or game.get_current_card().get("type") != "COMBAT_WARNING" \
				or int(game.state["runClock"]["decisionIndex"]) != base_index \
				or game.state["choiceHistory"].size() != base_index \
				or game.state["cardsPlayed"].has(offer["sourceCardId"]):
			_fail("accepting encounter did not persist an unresolved warning: " + path_id)
			return
		var warning_bytes := FileAccess.get_file_as_string(game._store.v2_path)
		if path_id == "sword" and origin_direction == "left":
			var broken_path := "user://tests/broken_warning_%d_v1.json" % Time.get_ticks_usec()
			var broken_store = RunSession.new(broken_path, "slot_2")
			var broken_envelope: Dictionary = JSON.parse_string(warning_bytes)
			broken_envelope["state"]["pendingWarning"] = null
			var broken_file := FileAccess.open(broken_store.v2_path, FileAccess.WRITE)
			broken_file.store_string(JSON.stringify(broken_envelope))
			broken_file.close()
			var broken_game = Domain.new(Registry.new(), broken_store, "slot_2")
			if broken_game.restore() or not broken_game.state.is_empty():
				_fail("malformed warning was restored as a valid unresolved encounter")
				return
		var reopened = Domain.new(Registry.new(), RunSession.new(save_path, "slot_2"), "slot_2")
		if not reopened.restore() or not _same(reopened.state, game.state) \
				or reopened.get_current_card().get("type") != "COMBAT_WARNING" \
				or reopened.choose("left", offer_token):
			_fail("warning did not survive reload or accepted an old offer token: " + path_id)
			return
		var before_stones := int(reopened.state["resources"]["spiritStone"])
		var before_health := int(reopened.state["attributes"]["health"])
		if path_id == "sword" and origin_direction == "left":
			var starved: Dictionary = reopened.state.duplicate(true)
			starved["resources"]["spiritStone"] = 0
			if not reopened._encounter_flow.confirm(starved, "right").is_empty():
				_fail("warning preparation accepted an unaffordable source cost")
				return
		var warning_token := reopened.issue_choice_token()
		if path_id == "spell":
			var before_failed_confirmation: Dictionary = reopened.state.duplicate(true)
			var warning_stable_bytes := FileAccess.get_file_as_string(reopened._store.v2_path)
			reopened._store.fail_promotion_once = true
			if reopened.choose(warning_direction, warning_token) \
					or not _same(reopened.state, before_failed_confirmation) \
					or FileAccess.get_file_as_string(reopened._store.v2_path) != warning_stable_bytes:
				_fail("failed preparation save spent resources or changed the warning")
				return
		if not reopened.choose(warning_direction, warning_token) \
				or reopened.state.get("phase") != "BATTLE_PENDING" \
				or int(reopened.state["runClock"]["decisionIndex"]) != base_index \
				or reopened.state["choiceHistory"].size() != base_index \
				or reopened.state["cardsPlayed"].has(offer["sourceCardId"]):
			_fail("warning confirmation prematurely settled the source decision: " + path_id)
			return
		var cost := 10 if warning_direction == "right" else 0
		if int(reopened.state["resources"]["spiritStone"]) != before_stones - cost \
				or int(reopened.state["attributes"]["health"]) != mini(
					int(reopened.state["maxHealth"]), before_health + (1 if cost > 0 else 0)):
			_fail("warning preparation diverged from the browser cost: " + path_id)
			return
		var request: Dictionary = gateway.build_request(reopened.state)
		if request.get("contractVersion") != 2 \
				or request.get("sourceCardId") != offer["sourceCardId"] \
				or request.get("warningChoiceDirection") != warning_direction \
				or request.get("baseDecisionIndex") != base_index:
			_fail("real persisted warning failed to create the battle contract: " + path_id)
			return
		var pending_bytes := FileAccess.get_file_as_string(reopened._store.v2_path)
		if path_id == "sword" and origin_direction == "left":
			for changed_source in ["data/config/paths.json",
					"data/combat/encounter_director.json"]:
				var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
					"res://content/source_manifest.json"))
				for row in manifest.get("data", []):
					if row is Dictionary and row.get("path") == changed_source:
						row["sha256"] = "0".repeat(64)
						break
				var bad_manifest := "user://tests/warning_bad_source_%d.json" % Time.get_ticks_usec()
				var bad_file := FileAccess.open(bad_manifest, FileAccess.WRITE)
				bad_file.store_string(JSON.stringify(manifest))
				bad_file.close()
				var mismatched_store = RunSession.new(save_path, "slot_2")
				var mismatched = Domain.new(Registry.new(), mismatched_store, "slot_2",
					ContentRepository.new(bad_manifest))
				if mismatched.restore() or mismatched_store.last_error != "SOURCE_MISMATCH" \
						or not mismatched_store.archive_unrestorable().is_empty() \
						or FileAccess.get_file_as_string(reopened._store.v2_path) != pending_bytes:
					_fail("source drift discarded or silently resumed a pending battle: " + changed_source)
					return
				DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_manifest))
		var pending_reload = Domain.new(Registry.new(), RunSession.new(save_path, "slot_2"), "slot_2")
		if not pending_reload.restore() or not _same(pending_reload.state, reopened.state) \
				or not _same(gateway.build_request(pending_reload.state), request) \
				or pending_reload.issue_choice_token() != 0 \
				or pending_reload.choose("left", warning_token) \
				or FileAccess.get_file_as_string(pending_reload._store.v2_path) != pending_bytes:
			_fail("pending battle changed across reload or duplicated confirmation: " + path_id)
			return
		var resumed_plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
			pending_reload.state)
		if resumed_plan.is_empty() or resumed_plan.get("sourceAuthenticated") != true \
				or resumed_plan.get("launchAuthorized") != true \
				or resumed_plan.get("sceneAvailable") != true \
				or resumed_plan.get("encounterInstanceId") != request.get("encounterInstanceId") \
				or resumed_plan.get("battlefieldId") != request.get("battlefieldId") \
				or resumed_plan.get("path") != path_id:
			_fail("真实预警与重载状态不能变成可信只读战斗计划：" + path_id)
			return
		if warning_bytes == pending_bytes:
			_fail("warning and pending battle did not have distinct committed snapshots")
			return
	print("NONCOMBAT_WARNING_FLOW_PASS cases=%d persisted_warning=true pending_request=true" % cases.size())
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
