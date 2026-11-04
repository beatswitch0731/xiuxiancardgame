extends RefCounted

const EncounterDirector = preload("res://scripts/noncombat_encounter_director.gd")

# Source-backed CardSystem normal-draw admission and base weights. The qi,
# foundation, golden and higher realm pools are consumed by Domain's runtime lane.
# Ledger-specific eligibility still requires its own parity evidence.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const CARD_SYSTEM_JS_SHA := "12f99d576b413313b36c9b6b2e3d0c23a56f9eff4793f0c9737c6dc5cb2e1c5f"
const FLOW_DIRECTOR_JS_SHA := "c62522bf280c6af7cb62e722c575ce6efe6b40ead5c3aa09a0be8bd1a7366b0d"
const NARRATIVE_LEDGER_JS_SHA := "485c6d61b335db1a418900a552d3b001aea66348b8ba02ef8b82111264c9e20a"
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const INIT_MODULES := ["cards:karma", "cards:karma_expansion", "cards:demonic_seductress",
	"cards:demon_path", "cards:interweave", "cards:post_ascension", "cards:rebirth",
	"cards:story_dialogue", "cards:world_atmosphere"]
const EXCLUDED_TYPES := ["DESTINY", "BOTTLENECK", "KARMA", "QUEST", "TUTORIAL",
	"PROLOGUE", "DEATH", "ENDING"]
const NARRATIVE_TYPES := ["STORY", "NPC_ENCOUNTER", "NPC_CROSS",
	"COMPANION_EVENT", "COMPANION_ARC", "MENTOR_ARC", "SEER_ARC",
	"ALLY_ARC", "FACTION_EVENT", "LOCATION", "EMERGENT",
	"SURFACING", "CHOICE_ECHO"]
const BUCKET_ORDER := ["current", "previous", "evergreen"]
const BUCKET_WEIGHTS := {"current": 72.0, "previous": 18.0, "evergreen": 10.0}
const PHASE_ORDER := ["CALM", "BUILDUP", "TENSION", "CLIMAX", "RESOLUTION"]
const PHASE_RATES := {"CALM": 8, "BUILDUP": 6, "TENSION": 5,
	"CLIMAX": 4, "RESOLUTION": 10}
const PHASE_SOURCE_WEIGHTS := {
	"CALM": {"normal": 70, "lightStory": 15, "shop": 10, "exploration": 5},
	"BUILDUP": {"normal": 45, "story": 20, "shop": 10,
		"exploration": 10, "combatLight": 15},
	"TENSION": {"normal": 25, "story": 15, "combat": 35, "challenge": 25},
	"CLIMAX": {"combat": 50, "story": 20, "challenge": 30},
	"RESOLUTION": {"normal": 35, "story": 35, "reward": 20, "shop": 10},
}
const MOOD_TAG_WEIGHTS := {
	"despair": {"risk": 1.5, "demon": 1.3, "combat": 0.7,
		"story": 1.4, "lightStory": 1.5},
	"inspired": {"combat": 1.3, "exploration": 1.4, "reward": 1.3, "risk": 1.2},
	"sinister": {"demon": 1.5, "risk": 1.3, "combat": 1.2, "story": 1.1},
	"cautious": {"shop": 1.4, "exploration": 1.3, "combat": 0.6,
		"story": 1.2, "lightStory": 1.3},
	"neutral": {},
}

var last_error := ""
var _content: RefCounted
var legacy_narrative_admission_replay := false

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()


func source_pins() -> Dictionary:
	var result := {}
	for module_id in ["cards:qi", "cards:foundation", "shops:treasures",
			"config:path_skills"] + INIT_MODULES:
		var sha: String = _content.source_sha256(module_id)
		if sha.length() != 64:
			last_error = "normal draw source unavailable: " + module_id
			return {}
		result[module_id] = sha
	return result


func legacy_source_pins() -> Dictionary:
	# The first N9q snapshot shape preceded passive settlement pins. It can be
	# replayed and upgraded only after its whole state passes strict comparison.
	var result := source_pins()
	result.erase("shops:treasures")
	result.erase("config:path_skills")
	return result


