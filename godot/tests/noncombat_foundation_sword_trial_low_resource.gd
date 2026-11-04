extends "res://tests/noncombat_foundation_sword_trial_outcomes.gd"

const DeathFlow = preload("res://scripts/noncombat_death_flow.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")


func _run() -> void:
	var path := "user://tests/foundation_sword_low_resource_%d.json" % Time.get_ticks_usec()
	var store = Session.new(path, "slot_2")
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURE))
	file.close()
	var game = Domain.new(Registry.new(), store, "slot_2")
	_quiet(game)
	if not game.restore():
		return _fail("natural trial low-resource prefix failed to restore")
	for step in 4:
		if not _trial(game, "defeat") or game.get_current_card().get("id") != "q_sword_3":
			return _fail("source defeat retry stopped at step %d" % step)
	if int(game.state.attributes.health) != 1 or int(game.state.attributes.daoHeart) != 1:
		return _fail("authored retry did not reach health=1, daoHeart=1: " + JSON.stringify({
			"health": game.state.attributes.health, "daoHeart": game.state.attributes.daoHeart}))
	var checkpoint := FileAccess.get_file_as_bytes(store.v2_path)
	var max_health := int(game.state.maxHealth)
	var max_heart := int(game.state.maxDaoHeart)
	if not game.choose("left", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.submit_battle_result(_result(game.battle_request(), "victory")):
		return _fail("low-health victory failed source settlement")
	if int(game.state.attributes.health) != 1 \
			or int(game.state.maxHealth) != max_health - 1 \
			or int(game.state.maxDaoHeart) != max_heart - 1:
		return _fail("low-health victory missed browser burn-blood rule")
	var victory = Domain.new(Registry.new(), Session.new(path, "slot_2"), "slot_2")
	_quiet(victory)
	if not victory.restore() or not _same(victory.state, game.state):
		return _fail("burn-blood victory failed strict cold restore")
	var death_path := "user://tests/foundation_sword_fatal_heart_%d.json" % Time.get_ticks_usec()
	var death_store = Session.new(death_path, "slot_2")
	var death_file := FileAccess.open(death_store.v2_path, FileAccess.WRITE)
	death_file.store_buffer(checkpoint)
	death_file.close()
	var fatal = Domain.new(Registry.new(), death_store, "slot_2")
	_quiet(fatal)
	if not fatal.restore() or not fatal.choose("left", fatal.issue_choice_token()) \
			or not fatal.choose("left", fatal.issue_choice_token()) \
			or not fatal.submit_battle_result(_result(fatal.battle_request(), "defeat")):
		return _fail("source daoHeart=1 defeat was rejected")
	if fatal.state.get("phase") != "DEATH_PENDING" \
			or fatal.get_current_card().get("id") != "death_dao_collapse":
		return _fail("fatal trial did not enter source death narrative")
	var fatal_reopen = Domain.new(Registry.new(), Session.new(death_path, "slot_2"), "slot_2")
	_quiet(fatal_reopen)
	if not fatal_reopen.restore() or not _same(fatal_reopen.state, fatal.state):
		return _fail("fatal trial failed strict cold restore")
	var equipped: Dictionary = fatal.state.duplicate(true)
	equipped.phase = "BATTLE_PENDING"
	equipped.dead = false
	equipped["equipment"] = {"weapon": null, "armor": null,
		"accessory": null, "artifact": null}
	equipped["treasureInstances"] = {}
	equipped.equipment.artifact = "tr:青云剑匣:1"
	equipped.treasureInstances[equipped.equipment.artifact] = {
		"instanceId": equipped.equipment.artifact,
		"definitionId": "青云剑匣", "lifecycle": "owned"}
	var death = DeathFlow.new(Repository.new())
	var with_sword_case: Dictionary = death.prepare_death(equipped, "q_sword_3")
	if with_sword_case.get("deathCauseId") != "death_dao_collapse":
		return _fail("non-reviving equipped artifact blocked source death")
	equipped.equipment.artifact = "tr:替身符:1"
	equipped.treasureInstances[equipped.equipment.artifact] = {
		"instanceId": equipped.equipment.artifact,
		"definitionId": "替身符", "lifecycle": "owned"}
	if not death.prepare_death(equipped, "q_sword_3").is_empty():
		return _fail("reviving artifact was treated as ordinary death")
	equipped.equipment.artifact = null
	equipped.attributes.daoHeart = 1
	equipped.resources.lifespan = 0
	if death.prepare_death(equipped, "q_sword_3").get(
			"deathCauseId") != "death_lifespan":
		return _fail("terminal sword trial retreat did not project lifespan death")
	print("NONCOMBAT_FOUNDATION_SWORD_TRIAL_LOW_RESOURCE_PASS burn=true fatal=true nonrevive=true lifespan=true replay=true")
	quit(0)


func _trial(game: RefCounted, outcome: String) -> bool:
	return game.choose("left", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.submit_battle_result(_result(game.battle_request(), outcome)) \
		and game.choose("down", game.issue_choice_token()) \
		and _continue_to_sword_quest(game)
