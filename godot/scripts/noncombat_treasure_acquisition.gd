extends RefCounted

# Godot's candidate-only port of TreasureSystem.acquire. The instance ledger
# is authoritative; resources.treasures and treasureInventory are derived reads.
const SOURCE_JS_SHA := "54bea3094b2cabb2cca9397a930e863672aa32d2cff31e3e5dc1258a66323d89"
const MODULE := "shops:treasures"
const SLOTS := ["weapon", "armor", "accessory", "artifact"]

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func acquire(state: Dictionary, definition_id: String, source_id: String,
		decision_index: int, vendor_source: Dictionary = {}) -> bool:
	last_error = ""
	var catalog: Variant = _content.read_module(MODULE)
	var source_sha: String = _content.source_sha256(MODULE)
	if not catalog is Dictionary or not catalog.get("treasures") is Array \
			or source_sha.length() != 64:
		last_error = "法宝定义来源不可用"
		return false
	var definitions := {}
	for row in catalog["treasures"]:
		if row is Dictionary and row.get("id") is String:
			definitions[row["id"]] = row
	if not definitions.has(definition_id) or source_id.is_empty() or decision_index < 0:
		last_error = "法宝或取得来源无效"
		return false
	if state.has("treasureRuleSourceSha") and (
			state["treasureRuleSourceSha"] != SOURCE_JS_SHA \
			or state.get("treasureSourceSha") != source_sha):
		last_error = "法宝规则来源已变化"
		return false
	var candidate: Dictionary = state.duplicate(true)
	if not _ensure_ledger(candidate, definitions):
		return false
	var receipt := "treasure:destiny:life:%s:decision:%d:slot:%s:item:%s" % [
		candidate.get("runClock", {}).get("lifeId", ""), decision_index,
		source_id.get_slice(":", source_id.get_slice_count(":") - 1), definition_id]
	var provenance := {"source": "destiny_wheel", "sourceId": receipt,
		"channel": "destiny"}
	if not vendor_source.is_empty():
		var public_trade: bool = vendor_source.get("source") == "public_bazaar_trade" \
			and vendor_source.get("channel") == "public_bazaar"
		var regulated_order: bool = vendor_source.get("source") \
			== "regulated_rusted_sword_order" \
			and vendor_source.get("channel") == "regulated_market" \
			and definition_id == "licensed_rusted_sword" \
			and vendor_source.get("sourceId") is String \
			and vendor_source.get("details") is Dictionary \
			and String(vendor_source.get("sourceId", "")).begins_with(
				"licensed_rusted_sword:") \
			and vendor_source.get("transactionId") \
				== "licensed_rusted_sword_delivery:" + String(
					vendor_source.get("sourceId", "")) \
			and String(vendor_source.get("details", {}).get(
				"rootFactInstanceId", "")).begins_with("fact:")
		var ghost_oath: bool = vendor_source.get("source") == "ghost_market_purchase" \
			and vendor_source.get("channel") == "ghost_market" \
			and definition_id == "ghost_oath_rusted_sword" \
			and vendor_source.get("sourceId") is String \
			and String(vendor_source.get("sourceId", "")).ends_with(
				":ghost_oath_rusted_sword") \
			and vendor_source.get("details") is Dictionary \
			and vendor_source.get("details", {}).get("exchangeMode") == "ghost_oath" \
			and vendor_source.get("details", {}).get("contractKind") == "ghost_oath_sword"
		var ghost_ordinary: bool = vendor_source.get("source") == "ghost_market_purchase" \
			and vendor_source.get("channel") == "ghost_market" \
			and definition_id != "ghost_oath_rusted_sword" \
			and definitions[definition_id].get("type") in SLOTS \
			and vendor_source.get("sessionKey") is String \
			and vendor_source.get("sourceId") == String(vendor_source.get(
				"sessionKey", "")) + ":" + definition_id \
			and vendor_source.get("transactionId") == \
				"treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					vendor_source.get("sessionKey"), definition_id] \
			and vendor_source.get("details") == {}
		var lesson_session: Dictionary = candidate.get("marketState", {}).get(
			"activeSession") if candidate.get("marketState", {}).get(
				"activeSession") is Dictionary else {}
		var lesson_offer_id := String(vendor_source.get("offerId", ""))
		var regulated_ordinary: bool = vendor_source.get("source") == "shop_purchase" \
			and vendor_source.get("channel") == "regulated_market" \
			and lesson_session.get("entryCardId") in ["thread_last_lesson_n2",
				"shop_encounter", "q_market", "loc_market_first"] \
			and lesson_session.get("vendorId") == "regulated_market" \
			and lesson_session.get("sessionKey") == vendor_source.get("sessionKey") \
			and lesson_offer_id == "shop_treasure_dyn_" + definition_id \
			and lesson_session.get("immutableOffers", []).any(func(raw: Variant) -> bool:
				return raw is Dictionary and raw.get("id") == lesson_offer_id \
					and raw.get("type") == "treasure" \
					and raw.get("effect", {}).get("treasureId") == definition_id) \
			and definitions[definition_id].get("type") in SLOTS \
			and vendor_source.get("sourceId") == String(
				vendor_source.get("sessionKey", "")) + ":" + lesson_offer_id \
			and vendor_source.get("transactionId") == \
				"treasure:shop:life:%s:decision:%d:session:%s:offer:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					vendor_source.get("sessionKey"), lesson_offer_id] \
			and vendor_source.get("details") == {}
		var identify_offer_id := String(vendor_source.get("offerId", ""))
		var shop_identify: bool = vendor_source.get("source") == "shop_identify" \
			and vendor_source.get("channel") == null \
			and lesson_session.get("entryCardId") in ["thread_last_lesson_n2",
				"shop_encounter", "q_market", "loc_market_first"] \
			and lesson_session.get("vendorId") == "regulated_market" \
			and lesson_session.get("sessionKey") == vendor_source.get("sessionKey") \
			and identify_offer_id in ["shop_treasure_box",
				"shop_treasure_mysterious"] \
			and lesson_session.get("immutableOffers", []).any(func(raw: Variant) -> bool:
				return raw is Dictionary and raw.get("id") == identify_offer_id \
					and raw.get("effect", {}).get("_identifyTreasure") == (
						"box" if identify_offer_id == "shop_treasure_box" else "antique")) \
			and vendor_source.get("sourceId") == String(
				vendor_source.get("sessionKey", "")) + ":" + identify_offer_id \
			and vendor_source.get("transactionId") == \
				"treasure:identify:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					vendor_source.get("sourceId"), definition_id] \
			and vendor_source.get("details") == {}
		var rebirth_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == "narrative" \
			and vendor_source.get("sourceId") == "rebirth_boon" \
			and source_id == "rebirth_boon" and definition_id == "避尘珠" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:rebirth_boon:item:避尘珠" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var sword_tomb_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "q_swordTomb" \
			and source_id == "q_swordTomb" and definition_id == "brokenSword" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:q_swordTomb:item:brokenSword" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var sword_cliff_location: Dictionary = {}
		var location_document: Variant = _content.read_module("locations:locations") \
			if source_id == "loc_sword_cliff_deep" else {}
		if location_document is Dictionary:
			for row in location_document.get("cards", []):
				if row is Dictionary and row.get("id") == source_id:
					sword_cliff_location = row
					break
		var sword_cliff_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == source_id \
			and source_id == "loc_sword_cliff_deep" \
			and definition_id == sword_cliff_location.get("choices", {}).get(
				"right", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					source_id, definition_id] \
			and vendor_source.get("details") == {}
		var echo_direction := String(vendor_source.get("details", {}).get("direction", ""))
		var echo_card: Variant = candidate.get("pendingEchoCard")
		var choice_echo_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == source_id \
			and echo_card is Dictionary and echo_card.get("id") == source_id \
			and echo_card.get("type") == "CHOICE_ECHO" \
			and definition_id == echo_card.get("choices", {}).get(
				echo_direction, {}).get("effects", {}).get("treasure") \
			and vendor_source.get("details") == {"direction": echo_direction} \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					source_id, definition_id]
		var surfacing_card: Variant = candidate.get("pendingSurfacingCard")
		var surfacing_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and source_id == "surface_bairen_memory" \
			and vendor_source.get("sourceId") == source_id \
			and surfacing_card is Dictionary and surfacing_card.get("id") == source_id \
			and surfacing_card.get("type") == "SURFACING" \
			and definition_id == surfacing_card.get("choices", {}).get(
				"left", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("details") == {"direction": "left"} \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					source_id, definition_id]
		var sword_trial_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "thread_sword_tomb_3" \
			and source_id == "thread_sword_tomb_3" and definition_id == "剑心古剑" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:thread_sword_tomb_3:item:剑心古剑" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var cave_beast_narrative: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "cave_beast" \
			and source_id == "cave_beast" and definition_id == "beastCore" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:cave_beast:item:beastCore" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var foundation_dungeon_reward: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "realm_treasure" \
			and source_id == "realm_treasure" and definition_id == "realmCore" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:realm_treasure:item:realmCore" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var foundation_auction: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "f_shop" \
			and source_id == "f_shop" and definition_id == "剑心佩" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:f_shop:item:剑心佩" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var foundation_event: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and source_id in ["f_demon2", "f_artifact"] \
			and vendor_source.get("sourceId") == source_id \
			and definition_id == ("demonTome" if source_id == "f_demon2" \
				else "pathRelic") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					source_id, definition_id] \
			and vendor_source.get("details") == {}
		var golden_old_friend: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "g_oldFriend" \
			and source_id == "g_oldFriend" and definition_id == "ancientToken" \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:g_oldFriend:item:ancientToken" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index] \
			and vendor_source.get("details") == {}
		var golden_shop: Dictionary = {}
		var golden_document: Variant = _content.read_module("cards:golden") \
			if source_id == "g_shop" else {}
		for source_card in golden_document.get("cards", []) if golden_document is Dictionary else []:
			if source_card is Dictionary and source_card.get("id") == "g_shop":
				golden_shop = source_card
				break
		var golden_shop_purchase: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "g_shop" \
			and source_id == "g_shop" \
			and definition_id == golden_shop.get("choices", {}).get(
				"right", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:g_shop:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					definition_id] \
			and vendor_source.get("details") == {}
		var nascent_document: Variant = _content.read_module("cards:nascent") \
			if source_id in ["n_trade_city", "n_cave", "nc_treasure", "ar_secret"] else {}
		var nascent_city: Dictionary = {}
		var nascent_cave: Dictionary = {}
		for source_card in nascent_document.get("cards", []) if nascent_document is Dictionary else []:
			if source_card is Dictionary and source_card.get("id") == "n_trade_city":
				nascent_city = source_card
			if source_card is Dictionary and source_card.get("id") == "n_cave":
				nascent_cave = source_card
		var nascent_city_purchase: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "n_trade_city" \
			and source_id == "n_trade_city" \
			and definition_id == nascent_city.get("choices", {}).get(
				"left", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:n_trade_city:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					definition_id] \
			and vendor_source.get("details") == {}
		var golden_dungeon_document: Variant = _content.read_module("cards:golden") \
			if source_id in ["ruins_guardian", "ruins_fork", "ruins_reward"] else {}
		var golden_dungeon_card: Dictionary = golden_dungeon_document.get(
			"dungeonCards", {}).get(source_id, {}) \
			if golden_dungeon_document is Dictionary else {}
		var dungeon_run: Variant = candidate.get("dungeonRun")
		var golden_dungeon_treasure: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == source_id \
			and dungeon_run is Dictionary \
			and dungeon_run.get("dungeonId") == "ancientRuins" \
			and dungeon_run.get("status") == "active" \
			and golden_dungeon_card.get("choices", {}).values().any(
				func(choice: Variant) -> bool: return choice is Dictionary \
					and choice.get("effects", {}).get("treasure") == definition_id) \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					source_id, definition_id] \
			and vendor_source.get("details") == {}
		var nascent_cave_entry_treasure: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "n_cave" \
			and source_id == "n_cave" \
			and definition_id == nascent_cave.get("choices", {}).get(
				"left", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:n_cave:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					definition_id] \
			and vendor_source.get("details") == {}
		var nascent_reward: Dictionary = nascent_document.get(
			"dungeonCards", {}).get("nc_treasure", {}) \
			if nascent_document is Dictionary else {}
		var nascent_cave_reward_treasure: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "nc_treasure" \
			and source_id == "nc_treasure" \
			and dungeon_run is Dictionary \
			and dungeon_run.get("dungeonId") == "nascent_cave" \
			and dungeon_run.get("status") == "active" \
			and definition_id == nascent_reward.get("choices", {}).get(
				"right", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:nc_treasure:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					definition_id] \
			and vendor_source.get("details") == {}
		var nascent_ruins_secret: Dictionary = nascent_document.get(
			"dungeonCards", {}).get("ar_secret", {}) \
			if nascent_document is Dictionary else {}
		var nascent_ruins_treasure: bool = vendor_source.get("source") == "narrative_effect" \
			and vendor_source.get("channel") == null \
			and vendor_source.get("sourceId") == "ar_secret" \
			and source_id == "ar_secret" \
			and dungeon_run is Dictionary \
			and dungeon_run.get("dungeonId") == "ancient_ruins" \
			and dungeon_run.get("status") == "active" \
			and definition_id == nascent_ruins_secret.get("choices", {}).get(
				"left", {}).get("effects", {}).get("treasure") \
			and vendor_source.get("transactionId") == \
				"treasure:narrative:life:%s:decision:%d:source:ar_secret:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					definition_id] \
			and vendor_source.get("details") == {}
		var opportunity: Dictionary = _content.read_module(
			"progression:acquisition_opportunities") if vendor_source.get("source") \
			== "opportunity_reward" else {}
		var opportunity_id := String(vendor_source.get("opportunityId", ""))
		var opportunity_rule: Dictionary = opportunity.get("opportunities", {}).get(
			opportunity_id, {})
		var opportunity_reward: bool = vendor_source.get("source") == "opportunity_reward" \
			and opportunity_rule.get("sourceType") == vendor_source.get("channel") \
			and opportunity_rule.get("sourceCardId") == source_id \
			and vendor_source.get("sourceId") == opportunity_id + ":" + source_id \
			and vendor_source.get("transactionId") == \
				"treasure:opportunity:life:%s:decision:%d:source:%s:item:%s" % [
					candidate.get("runClock", {}).get("lifeId", ""), decision_index,
					vendor_source.get("sourceId"), definition_id] \
			and vendor_source.get("details") == {}
		if not (public_trade or regulated_order or ghost_oath \
				or ghost_ordinary or regulated_ordinary or shop_identify \
				or rebirth_narrative or sword_tomb_narrative \
				or sword_cliff_narrative or choice_echo_narrative \
				or surfacing_narrative \
				or sword_trial_narrative or cave_beast_narrative \
				or foundation_dungeon_reward \
				or foundation_auction or foundation_event or golden_old_friend \
				or golden_shop_purchase or nascent_city_purchase \
				or nascent_cave_entry_treasure or nascent_cave_reward_treasure \
				or nascent_ruins_treasure \
				or golden_dungeon_treasure \
				or opportunity_reward) \
				or not vendor_source.get("transactionId") is String \
				or String(vendor_source["transactionId"]).is_empty() \
				or not vendor_source.get("sourceId") is String \
				or not vendor_source.get("details") is Dictionary:
			last_error = "法宝交易来源无效"
			return false
		receipt = String(vendor_source["transactionId"])
		provenance = vendor_source["details"].duplicate(true)
		provenance["source"] = vendor_source["source"]
		provenance["sourceId"] = String(vendor_source["sourceId"])
		provenance["channel"] = vendor_source["channel"]
	if candidate["treasureCommandReceipts"].has(receipt):
		last_error = "法宝奖励重复领取"
		return false
	var serial := 1
	var instance_id := "tr:%s:%d" % [definition_id, serial]
	while candidate["treasureInstances"].has(instance_id):
		serial += 1
		instance_id = "tr:%s:%d" % [definition_id, serial]
	candidate["treasureInstances"][instance_id] = {
		"instanceId": instance_id, "definitionId": definition_id,
		"provenance": provenance, "acquiredDecision": decision_index,
		"transactionId": receipt, "lifecycle": "owned"}
	candidate["treasureCommandReceipts"][receipt] = {"operation": "acquire",
		"transactionId": receipt, "instanceId": instance_id,
		"definitionId": definition_id, "decisionIndex": decision_index}
	candidate["treasureRuleSourceSha"] = SOURCE_JS_SHA
	candidate["treasureSourceSha"] = source_sha
	_refresh_derived(candidate)
	state.merge(candidate, true)
	return true

