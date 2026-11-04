extends RefCounted

const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const RegulatedCatalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const RegulatedVendor = preload("res://scripts/noncombat_regulated_vendor_flow.gd")

const ENTRY_ID := "thread_last_lesson_n2"
const OFFER_ID := "last_lesson_three_tone_sword"
const BARTER_ID := "last_lesson_exchange_sword_tassel"
const FALLBACK_ID := "last_lesson_insufficient_sect_loan"
const VENDOR_ID := "regulated_market"
const IDENTIFY_JS_SHA := "7552c41cbb707c642c1b66d434c084c33241227ada146ff9322ba707a53a72dc"
const ITEM_MODULE := "shops:shop_items"
const LESSON_MODULE := "threads:last_lesson_threads"
const PROFILE_MODULE := "markets:vendor_profiles"
const CATALOG_MODULES := ["shops:treasures", "combat:deck_progression",
	"cards:battle_cards", "world:trade_routes", "world:factions",
	"config:realms", "config:path_skills"]

var _content: RefCounted
var _threads: RefCounted
var _treasures: RefCounted
var _deck: RefCounted
var _regulated_vendor: RefCounted
var last_error := ""
var legacy_service_replay := false


func _init(content: RefCounted, threads: RefCounted) -> void:
	_content = content
	_threads = threads
	_treasures = TreasureAcquisition.new(content)
	_deck = DeckAcquisition.new(content)
	_regulated_vendor = RegulatedVendor.new(content)


func source_pins() -> Dictionary:
	var item_sha := String(_content.source_sha256(ITEM_MODULE))
	var lesson_sha := String(_content.source_sha256(LESSON_MODULE))
	var profile_sha := String(_content.source_sha256(PROFILE_MODULE))
	if item_sha.length() != 64 or lesson_sha.length() != 64 \
			or profile_sha.length() != 64:
		return {}
	var pins := {"items": item_sha, "lesson": lesson_sha,
		"profile": profile_sha}
	for module_id in CATALOG_MODULES:
		var sha := String(_content.source_sha256(module_id))
		if sha.length() != 64:
			return {}
		pins[module_id] = sha
	return pins


func _profile() -> Dictionary:
	var source: Variant = _content.read_module(PROFILE_MODULE)
	if source is Dictionary:
		for row in source.get("vendors", []):
			if row is Dictionary and row.get("id") == VENDOR_ID \
					and row.get("marketType") == "regulated" \
					and not String(row.get("presentationProfile", {}).get(
						"backgroundPath", "")).is_empty():
				return row.duplicate(true)
	return {}


func _offer() -> Dictionary:
	var source: Variant = _content.read_module(ITEM_MODULE)
	if not source is Dictionary:
		return {}
	for raw in source.get("items", []):
		if raw is Dictionary and raw.get("id") == OFFER_ID \
				and raw.get("type") == "story_item" and raw.get("realm") == "deity" \
				and raw.get("price") == 18 and raw.get("effect", {}).get(
					"itemId") == OFFER_ID and raw.get("storyAlternatives", []).size() == 2:
			return raw.duplicate(true)
	return {}


