extends SceneTree

# Pure source projections and boundary candidates, not a playable-route test.
# The Node oracle executes the original CardSystem/NarrativeLedger methods.
const Catalog = preload("res://scripts/noncombat_catalog_encounter.gd")
const Content = preload("res://scripts/noncombat_content_repository.gd")
const Gateway = preload("res://scripts/noncombat_battle_gateway.gd")
const Encounter = preload("res://scripts/noncombat_encounter_flow.gd")
const Director = preload("res://scripts/noncombat_encounter_director.gd")
const SOURCE_ID := "encounter_card_enc_patrol_qi_mountain_shadow"
const NODE_ORACLE := """
const fs=require('fs'),path=require('path'),vm=require('vm');
const root=process.argv[1];
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const docs=new Map();
const context=vm.createContext({dataLoader:{loadSync(id){
 if(!docs.has(id))docs.set(id,JSON.parse(read('data/'+id.replace(':','/')+'.json')));
 return docs.get(id);
}}});
for(const [file,name] of [
 ['src/core/GameStateManager.js','GameStateManager'],
 ['src/systems/NarrativeLedger.js','NarrativeLedger'],
 ['src/systems/CardSystem.js','CardSystem']]){
 vm.runInContext(read(file).split('// 全局单例')[0]+';globalThis.'+name+'='+name,context);
}
vm.runInContext('globalThis.ledger=narrativeLedger;',context);
const base=path=>({path,realm:'qi',turn:11,flags:{},resources:{companions:[]},cardsPlayed:[]});
const state=plain=>Object.assign(Object.create(context.GameStateManager.prototype),plain);
const result={paths:[],qualifications:[]};
for(const pathId of ['sword','spell','body','pill']){
 const system=new context.CardSystem();system.refreshCombatEncounterCards(pathId);
 const plain=base(pathId),current=state(plain);
 const cards=system.getCombatEncounterCatalogCards().filter(c=>c.realm==='qi'&&c.encounterRole!=='boss');
 const ids=()=>system.getEligibleCombatEncounterCards({state:current,includeDirectorCooldown:true}).map(c=>c.id);
 const eligible=ids();current.cardsPlayed=[eligible.find(id=>id.includes('enc_trial_'))];
 result.paths.push({path:pathId,cards,eligible,played:current.cardsPlayed,afterPlayed:ids()});
 if(pathId!=='sword')continue;
 const source=cards.find(c=>c.id==='encounter_card_enc_patrol_qi_mountain_shadow');
 const variants=[
 ['baseline',{},{}],['ledger_uninitialized',{}, {narrativeLedgerState:null}],['zero_weight',{weight:0},{}],
 ['path_mismatch',{path:'pill'},{}],['companion_missing',{requiredCompanion:'white_fox'},{}],
 ['companion_owned',{requiredCompanion:'white_fox'},{resources:{companions:['white_fox']}}],
 ['requires_missing',{requiresFlags:{seen:null}},{}],
 ['requires_written_false',{requiresFlags:{seen:null}},{flags:{seen:false}}],
 ['requires_exact',{requiresFlags:{seen:true}},{flags:{seen:false}}],
 ['any_missing',{requiresAnyFlags:['one','two']},{flags:{one:0,two:false}}],
 ['any_present',{requiresAnyFlags:['one','two']},{flags:{two:true}}],
 ['forbidden_truthy',{forbiddenFlags:{seen:null}},{flags:{seen:true}}],
 ['forbidden_false',{forbiddenFlags:{seen:null}},{flags:{seen:false}}],
 ['forbidden_exact',{forbiddenFlags:{seen:false}},{flags:{seen:false}}],
 ['played_once',{}, {cardsPlayed:[source.id]}],
 ['played_repeat',{once:false},{cardsPlayed:[source.id]}],
 ['upper_world',{}, {flags:{post_ascension_active:true}}],
 ['semantic_once',{}, {narrativeLedgerState:{entries:{['card:'+source.id]:{resolvedCount:1}}}}],
 ['semantic_repeat',{once:false},{narrativeLedgerState:{entries:{['card:'+source.id]:{resolvedCount:1}}}}]
 ];
 for(const [name,patch,changes] of variants){
  const card={...source,...patch},plainState={...base('sword'),...changes};
  context.ledger.entries=new Map(Object.entries(plainState.narrativeLedgerState?.entries||{}));
  const eligible=system.isCardEligibleForNormalDraw(card,state(plainState),new Set(),{
   allowDirectorEncounter:true,skipEncounterDirector:true});
  result.qualifications.push({name,card,state:plainState,eligible});
 }
 context.ledger.entries=new Map();
}
process.stdout.write(JSON.stringify(result).replace(/[^ -~]/g,c=>String.fromCharCode(92)+'u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
"""
var _error := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content := Content.new()
	var catalog := Catalog.new(content)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cadence_battle_source.json"))
	var repo := ProjectSettings.globalize_path("res://").path_join("..")
	for source in catalog.source_rule_pins():
		var sha := FileAccess.get_sha256(repo.path_join(source))
		if sha != catalog.source_rule_pins()[source] or fixture.pins.get(source) != sha:
			return _fail("source rule drift: " + source)
	var hashes := catalog.source_hashes()
	if hashes.size() != Catalog.MODULES.size():
		return _fail("source hashes missing: " + catalog.last_error)
	for module_id in hashes:
		if hashes[module_id] != FileAccess.get_sha256(repo.path_join(content.module_path(module_id))):
			return _fail("packaged catalog differs from original: " + module_id)
	var output: Array = []
	var code := OS.execute("node", ["-e", NODE_ORACLE, repo], output, true)
	if code != 0 or output.is_empty():
		return _fail("original source oracle failed: " + str(output))
	var oracle: Variant = JSON.parse_string(output[0])
	if not oracle is Dictionary or oracle.get("paths", []).size() != 4:
		return _fail("original source oracle is incomplete: size=%d tail=%s" % [output[0].length(), output[0].right(150)])
	print("CADENCE_CATALOG oracle=original_js paths=4")
	var projected := 0
	for row in oracle.paths:
		var state := {"path": row.path, "realm": "qi", "flags": {}, "resources": {"companions": []}, "cardsPlayed": []}
		var before := state.duplicate(true)
		for source in row.cards:
			if not _check(_same(catalog.card(state, source.id), source), row.path + " full card mismatch: " + source.id):
				return _fail(_error)
			projected += 1
		if not _check(_ids(catalog.candidates(state)) == row.eligible, row.path + " candidates differ"):
			return _fail(_error)
		state.cardsPlayed = row.played
		if not _check(_ids(catalog.candidates(state)) == row.afterPlayed, row.path + " avoided teaching can repeat"):
			return _fail(_error)
		state.cardsPlayed = []
		state["noncombatFlow"] = {"encounterDirectorState": {"cooldownUntilDecision": 100,
			"realmProgress": {"qi": {"resolvedIds": [SOURCE_ID.trim_prefix(Catalog.PREFIX)], "avoidedIds": [SOURCE_ID.trim_prefix(Catalog.PREFIX)]}}}}
		if not _check(_ids(catalog.candidates(state)) == row.eligible, "catalog consumed director eligibility"):
			return _fail(_error)
		state.erase("noncombatFlow")
		if not _check(_same(state, before), "source projection mutated its input"):
			return _fail(_error)
		print("CADENCE_CATALOG source path=", row.path, " cards=", row.cards.size(), " eligibility=pass")
	for row in oracle.qualifications:
		if not _check(catalog.eligible(row.state, row.card) == row.eligible, "eligibility differs: " + row.name):
			return _fail(_error)
	if not _receipt_eligibility(catalog) or not _fixture_boundary(catalog, content, fixture.rows[1]):
		return _fail(_error)
	print("NONCOMBAT_CADENCE_CATALOG_PASS source_cards=", projected,
		" eligibility_cases=", oracle.qualifications.size(), " committed_choice_cases=3 fixture_resolution=true warning=true paid_snapshot=true")
	quit(0)


