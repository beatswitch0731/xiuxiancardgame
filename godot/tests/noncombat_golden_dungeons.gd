extends "res://tests/noncombat_foundation_normal_pool.gd"

const GoldenDungeonFlow = preload("res://scripts/noncombat_golden_dungeon_flow.gd")


func _run() -> void:
	var content = ContentRepository.new()
	var flow = GoldenDungeonFlow.new(content)
	var catalog: Dictionary = flow.catalog()
	if catalog.is_empty() or catalog.dungeons.size() != 5 \
			or catalog.dungeonCards.size() != 16:
		return _fail("golden linear dungeon source graph unavailable")
	var traversed := 0
	for row in [{"path": "spell", "entry": "g_ruins", "direction": "right",
			"dungeon": "ancientRuins", "nodes": ["ruins_ancient",
				"ruins_guardian", "ruins_fork", "ruins_reward"],
			"directions": ["left", "right", "left", "left"]},
			{"path": "sword", "entry": "g_secret_sword", "direction": "left",
				"dungeon": "swordSanctum", "nodes": ["secret_sword_1",
					"secret_sword_2", "secret_sword_3"],
				"directions": ["left", "left", "left"]},
			{"path": "spell", "entry": "g_secret_spell", "direction": "left",
				"dungeon": "spellSanctum", "nodes": ["secret_spell_1",
					"secret_spell_2", "secret_spell_3"],
				"directions": ["left", "left", "left"]},
			{"path": "body", "entry": "g_secret_body", "direction": "left",
				"dungeon": "bodySanctum", "nodes": ["secret_body_1",
					"secret_body_2", "secret_body_3"],
				"directions": ["left", "left", "left"]},
			{"path": "pill", "entry": "g_secret_pill", "direction": "left",
				"dungeon": "pillSanctum", "nodes": ["secret_pill_1",
					"secret_pill_2", "secret_pill_3"],
				"directions": ["left", "left", "left"]}]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start(row.path):
			return _fail("golden dungeon fixture start failed: " + row.entry)
		game.state.realm = "golden"
		game.state.maxHealth = 6
		game.state.attributes.health = 5
		game.state.attributes.cultivation = 10
		game.state.phase = "NORMAL_PENDING"
		game.state.currentCardId = row.entry
		if not game.choose(row.direction, game.issue_choice_token()) \
				or game.state.get("dungeonRun", {}).get("dungeonId") != row.dungeon:
			return _fail("golden dungeon entry failed: " + row.entry)
		for index in row.nodes.size():
			var node: Dictionary = game.get_current_card()
			if node.get("id") != row.nodes[index] \
					or node.get("_dungeonNodeIndex") != index \
					or not game.choose(row.directions[index], game.issue_choice_token()):
				return _fail("golden dungeon source node failed: " + row.entry \
					+ ":" + str(index))
			traversed += 1
		if game.state.phase != "FLOW_PENDING" \
				or game.state.get("dungeonRun") != null \
				or game.state.get("dungeonOutcomeReceipts", []).back().get(
					"outcome") != "success" \
				or game.state.dungeonOutcomeReceipts.back().get("path") != []:
			return _fail("golden dungeon did not finish once: " + row.entry)
		if row.dungeon == "ancientRuins" and (
				not game.state.resources.treasures.has("guardianCore") \
				or not game.state.resources.treasures.has("ancientJade") \
				or int(game.state.resources.pills.get("nascent", 0)) != 1):
			return _fail("ancient ruins treasure and pill rewards missing")
	if traversed != 16:
		return _fail("golden dungeon node count differs")
	var wrong_path = Domain.new(Registry.new(), null, "slot_3")
	if not wrong_path.start("spell"):
		return _fail("wrong-path golden dungeon fixture could not start")
	wrong_path.state.realm = "golden"
	wrong_path.state.phase = "NORMAL_PENDING"
	wrong_path.state.currentCardId = "g_secret_sword"
	if wrong_path.choose("left", wrong_path.issue_choice_token()):
		return _fail("golden sword sanctum admitted a spell-path run")
	var alternate = Domain.new(Registry.new(), null, "slot_3")
	if not alternate.start("spell"):
		return _fail("alternate golden ruins fixture could not start")
	alternate.state.realm = "golden"
	alternate.state.maxHealth = 6
	alternate.state.attributes.health = 5
	alternate.state.phase = "NORMAL_PENDING"
	alternate.state.currentCardId = "g_ruins"
	if not alternate.choose("right", alternate.issue_choice_token()) \
			or not alternate.choose("left", alternate.issue_choice_token()) \
			or not alternate.choose("left", alternate.issue_choice_token()) \
			or not alternate.choose("right", alternate.issue_choice_token()) \
			or not alternate.state.resources.treasures.has("ancientSword") \
			or alternate.state.resources.treasures.has("guardianCore") \
			or not alternate.abandon_dungeon(alternate.issue_choice_token()) \
			or alternate.state.get("dungeonOutcomeReceipts", []).back().get(
				"outcome") != "abandon" \
			or alternate.abandon_dungeon(alternate.issue_choice_token()):
		return _fail("golden ruins alternate treasure or one-time abandon differs")
	print("NONCOMBAT_GOLDEN_DUNGEONS_PASS dungeons=5 nodes=16 rewards=true alternate=true abandon=true")
	quit(0)
