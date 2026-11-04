extends SceneTree

const Content = preload("res://scripts/noncombat_content_repository.gd")
const Acquisition = preload("res://scripts/noncombat_deck_acquisition.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = Content.new()
	var acquisition = Acquisition.new(content)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/battle_victory_source.json"))
	var source := "src/systems/SkillCardAcquisitionSystem.js"
	var source_path := ProjectSettings.globalize_path("res://").path_join("../" + source)
	if oracle.get("pins", {}).get(source) != FileAccess.get_sha256(source_path):
		return _fail("browser acquisition oracle source drift")
	if not acquisition.has_method("battle_reward_offers") \
			or not acquisition.has_method("acquire_battle_reward"):
		return _fail("battle reward producer/acquisition interfaces missing")
	var acquired_count := 0
	for row in oracle["rows"]:
		var state: Dictionary = row["victory"].duplicate(true)
		state["path"] = row["path"]
		state["realm"] = "qi"
		state["starterDeckPath"] = row["path"]
		state["battleLoadout"] = {"deck": state["deck"].duplicate(true), "marker": "preserve"}
		var before := state.duplicate(true)
		var offers: Array = acquisition.battle_reward_offers(state)
		if offers.size() != 3 or state != before \
				or acquisition.battle_reward_offers(state) != offers:
			return _fail("three deterministic offers without state mutation: " + row["path"])
		for index in 3:
			var direction: String = ["left", "right", "up"][index]
			var choice: Dictionary = row["rewardCard"]["choices"][direction]
			var authored: Dictionary = choice["effects"]["deckCard"]
			var offer: Dictionary = offers[index]
			if offer.get("cardId") != authored["cardId"] \
					or offer.get("path") != authored["path"] \
					or offer.get("realm") != "qi" \
					or offer.get("sourceType") != authored["sourceType"] \
					or "参悟【%s】" % offer.get("cardName", "") != choice["text"] \
					or String(offer.get("description", "")) + "\n\n【来源】战斗缴获" != choice["desc"]:
				return _fail("offer differs from browser: " + row["path"] + "." + direction)
		if row["direction"] == "down":
			if state["deck"] != row["chosen"]["deck"] \
					or state["skillAcquisitions"] != row["chosen"]["skillAcquisitions"]:
				return _fail("skip should leave acquisition to the choice consumer")
			continue
		var payload: Dictionary = row["rewardCard"]["choices"][row["direction"]]["effects"]["deckCard"]
		var candidate: Dictionary = acquisition.acquire_battle_reward(
			state, payload["cardId"], payload["sourceId"])
		if candidate.is_empty() or state != before:
			return _fail("reward candidate was rejected or mutated source: " + row["path"])
		for key in ["deck", "skillAcquisitions", "deckOperations"]:
			# JSON fixtures parse every number as float; compare at the same save
			# boundary so an integer turn 4 matches the source JSON number 4.
			if JSON.parse_string(JSON.stringify(candidate.get(key))) != row["chosen"][key]:
				print("actual=", JSON.stringify(candidate.get(key)), " expected=", JSON.stringify(row["chosen"][key]))
				return _fail("acquisition differs from browser: " + row["path"] + "." + key)
		for key in ["attributes", "resources", "knowledge", "modifiers", "turn"]:
			if candidate.get(key) != before.get(key):
				return _fail("acquisition executed combat effects or advanced clock: " + key)
		if candidate["battleLoadout"] != {"deck": candidate["deck"], "marker": "preserve"}:
			return _fail("battle loadout did not preserve metadata and sync deck")
		var acquired_before := candidate.duplicate(true)
		if not acquisition.acquire_battle_reward(candidate, payload["cardId"], payload["sourceId"]).is_empty() \
				or candidate != acquired_before:
			return _fail("duplicate acquisition accepted or mutated state")
		acquired_count += 1
	if acquired_count != 12 or not _check_owned_and_edited_deck(acquisition, content):
		return _fail("owned/upgraded/cumulative reward boundary")
	print("NONCOMBAT_BATTLE_DECK_REWARDS_PASS source_rows=16 acquired=12 owned=true upgraded=true edited_deck=true cumulative=true")
	quit(0)


func _check_owned_and_edited_deck(acquisition: RefCounted, content: RefCounted) -> bool:
	var state: Dictionary = acquisition.ensure_starter({"path": "sword", "realm": "qi", "turn": 17})
	state["deck"].remove_at(0)
	state["deck"].reverse()
	state["deck"][0] += "+"
	state["deck"].append("sword_intent++")
	state["skillAcquisitions"]["draw_sword++"] = {"mode": "old_record"}
	state["battleLoadout"] = {"deck": state["deck"].duplicate(true)}
	var before := state.duplicate(true)
	var offers: Array = acquisition.battle_reward_offers(state)
	if _ids(offers) != ["sword_array", "sword_qi_riposte"] or state != before:
		return false
	for invalid_id in ["sword_intent", "draw_sword", "spell_gather",
			"sword_foundation_cloudstep", "sword_shop_qi_sheath"]:
		if not acquisition.acquire_battle_reward(state, invalid_id, "edited_deck_battle").is_empty() \
				or state != before:
			return false
	if not acquisition.acquire_battle_reward(state, "sword_array", "").is_empty() \
			or state != before:
		return false
	var candidate: Dictionary = acquisition.acquire_battle_reward(state, "sword_array", "edited_deck_battle")
	if candidate.is_empty() or candidate["deck"] != before["deck"] + ["sword_array"] \
			or candidate["battleLoadout"]["deck"] != candidate["deck"] \
			or candidate["skillAcquisitions"]["draw_sword++"] != before["skillAcquisitions"]["draw_sword++"] \
			or candidate["skillAcquisitions"]["sword_array"]["turn"] != 17 \
			or candidate["deckOperations"][-1]["mode"] != "path_reward" or state != before:
		return false
	state["realm"] = "foundation"
	if _ids(acquisition.battle_reward_offers(state)) != [
			"sword_array", "sword_qi_riposte", "sword_foundation_cloudstep"]:
		return false
	# acquirePathCard accepts every eligible cumulative-pool card; the reward
	# consumer authenticates which of the three displayed options was selected.
	if acquisition.acquire_battle_reward(state, "sword_foundation_guard", "foundation_battle").is_empty():
		return false
	var rules: Dictionary = content.read_module("combat:deck_progression")
	for card_id in rules["paths"]["sword"]["rewardPool"]:
		state["skillAcquisitions"][card_id] = {}
	return acquisition.battle_reward_offers(state).is_empty()


func _ids(offers: Array) -> Array:
	return offers.map(func(offer: Dictionary) -> String: return offer["cardId"])


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
