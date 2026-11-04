extends RefCounted

# The imported source snapshot is immutable. Rebuild the observed first
# exchange from card intents and recorded native random receipts.
const Combat = preload("res://scripts/combat_domain.gd")
const Seal = preload("res://scripts/noncombat_browser_combat_seal.gd")


func replay(snapshot: Dictionary, authority: Dictionary, request: Dictionary,
		plan: Dictionary, actions: Array, registry: RefCounted) -> Dictionary:
	if actions.size() > 4:
		return {}
	var combat = Combat.new(registry)
	if not combat.load_persisted_request(request, plan) \
			or not combat.load_browser_first_sword_snapshot(snapshot, authority, request):
		return {}
	for index in actions.size():
		var action: Variant = actions[index]
		if not action is Dictionary:
			return {}
		if action.get("type") == "END_TURN":
			if index != 2 or action.size() != 1 \
					or actions[0].get("cardId") != "sword_edge" \
					or actions[1].get("cardId") != "sword_followthrough" \
					or not combat.end_turn():
				return {}
			continue
		if action.get("type") == "REACTION":
			var expected_values: Array = _reaction_random_values(authority, request)
			if index != 3 or action.size() != 3 \
					or actions[2].get("type") != "END_TURN" \
					or action.get("reactionId") != "TAKE_HIT" \
					or not action.get("randomValues") is Array \
					or action.randomValues.size() != 5 \
					or action.randomValues != expected_values \
					or combat.state.get("phase") != "REACTION_OPEN" \
					or not combat.set_replay_random_values(action.randomValues) \
					or not combat.choose_reaction("TAKE_HIT") \
					or combat.replay_random_remaining() != 0:
				return {}
			continue
		if index >= 2 or action.size() != 3 \
				or action.get("type") != "PLAY_CARD" \
				or not (action.get("handIndex") is int \
					or action.get("handIndex") is float) \
				or float(action.get("handIndex", -1)) != floorf(
					float(action.get("handIndex", -1))) \
				or not action.get("cardId") is String \
				or combat.state.get("turn") != 1 \
				or combat.state.get("phase") != "PLAYER_TURN":
			return {}
		var hand_index: int = action.handIndex
		var hand: Array = combat.state.get("hand", [])
		if hand_index < 0 or hand_index >= hand.size() \
				or hand[hand_index] != action.cardId:
			return {}
		var card: Dictionary = registry.get_battle_card(action.cardId)
		if card.get("id") not in ["sword_guard", "sword_edge",
				"sword_followthrough"] or combat.state.get("player", {}).get(
				"critRate") != 0:
			return {}
		for effect in card.get("effects", []):
			if not effect is Dictionary or effect.get("type") not in [
					"damage", "block", "status"]:
				return {}
		if not combat.play_card(hand_index):
			return {}
	return combat.state.duplicate(true)


func propose_reaction(snapshot: Dictionary, authority: Dictionary,
		request: Dictionary, plan: Dictionary, actions: Array,
		registry: RefCounted) -> Dictionary:
	if actions.size() != 3 or actions[2].get("type") != "END_TURN":
		return {}
	var before: Dictionary = replay(snapshot, authority, request, plan,
		actions, registry)
	if before.is_empty() or before.get("phase") != "REACTION_OPEN":
		return {}
	var combat = Combat.new(registry)
	if not combat.load_persisted_request(request, plan) \
			or not combat.load_browser_first_sword_snapshot(snapshot, authority, request):
		return {}
	combat.state = before.duplicate(true)
	var random_values: Array = _reaction_random_values(authority, request)
	if random_values.size() != 5 \
			or not combat.set_replay_random_values(random_values) \
			or not combat.choose_reaction("TAKE_HIT") \
			or combat.replay_random_remaining() != 0:
		return {}
	var receipt := {"type": "REACTION", "reactionId": "TAKE_HIT",
		"randomValues": random_values}
	var proposed: Array = actions.duplicate(true)
	proposed.append(receipt)
	if replay(snapshot, authority, request, plan, proposed,
			registry) != combat.state:
		return {}
	return {"action": receipt, "state": combat.state.duplicate(true)}


func _reaction_random_values(authority: Dictionary, request: Dictionary) -> Array:
	var owner := String(request.get("encounterInstanceId", ""))
	if owner.is_empty():
		return []
	# Restore binds these exact fields to its replayed world and encounter.
	# Ignore the source snapshot's public seal and unrelated extra fields.
	var projection := {
		"owner": owner,
		"sourceCardId": request.get("sourceCardId"),
		"encounterId": request.get("encounterId"),
		"path": authority.get("path"),
		"realm": authority.get("realm"),
		"lifeCount": authority.get("lifeCount"),
		"decisionIndex": authority.get("runClock", {}).get("decisionIndex"),
		"health": authority.get("attributes", {}).get("health"),
		"daoHeart": authority.get("attributes", {}).get("daoHeart"),
		"aura": authority.get("attributes", {}).get("aura"),
		"maxHealth": authority.get("maxHealth"),
		"deck": authority.get("deck")}
	var digest := ("n10:first-sword:reaction:1:world:" + Seal.new().stable_serialize(
		projection)).sha256_text()
	var alphabet := "0123456789abcdef"
	var seed_value := 0
	for index in 15:
		var digit := alphabet.find(digest.substr(index, 1))
		if digit < 0:
			return []
		seed_value = seed_value * 16 + digit
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var values: Array = []
	for _index in 5:
		values.append(floorf(rng.randf() * 100000000.0) / 100000000.0)
	return values