func equip_owned(state: Dictionary, instance_id: String, slot: String) -> bool:
	last_error = ""
	var catalog: Variant = _content.read_module(MODULE)
	if not catalog is Dictionary or slot not in SLOTS:
		return false
	var definitions := {}
	for row in catalog.get("treasures", []):
		if row is Dictionary and row.get("id") is String:
			definitions[row["id"]] = row
	var candidate: Dictionary = state.duplicate(true)
	if not _ensure_ledger(candidate, definitions):
		return false
	var instance: Dictionary = candidate.get("treasureInstances", {}).get(instance_id, {})
	if instance.get("lifecycle") != "owned" or not definitions.has(
			instance.get("definitionId")) or definitions[instance["definitionId"]].get(
			"type") != slot:
		return false
	for other_slot in SLOTS:
		if other_slot != slot and candidate["equipment"].get(other_slot) == instance_id:
			return false
	candidate["equipment"][slot] = instance_id
	_refresh_derived(candidate)
	state.merge(candidate, true)
	return true


func unequip_owned(state: Dictionary, instance_id: String, slot: String) -> bool:
	last_error = ""
	var catalog: Variant = _content.read_module(MODULE)
	if not catalog is Dictionary or slot not in SLOTS:
		return false
	var definitions := {}
	for row in catalog.get("treasures", []):
		if row is Dictionary and row.get("id") is String:
			definitions[row["id"]] = row
	var candidate: Dictionary = state.duplicate(true)
	if not _ensure_ledger(candidate, definitions) \
			or candidate.get("equipment", {}).get(slot) != instance_id:
		return false
	candidate["equipment"][slot] = null
	_refresh_derived(candidate)
	state.merge(candidate, true)
	return true


