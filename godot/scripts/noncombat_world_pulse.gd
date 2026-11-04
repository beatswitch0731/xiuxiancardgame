extends RefCounted

# WorldPulseSystem.js owns a narrative signal, not combat modifiers.
const SOURCE_JS_SHA := "48eac7adf17b94a0dce900ea61c1d9dfde20f23d7a6455cfb0935c21dca2e250"
const HEADLINES := {
	"serene": "灵脉平稳，诸宗暂息兵戈。",
	"bustling": "商路繁忙，坊市流言比灵石更快。",
	"mystery": "旧日禁制松动，失落的真相正在浮现。",
	"ominous": "魔气越过边界，正邪盟约摇摇欲坠。",
	"crisis": "天下暗流汇聚，下一次选择可能改变格局。",
	"flourishing": "你留下的善意正在陌生之处开花。",
	"scarcity": "灵脉与商路同时收紧，各方开始争夺资源。",
	"revelation": "证据开始相互印证，天道的裂缝已无法遮掩。",
}


static func initial(state: Dictionary, activation_index: int = 0) -> Dictionary:
	return {"version": 1, "activationIndex": activation_index,
		"ruleSha": SOURCE_JS_SHA, "lastBroadcastTurn": -1,
		"state": {"instability": 18, "scarcity": 22, "hope": 50,
			"truth": mini(100, state.get("clues", []).size() * 12),
			"dominantTag": "serene", "lastCause": "轮回初醒"}}


static func valid(snapshot: Variant) -> bool:
	if not snapshot is Dictionary or snapshot.get("version") != 1 \
			or snapshot.get("ruleSha") != SOURCE_JS_SHA \
			or not _integer(snapshot.get("activationIndex")) \
			or int(snapshot.activationIndex) < 0 \
			or not _integer(snapshot.get("lastBroadcastTurn")) \
			or not snapshot.get("state") is Dictionary:
		return false
	var values: Dictionary = snapshot.state
	for key in ["instability", "scarcity", "hope", "truth"]:
		if not (values.get(key) is int or values.get(key) is float) \
				or float(values.get(key, -1)) < 0.0 \
				or float(values.get(key, -1)) > 100.0:
			return false
	return values.get("dominantTag") in HEADLINES \
		and values.get("lastCause") is String


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value))


static func settle(prior: Dictionary, candidate: Dictionary,
		card: Dictionary = {}, choice: Dictionary = {}, combat_outcome: String = "") -> bool:
	var snapshot: Variant = candidate.get("worldPulseState")
	if not valid(snapshot):
		return false
	if prior.get("runClock", {}).get("lifeId") != candidate.get(
			"runClock", {}).get("lifeId"):
		return true # A new life has already reset the pulse and inherited clues.
	var pulse: Dictionary = snapshot.state
	var old_clues := {}
	for clue in prior.get("clues", []):
		if clue is Dictionary:
			old_clues[String(clue.get("id", ""))] = true
	for clue in candidate.get("clues", []):
		if clue is Dictionary and not old_clues.has(String(clue.get("id", ""))):
			_adjust(pulse, {"truth": 12, "instability": 1}, "truth",
				String(candidate.get("currentLocation", "")))
	var old_progress: Variant = prior.get("factionProgress")
	if old_progress is Dictionary and old_progress.get("undercurrentStages") is Dictionary:
		var before_stages: Dictionary = old_progress.undercurrentStages
		for undercurrent_id in candidate.get("factionProgress", {}).get(
				"undercurrentStages", {}):
			var stage := int(candidate.factionProgress.undercurrentStages[undercurrent_id])
			if stage != int(before_stages.get(undercurrent_id, 0)):
				_adjust(pulse, {"instability": maxi(1, stage)}, "faction",
					String(candidate.get("currentLocation", "")))
	if not choice.is_empty():
		var effects: Dictionary = choice.get("effects", {})
		var delta := {}
		if float(effects.get("karmaGood", 0)) > 0.0:
			delta["hope"] = 2
		if float(effects.get("karmaBad", 0)) > 0.0:
			delta["instability"] = 2
			delta["hope"] = int(delta.get("hope", 0)) - 1
		if float(effects.get("spiritStone", 0)) < 0.0:
			delta["scarcity"] = -1
		if choice.get("triggerCombat") == true or effects.get(
				"triggerCombat") == true or card.get("type") == "COMBAT":
			delta["instability"] = int(delta.get("instability", 0)) + 1
		if card.get("type") in ["LOCATION", "STORY"]:
			delta["hope"] = int(delta.get("hope", 0)) + 1
		var cause := String(card.get("title", ""))
		if cause.is_empty():
			cause = String(choice.get("text", ""))
		if cause.is_empty():
			cause = "无名选择"
		_adjust(pulse, delta, cause,
			String(candidate.get("currentLocation", "")))
	if combat_outcome == "victory":
		_adjust(pulse, {"hope": 2, "instability": -1}, "victory",
			String(candidate.get("currentLocation", "")))
	elif combat_outcome == "defeat":
		_adjust(pulse, {"hope": -2, "instability": 2}, "defeat",
			String(candidate.get("currentLocation", "")))
	if not choice.is_empty() or prior.get("currentLocation") != candidate.get(
			"currentLocation"):
		# Browser emits card:chosen before commitTopLevelDecision advances turn.
		snapshot["lastBroadcastTurn"] = int(prior.get("turn", 0))
	snapshot["state"] = pulse
	candidate["worldPulseState"] = snapshot
	return true


static func project(snapshot: Variant, location: String) -> Dictionary:
	if not valid(snapshot):
		return {}
	var result: Dictionary = snapshot.state.duplicate(true)
	var mood := _mood(result, location)
	result["dominantTag"] = mood
	result["headline"] = HEADLINES[mood]
	return result


static func _adjust(pulse: Dictionary, delta: Dictionary,
		cause: String, location: String) -> void:
	for key in ["instability", "scarcity", "hope", "truth"]:
		if delta.has(key):
			pulse[key] = clampf(float(pulse[key]) + float(delta[key]), 0.0, 100.0)
	pulse["lastCause"] = cause if not cause.is_empty() else pulse["lastCause"]
	pulse["dominantTag"] = _mood(pulse, location)


static func _mood(pulse: Dictionary, location: String) -> String:
	if float(pulse.truth) >= 60.0:
		return "revelation"
	if float(pulse.instability) >= 65.0:
		return "crisis"
	if float(pulse.hope) >= 70.0:
		return "flourishing"
	if float(pulse.scarcity) >= 65.0:
		return "scarcity"
	if location in ["秘境", "天道虚空"]:
		return "mystery"
	if location == "魔域":
		return "ominous"
	if location == "坊市":
		return "bustling"
	return "serene"
