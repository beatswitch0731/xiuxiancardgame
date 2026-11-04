extends RefCounted

const GhostCatalog = preload("res://scripts/noncombat_ghost_market_catalog.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")

# Source: MarketSystem.ensureCadence/tick/_buildBazaarCard. The browser has one
# FlowDirector.pendingFlags.market slot, so a later arrival replaces an older
# one even when an authored card keeps both arrivals off-screen.
const SOURCE_JS_SHA := "1a3ff0e1fcd1990db5ea6e66baa87425b751246c6db2f4f986660544555fc611"
const PROFILE_MODULE := "markets:vendor_profiles"
const RNG_MODULUS := 2147483647
const BAZAAR_ID := "bazaar_encounter"
const GHOST_ID := "market_encounter"

var roll_override := -1.0 # Fixed browser parity tests; never stored.
var ghost_plan_activation_index := 0
var rebirth_archive_verified := false
var last_error := ""
var _content: RefCounted

func _init(content: RefCounted) -> void:
	_content = content

func source_missing() -> bool:
	var path := String(_content.module_path(PROFILE_MODULE))
	return path.is_empty() or not FileAccess.file_exists("res://content/" + path)

func settle(prior: Dictionary, candidate: Dictionary, replay_without_market: bool,
		replay_activation_index: int, replay_initial_seed: int,
		suppress_cadence: bool = false) -> bool:
	last_error = ""
	if replay_without_market:
		return true
	var index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if index < 0:
		last_error = "坊市决定时钟无效"
		return false
	var profiles := _profiles()
	if profiles.is_empty():
		return false
	var source_sha: String = _content.source_sha256(PROFILE_MODULE)
	if source_sha.length() != 64:
		last_error = "坊市来源配置缺失"
		return false
	if not candidate.has("marketStateVersion"):
		# An old FLOW_PENDING snapshot may be resumed without a new player
		# decision. Preserve its exact schema until the next committed choice.
		if not prior.is_empty() and index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
			return true
		if replay_activation_index >= 0 and index < replay_activation_index:
			return true
		if replay_activation_index >= 0 and index > replay_activation_index:
			last_error = "坊市旧档激活点未重放"
			return false
		var seed := replay_initial_seed if replay_initial_seed > 0 else randi_range(1, RNG_MODULUS - 1)
		candidate["marketStateVersion"] = 1
		candidate["marketRuleSourceSha"] = SOURCE_JS_SHA
		candidate["marketProfileSourceSha"] = source_sha
		candidate["marketActivationIndex"] = index
		candidate["marketRngState"] = {"initialSeed": seed, "value": seed}
		candidate["currentLocation"] = String(candidate.get("currentLocation", "宗门"))
		candidate["marketState"] = {
			"version": 3, "lastBazaarDecisionIndex": -99,
			"nextBazaarDecisionIndex": _schedule(candidate, profiles["public_bazaar"], index),
			"lastGhostDecisionIndex": -99,
			"nextGhostDecisionIndex": _schedule_ghost(candidate, profiles["ghost_market"], index),
			"totalVisits": 0, "activeSession": null, "visitHistory": [],
			"ghostMarketAccess": "open", "migrationSource": "fresh_run" if index == 0 else "legacy_clock"
		}
	if not _valid(candidate, source_sha):
		last_error = "坊市存档或来源指纹不符"
		return false
	if prior.is_empty() or index <= int(prior.get("runClock", {}).get("decisionIndex", -1)):
		if prior.is_empty() and ghost_plan_activation_index == index:
			candidate["ghostPlanVersion"] = 1
			candidate["ghostPlanActivationIndex"] = index
		return true
	if candidate.has("ghostPlanVersion"):
		if candidate.get("ghostPlanVersion") != 1 \
				or candidate.get("ghostPlanActivationIndex") != ghost_plan_activation_index \
				or not prior.has("ghostPlanVersion"):
			last_error = "鬼市抽货版本或激活点无效"
			return false
	elif index == ghost_plan_activation_index:
		candidate["ghostPlanVersion"] = 1
		candidate["ghostPlanActivationIndex"] = index
	elif index > ghost_plan_activation_index:
		last_error = "鬼市旧抽货规则未在激活点升级"
		return false
	# GameLogic queues an official delivery before attempting an ambient market
	# tick on this same projected decision. The order itself is not a market roll.
	if suppress_cadence:
		return true
	# Browser queues ripple before attempting an ambient market tick. A newly
	# queued ripple consumes this decision's interruption slot; leave cadence due.
	if int(candidate.get("karmaRippleState", {}).get("lastRippleTurn", -99)) == index:
		return true
	# The browser inserts a newly generated hint in the same interruption slot
	# and skips ambient market cadence for that decision as well.
	var issued_hints: Array = candidate.get("heavensHintState", {}).get("issuedHints", [])
	if not issued_hints.is_empty() and issued_hints.back() is Dictionary \
			and int(issued_hints.back().get("turn", -1)) == index:
		return true
	# GameLogic suppresses ambient market generation during battle/wheel and
	# first-session serial continuation. The first live arrival is decision 6.
	if candidate.get("phase") in ["BATTLE_PENDING", "WARNING_PENDING", "DESTINY_WHEEL_PENDING"] \
			or index <= 5 and candidate.get("noncombatFlow", {}).get("scope") == "first_session_avoid":
		return true
	var market: Dictionary = candidate["marketState"]
	var location := String(candidate.get("currentLocation", ""))
	if location.strip_edges().is_empty():
		return true
	if index >= int(market["nextGhostDecisionIndex"]) \
			and market.get("ghostMarketAccess") != "revoked" \
			and _night(index) and _ghost_signal(candidate, profiles["ghost_market"]):
		market["lastGhostDecisionIndex"] = index
		market["nextGhostDecisionIndex"] = _schedule_ghost(candidate, profiles["ghost_market"], index)
		if not candidate.has("ghostPlanVersion"):
			# Reproduce archived saves that queued the historical placeholder and
			# consumed no stock rolls. Only decisions before activation use it.
			candidate["pendingMarketCard"] = {"id": GHOST_ID,
				"unportedStock": true}
		else:
			var catalog = GhostCatalog.new(_content)
			catalog.rebirth_archive_verified = rebirth_archive_verified
			# Production shares the saved market stream with cadence. Fixed-zero
			# cadence fixtures use seeded stock rolls to avoid duplicate seals.
			var plan: Dictionary = catalog.generate(candidate, func() -> float:
				return _roll_seeded(candidate["marketRngState"]))
			if plan.is_empty():
				last_error = "鬼市货单未能按来源冻结：" + catalog.last_error
				return false
			candidate["pendingGhostPlan"] = plan
			candidate["pendingMarketCard"] = plan["card"].duplicate(true)
		return true
	if index >= int(market["nextBazaarDecisionIndex"]):
		market["lastBazaarDecisionIndex"] = index
		market["nextBazaarDecisionIndex"] = _schedule(candidate, profiles["public_bazaar"], index)
		candidate["marketCardLocation"] = location
		candidate.erase("pendingGhostPlan")
		candidate["pendingMarketCard"] = _bazaar_card(location, String(candidate.get("realm", "qi")))
	return true

