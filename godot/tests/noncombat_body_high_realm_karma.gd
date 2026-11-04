extends "res://tests/noncombat_market_arrival.gd"

const KarmaFlow = preload("res://scripts/noncombat_karma_flow.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const DeathFlow = preload("res://scripts/noncombat_death_flow.gd")


func _run() -> void:
	var path := "user://tests/body_high_realm_karma_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	if not game.start("body"):
		return _fail("body high realm source state could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.phase = "FLOW_PENDING"
	state.realm = "golden"
	state["noncombatFlow"] = {"scope": "first_session_combat"}
	state["decisionCheckpoint"] = {"sourceCardId": "q_body_4"}
	state.attributes.health = 5
	state.attributes.daoHeart = 1
	state.attributes.cultivation = 10
	state.attributes.fortune = 40
	state.attributes.karmaGood = 0
	state.karmaSeeds = [
		{"id": "bodyTrialStarted", "delay": 0, "realm": "golden",
			"path": "body", "priority": 2},
		{"id": "bodyTrialDeep", "delay": 0, "realm": "nascent",
			"path": "body", "priority": 2}]
	var flow = KarmaFlow.new(ContentRepository.new())
	var regen: Dictionary = state.duplicate(true)
	regen.attributes.health = 1
	regen["equipment"] = {"accessory": "灵泉葫芦"}
	var regen_echo: Dictionary = flow.resume(regen)
	var regen_right: Dictionary = flow.settle(regen_echo, "right")
	if regen_right.is_empty() or int(regen_right.attributes.health) != 2:
		return _fail("golden body echo omitted equipped source passive recovery")
	var overdue: Dictionary = state.duplicate(true)
	overdue.realm = "nascent"
	if flow.resume(overdue).get("currentCardId") != "k_body_echo":
		return _fail("overdue golden seed did not outrank nascent seed")
	var echo: Dictionary = flow.resume(state)
	if echo.get("currentCardId") != "k_body_echo" \
			or echo.get("pendingKarmaCard", {}).get("sceneImage") != \
				"assets/cards/events/scene_karma_k_body_echo.png" \
			or flow.choice_available(echo, "left") != true:
		return _fail("mature golden body seed did not open its source echo")
	var echo_left: Dictionary = flow.settle(echo, "left")
	if echo_left.is_empty() or echo_left.get("cardsPlayed", []).count("k_body_echo") != 1 \
			or echo_left.get("karmaSeeds", []).size() != 1 \
			or int(echo_left.attributes.cultivation) != 25 \
			or int(echo_left.attributes.health) != 8:
		return _fail("golden body echo left choice did not settle once")
	var nascent: Dictionary = echo_left.duplicate(true)
	nascent.realm = "nascent"
	var ascension: Dictionary = flow.resume(nascent)
	if ascension.get("currentCardId") != "k_body_ascension" \
			or ascension.get("pendingKarmaCard", {}).get("sceneImage") != \
				"assets/cards/events/scene_karma_k_body_ascension.png":
		return _fail("mature nascent body seed did not open its source ascension")
	var ascension_right: Dictionary = flow.settle(ascension, "right")
	if ascension_right.is_empty() \
			or ascension_right.get("cardsPlayed", []).count("k_body_ascension") != 1 \
			or not ascension_right.get("karmaSeeds", []).is_empty() \
			or int(ascension_right.attributes.karmaGood) != 30 \
			or int(ascension_right.attributes.health) != 7 \
			or not flow.resume(ascension_right).is_empty():
		return _fail("nascent body ascension right choice or once guard failed")
	var right: Dictionary = flow.settle(echo, "right")
	if right.is_empty() or int(right.attributes.health) != 4 \
			or int(right.attributes.fortune) != 50 \
			or int(right.attributes.cultivation) != 20:
		return _fail("golden body echo right choice lost source effects")
	var left: Dictionary = flow.settle(ascension, "left")
	var path_skills: Dictionary = ContentRepository.new().read_module("config:path_skills")
	var max_hp_bonus := 0
	for skill in path_skills.get("skills", {}).get("body", {}).get("skills", []):
		if skill.get("unlockRealm") == "foundation":
			max_hp_bonus += int(skill.get("passive", {}).get("maxHp", 0))
	if left.is_empty() or int(left.attributes.cultivation) != 40 \
			or max_hp_bonus != 2 \
			or int(left.attributes.health) != mini(int(left.maxHealth) + max_hp_bonus, 11):
		return _fail("nascent body ascension left choice lost source effects: "
			+ JSON.stringify({"attributes": left.get("attributes"),
				"maxHealth": left.get("maxHealth"), "maxHpBonus": max_hp_bonus}))
	var low: Dictionary = state.duplicate(true)
	low.maxHealth = 1
	low.maxDaoHeart = 1
	low.attributes.health = 1
	low.resources.lifespan = 1
	var low_echo: Dictionary = flow.resume(low)
	var low_right: Dictionary = flow.settle(low_echo, "right")
	var death = DeathFlow.new(ContentRepository.new())
	if low_right.is_empty() or int(low_right.attributes.health) != 1 \
			or int(low_right.maxHealth) != 1 \
			or death.prepare_death(low_right,
				"k_body_echo").get("deathCauseId") != "death_lifespan" \
			or not death.prepare_death(low_right, "k_body_ascension").is_empty():
		return _fail("low-cap golden echo did not respect authenticated death cause")
	print("NONCOMBAT_BODY_HIGH_REALM_KARMA_PASS golden=true nascent=true once=true effects=true")
	quit(0)
