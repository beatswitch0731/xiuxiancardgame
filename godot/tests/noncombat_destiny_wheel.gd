extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

class MissingTreasureContent extends "res://scripts/noncombat_content_repository.gd":
	func module_path(module_id: String) -> String:
		if module_id == "shops:treasures":
			return ""
		return super.module_path(module_id)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/destiny_wheel_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._destiny_wheel_flow.roll_override = 0.0
	if not _reach_fifteenth_choice(game):
		return _fail("browser fifteenth-decision route unreachable")
	var wheel: Dictionary = game.get_current_card()
	if game.state.get("phase") != "DESTINY_WHEEL_PENDING" \
			or wheel.get("type") != "DESTINY_WHEEL" \
			or wheel.get("wheelState", {}).get("deck", []).size() != 5 \
			or wheel.get("wheelState", {}).get("flipped") != 0:
		return _fail("due wheel did not preempt mentor result")
	for reward in wheel["wheelState"]["deck"]:
		if reward.get("name") != "龙脉印记" or reward.get("rarity") != "legendary":
			return _fail("fixed-zero browser wheel deck differs")
	var covered: Dictionary = game.state.duplicate(true)
	covered["phase"] = "NORMAL_PENDING"
	covered["currentCardId"] = "secret_sword_2"
	covered["destinyWheelTicks"] = 14
	var ticked: Dictionary = covered.duplicate(true)
	ticked["runClock"]["decisionIndex"] = 16
	ticked["turn"] = 16
	if not game._destiny_wheel_flow.settle(covered, ticked, false, 0, 0) \
			or ticked.get("destinyWheelTicks") != 15 \
			or ticked.get("pendingDestinyWheel", {}).get("triggerDecisionIndex") != 15:
		return _fail("active wheel was duplicated on the next interval")
	ticked["phase"] = "FLOW_PENDING"
	ticked["currentCardId"] = ""
	var deferred: Dictionary = game._destiny_wheel_flow.resume_deferred(ticked)
	if deferred.get("phase") != "DESTINY_WHEEL_PENDING" \
			or deferred.get("wheelReturn", {}).get("phase") != "FLOW_PENDING" \
			or game._destiny_wheel_flow.flip(deferred, "left").get("phase") != "FLOW_PENDING":
		return _fail("dungeon-covered wheel did not return to live flow")
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	restored._destiny_wheel_flow.roll_override = 0.0
	var reloaded := restored.restore()
	if not reloaded or not _same(restored.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		print("wheel restore diagnostics error=", restored._store.last_error,
			" reload=", reloaded, " equal=", restored.state == before)
		return _fail("pending wheel did not strictly reload")
	var token: int = restored.issue_choice_token()
	if token <= 0 or restored.choose("down", token - 1) \
			or restored.choose("invalid", token):
		return _fail("wheel token or direction admitted invalid input")
	restored._store.fail_promotion_once = true
	if restored.choose("left", token) or not _same(restored.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return _fail("failed flip commit leaked reward")
	if not restored.choose("left", token) \
			or restored.state.get("phase") != "NARRATIVE_RESULT_PENDING" \
			or not String(restored.get_current_card().get("id", "")).begins_with("promise_result_") \
			or restored.choose("left", token):
		return _fail("wheel flip did not restore mentor result exactly once")
	var attrs: Dictionary = restored.state["attributes"]
	if int(attrs.get("cultivation", -1)) != 100 \
			or int(attrs.get("daoHeart", -1)) != 4 \
			or int(attrs.get("fortune", -1)) != 85 \
			or int(restored.state["runClock"]["decisionIndex"]) != 15:
		return _fail("fixed-zero Dragon Mark reward differs from browser trace")
	var final_state: Dictionary = restored.state.duplicate(true)
	var final_bytes := FileAccess.get_file_as_string(store.v2_path)
	var final_reload = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	final_reload._destiny_wheel_flow.roll_override = 0.0
	if not final_reload.restore() or not _same(final_reload.state, final_state) \
			or FileAccess.get_file_as_string(store.v2_path) != final_bytes:
		return _fail("flipped wheel did not strictly replay")
	var rarities_ok: bool = _check_rarities_and_rewards()
	var treasure_ok: bool = _check_treasure_reward()
	var old_ok: bool = _check_old_save_upgrade()
	var drift_ok: bool = _check_source_drift(store)
	if not rarities_ok or not treasure_ok or not old_ok or not drift_ok:
		return _fail("wheel variants, old save upgrade or source drift: rarities=%s treasure=%s old=%s drift=%s" % [
			rarities_ok, treasure_ok, old_ok, drift_ok])
	print("NONCOMBAT_DESTINY_WHEEL_PASS trigger=15 deck=5 flip=once rollback=true replay=true")
	quit(0)


func _reach_fifteenth_choice(game: RefCounted) -> bool:
	if not game.start("sword"):
		return false
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("down", game.issue_choice_token()) \
		and game.resume_flow() and game.get_current_card().get("id") == "ch_qi_60" \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and String(game.get_current_card().get("id", "")).begins_with("kx_") \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.get_current_card().get("id") == \
			"mentor_bai_ren_stage_INNER_DISCIPLE" \
		and game.choose("left", game.issue_choice_token()) \
		and int(game.state.get("runClock", {}).get("decisionIndex", -1)) == 15


func _check_rarities_and_rewards() -> bool:
	for example in [
		{"roll": 0.16, "reward": "attack_bonus", "field": "flags", "key": "atkBonus", "delta": 5},
		{"roll": 0.4, "reward": "spirit_stones_30", "field": "resources", "key": "spiritStone", "delta": 30},
		{"roll": 0.8, "reward": "lifespan_peach", "field": "resources", "key": "lifespan", "delta": 3},
	]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		game._destiny_wheel_flow.roll_override = example["roll"]
		if not _reach_fifteenth_choice(game):
			return false
		var wheel: Dictionary = game.get_current_card()["wheelState"]
		if wheel["deck"][0]["rewardId"] != example["reward"]:
			return false
		var before := int(game.state.get(example["field"], {}).get(example["key"], 0))
		if not game.choose("left", game.issue_choice_token()) \
				or int(game.state.get(example["field"], {}).get(example["key"], 0)) \
				!= before + example["delta"]:
			return false
	var empty = Domain.new(Registry.new(), null, "slot_3")
	empty._destiny_wheel_flow.roll_override = 0.99
	if not _reach_fifteenth_choice(empty):
		return false
	var deck: Array = empty.get_current_card()["wheelState"]["deck"]
	var rare_or_better := 0
	var empty_count := 0
	for reward in deck:
		if reward["rarity"] in ["rare", "epic", "legendary"]: rare_or_better += 1
		if reward["rarity"] == "empty": empty_count += 1
	if rare_or_better < 1 or empty_count > 1 \
			or deck[0]["rewardId"] != "lifespan_peach" \
			or deck[3]["rewardId"] != "empty" \
			or deck[4]["rarity"] != "epic":
		return false
	var prior_lifespan := int(empty.state["resources"]["lifespan"])
	return empty.choose("left", empty.issue_choice_token()) \
		and int(empty.state["resources"]["lifespan"]) == prior_lifespan + 3


func _check_old_save_upgrade() -> bool:
	var path := "user://tests/destiny_old_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	if not game.start("sword"):
		return false
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.v2_path))
	for key in ["destinyWheelVersion", "destinyWheelRuleSourceSha",
			"destinyWheelActivationIndex", "destinyWheelRngState", "destinyWheelTicks"]:
		envelope["state"].erase(key)
	var old_bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(old_bytes)
	file.close()
	var old = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	var restored_old: bool = old.restore()
	if not restored_old or old.state.has("destinyWheelVersion") \
			or FileAccess.get_file_as_string(store.v2_path) != old_bytes:
		print("old wheel restore: ok=", restored_old, " error=", old._store.last_error,
			" state=", old.state.get("phase"), " savedMentor=", envelope.state.get(
				"mentorArcState", {}), " loadedMentor=", old.state.get(
				"mentorArcState", {}))
		return false
	var prior: Dictionary = old.state.duplicate(true)
	old._store.fail_promotion_once = true
	if old.choose("left", old.issue_choice_token()) or not _same(old.state, prior) \
			or FileAccess.get_file_as_string(store.v2_path) != old_bytes:
		return false
	return old.choose("left", old.issue_choice_token()) \
		and old.state.get("destinyWheelVersion") == 1