func revive_equipped(state: Dictionary) -> Dictionary:
	last_error = ""
	if int(state.get("attributes", {}).get("daoHeart", 1)) > 0 \
			and int(state.get("attributes", {}).get("health", 1)) > 0 \
			and int(state.get("resources", {}).get("lifespan", 1)) > 0:
		return {"revived": false}
	var catalog: Variant = _content.read_module(MODULE)
	var source_sha: String = _content.source_sha256(MODULE)
	if not catalog is Dictionary or not catalog.get("treasures") is Array \
			or source_sha.length() != 64:
		last_error = "法宝定义来源不可用"
		return {}
	if state.has("treasureRuleSourceSha") and (
			state.treasureRuleSourceSha != SOURCE_JS_SHA \
			or state.get("treasureSourceSha") != source_sha):
		last_error = "法宝规则来源已变化"
		return {}
	var definitions := {}
	for row in catalog.treasures:
		if row is Dictionary and row.get("id") is String:
			definitions[row.id] = row
	var candidate: Dictionary = state.duplicate(true)
	if not _ensure_ledger(candidate, definitions):
		return {}
	var instance_id: Variant = candidate.equipment.get("artifact")
	if instance_id == null or instance_id == "":
		return {"revived": false}
	var instance: Dictionary = candidate.treasureInstances.get(instance_id, {})
	if instance.get("lifecycle") != "owned" or not definitions.has(
			instance.get("definitionId")):
		last_error = "复活秘宝所有权无效"
		return {}
	var definition: Dictionary = definitions[instance.definitionId]
	var revive: Variant = definition.get("revive")
	if revive == null:
		return {"revived": false}
	if not revive is Dictionary or revive.get("type") not in [
			"nirvana", "substitute", "samsara", "chaos"]:
		last_error = "复活秘宝规则无效"
		return {}
	var max_health := int(candidate.get("maxHealth", 3))
	match String(revive.type):
		"nirvana":
			candidate.attributes.health = max_health
			candidate.attributes.daoHeart = maxi(0,
				int(candidate.attributes.daoHeart) - 1)
		"substitute":
			candidate.attributes.health = mini(max_health, 2)
			candidate.resources.spiritStone = floori(
				float(candidate.resources.spiritStone) * 0.5)
		"samsara":
			candidate.attributes.health = mini(max_health, 2)
			candidate.attributes.daoHeart = maxi(0,
				int(candidate.attributes.daoHeart) - 2)
			candidate.attributes.cultivation = floori(
				float(candidate.attributes.cultivation) * 0.8)
		"chaos":
			candidate.attributes.health = max_health
			candidate.attributes.cultivation = floori(
				float(candidate.attributes.cultivation) * 0.8)
	for slot in SLOTS:
		if candidate.equipment.get(slot) == instance_id:
			candidate.equipment[slot] = null
	candidate.treasureInstances.erase(instance_id)
	candidate.treasureCooldowns.erase(instance_id)
	candidate["dead"] = false
	candidate["deadReason"] = ""
	candidate["treasureRuleSourceSha"] = SOURCE_JS_SHA
	candidate["treasureSourceSha"] = source_sha
	_refresh_derived(candidate)
	return {"revived": true, "state": candidate,
		"instanceId": instance_id, "type": revive.type}