func open(state: Dictionary, ordinary_offers: Array) -> Dictionary:
	last_error = ""
	var current: Dictionary = _threads.card(state)
	var offer := _offer()
	var pins := source_pins()
	var profile := _profile()
	if state.get("phase") != "THREAD_PENDING" or current.get("id") != ENTRY_ID \
			or current.get("_threadId") != "bairen_last_lesson" \
			or current.get("choices", {}).get("left", {}).get("action", {}).get(
				"type") != "ENTER_VENDOR" \
			or current.get("choices", {}).get("left", {}).get("action", {}).get(
				"vendorId") != VENDOR_ID or offer.is_empty() or pins.is_empty() \
			or profile.is_empty() or ordinary_offers.is_empty() \
			or state.get("marketState", {}).get("activeSession") != null:
		last_error = "最后一课坊市入口或来源商品无效"
		return {}
	var next := state.duplicate(true)
	var index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	if index < 1:
		return {}
	var key := "vendor:%s:%d:%s:%s" % [state.runClock.lifeId,
		index, ENTRY_ID, VENDOR_ID]
	var causal_services: Array = []
	if not legacy_service_replay:
		_regulated_vendor.last_error = ""
		causal_services = _regulated_vendor._materialize_causal_services(next, index)
		if not _regulated_vendor.last_error.is_empty():
			last_error = _regulated_vendor.last_error
			return {}
		next["lastLessonServiceVersion"] = 1
		next["regulatedCausalServiceVersion"] = 1
		if not next.has("regulatedCausalActivationIndex"):
			next["regulatedCausalActivationIndex"] = index
		next["regulatedCausalGraphSourceSha"] = _content.source_sha256(
			"narrative:causal_graph")
	var offers: Array = [offer]
	for ordinary in ordinary_offers:
		if not ordinary is Dictionary or ordinary.get("id") == OFFER_ID:
			return {}
		offers.append(ordinary.duplicate(true))
	var session := {"version": 1, "status": "open", "vendorId": VENDOR_ID,
		"entryCardId": ENTRY_ID, "sessionKey": key,
		"openedAtDecisionIndex": index, "sourcePins": pins,
		"presentationProfile": profile.presentationProfile.duplicate(true),
		"entryCheckpoint": state.get("decisionCheckpoint", {}).duplicate(true),
		"immutableOffers": offers,
		"summary": {"openingOfferCount": offers.size(), "purchaseCount": 0,
			"spiritStoneSpent": 0, "exchangeCount": 0, "resolution": null,
			"purchasedItems": [], "exchangedItems": []}}
	if not legacy_service_replay:
		session["services"] = profile.get("services", []).duplicate(true) + causal_services
		session["actionReceipts"] = {}
	next["marketState"]["activeSession"] = session
	next["phase"] = "VENDOR_OPEN"
	next["currentCardId"] = "vendor_pending:" + ENTRY_ID
	next["decisionCheckpoint"] = {"version": 1, "cardId": next.currentCardId,
		"sourceCardId": ENTRY_ID, "turn": next.get("turn"),
		"decisionIndex": next.runClock.decisionIndex, "vendorSessionKey": key}
	return next


func source_valid(state: Dictionary) -> bool:
	var session: Variant = state.get("marketState", {}).get("activeSession")
	return session is Dictionary and session.get("entryCardId") == ENTRY_ID \
		and session.get("vendorId") == VENDOR_ID \
		and session.get("sourcePins") == source_pins() \
		and session.get("presentationProfile") == _profile().get(
			"presentationProfile") \
		and session.get("sessionKey") == "vendor:%s:%d:%s:%s" % [
			state.get("runClock", {}).get("lifeId"),
			int(session.get("openedAtDecisionIndex", -1)), ENTRY_ID, VENDOR_ID] \
		and not _offer().is_empty()


func _open_valid(state: Dictionary) -> bool:
	return state.get("phase") == "VENDOR_OPEN" and source_valid(state) \
		and state.get("marketState", {}).get("activeSession", {}).get("status") == "open" \
		and int(state.get("marketState", {}).get("activeSession", {}).get(
			"openedAtDecisionIndex", -1)) == int(state.get("runClock", {}).get(
				"decisionIndex", -1)) + 1


func pending_card(state: Dictionary) -> Dictionary:
	if not _open_valid(state):
		return {}
	return {"id": "vendor_pending:" + ENTRY_ID, "title": "最后一课 · 三鸣旧剑",
		"type": "VENDOR_PENDING", "realm": state.get("realm", "deity"),
		"description": "可购买旧剑、用剑穗交换、灵石不足时借剑，或空手离开。交易结束后才继续师徒故事。",
		"weight": 0, "once": true, "choices": {}}


func available_offers(state: Dictionary) -> Array:
	if not _open_valid(state):
		return []
	var result := []
	for offer in state.marketState.activeSession.immutableOffers:
		var supported: bool = offer.get("id") == OFFER_ID \
			or _ordinary_supported(offer, state)
		result.append({"id": offer.id, "name": offer.name,
			"price": int(offer.price), "stallName": "万宝楼",
			"supported": supported, "enabled": supported and int(state.resources.get(
				"spiritStone", 0)) >= int(offer.price)})
	return result


