extends RefCounted

# Source death choice -> GameStateManager.reset(true) -> unresolved rebirth boon.
# This builds a new-life candidate; the domain owns the sole durable commit.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const WorldPulse = preload("res://scripts/noncombat_world_pulse.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")
const REBIRTH_SOURCE := "data/cards/rebirth.json"
const BONUS_KEYS := ["startCultivation", "startSpiritStone", "maxLifespan",
	"daoHeart", "fortune", "maxHp", "karmaGood", "karmaBad"]
const CROSS_LIFE_CLEAR_FLAGS := ["game_ended", "post_ascension_active",
	"ascension_continued_this_life", "post_ascension_next_card"]

var last_error := ""
var _content: RefCounted
var _deck: RefCounted
var _treasure: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()
	_deck = DeckAcquisition.new(_content)
	_treasure = TreasureAcquisition.new(_content)


func boon_card(state: Dictionary) -> Dictionary:
	last_error = ""
	if state.get("phase") not in ["REBIRTH_PENDING", "CAMP_TARGET_PENDING"] \
			or state.get("lifePhase") != (
				"LEGACY_CHOICE" if state.get("path") == null else "ALIVE") \
			or state.get("currentCardId") != "rebirth_boon":
		return {}
	var row: Dictionary = _content.find("card", "rebirth_boon")
	var card: Variant = row.get("data")
	var art: Dictionary = _content.card_scene_image_status("rebirth_boon")
	if row.get("sourcePath") != REBIRTH_SOURCE or not card is Dictionary \
			or not card.get("choices") is Dictionary \
			or not art.get("textureLoadable") == true \
			or art.get("sceneImage") != card.get("sceneImage") \
			or state.get("rebirthSourceSha") != _content.source_sha256("cards:rebirth"):
		last_error = "rebirth source or original art unavailable"
		return {}
	return card.duplicate(true)