func _receipt_eligibility(catalog: RefCounted) -> bool:
	# Godot's existing committed-choice receipts are the bounded projection
	# of card:chosen while the complete NarrativeLedger producer is unmigrated.
	var source_id := "encounter_card_enc_trial_sword_swift"
	var state := {"path": "sword", "realm": "qi", "flags": {}, "resources": {"companions": []},
		"cardsPlayed": [], "runClock": {"version": 1, "lifeId": "slot_1:life:0", "decisionIndex": 6, "receipts": {}},
		"noncombatFlow": {"encounterDirectorState": {"firstTeachingStatus": "avoided"}}}
	var source: Dictionary = catalog.card(state, source_id)
	if not _check(not source.is_empty() and catalog.eligible(state, source), "uncommitted avoidance suppressed teaching"):
		return false
	var other_token := "decision:slot_1:life:0:choice:q_start_sword:5"
	state.runClock.receipts[other_token] = {"token": other_token, "decisionIndex": 5,
		"sourceCardId": "q_start_sword", "kind": "choice"}
	if not _check(catalog.eligible(state, source), "another source's choice receipt suppressed teaching"):
		return false
	var token := "decision:slot_1:life:0:choice:%s:6" % source_id
	state.runClock.receipts[token] = {"token": token, "decisionIndex": 6,
		"sourceCardId": source_id, "kind": "choice"}
	var before := state.duplicate(true)
	if not _check(not catalog.eligible(state, source) and not _ids(catalog.candidates(state)).has(source_id),
			"committed teaching avoidance remained eligible without a full narrative ledger") \
			or not _check(not catalog.card(state, source_id).is_empty(), "committed choice blocked static source access") \
			or not _check(_same(state, before), "receipt projection wrote cardsPlayed or a narrative ledger"):
		return false
	var repeatable := source.duplicate(true)
	repeatable.once = false
	if not _check(catalog.eligible(state, repeatable), "choice receipt suppressed an unrestricted card"):
		return false
	print("CADENCE_CATALOG committed_choice_projection=pass cases=3")
	return true