func available_actions(state: Dictionary) -> Array:
	if not _open_valid(state):
		return []
	var result: Array = _regulated_vendor.available_actions_session(state)
	if not _sword_available(state.marketState.activeSession.immutableOffers):
		return result
	var offer := _offer()
	for alternative in offer.storyAlternatives:
		var enabled := int(state.get("itemInventory", {}).get("剑穗", 0)) >= 1 \
			if alternative.get("id") == BARTER_ID else int(state.resources.get(
				"spiritStone", 0)) < int(offer.price)
		result.append({"id": alternative.id, "label": alternative.get("label", ""),
			"description": alternative.get("description", ""), "enabled": enabled})
	return result


func _append_event(next: Dictionary, session_key: String,
		kind: String, item_id: String) -> void:
	if not next.has("lastLessonVendorEventHistory"):
		next["lastLessonVendorEventHistory"] = []
	next.lastLessonVendorEventHistory.append({"sessionKey": session_key,
		"kind": kind, "itemId": item_id})


func _sword_available(offers: Array) -> bool:
	return offers.any(func(raw: Variant) -> bool:
		return raw is Dictionary and raw.get("id") == OFFER_ID)


func _without_sword(offers: Array) -> Array:
	return offers.filter(func(raw: Variant) -> bool:
		return raw is Dictionary and raw.get("id") != OFFER_ID)


func _without_offer(offers: Array, offer_id: String) -> Array:
	return offers.filter(func(raw: Variant) -> bool:
		return raw is Dictionary and raw.get("id") != offer_id)


func _ordinary_supported(offer: Dictionary, state: Dictionary) -> bool:
	if offer.get("type") == "treasure" and offer.get("effect", {}).has(
			"_identifyTreasure"):
		return offer.get("id") in ["shop_treasure_box",
			"shop_treasure_mysterious"] and offer.get("effect", {}).get(
				"_identifyTreasure") == ("box" if offer.get("id") == \
					"shop_treasure_box" else "antique") \
			and int(offer.get("price", -1)) >= 1
	if offer.get("type") == "card":
		var deck_doc: Variant = _content.read_module("combat:deck_progression")
		var card_doc: Variant = _content.read_module("cards:battle_cards")
		if not deck_doc is Dictionary or not card_doc is Dictionary:
			return false
		var expected: Dictionary = RegulatedCatalog.new(_content)._path_offer(
			state, deck_doc, card_doc, String(state.get("realm", "")))
		return not expected.is_empty() and offer.get("id") == expected.get("id") \
			and offer.get("effect") == expected.get("effect") \
			and offer.get("path") == expected.get("path") \
			and offer.get("realm") == expected.get("realm") \
			and int(offer.get("price", -1)) >= 1
	if offer.get("type") == "treasure":
		var definition_id := String(offer.get("effect", {}).get("treasureId", ""))
		if offer.get("id") != "shop_treasure_dyn_" + definition_id \
				or int(offer.get("price", -1)) < 1:
			return false
		var document: Variant = _content.read_module("shops:treasures")
		if document is Dictionary:
			for raw in document.get("treasures", []):
				if raw is Dictionary and raw.get("id") == definition_id \
						and raw.get("type") in TreasureAcquisition.SLOTS \
						and raw.get("name") == offer.get("name") \
						and raw.get("realm", "qi") == offer.get("realm") \
						and raw.get("storyOnly") != true:
					return true
		return false
	if offer.get("type") not in ["gift", "pill"] \
			or int(offer.get("price", -1)) < 1:
		return false
	var source: Variant = _content.read_module(ITEM_MODULE)
	if not source is Dictionary:
		return false
	for raw in source.get("items", []):
		if not raw is Dictionary or raw.get("id") != offer.get("id") \
				or raw.get("type") != offer.get("type") \
				or raw.get("effect") != offer.get("effect"):
			continue
		var effect: Dictionary = raw.get("effect", {})
		if raw.get("type") == "gift":
			return effect.get("giftItemId") is String \
				and int(effect.get("quantity", 0)) > 0
		return effect.has("pillId") or effect.has("healHp") \
			or effect.has("healDaoHeart") or effect.has("tempCultivation")
	return false


