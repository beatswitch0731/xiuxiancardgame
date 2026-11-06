extends SceneTree

const Content = preload("res://scripts/noncombat_content_repository.gd")
const Director = preload("res://scripts/noncombat_encounter_director.gd")
const REALMS := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const PATHS := ["sword", "spell", "body", "pill"]
var _error := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = Content.new()
	var policy = Director.new(content)
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/cadence_battle_source.json"))
	var pins: Dictionary = policy.source_rule_pins()
	if pins.is_empty():
		return _fail("source rule pins missing: " + policy.last_error)
	for source in pins:
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://tests/fixtures/source/").path_join(source))
		if pins[source] != actual or oracle.pins.get(source) != actual:
			return _fail("source rule drift: " + source)
	for source in ["src/systems/CardSystem.js", "data/combat/encounters.json"]:
		if oracle.pins.get(source) != FileAccess.get_sha256(ProjectSettings.globalize_path(
				"res://tests/fixtures/source/").path_join(source)):
			return _fail("candidate catalog source drift: " + source)
	if not _fixture_cases(policy, oracle) or not _policy_boundaries(policy, oracle.rows[1]) \
			or not _catalog_order(policy, content, oracle.rows[1]):
		return _fail(_error)
	print("NONCOMBAT_CADENCE_DIRECTOR_PASS source_rows=4 catalog_ids=54 order_cases=24 pending=true repeat=true cooldown=true history80=true immutable=true")
	quit(0)


func _fixture_cases(policy: RefCounted, oracle: Dictionary) -> bool:
	if oracle.rows.size() != 4 or oracle.get("realCombat") != true or oracle.get("publicInput") != true:
		return _check(false, "cadence source matrix is incomplete")
	for row in oracle.rows:
		var before := _state(row.beforeOffer)
		var untouched := before.duplicate(true)
		var card: Dictionary = row.sourceCard.duplicate(true)
		var card_before := card.duplicate(true)
		var scheduled: Dictionary = policy.schedule(before, [card])
		if not _check(_same(scheduled, row.offered.director), row.caseId + " schedule differs from source") \
				or not _check(before == untouched and card == card_before, "schedule mutated inputs"):
			return false
		var offered := _state(row.offered)
		var offered_before := offered.duplicate(true)
		var settled: Dictionary
		if row.outcome == "avoided":
			settled = policy.settled(offered, card, "avoided", "right")
		else:
			var accepted: Dictionary = policy.accepted(offered, card)
			if not _check(_same(accepted, row.afterChoice.director), row.caseId + " acceptance differs"):
				return false
			var active := _state(row.afterWarning)
			var active_before := active.duplicate(true)
			settled = policy.settled(active, card, row.outcome)
			if not _check(_same(policy.accepted(active, card), accepted), "repeated acceptance changed history") \
					or not _check(_same(policy.settled(offered, card, row.outcome), settled),
						"terminal did not include missing acceptance exactly once") \
					or not _check(active == active_before, "accepted settlement mutated active state"):
				return false
		if not _check(_same(settled, row.directorAfter), row.caseId + " settlement differs from source") \
				or not _check(offered == offered_before and card == card_before, "settlement mutated source inputs"):
			return false
		var committed := offered.duplicate(true)
		committed.noncombatFlow.encounterDirectorState = settled
		if not _check(policy.settled(committed, card, row.outcome).is_empty(), "settled owner replay accepted"):
			return false
	return true


