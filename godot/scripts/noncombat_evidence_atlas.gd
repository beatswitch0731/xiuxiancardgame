extends RefCounted

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const ATLAS_MODULE := "world:truth_atlas"
const REALMS_MODULE := "config:realms"

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else Repository.new()


func project(state: Dictionary) -> Dictionary:
	last_error = ""
	var atlas: Variant = _content.read_module(ATLAS_MODULE)
	var realms: Variant = _content.read_module(REALMS_MODULE)
	var atlas_sha: String = _content.source_sha256(ATLAS_MODULE)
	if not atlas is Dictionary or atlas_sha.length() != 64 \
			or not atlas.get("clues") is Array \
			or not atlas.get("hypotheses") is Array \
			or not atlas.get("endings") is Array \
			or not realms is Dictionary \
			or _content.source_sha256(REALMS_MODULE).length() != 64:
		last_error = "证据星图来源不可用"
		return {}
	var clue_definitions := {}
	for definition in atlas["clues"]:
		if definition is Dictionary:
			clue_definitions[String(definition.get("id", ""))] = definition
	var discovered := []
	var clue_ids := {}
	var stored_clues: Array = state.get("clues", []).duplicate()
	# Older migrated runs stored Heaven's Hint discoveries outside the main clue list.
	stored_clues.append_array(state.get("noncombatFlow", {}).get("hintClues", []))
	for entry in stored_clues:
		var clue_id := String(entry.get("id", "") if entry is Dictionary else entry)
		if clue_id.is_empty() or clue_ids.has(clue_id):
			continue
		clue_ids[clue_id] = true
		var definition: Dictionary = clue_definitions.get(clue_id, {"id": clue_id,
			"name": clue_id, "category": "unknown", "reliability": 1,
			"description": "这条证据尚未被天机星图完整解读。"})
		var row: Dictionary = entry.duplicate(true) if entry is Dictionary else {"id": clue_id}
		row["definition"] = definition.duplicate(true)
		discovered.append(row)
	var hypotheses := []
	var hypotheses_by_id := {}
	for definition in atlas["hypotheses"]:
		if not definition is Dictionary:
			continue
		var supports := []
		for clue_id in definition.get("supports", []):
			if clue_ids.has(clue_id):
				supports.append(clue_id)
		var contradictions := []
		for clue_id in definition.get("contradicts", []):
			if clue_ids.has(clue_id):
				contradictions.append(clue_id)
		var required := maxi(1, int(definition.get("requiredEvidence", 1)))
		var confidence := clampi(roundi(float(supports.size()) / float(required)
			* 100.0 - float(contradictions.size()) * 25.0), 0, 100)
		var row: Dictionary = definition.duplicate(true)
		row["discoveredSupports"] = supports
		row["discoveredContradictions"] = contradictions
		row["confidence"] = confidence
		row["status"] = "verified" if confidence >= 100 else (
			"plausible" if confidence >= 50 else "unknown")
		hypotheses.append(row)
		hypotheses_by_id[String(row.get("id", ""))] = row
	var endings := []
	for definition in atlas["endings"]:
		if definition is Dictionary:
			endings.append(_project_ending(definition, state, realms, clue_ids,
				hypotheses_by_id, clue_definitions))
	return {"sourceSha256": atlas_sha, "discoveredClues": discovered,
		"totalClues": atlas["clues"].size(), "hypotheses": hypotheses,
		"endings": endings}


func _project_ending(definition: Dictionary, state: Dictionary,
		realms: Dictionary, clue_ids: Dictionary, hypotheses: Dictionary,
		clue_definitions: Dictionary) -> Dictionary:
	var context: Dictionary = state.get("terminalContext", {})
	var snapshot: Dictionary = context.get("eligibilitySnapshot", {})
	var frozen: bool = snapshot.get("version") == 1
	var requirements: Dictionary = definition.get("requirements", {})
	var gate: Dictionary = definition.get("terminalGate", {})
	var encounter_ids: Array = gate.get("encounterIds", [])
	var gate_ok: bool = frozen \
		and context.get("gateId") == gate.get("id") \
		and context.get("outcome") == gate.get("requiredOutcome", "victory") \
		and context.get("stage") == "REWARD_PENDING" \
		and context.get("consumed") == false \
		and encounter_ids.has(context.get("encounterId")) \
		and context.get("victoryToken") == "combat:" + String(
			context.get("encounterInstanceId", ""))
	var reasons := [{"ok": gate_ok,
		"text": "通过终局门禁「%s」" % String(gate.get("id", "unknown"))}]
	var realm_order: Array = realms.get("order", [])
	var realm_id := String(snapshot.get("realm", "qi") if frozen else state.get("realm", "qi"))
	if requirements.has("minRealm"):
		var min_realm := String(requirements["minRealm"])
		var realm_ok := realm_order.find(realm_id) >= realm_order.find(min_realm)
		var realm_name := String(realms.get("realms", {}).get(min_realm, {}).get(
			"name", min_realm))
		reasons.append({"ok": realm_ok, "text": "境界达到%s" % realm_name})
	for hypothesis_id in requirements.get("hypotheses", []):
		var hypothesis: Dictionary = hypotheses.get(hypothesis_id, {})
		var confidence := int(snapshot.get("hypothesisConfidence", {}).get(
			hypothesis_id, 0)) if frozen else int(hypothesis.get("confidence", 0))
		reasons.append({"ok": confidence >= 100,
			"text": "证实假说「%s」" % String(hypothesis.get(
				"title", hypothesis_id))})
	for clue_id in requirements.get("clues", []):
		var has_clue: bool = snapshot.get("clueIds", []).has(clue_id) if frozen \
			else clue_ids.has(clue_id)
		var clue: Dictionary = clue_definitions.get(clue_id, {})
		reasons.append({"ok": has_clue,
			"text": "取得线索「%s」" % String(clue.get("name", clue_id))})
	if requirements.has("minBond"):
		var max_bond := int(snapshot.get("maxBond", 0)) if frozen else _max_bond(state)
		reasons.append({"ok": max_bond >= int(requirements["minBond"]),
			"text": "任一羁绊达到 %d" % int(requirements["minBond"])})
	var met := 0
	for reason in reasons:
		if reason.ok:
			met += 1
	var row: Dictionary = definition.duplicate(true)
	row["eligible"] = met == reasons.size()
	row["progress"] = roundi(float(met) / float(reasons.size()) * 100.0)
	row["reasons"] = reasons
	return row


func _max_bond(state: Dictionary) -> int:
	var result := 0
	for value in state.get("npcAffection", {}).values():
		result = maxi(result, int(value))
	for value in state.get("npcEncounterScheduling", {}).get("affections", {}).values():
		result = maxi(result, int(value))
	return result
