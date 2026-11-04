extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const MODULE := "companions:arcs"
const PORTRAITS := "companions:portrait_stages"
const RULE_SHA := "08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4"
const NPC_ID := "xuesha_laozu"
const STAGES := [
	{"name": "RECOGNITION", "index": 1, "threshold": 20},
	{"name": "TRUST", "index": 2, "threshold": 40},
	{"name": "COMRADE", "index": 3, "threshold": 60},
	{"name": "LEGACY", "index": 4, "threshold": 80},
]
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const BATTLE_TAGS := ["demonic", "blood", "war", "battle", "slaughter"]

var last_error := ""
var _content: RefCounted

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()

func marker(activation_index: int) -> Dictionary:
	var arc_sha: String = _content.source_sha256(MODULE)
	var portrait_sha: String = _content.source_sha256(PORTRAITS)
	if arc_sha.length() != 64 or portrait_sha.length() != 64:
		last_error = "盟友弧线来源不可用"
		return {}
	return {"version": 1, "activationIndex": activation_index,
		"ruleSha": RULE_SHA, "sourceSha": arc_sha,
		"portraitSha": portrait_sha, "stage": "CONTACT", "stageIndex": 0,
		"alignment": 0, "enteredAtTurn": 0, "eventsTriggered": [],
		"pendingStages": [], "pendingClimaxes": [], "climaxTriggered": false}

func valid(state: Dictionary) -> bool:
	var arc: Variant = state.get("allyArcState")
	if not arc is Dictionary or arc.get("version") != 1 \
			or arc.get("ruleSha") != RULE_SHA \
			or arc.get("sourceSha") != _content.source_sha256(MODULE) \
			or arc.get("portraitSha") != _content.source_sha256(PORTRAITS) \
			or not arc.get("eventsTriggered") is Array \
			or not arc.get("pendingStages") is Array \
			or not arc.get("pendingClimaxes") is Array \
			or not _whole_number(arc.get("alignment")) \
			or not _whole_number(arc.get("stageIndex")):
		last_error = "盟友弧线状态或来源指纹不符"
		return false
	return true

func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value))

func advance(prior: Dictionary, candidate: Dictionary) -> bool:
	last_error = ""
	if not valid(candidate):
		return false
	var old_index := int(prior.get("runClock", {}).get("decisionIndex", -1))
	var new_index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if new_index < old_index:
		return true
	var arc: Dictionary = candidate["allyArcState"]
	var delta := maxi(0, int(candidate.get("attributes", {}).get("karmaBad", 0)) -
		int(prior.get("attributes", {}).get("karmaBad", 0)))
	if delta > 0:
		_add_alignment(arc, maxi(1, ceili(float(delta) * 0.5)),
			int(prior.get("turn", 0)))
	var recent: Array = candidate.get("choiceHistory", [])
	if new_index > old_index and not recent.is_empty():
		var entry: Variant = recent.back()
		if entry is Dictionary and int(entry.get("decisionIndex", -1)) == new_index:
			for tag in entry.get("tags", []):
				if tag in BATTLE_TAGS:
					_add_alignment(arc, 3, int(prior.get("turn", 0)))
					break
			if entry.get("combatOutcome") == "victory":
				_add_alignment(arc, 4, int(prior.get("turn", 0)))
	var old_realm := String(prior.get("realm", "qi"))
	var new_realm := String(candidate.get("realm", "qi"))
	if old_realm != new_realm and new_realm in ["nascent", "deity", "tribulation"]:
		var bonus: int = {"nascent": 15, "deity": 20, "tribulation": 25}[new_realm]
		_add_alignment(arc, ceili(float(bonus) * 1.2), int(prior.get("turn", 0)))
	_reconcile_realm(arc, new_realm)
	candidate["allyArcState"] = arc
	return true