func new_life(terminal: Dictionary, death_card: Dictionary,
		direction: String, slot_id: String, inheritance_version: int = 5) -> Dictionary:
	last_error = ""
	if inheritance_version not in [0, 1, 2, 3, 4, 5]:
		last_error = "unsupported rebirth inheritance version"
		return {}
	if terminal.get("phase") != "DEATH_PENDING" \
			or terminal.get("lifePhase") != "DYING_NARRATIVE" \
			or terminal.get("dead") != true \
			or terminal.get("deathCauseId") != "death_dao_collapse" \
			or terminal.get("currentCardId") != death_card.get("id") \
			or direction not in ["left", "right"] \
			or not terminal.get("lifeJournal", []) is Array:
		last_error = "unsupported death transition"
		return {}
	var choice: Variant = death_card.get("choices", {}).get(direction)
	var bonus_text := String(choice.get("effects", {}).get("reincarnation_bonus", "")) \
		if choice is Dictionary else ""
	var parts := bonus_text.split(" ", false)
	if parts.size() != 2 or not String(parts[1]).is_valid_int() \
			or not String(parts[1]).begins_with("+") \
			or parts[0] not in ["daoHeart", "cultivation", "fortune", "karmaGood"]:
		last_error = "unsupported source legacy reward"
		return {}
	var old_id := String(terminal.get("runClock", {}).get("lifeId", ""))
	var prefix := slot_id + ":life:"
	var suffix := old_id.trim_prefix(prefix)
	if not old_id.begins_with(prefix) or not suffix.is_valid_int() \
			or suffix != str(int(suffix)) \
			or int(terminal.get("lifeCount", -1)) != int(suffix):
		last_error = "old life identity invalid"
		return {}
	var next_life := int(suffix) + 1
	var bonuses: Dictionary = terminal.get("legacyBonuses", {}).duplicate(true)
	for key in bonuses:
		if key not in BONUS_KEYS or not bonuses[key] is int and not bonuses[key] is float:
			last_error = "old legacy bonus invalid"
			return {}
	if int(terminal.get("turn", 0)) > 30:
		bonuses["startSpiritStone"] = int(bonuses.get("startSpiritStone", 0)) \
			+ 5 + mini(next_life, 5) * 2
	if inheritance_version >= 3:
		var old_realm := String(terminal.get("realm", "qi"))
		if old_realm != "qi":
			bonuses["startCultivation"] = int(bonuses.get("startCultivation", 0)) \
				+ 3 + (2 if next_life > 1 else 0)
		if old_realm in ["foundation", "golden"]:
			bonuses["maxLifespan"] = int(bonuses.get("maxLifespan", 0)) \
				+ 5 + next_life
		elif old_realm in ["nascent", "deity"]:
			bonuses["maxLifespan"] = int(bonuses.get("maxLifespan", 0)) \
				+ 10 + next_life * 2
	var mapped_key := "startCultivation" if parts[0] == "cultivation" else parts[0]
	bonuses[mapped_key] = int(bonuses.get(mapped_key, 0)) + int(parts[1])
	var max_health := 6 + int(bonuses.get("maxHp", 0))
	var max_dao := 3 + int(bonuses.get("daoHeart", 0))
	if max_health < 1 or max_dao < 1:
		last_error = "legacy health cap invalid"
		return {}
	var preserved_seeds: Array = []
	for source_seed in terminal.get("karmaSeeds", []):
		if not source_seed is Dictionary:
			return {}
		if source_seed.get("seedType") in ["bloodline", "fate"]:
			var seed: Dictionary = source_seed.duplicate(true)
			seed["delay"] = roundi(int(seed.get("delay", 5)) * 1.5) + 5
			preserved_seeds.append(seed)
	var journal: Array = terminal.get("lifeJournal", []).duplicate(true)
	var closure: Dictionary = terminal.duplicate(true)
	closure.erase("lifeJournal")
	journal.append({"terminalState": closure, "deathDirection": direction})
	var path_memories: Dictionary = terminal.get("legacyPathMemories", {}).duplicate(true)
	var old_path := String(terminal.get("path", ""))
	if not old_path.is_empty():
		var memory_gain := 1
		if inheritance_version >= 4:
			var lineage_tree = terminal.get("rebirthTree",
				LineageFlow.new(_content).initial_tree())
			memory_gain += maxi(0, int(LineageFlow.new(_content).effect_value(
					lineage_tree, "pathMemoryGain")))
		path_memories[old_path] = mini(5, int(path_memories.get(old_path, 0))
			+ memory_gain)
	var legacy_archive: Dictionary = terminal.get("legacyArchive", {}).duplicate(true)
	var old_knowledge: Variant = terminal.get("knowledge", {})
	var old_clues: Variant = terminal.get("clues", [])
	if not old_knowledge is Dictionary or not old_clues is Array:
		last_error = "previous-life memory invalid"
		return {}
	var inherited_clues: Array = []
	var seen_clues := {}
	for old_clue in old_clues:
		if not old_clue is Dictionary or not old_clue.get("id") is String \
				or String(old_clue["id"]).is_empty():
			last_error = "previous-life clue invalid"
			return {}
		var clue_id := String(old_clue["id"])
		if seen_clues.has(clue_id):
			continue
		seen_clues[clue_id] = true
		inherited_clues.append({"id": clue_id, "source": "legacy",
			"turn": 0, "life": next_life})
	for old_hint_clue in terminal.get("noncombatFlow", {}).get("hintClues", []):
		if not old_hint_clue is Dictionary or not old_hint_clue.get("id") is String \
				or String(old_hint_clue["id"]).is_empty():
			last_error = "previous-life hint clue invalid"
			return {}
		var clue_id := String(old_hint_clue["id"])
		if seen_clues.has(clue_id):
			continue
		seen_clues[clue_id] = true
		inherited_clues.append({"id": clue_id, "source": "legacy",
			"turn": 0, "life": next_life})
	var run_legacy := {"lifeCount": next_life, "focusedSetId": null,
		"activeSetIds": [], "inheritedSetId": null,
		"pendingInheritanceChoice": null, "ordinaryMissStreak": 0,
		"pendingBossFragmentReward": null, "claimedEncounterInstanceIds": []}
	var result := {
		"active": true, "phase": "REBIRTH_PENDING", "path": null,
		"playerName": terminal.get("playerName", "叶凌云"), "realm": "qi",
		"turn": 0, "cardsPlayed": [], "tutorialCompleted": true,
		"currentCardId": "rebirth_boon", "maxHealth": max_health,
		"maxDaoHeart": max_dao, "choiceHistory": [], "replayHistory": [],
		"recentCardTags": [], "runClock": {"version": 1,
			"lifeId": prefix + str(next_life), "decisionIndex": 0,
			"decisionClockMigrationSource": null, "receipts": {}},
		"decisionCheckpoint": {"version": 1, "cardId": "rebirth_boon",
			"sourceCardId": death_card["id"], "turn": 0, "decisionIndex": 0},
		"attributes": {"cultivation": int(bonuses.get("startCultivation", 0)),
			"daoHeart": maxi(0, max_dao - 1),
			"karmaGood": int(bonuses.get("karmaGood", 0)),
			"karmaBad": int(bonuses.get("karmaBad", 0)),
			"fortune": 50 + int(bonuses.get("fortune", 0)),
			"health": maxi(1, max_health - 1), "aura": 0, "tianji": 0},
		"resources": {"spiritStone": 10 + int(bonuses.get("startSpiritStone", 0)),
			"lifespan": 80 + int(bonuses.get("maxLifespan", 0)),
			"pills": {}, "treasures": [], "companions": []},
		"dead": false, "deadReason": "", "deathCauseId": "",
		"lifePhase": "LEGACY_CHOICE", "lifeCount": next_life,
		"legacyBonuses": bonuses, "legacyArchive": legacy_archive,
		"legacyRunState": run_legacy, "legacyPathMemories": path_memories,
		"lifeJournal": journal, "flags": {},
		"knowledge": old_knowledge.duplicate(true), "clues": inherited_clues,
		"karmaSeeds": preserved_seeds, "pendingKarmaSeeds": preserved_seeds.duplicate(true),
		"deck": [], "deckOperations": [], "skillAcquisitions": {},
		"equipment": {"weapon": null, "armor": null,
			"accessory": null, "artifact": null},
		"treasureInstances": {}, "treasureInventory": [],
		"treasureCommandReceipts": {}, "treasureCooldowns": {},
		"itemInventory": {}, "currentLocation": "宗门",
		"visitedLocations": ["宗门"], "locationStates": {},
		"rebirthSourceSha": _content.source_sha256("cards:rebirth")
	}
	if terminal.has("companionCosmetics"):
		result["companionCosmetics"] = terminal["companionCosmetics"].duplicate(true)
	# The archive survives death. Keep its rule identity and RNG cursor with it;
	# otherwise the first new-life choice reinitializes and erases the archive.
	if terminal.has("legacyFragmentVersion"):
		for key in ["legacyFragmentVersion", "legacyRuleSourceSha",
				"legacyFragmentActivationIndex", "legacyRngState"]:
			if not terminal.has(key):
				last_error = "previous-life legacy cursor incomplete"
				return {}
			result[key] = terminal[key].duplicate(true) if terminal[key] is Dictionary \
				else terminal[key]
	if inheritance_version >= 1 and not _inherit_factions_and_flags(terminal, result):
		return {}
	if inheritance_version >= 2:
		var quest_state: Dictionary = _carry_closed_quests(terminal)
		if quest_state.is_empty():
			return {}
		result["questState"] = quest_state
		result["rebirthInheritanceVersion"] = 2
	if inheritance_version >= 3:
		var retention := 0.5
		if inheritance_version >= 4:
			var lineage := LineageFlow.new(_content)
			var archive: Dictionary = lineage.archive_life(terminal,
				inheritance_version >= 5)
			if archive.is_empty():
				last_error = lineage.last_error
				return {}
			result.merge(archive, true)
			result["rebirthTreeActions"] = []
			retention = minf(0.7, 0.5 + maxf(0.0, lineage.effect_value(
				result.rebirthTree, "affectionRetention")))
		if not _inherit_npc_affection(terminal, result, retention):
			return {}
		result["rebirthInheritanceVersion"] = inheritance_version
	var world: Dictionary = WorldContinuity.initial(_content, next_life)
	if world.is_empty():
		last_error = "new-life NPC source unavailable"
		return {}
	result["worldContinuityState"] = world["state"]
	result["worldContinuityActivationIndex"] = 0
	result["worldContinuitySourceSha"] = world["sourceSha"]
	result["worldPulseState"] = WorldPulse.initial(result)
	if inheritance_version >= 1:
		var faction_events := FactionEvents.new(_content)
		result["factionEventState"] = faction_events.marker(0)
		if result["factionEventState"].is_empty():
			last_error = "new-life faction source unavailable"
			return {}
	if String(result["rebirthSourceSha"]).length() != 64 \
			or boon_card(result).is_empty():
		last_error = "rebirth boon source unavailable"
		return {}
	return result