func _fixture_boundary(catalog: RefCounted, content: RefCounted, row: Dictionary) -> bool:
	var source: Dictionary = _without_flow(row.sourceCard)
	var state: Dictionary = row.offered.duplicate(true)
	state.merge({"path": "sword", "realm": "qi", "phase": "COMBAT_HANDOFF", "currentCardId": SOURCE_ID,
		"lifeCount": 0, "starterDeckPath": "sword", "skills": {}, "lineage": {}, "equipment": {},
		"pendingCadenceCard": source, "noncombatFlow": {"encounterDirectorState": row.offered.director.duplicate(true)}}, true)
	var pins: Dictionary = catalog.source_rule_pins()
	pins.merge(Director.new(content).source_rule_pins(), true)
	state["encounterCadence"] = {"version": 1, "activationIndex": 0, "rulePins": pins, "sourceHashes": catalog.source_hashes()}
	var expected: Dictionary = _without_flow(row.pendingResolution)
	expected["sourceCardId"] = SOURCE_ID
	var gateway := Gateway.new(RefCounted.new(), content)
	var flow := Encounter.new(content, gateway)
	var before := state.duplicate(true)
	if not _check(_same(catalog.resolution(state, SOURCE_ID), expected), "recorded full source resolution differs") \
			or not _check(not gateway.offer_from_state(state).is_empty(), "catalog offer unavailable: " + gateway.source_error):
		return false
	var warning: Dictionary = flow.accept(state)
	if not _check(not warning.is_empty(), "catalog warning candidate unavailable"):
		return false
	var card: Dictionary = flow.warning_card(warning)
	if not _check(_same(warning.noncombatFlow.encounterDirectorState, row.afterChoice.director), "accepted director differs from source") \
			or not _check(card.get("description") == row.warning.description and card.get("sceneImage") == row.warning.sceneImage,
				"warning description or original image differs"):
		return false
	var pending: Dictionary = flow.confirm(warning, "right")
	if not _check(not pending.is_empty(), "paid preparation candidate unavailable"):
		return false
	var request: Dictionary = gateway.build_request(pending)
	if not _check(not request.is_empty() and _same(request.pendingResolution, expected), "catalog request projection differs") \
			or not _check(pending.deck.size() == 8 and pending.deck == state.deck and request.playerSnapshot.battleLoadout.deck == state.deck,
				"current eight-card deck was replaced") \
			or not _check(request.playerSnapshot.knowledge == state.knowledge and request.playerSnapshot.modifiers == state.modifiers,
				"knowledge/modifiers snapshot missing") \
			or not _check(pending.resources.spiritStone == state.resources.spiritStone - 10 \
				and request.playerSnapshot.resources.spiritStone == pending.resources.spiritStone, "snapshot precedes preparation") \
			or not _check(_same(state, before), "candidate builder mutated source state"):
		return false
	var malformed := state.duplicate(true)
	malformed.noncombatFlow.encounterDirectorState.pending.scheduledDecision += 1
	if not _check(gateway.offer_from_state(malformed).is_empty(), "clock mismatch accepted"):
		return false
	malformed = state.duplicate(true)
	malformed.pendingCadenceCard.description = "forged"
	if not _check(gateway.offer_from_state(malformed).is_empty(), "full source mismatch accepted"):
		return false
	malformed = state.duplicate(true)
	malformed.encounterCadence.rulePins["src/systems/CardSystem.js"] = "forged"
	if not _check(gateway.offer_from_state(malformed).is_empty() and gateway.source_error == "SOURCE_MISMATCH", "rule mismatch classification lost"):
		return false
	var completed := pending.duplicate(true)
	completed.currentCardId = "combat_reward"
	completed.cardsPlayed.append(SOURCE_ID)
	completed.erase("pendingCadenceCard")
	if not _check(not gateway.resolved_encounter(completed, source.encounterId, SOURCE_ID).is_empty(),
			"resolved once-only catalog source could not be rebuilt"):
		return false
	print("CADENCE_CATALOG boundary=fixture projection_only=true paid_current_deck=8")
	return true


func _ids(cards: Array) -> Array:
	return cards.map(func(card: Dictionary) -> String: return card.id)


func _without_flow(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			if key not in ["_flowSource", "_flowPhase"]:
				result[key] = _without_flow(value[key])
		return result
	if value is Array:
		return value.map(_without_flow)
	return value


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_error = message
	return ok


func _fail(message: String) -> void:
	push_error("NONCOMBAT_CADENCE_CATALOG_FAIL " + message)
	quit(1)