func _add_alignment(arc: Dictionary, delta: int, entered_turn: int) -> void:
	var old_stage := int(arc.get("stageIndex", 0))
	arc["alignment"] = clampi(int(arc.get("alignment", 0)) + delta, 0, 100)
	for stage in STAGES:
		if int(arc.alignment) >= int(stage.threshold) \
				and int(stage.index) > int(arc.stageIndex):
			arc["stage"] = stage.name
			arc["stageIndex"] = stage.index
			arc["enteredAtTurn"] = entered_turn
			if int(stage.index) > old_stage and not arc.pendingStages.has(stage.name):
				arc["pendingStages"].append(stage.name)
	if int(arc.stageIndex) >= 3 and not arc.get("climaxTriggered", false) \
			and not arc.pendingClimaxes.has("revelation") \
			and not arc.eventsTriggered.has("ally_xuesha_laozu_revelation"):
		arc["pendingClimaxes"].append("revelation")

func _reconcile_realm(arc: Dictionary, realm: String) -> void:
	var index := REALMS.find(realm)
	if index >= 2 and int(arc.stageIndex) >= 3 \
			and not arc.get("climaxTriggered", false) \
			and not arc.pendingClimaxes.has("tribulation") \
			and not arc.eventsTriggered.has("ally_xuesha_laozu_tribulation"):
		arc["pendingClimaxes"].append("tribulation")
	if index >= 4 and int(arc.stageIndex) >= 4 \
			and not arc.pendingClimaxes.has("destiny") \
			and not arc.eventsTriggered.has("ally_xuesha_laozu_destiny"):
		arc["pendingClimaxes"].append("destiny")

func take(state: Dictionary, kind: String) -> Dictionary:
	last_error = ""
	if state.get("phase") != "FLOW_PENDING" or not valid(state) \
			or kind not in ["event", "climax"]:
		return {}
	var arc: Dictionary = state["allyArcState"]
	if not _physically_present(state):
		# Browser _peekArcCard discards queued physical cards whose owner can no
		# longer manifest. Drop this queue on the candidate being committed too.
		if kind == "climax":
			arc["pendingClimaxes"].clear()
		else:
			arc["pendingStages"].clear()
		return {}
	if kind == "climax" and not arc.pendingStages.is_empty():
		return {}
	var queue: Array = arc.pendingClimaxes if kind == "climax" else arc.pendingStages
	if queue.is_empty():
		return {}
	var key := String(queue[0])
	var projected := _project(key, String(state.get("realm", "qi")))
	if projected.is_empty() or arc.eventsTriggered.has(projected.id):
		last_error = "盟友事件来源无法投影"
		return {}
	var candidate := state.duplicate(true)
	candidate["pendingAllyCard"] = projected
	candidate["phase"] = "ALLY_PENDING"
	candidate["currentCardId"] = projected.id
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": projected.id,
		"sourceCardId": state.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": state.get("turn"),
		"decisionIndex": state.get("runClock", {}).get("decisionIndex"),
		"flowSource": "ally_arc:" + kind, "arcKey": key}
	return candidate

func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "ALLY_PENDING" or not valid(state) \
			or not _physically_present(state):
		return {}
	var key := String(state.get("decisionCheckpoint", {}).get("arcKey", ""))
	var projected := _project(key, String(state.get("realm", "qi")))
	return projected if not projected.is_empty() \
		and projected.get("id") == state.get("currentCardId") \
		and JSON.parse_string(JSON.stringify(projected)) == JSON.parse_string(
			JSON.stringify(state.get("pendingAllyCard"))) else {}

func _physically_present(state: Dictionary) -> bool:
	if state.get("deadNpcs", []).has(NPC_ID):
		return false
	var world: Variant = state.get("worldContinuityState")
	# Old Godot saves can predate the world registry. Preserve their existing
	# deadNpcs-only admission; current saves require this life's physical NPC.
	if not world is Dictionary:
		return true
	if world.get("version") != 1 or world.get("lifeId") != state.get("lifeCount", 0):
		return false
	var row: Variant = world.get("npcs", {}).get(NPC_ID)
	return row is Dictionary and row.get("npcId") == NPC_ID \
		and row.get("lifeId") == world.get("lifeId") \
		and row.get("lifecycle") == "ACTIVE" \
		and row.get("manifestation") == "PHYSICAL"