func _policy_boundaries(policy: RefCounted, row: Dictionary) -> bool:
	# These are pure scheduling-policy counterexamples, not production-route fixtures.
	var card: Dictionary = row.sourceCard.duplicate(true)
	var early := _state(row.beforeOffer)
	early.turn = 10
	if not _check(policy.schedule(early, [card]).is_empty() and policy.last_error.is_empty(), "not-due must be a clean no-op"):
		return false
	var cooling := _state(row.beforeOffer)
	cooling.noncombatFlow.encounterDirectorState.cooldownUntilDecision = 14
	if not _check(policy.schedule(cooling, [card]).is_empty() and policy.last_error.is_empty(), "cooldown ignored"):
		return false
	var pending := _state(row.offered)
	pending.noncombatFlow.encounterDirectorState.cooldownUntilDecision = 100
	pending.noncombatFlow.encounterDirectorState.nextDueDecision = 200
	pending.noncombatFlow.encounterDirectorState.realmProgress.qi.resolvedIds.append(card.encounterId)
	var pending_before := pending.duplicate(true)
	if not _check(_same(policy.schedule(pending, [card]), pending.noncombatFlow.encounterDirectorState),
			"pending must recover before due/cooldown/once and without new presentation") \
			or not _check(pending == pending_before, "pending restore mutated input"):
		return false
	var invalidated: Dictionary = policy.schedule(pending, [])
	if not _check(invalidated.get("pending") == null and invalidated.history[-1].event == "invalidated" \
			and invalidated.history[-1].reason == "eligibility_changed", "ineligible pending was not invalidated"):
		return false
	var wrong := card.duplicate(true)
	wrong.id = "policy_other_owner"
	if not _check(policy.accepted(pending, wrong).is_empty() \
			and policy.settled(pending, wrong, "victory").is_empty(), "foreign owner accepted"):
		return false
	var committed := _state(row.after)
	committed.turn = 19
	if not _check(policy.schedule(committed, [card]).is_empty(), "once encounter repeated after resolution"):
		return false
	var repeated := card.duplicate(true)
	repeated.once = false
	var rescheduled: Dictionary = policy.schedule(committed, [repeated])
	if not _check(not rescheduled.is_empty() and rescheduled.realmProgress.qi.seenCounts.ordinary == 2,
			"repeatable encounter should not increase unique seen count"):
		return false
	committed.noncombatFlow.encounterDirectorState = rescheduled
	var twice: Dictionary = policy.settled(committed, repeated, "flee")
	if not _check(twice.realmProgress.qi.counts.ordinary == 3 \
			and twice.realmProgress.qi.resolvedIds.size() == 2, "repeat resolution must increment count but deduplicate IDs"):
		return false
	# Repeated real policy transitions exercise the source's rolling history cap.
	for index in 24:
		committed.noncombatFlow.encounterDirectorState = twice
		committed.turn = maxi(int(twice.nextDueDecision) - 1, int(twice.cooldownUntilDecision))
		committed.noncombatFlow.encounterDirectorState = policy.schedule(committed, [repeated])
		twice = policy.settled(committed, repeated, "victory")
	if not _check(twice.history.size() == 80 and twice.history[-1].event == "resolved", "history cap differs"):
		return false
	var deadline := _state(row.beforeOffer)
	deadline.turn = 11 # presentation 4; next decision 12 -> gap 8, latest-safe-start 9.
	if not _check(not policy.is_hard_due(deadline), "hard deadline early"):
		return false
	deadline.turn = 12
	if not _check(policy.is_hard_due(deadline), "hard deadline boundary missing") \
			or not _check(policy.can_start_authored_sequence(deadline, 2) \
				and not policy.can_start_authored_sequence(deadline, 3), "authored sequence budget boundary") \
			or not _check(not policy.is_hard_due(pending) \
				and policy.can_start_authored_sequence(pending, 100), "pending deadline semantics"):
		return false
	var foreign := _state(row.beforeOffer)
	foreign.lifeCount = 1
	if not _check(policy.schedule(foreign, [card]).is_empty() and not policy.last_error.is_empty(),
			"cross-life state must not recreate teaching authority"):
		return false
	return true


func _catalog_order(policy: RefCounted, content: RefCounted, row: Dictionary) -> bool:
	var catalog: Dictionary = content.read_module("combat:encounters")
	if not _check(catalog.encounters.size() == 54, "catalog full ID contract changed"):
		return false
	var covered := {}
	var bosses := {}
	for realm in REALMS:
		for path_id in PATHS:
			var state := _state(row.beforeOffer)
			state.realm = realm
			state.path = path_id
			state.turn = 100
			var director: Dictionary = state.noncombatFlow.encounterDirectorState
			director.realmProgress = {}
			director.history = []
			director.pending = null
			director.cooldownUntilDecision = 0
			var candidates := _catalog_policy_projection(catalog, realm, path_id)
			var actual: Array = []
			for ignored in 20:
				director.nextDueDecision = int(state.turn) + 1
				state.noncombatFlow.encounterDirectorState = director
				var scheduled: Dictionary = policy.schedule(state, candidates)
				if scheduled.is_empty():
					break
				var id: String = scheduled.pending.encounterId
				actual.append(id)
				covered[id] = true
				var selected: Dictionary = {}
				for card in candidates:
					if card.encounterId == id:
						selected = card
				state.noncombatFlow.encounterDirectorState = scheduled
				director = policy.settled(state, selected, "victory")
				state.turn = director.cooldownUntilDecision
			if not _check(actual == _source_order(realm, path_id), "source catalog order: " + realm + ":" + path_id):
				print("actual=", actual, " expected=", _source_order(realm, path_id))
				return false
			for card in candidates:
				if card.encounterRole == "boss":
					bosses[card.encounterId] = true
	for encounter in catalog.encounters:
		if not _check(covered.has(encounter.id) != bosses.has(encounter.id), "catalog ID neither selected nor excluded boss: " + encounter.id):
			return false
	return _check(covered.size() == 48 and bosses.size() == 6, "full catalog coverage")