func voluntary_new_life(pending: Dictionary, warning_card: Dictionary,
		slot_id: String, inheritance_version: int = 5) -> Dictionary:
	if pending.get("phase") != "WARNING_PENDING" \
			or pending.get("lifePhase", "ALIVE") != "ALIVE" \
			or pending.get("dead") == true \
			or pending.get("pendingRealmGateCard", {}).get("id") != RealmGateFlow.TRIBULATION_CARD_ID \
			or warning_card.get("id") != "_warning_" + RealmGateFlow.TRIBULATION_CARD_ID \
			or warning_card.get("choices", {}).get("right", {}).get("effects", {}).get("reincarnate") != true \
			or warning_card != RealmGateFlow.new(_content).warning_card(pending):
		return {}
	var handoff: Dictionary = pending.duplicate(true)
	handoff["phase"] = "DEATH_PENDING"
	handoff["lifePhase"] = "DYING_NARRATIVE"
	handoff["dead"] = true
	handoff["deathCauseId"] = "death_dao_collapse"
	if not handoff.has("lifeCount"):
		handoff["lifeCount"] = 0
	handoff["currentCardId"] = warning_card.id
	var next: Dictionary = new_life(handoff, warning_card, "right", slot_id,
		inheritance_version)
	if next.is_empty():
		return {}
	var journal: Array = next["lifeJournal"]
	journal.back()["terminalState"] = pending.duplicate(true)
	journal.back()["voluntaryReincarnation"] = true
	next["decisionCheckpoint"]["sourceCardId"] = warning_card.id
	return next


