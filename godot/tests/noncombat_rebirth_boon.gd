extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const RebirthFlow = preload("res://scripts/noncombat_rebirth_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source = Domain.new(Registry.new(), null, "slot_3")
	if not source.start("pill"):
		return _fail("source life could not start")
	var terminal: Dictionary = source.state.duplicate(true)
	terminal["phase"] = "DEATH_PENDING"
	terminal["lifePhase"] = "DYING_NARRATIVE"
	terminal["dead"] = true
	terminal["deathCauseId"] = "death_dao_collapse"
	terminal["currentCardId"] = "death_dao_collapse"
	terminal["lifeCount"] = 0
	terminal["lifeJournal"] = []
	terminal["turn"] = 54
	var death_card: Dictionary = ContentRepository.new().find(
		"card", "death_dao_collapse").get("data", {})
	var flow = RebirthFlow.new()
	var newborn: Dictionary = flow.new_life(
		terminal, death_card, "left", "slot_3")
	var sword: Dictionary = flow.select_path(newborn, "sword")
	var body: Dictionary = flow.select_path(newborn, "body")
	if sword.is_empty() or body.is_empty():
		return _fail("source path selection unavailable")
	if not flow.has_method("settle_boon"):
		return _fail("rebirth boon settlement missing")
	var funded_sword: Dictionary = sword.duplicate(true)
	funded_sword["attributes"]["karmaGood"] = 15
	funded_sword["resources"]["spiritStone"] = 30
	var left: Dictionary = flow.settle_boon(funded_sword, "left")
	if left.is_empty() or left.get("attributes", {}).get("karmaGood") != 5 \
			or left.get("deck", []).count("sword_intent") != 1 \
			or left.get("skillAcquisitions", {}).get(
				"sword_intent", {}).get("sourceId") != "rebirth_boon" \
			or left.get("runClock", {}).get("decisionIndex") != 1:
		return _fail("sword boon was not paid and granted exactly once: "
			+ JSON.stringify(left) + " error=" + String(flow.last_error))
	var funded_body: Dictionary = body.duplicate(true)
	funded_body["attributes"]["karmaGood"] = 15
	if not flow.settle_boon(funded_body, "left").is_empty() \
			or funded_body["attributes"]["karmaGood"] != 15:
		return _fail("off-path sword boon consumed karma without reward")
	var right: Dictionary = flow.settle_boon(funded_sword, "right")
	if right.is_empty() or right.get("resources", {}).get("spiritStone") != 10 \
			or not right.get("resources", {}).get("treasures", []).has("避尘珠") \
			or right.get("treasureInstances", {}).size() != 1 \
			or right.get("treasureInstances", {}).values()[0].get(
				"provenance", {}).get("source") != "narrative_effect" \
			or right.get("treasureInstances", {}).values()[0].get(
				"transactionId", "").find(":source:rebirth_boon:item:避尘珠") < 0 \
			or right.get("runClock", {}).get("decisionIndex") != 1:
		return _fail("treasure boon cost or instance missing")
	var down: Dictionary = flow.settle_boon(funded_sword, "down")
	if down.is_empty() or down.get("attributes", {}).get("health") != \
			down.get("maxHealth") or down.get("phase") != "CAMP_TARGET_PENDING" \
			or down.get("pendingCampAction") != "remove" \
			or down.get("deck") != funded_sword.get("deck") \
			or down.get("runClock", {}).get("decisionIndex") != 1:
		return _fail("healing/removal boon did not open one target decision")
	if not flow.settle_boon(sword, "left").is_empty() \
			or not flow.settle_boon(sword, "right").is_empty():
		return _fail("unaffordable boon committed")
	var live = Domain.new(Registry.new(), null, "slot_3")
	live.state = funded_sword.duplicate(true)
	live._install_rebirth_path_bundle(live._rebirth_path_bundle("sword"))
	live._current_card_id = "rebirth_boon"
	live._choice_token = 1
	live._market_flow.ghost_plan_activation_index = 1
	var live_token: int = live.issue_choice_token()
	var live_ok: bool = live.choose("left", live_token)
	if live_token <= 0 or not live_ok \
			or live.state.get("phase") != "FLOW_PENDING" \
			or not live.state.get("resources", {}).get("treasures") is Array:
		return _fail("public boon choice did not use the durable transition: " \
			+ JSON.stringify({"token": live_token, "ok": live_ok,
				"phase": live.state.get("phase"),
				"flow": live.state.get("noncombatFlow"),
				"tradeError": live._trade_route_flow.last_error,
				"legacyError": live._legacy_fragment_flow.last_error,
				"marketError": live._market_flow.last_error}))
	if not live.resume_flow() or live.get_current_card().is_empty():
		return _fail("new life ordinary card did not follow the boon: " \
			+ JSON.stringify({"flow": live.state.get("noncombatFlow"),
				"phase": live.state.get("phase"),
				"normalError": live._normal_flow_error,
				"marketError": live._market_flow.last_error,
				"questError": live._quest_flow.last_error}))
	var due: Dictionary = funded_sword.duplicate(true)
	due["phase"] = "FLOW_PENDING"
	due["currentCardId"] = ""
	due["attributes"]["cultivation"] = 15
	due["noncombatFlow"] = live.state["noncombatFlow"].duplicate(true)
	var milestone: Dictionary = live._milestone_flow.resume(due)
	if milestone.get("phase") != "MILESTONE_PENDING" \
			or milestone.get("currentCardId") != "ch_qi_20":
		return _fail("new-life cultivation 15 did not present source chapter card")
	var milestone_choice: Dictionary = live._milestone_flow.settle(milestone, "left")
	var fact: Dictionary = milestone_choice.get("noncombatFlow", {}).get(
		"spineFacts", {}).get("fact:1:qi_main_call", {})
	if milestone_choice.is_empty() or fact.get("lifeCount") != 1 \
			or milestone_choice.get("karmaSeeds", []).back().get("originLife") != 1:
		return _fail("new-life chapter choice lost second-life fact or seed identity")
	print("NONCOMBAT_REBIRTH_BOON_PASS sword=true treasure=true remove=true cost=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
