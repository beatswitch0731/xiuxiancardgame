extends RefCounted

# Story-side copy of SkillCardAcquisitionSystem's reward transactions.
# It writes only to a candidate RunSession snapshot; combat reads that deck.
const DECK_MODULE := "combat:deck_progression"
const CARD_MODULE := "cards:battle_cards"

var _content: RefCounted
var last_error := ""


func _init(content: RefCounted) -> void:
	_content = content


func ensure_starter(state: Dictionary) -> Dictionary:
	last_error = ""
	var deck_rules: Variant = _content.read_module(DECK_MODULE)
	var card_rules: Variant = _content.read_module(CARD_MODULE)
	var deck_sha: String = _content.source_sha256(DECK_MODULE)
	var card_sha: String = _content.source_sha256(CARD_MODULE)
	if not deck_rules is Dictionary or not card_rules is Dictionary \
			or deck_sha.length() != 64 or card_sha.length() != 64:
		last_error = "起始牌组来源不可用"
		return {}
	var path_id := String(state.get("path", ""))
	var starter: Variant = deck_rules.get("paths", {}).get(path_id, {}).get("starterDeck")
	var definitions: Variant = card_rules.get("battle_cards")
	if not starter is Array or starter.size() != 6 or not definitions is Array:
		last_error = "流派起始牌组无效"
		return {}
	for card_id in starter:
		if not card_id is String or _card_definition(definitions, String(card_id)).is_empty():
			last_error = "起始牌缺少来源定义"
			return {}
	var existing: Variant = state.get("deck", [])
	if not existing is Array or not existing.is_empty() and (
			state.get("starterDeckPath") != path_id \
			or existing.size() < starter.size() \
			or existing.slice(0, starter.size()) != starter):
		last_error = "已有牌组不属于当前流派"
		return {}
	var operations: Variant = state.get("deckOperations", [])
	var acquisitions: Variant = state.get("skillAcquisitions", {})
	if not operations is Array or not acquisitions is Dictionary:
		last_error = "牌组存档结构无效"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if existing.is_empty():
		candidate["deck"] = starter.duplicate(true)
	candidate["starterDeckPath"] = path_id
	candidate["deckOperations"] = operations.duplicate(true)
	candidate["skillAcquisitions"] = acquisitions.duplicate(true)
	if not candidate["deckOperations"].any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("operation") == "starter_grant"):
		candidate["deckOperations"].append({"operation": "starter_grant",
			"sourceType": "starter_path", "sourceId": "path_select:" + path_id,
			"path": path_id, "realm": candidate.get("realm"), "turn": 0,
			"cardIds": starter.duplicate(true)})
	candidate["deckStateVersion"] = 1
	candidate["deckProgressionSourceSha"] = deck_sha
	candidate["battleCardSourceSha"] = card_sha
	return candidate