func ending_new_life(pending: Dictionary, ending_card: Dictionary,
		direction: String, slot_id: String, inheritance_version: int = 5) -> Dictionary:
	if pending.get("phase") != "ENDING_PENDING" \
			or pending.get("lifePhase") != "EPILOGUE" \
			or ending_card.get("id") != "ending_" + String(pending.get("endingId", "")) \
			or ending_card != RealmGateFlow.new(_content).ending_card(pending) \
			or ending_card.get("choices", {}).get(direction, {}).get("effects", {}).get("reincarnate") != true:
		return {}
	var handoff: Dictionary = pending.duplicate(true)
	handoff["phase"] = "DEATH_PENDING"
	handoff["lifePhase"] = "DYING_NARRATIVE"
	handoff["dead"] = true
	handoff["deathCauseId"] = "death_dao_collapse"
	if not handoff.has("lifeCount"):
		handoff["lifeCount"] = 0
	var synthetic_card: Dictionary = ending_card.duplicate(true)
	if not synthetic_card["choices"][direction]["effects"].has("reincarnation_bonus"):
		synthetic_card["choices"][direction]["effects"]["reincarnation_bonus"] = "daoHeart +0"
	var next: Dictionary = new_life(handoff, synthetic_card, direction, slot_id,
		inheritance_version)
	if next.is_empty():
		return {}
	var journal: Array = next["lifeJournal"]
	journal.back()["terminalState"] = pending.duplicate(true)
	journal.back()["endingReincarnation"] = true
	return next


