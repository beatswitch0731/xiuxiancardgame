extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const FragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")

class MissingLegacyTagContent extends "res://scripts/noncombat_content_repository.gd":
	func read_module(module_id: String) -> Variant:
		var document: Variant = super.read_module(module_id)
		if module_id != "cards:battle_cards" or not document is Dictionary:
			return document
		var altered: Dictionary = document.duplicate(true)
		for row in altered.get("battle_cards", []):
			if row is Dictionary and row.get("id") == "legacy_sword_heart_art":
				row["tags"].erase("legacy")
		return altered


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "user://tests/legacy_fragments_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._legacy_fragment_flow.roll_override = 0.0
	if not game.start("sword"):
		return _fail("start")
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return _fail("tutorial choice %d" % i)
	if not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("first milestone route")
	var pre_completion: Dictionary = game.state.duplicate(true)
	var pre_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose("right", token) or game.state != pre_completion \
			or FileAccess.get_file_as_string(store.v2_path) != pre_bytes:
		return _fail("failed eighth-fragment commit leaked reward")
	if not game.choose("right", token):
		return _fail("eighth fragment retry")
	var archive: Dictionary = game.state.get("legacyArchive", {})
	var fragments: Dictionary = archive.get("fragmentsBySet", {})
	var acquisition: Dictionary = game.state.get("skillAcquisitions", {}).get(
		"legacy_sword_heart_art", {})
	if int(fragments.get("sword_heart", -1)) != 8 \
			or not archive.get("completedSetIds", []).has("sword_heart") \
			or not game.state.get("legacyRunState", {}).get("activeSetIds", []).has("sword_heart") \
			or not game.state.get("deck", []).has("legacy_sword_heart_art") \
			or acquisition.get("sourceType") != "legacy_fragment_set" \
			or acquisition.get("sourceId") != "sword_heart" \
			or int(acquisition.get("turn", -1)) != 8:
		print("legacy diagnostics count=", fragments.get("sword_heart"),
			" archive=", archive.get("completedSetIds"), " deck=", game.state.get("deck"),
			" acquisition=", acquisition, " history=", game.state.get("choiceHistory"))
		return _fail("eight fragments did not award the source art")
	var bytes := FileAccess.get_file_as_string(store.v2_path)
	var restored = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	restored._legacy_fragment_flow.roll_override = 0.0
	if not restored.restore() or restored.state.get("deck") != game.state.get("deck") \
			or FileAccess.get_file_as_string(store.v2_path) != bytes:
		return _fail("strict reload or original bytes")
	if not restored.resume_flow():
		return _fail("next milestone schedule")
	var scheduled: Dictionary = restored.state.duplicate(true)
	var scheduled_bytes := FileAccess.get_file_as_string(store.v2_path)
	restored._store.fail_promotion_once = true
	if restored.choose("right", restored.issue_choice_token()) \
			or restored.state != scheduled \
			or FileAccess.get_file_as_string(store.v2_path) != scheduled_bytes:
		return _fail("failed write leaked fragment progress")
	if not restored.choose("right", restored.issue_choice_token()) \
			or restored.state.get("deck", []).count("legacy_sword_heart_art") != 1:
		return _fail("completed art duplicated on next choice")
	if not _check_old_save_upgrade():
		return _fail("old save fragment migration")
	if not _check_rule_source_drift(store):
		return _fail("changed legacy rules source accepted")
	if not _check_malformed_rng_classification(store):
		return _fail("malformed RNG mislabeled as source drift")
	if not _check_pity():
		return _fail("seven-miss pity or combat exclusion")
	if not _check_path_variants():
		return _fail("other paths did not receive their source variant")
	if not _check_missing_legacy_tag(game):
		return _fail("missing legacy tag was admitted")
	if not _check_completion_effects():
		return _fail("completion activation or passive contract")
	print("NONCOMBAT_LEGACY_FRAGMENTS_PASS drops=8 art=1 variants=4 pity=true rollback=true replay=true")
	quit(0)