func _actual_health_cap(state: Dictionary) -> int:
	var skill = PathSkillFlow.new(_content)
	var cap := skill.actual_max_health(state)
	if not skill.last_error.is_empty():
		last_error = skill.last_error
		return -1
	return cap


func _identify_roll(supplied: Dictionary, key: String) -> float:
	var raw: Variant = supplied[key] if supplied.has(key) else randf()
	if not (raw is int or raw is float) or float(raw) < 0.0 \
			or float(raw) >= 1.0:
		return -1.0
	return float(raw)


func _identify_purchase(next: Dictionary, offer: Dictionary,
		supplied: Dictionary) -> Dictionary:
	var document: Variant = _content.read_module("shops:treasures")
	if not document is Dictionary:
		return {}
	var by_realm := {"qi": [], "foundation": [], "golden": [], "nascent": []}
	for raw in document.get("treasures", []):
		if not raw is Dictionary or not raw.get("id") is String:
			return {}
		var realm := String(raw.get("realm", "qi"))
		by_realm[realm if realm in ["qi", "foundation", "golden"] else "nascent"].append(raw.id)
	# TreasureSystem loads the same definitions into EquipmentSystem. EffectService
	# iterates both registries, so its second pass adds every tierless item to qi.
	for raw in document.get("treasures", []):
		var tier := String(raw.get("tier", ""))
		var bucket := "nascent" if tier in ["天阶", "玄阶"] else \
			"golden" if tier == "地阶" else \
			"foundation" if tier == "灵阶" else "qi"
		by_realm[bucket].append(raw.id)
	if by_realm.qi.is_empty():
		by_realm = {"qi": ["玄铁甲", "灵泉葫芦"],
			"foundation": ["避尘珠", "剑心佩"],
			"golden": ["避尘珠", "剑心佩"],
			"nascent": ["避尘珠", "剑心佩"]}
	var is_box: bool = offer.get("effect", {}).get("_identifyTreasure") == "box"
	var identify_roll := _identify_roll(supplied, "identifyRoll")
	if identify_roll < 0.0:
		return {}
	var fortune := float(next.get("attributes", {}).get("fortune", 0))
	var heart := float(next.get("attributes", {}).get("daoHeart", 0))
	var score := identify_roll * (120.0 if is_box else 100.0) \
		+ fortune * (2.5 if is_box else 2.0) \
		+ heart * (2.5 if is_box else 1.5)
	var outcome := {"identifyRoll": identify_roll}
	next["shopIdentifyRuleSourceSha"] = IDENTIFY_JS_SHA
	if is_box and score < 35.0:
		var rewards: Array = _deck.battle_reward_offers(next)
		if not rewards.is_empty():
			var card_id := String(rewards[0].get("cardId", ""))
			var acquired: Dictionary = _deck.acquire_battle_reward(next, card_id,
				"treasure_box_backlash", "treasure_box_backlash_reward",
				"treasure_box")
			if acquired.is_empty():
				return {}
			next.merge(acquired, true)
		return outcome
	var bucket := ""
	if is_box:
		bucket = "foundation" if score < 70.0 else \
			"golden" if score < 105.0 else "nascent"
	else:
		if score < 40.0:
			next.resources.spiritStone = int(next.resources.spiritStone) + 2
			return outcome
		bucket = "qi" if score < 75.0 else \
			"foundation" if score < 95.0 else "golden"
	var candidates: Array = by_realm[bucket]
	if candidates.is_empty():
		candidates = ["玄铁甲", "灵泉葫芦"] if bucket == "qi" else \
			["剑心佩"] if bucket == "golden" and not is_box else \
			["避尘珠", "剑心佩"] if bucket == "foundation" else ["避尘珠"]
	var item_roll := _identify_roll(supplied, "itemRoll")
	if item_roll < 0.0 or candidates.is_empty():
		return {}
	var definition_id := String(candidates[int(floor(item_roll * candidates.size()))])
	var session_key := String(next.marketState.activeSession.sessionKey)
	var source_id := session_key + ":" + String(offer.id)
	var decision_index := int(next.runClock.decisionIndex) + 1
	var token := "treasure:identify:life:%s:decision:%d:source:%s:item:%s" % [
		next.runClock.lifeId, decision_index, source_id, definition_id]
	if not _treasures.acquire(next, definition_id, String(offer.id), decision_index,
			{"source": "shop_identify", "channel": null,
			"sessionKey": session_key, "offerId": offer.id,
			"transactionId": token, "sourceId": source_id, "details": {}}):
		last_error = _treasures.last_error
		return {}
	outcome["itemRoll"] = item_roll
	return outcome