func source_card(state: Dictionary, card_id: String) -> Dictionary:
	last_error = ""
	for card_value in _catalog(state, true):
		var card: Dictionary = card_value
		if card.get("id") == card_id and card.get("type") not in EXCLUDED_TYPES:
			return card.duplicate(true)
	if last_error.is_empty():
		last_error = "normal card absent from source catalog"
	return {}


func select_source(state: Dictionary, phase: String, starvation: Dictionary,
		roll: float) -> String:
	if roll < 0.0 or roll >= 1.0:
		return ""
	var weights: Dictionary = PHASE_SOURCE_WEIGHTS.get(phase, {})
	if weights.is_empty():
		return ""
	var mood_weights: Dictionary = MOOD_TAG_WEIGHTS.get(mood(state), {})
	var adjusted := {}
	var total := 0.0
	for key in weights:
		var weight := float(weights[key]) * float(mood_weights.get(key, 1.0))
		var count := int(starvation.get(key, 0))
		if count >= 12:
			weight *= minf(3.0, 1.0 + float(count - 12) / 10.0)
		adjusted[key] = weight
		total += weight
	if total <= 0.0:
		return ""
	var cursor := roll * total
	for key in adjusted:
		cursor -= float(adjusted[key])
		if cursor <= 0.0:
			return String(key)
	return String(adjusted.keys().back())


func preferred_tags_for(source: String) -> Array:
	match source:
		"exploration": return ["exploration", "discovery"]
		"combat", "combatLight": return ["combat", "enemy", "danger"]
		"challenge": return ["challenge", "risk", "trial"]
		"reward": return ["reward", "fortune", "treasure"]
	return []


func buckets(state: Dictionary) -> Dictionary:
	last_error = ""
	var result := {"current": [], "previous": [], "evergreen": []}
	var catalog: Array = _catalog(state)
	if not last_error.is_empty():
		return {}
	var played: Array = state.get("cardsPlayed", [])
	var recent: Array = played.slice(maxi(0, played.size() - 8))
	for card_value in catalog:
		var card: Dictionary = card_value
		var bucket := bucket_for(card, state)
		if not bucket.is_empty() and eligible(card, state, recent):
			result[bucket].append({"id": card["id"], "baseWeight": base_weight(card, state)})
	return result


func pick(state: Dictionary, bucket_roll: float, card_roll: float,
		preferred_tags: Array = []) -> String:
	if bucket_roll < 0.0 or bucket_roll >= 1.0 or card_roll < 0.0 or card_roll >= 1.0:
		return ""
	var available: Dictionary = buckets(state)
	if available.is_empty():
		return ""
	var bucket_total := 0.0
	for name in BUCKET_ORDER:
		if not available[name].is_empty():
			bucket_total += float(BUCKET_WEIGHTS[name])
	if bucket_total <= 0.0:
		return ""
	var bucket_cursor := bucket_roll * bucket_total
	var chosen_bucket := ""
	for name in BUCKET_ORDER:
		if available[name].is_empty():
			continue
		bucket_cursor -= float(BUCKET_WEIGHTS[name])
		if bucket_cursor < 0.0:
			chosen_bucket = name
			break
	if chosen_bucket.is_empty():
		return ""
	var by_id := {}
	for card_value in _catalog(state):
		var card: Dictionary = card_value
		by_id[card["id"]] = card
	var weighted: Array = []
	var total := 0.0
	var mood_weights: Dictionary = MOOD_TAG_WEIGHTS.get(mood(state), {})
	for row in available[chosen_bucket]:
		var card: Dictionary = by_id.get(row["id"], {})
		var tags: Array = card.get("tags", [])
		var weight := float(row["baseWeight"])
		for tag in mood_weights:
			if tags.has(tag):
				weight *= float(mood_weights[tag])
		for tag in preferred_tags:
			if tags.has(tag):
				weight *= 2.0
				break
		if weight <= 0.0:
			continue
		total += weight
		weighted.append({"id": row["id"], "weight": weight})
	if total <= 0.0:
		return ""
	var card_cursor := card_roll * total
	for row in weighted:
		card_cursor -= float(row["weight"])
		if card_cursor < 0.0:
			return String(row["id"])
	return String(weighted.back()["id"])