func upper_new_life(pending: Dictionary, upper_card: Dictionary,
		direction: String, slot_id: String, inheritance_version: int = 5) -> Dictionary:
	if pending.get("phase") not in ["UPPER_REALM_PENDING", "NORMAL_PENDING"] \
			or pending.get("lifePhase") != "ALIVE" \
			or pending.get("flags", {}).get("post_ascension_active") != true \
			or pending.get("currentCardId") != upper_card.get("id") \
			or upper_card != (RealmGateFlow.new(_content).upper_card(pending) \
				if pending.get("phase") == "UPPER_REALM_PENDING" else \
				RealmGateFlow.new(_content)._upper_source_card(String(upper_card.get("id", "")))) \
			or upper_card.get("choices", {}).get(direction, {}).get("effects", {}).get("reincarnate") != true:
		return {}
	var handoff: Dictionary = pending.duplicate(true)
	handoff["phase"] = "DEATH_PENDING"
	handoff["lifePhase"] = "DYING_NARRATIVE"
	handoff["dead"] = true
	handoff["deathCauseId"] = "death_dao_collapse"
	if not handoff.has("lifeCount"):
		handoff["lifeCount"] = 0
	var synthetic_card: Dictionary = upper_card.duplicate(true)
	if not synthetic_card["choices"][direction]["effects"].has("reincarnation_bonus"):
		synthetic_card["choices"][direction]["effects"]["reincarnation_bonus"] = "daoHeart +0"
	var next: Dictionary = new_life(handoff, synthetic_card, direction, slot_id,
		inheritance_version)
	if next.is_empty():
		return {}
	var journal: Array = next["lifeJournal"]
	journal.back()["terminalState"] = pending.duplicate(true)
	journal.back()["upperReincarnation"] = true
	return next


func _inherit_npc_affection(terminal: Dictionary, result: Dictionary,
		retention: float = 0.5) -> bool:
	var npc_source: Variant = _content.read_module("npcs:core")
	var companion_source: Variant = _content.read_module("companions:events")
	var old_legacy: Variant = terminal.get("legacyNpcAffections", {})
	var old_current: Variant = terminal.get("npcAffection", {})
	var old_schedule: Variant = terminal.get("npcEncounterScheduling", {})
	if not npc_source is Dictionary or not npc_source.get("npcs") is Array \
			or not companion_source is Dictionary \
			or not companion_source.get("companions") is Array \
			or not old_legacy is Dictionary or not old_current is Dictionary \
			or not old_schedule is Dictionary \
			or not old_schedule.get("affections", {}) is Dictionary:
		last_error = "previous-life NPC affection source or state invalid"
		return false
	var companion_starts := {}
	for companion in companion_source["companions"]:
		if not companion is Dictionary or not companion.get("id") is String \
				or not companion.get("startAffection", 0) is int \
					and not companion.get("startAffection", 0) is float:
			last_error = "companion affection source invalid"
			return false
		companion_starts[companion["id"]] = float(companion.get("startAffection", 0))
	var legacy: Dictionary = old_legacy.duplicate(true)
	for npc_id in legacy:
		if not legacy[npc_id] is int and not legacy[npc_id] is float:
			last_error = "previous-life NPC affection legacy invalid"
			return false
	var current := {}
	for npc in npc_source["npcs"]:
		if not npc is Dictionary or not npc.get("id") is String \
				or not npc.get("startAffection", 0) is int \
					and not npc.get("startAffection", 0) is float:
			last_error = "NPC affection source invalid"
			return false
		var npc_id: String = npc["id"]
		var base: float = float(npc.get("startAffection", 0))
		var previous: float = maxf(base, float(companion_starts.get(npc_id, base)))
		if old_current.has(npc_id):
			if not old_current[npc_id] is int and not old_current[npc_id] is float:
				last_error = "previous-life NPC affection invalid"
				return false
			previous = float(old_current[npc_id])
		elif npc_id == "bai_ren" and old_schedule.get("affections", {}).has(npc_id):
			var scheduled: Variant = old_schedule["affections"][npc_id]
			if not scheduled is int and not scheduled is float:
				last_error = "previous-life scheduled NPC affection invalid"
				return false
			previous = float(scheduled)
			# Old Godot schedules started at zero; the browser companion loader
			# starts Bai Ren at ten until an encounter actually changes him.
			if previous == 0.0 and old_schedule.get("memories", {}).get(
					npc_id, []).is_empty():
				previous = maxf(previous, float(companion_starts.get(npc_id, base)))
		legacy[npc_id] = maxf(float(legacy.get(npc_id, 0)), previous * retention)
		current[npc_id] = clampi(_js_round(float(legacy[npc_id])), -50, 100) \
			if float(legacy[npc_id]) > 0.0 else int(base)
	result["legacyNpcAffections"] = legacy
	result["npcAffection"] = current
	return true