func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not state.has("pendingMarketCard"):
		return {}
	if not _valid(state, _content.source_sha256(PROFILE_MODULE)):
		last_error = "坊市待发卡来源不符"
		return {}
	var pending: Variant = state["pendingMarketCard"]
	if not pending is Dictionary:
		last_error = "坊市待发卡损坏"
		return {}
	var expected: Dictionary = {}
	if pending.get("id") == GHOST_ID:
		var plan: Variant = state.get("pendingGhostPlan")
		var catalog = GhostCatalog.new(_content)
		if state.get("ghostPlanVersion") != 1 or not plan is Dictionary \
				or not plan.get("stock") is Array or plan.get("stock", []).is_empty() \
				or plan.get("sourcePins") != catalog.source_pins() \
				or not plan.get("card") is Dictionary:
			last_error = "鬼市待发货单或来源不符"
			return {}
		expected = plan["card"]
	else:
		expected = _bazaar_card(String(state.get("marketCardLocation", "")),
			String(pending.get("realm", "")))
	if JSON.parse_string(JSON.stringify(pending)) != JSON.parse_string(JSON.stringify(expected)):
		last_error = "坊市待发卡与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	candidate.erase("pendingMarketCard")
	candidate["pendingMarketChoiceCard"] = expected
	candidate["currentCardId"] = String(expected["id"])
	candidate["phase"] = "MARKET_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": expected["id"],
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state["turn"], "decisionIndex": state["runClock"]["decisionIndex"],
		"flowSource": "market:20"}
	return candidate

func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "MARKET_PENDING" or not direction in ["left", "right"]:
		return false
	if state.get("currentCardId") == BAZAAR_ID:
		return true
	return state.get("currentCardId") == GHOST_ID and (direction == "right" \
		or ghost_entry_available(state))