func acquire_legacy(state: Dictionary, card_id: String,
		source_card_id: String, source_type: String = "legacy_deck_effect",
		source_turn: int = -1, source_meta: Dictionary = {}) -> Dictionary:
	last_error = ""
	var deck_rules: Variant = _content.read_module(DECK_MODULE)
	var card_rules: Variant = _content.read_module(CARD_MODULE)
	var deck_sha: String = _content.source_sha256(DECK_MODULE)
	var card_sha: String = _content.source_sha256(CARD_MODULE)
	if not deck_rules is Dictionary or not card_rules is Dictionary \
			or deck_sha.length() != 64 or card_sha.length() != 64:
		last_error = "牌组来源不可用"
		return {}
	var path_id := String(state.get("path", ""))
	var path_rules: Dictionary = deck_rules.get("paths", {}).get(path_id, {})
	var starter: Variant = path_rules.get("starterDeck")
	var definitions: Variant = card_rules.get("battle_cards")
	if not starter is Array or starter.size() != 6 or not definitions is Array \
			or source_card_id.is_empty() or card_id.is_empty():
		last_error = "牌组或取得来源无效"
		return {}
	var definition := _card_definition(definitions, card_id)
	if definition.is_empty() or not definition.get("tags") is Array \
			or not definition["tags"].has(path_id) \
			or source_type == "legacy_fragment_set" and not definition["tags"].has("legacy") \
			or not source_type in ["legacy_deck_effect", "legacy_fragment_set",
				"story_quest_completion"] \
			or source_type == "legacy_fragment_set" and (
				definition.get("legacySetId") != source_card_id \
				or definition.get("legacyPath") != path_id):
		last_error = "奖励卡与流派不符"
		return {}
	for starter_id in starter:
		if not starter_id is String or _card_definition(definitions,
				String(starter_id)).is_empty():
			last_error = "流派起始牌缺少定义"
			return {}
	var existing: Variant = state.get("deck", [])
	if not existing is Array or not existing.is_empty() \
			and state.get("starterDeckPath") != path_id:
		last_error = "当前牌组与流派不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	if existing.is_empty():
		candidate["deck"] = starter.duplicate(true)
		candidate["starterDeckPath"] = path_id
		candidate["deckOperations"] = candidate.get("deckOperations", [])
		candidate["deckOperations"].append({"operation": "starter_grant",
			"sourceType": "starter_path", "sourceId": "path_select:" + path_id,
			"path": path_id, "realm": candidate.get("realm"), "turn": 0,
			"cardIds": starter.duplicate(true)})
	var acquisition_map: Dictionary = candidate.get("skillAcquisitions", {})
	if _owned(candidate["deck"], acquisition_map, card_id):
		last_error = "奖励卡已取得"
		return {}
	candidate["deck"].append(card_id)
	candidate["skillAcquisitions"] = acquisition_map
	var record := {"cardId": card_id, "cardName": definition.get("name", card_id),
		"offerId": null, "sourceId": source_card_id,
		"sourceType": source_type, "locationId": source_meta.get("locationId"),
		"realm": candidate.get("realm"), "path": path_id,
		"turn": source_turn if source_turn >= 0 else int(candidate.get("turn", 0)),
		"mode": source_meta.get("mode", "legacy"),
		"chance": source_meta.get("chance"), "roll": source_meta.get("roll")}
	candidate["skillAcquisitions"][card_id] = record
	candidate["deckOperations"] = candidate.get("deckOperations", [])
	candidate["deckOperations"].append({"operation": "acquire",
		"sourceType": record["sourceType"], "sourceId": source_card_id,
		"path": path_id, "realm": candidate.get("realm"),
		"turn": record["turn"], "cardId": card_id,
		"mode": record["mode"]})
	if candidate["deckOperations"].size() > 100:
		candidate["deckOperations"] = candidate["deckOperations"].slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate["battleLoadout"]["deck"] = candidate["deck"].duplicate(true)
	if candidate.get("noncombatFlow") is Dictionary:
		candidate["noncombatFlow"]["deckProgressionSourceSha"] = deck_sha
		candidate["noncombatFlow"]["battleCardSourceSha"] = card_sha
	return candidate


func acquire_shop_card(state: Dictionary, card_id: String,
		offer_id: String) -> Dictionary:
	last_error = ""
	var rules: Variant = _content.read_module(DECK_MODULE)
	var card_doc: Variant = _content.read_module(CARD_MODULE)
	var deck_sha := String(_content.source_sha256(DECK_MODULE))
	var card_sha := String(_content.source_sha256(CARD_MODULE))
	var path := String(state.get("path", ""))
	var realm := String(state.get("realm", ""))
	if not rules is Dictionary or not card_doc is Dictionary \
			or deck_sha.length() != 64 or card_sha.length() != 64 \
			or state.get("deckProgressionSourceSha") != deck_sha \
			or state.get("battleCardSourceSha") != card_sha \
			or not state.get("deck") is Array \
			or not state.get("skillAcquisitions") is Dictionary \
			or not state.get("deckOperations") is Array \
			or state.get("starterDeckPath") != path:
		last_error = "坊市功法牌组或来源无效"
		return {}
	var contract: Dictionary = rules.get("paths", {}).get(path, {})
	var pool: Variant = contract.get("shopPoolByRealm", {}).get(realm,
		contract.get("shopPool", []))
	var definition := _card_definition(card_doc.get("battle_cards", []), card_id)
	if not pool is Array or not pool.has(card_id) \
			or offer_id != "card_%s_%s" % [path, card_id] \
			or definition.is_empty() or not definition.get("tags", []).has(path) \
			or _owned(state.deck, state.skillAcquisitions, card_id):
		last_error = "坊市功法不属于当前流派境界或已经取得"
		return {}
	var candidate := state.duplicate(true)
	candidate.deck.append(card_id)
	var source_id := "shop:%s:%s" % [realm, path]
	var record := {"cardId": card_id, "cardName": definition.get("name", card_id),
		"offerId": null, "sourceId": source_id,
		"sourceType": "shop_path_slot", "locationId": null,
		"realm": realm, "path": path, "turn": int(candidate.get("turn", 0)),
		"mode": "path_reward", "chance": null, "roll": null}
	candidate.skillAcquisitions[card_id] = record
	candidate.deckOperations.append({"operation": "acquire",
		"sourceType": "shop_path_slot", "sourceId": source_id,
		"path": path, "realm": realm, "turn": record.turn,
		"cardId": card_id, "mode": "path_reward"})
	if candidate.deckOperations.size() > 100:
		candidate.deckOperations = candidate.deckOperations.slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate.battleLoadout.deck = candidate.deck.duplicate(true)
	if candidate.get("noncombatFlow") is Dictionary:
		candidate.noncombatFlow.deckProgressionSourceSha = deck_sha
		candidate.noncombatFlow.battleCardSourceSha = card_sha
	return candidate


