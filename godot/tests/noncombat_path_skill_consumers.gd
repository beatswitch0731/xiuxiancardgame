extends SceneTree

const Content = preload("res://scripts/noncombat_content_repository.gd")
const Milestone = preload("res://scripts/noncombat_milestone_flow.gd")
const NascentCave = preload("res://scripts/noncombat_nascent_cave_flow.gd")
const Gateway = preload("res://scripts/noncombat_battle_gateway.gd")
const Combat = preload("res://scripts/combat_domain.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const PathSkill = preload("res://scripts/noncombat_path_skill_flow.gd")
const NormalChoice = preload("res://scripts/noncombat_normal_choice_policy.gd")
const RegulatedVendor = preload("res://scripts/noncombat_regulated_vendor_flow.gd")
const LastLessonVendor = preload("res://scripts/noncombat_last_lesson_vendor_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = Content.new()
	var milestone = Milestone.new(content)
	var spell := {"path": "spell", "realm": "foundation",
		"pathSkillActivationIndex": 5, "runClock": {"decisionIndex": 4},
		"attributes": {"cultivation": 0, "daoHeart": 10, "health": 5},
		"resources": {"spiritStone": 0}, "maxHealth": 6, "maxDaoHeart": 10}
	if not milestone._apply_effect(spell, "spiritStone", 11, "f_meditation") \
			or int(spell.resources.spiritStone) != 13:
		return _fail("milestone effect did not consume spell stone bonus")
	spell["realm"] = "golden"
	if not milestone._apply_effect(spell, "cultivation", 3, "f_meditation") \
			or int(spell.attributes.cultivation) != 6:
		return _fail("milestone effect did not consume spell meditation bonus")
	if PathSkill.new(content).effect_delta(spell, "cultivation", 3,
			"g_daoConference") != 6:
		return _fail("cultivation-tagged source card missed meditation multiplier")
	var sword := spell.duplicate(true)
	sword["path"] = "sword"
	sword["attributes"]["daoHeart"] = 10
	if not milestone._apply_effect(sword, "daoHeart", -5, "f_trial") \
			or int(sword.attributes.daoHeart) != 7:
		return _fail("milestone effect did not consume sword dao-heart resistance")
	var body := spell.duplicate(true)
	body["path"] = "body"
	body["attributes"]["health"] = 6
	if not milestone._apply_effect(body, "health", 2, "f_heal") \
			or int(body.attributes.health) != 8:
		return _fail("health effect did not use body max-health skill")
	var gateway = Gateway.new(Registry.new(), content)
	if int(gateway.player_snapshot(body).get("maxHealth", 0)) != 8 \
			or int(gateway.player_snapshot(sword).get(
				"pathSkillPassives", {}).get("critRate", 0)) != 1:
		return _fail("battle loadout did not project body and sword skills")
	var old_sword: Dictionary = sword.duplicate(true)
	old_sword["phase"] = "BATTLE_PENDING"
	old_sword["pathSkillActivationIndex"] = 6
	if gateway.player_snapshot(old_sword).has("pathSkillPassives"):
		return _fail("legacy pending battle changed its frozen loadout")
	var battle = Combat.new(Registry.new())
	battle.state = {"player": {"hp": 1, "maxHp": 4,
		"lowHpAtkBonus": 1, "critRate": 10, "atkMod": 0},
		"enemy": {"hp": 10, "block": 0, "defPower": 0},
		"playerStatus": {}, "enemyStatus": {}}
	if not battle.set_replay_random_values([0.0]) \
			or int(battle._damage_enemy({"type": "attack"}, {"value": 4}).hpLoss) != 6 \
			or battle.replay_random_remaining() != 0:
		return _fail("path skill low-health and critical damage did not reach combat")
	var defense_battle = Combat.new(Registry.new())
	if not defense_battle.load_m0_opening():
		return _fail("defense battle fixture unavailable")
	defense_battle.state["phase"] = "REACTION_OPEN"
	defense_battle.state["enemyIntent"] = {"type": "attack", "value": 3}
	defense_battle.state["player"]["hp"] = 4
	defense_battle.state["player"]["block"] = 0
	defense_battle.state["player"]["defMod"] = 2
	defense_battle.state["player"]["daoHeart"] = 0
	if not defense_battle.take_hit() or int(defense_battle.state.player.hp) != 3:
		return _fail("path skill permanent defense did not reduce incoming damage")
	var regen: Dictionary = body.duplicate(true)
	regen["realm"] = "golden"
	regen["attributes"]["health"] = 7
	regen["resources"]["companions"] = []
	regen["modifiers"] = {}
	regen["equipment"] = {}
	regen["treasureInstances"] = {}
	if not NormalChoice.new(content)._apply_passive_regen(regen) \
			or int(regen.attributes.health) != 8:
		return _fail("body regeneration ignored path-skill health cap")
	var old_regen: Dictionary = regen.duplicate(true)
	old_regen.erase("pathSkillActivationIndex")
	old_regen.attributes.health = 5
	if not NormalChoice.new(content)._apply_passive_regen(old_regen) \
			or int(old_regen.attributes.health) != 5:
		return _fail("legacy run received body regeneration before activation")
	var regulated = RegulatedVendor.new(content)
	var lesson_vendor = LastLessonVendor.new(content, null)
	if regulated._actual_health_cap(regen) != 8 \
			or lesson_vendor._actual_health_cap(regen) != 8 \
			or regulated._actual_health_cap(old_regen) != 6 \
			or lesson_vendor._actual_health_cap(old_regen) != 6:
		return _fail("vendor healing ignored body skill activation or health cap")
	var cave := {"path": "spell", "realm": "nascent",
		"pathSkillActivationIndex": 5,
		"runClock": {"decisionIndex": 4, "lifeId": "slot_1:life:0"},
		"attributes": {"cultivation": 10}, "resources": {"spiritStone": 2},
		"dungeonRun": {"status": "active", "realm": "nascent",
			"dungeonId": "nascent_cave", "sessionId": "dungeon:slot_1:life:0:4:nascent_cave",
			"sourceCardId": "n_cave", "sourceDecisionIndex": 4},
		"dungeonPath": ["nc_trap", "nc_treasure"], "dungeonOutcomeReceipts": []}
	var dungeon = NascentCave.new(content)
	if not dungeon.complete(cave, "success", 5) \
			or int(cave.attributes.cultivation) != 15 \
			or int(cave.resources.spiritStone) != 7 \
			or dungeon.complete(cave, "success", 5):
		return _fail("dungeon completion bonus or duplicate guard differs")
	print("NONCOMBAT_PATH_SKILL_CONSUMERS_PASS effect=true health_cap=true regen=true vendor_cap=true dungeon=true battle=true")
	quit(0)


func _fail(message: String) -> void:
	printerr("NONCOMBAT_PATH_SKILL_CONSUMERS_FAIL " + message)
	quit(1)