func _check_old_save_upgrade() -> bool:
	var path := "user://tests/legacy_fragments_old_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._legacy_fragment_flow.roll_override = 0.0
	if not game.start("sword") or not game.choose("left", game.issue_choice_token()):
		return false
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.v2_path))
	for key in ["legacyFragmentVersion", "legacyRuleSourceSha", "legacyFragmentActivationIndex", "legacyArchive",
			"legacyRunState", "legacyRngState"]:
		envelope["state"].erase(key)
	var old_bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(old_bytes)
	file.close()
	var old = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	old._legacy_fragment_flow.roll_override = 0.0
	if not old.restore() or FileAccess.get_file_as_string(store.v2_path) != old_bytes \
			or old.state.has("legacyArchive"):
		print("old restore detail=", old._store.last_error, " has=", old.state.has("legacyArchive"))
		return false
	var old_state: Dictionary = old.state.duplicate(true)
	old._store.fail_promotion_once = true
	if old.choose("left", old.issue_choice_token()) or old.state != old_state \
			or FileAccess.get_file_as_string(store.v2_path) != old_bytes:
		print("old rollback detail state=", old.state == old_state,
			" bytes=", FileAccess.get_file_as_string(store.v2_path) == old_bytes)
		return false
	if not old.choose("left", old.issue_choice_token()) \
			or int(old.state.get("legacyArchive", {}).get("fragmentsBySet", {}).get(
				"sword_heart", -1)) != 1:
		print("old upgrade detail=", old.state.get("legacyArchive"), " error=",
			old._legacy_fragment_flow.last_error)
		return false
	var upgraded = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	upgraded._legacy_fragment_flow.roll_override = 0.0
	var reloaded := upgraded.restore()
	var equal: bool = JSON.parse_string(JSON.stringify(upgraded.state)) == \
		JSON.parse_string(JSON.stringify(old.state))
	if not reloaded or not equal:
		print("old reloaded detail=", upgraded._store.last_error,
			" equal=", equal)
	return reloaded and equal


func _check_pity() -> bool:
	var path := "user://tests/legacy_fragments_pity_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	game._legacy_fragment_flow.roll_override = 0.99
	if not game.start("sword"):
		return false
	for i in 5:
		if not game.choose("left", game.issue_choice_token()):
			return false
	if int(game.state["legacyRunState"]["ordinaryMissStreak"]) != 5:
		return false
	if not game.choose("right", game.issue_choice_token()) \
			or int(game.state["legacyRunState"]["ordinaryMissStreak"]) != 5:
		return false
	if not game.choose("left", game.issue_choice_token()) \
			or not game.resume_flow() \
			or not game.choose("left", game.issue_choice_token()) \
			or int(game.state["legacyRunState"]["ordinaryMissStreak"]) != 7:
		return false
	if not game.choose("right", game.issue_choice_token()):
		return false
	var counts: Dictionary = game.state["legacyArchive"]["fragmentsBySet"]
	var total := 0
	for count in counts.values():
		total += int(count)
	return total == 1 and int(game.state["legacyRunState"]["ordinaryMissStreak"]) == 0


func _check_rule_source_drift(current_store: RefCounted) -> bool:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(current_store.v2_path))
	envelope["state"]["legacyRuleSourceSha"] = "f".repeat(64)
	var path := "user://tests/legacy_fragments_rule_drift_%d.json" % Time.get_ticks_usec()
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


func _check_malformed_rng_classification(current_store: RefCounted) -> bool:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(current_store.v2_path))
	envelope["state"]["legacyRngState"] = null
	var path := "user://tests/legacy_fragments_bad_rng_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var bytes := JSON.stringify(envelope)
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	return not game.restore() and store.last_error != "SOURCE_MISMATCH" \
		and FileAccess.get_file_as_string(store.v2_path) == bytes