func purchase(state: Dictionary, offer_id: String, cost_mode: String = "",
		identify_rolls: Dictionary = {}) -> Dictionary:
	if not _open_valid(state) or not cost_mode.is_empty():
		return {}
	var offer: Dictionary = {}
	for raw in state.marketState.activeSession.immutableOffers:
		if raw is Dictionary and raw.get("id") == offer_id:
			offer = raw
			break
	if offer.is_empty() or not (offer_id == OFFER_ID or _ordinary_supported(offer, state)) \
			or int(offer.get("price", -1)) < 1 \
			or int(state.resources.get("spiritStone", 0)) < int(offer.price) \
			or offer.get("effect", {}).has("treasureId") and \
				state.get("pendingLoadoutDecision") != null:
		return {}
	if not identify_rolls.is_empty() and not offer.get("effect", {}).has(
			"_identifyTreasure"):
		return {}
	var next := state.duplicate(true)
	var session: Dictionary = next.marketState.activeSession
	next.resources.spiritStone = int(next.resources.spiritStone) - int(offer.price)
	var effect: Dictionary = offer.get("effect", {})
	var identify_outcome := {}
	if offer.get("type") == "card":
		var card_payload: Dictionary = effect.get("deckCard", {})
		var acquired: Dictionary = _deck.acquire_shop_card(next,
			String(card_payload.get("cardId", "")), offer_id)
		if acquired.is_empty():
			last_error = _deck.last_error
			return {}
		next = acquired
		session = next.marketState.activeSession
	elif effect.has("_identifyTreasure"):
		identify_outcome = _identify_purchase(next, offer, identify_rolls)
		if identify_outcome.is_empty():
			return {}
		session = next.marketState.activeSession
	elif offer.get("type") == "treasure":
		var session_key := String(session.sessionKey)
		var decision_index := int(next.runClock.decisionIndex) + 1
		var definition_id := String(effect.treasureId)
		var token := "treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
			next.runClock.lifeId, decision_index, session_key, offer_id]
		if not _treasures.acquire(next, definition_id, offer_id, decision_index,
				{"source": "shop_purchase", "channel": VENDOR_ID,
				"sessionKey": session_key, "offerId": offer_id,
				"transactionId": token,
				"sourceId": session_key + ":" + offer_id, "details": {}}):
			last_error = _treasures.last_error
			return {}
		var instance_id := String(next.get("treasureCommandReceipts", {}).get(
			token, {}).get("instanceId", ""))
		var instance: Dictionary = next.get("treasureInstances", {}).get(instance_id, {})
		if instance.is_empty() or instance.get("definitionId") != definition_id:
			return {}
		var definitions: Variant = _content.read_module("shops:treasures")
		var slot := ""
		if definitions is Dictionary:
			for raw in definitions.get("treasures", []):
				if raw is Dictionary and raw.get("id") == definition_id:
					slot = String(raw.get("type", ""))
					break
		if slot not in TreasureAcquisition.SLOTS:
			return {}
		next["pendingLoadoutDecision"] = {"id": "loadout:%s:%s" % [
			session_key, offer_id], "instanceId": instance_id,
			"sourceVendorSessionKey": session_key, "purchaseReceiptToken": token,
			"targetSlot": slot, "status": "pending",
			"allowedActions": {"equip": true, "stash": true,
				"viewProvenance": true, "return": false}, "refundPolicy": null}
	elif offer_id == OFFER_ID:
		var inventory: Dictionary = next.get("itemInventory", {})
		inventory[OFFER_ID] = int(inventory.get(OFFER_ID, 0)) + 1
		next.itemInventory = inventory
		session.summary.resolution = "purchased"
	elif offer.get("type") == "gift":
		var inventory: Dictionary = next.get("itemInventory", {})
		var gift_id := String(effect.giftItemId)
		inventory[gift_id] = int(inventory.get(gift_id, 0)) + int(effect.quantity)
		next.itemInventory = inventory
	elif effect.has("pillId"):
		var pills: Dictionary = next.resources.get("pills", {})
		pills[effect.pillId] = int(pills.get(effect.pillId, 0)) + 1
		next.resources.pills = pills
	elif effect.has("healHp"):
		var cap := _actual_health_cap(next)
		if cap < 1:
			return {}
		next.attributes.health = mini(cap,
			int(next.attributes.health) + int(effect.healHp))
	elif effect.has("healDaoHeart"):
		next.attributes.daoHeart = mini(LegacyFragmentFlow.actual_max_dao_heart(next),
			int(next.attributes.daoHeart) + int(effect.healDaoHeart))
	elif effect.has("tempCultivation"):
		next.attributes.cultivation = int(next.attributes.cultivation) + int(
			effect.tempCultivation)
	else:
		return {}
	session.immutableOffers = _without_offer(session.immutableOffers, offer_id)
	session.summary.purchaseCount = int(session.summary.purchaseCount) + 1
	session.summary.spiritStoneSpent = int(session.summary.spiritStoneSpent) + int(
		offer.price)
	session.summary.purchasedItems.append({"id": offer_id, "name": offer.name,
		"price": int(offer.price)})
	_append_event(next, String(session.sessionKey), "purchase", offer_id)
	if not identify_outcome.is_empty():
		next.lastLessonVendorEventHistory.back().merge(identify_outcome, true)
	return next


