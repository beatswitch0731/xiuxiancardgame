extends "res://tests/noncombat_foundation_shop_natural.gd"

const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")


func _fixed_roll() -> float:
	return 0.0


func _target_card_id() -> String:
	return "f_mission"


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.realm != "foundation" or game.state.phase != "NORMAL_PENDING" \
			or game.get_current_card().get("id") != "f_mission" \
			or not game.can_choose_direction("right"):
		return _fail("natural foundation beast mission is not actionable")
	var entry: Dictionary = game.state.duplicate(true)
	var entry_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	for outcome in ["victory", "defeat", "flee"]:
		var branch_path := "user://tests/foundation_mission_%s_%d.json" % [
			outcome, Time.get_ticks_usec()]
		var branch = _shop_branch(entry_bytes, branch_path)
		if branch == null or not _same(branch.state, entry):
			return _fail("natural beast pending card did not strictly restore: " + outcome)
		var card: Dictionary = branch.get_current_card()
		if card.get("id") != "f_mission" or card.get("enemy", {}).get(
				"templateId") != "blazing_tiger_foundation" \
				or not branch.choose("right", branch.issue_choice_token()) \
				or branch.state.phase != "WARNING_PENDING":
			return _fail("natural beast mission warning route failed: " + outcome)
		var warning: Dictionary = branch.state.duplicate(true)
		var cold_warning = _shop_branch(FileAccess.get_file_as_bytes(
			branch._store.v2_path), branch_path)
		if cold_warning == null or not _same(cold_warning.state, warning) \
				or not cold_warning.choose("left", cold_warning.issue_choice_token()) \
				or cold_warning.state.phase != "BATTLE_PENDING":
			return _fail("natural beast warning did not enter battle: " + outcome)
		var request: Dictionary = cold_warning.battle_request()
		var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(
			cold_warning.state)
		if request.get("sourceCardId") != "f_mission" \
				or request.get("pendingResolution", {}).get("combatCard", {}).get(
					"enemy", {}).get("templateId") != "blazing_tiger_foundation" \
				or request.get("playerSnapshot", {}).get("modifiers") != cold_warning.state.get("modifiers", {}) \
				or request.get("playerSnapshot", {}).get("knowledge") != cold_warning.state.get("knowledge", {}) \
				or plan.get("launchAuthorized") != true:
			return _fail("natural beast mission plan or request differs: " + outcome)
		if outcome == "victory":
			var stage_context: Dictionary = StageRouter.new(Registry.new()).resolve_choice(
				"f_mission", "right", request.get("pendingResolution", {}).get(
					"combatCard", {}), String(request.encounterInstanceId),
				request.get("pendingResolution", {}), String(request.path),
				String(request.realm))
			stage_context["path"] = plan.get("path", "")
			stage_context["deck"] = plan.get("deck", []).duplicate(true)
			var stage: Control = load(
				"res://scenes/duel_stage_mission_2d.tscn").instantiate()
			var source_assets: bool = stage.source_assets_ready(Registry.new(),
				stage_context)
			var bound: bool = stage.bind_stage_context(stage_context) \
				if not stage_context.is_empty() else false
			if bound:
				root.add_child(stage)
			var hd2d: bool = stage.has_hd2d_assets() if bound else false
			if stage_context.is_empty() or not source_assets or not bound or not hd2d:
				print("MISSION_STAGE_DIAG " + JSON.stringify({
					"sourceCardId": stage_context.get("sourceCardId"),
					"battlefieldId": stage_context.get("battlefieldId"),
					"sourceAssets": source_assets, "bound": bound, "hd2d": hd2d}))
				stage.free()
				return _fail("natural beast mission desktop stage could not bind")
			stage.queue_free()
		var pending: Dictionary = cold_warning.state.duplicate(true)
		var cold_battle = _shop_branch(FileAccess.get_file_as_bytes(
			cold_warning._store.v2_path), branch_path)
		if cold_battle == null or not _same(cold_battle.state, pending):
			return _fail("natural beast battle request did not strictly restore: " + outcome)
		var result: Dictionary = _result_for(request, outcome)
		var foreign: Dictionary = result.duplicate(true)
		foreign.encounterInstanceId = "foreign:owner"
		if cold_battle.submit_battle_result(foreign) \
				or not _same(cold_battle.state, pending):
			return _fail("natural beast accepted foreign battle result: " + outcome)
		var before_bytes := FileAccess.get_file_as_bytes(cold_battle._store.v2_path)
		cold_battle._store.fail_promotion_once = true
		if cold_battle.submit_battle_result(result) \
				or not _same(cold_battle.state, pending) \
				or FileAccess.get_file_as_bytes(cold_battle._store.v2_path) != before_bytes:
			return _fail("natural beast failed write mutated save or state: " + outcome)
		if not cold_battle.submit_battle_result(result) \
				or cold_battle.state.phase != "BATTLE_RESULT_PENDING" \
				or cold_battle.state.choiceHistory.back().direction != "right":
			return _fail("natural beast result failed: " + outcome + "/" \
				+ cold_battle.flow_failure_reason())
		var after: Dictionary = cold_battle.state.duplicate(true)
		var expected_id := "combat_reward" if outcome == "victory" else (
			"combat_defeat_f_mission" if outcome == "defeat" else "combat_fled_f_mission")
		if cold_battle.get_current_card().get("id") != expected_id \
				or cold_battle.submit_battle_result(result):
			return _fail("natural beast duplicate/result card mismatch: " + outcome)
		if outcome == "victory":
			var source_skills: Dictionary = ContentRepository.new().read_module(
				"config:path_skills")
			var stone_ratio := 0.0
			for skill in source_skills.get("skills", {}).get("spell", {}).get("skills", []):
				if skill.get("unlockRealm") == "foundation":
					stone_ratio += float(skill.get("passive", {}).get(
						"spiritStoneBonus", 0.0))
			var authored_stones := int(card.get("combatRewards", {}).get(
				"spiritStone", 0))
			var base_stones := floori(maxi(1, int(card.get("enemy", {}).get(
				"atk", 0))) * 1.5)
			var expected_stones := base_stones + authored_stones \
				+ floori(authored_stones * stone_ratio)
			if int(after.resources.pills.get("筑基丹", 0)) - int(
					pending.resources.pills.get("筑基丹", 0)) != 1 \
					or int(after.attributes.karmaBad) - int(pending.attributes.karmaBad) != 5 \
					or not is_equal_approx(stone_ratio, 0.2) \
					or int(after.resources.spiritStone) - int(
					pending.resources.spiritStone) != expected_stones \
					or int(after.attributes.cultivation) != mini(100,
						int(pending.attributes.cultivation) + 42):
				return _fail("natural beast victory rewards differ: " + JSON.stringify({
					"before": {"pills": pending.resources.pills,
						"bad": pending.attributes.karmaBad,
						"stone": pending.resources.spiritStone,
						"cultivation": pending.attributes.cultivation},
					"after": {"pills": after.resources.pills,
						"bad": after.attributes.karmaBad,
						"stone": after.resources.spiritStone,
						"cultivation": after.attributes.cultivation},
					"expectedStones": expected_stones}))
		elif outcome == "defeat":
			if int(after.attributes.daoHeart) != int(pending.attributes.daoHeart) - 1 \
					or int(after.attributes.health) != int(pending.attributes.health) - 2:
				return _fail("natural beast defeat effects differ")
		elif int(after.resources.lifespan) != int(pending.resources.lifespan) - 1:
			return _fail("natural beast flee cost differs")
		var settled = _shop_branch(FileAccess.get_file_as_bytes(
			cold_battle._store.v2_path), branch_path)
		if settled == null:
			return _fail("natural beast result could not strictly restore: " + outcome)
		if not _same(settled.state, after) \
				or settled.get_current_card().get("id") != expected_id:
			return _fail("natural beast restored result differs: " + outcome)
		if not settled.choose("down", settled.issue_choice_token()):
			return _fail("natural beast result acknowledgement failed: " + outcome)
		if settled.state.phase == "FLOW_PENDING":
			if not settled.resume_flow():
				return _fail("natural beast result continuation failed: " + outcome)
		elif settled.state.phase == "DESTINY_WHEEL_PENDING":
			if settled.get_current_card().get("id") != "destiny_wheel" \
					or not settled.can_choose_direction("left"):
				return _fail("natural beast destiny continuation failed: " + outcome)
		else:
			return _fail("natural beast result stopped on " + settled.state.phase)
		print("FOUNDATION_MISSION_NATURAL_OUTCOME_PASS " + outcome)
	print("NONCOMBAT_FOUNDATION_MISSION_NATURAL_PASS draw=true warning=true battle=true outcomes=3 replay=true rollback=true")
	quit(0)
