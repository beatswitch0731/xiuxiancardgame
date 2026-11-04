extends RefCounted

# Browser NarrativeLedger.closeExpiredFacts runs on the authoritative decision
# clock. This projection changes only the candidate snapshot being committed.
var _content: RefCounted
var activation_index := 1

func _init(content: RefCounted) -> void:
	_content = content

func settle(candidate: Dictionary, decision_index: int) -> bool:
	if decision_index < activation_index:
		return true
	var document: Variant = _content.read_module("narrative:causal_graph")
	var flow: Variant = candidate.get("noncombatFlow", {})
	if not document is Dictionary or document.get("version") != 1 \
			or not flow is Dictionary or not flow.get("spineFacts", {}) is Dictionary \
			or not flow.get("spineConsumptions", {}) is Dictionary:
		return false
	var definitions: Dictionary = {}
	for raw in document.get("factTypes", []):
		if raw is Dictionary and raw.get("factTypeId") is String:
			definitions[raw["factTypeId"]] = raw
	var facts: Dictionary = flow.get("spineFacts", {})
	var consumptions: Dictionary = flow.get("spineConsumptions", {})
	for fact_id in facts:
		var fact: Variant = facts[fact_id]
		if not fact is Dictionary or fact.get("factInstanceId") != fact_id:
			return false
		if fact.get("status") != "active":
			continue
		var definition: Dictionary = definitions.get(fact.get("factTypeId"), {})
		if definition.is_empty():
			return false
		var still_open := false
		var terminal: Dictionary = {}
		var settle_count := 0
		for raw_consumer in definition.get("consumers", []):
			if not raw_consumer is Dictionary or raw_consumer.get("mode") == "observe":
				continue
			settle_count += 1
			var key := String(fact_id) + ":" + String(raw_consumer.get("consumerId", ""))
			if consumptions.has(key):
				continue
			if terminal.is_empty():
				terminal = raw_consumer
			if decision_index <= int(fact.get("createdDecisionIndex", -1)) \
					+ int(raw_consumer.get("latestDecisionOffset", -1)):
				still_open = true
		if settle_count == 0 or still_open:
			continue
		fact["status"] = "closed"
		fact["closedDecisionIndex"] = decision_index
		fact["terminalClosure"] = terminal.get("terminalClosure",
			"这条线索已无从追查。")
	candidate["causalFactClockVersion"] = 1
	if not candidate.has("causalFactClockActivationIndex"):
		candidate["causalFactClockActivationIndex"] = activation_index
	return true
