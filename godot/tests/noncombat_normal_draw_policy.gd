extends SceneTree

const NormalDrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const FIXTURE := "res://tests/fixtures/normal_draw_decision27.json"

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:
		return _fail("normal draw browser fixture missing")
	var policy = NormalDrawPolicy.new()
	var state: Dictionary = fixture["state"]
	var actual: Dictionary = policy.buckets(state)
	var expected: Dictionary = fixture["expectedBuckets"]
	if not policy.last_error.is_empty() or actual.is_empty():
		return _fail("source card catalog could not be read: " + policy.last_error)
	for name in ["current", "previous", "evergreen"]:
		var rows: Array = actual.get(name, [])
		var source_rows: Array = expected.get(name, [])
		if rows.size() != source_rows.size():
			return _fail("normal draw %s count differs: %d vs %d" % [
				name, rows.size(), source_rows.size()])
		for i in rows.size():
			if rows[i].get("id") != source_rows[i].get("id") \
					or not is_equal_approx(float(rows[i].get("baseWeight", -1)),
						float(source_rows[i].get("baseWeight", -2))):
				return _fail("normal draw %s candidate %d differs: %s vs %s" % [
					name, i, rows[i], source_rows[i]])
	if actual["current"].size() != 26 \
			or actual["current"][0].get("id") != "q_gathering" \
			or actual["current"][1].get("baseWeight") != 14.0 \
			or fixture["expectedPhase"].get("phase") != "BUILDUP" \
			or policy.mood(state) != "cautious" \
			or policy.pick(state, 0.0, 0.0) != "q_gathering":
		return _fail("fixed browser ordinary-draw checkpoint changed")
	var passive_mood: Dictionary = state.duplicate(true)
	passive_mood["maxHealth"] = 5
	passive_mood["attributes"]["health"] = 5
	passive_mood["attributes"]["daoHeart"] = passive_mood["maxDaoHeart"]
	passive_mood["attributes"]["fortune"] = 100
	if policy.mood(passive_mood) != "inspired":
		return _fail("ordinary mood baseline should be inspired")
	passive_mood["legacyArchive"] = {"completedSetIds": ["immortal_will"]}
	passive_mood["legacyRunState"] = {"activeSetIds": ["immortal_will"]}
	if policy.mood(passive_mood) != "neutral":
		return _fail("ordinary mood ignored active immortal-will max health")
	var source_cursor: Dictionary = fixture["expectedPhase"]
	var replay_cursor: Dictionary = policy.phase_cursor_after(int(source_cursor["cardCount"]))
	if replay_cursor.get("phase") != source_cursor.get("phase") \
			or replay_cursor.get("phaseProgress") != source_cursor.get("phaseProgress") \
			or policy.phase_cursor_after(13).get("phase") != "BUILDUP" \
			or policy.phase_cursor_after(19).get("phaseProgress") != 36 \
			or policy.phase_cursor_after(85).get("phase") != "CALM" \
			or policy.phase_cursor_after(85).get("phaseProgress") != 0 \
			or policy.source_at_zero_roll("BUILDUP") != "normal":
		return _fail("source flow phase cursor or zero-roll source lottery diverged")
	var blocked: Dictionary = state.duplicate(true)
	blocked["cardsPlayed"].append("q_gathering")
	if policy.buckets(blocked)["current"].any(func(row): return row.get("id") == "q_gathering") \
			or policy.pick(blocked, 0.0, 0.0) != "q_meditation":
		return _fail("last-eight card cooldown did not exclude q_gathering")
	var higher_realm: Dictionary = state.duplicate(true)
	higher_realm["realm"] = "golden"
	var golden_buckets: Dictionary = policy.buckets(higher_realm)
	if not policy.last_error.is_empty() or golden_buckets.is_empty() \
			or not golden_buckets.get("current", []).any(
				func(row: Dictionary) -> bool: return row.get("id") == "g_shop"):
		return _fail("audited golden realm ordinary pool was not admitted")
	var choices = NormalChoicePolicy.new()
	var gathering: Dictionary = choices.source_card("q_gathering")
	if gathering.is_empty() or not choices.choice_available(state, gathering, "left") \
			or choices.choice_available(state, gathering, "right"):
		return _fail("browser gathering choice admission or source lookup differs")
	var settled: Dictionary = choices.settle(state, "q_gathering", "left")
	var expected_after: Dictionary = fixture["expectedGatheringAfter"]
	if settled.is_empty() or settled.get("maxHealth") != expected_after.get("maxHealth") \
			or settled.get("maxDaoHeart") != expected_after.get("maxDaoHeart"):
		return _fail("source gathering burn-blood max stats differ")
	for key in expected_after["attributes"]:
		if not is_equal_approx(float(settled["attributes"].get(key, -999)),
				float(expected_after["attributes"][key])):
			return _fail("source gathering attribute differs: " + String(key))
	for key in ["spiritStone", "lifespan"]:
		if not is_equal_approx(float(settled["resources"].get(key, -999)),
				float(expected_after["resources"][key])):
			return _fail("source gathering resource differs: " + key)
	for key in ["pills", "treasures", "companions"]:
		if settled["resources"].get(key) != expected_after["resources"].get(key):
			return _fail("source gathering inventory differs: " + key)
	var meditation: Dictionary = choices.source_card("q_meditation")
	if meditation.is_empty() or choices.choice_available(settled, meditation, "left") \
			or not choices.choice_available(settled, meditation, "right"):
		return _fail("meditation follow-up capped-choice admission differs")
	var death_edge: Dictionary = state.duplicate(true)
	death_edge["maxHealth"] = 1
	death_edge["maxDaoHeart"] = 1
	var unchanged: Dictionary = death_edge.duplicate(true)
	var fatal_gathering: Dictionary = choices.settle(death_edge,
		"q_gathering", "left")
	if fatal_gathering.is_empty() or int(fatal_gathering.get(
			"attributes", {}).get("health", 1)) > 0 or death_edge != unchanged:
		return _fail("fatal gathering preview lost source effect or changed input state")
	var love: Dictionary = choices.settle(state, "q_love", "right")
	if love.is_empty() or love.get("resources", {}).get("companions") != ["mortal"] \
			or int(love["attributes"]["daoHeart"]) != \
			int(state["attributes"]["daoHeart"]) - 2 \
			or int(love["resources"]["lifespan"]) != \
			int(state["resources"]["lifespan"]) - 1:
		return _fail("source love reward or negative costs differ")
	var already_owned: Dictionary = state.duplicate(true)
	already_owned["resources"]["companions"] = ["mortal"]
	var love_again: Dictionary = choices.settle(already_owned, "q_love", "right")
	if love_again.get("resources", {}).get("companions") != ["mortal"]:
		return _fail("source love reward duplicated an owned companion")
	var love_left_state: Dictionary = state.duplicate(true)
	love_left_state["attributes"]["daoHeart"] = 1
	love_left_state["attributes"]["cultivation"] = 50
	var love_left: Dictionary = choices.settle(love_left_state, "q_love", "left")
	if love_left.is_empty() or int(love_left["attributes"]["daoHeart"]) != \
			mini(int(love_left_state["maxDaoHeart"]), 11) \
			or int(love_left["attributes"]["cultivation"]) != 58 \
			or love_left["resources"]["companions"] != []:
		return _fail("source love left choice differed from authored numeric effects")
	if choices.settle(love, "q_spiritStone", "left").is_empty():
		return _fail("unregistered mortal blocked later numeric choice")
	var fatal_love: Dictionary = state.duplicate(true)
	fatal_love["attributes"]["daoHeart"] = 2
	if not choices.choice_available(fatal_love, choices.source_card("q_love"), "right") \
			or not choices.choice_available(fatal_love,
				choices.source_card("q_love"), "left"):
		return _fail("source love death choice was not offered")
	var fatal_settled: Dictionary = choices.settle(fatal_love, "q_love", "right")
	if fatal_settled.is_empty() or fatal_settled.get("attributes", {}).get("daoHeart") != 0:
		return _fail("source love death did not reach the domain consumer")
	var terminal_lifespan: Dictionary = state.duplicate(true)
	terminal_lifespan["resources"]["lifespan"] = 1
	if not choices.choice_available(terminal_lifespan,
			choices.source_card("q_love"), "right"):
		return _fail("source love lifespan death was hidden")
	var body_karma: Dictionary = choices.source_card("karma_body_awakening")
	if body_karma.get("sceneImage") != \
			"assets/cards/events/scene_qi_q_bodyTrial.png" \
			or not choices.choice_available(state, body_karma, "left") \
			or not choices.choice_available(state, body_karma, "right"):
		return _fail("source body karma option or original art was unavailable")
	var injured_body: Dictionary = state.duplicate(true)
	injured_body["attributes"]["health"] = 1
	var body_left: Dictionary = choices.settle(injured_body,
		"karma_body_awakening", "left")
	if body_left.is_empty() or int(body_left.get("maxHealth", 0)) != \
			int(injured_body["maxHealth"]) + 2 \
			or int(body_left.get("attributes", {}).get("health", 0)) != 5:
		return _fail("source body karma max health or stacked healing differed")
	var pill_body: Dictionary = state.duplicate(true)
	pill_body["path"] = "pill"
	pill_body["attributes"]["cultivation"] = 50
	var declined_card: Dictionary = choices.settle(pill_body,
		"karma_body_awakening", "right")
	if declined_card.is_empty() or int(declined_card.get("attributes", {}).get(
			"cultivation", -1)) != 65 \
			or declined_card.get("deck", []) != pill_body.get("deck", []):
		return _fail("off-path body card wrongly blocked numeric settlement or granted a card")
	var body_start: Dictionary = state.duplicate(true)
	body_start["path"] = "body"
	body_start["deck"] = []
	body_start["deckOperations"] = []
	body_start["skillAcquisitions"] = {}
	var body_ready: Dictionary = DeckAcquisition.new(
		ContentRepository.new()).ensure_starter(body_start)
	if body_ready.is_empty():
		return _fail("body starter deck fixture could not be prepared")
	body_ready["attributes"]["cultivation"] = 50
	var awarded: Dictionary = choices.settle(body_ready,
		"karma_body_awakening", "right")
	if awarded.is_empty() or awarded.get("deck", []).size() != \
			body_ready["deck"].size() + 1 or not awarded["deck"].has("iron_skin") \
			or awarded.get("skillAcquisitions", {}).get("iron_skin", {}).get(
				"sourceId") != "karma_body_awakening" \
			or int(awarded["attributes"]["cultivation"]) != 65:
		return _fail("body-path karma card was not acquired through deck authority")
	var owned_again: Dictionary = choices.settle(awarded,
		"karma_body_awakening", "right")
	if owned_again.is_empty() or owned_again.get("deck", []).size() != \
			awarded["deck"].size():
		return _fail("repeated body karma reward duplicated its card")
	var defined_companion: Dictionary = state.duplicate(true)
	defined_companion["resources"]["companions"] = ["unported_defined_companion"]
	if not choices.settle(defined_companion, "q_spiritStone", "left").is_empty() \
			or choices.last_error != "companion passive consumer required":
		return _fail("unmigrated defined companion passive was silently accepted")
	var fellow: Dictionary = choices.source_card("q_fellow", state)
	if fellow.get("type") != "COMBAT" \
			or choices.choice_available(state, fellow, "left") \
			or not choices.choice_available(state, fellow, "right"):
		return _fail("capped combat fallback hid the executable fellow challenge")
	var uncapped_fellow: Dictionary = state.duplicate(true)
	uncapped_fellow["attributes"]["cultivation"] = 50
	uncapped_fellow["attributes"]["daoHeart"] = 2
	var sparring: Dictionary = choices.settle(uncapped_fellow, "q_fellow", "left")
	if sparring.get("resources", {}).get("lifespan") != 75:
		return _fail("non-fatal combat-tag ordinary choice missed lifespan cost")
	var regen_modifier: Dictionary = state.duplicate(true)
	regen_modifier["modifiers"] = {"hpRegen": 1}
	var healed_by_modifier: Dictionary = choices.settle(regen_modifier, "q_gathering", "left")
	if healed_by_modifier.get("attributes", {}).get("health") != 1 \
			or healed_by_modifier.get("maxHealth") != 5 \
			or healed_by_modifier.get("maxDaoHeart") != 4:
		return _fail("passive modifier healing must run before death and burn-blood")
	var regen_treasure: Dictionary = state.duplicate(true)
	regen_treasure["treasureInstances"] = {"tr:灵泉葫芦:1": {
		"instanceId": "tr:灵泉葫芦:1", "definitionId": "灵泉葫芦", "lifecycle": "owned"}}
	regen_treasure["equipment"] = {"weapon": null, "armor": null,
		"accessory": "tr:灵泉葫芦:1", "artifact": null}
	var healed_by_treasure: Dictionary = choices.settle(regen_treasure, "q_gathering", "left")
	if healed_by_treasure.get("attributes", {}).get("health") != 1 \
			or healed_by_treasure.get("maxHealth") != 5 \
			or healed_by_treasure.get("maxDaoHeart") != 4:
		return _fail("equipped treasure passive healing must run before death")
	var atmosphere: Dictionary = choices.source_card("atm_qi_tea_rumor", state)
	var uncapped_atmosphere: Dictionary = state.duplicate(true)
	uncapped_atmosphere["attributes"]["daoHeart"] = 1
	uncapped_atmosphere["attributes"]["fortune"] = 50
	if atmosphere.get("id") != "atm_qi_tea_rumor" \
			or not choices.choice_available(uncapped_atmosphere, atmosphere, "left") \
			or choices.settle(uncapped_atmosphere, "atm_qi_tea_rumor", "left").is_empty():
		return _fail("extra authored atmosphere card was omitted from ordinary settlement: card=%s error=%s" % [
			atmosphere.get("id"), choices.last_error])
	print("NONCOMBAT_NORMAL_DRAW_POLICY_PASS candidates=26 weights=true cooldown=true phase=true pick=true burn=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
