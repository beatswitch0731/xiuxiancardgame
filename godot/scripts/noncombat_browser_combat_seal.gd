extends RefCounted

# Browser DeckCombatSystem v3 uses canonical JSON plus two 32-bit Math.imul lanes.
# This checks seal and ledger consistency only. Browser hydration additionally
# replays authored opening and card transitions against rules, cards, and state.
const PREFIX := "xiuxian-deck-combat-v2|"
const ROOT_CHAIN := "dc2-root"
const KINDS := ["TURN_START", "CARD_PLAY", "REACTION_OPEN", "REACTION_RESOLVED", "LEGACY_MIGRATED"]
const REACTIONS := ["TAKE_HIT", "GUARD", "EVADE", "DEFLECT", "INTERRUPT", "ABSORB", "TRANSMUTE"]


func verify_hash_chain(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.get("version") != 3 \
			or snapshot.get("active") != true or not snapshot.get("originalCard") is Dictionary:
		return false
	var ledger: Variant = snapshot.get("authorityLedger")
	if not ledger is Array or ledger.is_empty() or ledger.size() > 1024:
		return false
	var seal: Variant = snapshot.get("authoritySeal")
	if not seal is String or seal != compute_seal(snapshot):
		return false
	var previous := ROOT_CHAIN
	var previous_turn := 0
	for index in ledger.size():
		var entry: Variant = ledger[index]
		if not entry is Dictionary or entry.get("sequence") != index + 1 \
				or entry.get("previous") != previous or entry.get("kind") not in KINDS \
				or entry.get("sourceCardId") != snapshot.originalCard.get("id") \
				or not entry.get("state") is Dictionary:
			return false
		var turn: Variant = entry.get("turn")
		if not (turn is int or turn is float) or floor(float(turn)) != float(turn) \
				or int(turn) < previous_turn:
			return false
		var detail: Variant = entry.get("detail")
		if not detail is Dictionary:
			return false
		match entry.kind:
			"CARD_PLAY":
				if not detail.get("cardId") is String or detail.cardId.is_empty() \
						or not (detail.get("handIndex") is int or detail.get("handIndex") is float) \
						or floor(float(detail.handIndex)) != float(detail.handIndex) \
						or detail.handIndex < 0:
					return false
			"REACTION_OPEN":
				if not detail.get("windowId") is String or detail.windowId.is_empty():
					return false
			"REACTION_RESOLVED":
				if not detail.get("windowId") is String or detail.get("reactionId") not in REACTIONS:
					return false
		var unsigned: Dictionary = entry.duplicate(true)
		unsigned.erase("hash")
		if entry.get("hash") != compute_seal({"ledgerEntry": unsigned}):
			return false
		previous = entry.hash
		previous_turn = int(turn)
	if snapshot.get("authorityChain") != previous:
		return false
	return stable_serialize(ledger.back().state) == stable_serialize(_projection(snapshot))


func compute_seal(snapshot: Dictionary) -> String:
	var payload := snapshot.duplicate(true)
	payload.erase("authoritySeal")
	var source := PREFIX + stable_serialize(payload)
	var primary := 0x811c9dc5
	var secondary := 0x9e3779b9
	var unit_index := 0
	for character_index in source.length():
		var point := source.unicode_at(character_index)
		var units: Array[int] = []
		if point > 0xffff:
			point -= 0x10000
			units = [0xd800 + (point >> 10), 0xdc00 + (point & 0x3ff)]
		else:
			units = [point]
		for code in units:
			primary = _imul32(primary ^ code, 0x01000193)
			secondary = _imul32(secondary ^ (code + unit_index), 0x85ebca6b)
			unit_index += 1
	return "dc2-%08x%08x" % [primary, secondary]


func stable_serialize(value: Variant) -> String:
	if value is float:
		if not is_finite(value):
			return "null"
		if value == 0.0:
			return "0"
		if floor(value) == value and abs(value) < 9007199254740992.0:
			return JSON.stringify(int(value))
		var decimal := JSON.stringify(value)
		if decimal.ends_with(".0"):
			decimal = decimal.substr(0, decimal.length() - 2)
		if abs(value) < 0.000001 or abs(value) >= 1e21:
			return _scientific(decimal)
		return decimal
	if value is Array:
		var members: Array[String] = []
		for item in value:
			members.append(stable_serialize(item))
		return "[" + ",".join(members) + "]"
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(_utf16_less)
		var members: Array[String] = []
		for key in keys:
			members.append(JSON.stringify(String(key)) + ":" + stable_serialize(value[key]))
		return "{" + ",".join(members) + "}"
	return JSON.stringify(value)


func _utf16_less(left: Variant, right: Variant) -> bool:
	var a: String = String(left)
	var b: String = String(right)
	var a_units := _utf16_units(a)
	var b_units := _utf16_units(b)
	for index in mini(a_units.size(), b_units.size()):
		if a_units[index] != b_units[index]:
			return a_units[index] < b_units[index]
	return a_units.size() < b_units.size()


func _utf16_units(value: String) -> Array[int]:
	var result: Array[int] = []
	for index in value.length():
		var point := value.unicode_at(index)
		if point > 0xffff:
			point -= 0x10000
			result.append(0xd800 + (point >> 10))
			result.append(0xdc00 + (point & 0x3ff))
		else:
			result.append(point)
	return result


func _imul32(a: int, b: int) -> int:
	var low := (a & 0xffff) * (b & 0xffff)
	var cross := (a >> 16) * (b & 0xffff) + (a & 0xffff) * (b >> 16)
	return (low + ((cross & 0xffff) << 16)) & 0xffffffff


func _scientific(decimal: String) -> String:
	var negative := decimal.begins_with("-")
	var unsigned := decimal.substr(1) if negative else decimal
	var point := unsigned.find(".")
	if point < 0:
		point = unsigned.length()
	var digits := unsigned.replace(".", "")
	var first := 0
	while first < digits.length() and digits[first] == "0":
		first += 1
	var exponent := point - first - 1
	var significant := digits.substr(first).rstrip("0")
	var mantissa := significant[0]
	if significant.length() > 1:
		mantissa += "." + significant.substr(1)
	return ("-" if negative else "") + mantissa + "e" \
		+ ("+" if exponent >= 0 else "") + str(exponent)


func _projection(snapshot: Dictionary) -> Dictionary:
	var player: Dictionary = snapshot.get("player", {})
	var enemy: Dictionary = snapshot.get("enemy", {})
	var projected_player := {}
	for field in ["hp", "maxHp", "block", "aura", "atkMod", "defMod", "critRate"]:
		projected_player[field] = _js_number(player.get(field))
	var projected_enemy := {"name": enemy.get("name", "")}
	for field in ["hp", "maxHp", "block", "tier", "atkPower", "defPower"]:
		projected_enemy[field] = _js_number(enemy.get(field))
	projected_enemy["planRuntime"] = enemy.get("planRuntime")
	var result := {"phase": snapshot.get("phase"), "turn": _js_number(snapshot.get("turn")),
		"qi": _js_number(snapshot.get("qi")), "player": projected_player,
		"enemy": projected_enemy, "bossPhaseIndex": _js_number(snapshot.get("bossPhaseIndex", 0)),
		"nextTurnDrawPenalty": _js_number(snapshot.get("nextTurnDrawPenalty")),
		"damageDealtThisTurn": bool(snapshot.get("damageDealtThisTurn")),
		"pendingReaction": snapshot.get("pendingReaction"),
		"pathCombatState": snapshot.get("pathCombatState")}
	for field in ["masterDeck", "drawPile", "hand", "discardPile", "exhaustPile",
			"playerStatusesAppliedByEnemy", "settledReactionWindows"]:
		result[field] = snapshot.get(field, [])
	for field in ["playerStatus", "enemyStatus", "equipmentState"]:
		result[field] = snapshot.get(field, {})
	return result


func _js_number(value: Variant) -> Variant:
	if value == null:
		return 0
	if value is int or value is float:
		return value
	if value is String and value.is_valid_float():
		return float(value)
	return null
