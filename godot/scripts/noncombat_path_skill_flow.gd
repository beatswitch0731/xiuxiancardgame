extends RefCounted

# PathSkillSystem's authority is the current life's path and realm. The
# activation index only protects decisions committed before this migration.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const REALM_ORDER := ["qi", "foundation", "golden", "nascent", "deity", "tribulation"]
const MODULE := "config:path_skills"

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()


func activation_valid(state: Dictionary) -> bool:
	var value: Variant = state.get("pathSkillActivationIndex")
	var pending_battle: bool = state.get("phase") in ["WARNING_PENDING", "BATTLE_PENDING"]
	var latest := int(state.get("runClock", {}).get("decisionIndex", -1)) + (
		2 if pending_battle else 1)
	return (value is int or value is float) and float(value) == floorf(float(value)) \
		and int(value) >= 1 and int(value) <= latest


func bonuses(state: Dictionary) -> Dictionary:
	last_error = ""
	var path: String = String(state.get("path", ""))
	var current_index := REALM_ORDER.find(state.get("realm"))
	var document: Variant = _content.read_module(MODULE)
	if not document is Dictionary or not document.get("skills") is Dictionary:
		last_error = "功法技能来源不可用"
		return {}
	var path_row: Variant = document.skills.get(path)
	if current_index < 0 or not path_row is Dictionary \
			or not path_row.get("skills") is Array:
		last_error = "当前流派或境界没有功法技能定义"
		return {}
	var result := {}
	for skill in path_row.skills:
		if not skill is Dictionary or not skill.get("unlockRealm") is String \
				or not skill.get("passive") is Dictionary:
			last_error = "功法技能定义无效"
			return {}
		var unlock_index := REALM_ORDER.find(skill.unlockRealm)
		if unlock_index < 0:
			last_error = "功法技能解锁境界无效"
			return {}
		if current_index < unlock_index:
			continue
		for key in skill.passive:
			var value: Variant = skill.passive[key]
			if not (value is int or value is float):
				last_error = "功法技能被动数值无效"
				return {}
			result[key] = float(result.get(key, 0.0)) + float(value)
	return result


func active_bonuses(state: Dictionary, decision_index: int = -1) -> Dictionary:
	last_error = ""
	if not state.has("pathSkillActivationIndex"):
		return {}
	if not activation_valid(state):
		last_error = "功法技能启用序号无效"
		return {}
	var current_decision := decision_index if decision_index >= 0 else int(
		state.get("runClock", {}).get("decisionIndex", -1)) + 1
	if current_decision < int(state.pathSkillActivationIndex):
		return {}
	return bonuses(state)


func effect_delta(state: Dictionary, key: String, amount: int,
		card_id: String = "", decision_index: int = -1) -> int:
	var passive := active_bonuses(state, decision_index)
	if not last_error.is_empty():
		return amount
	var source: Dictionary = _content.find("card", card_id) if not card_id.is_empty() else {}
	var source_tags: Variant = source.get("data", {}).get("tags", [])
	var is_meditation: bool = card_id.contains("meditation") or (
		source_tags is Array and source_tags.has("cultivation"))
	if amount > 0 and key in ["cultivation", "daoHeart", "aura"] \
			and is_meditation:
		var multiplier := float(passive.get("meditationBonus", 0.0))
		if multiplier > 0.0:
			amount = floori(float(amount) * multiplier)
	if key == "daoHeart" and amount < 0:
		var resist := float(passive.get("daoResist", 0.0))
		if resist > 0.0:
			amount += floori(float(-amount) * resist)
	if key == "spiritStone" and amount > 0:
		var ratio := float(passive.get("spiritStoneBonus", 0.0))
		if ratio > 0.0:
			amount += floori(float(amount) * ratio)
	return amount


func actual_max_health(state: Dictionary, decision_index: int = -1) -> int:
	var base := LegacyFragmentFlow.actual_max_health(state)
	var passive := active_bonuses(state, decision_index)
	return base + int(passive.get("maxHp", 0)) if last_error.is_empty() else base


func breakthrough_cultivation_bonus(state: Dictionary, next_threshold: int,
		pill_used: bool, decision_index: int = -1) -> int:
	last_error = ""
	if not pill_used or next_threshold <= 0:
		return 0
	var passive := active_bonuses(state, decision_index)
	if not last_error.is_empty():
		return 0
	var ratio := clampf(float(passive.get("pillBreakthroughCultivationRatio", 0.0)), 0.0, 1.0)
	return floori(float(next_threshold) * ratio)


func dungeon_bonus(state: Dictionary, decision_index: int = -1) -> int:
	var passive := active_bonuses(state, decision_index)
	return int(passive.get("dungeonBonus", 0)) if last_error.is_empty() else 0


func apply_dungeon_completion(state: Dictionary, outcome: String,
		decision_index: int) -> bool:
	if outcome != "success":
		return true
	var bonus := dungeon_bonus(state, decision_index)
	if not last_error.is_empty():
		return false
	if bonus > 0:
		state["attributes"]["cultivation"] = mini(100,
			int(state["attributes"].get("cultivation", 0)) + bonus)
		state["resources"]["spiritStone"] = int(state["resources"].get(
			"spiritStone", 0)) + bonus
	return true