func resolve_loadout(state: Dictionary, action: String) -> Dictionary:
	if action not in ["equip", "stash"]:
		return {}
	var pending: Variant = state.get("pendingLoadoutDecision")
	var session_key := String(pending.get("sourceVendorSessionKey", "")) \
		if pending is Dictionary else ""
	if not pending is Dictionary or pending.get("status") != "pending" \
			or not session_key.begins_with("vendor:%s:" % state.get(
				"runClock", {}).get("lifeId", "")) \
			or not session_key.ends_with(":" + ENTRY_ID + ":" + VENDOR_ID) \
			or state.get("marketState", {}).get("activeSession") is Dictionary \
				and state.marketState.activeSession.get("sessionKey") != session_key \
			or pending.get("targetSlot") not in TreasureAcquisition.SLOTS \
			or pending.get("allowedActions", {}).get(action) != true:
		return {}
	var token := String(pending.get("purchaseReceiptToken", ""))
	var instance_id := String(pending.get("instanceId", ""))
	var receipt: Dictionary = state.get("treasureCommandReceipts", {}).get(token, {})
	var instance: Dictionary = state.get("treasureInstances", {}).get(instance_id, {})
	if receipt.get("instanceId") != instance_id \
			or instance.get("provenance", {}).get("source") != "shop_purchase" \
			or instance.get("provenance", {}).get("sourceId") != \
				String(pending.sourceVendorSessionKey) + ":" + String(
					pending.id).get_slice(":", String(pending.id).get_slice_count(":") - 1):
		return {}
	var next := state.duplicate(true)
	if action == "equip" and not _treasures.equip_owned(next, instance_id,
			String(pending.targetSlot)):
		return {}
	next.pendingLoadoutDecision = null
	next["loadoutResolutionHistory"] = next.get("loadoutResolutionHistory", []).duplicate(true)
	next.loadoutResolutionHistory.append({"purchaseReceiptToken": token,
		"action": action})
	next.lastLessonVendorEventHistory.append({"sessionKey": pending.sourceVendorSessionKey,
		"kind": "loadout", "action": action, "phase": state.get("phase"),
		"decisionIndex": int(state.get("runClock", {}).get("decisionIndex", -1))})
	return next