func phase_cursor_after(draw_count: int) -> Dictionary:
	if draw_count < 0:
		return {}
	var cycle_length := 0
	for phase in PHASE_ORDER:
		cycle_length += ceili(100.0 / float(PHASE_RATES[phase]))
	var remaining := draw_count % cycle_length
	for phase in PHASE_ORDER:
		var span := ceili(100.0 / float(PHASE_RATES[phase]))
		if remaining >= span:
			remaining -= span
			continue
		return {"phase": phase, "phaseProgress": remaining * int(PHASE_RATES[phase]),
			"cardCount": draw_count}
	return {}


func source_at_zero_roll(phase: String) -> String:
	# This only describes FlowDirector's phase source lottery. The actual
	# scheduler must first arbitrate P100..P15 and maintain starvation counters.
	var weights: Dictionary = PHASE_SOURCE_WEIGHTS.get(phase, {})
	if weights.is_empty():
		return ""
	for source in weights:
		if float(weights[source]) > 0.0:
			return String(source)
	return ""


func mood(state: Dictionary) -> String:
	var attributes: Dictionary = state.get("attributes", {})
	var max_health := maxf(1.0, float(LegacyFragmentFlow.actual_max_health(state)))
	var max_dao := maxf(1.0, float(LegacyFragmentFlow.actual_max_dao_heart(state)))
	var health_ratio := clampf(float(attributes.get("health", 100)) / max_health, 0.0, 1.0)
	var dao_ratio := clampf(float(attributes.get("daoHeart", 50)) / max_dao, 0.0, 1.0)
	if dao_ratio <= 1.0 / 3.0:
		return "despair"
	if health_ratio > 0.8 and float(attributes.get("fortune", 50)) > 70.0:
		return "inspired"
	if float(attributes.get("karmaBad", 0)) > 60.0:
		return "sinister"
	if health_ratio <= 1.0 / 3.0:
		return "cautious"
	return "neutral"


func bucket_for(card: Dictionary, state: Dictionary) -> String:
	var current := String(state.get("realm", "qi"))
	var index := REALMS.find(current)
	if index < 0:
		return ""
	var card_realms := _card_realms(card)
	var tags: Array = card.get("tags", [])
	if index >= 1 and tags.has("basic") and (card_realms.has("qi") or tags.has("qi")):
		return ""
	if card_realms.has(current):
		return "current"
	if card.get("evergreen") == true:
		for realm in card_realms:
			var card_index := REALMS.find(realm)
			if card_index >= 0 and card_index < index:
				return "evergreen"
	if index > 0 and card_realms.has(REALMS[index - 1]):
		return "previous"
	return ""


func eligible(card: Dictionary, state: Dictionary, recent: Array) -> bool:
	if not card.get("id") is String or String(card["id"]).is_empty() \
			or card.get("type") in EXCLUDED_TYPES or bucket_for(card, state).is_empty() \
			or recent.has(card["id"]):
		return false
	var weight: Variant = card.get("weight", 5)
	if not _number(weight) or float(weight) <= 0.0:
		return false
	if card.get("id") == "q_cave" and state.has("encounterCadence"):
		var qi_source: Variant = _content.read_module("cards:qi")
		var nodes: Variant = qi_source.get("dungeons", {}).get(
			"ancientCave", {}).get("nodes", []) if qi_source is Dictionary else []
		if not nodes is Array or nodes.size() != 3 \
				or not EncounterDirector.new(_content).can_start_authored_sequence(
					state, 1 + nodes.size()):
			return false
	var flags: Dictionary = state.get("flags", {})
	var upper_active := bool(flags.get("post_ascension_active", false))
	if (card.get("worldLayer") == "upper_realm") != upper_active:
		return false
	# Realm-boss and ordinary encounter contracts have separate owners.
	if card.has("encounterId"):
		return false
	var paths := _paths(card)
	if not paths.is_empty() and not paths.has(state.get("path")):
		return false
	if card.has("requiredCompanion") and not state.get("resources", {}).get(
			"companions", []).has(card["requiredCompanion"]):
		return false
	if card.get("once") == true and state.get("cardsPlayed", []).has(card["id"]):
		return false
	if not _narrative_eligible(card, state):
		return false
	var required: Variant = card.get("requiresFlags")
	if required is Dictionary:
		for key in required:
			if required[key] == null:
				if not flags.has(key):
					return false
			elif flags.get(key) != required[key]:
				return false
	var any_flags: Variant = card.get("requiresAnyFlags")
	if any_flags is Array and not any_flags.is_empty():
		var found := false
		for key in any_flags:
			if bool(flags.get(key, false)):
				found = true
				break
		if not found:
			return false
	var forbidden: Variant = card.get("forbiddenFlags")
	if forbidden is Dictionary:
		for key in forbidden:
			if forbidden[key] == null:
				if bool(flags.get(key, false)):
					return false
			elif flags.get(key) == forbidden[key]:
				return false
	var requirements: Variant = card.get("requirements")
	if requirements is Dictionary:
		if requirements.has("minLifeCount") and int(state.get("lifeCount", 0)) < int(
				requirements["minLifeCount"]):
			return false
		if requirements.has("minTurn") and int(state.get("turn", 0)) < maxi(0,
				int(requirements["minTurn"])):
			return false
		var memories: Dictionary = state.get("unlocks", {}).get("legacy", {}).get(
			"pathMemories", {})
		if requirements.get("differentPaths"):
			var different := false
			for path in memories:
				if path != state.get("path") and float(memories[path]) > 0.0:
					different = true
			if not different:
				return false
		if requirements.has("pastPath") and float(memories.get(
				requirements["pastPath"], 0)) <= 0.0:
			return false
	return true