func _ensure_ledger(candidate: Dictionary, definitions: Dictionary) -> bool:
	var resources: Variant = candidate.get("resources")
	if not resources is Dictionary or not resources.get("treasures") is Array:
		last_error = "法宝资源结构无效"
		return false
	var instances: Variant = candidate.get("treasureInstances")
	if not instances is Dictionary:
		# Preserve old Godot saves that have only the legacy list, including
		# duplicate copies of the same definition.
		instances = {}
		var count := {}
		for definition_id in resources["treasures"]:
			if not definition_id is String or not definitions.has(definition_id):
				last_error = "旧档包含未知法宝"
				return false
			count[definition_id] = int(count.get(definition_id, 0)) + 1
			var instance_id := "legacy:%s:%d" % [definition_id, count[definition_id]]
			instances[instance_id] = {"instanceId": instance_id,
				"definitionId": definition_id,
				"provenance": {"source": "legacy_save", "migrationVersion": 8},
				"acquiredDecision": int(candidate.get("turn", 0)),
				"lifecycle": "owned"}
		candidate["treasureInstances"] = instances
	for instance_id in instances:
		var entry: Variant = instances[instance_id]
		if not entry is Dictionary or entry.get("instanceId") != instance_id \
				or not definitions.has(entry.get("definitionId")):
			last_error = "法宝实例账本无效"
			return false
	var equipment: Variant = candidate.get("equipment", {})
	if not equipment is Dictionary:
		last_error = "法宝装备结构无效"
		return false
	var used: Array = []
	for slot in SLOTS:
		var equipped: Variant = equipment.get(slot)
		if equipped != null and equipped != "":
			if not instances.has(equipped) or used.has(equipped) \
					or definitions[instances[equipped]["definitionId"]].get("type") != slot:
				last_error = "法宝装备与实例不符"
				return false
			used.append(equipped)
		else:
			equipment[slot] = null
	candidate["equipment"] = equipment
	if not candidate.get("treasureCooldowns", {}) is Dictionary \
			or not candidate.get("treasureCommandReceipts", {}) is Dictionary:
		last_error = "法宝冷却或回执结构无效"
		return false
	candidate["treasureCooldowns"] = candidate.get("treasureCooldowns", {})
	candidate["treasureCommandReceipts"] = candidate.get("treasureCommandReceipts", {})
	candidate["_treasureOwnershipMigrationRequired"] = false
	return true


func _refresh_derived(candidate: Dictionary) -> void:
	var ids: Array = []
	var inventory: Array = []
	var equipped: Array = candidate["equipment"].values()
	for instance_id in candidate["treasureInstances"]:
		var definition_id: String = candidate["treasureInstances"][instance_id]["definitionId"]
		if not ids.has(definition_id):
			ids.append(definition_id)
		if not equipped.has(instance_id):
			inventory.append(instance_id)
	candidate["resources"]["treasures"] = ids
	candidate["treasureInventory"] = inventory