func _inherit_factions_and_flags(terminal: Dictionary, result: Dictionary) -> bool:
	var source: Variant = _content.read_module("world:factions")
	var faction: Dictionary = _source_faction_progress(source) if source is Dictionary else {}
	var old_legacy: Variant = terminal.get("legacyFactionReputations", {})
	var old_progress: Variant = terminal.get("factionProgress", {})
	var old_completed: Variant = terminal.get("legacyCompletedQuests", [])
	var old_flags: Variant = terminal.get("flags", {})
	if faction.is_empty() or not old_legacy is Dictionary \
			or not old_progress is Dictionary or not old_completed is Array \
			or not old_flags is Dictionary:
		last_error = "previous-life faction or flag state invalid"
		return false
	var previous_reputations: Variant = old_progress.get("reputations", {})
	if not previous_reputations is Dictionary:
		last_error = "previous-life faction reputation invalid"
		return false
	var legacy: Dictionary = old_legacy.duplicate(true)
	for id in legacy:
		if not legacy[id] is int and not legacy[id] is float:
			last_error = "previous-life reputation legacy invalid"
			return false
	for id in faction["reputations"]:
		var current: int = int(faction["reputations"][id])
		if previous_reputations.has(id):
			if not previous_reputations[id] is int \
					and not previous_reputations[id] is float:
				last_error = "previous-life reputation invalid"
				return false
			current = clampi(int(previous_reputations[id]), -100, 100)
		var previous: int = int(legacy.get(id, 0))
		var retained := _js_round(float(current) * 0.6)
		legacy[id] = maxi(previous, retained) if retained >= 0 \
			else mini(previous, retained)
		var inherited: int = int(legacy[id])
		var base: int = inherited if inherited != 0 \
			else int(faction["reputations"][id])
		# The browser's GameLogic._reincarnate adds another 30% after
		# FactionSystem has already initialized from the retained legacy.
		faction["reputations"][id] = clampi(base + (
			_js_round(float(inherited) * 0.3) if inherited != 0 else 0), -100, 100)
	var completed: Array = []
	for existing in old_completed:
		if not existing is String or String(existing).is_empty():
			last_error = "previous-life completed quest legacy invalid"
			return false
		if not completed.has(existing):
			completed.append(existing)
	var flags: Dictionary = old_flags.duplicate(true)
	for key in old_flags:
		if not key is String:
			last_error = "previous-life flag invalid"
			return false
		if String(key).ends_with("Completed") and bool(old_flags[key]) \
				and not completed.has(key):
			completed.append(key)
		if String(key).begins_with("quest_") \
				and String(key).ends_with("_active") and bool(old_flags[key]):
			flags[key] = false
		if key in CROSS_LIFE_CLEAR_FLAGS \
				or String(key).begins_with("breakthrough_boost:"):
			flags.erase(key)
	result["rebirthInheritanceVersion"] = 1
	result["legacyFactionReputations"] = legacy
	result["legacyCompletedQuests"] = completed
	result["factionProgress"] = faction
	result["flags"] = flags
	return true


