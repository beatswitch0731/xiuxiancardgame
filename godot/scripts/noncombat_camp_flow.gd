extends RefCounted

const CARD_ID := "camp_meditation"
const MODULE_ID := "cards:camp"
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")

var _content: RefCounted
var last_error := ""


func _init(content: RefCounted) -> void:
	_content = content


func card() -> Dictionary:
	last_error = ""
	var source: Variant = _content.read_module(MODULE_ID)
	if not source is Array or source.size() != 1 or not source[0] is Dictionary:
		last_error = "洞府来源结构无效"
		return {}
	var result: Dictionary = source[0]
	if result.get("id") != CARD_ID or result.get("type") != "NORMAL" \
			or not result.get("choices") is Dictionary \
			or not result.get("sceneImage") is String:
		last_error = "洞府来源卡无效"
		return {}
	for direction in ["left", "right", "down", "up"]:
		var choice: Variant = result["choices"].get(direction)
		if not choice is Dictionary or not choice.get("effects") is Dictionary \
				or not choice.get("costCheck", {}) is Dictionary:
			last_error = "洞府选项结构无效"
			return {}
		var effects: Dictionary = choice["effects"]
		var cost: Dictionary = choice.get("costCheck", {})
		if cost.keys().any(func(key: Variant) -> bool: return key != "spiritStone") \
				or effects.keys().any(func(key: Variant) -> bool:
					return not key in ["health", "removeCard", "upgradeCard"]):
			last_error = "洞府来源有未迁入的效果"
			return {}
		match direction:
			"left":
				var healing: Variant = effects.get("health")
				if effects.size() != 1 or not (healing is int or healing is float) \
						or float(healing) != float(int(healing)) or int(healing) <= 0:
					last_error = "洞府疗伤效果无效"
					return {}
			"right":
				if effects.size() != 1 or effects.get("removeCard") != true:
					last_error = "洞府斩牌效果无效"
					return {}
			"down":
				if effects.size() != 1 or effects.get("upgradeCard") != true:
					last_error = "洞府强化效果无效"
					return {}
			"up":
				if not effects.is_empty() or not cost.is_empty():
					last_error = "洞府离开效果无效"
					return {}
	return result.duplicate(true)


func available(state: Dictionary, direction: String) -> bool:
	var source_card := card()
	if source_card.is_empty() or not source_card["choices"].has(direction):
		return false
	var choice: Dictionary = source_card["choices"][direction]
	var cost: Dictionary = choice.get("costCheck", {})
	var stone: Variant = cost.get("spiritStone", 0)
	if not (stone is int or stone is float) or float(stone) != float(int(stone)) \
			or int(stone) < 0 or int(state.get("resources", {}).get("spiritStone", 0)) < int(stone):
		return false
	var effects: Dictionary = choice["effects"]
	# EffectService.previewCardChoices disables an entirely capped numeric heal;
	# the always-executable departure choice prevents its capped fallback here.
	if effects.has("health"):
		return int(state.get("attributes", {}).get("health", 0)) < \
			LegacyFragmentFlow.actual_max_health(state)
	return true


func settle(state: Dictionary, direction: String) -> Dictionary:
	if not available(state, direction):
		return {}
	var choice: Dictionary = card()["choices"][direction]
	var next := state.duplicate(true)
	var cost := int(choice.get("costCheck", {}).get("spiritStone", 0))
	next["resources"]["spiritStone"] = int(next["resources"]["spiritStone"]) - cost
	if choice["effects"].has("health"):
		var amount: Variant = choice["effects"]["health"]
		if not (amount is int or amount is float) or float(amount) != float(int(amount)):
			return {}
		next["attributes"]["health"] = clampi(
			int(next["attributes"]["health"]) + int(amount), 0,
			LegacyFragmentFlow.actual_max_health(next))
	return next