func ghost_entry_available(state: Dictionary) -> bool:
	if state.get("phase") != "MARKET_PENDING" or state.get("currentCardId") != GHOST_ID \
			or state.get("marketState", {}).get("activeSession") != null \
			or state.get("marketState", {}).get("ghostMarketAccess") == "revoked" \
			or not state.get("pendingGhostPlan") is Dictionary:
		return false
	var plan: Dictionary = state["pendingGhostPlan"]
	var catalog = GhostCatalog.new(_content)
	if plan.get("sourcePins") != catalog.source_pins() \
			or plan.get("card") != state.get("pendingMarketChoiceCard"):
		return false
	var profiles := _profiles()
	if profiles.is_empty():
		return false
	var profile: Dictionary = profiles["ghost_market"]
	var index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	return index > 0 and (not profile.get("entryRules", {}).get(
		"requiresNightWindow", false) or _night(index)) \
		and (not profile.get("entryRules", {}).get("requiresPopulationLocation", false) \
			or not state.has("currentLocation") or not String(state.get(
				"currentLocation", "")).strip_edges().is_empty()) \
		and _ghost_signal(state, profile)

func settle_skip(state: Dictionary, direction: String,
		tick_karma_seed: bool = true) -> Dictionary:
	last_error = ""
	if direction != "right" or not choice_available(state, direction) \
			or not _valid(state, _content.source_sha256(PROFILE_MODULE)):
		last_error = "坊市选择或来源无效"
		return {}
	var card_id := String(state.get("currentCardId", ""))
	var card: Dictionary = {}
	if card_id == GHOST_ID:
		var plan: Variant = state.get("pendingGhostPlan")
		var catalog = GhostCatalog.new(_content)
		if state.get("ghostPlanVersion") != 1 or not plan is Dictionary \
				or plan.get("sourcePins") != catalog.source_pins() \
				or not plan.get("card") is Dictionary:
			last_error = "鬼市选择货单或来源无效"
			return {}
		card = plan["card"]
	else:
		card = _bazaar_card(String(state.get("marketCardLocation", "")),
			String(state.get("pendingMarketChoiceCard", {}).get("realm", "")))
	if JSON.parse_string(JSON.stringify(state.get("pendingMarketChoiceCard", {}))) != \
			JSON.parse_string(JSON.stringify(card)):
		last_error = "坊市待选卡与来源不符"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var base_index := int(candidate["runClock"].get("decisionIndex", -1))
	var life_id := String(candidate["runClock"].get("lifeId", ""))
	if base_index < 0 or life_id.is_empty():
		return {}
	var next_index := base_index + 1
	var receipt := "decision:%s:choice:%s:%d" % [life_id, card_id, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return {}
	candidate["choiceHistory"].append({"cardId": card_id,
		"cardType": "MARKET" if card_id == GHOST_ID else "BAZAAR",
		"direction": "right", "turn": base_index, "decisionIndex": next_index, "tags": []})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append(card_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	if tick_karma_seed:
		MilestoneFlow.tick_seeds(candidate)
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card_id, "kind": "choice"}
	candidate.erase("pendingMarketChoiceCard")
	candidate.erase("pendingGhostPlan")
	candidate.erase("marketCardLocation")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": card_id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return candidate

func _profiles() -> Dictionary:
	var doc: Variant = _content.read_module(PROFILE_MODULE)
	if not doc is Dictionary:
		last_error = "坊市来源配置不可用"
		return {}
	var profiles := {}
	for item in doc.get("vendors", []):
		if item is Dictionary and item.get("id") in ["public_bazaar", "ghost_market"]:
			profiles[item["id"]] = item
	if profiles.size() != 2:
		last_error = "坊市来源档缺少公开或鬼市档"
		return {}
	for vendor_id in profiles:
		var path := String(profiles[vendor_id].get("presentationProfile", {}).get("backgroundPath", ""))
		if not path.begins_with("../assets/"):
			last_error = "坊市来源背景路径无效"
			return {}
		var art: Dictionary = _content.asset_status(path.trim_prefix("../"))
		if not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			last_error = "坊市来源背景不可用"
			return {}
	return profiles

func _schedule(candidate: Dictionary, profile: Dictionary, base: int) -> int:
	var cadence: Dictionary = profile.get("cadence", {})
	var min_decisions := maxi(1, int(cadence.get("minDecisions", 6)))
	var max_decisions := maxi(min_decisions, int(cadence.get("maxDecisions", 10)))
	return base + min_decisions + int(_roll(candidate["marketRngState"]) *
		(max_decisions - min_decisions + 1))

func _schedule_ghost(candidate: Dictionary, profile: Dictionary, base: int) -> int:
	var cadence: Dictionary = profile.get("cadence", {})
	var min_decisions := maxi(1, int(cadence.get("minDecisions", 14)))
	var max_decisions := maxi(min_decisions, int(cadence.get("maxDecisions", 20)))
	var candidates: Array[int] = []
	for offset in range(min_decisions, max_decisions + 1):
		if _night(base + offset): candidates.append(base + offset)
	if candidates.is_empty():
		return _schedule(candidate, profile, base)
	return candidates[mini(candidates.size() - 1,
		int(_roll(candidate["marketRngState"]) * candidates.size()))]

func _night(index: int) -> bool:
	return posmod(index, 4) in [2, 3]

func _ghost_signal(candidate: Dictionary, profile: Dictionary) -> bool:
	var requested: Array = profile.get("entryRules", {}).get("signalAny", [])
	if requested.is_empty(): return true
	var attrs: Dictionary = candidate.get("attributes", {})
	return requested.has("fortune>=40") and int(attrs.get("fortune", 0)) >= 40 \
		or requested.has("karmaBad>=10") and int(attrs.get("karmaBad", 0)) >= 10 \
		or requested.has("ghost_market_lead") and (candidate.get(
			"marketState", {}).get("ghostMarketLead") == true \
			or int(candidate.get("itemInventory", {}).get("鬼市路引", 0)) > 0)

func _roll(rng: Dictionary) -> float:
	if roll_override >= 0.0:
		return clampf(roll_override, 0.0, 0.999999)
	return _roll_seeded(rng)

func _roll_seeded(rng: Dictionary) -> float:
	var value := int((int(rng["value"]) * 48271) % RNG_MODULUS)
	rng["value"] = value
	return float(value) / float(RNG_MODULUS)

func seed_matching_initial_schedule(bazaar_index: int, ghost_index: int,
		next_bazaar_index: int = -1) -> int:
	var profiles := _profiles()
	if profiles.is_empty():
		return 0
	for seed in range(1, 100001):
		var candidate := {"marketRngState": {"value": seed}}
		var first_bazaar := _schedule(candidate, profiles["public_bazaar"], 0)
		var first_ghost := _schedule_ghost(candidate, profiles["ghost_market"], 0)
		if first_bazaar == bazaar_index and first_ghost == ghost_index \
				and (next_bazaar_index < 0 or _schedule(candidate,
					profiles["public_bazaar"], bazaar_index) == next_bazaar_index):
			return seed
	return 0

func _valid(candidate: Dictionary, source_sha: String) -> bool:
	if candidate.get("marketStateVersion") != 1 or candidate.get("marketRuleSourceSha") != SOURCE_JS_SHA \
			or source_sha.length() != 64 or candidate.get("marketProfileSourceSha") != source_sha \
			or not candidate.get("marketState") is Dictionary \
			or not candidate.get("marketRngState") is Dictionary:
		return false
	var rng: Dictionary = candidate["marketRngState"]
	if int(rng.get("initialSeed", 0)) <= 0 or int(rng.get("value", 0)) <= 0 \
			or int(rng.get("value", 0)) >= RNG_MODULUS:
		return false
	var market: Dictionary = candidate["marketState"]
	return market.get("version") == 3 and int(market.get("nextBazaarDecisionIndex", -1)) >= 0 \
		and int(market.get("nextGhostDecisionIndex", -1)) >= 0

func _bazaar_card(location: String, realm: String) -> Dictionary:
	return {"id": BAZAAR_ID, "title": "行商到访 · 三摊开张",
		"description": "商队在%s外支起三盏不同的灯：药材、旧货和鉴物各占一席。摊主说得明白——买卖不占人情，但你若肯帮忙或打听，他们会记得。" % location,
		"type": "BAZAAR", "realm": realm, "weight": 0, "once": false,
		"choices": {
			"left": {"text": "循摊位逐一看看", "effects": {},
				"action": {"type": "ENTER_VENDOR", "vendorId": "public_bazaar",
					"marketEncounter": true, "resumePolicy": "ON_VENDOR_CLOSED",
					"settlePolicy": "AFTER_CLOSE_EXACTLY_ONCE"},
				"desc": "本次可做两次深度来往；购买与换物另行结算。"},
			"right": {"text": "记下商队旗号，继续赶路", "effects": {},
				"desc": "错过的摊主和线索会在这次到访结束后离开。"}}}
