extends "res://tests/noncombat_cadence_battle.gd"


func _run() -> void:
	var file := "user://tests/npc_first_legacy_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), Session.new(file, "slot_2"), "slot_2")
	_quiet_ambient(game)
	if not game.start("sword"):
		return _fail("NPC legacy opening")
	# Recreate a pre-NPC save through a committed public tutorial decision.
	game.state.erase("npcEncounterScheduling")
	game._npc_activation_index = 100000
	game.state.erase("npcCrossState")
	game._npc_cross_activation_index = 100000
	if not game.choose("right", game.issue_choice_token()) \
			or game.state.has("npcEncounterScheduling") \
			or game.state.has("npcCrossState"):
		return _fail("old tutorial prefix acquired NPC marker")
	var prior: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	game = _cold(game, "old NPC prefix")
	if game == null or game._npc_activation_index != 2 \
			or game._npc_cross_activation_index != 2 \
			or game._npc_cross_dynamic_activation_index != 2 \
			or game.state.has("npcEncounterScheduling") \
			or game.state.has("npcCrossState") \
			or not _same(game.state, prior) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		return _fail("old NPC prefix changed on strict restore")
	var token: int = game.issue_choice_token()
	game._store.fail_promotion_once = true
	if game.choose("right", token) or not _unchanged(game, prior, bytes):
		return _fail("failed old choice activated NPC marker")
	if not game.choose("right", token) \
			or game.state.get("npcEncounterScheduling", {}).get("activationIndex") != 2 \
			or game.state.get("npcCrossState", {}).get("activationIndex") != 2 \
			or game.state.get("npcCrossState", {}).get("dynamicActivationIndex") != 2:
		return _fail("next committed choice did not activate NPC schedule")
	if _cold(game, "activated NPC schedule") == null:
		return _fail("activated NPC schedule failed strict restore")
	var old_cross_file := "user://tests/npc_cross_v1_%d.json" % Time.get_ticks_usec()
	var old_cross = Domain.new(Registry.new(), Session.new(old_cross_file, "slot_2"), "slot_2")
	_quiet_ambient(old_cross)
	if not old_cross.start("sword"):
		return _fail("old NPC cross marker opening")
	for field in ["dynamicActivationIndex", "growthSha", "queuedCards",
			"lastCrossTurn", "lastResolvedTurn", "issuedCards"]:
		old_cross.state.npcCrossState.erase(field)
	old_cross.state.npcCrossState.version = 1
	old_cross._npc_cross_dynamic_activation_index = 100000
	if not old_cross.choose("right", old_cross.issue_choice_token()) \
			or old_cross.state.npcCrossState.has("dynamicActivationIndex"):
		return _fail("old NPC cross marker gained dynamic fields in history")
	var old_cross_state: Dictionary = old_cross.state.duplicate(true)
	old_cross = _cold(old_cross, "old NPC cross marker")
	if old_cross == null or old_cross._npc_cross_dynamic_activation_index != 2 \
			or not _same(old_cross.state, old_cross_state):
		return _fail("old NPC cross marker changed during strict replay")
	if not old_cross.choose("right", old_cross.issue_choice_token()) \
			or old_cross.state.npcCrossState.get("dynamicActivationIndex") != 2 \
			or _cold(old_cross, "upgraded NPC cross marker") == null:
		return _fail("old NPC cross marker did not upgrade at next decision")
	print("NONCOMBAT_NPC_FIRST_LEGACY_PASS deferred_activation=2 cross=true dynamic=true atomic=true replay=true")
	quit(0)
