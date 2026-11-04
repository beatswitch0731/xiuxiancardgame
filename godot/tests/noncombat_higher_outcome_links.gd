extends "res://tests/noncombat_higher_catalog.gd"

const CatalogOutcome = preload("res://scripts/noncombat_catalog_outcome_flow.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const VictoryFlow = preload("res://scripts/noncombat_battle_victory_flow.gd")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword"):
		return _fail("higher outcome fixture could not start")
	var content = ContentRepository.new()
	var catalog = CatalogEncounter.new(content)
	var factions = FactionEvents.new(content)
	var companions = CompanionEvents.new(content)
	var baseline: Dictionary = game.state.duplicate(true)
	baseline.factionEventState = factions.marker(0)
	baseline.factionProgress = factions.baseline_progress()
	baseline.companionProgress = companions.marker(0, 0)
	baseline.karmaSeeds = []
	baseline.karmaPromiseFlags = {}
	var count := 0
	var document: Dictionary = content.read_module("combat:encounters")
	for encounter in document.get("encounters", []):
		if encounter.get("realm") not in ["golden", "nascent", "deity", "tribulation"] \
				or encounter.get("category") == "realmBoss" \
				or encounter.get("outcomeLinks", {}).is_empty() \
					and not encounter.has("karmaSeed") \
					and not encounter.get("enemy", {}).has("factionId"):
			continue
		for outcome in ["victory", "defeat", "flee"]:
			var state: Dictionary = baseline.duplicate(true)
			state.realm = encounter.realm
			var source: Dictionary = catalog.card(state,
				"encounter_card_" + String(encounter.id))
			if source.is_empty():
				return _fail("higher linked source missing: " + String(encounter.id))
			var flow = CatalogOutcome.new(content)
			if not flow.apply(state, source, source.choices.left, encounter, outcome, 2):
				return _fail("higher linked outcome failed: " + String(encounter.id) \
					+ "/" + outcome + " " + flow.last_error)
			var linked: Dictionary = encounter.get("outcomeLinks", {}).get(outcome, {})
			var faction: Dictionary = linked.get("factionEffects", {})
			if not faction.is_empty() and int(state.factionProgress.reputations.get(
						faction.factionId, 999)) != clampi(int(baseline.factionProgress.reputations.get(
						faction.factionId, 999)) + int(faction.reputationDelta), -100, 100):
				return _fail("higher linked faction mismatch: " + String(encounter.id))
			var companion: Dictionary = linked.get("companionEffects", {})
			if not companion.is_empty():
				var comp_id := String(companion.compId)
				var start: Dictionary = baseline.companionProgress.states[comp_id]
				var after: Dictionary = state.companionProgress.states[comp_id]
				if int(after.trust) != clampi(int(start.trust) + int(companion.get(
						"trustDelta", 0)), 0, 100) \
						or int(after.bond) != clampi(int(start.bond) + int(companion.get(
							"bondDelta", 0)), 0, 5):
					return _fail("higher linked companion mismatch: " + String(encounter.id))
			var expected_seed: Dictionary = linked.get("karmaSeed", {})
			if not expected_seed.is_empty() and not state.karmaSeeds.any(
					func(seed: Variant) -> bool:
						return seed is Dictionary and seed.get("id") == expected_seed.id \
							and seed.get("originOutcome") == outcome):
				return _fail("higher linked karma mismatch: " + String(encounter.id))
			if encounter.has("karmaSeed") and (outcome in encounter.get(
					"karmaSeedOn", ["victory"])) != state.karmaSeeds.any(
					func(seed: Variant) -> bool:
						return seed is Dictionary and seed.get("id") == encounter.karmaSeed.id):
				return _fail("higher direct karma result mismatch: " + String(encounter.id))
			if outcome == "victory" and encounter.get("enemy", {}).has("factionId") \
					and not state.karmaSeeds.any(func(seed: Variant) -> bool:
						return seed is Dictionary and seed.get("id") == "combatGlory" \
							and seed.get("context", {}).get("factionId") == encounter.enemy.factionId):
				return _fail("higher combat glory absent: " + String(encounter.id))
			count += 1
	var state: Dictionary = baseline.duplicate(true)
	state.realm = "golden"
	var elixir: Dictionary = document.encounters.filter(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id") == "enc_quota_golden_lost_elixir")[0]
	var source: Dictionary = catalog.card(state,
		"encounter_card_enc_quota_golden_lost_elixir")
	var before := int(state.get("knowledge", {}).get("world", 0))
	var rewards: Dictionary = VictoryFlow.new(content).apply_rewards(state,
		elixir, source.choices.left)
	if rewards.is_empty() or int(state.knowledge.get("world", 0)) != before + 2:
		return _fail("higher knowledge victory effect missing")
	print("NONCOMBAT_HIGHER_OUTCOME_LINKS_PASS outcomes=", count,
		" knowledge=true faction=true companion=true karma=true")
	quit(0)
