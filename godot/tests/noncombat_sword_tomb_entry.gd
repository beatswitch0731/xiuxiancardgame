extends "res://tests/noncombat_normal_runtime.gd"

func _run() -> void:
	var path := "user://tests/sword_tomb_entry_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(game)
	if not _reach_decision27(game):
		return _fail("natural ordinary pre-draw route failed")
	game._normal_roll_override = 0.46
	if not game.resume_flow() or game.get_current_card().get("id") != "q_swordTomb":
		return _fail("ordinary pool drew %s instead of sword tomb: %s" % [
			game.get_current_card().get("id"), game._normal_flow_error])
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/sword_tomb_source.json"))
	var card: Dictionary = game.get_current_card()
	for key in ["id", "title", "description", "type", "realm", "path", "choices", "sceneImage"]:
		if not _same_value(card.get(key), oracle["sourceCard"].get(key)):
			return _fail("ordinary sword tomb card differs from browser: " + key)
	if not game.can_choose_direction("left"):
		return _fail("source sword tomb treasure and seed choice was blocked")
	var before: Dictionary = game.state.duplicate(true)
	var next_decision := int(before["runClock"]["decisionIndex"]) + 1
	if not game.choose("left", game.issue_choice_token()):
		return _fail("source sword tomb left choice did not settle")
	var after: Dictionary = game.state
	if int(after["attributes"]["cultivation"]) != mini(100,
			int(before["attributes"]["cultivation"]) + 10) \
			or int(after["attributes"]["karmaBad"]) != mini(100,
				int(before["attributes"]["karmaBad"]) + 5):
		return _fail("sword tomb numeric choice differs from browser")
	var instance: Dictionary = after.get("treasureInstances", {}).get("tr:brokenSword:1", {})
	var source_instance: Dictionary = oracle["after"]["treasureInstances"]["tr:brokenSword:1"]
	for key in ["instanceId", "definitionId", "provenance", "lifecycle"]:
		if not _same_value(instance.get(key), source_instance.get(key)):
			return _fail("sword tomb treasure differs from browser: " + key)
	if instance.get("acquiredDecision") != next_decision \
			or after["resources"].get("treasures", []).count("brokenSword") != 1 \
			or not after.get("treasureInventory", []).has("tr:brokenSword:1"):
		return _fail("sword tomb ownership ledger differs from browser")
	var transaction_id := "treasure:narrative:life:%s:decision:%d:source:q_swordTomb:item:brokenSword" % [
		before["runClock"]["lifeId"], next_decision]
	if instance.get("transactionId") != transaction_id \
			or after.get("treasureCommandReceipts", {}).get(transaction_id, {}).get(
				"instanceId") != "tr:brokenSword:1":
		return _fail("sword tomb acquisition receipt differs from browser")
	var seed: Dictionary = {}
	for row in after.get("karmaSeeds", []):
		if row.get("id") == "swordHonor":
			seed = row
			break
	if seed.is_empty():
		return _fail("sword tomb did not plant swordHonor")
	var source_seed: Dictionary = {}
	for row in oracle["after"]["karmaSeeds"]:
		if row.get("id") == "swordHonor":
			source_seed = row
			break
	for key in ["delay", "realm", "priority", "originLife", "originCard",
			"originChoice", "context"]:
		if not _same_value(seed.get(key), source_seed.get(key)):
			return _fail("sword tomb seed differs from browser: " + key)
	if seed.get("originTurn") != next_decision \
			or after.get("storyThreadState", {}).get("threads", {}).get(
				"sword_tomb_trial", {}).get("status") == "active":
		return _fail("sword tomb seed turn or trigger delay differs from browser")
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_set_zero_rolls(restored)
	restored._normal_roll_override = 0.46
	if not restored.restore() or not _same_value(restored.state, after):
		return _fail("sword tomb ordinary choice failed strict cold replay")
	if not _continue_to(game, "thread_sword_tomb_1"):
		return _fail("sword tomb choice did not activate its first thread node")
	var first: Dictionary = game.get_current_card()
	for key in ["id", "semanticKey", "title", "description", "sceneImage", "choices"]:
		if not _same_value(first.get(key), oracle["firstCard"].get(key)):
			return _fail("first sword tomb node differs from browser: " + key)
	if not _reopen(game):
		return _fail("first sword tomb pending node failed strict cold replay")
	var branch_path := "user://tests/sword_tomb_defer_%d.json" % Time.get_ticks_usec()
	var branch_store = RunSession.new(branch_path, "slot_3")
	if branch_store.commit_snapshot(game.state, -1).get("ok") != true:
		return _fail("first sword tomb choice could not be forked")
	var deferred = Domain.new(Registry.new(), branch_store, "slot_3")
	_set_zero_rolls(deferred)
	deferred._normal_roll_override = 0.46
	if not deferred.restore() or not deferred.choose("right", deferred.issue_choice_token()):
		return _fail("sword tomb defer branch did not settle")
	var deferred_runtime: Dictionary = deferred.state.get("storyThreadState", {}).get(
		"threads", {}).get("sword_tomb_trial", {})
	if deferred_runtime.get("status") != "declined" \
			or deferred_runtime.get("receipt", {}).get("status") != "declined" \
			or deferred_runtime.get("receipt", {}).get("nodes", []).size() != 1 \
			or deferred_runtime.get("choices", [])[0].get("threadDirection") != "defer" \
			or int(deferred.state["attributes"]["fortune"]) != mini(100,
				int(game.state["attributes"]["fortune"]) + 5) \
			or not _reopen(deferred):
		return _fail("sword tomb defer receipt or reward differs from browser")
	if not game.choose("left", game.issue_choice_token()):
		return _fail("sword tomb accept branch did not settle")
	var accepted_runtime: Dictionary = game.state.get("storyThreadState", {}).get(
		"threads", {}).get("sword_tomb_trial", {})
	if accepted_runtime.get("status") != "active" \
			or accepted_runtime.get("nodeIndex") != 1 \
			or accepted_runtime.get("choices", []).size() != 1 \
			or accepted_runtime["choices"][0].get("threadDirection") != "accept" \
			or not _reopen(game):
		return _fail("sword tomb accept history or replay differs from browser")
	if not _continue_to(game, "thread_sword_tomb_2"):
		return _fail("accepted sword tomb trial did not reach its combat node")
	var second: Dictionary = game.get_current_card()
	var source_threads: Array = game._content.read_module("threads:qi_threads")["threads"]
	var source_thread: Dictionary = {}
	for row in source_threads:
		if row.get("threadId") == "sword_tomb_trial":
			source_thread = row
			break
	if second.get("type") != "COMBAT" or second.get("enemy") != source_thread[
			"nodes"][1]["card"]["enemy"] or not _reopen(game):
		return _fail("second sword tomb node lost authored combat enemy or replay")
	if not game.can_choose_direction("left") or not game.can_choose_direction("right"):
		return _fail("sword tomb authored combat directions are unavailable")
	var second_state: Dictionary = game.state.duplicate(true)
	for battle_direction in ["left", "right"]:
		var battle_path := "user://tests/sword_tomb_%s_%d.json" % [
			battle_direction, Time.get_ticks_usec()]
		var battle_store = RunSession.new(battle_path, "slot_3")
		if battle_store.commit_snapshot(second_state, -1).get("ok") != true:
			return _fail("sword tomb battle direction could not fork")
		var battle = Domain.new(Registry.new(), battle_store, "slot_3")
		_set_zero_rolls(battle)
		battle._normal_roll_override = 0.46
		if not battle.restore() or not battle.choose(battle_direction,
				battle.issue_choice_token()):
			return _fail("sword tomb combat direction did not enter warning: " + battle_direction)
		var warning: Dictionary = battle.get_current_card()
		var expected_warning: Dictionary = oracle["battleBranches"][
			battle_direction + "_victory"]["warningCard"]
		for key in ["id", "title", "description", "sceneImage", "choices"]:
			if not _same_value(warning.get(key), expected_warning.get(key)):
				return _fail("sword tomb warning differs from browser: " + battle_direction + "/" + key)
		if not _reopen(battle) or not battle.choose("left", battle.issue_choice_token()):
			return _fail("sword tomb warning could not confirm: " + battle_direction)
		var request: Dictionary = battle.battle_request()
		if request.get("sourceCardId") != "thread_sword_tomb_2" \
				or request.get("threadId") != "sword_tomb_trial" \
				or request.get("direction") != battle_direction \
				or request.get("encounterId") != null \
				or request.get("pendingResolution", {}).get("combatCard", {}).get(
					"enemy", {}).get("templateId") != "sword_intent_avatar_qi" \
				or not _reopen(battle):
			return _fail("sword tomb battle request or cold replay failed: " + battle_direction)
	print("NONCOMBAT_SWORD_TOMB_ENTRY_PASS natural=true treasure=true seed=true first_node=true branches=2 battle_directions=2 replay=true")
	quit(0)