func interact(state: Dictionary, action_id: String) -> Dictionary:
	if _open_valid(state) and (action_id.begins_with("regulated_buyback:") \
			or action_id.begins_with("causal_fact:")):
		var next: Dictionary = _regulated_vendor.interact_session(state, action_id)
		if next.is_empty():
			last_error = _regulated_vendor.last_error
			return {}
		var history: Array = next.get("regulatedEventHistory", [])
		if history.is_empty() or history.back().get("sessionKey") != \
				state.marketState.activeSession.sessionKey:
			return {}
		history.pop_back()
		if history.is_empty() and not state.has("regulatedEventHistory"):
			next.erase("regulatedEventHistory")
		_append_event(next, String(state.marketState.activeSession.sessionKey),
			"action", action_id)
		return next
	if not _open_valid(state) or not _sword_available(
			state.marketState.activeSession.immutableOffers) \
			or not action_id in [BARTER_ID, FALLBACK_ID]:
		return {}
	var option: Dictionary = {}
	for raw in _offer().get("storyAlternatives", []):
		if raw.get("id") == action_id:
			option = raw
			break
	if option.is_empty():
		return {}
	var next := state.duplicate(true)
	var session: Dictionary = next.marketState.activeSession
	if action_id == BARTER_ID:
		if option.get("type") != "barter_item" or option.get("itemId") != "剑穗" \
				or option.get("quantity") != 1 or option.get("resolution") != "bartered" \
				or int(next.get("itemInventory", {}).get("剑穗", 0)) < 1:
			return {}
		next.itemInventory["剑穗"] = int(next.itemInventory["剑穗"]) - 1
		next.itemInventory[OFFER_ID] = int(next.itemInventory.get(OFFER_ID, 0)) + 1
		session.summary.exchangeCount = int(session.summary.exchangeCount) + 1
		session.summary.resolution = "bartered"
		session.summary.exchangedItems.append({"offeredItemId": OFFER_ID,
			"paymentItemId": "剑穗", "quantity": 1})
	else:
		if option.get("type") != "insufficient_fallback" \
				or option.get("resolution") != "sect_loan" \
				or option.get("playerLocation") != "qingyun_trial_sword_terrace" \
				or int(next.resources.get("spiritStone", 0)) >= 18:
			return {}
		session.summary.resolution = "sect_loan"
		session.summary.playerLocation = option.playerLocation
		next.currentLocation = option.playerLocation
		if not next.has("visitedLocations"):
			next.visitedLocations = []
		if not next.visitedLocations.has(option.playerLocation):
			next.visitedLocations.append(option.playerLocation)
	session.immutableOffers = _without_sword(session.immutableOffers)
	_append_event(next, String(session.sessionKey), "action", action_id)
	return next