func _narrative_eligible(card: Dictionary, state: Dictionary) -> bool:
	if legacy_narrative_admission_replay:
		return true
	var npc_ids: Array = []
	for key in ["npcId", "compId"]:
		if card.get(key) is String and not String(card[key]).is_empty():
			npc_ids.append(card[key])
	for npc_id in card.get("npcIds", []):
		if npc_id is String and not npc_ids.has(npc_id):
			npc_ids.append(npc_id)
	if card.get("manifestation", "PHYSICAL") == "PHYSICAL":
		var world: Variant = state.get("worldContinuityState")
		var npcs: Dictionary = world.get("npcs", {}) if world is Dictionary else {}
		for npc_id in npc_ids:
			if state.get("deadNpcs", []).has(npc_id):
				return false
			var lifecycle: Variant = npcs.get(npc_id)
			if world is Dictionary and (world.get("version") != 1 \
					or world.get("lifeId") != state.get("lifeCount", 0) \
					or not lifecycle is Dictionary \
					or lifecycle.get("npcId") != npc_id \
					or lifecycle.get("lifeId") != world.get("lifeId") \
					or lifecycle.get("lifecycle") != "ACTIVE" \
					or lifecycle.get("manifestation") != "PHYSICAL"):
				return false
	var required: Variant = card.get("requiresResolvedSemanticKeys")
	var repeat_policy: Variant = card.get("repeatPolicy")
	var repeat_mode := String(repeat_policy.get("mode", "")) if repeat_policy is Dictionary \
		else String(repeat_policy) if repeat_policy is String else ""
	var semantic := String(card.get("semanticKey", "card:" + String(card.get("id", "")))).strip_edges()
	var needs_resolved := required != null or card.has("semanticKey") \
		or repeat_mode == "once"
	var resolved := _resolved_semantic_keys(state) if needs_resolved else {}
	if required != null:
		if not required is Array or required.is_empty():
			return false
		for key in required:
			if not key is String or String(key).strip_edges().is_empty() \
					or not resolved.has(String(key).strip_edges()):
				return false
	if (card.get("once") == true or repeat_mode == "once") \
			and not semantic.is_empty() and resolved.has(semantic):
		return false
	if repeat_mode == "cooldown" or repeat_mode.is_empty() \
			and card.get("type") in NARRATIVE_TYPES and card.get("once") != true:
		var cooldown := maxi(1, int(repeat_policy.get("cooldownTurns",
			card.get("cooldownTurns", 12)))) if repeat_policy is Dictionary else 12
		var history: Array = state.get("replayHistory", state.get("choiceHistory", []))
		for index in range(history.size() - 1, -1, -1):
			var record: Variant = history[index]
			if record is Dictionary and _semantic_for(String(record.get("cardId", ""))) == semantic:
				if int(state.get("runClock", {}).get("decisionIndex", 0)) - int(
						record.get("decisionIndex", 0)) < cooldown:
					return false
				break
	return true


func _resolved_semantic_keys(state: Dictionary) -> Dictionary:
	var resolved := {}
	for value in state.get("cardsPlayed", []):
		if not value is String:
			continue
		resolved[_semantic_for(String(value))] = true
	return resolved