func choice_available(state: Dictionary, direction: String) -> bool:
	var current := card(state)
	if current.is_empty() or not current.get("choices", {}).has(direction):
		return false
	return true

func settle(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	var current := card(state)
	if current.is_empty() or not choice_available(state, direction):
		return {}
	var key := String(state.get("decisionCheckpoint", {}).get("arcKey", ""))
	var is_climax := key in ["revelation", "tribulation", "destiny"]
	var candidate := state.duplicate(true)
	var arc: Dictionary = candidate["allyArcState"]
	var queue: Array = arc.pendingClimaxes if is_climax else arc.pendingStages
	if queue.is_empty() or queue[0] != key or arc.eventsTriggered.has(current.id):
		return {}
	var choice: Dictionary = current.choices[direction]
	var effects: Dictionary = choice.get("effects", {})
	for effect_key in effects:
		if not _apply_attribute(candidate, String(effect_key), effects[effect_key]):
			return {}
	var next_index := int(state.runClock.decisionIndex) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state.runClock.lifeId,
		current.id, next_index]
	if candidate.runClock.receipts.has(receipt):
		return {}
	candidate.runClock.receipts[receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": current.id, "kind": "choice"}
	var record := {"cardId": current.id, "cardType": "ALLY_ARC",
		"direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": current.tags.duplicate(true)}
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = candidate.get("choiceHistory", []).duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	for tag in current.tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(current.id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	queue.pop_front()
	if is_climax:
		arc["pendingClimaxes"] = queue
	else:
		arc["pendingStages"] = queue
	arc["eventsTriggered"].append(current.id)
	if key in ["tribulation", "destiny"]:
		arc["climaxTriggered"] = true
	candidate["allyArcState"] = arc
	candidate.erase("pendingAllyCard")
	var promise_id := "promise:%08x" % _fnv32("life:%d|%s|%s|%s" % [
		int(state.get("lifeCount", 0)), current.semanticKey, current.id, direction])
	var result_id := "promise_result_%08x" % _fnv32(promise_id)
	var response := "你在「%s」中选择了「%s」。这段因缘已给出明确回应。" % [
		current.title, choice.text]
	var result := {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(current.title) + "·回应",
		"description": response, "sceneImage": current.sceneImage,
		"promiseId": promise_id, "originCardId": current.id,
		"originChoice": direction, "_narrativeLane": "primary",
		"_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": response,
				"lane": "narrative"}}}}
	candidate["noncombatFlow"]["promise"] = {"id": promise_id,
		"status": "pending", "sourceCardId": current.id,
		"sourceSemanticKey": current.semanticKey, "sourceTitle": current.title,
		"choiceDirection": direction, "createdDecisionIndex": next_index,
		"dueWithinDecisions": 2, "dueDecisionIndex": next_index + 2,
		"followUpCardId": result_id, "resolvedDecisionIndex": null,
		"resolutionCardId": null}
	candidate["noncombatFlow"]["pendingResultCard"] = result.duplicate(true)
	candidate["pendingNarrativeResult"] = result
	candidate["currentCardId"] = result_id
	candidate["phase"] = "NARRATIVE_RESULT_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": result_id,
		"sourceCardId": current.id, "turn": next_index,
		"decisionIndex": next_index}
	return candidate