func _check_treasure_reward() -> bool:
	var path := "user://tests/destiny_treasure_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._legacy_wheel_replay_initial_seed = 4
	if not _reach_fifteenth_choice(game):
		return false
	var deck: Array = game.get_current_card()["wheelState"]["deck"]
	if deck[0]["rewardId"] != "hunyuan_stone":
		print("stone seed produced ", deck[0])
		return false
	if not game.choose("left", game.issue_choice_token()):
		return false
	var instances: Dictionary = game.state.get("treasureInstances", {})
	var instance: Dictionary = instances.get("tr:混元神石:1", {})
	var resources: Dictionary = game.state.get("resources", {})
	var receipt := String(instance.get("transactionId", ""))
	if instance.get("definitionId") != "混元神石" \
			or not receipt.contains(":decision:16:slot:0:item:混元神石") \
			or int(instance.get("acquiredDecision", -1)) != 16 \
			or not resources.get("treasures", []).has("混元神石") \
			or not game.state.get("treasureInventory", []).has("tr:混元神石:1") \
			or game.state.get("treasureCommandReceipts", {}).get(receipt, {}).get(
				"instanceId") != "tr:混元神石:1":
		return false
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	restored._legacy_wheel_replay_initial_seed = 4
	if not restored.restore() or not _same(before, restored.state) \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return false
	var missing_store = RunSession.new(path, "slot_3")
	var missing = Domain.new(Registry.new(), missing_store, "slot_3",
		MissingTreasureContent.new())
	if missing.restore() or missing_store.last_error != "SOURCE_UNAVAILABLE" \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return false
	return true


func _check_source_drift(current_store: RefCounted) -> bool:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(current_store.v2_path))
	envelope["state"]["destinyWheelRuleSourceSha"] = "f".repeat(64)
	var path := "user://tests/destiny_drift_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	return not game.restore() and store.last_error == "SOURCE_MISMATCH" \
		and FileAccess.get_file_as_string(store.v2_path) == bytes


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