func _semantic_for(card_id: String) -> String:
	var source: Dictionary = _content.find("card", card_id)
	var authored: Variant = source.get("data")
	if authored is Dictionary and authored.get("semanticKey") is String \
			and not String(authored["semanticKey"]).strip_edges().is_empty():
		return String(authored["semanticKey"]).strip_edges()
	var stage_marker := card_id.rfind("_stage_")
	if stage_marker > 0 and (card_id.begins_with("arc_") \
			or card_id.begins_with("mentor_") \
			or card_id.begins_with("seer_") \
			or card_id.begins_with("ally_")):
		var owner := card_id.substr(0, stage_marker)
		if card_id.begins_with("arc_"):
			owner = owner.trim_prefix("arc_")
		else:
			owner = owner.substr(owner.find("_") + 1)
		return "arc:%s:%s" % [owner, card_id.substr(stage_marker + 7)]
	return "card:" + card_id


func base_weight(card: Dictionary, state: Dictionary) -> float:
	var weight := float(card.get("weight", 5))
	if weight <= 0.0:
		return 0.0
	if _paths(card).has(state.get("path")):
		weight *= 1.5
	var tags: Array = card.get("tags", [])
	if float(state.get("attributes", {}).get("fortune", 0)) > 70.0 \
			and card.get("tags") is Array and not tags.has("risk"):
		weight += 2.0
	if float(state.get("attributes", {}).get("karmaBad", 0)) > 50.0 and tags.has("demon"):
		weight *= 1.3
	return weight


func _catalog(state: Dictionary, source_lookup_only: bool = false) -> Array:
	var realm := String(state.get("realm", "qi"))
	if realm not in REALMS:
		last_error = "normal draw catalog realm is unknown"
		return []
	var realm_index := REALMS.find(realm)
	if realm_index < 0:
		last_error = "unknown realm"
		return []
	var by_id := {}
	# CardSystem.init preloads qi and foundation, then karma and extra modules.
	# Its draw API also loads every realm up to the current one.
	for index in range(maxi(1, realm_index) + 1):
		var module_id: String = "cards:" + String(REALMS[index])
		var document: Variant = _content.read_module(module_id)
		if not document is Dictionary:
			last_error = "missing source module " + module_id
			return []
		for card in document.get("cards", []):
			if card is Dictionary and card.get("id") is String:
				by_id[card["id"]] = card
		for card in document.get("dungeonCards", {}).values():
			if card is Dictionary and card.get("id") is String:
				by_id[card["id"]] = card
		for card in document.get("karmaCards", {}).values():
			if card is Dictionary and card.get("id") is String:
				by_id[card["id"]] = card
	for module_id in INIT_MODULES:
		var document: Variant = _content.read_module(module_id)
		if not document is Dictionary:
			last_error = "missing source module " + module_id
			return []
		for card in document.get("cards", []):
			if card is Dictionary and card.get("id") is String:
				by_id[card["id"]] = card
		for card in document.get("karmaCards", {}).values():
			if card is Dictionary and card.get("id") is String:
				by_id[card["id"]] = card
	# Source _getNormalDrawCards starts with current-realm JSON insertion order,
	# then fills unseen IDs from CardSystem's cache.
	var ordered: Array = []
	var current_doc: Dictionary = _content.read_module("cards:" + realm)
	for card in current_doc.get("cards", []):
		if card is Dictionary and card.get("id") is String and by_id.has(card["id"]):
			ordered.append(by_id[card["id"]])
			by_id.erase(card["id"])
	for card in by_id.values():
		if card is Dictionary and card.has("realm"):
			ordered.append(card)
	return ordered


func _card_realms(card: Dictionary) -> Array:
	var found: Array = []
	for value in String(card.get("realm", "qi")).split(","):
		var realm := value.strip_edges()
		if not realm.is_empty():
			found.append(realm)
	return found


func _paths(card: Dictionary) -> Array:
	var declared: Variant = card.get("paths", card.get("pathRestriction", card.get("path")))
	var values: Array = declared if declared is Array else [declared]
	var found: Array = []
	for value in values:
		if value is String and not String(value).strip_edges().is_empty() \
				and not found.has(String(value).strip_edges()):
			found.append(String(value).strip_edges())
	return found


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