func _project(key: String, realm: String) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	var portraits: Variant = _content.read_module(PORTRAITS)
	if not source is Dictionary or not portraits is Dictionary:
		return {}
	var arc: Variant = source.get("allyArc", {}).get(NPC_ID)
	var portrait_list: Variant = portraits.get("portraitStages", {}).get(
		NPC_ID, {}).get("stages")
	if not arc is Dictionary or not portrait_list is Array \
			or portrait_list.is_empty() or not portrait_list[0] is Dictionary:
		return {}
	var image_path := String(portrait_list[0].get("asset", ""))
	var image_status: Dictionary = _content.asset_status(image_path)
	if not image_status.get("shaVerified", false) \
			or not image_status.get("textureLoadable", false):
		return {}
	var authored: Variant = arc.get("arcStages", {}).get(key) if key not in [
		"revelation", "tribulation", "destiny"] else arc.get({
		"revelation": "revelation", "tribulation": "tribulationClimax",
		"destiny": "destinyClimax"}[key])
	if not authored is Dictionary:
		return {}
	for field in ["title", "desc", "leftText", "rightText"]:
		if not authored.get(field) is String or String(authored[field]).is_empty():
			return {}
	for field in ["leftEffects", "rightEffects"]:
		if not authored.get(field) is Dictionary:
			return {}
	var card_id := "ally_%s_%s" % [NPC_ID, key if key in [
		"revelation", "tribulation", "destiny"] else "stage_" + key]
	var author_key: String = {"revelation": "revelation",
		"tribulation": "tribulationClimax",
		"destiny": "destinyClimax"}.get(key, "arcStages." + key)
	var registered: Dictionary = _content.find("generated_card", card_id)
	if registered.get("data") != authored \
			or registered.get("sourcePath") != "src/systems/StoryNetworkSystem.js" \
			or registered.get("sourceSha256") != RULE_SHA \
			or registered.get("authorPath") != "data/companions/arcs.json" \
			or registered.get("authorPointer") != "$.allyArc.%s.%s" % [NPC_ID, author_key] \
			or registered.get("authorSha256") != _content.source_sha256(MODULE) \
			or registered.get("producerGodot") != "res://scripts/noncombat_ally_arc_flow.gd::_project":
		return {}
	var semantic_key := String(authored.get("semanticKey", ""))
	if semantic_key.is_empty():
		semantic_key = "card:" + card_id if key in [
			"revelation", "tribulation", "destiny"] else "arc:%s:%s" % [NPC_ID, key]
	return {"id": card_id, "semanticKey": semantic_key, "title": authored.title,
		"description": authored.desc, "type": "ALLY_ARC", "realm": realm,
		"npcId": NPC_ID, "arcStage": key if key in STAGES.map(
			func(stage: Dictionary) -> String: return stage.name) else (
			"REVELATION" if key == "revelation" else "CLIMAX" if key == "tribulation" else "DESTINY"),
		"once": true, "weight": 0, "tags": ["ally_arc",
			"milestone" if key not in ["revelation", "tribulation", "destiny"] else key],
		"sceneImage": image_path,
		"choices": {"left": {"text": authored.leftText,
			"effects": authored.leftEffects.duplicate(true)},
			"right": {"text": authored.rightText,
				"effects": authored.rightEffects.duplicate(true)}}}

func _apply_attribute(state: Dictionary, key: String, raw: Variant) -> bool:
	if key not in ["cultivation", "daoHeart", "health", "fortune",
			"karmaGood", "karmaBad"] or not (raw is int or raw is float) \
			or float(raw) != float(int(raw)):
		last_error = "盟友选项包含未支持的效果"
		return false
	var amount := LegacyFragmentFlow.effective_delta(state, key, int(raw))
	var maximum := 100
	if key == "health":
		maximum = LegacyFragmentFlow.actual_max_health(state)
		if amount < 0 and int(state["attributes"].get("aura", 0)) > 0:
			var absorbed := mini(int(state["attributes"]["aura"]), -amount)
			state["attributes"]["aura"] = int(state["attributes"]["aura"]) - absorbed
			amount += absorbed
	elif key == "daoHeart":
		maximum = LegacyFragmentFlow.actual_max_dao_heart(state)
	elif key == "cultivation":
		var realm_doc: Variant = _content.read_module("config:realms")
		var value: Variant = realm_doc.get("realms", {}).get(
			String(state.get("realm", "qi")), {}).get(
				"cultivationThreshold") if realm_doc is Dictionary else null
		if not (value is int or value is float) or int(value) <= 0:
			return false
		maximum = int(value)
	state["attributes"][key] = clampi(int(state["attributes"].get(key, 0)) +
		amount, 0, maximum)
	return true

func _fnv32(value: String) -> int:
	var hash := 2166136261
	for index in value.length():
		hash = ((hash ^ value.unicode_at(index)) * 16777619) & 0xffffffff
	return hash