func _carry_closed_quests(terminal: Dictionary) -> Dictionary:
	# QuestSystem._onReset clears only active quests. Its completed, closed and
	# outcome records remain in the save-slot quest state across reincarnation.
	var old: Variant = terminal.get("questState", {})
	if not old is Dictionary or not old.get("activeQuests", []) is Array \
			or not old.get("completedQuests", []) is Array \
			or not old.get("closedQuests", []) is Array \
			or not old.get("questOutcomes", {}) is Dictionary:
		last_error = "previous-life quest record invalid"
		return {}
	return {"saveVersion": 3, "activeQuests": [],
		"completedQuests": old.get("completedQuests", []).duplicate(true),
		"closedQuests": old.get("closedQuests", []).duplicate(true),
		"questOutcomes": old.get("questOutcomes", {}).duplicate(true)}


func _source_faction_progress(source: Dictionary) -> Dictionary:
	if not source.get("factions") is Array \
			or not source.get("undercurrents") is Dictionary:
		return {}
	var reputations := {}
	for row in source["factions"]:
		if not row is Dictionary or not row.get("id") is String \
				or not row.get("startReputation") is int \
					and not row.get("startReputation") is float:
			return {}
		reputations[row["id"]] = int(row["startReputation"])
		for sub in row.get("subfactions", []):
			if not sub is Dictionary or not sub.get("id") is String \
					or not sub.get("startReputation") is int \
						and not sub.get("startReputation") is float:
				return {}
			reputations[sub["id"]] = int(sub["startReputation"])
	var stages := {}
	for id in source["undercurrents"]:
		var row: Variant = source["undercurrents"][id]
		if not row is Dictionary or not row.get("stage") is int \
				and not row.get("stage") is float:
			return {}
		stages[id] = int(row["stage"])
	return {"reputations": reputations, "undercurrentStages": stages,
		"globalFlags": {}, "ticksSinceEvent": 0}


func _js_round(value: float) -> int:
	return floori(value + 0.5)


func select_path(pending: Dictionary, path_id: String) -> Dictionary:
	last_error = ""
	if pending.get("phase") != "REBIRTH_PENDING" or pending.get("path") != null \
			or boon_card(pending).is_empty():
		last_error = "rebirth path selection unavailable"
		return {}
	var doc: Variant = _content.read_module("config:paths")
	var path: Dictionary = doc.get("paths", {}).get(path_id, {}) if doc is Dictionary else {}
	var bonuses: Dictionary = path.get("bonuses", {})
	if path.is_empty() or path.get("startCard") != "q_start_" + path_id:
		last_error = "source path unavailable"
		return {}
	var result: Dictionary = pending.duplicate(true)
	result["path"] = path_id
	result["lifePhase"] = "ALIVE"
	for key in bonuses:
		var amount := int(bonuses[key])
		match key:
			"health":
				result["maxHealth"] = maxi(1, int(result["maxHealth"]) + amount)
				result["attributes"]["health"] = clampi(
					int(result["attributes"]["health"]) + amount, 0,
					int(result["maxHealth"]))
			"daoHeart":
				result["maxDaoHeart"] = maxi(1, int(result["maxDaoHeart"]) + amount)
				result["attributes"]["daoHeart"] = clampi(
					int(result["attributes"]["daoHeart"]) + amount, 0,
					int(result["maxDaoHeart"]))
			"spiritStone":
				result["resources"]["spiritStone"] = maxi(0,
					int(result["resources"]["spiritStone"]) + amount)
			"cultivation", "fortune":
				result["attributes"][key] = clampi(int(result["attributes"][key]) \
					+ amount, 0, 100)
			"combatOpeningBlock":
				pass
			_:
				last_error = "unrecognized source path bonus"
				return {}
	result = _deck.ensure_starter(result)
	if result.is_empty():
		last_error = _deck.last_error
	return result


func choice_available(state: Dictionary, direction: String) -> bool:
	if state.get("phase") != "REBIRTH_PENDING":
		return false
	var card: Dictionary = boon_card(state)
	if card.is_empty() or not state.get("path") is String \
			or direction not in ["left", "right", "down"]:
		return false
	var choice: Dictionary = card.get("choices", {}).get(direction, {})
	var check: Dictionary = choice.get("costCheck", {})
	if choice.is_empty() or check.keys().size() > 1:
		return false
	for key in check:
		var owned: Variant = state.get("attributes", {}).get(key) if key == "karmaGood" \
			else state.get("resources", {}).get(key)
		if not (owned is int or owned is float) or int(owned) < int(check[key]):
			return false
	if direction == "left":
		return not _deck.acquire_legacy(state, "sword_intent",
			"rebirth_boon").is_empty()
	return true


