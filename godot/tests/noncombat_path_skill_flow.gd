extends SceneTree

const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var skills = PathSkillFlow.new()
	var state := {"path": "sword", "realm": "qi", "maxHealth": 6,
		"runClock": {"decisionIndex": 4}, "pathSkillActivationIndex": 5}
	if not skills.activation_valid(state) or not skills.active_bonuses(state).is_empty():
		return _fail("qi path or activation boundary is wrong")
	state["realm"] = "foundation"
	if int(skills.active_bonuses(state).get("critRate", 0)) != 1:
		return _fail("foundation sword skill is missing")
	state["realm"] = "golden"
	if not is_equal_approx(float(skills.active_bonuses(state).get("daoResist", 0)), 0.5) \
			or skills.effect_delta(state, "daoHeart", -5) != -3:
		return _fail("golden sword dao-heart resistance differs")
	state["realm"] = "nascent"
	if int(skills.active_bonuses(state).get("lowHpAtkBonus", 0)) != 1:
		return _fail("nascent sword skill is missing")
	state["path"] = "spell"
	state["realm"] = "foundation"
	if skills.effect_delta(state, "spiritStone", 11) != 13:
		return _fail("foundation spell stone bonus differs")
	state["realm"] = "golden"
	if skills.effect_delta(state, "cultivation", 3, "f_meditation") != 6 \
			or skills.effect_delta(state, "cultivation", 3, "f_herbs") != 3:
		return _fail("golden spell meditation context differs")
	state["realm"] = "nascent"
	if int(skills.active_bonuses(state).get("critRate", 0)) != 10 \
			or skills.dungeon_bonus(state) != 5:
		return _fail("nascent spell dungeon skill differs")
	state["path"] = "body"
	state["realm"] = "foundation"
	if skills.actual_max_health(state) != 8:
		return _fail("foundation body max-health skill differs")
	state["realm"] = "golden"
	if int(skills.active_bonuses(state).get("hpRegen", 0)) != 1:
		return _fail("golden body regeneration skill differs")
	state["realm"] = "nascent"
	if int(skills.active_bonuses(state).get("def", 0)) != 1:
		return _fail("nascent body defense skill differs")
	state["path"] = "pill"
	state["realm"] = "foundation"
	if skills.breakthrough_cultivation_bonus(state, 100, true) != 50 \
			or skills.breakthrough_cultivation_bonus(state, 100, false) != 0:
		return _fail("foundation pill breakthrough bonus differs")
	state["realm"] = "golden"
	if not is_equal_approx(float(skills.active_bonuses(state).get("poisonResist", 0)), 0.5):
		return _fail("golden pill poison passive is missing")
	state["realm"] = "nascent"
	if int(skills.active_bonuses(state).get("stoneToPill", 0)) != 20:
		return _fail("nascent pill shop passive is missing")
	state["pathSkillActivationIndex"] = 6
	if skills.activation_valid(state) or not skills.active_bonuses(state).is_empty() \
			or skills.last_error.is_empty():
		return _fail("future activation marker was accepted")
	state["phase"] = "BATTLE_PENDING"
	if not skills.activation_valid(state) or not skills.active_bonuses(state, 5).is_empty():
		return _fail("frozen legacy battle gained a future passive")
	state.erase("phase")
	state["pathSkillActivationIndex"] = 5
	if not skills.active_bonuses(state, 4).is_empty() \
			or int(skills.active_bonuses(state, 5).get("stoneToPill", 0)) != 20:
		return _fail("activation decision was applied to prior history")
	state.erase("pathSkillActivationIndex")
	if not skills.active_bonuses(state).is_empty() or not skills.last_error.is_empty():
		return _fail("legacy save without marker gained new passives")
	print("NONCOMBAT_PATH_SKILL_FLOW_PASS paths=4 skills=12 activation=true")
	quit(0)


func _fail(message: String) -> void:
	printerr("NONCOMBAT_PATH_SKILL_FLOW_FAIL " + message)
	quit(1)