func battle_reward_offers(state: Dictionary) -> Array:
	last_error = ""
	var context := _battle_reward_context(state)
	if context.is_empty():
		return []
	var offers: Array = []
	for card_id in context["pool"]:
		var definition := _card_definition(context["definitions"], String(card_id))
		if definition.is_empty() or not definition.get("tags", []).has(context["path"]) \
				or _owned(state.get("deck", []), state.get("skillAcquisitions", {}), String(card_id)):
			continue
		offers.append({"cardId": card_id, "cardName": definition.get("name", card_id),
			"description": definition.get("description", definition.get("desc", "")),
			"path": context["path"], "realm": context["realm"], "sourceType": "battle_reward"})
		if offers.size() == 3:
			break
	return offers


func acquire_battle_reward(state: Dictionary, card_id: String,
		source_card_id: String, source_type: String = "battle_reward",
		mode: String = "path_reward") -> Dictionary:
	last_error = ""
	var context := _battle_reward_context(state)
	if context.is_empty():
		return {}
	var definition := _card_definition(context["definitions"], card_id)
	if source_card_id.is_empty() or source_type not in ["battle_reward", "breakthrough_reward",
			"treasure_box_backlash_reward"] \
			or source_type == "treasure_box_backlash_reward" and (
				source_card_id != "treasure_box_backlash" or mode != "treasure_box") \
			or not context["pool"].has(card_id) \
			or definition.is_empty() or not definition.get("tags", []).has(context["path"]):
		last_error = "战利功法与流派、境界或取得来源不符"
		return {}
	if _owned(state.get("deck", []), state.get("skillAcquisitions", {}), card_id):
		last_error = "奖励卡已取得"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	# Camp removal/upgrades are authoritative. Acquiring a reward appends to the
	# current deck, without reconstructing or revalidating its starter prefix.
	candidate["deck"] = candidate.get("deck", [])
	candidate["deck"].append(card_id)
	var record := {"cardId": card_id, "cardName": definition.get("name", card_id),
		"offerId": null, "sourceId": source_card_id, "sourceType": source_type,
		"locationId": null, "realm": context["realm"], "path": context["path"],
		"turn": int(candidate.get("turn", 0)), "mode": mode,
		"chance": null, "roll": null}
	candidate["skillAcquisitions"] = candidate.get("skillAcquisitions", {})
	candidate["skillAcquisitions"][card_id] = record
	candidate["deckOperations"] = candidate.get("deckOperations", [])
	candidate["deckOperations"].append({"operation": "acquire",
		"sourceType": record["sourceType"], "sourceId": source_card_id,
		"path": context["path"], "realm": context["realm"], "turn": record["turn"],
		"cardId": card_id, "mode": record["mode"]})
	if candidate["deckOperations"].size() > 100:
		candidate["deckOperations"] = candidate["deckOperations"].slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate["battleLoadout"]["deck"] = candidate["deck"].duplicate(true)
	if candidate.get("noncombatFlow") is Dictionary:
		candidate["noncombatFlow"]["deckProgressionSourceSha"] = context["deckSha"]
		candidate["noncombatFlow"]["battleCardSourceSha"] = context["cardSha"]
	return candidate


func _battle_reward_context(state: Dictionary) -> Dictionary:
	var rules: Variant = _content.read_module(DECK_MODULE)
	var card_doc: Variant = _content.read_module(CARD_MODULE)
	var deck_sha: String = _content.source_sha256(DECK_MODULE)
	var card_sha: String = _content.source_sha256(CARD_MODULE)
	if not rules is Dictionary or not card_doc is Dictionary \
			or not card_doc.get("battle_cards") is Array \
			or deck_sha.length() != 64 or card_sha.length() != 64:
		last_error = "战利功法来源不可用"
		return {}
	var path_id := String(state.get("path", ""))
	var realm := String(state.get("realm", "qi"))
	var path_rules: Variant = rules.get("paths", {}).get(path_id)
	if not path_rules is Dictionary or not state.get("deck", []) is Array \
			or not state.get("skillAcquisitions", {}) is Dictionary \
			or not state.get("deckOperations", []) is Array:
		last_error = "流派或牌组存档无效"
		return {}
	var pool: Array = []
	var by_realm: Variant = path_rules.get("rewardPoolByRealm")
	if by_realm is Dictionary:
		var realm_order: Array = rules.get("realmOrder", [])
		var realm_index := realm_order.find(realm)
		if realm_index < 0:
			last_error = "战利功法境界无效"
			return {}
		for realm_id in realm_order.slice(0, realm_index + 1):
			for card_id in by_realm.get(realm_id, []):
				if not pool.has(card_id):
					pool.append(card_id)
	elif path_rules.get("rewardPool") is Array:
		pool = path_rules["rewardPool"].duplicate()
	return {"pool": pool, "definitions": card_doc["battle_cards"],
		"path": path_id, "realm": realm, "deckSha": deck_sha, "cardSha": card_sha}


