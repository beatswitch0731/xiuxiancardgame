extends RefCounted

const MODULE := "companions:portrait_stages"

var _content: RefCounted


static func canonical_id(comp_id: String) -> String:
	return {"tian_ji": "tianji_laoren", "xue_sha": "xuesha_laozu",
		"jiuwei": "jiuwei_suyue"}.get(comp_id, comp_id)


func _init(content: RefCounted) -> void:
	_content = content


func unlocked(comp_id: String, affection: int) -> Array[Dictionary]:
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		return []
	var stages: Variant = source.get("portraitStages", {}).get(
		comp_id, {}).get("stages", [])
	if not stages is Array:
		return []
	var result: Array[Dictionary] = []
	for stage in stages:
		if stage is Dictionary and stage.get("id") is String \
				and stage.get("asset") is String \
				and int(stage.get("affection", 0)) <= affection:
			result.append(stage.duplicate(true))
	return result


func selected(run: Dictionary, comp_id: String, affection: int,
		allow_intimate: bool = false) -> Dictionary:
	var stages := unlocked(comp_id, affection)
	if stages.is_empty():
		return {}
	var selected_id: Variant = run.get("companionCosmetics", {}).get(
		"selectedPortraitByNpc", {}).get(comp_id)
	for stage in stages:
		if stage.id == selected_id:
			return stage
	var eligible: Array[Dictionary] = []
	for stage in stages:
		if allow_intimate or stage.get("sceneGate") != "intimate_only":
			eligible.append(stage)
	return eligible.back() if not eligible.is_empty() else stages.back()