func _catalog_policy_projection(catalog: Dictionary, realm: String, path_id: String) -> Array:
	# Only CardSystem's scheduling fields from all real catalog entries. These
	# tests intentionally do not claim flag/companion eligibility or world reachability.
	var roles := {"archetypeTrial": "ordinary", "realmPatrol": "ordinary", "factionElite": "elite",
		"companionQuest": "relationship", "heavenChaos": "quest", "realmQuotaOrdinary": "ordinary",
		"realmQuest": "quest", "realmElite": "elite", "realmBoss": "boss"}
	var cards: Array = []
	for raw in catalog.encounters:
		if raw.realm != realm or raw.get("path", path_id) != path_id:
			continue
		var card: Dictionary = raw.duplicate(true)
		card.merge({"id": "encounter_card_" + raw.id, "encounterId": raw.id,
			"encounterKind": raw.get("encounterKind", "realm_boss" if raw.category == "realmBoss" else "ordinary"),
			"encounterRole": raw.get("encounterRole", roles.get(raw.category, "ordinary")),
			"narrativeSource": raw.get("narrativeSource", "encounter_catalog:%s:%s" % [raw.category, raw.id]),
			"once": raw.get("once") != false}, true)
		cards.append(card)
	return cards


func _source_order(realm: String, path_id: String) -> Array:
	# Expected sequences captured by the original JS EncounterDirector over all
	# 54 CardSystem-materialized cards, separately for 6 realms x 4 paths. This is
	# an isolated policy oracle; it does not bypass prerequisites in a game run.
	match realm:
		"qi":
			return ["enc_patrol_qi_mountain_shadow", {"sword": "enc_trial_sword_swift",
				"spell": "enc_trial_spell_seal", "body": "enc_trial_body_iron", "pill": "enc_trial_pill_poison"}[path_id],
				"enc_quota_qi_missing_disciple", "enc_quota_qi_outer_guard"]
		"foundation":
			return ["enc_quota_foundation_mirror_mist", "enc_quota_foundation_vein_wolf",
				"enc_companion_bai_luoxuan_hunt", "enc_faction_qingyun_elite",
				"enc_quota_foundation_broken_array", "enc_faction_wumeng_elite"]
		"golden":
			var result := ["enc_quota_golden_furnace_flame", "enc_quota_golden_ore_spirit",
				"enc_companion_jian_linger_tomb", "enc_faction_dangu_elite", "enc_quota_golden_lost_elixir",
				"enc_faction_tianshu_elite", "enc_companion_mu_qinglan_medicine"]
			if path_id != "pill":
				result.append({"sword": "enc_trial_sword_array", "spell": "enc_trial_spell_elements",
					"body": "enc_trial_body_mountain"}[path_id])
			return result
		"nascent":
			var result := ["enc_quota_nascent_soul_echo", "enc_quota_nascent_void_moth",
				"enc_companion_yin_xue_pursuit", "enc_faction_tianji_elite", "enc_quota_nascent_rift_rescue",
				"enc_faction_xuesha_elite"]
			if path_id == "pill":
				result.append("enc_trial_pill_spirit")
			return result
		"deity":
			var result := ["enc_patrol_deity_law_echo", "enc_quota_deity_law_beast",
				"enc_companion_jiuwei_memory", "enc_quota_deity_heaven_envoy", "enc_hidden_chaos_reversal",
				"enc_hidden_heaven_censor"]
			if path_id in ["sword", "spell"]:
				result.append("enc_trial_sword_heaven" if path_id == "sword" else "enc_trial_spell_void")
			result.append("enc_quota_deity_mortal_prayer")
			return result
		"tribulation":
			var result := ["enc_patrol_tribulation_storm_echo", "enc_quota_tribulation_thunder_wraith",
				"enc_companion_tianji_future", "enc_quota_tribulation_gate_hunter", "enc_hidden_chaos_nameless",
				"enc_hidden_heaven_chain"]
			if path_id in ["body", "pill"]:
				result.append("enc_trial_body_immortal" if path_id == "body" else "enc_trial_pill_chaos")
			result.append("enc_quota_tribulation_fallen_ascender")
			return result
	return []


func _state(source: Dictionary) -> Dictionary:
	var state := source.duplicate(true)
	state.merge({"realm": "qi", "path": "sword", "lifeCount": 0,
		"noncombatFlow": {"encounterDirectorState": source.director.duplicate(true)}}, true)
	return state


func _same(actual: Variant, expected: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_error = message
	return condition


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