func camp_targets(state: Dictionary, action: String) -> Array:
	last_error = ""
	if not action in ["remove", "upgrade"]:
		return []
	var rules: Variant = _content.read_module(DECK_MODULE)
	var card_doc: Variant = _content.read_module(CARD_MODULE)
	if not rules is Dictionary or not card_doc is Dictionary \
			or not card_doc.get("battle_cards") is Array \
			or state.get("deckProgressionSourceSha") != _content.source_sha256(DECK_MODULE) \
			or state.get("battleCardSourceSha") != _content.source_sha256(CARD_MODULE):
		last_error = "牌组目标来源不可用或已变更"
		return []
	var deck: Variant = state.get("deck")
	if not deck is Array or state.get("starterDeckPath") != state.get("path"):
		last_error = "当前牌组无效"
		return []
	var economy: Dictionary = rules.get("economy", {})
	var cost_value: Variant = economy.get("removeCost") if action == "remove" \
		else economy.get("upgradeCost")
	var minimum_value: Variant = economy.get("minimumDeckSize")
	if not (cost_value is int or cost_value is float) \
			or not (minimum_value is int or minimum_value is float) \
			or float(cost_value) != float(int(cost_value)) \
			or float(minimum_value) != float(int(minimum_value)) \
			or int(cost_value) < 0 or int(minimum_value) < 1:
		last_error = "牌组费用来源无效"
		return []
	var options: Array = []
	for index in deck.size():
		var card_id: String = String(deck[index])
		var base_id := card_id.trim_suffix("+")
		var definition := _card_definition(card_doc["battle_cards"], base_id)
		var allowed: bool = not definition.is_empty() \
			and int(state.get("resources", {}).get("spiritStone", 0)) >= int(cost_value) \
			and (action != "remove" or deck.size() > int(minimum_value)) \
			and (action != "upgrade" or not card_id.ends_with("+"))
		options.append({"index": index, "cardId": card_id,
			"name": String(definition.get("name", card_id)) + ("+" if card_id.ends_with("+") else ""),
			"cost": int(cost_value), "allowed": allowed})
	return options


func settle_camp_target(state: Dictionary, action: String, index: int) -> Dictionary:
	var options := camp_targets(state, action)
	if index < 0 or index >= options.size() or not options[index].get("allowed", false):
		return {}
	var selected: Dictionary = options[index]
	var card_id := String(selected["cardId"])
	var candidate := state.duplicate(true)
	var cost := int(selected["cost"])
	candidate["resources"]["spiritStone"] = int(
		candidate["resources"]["spiritStone"]) - cost
	var record := {"operation": action, "sourceType": "deck_" + action,
		"sourceId": card_id, "index": index, "turn": int(candidate.get("turn", 0)),
		"path": candidate.get("path"), "realm": candidate.get("realm"), "cost": cost}
	if action == "remove":
		record["cardId"] = card_id
		candidate["deck"].remove_at(index)
	else:
		record["fromCardId"] = card_id
		record["toCardId"] = card_id + "+"
		candidate["deck"][index] = card_id + "+"
	candidate["deckOperations"].append(record)
	if candidate["deckOperations"].size() > 100:
		candidate["deckOperations"] = candidate["deckOperations"].slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate["battleLoadout"]["deck"] = candidate["deck"].duplicate(true)
	return candidate


func _card_definition(definitions: Array, card_id: String) -> Dictionary:
	for value in definitions:
		if value is Dictionary and value.get("id") == card_id:
			return value
	return {}


func _owned(deck: Array, acquisitions: Dictionary, card_id: String) -> bool:
	var canonical := card_id
	while canonical.ends_with("+"):
		canonical = canonical.trim_suffix("+")
	for owned_id in deck + acquisitions.keys():
		if not owned_id is String:
			continue
		var base: String = owned_id
		while base.ends_with("+"):
			base = base.trim_suffix("+")
		if base == canonical:
			return true
	return false