func close(state: Dictionary) -> Dictionary:
	if not _open_valid(state):
		return {}
	var working := state.duplicate(true)
	var session: Dictionary = working.marketState.activeSession
	var summary: Dictionary = session.summary
	if summary.get("resolution") == null:
		summary.resolution = "left_empty"
	var fallback: bool = summary.resolution == "sect_loan" and summary.get(
		"playerLocation") == "qingyun_trial_sword_terrace" and working.get(
		"currentLocation") == "qingyun_trial_sword_terrace"
	if not fallback:
		var effects: Dictionary = working.get("pendingThreadCard", {}).get(
			"choices", {}).get("left", {}).get("vendorCloseEffects", {})
		if effects.get("playerLocation") != "deity_market_stone_street":
			return {}
		working.currentLocation = effects.playerLocation
		if not working.has("visitedLocations"):
			working.visitedLocations = []
		if not working.visitedLocations.has(effects.playerLocation):
			working.visitedLocations.append(effects.playerLocation)
	var context := {"mode": "vendor", "vendorSummary": {
		"purchaseCount": int(summary.purchaseCount),
		"spiritStoneSpent": int(summary.spiritStoneSpent),
		"resolution": summary.resolution,
		"purchasedItemIds": []}}
	for row in summary.purchasedItems:
		context.vendorSummary.purchasedItemIds.append(row.id)
	working.phase = "THREAD_PENDING"
	working.currentCardId = ENTRY_ID
	working.decisionCheckpoint = session.entryCheckpoint.duplicate(true)
	var settled: Dictionary = _threads.settle_choice(working, "left", context)
	if settled.is_empty():
		last_error = _threads.last_error
		return {}
	var visit := {"visitId": "market_visit:" + String(session.sessionKey),
		"sessionKey": session.sessionKey, "vendorId": VENDOR_ID,
		"marketType": "regulated", "decisionIndex": settled.runClock.decisionIndex,
		"seen": true, "refused": int(summary.purchaseCount) == 0,
		"outcome": "traded" if int(summary.purchaseCount) > 0 else "declined",
		"missedOffers": []}
	for offer in session.immutableOffers:
		visit.missedOffers.append({"id": offer.id, "name": offer.name, "stallId": null})
	settled.marketState.visitHistory.append(visit)
	while settled.marketState.visitHistory.size() > 48:
		settled.marketState.visitHistory.pop_front()
	var result_id := "vendor_result:%s:%s" % [session.sessionKey, ENTRY_ID]
	var result := {"id": result_id, "title": "三鸣旧剑 · 此行收尾",
		"description": "旧剑交易已结，白刃最后一课继续。",
		"type": "VENDOR_RESULT", "realm": settled.get("realm", "deity"),
		"weight": 0, "once": true,
		"choices": {"right": {"text": "继续行程", "effects": {},
			"action": {"type": "DISMISS_VENDOR_RESULT"}}}}
	settled.marketState.activeSession = {"version": 1, "status": "result",
		"vendorId": VENDOR_ID, "entryCardId": ENTRY_ID,
		"sessionKey": session.sessionKey,
		"openedAtDecisionIndex": session.openedAtDecisionIndex,
		"sourcePins": session.sourcePins, "resultCard": result,
		"presentationProfile": session.presentationProfile.duplicate(true),
		"summary": summary.duplicate(true)}
	settled.pendingVendorResultCard = result
	settled.currentCardId = result_id
	settled.phase = "VENDOR_RESULT_PENDING"
	settled.decisionCheckpoint = {"version": 1, "cardId": result_id,
		"sourceCardId": ENTRY_ID, "turn": settled.turn,
		"decisionIndex": settled.runClock.decisionIndex,
		"vendorSessionKey": session.sessionKey}
	return settled


func result_card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "VENDOR_RESULT_PENDING" or not source_valid(state):
		return {}
	return state.get("pendingVendorResultCard", {}) if state.get(
		"pendingVendorResultCard", {}) == state.get("marketState", {}).get(
			"activeSession", {}).get("resultCard") else {}


func dismiss(state: Dictionary) -> Dictionary:
	var result := result_card(state)
	if result.is_empty() or state.get("currentCardId") != result.get("id"):
		return {}
	var next := state.duplicate(true)
	var index := int(next.runClock.decisionIndex)
	next.choiceHistory.append({"cardId": result.id, "cardType": "VENDOR_RESULT",
		"direction": "right", "turn": index, "decisionIndex": index + 1, "tags": []})
	while next.choiceHistory.size() > 30:
		next.choiceHistory.pop_front()
	next.cardsPlayed.append(result.id)
	next.marketState.activeSession = null
	next.erase("pendingVendorResultCard")
	next.phase = "FLOW_PENDING"
	next.currentCardId = ""
	next.decisionCheckpoint = {"version": 1, "cardId": null,
		"sourceCardId": result.id, "turn": index,
		"decisionIndex": index, "flowPending": true}
	return next
