extends RefCounted

# P88 catalog invitations. The director owns cadence; this owner materializes
# the source card and commits ordinary avoidance without a teaching promise.
const Catalog = preload("res://scripts/noncombat_catalog_encounter.gd")
const Director = preload("res://scripts/noncombat_encounter_director.gd")
const Milestone = preload("res://scripts/noncombat_milestone_flow.gd")
const NormalChoice = preload("res://scripts/noncombat_normal_choice_policy.gd")
var last_error := ""
var source_error := ""
var _content: RefCounted
var _gateway: RefCounted
var _catalog: RefCounted
var _director: RefCounted

func _init(content: RefCounted, gateway: RefCounted) -> void:
	_content = content
	_gateway = gateway
	_catalog = Catalog.new(content)
	_director = Director.new(content)


func initial_state(life_id: int) -> Dictionary:
	return _director.initial_state(life_id)

func marker(activation: int, higher_activation: int = -1) -> Dictionary:
	last_error = ""
	source_error = ""
	var hashes: Dictionary = _catalog.source_hashes()
	var director_pins: Dictionary = _director.source_rule_pins()
	if hashes.is_empty() or director_pins.is_empty():
		_copy_error(_catalog if hashes.is_empty() else _director)
		return {}
	var pins: Dictionary = _catalog.source_rule_pins()
	pins.merge(director_pins, true)
	var result := {"version": 1, "activationIndex": activation,
		"rulePins": pins, "sourceHashes": hashes}
	if higher_activation >= 0:
		result["higherRealmActivationIndex"] = higher_activation
	return result

func validate_marker(state: Dictionary) -> bool:
	var saved: Variant = state.get("encounterCadence")
	if not saved is Dictionary:
		return false
	var activation: Variant = saved.get("activationIndex")
	if not (activation is int or activation is float) \
			or float(activation) != floorf(float(activation)) or activation < 0 \
			or activation > int(state.get("runClock", {}).get("decisionIndex", -1)):
		return false
	var higher: Variant = saved.get("higherRealmActivationIndex", -1)
	if not (higher is int or higher is float) or float(higher) != floorf(float(higher)) \
			or int(higher) < -1 or int(higher) > int(state.get(
				"runClock", {}).get("decisionIndex", -1)) + 1:
		return false
	var expected := marker(int(activation), int(higher))
	if expected.is_empty():
		return false
	if not _same(saved, expected):
		source_error = "SOURCE_MISMATCH"
		last_error = "定期遭遇来源标记不匹配"
		return false
	return true

func resume(state: Dictionary) -> Dictionary:
	last_error = ""
	source_error = ""
	if state.get("phase") != "FLOW_PENDING" or state.get("realm") not in [
			"qi", "foundation", "golden", "nascent", "deity", "tribulation"] \
			or not state.has("encounterCadence"):
		return {}
	if state.get("realm") not in ["qi", "foundation"] and int(state.get(
			"runClock", {}).get("decisionIndex", -1)) < int(state.get(
			"encounterCadence", {}).get("higherRealmActivationIndex", 2147483647)):
		return {}
	if not validate_marker(state):
		return {}
	var candidates: Array = _catalog.candidates(state)
	if not _catalog.last_error.is_empty():
		_copy_error(_catalog)
		return {}
	var director: Dictionary = _director.schedule(state, candidates)
	if director.is_empty():
		_copy_error(_director)
		return {}
	var next := state.duplicate(true)
	next.noncombatFlow.encounterDirectorState = director
	if director.get("pending") == null:
		return next
	var source: Dictionary = _catalog.card(state, String(director.pending.cardId))
	if source.is_empty():
		_copy_error(_catalog)
		return {}
	next["pendingCadenceCard"] = source
	next["currentCardId"] = source.id
	next["phase"] = "COMBAT_HANDOFF"
	next["decisionCheckpoint"] = {"version": 1, "cardId": source.id,
		"turn": state.turn, "decisionIndex": state.runClock.decisionIndex,
		"flowSource": "encounter:cadence"}
	if _gateway.offer_from_state(next).is_empty():
		source_error = _gateway.source_error
		last_error = "定期遭遇原卡或原图不可用"
		return {}
	return next

func card(state: Dictionary) -> Dictionary:
	last_error = ""
	source_error = ""
	if state.get("phase") != "COMBAT_HANDOFF" or not state.has("pendingCadenceCard"):
		return {}
	if _gateway.offer_from_state(state).is_empty():
		source_error = _gateway.source_error
		last_error = "定期遭遇来源校验失败"
		return {}
	return state.pendingCadenceCard.duplicate(true)

func avoid(state: Dictionary) -> Dictionary:
	var current := card(state)
	if current.is_empty():
		return {}
	var choice: Dictionary = current.get("choices", {}).get("right", {})
	if choice.is_empty() or choice.get("costCheck") not in [null, {}]:
		return {}
	var director: Dictionary = _director.settled(state, current, "avoided", "right")
	if director.is_empty():
		_copy_error(_director)
		return {}
	var next := state.duplicate(true)
	var effects := Milestone.new(_content)
	for key in choice.get("effects", {}):
		var value: Variant = choice.effects[key]
		if key == "knowledge" and (value is int or value is float) \
				and float(value) == floorf(float(value)):
			next["knowledge"]["world"] = int(next.get("knowledge", {}).get("world", 0)) + int(value)
		elif key == "pills" and value is String and not String(value).is_empty() \
				and next.get("resources", {}).get("pills") is Dictionary:
			var pills: Dictionary = next.resources.pills
			pills[String(value)] = int(pills.get(String(value), 0)) + 1
		elif not effects._apply_effect(next, key, value):
			return {}
	next.resources.lifespan = maxi(0, int(next.resources.lifespan) - 1)
	var passive := NormalChoice.new(_content)
	if not passive._apply_passive_regen(next):
		last_error = passive.last_error
		return {}
	if int(next.attributes.health) <= 0 or int(next.attributes.daoHeart) <= 0 \
			or int(next.resources.lifespan) <= 0:
		last_error = "绕行触发的死亡结算尚未迁入，原存档已保留"
		return {}
	var index := int(state.turn) + 1
	next.choiceHistory.append({"cardId": current.id, "cardType": current.type,
		"direction": "right", "turn": state.turn, "decisionIndex": index,
		"tags": current.tags.duplicate(true)})
	while next.choiceHistory.size() > 30:
		next.choiceHistory.pop_front()
	next.recentCardTags.append_array(current.tags)
	while next.recentCardTags.size() > 20:
		next.recentCardTags.pop_front()
	next["turn"] = index
	next.runClock.decisionIndex = index
	var token := "decision:%s:choice:%s:%d" % [next.runClock.lifeId, current.id, index]
	next.runClock.receipts[token] = {"token": token, "decisionIndex": index,
		"sourceCardId": current.id, "kind": "choice"}
	Milestone.tick_seeds(next)
	next.noncombatFlow.encounterDirectorState = director
	next.erase("pendingCadenceCard")
	next["currentCardId"] = ""
	next["phase"] = "FLOW_PENDING"
	next["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": current.id, "turn": index, "decisionIndex": index, "flowPending": true}
	return next

func _copy_error(owner: RefCounted) -> void:
	last_error = owner.last_error
	source_error = owner.source_error

func _same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
