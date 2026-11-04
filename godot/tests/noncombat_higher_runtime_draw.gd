extends "res://tests/noncombat_foundation_normal_pool.gd"


func _run() -> void:
	for realm in ["nascent", "deity", "tribulation"]:
		var game = Domain.new(Registry.new(), null, "slot_3")
		if not game.start("spell"):
			return _fail("higher runtime draw fixture did not start")
		game._normal_roll_override = 0.1
		var state: Dictionary = game.state.duplicate(true)
		state.realm = realm
		state.attributes.cultivation = 10
		state.resources.spiritStone = 1000
		state.decisionCheckpoint = {"sourceCardId": "higher_runtime_fixture"}
		var drawn: Dictionary = game._draw_normal_after_priorities(state)
		var source_id: String = "cards:" + String(realm)
		var pin_key: String = String(realm) + "SourceSha"
		if drawn.is_empty() or drawn.get("phase") != "NORMAL_PENDING" \
				or String(drawn.get("currentCardId", "")).is_empty() \
				or drawn.get("normalFlow", {}).get(pin_key) != ContentRepository.new().source_sha256(source_id):
			return _fail("higher runtime draw stopped: %s %s" % [realm,
				game._normal_flow_error])
		var cold: Dictionary = JSON.parse_string(JSON.stringify(drawn))
		var card: Dictionary = DrawPolicy.new(ContentRepository.new()).source_card(
			cold, String(cold.currentCardId))
		if card.is_empty() or not card.get("choices", {}).keys().any(
				func(direction: Variant) -> bool:
					return ChoicePolicy.new(ContentRepository.new()).choice_available(
						cold, card, String(direction))):
			return _fail("higher runtime draw did not recover a playable card: " + realm)
	print("NONCOMBAT_HIGHER_RUNTIME_DRAW_PASS realms=3")
	quit(0)