func _same_value(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _reopen(game: RefCounted) -> bool:
	var loaded = Domain.new(Registry.new(), RunSession.new(game._store.legacy_path, "slot_3"), "slot_3")
	_set_zero_rolls(loaded)
	loaded._normal_roll_override = 0.46
	return loaded.restore() and _same_value(loaded.state, game.state) \
		and _same_value(loaded.get_current_card(), game.get_current_card())


func _continue_to(game: RefCounted, target: String) -> bool:
	for step in 20:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return false
		if game.get_current_card().get("id") == target:
			return true
		if game.state.get("phase") == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			var result := {"contractVersion": 2,
				"encounterInstanceId": request.get("encounterInstanceId"),
				"sourceCardId": request.get("sourceCardId"),
				"encounterId": request.get("encounterId"),
				"sourceContentHash": request.get("sourceContentHash"),
				"outcome": "victory",
				"combatReceipt": "combat:" + String(request.get("encounterInstanceId", "")),
				"postBattleState": {"encounterInstanceId": request.get("encounterInstanceId"),
					"terminal": true, "combatPhase": "VICTORY"}}
			if not game.submit_battle_result(result):
				return false
			continue
		if game.state.get("phase") == "BATTLE_RESULT_PENDING":
			if not game.choose("down", game.issue_choice_token()):
				return false
			continue
		if game.state.get("phase") == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return false
			continue
		var direction := "left" if game.can_choose_direction("left") else "right"
		if game.get_current_card().get("id") == "q_shop" and game.can_choose_direction("down"):
			direction = "down"
		elif game.get_current_card().get("id") == "q_market" and game.can_choose_direction("right"):
			direction = "right"
		elif game.state.get("phase") == "MARKET_PENDING" and game.can_choose_direction("right"):
			direction = "right"
		if not game.choose(direction, game.issue_choice_token()):
			return false
	return false