func settle_boon(state: Dictionary, direction: String) -> Dictionary:
	last_error = ""
	if not choice_available(state, direction):
		last_error = "rebirth boon choice unavailable"
		return {}
	var card: Dictionary = boon_card(state)
	var choice: Dictionary = card["choices"][direction]
	var effects: Dictionary = choice.get("effects", {})
	var check: Dictionary = choice.get("costCheck", {})
	var expected: bool = direction == "left" and check.size() == 1 \
		and _source_amount(check.get("karmaGood"), 10) \
		and effects.size() == 1 and effects.get("deckCard") == "sword_intent" \
		or direction == "right" and check.size() == 1 \
		and _source_amount(check.get("spiritStone"), 20) \
		and effects.size() == 1 and effects.get("treasure") == "避尘珠" \
		or direction == "down" and check.is_empty() and effects.size() == 2 \
		and effects.get("removeCard") == true \
		and _source_amount(effects.get("health"), 5)
	if not expected or not state.get("runClock") is Dictionary \
			or not state.get("runClock", {}).get("receipts") is Dictionary \
			or not state.get("choiceHistory") is Array \
			or not state.get("cardsPlayed") is Array \
			or not state.get("recentCardTags") is Array:
		last_error = "rebirth boon source or decision state invalid"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var decision_index := int(candidate["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:rebirth_boon:%d" % [
		candidate["runClock"]["lifeId"], decision_index]
	if decision_index != 1 or candidate["runClock"]["receipts"].has(receipt):
		last_error = "rebirth boon already settled"
		return {}
	for key in check:
		if key == "karmaGood":
			candidate["attributes"][key] = int(candidate["attributes"][key]) \
				- int(check[key])
		else:
			candidate["resources"][key] = int(candidate["resources"][key]) \
				- int(check[key])
	match direction:
		"left":
			candidate = _deck.acquire_legacy(candidate, "sword_intent",
				"rebirth_boon", "legacy_deck_effect", 0)
			if candidate.is_empty():
				last_error = _deck.last_error
				return {}
		"right":
			var transaction := "treasure:narrative:life:%s:decision:%d:source:rebirth_boon:item:避尘珠" % [
				candidate["runClock"]["lifeId"], decision_index]
			if not _treasure.acquire(candidate, "避尘珠", "rebirth_boon",
				decision_index, {"source": "narrative_effect", "channel": "narrative",
				"sourceId": "rebirth_boon", "transactionId": transaction,
				"details": {}}):
				last_error = _treasure.last_error
				return {}
		"down":
			candidate["attributes"]["health"] = mini(
				int(candidate["maxHealth"]),
				int(candidate["attributes"]["health"]) + 5)
			candidate["pendingCampAction"] = "remove"
	candidate["choiceHistory"].append({"cardId": "rebirth_boon",
		"cardType": card["type"], "direction": direction,
		"turn": int(state.get("turn", 0)), "decisionIndex": decision_index,
		"tags": card.get("tags", []).duplicate(true)})
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()
	candidate["cardsPlayed"].append("rebirth_boon")
	for tag in card.get("tags", []):
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["turn"] = decision_index
	candidate["runClock"]["decisionIndex"] = decision_index
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": decision_index, "sourceCardId": "rebirth_boon",
		"kind": "choice"}
	candidate["phase"] = "CAMP_TARGET_PENDING" if direction == "down" else "FLOW_PENDING"
	candidate["currentCardId"] = "rebirth_boon" if direction == "down" else ""
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": "rebirth_boon" if direction == "down" else null,
		"sourceCardId": "rebirth_boon", "turn": decision_index,
		"decisionIndex": decision_index, "flowPending": direction != "down"}
	return candidate


func _source_amount(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and float(value) == float(expected)