func _check_path_variants() -> bool:
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/data/cards/battle_cards.json"))
	for path_id in ["spell", "body", "pill"]:
		var variant := ""
		for row in cards.get("battle_cards", []):
			if row is Dictionary and row.get("legacySetId") == "sword_heart" \
					and row.get("legacyPath") == path_id:
				variant = String(row.get("id", ""))
		if variant.is_empty():
			return false
		var path := "user://tests/legacy_fragments_%s_%d.json" % [path_id, Time.get_ticks_usec()]
		var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
		game._legacy_fragment_flow.roll_override = 0.0
		if not game.start(path_id):
			return false
		for i in 5:
			if not game.choose("left", game.issue_choice_token()):
				return false
		if not game.choose("right", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.resume_flow() \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.choose("right", game.issue_choice_token()) \
					or not game.state.get("deck", []).has(variant):
			print("path variant detail=", path_id, " card=", game.get_current_card().get("id"),
				" fragments=", game.state.get("legacyArchive", {}).get("fragmentsBySet"))
			return false
	return true


func _check_missing_legacy_tag(game: RefCounted) -> bool:
	var content = MissingLegacyTagContent.new()
	var deck = DeckAcquisition.new(content)
	var flow = FragmentFlow.new(content, deck)
	return flow._variant_card_id("sword_heart", "sword").is_empty() \
		and deck.acquire_legacy(game.state, "legacy_sword_heart_art", "sword_heart",
			"legacy_fragment_set", 8).is_empty()


func _check_completion_effects() -> bool:
	var expected := {
		"sword_heart": ["sword", {"critRate": 5}],
		"pill_way": ["pill", {"pillBonus": 15}],
		"array_way": ["spell", {"combatStartBlock": 3, "daoResist": 10}],
		"heaven_book": ["spell", {"cultivationBonus": 10}],
		"demon_blood": ["body", {"lowHpDamageBonus": 2, "daoHeartPenalty": -2}],
		"immortal_will": ["body", {"maxHp": 6, "maxLifespan": 5}],
	}
	for set_id in expected:
		var path_id: String = expected[set_id][0]
		var game = Domain.new(Registry.new(), null, "slot_3")
		game._legacy_fragment_flow.roll_override = 0.0
		if not game.start(path_id):
			return false
		var prior: Dictionary = game.state.duplicate(true)
		prior["legacyArchive"]["fragmentsBySet"][set_id] = 7
		prior["legacyRunState"]["focusedSetId"] = set_id
		var candidate: Dictionary = prior.duplicate(true)
		candidate["runClock"]["decisionIndex"] = 1
		candidate["turn"] = 1
		candidate["choiceHistory"].append({"cardId": "tutorial_1", "cardType": "NORMAL",
			"direction": "left", "turn": 0, "decisionIndex": 1, "tags": []})
		if not game._legacy_fragment_flow.settle(prior, candidate, false, -1, 0):
			print("completion error=", set_id, " ", game._legacy_fragment_flow.last_error)
			return false
		if not candidate["legacyArchive"]["completedSetIds"].has(set_id) \
				or game._legacy_fragment_flow.passive_bonuses(candidate) != expected[set_id][1]:
			return false
		if set_id == "heaven_book" and int(candidate["attributes"]["fortune"]) != \
				int(prior["attributes"]["fortune"]) + 3:
			return false
		if set_id == "immortal_will" and (
				int(candidate["resources"]["lifespan"]) != int(prior["resources"]["lifespan"]) + 5 \
				or int(candidate["attributes"]["health"]) != \
				mini(int(prior["attributes"]["health"]) + 6,
					int(prior["maxHealth"]) + 6)):
			return false
		if set_id == "demon_blood" and int(candidate["attributes"]["daoHeart"]) != \
				mini(int(prior["attributes"]["daoHeart"]),
					maxi(1, int(prior["maxDaoHeart"]) - 2)):
			return false
		if set_id == "heaven_book" and FragmentFlow.effective_delta(candidate,
				"cultivation", 10) != 11:
			return false
		if set_id == "array_way" and FragmentFlow.effective_delta(candidate,
				"daoHeart", -10) != -9:
			return false
		if set_id == "demon_blood" and FragmentFlow.actual_max_dao_heart(candidate) != \
				maxi(1, int(prior["maxDaoHeart"]) - 2):
			return false
		if set_id == "immortal_will" and FragmentFlow.actual_max_health(candidate) != \
				int(prior["maxHealth"]) + 6:
			return false
	return true


func _fail(message: String) -> void:
	printerr("NONCOMBAT_LEGACY_FRAGMENTS_FAIL: " + message)
	quit(1)
