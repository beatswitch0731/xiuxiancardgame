extends RefCounted

# Read-only Godot counterpart of HeavenlyGallery.buildCatalog. Entries retain
# authored JSON nodes and their structural addresses; opening them never changes
# a run or settles a choice.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const CompanionWhisper = preload("res://scripts/noncombat_companion_whisper.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const MANIFEST := "res://content/source_manifest.json"
const CATEGORIES := {"all": "全部", "portraits": "人物立绘", "people": "人物秘闻",
	"story": "剧情与命线", "skills": "功法与战斗卡", "items": "器物丹药",
	"fragments": "传承残卷", "endings": "结局与真相"}

var _repository: RefCounted
var _whisper := CompanionWhisper.new()
var _entries: Array[Dictionary] = []
var _ready := false


func _init(repository: RefCounted = null) -> void:
	_repository = repository if repository != null else ContentRepository.new()


func entries() -> Array[Dictionary]:
	if not _ready:
		_build()
	return _entries.duplicate(true)


func filter(category: String, query: String = "") -> Array[Dictionary]:
	if not CATEGORIES.has(category):
		return []
	if not _ready:
		_build()
	var needle := query.strip_edges().to_lower()
	var found: Array[Dictionary] = []
	for entry in _entries:
		if category != "all" and entry.category != category:
			continue
		var search := "%s %s %s %s %s" % [entry.title, entry.subtitle,
			entry.id, entry.data.get("description", ""), entry.data.get("desc", "")]
		if needle.is_empty() or search.to_lower().contains(needle):
			found.append(entry.duplicate(true))
	return found


func _build() -> void:
	_ready = true
	var portrait_data: Variant = _repository.read_module("companions:portrait_stages")
	var portraits: Dictionary = portrait_data.get("portraitStages", {}) \
		if portrait_data is Dictionary else {}
	for comp_id in portraits:
		var definition: Dictionary = portraits[comp_id]
		for stage in definition.get("stages", []):
			if stage is Dictionary:
				_entries.append({"key": "portrait:" + String(stage.get("id", "")),
					"id": String(stage.get("id", "")), "category": "portraits",
					"title": String(stage.get("name", "")),
					"subtitle": String(definition.get("name", "")),
					"asset": String(stage.get("asset", "")),
					"data": stage, "module": "companions:portrait_stages",
					"address": String(comp_id) + "/" + String(stage.get("id", ""))})
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not manifest is Dictionary or not manifest.get("data") is Array:
		return
	for record in manifest.data:
		if not record is Dictionary:
			continue
		var path := String(record.get("path", ""))
		if not path.begins_with("data/") or not path.ends_with(".json"):
			continue
		var parts := path.trim_prefix("data/").trim_suffix(".json").split("/")
		if parts.size() != 2:
			continue
		var module_id := "%s:%s" % [parts[0], parts[1]]
		if path == "data/npcs/core_npcs.json":
			module_id = "npcs:core"
		if not _gallery_module(module_id):
			continue
		var content: Variant = _repository.read_module(module_id)
		if content != null:
			_walk(module_id, content, [])
	for set_id in LegacyFragmentFlow.SET_IDS:
		var title: String = LegacyFragmentFlow.SET_NAMES[set_id]
		_entries.append({"key": "fragment:" + set_id, "id": set_id,
			"category": "fragments", "title": title, "subtitle": "传承残卷",
			"asset": "", "data": {"name": title,
				"description": LegacyFragmentFlow.SET_EFFECTS[set_id],
				"flavor": "集齐 8 片可成卷。"},
			"module": "LegacyFragmentSystem", "address": set_id})


func _gallery_module(module_id: String) -> bool:
	for prefix in ["cards:", "threads:", "quests:", "companions:",
			"npcs:", "world:", "shops:", "items:", "locations:", "narrative:"]:
		if module_id.begins_with(prefix):
			return module_id != "companions:portrait_stages"
	return module_id in ["config:path_skills", "progression:rebirth_tree",
		"progression:acquisition_opportunities", "combat:skill_acquisitions"]


func _walk(module_id: String, node: Variant, parts: Array) -> void:
	if node is Dictionary:
		_add(module_id, node, parts)
		for key in node:
			var value: Variant = node[key]
			if not String(key).begins_with("_") and (value is Dictionary or value is Array):
				_walk(module_id, value, parts + [String(key)])
	elif node is Array:
		for index in range(node.size()):
			var value: Variant = node[index]
			if value is Dictionary or value is Array:
				_walk(module_id, value, parts + [str(index)])


func _add(module_id: String, node: Dictionary, parts: Array) -> void:
	var title: Variant = node.get("title", node.get("name"))
	if not title is String or title.is_empty():
		return
	var has_text := false
	for field in ["description", "desc", "summary", "firstMeeting", "text",
			"epilogue", "flavor"]:
		if node.get(field) is String and not String(node[field]).strip_edges().is_empty():
			has_text = true
	if not has_text and not node.has("choices") and not node.has("leftText") \
			and not node.has("rightText"):
		return
	var category := "story"
	if module_id == "npcs:core":
		category = "people"
	elif module_id == "world:truth_atlas":
		category = "endings"
	elif module_id.begins_with("shops:") or module_id.begins_with("items:"):
		category = "items"
	elif module_id in ["config:path_skills", "cards:battle_cards",
			"combat:skill_acquisitions", "progression:rebirth_tree"]:
		category = "skills"
	var asset := ""
	for field in ["sceneImage", "image", "asset", "portrait"]:
		if node.get(field) is String and _image_path(String(node[field])):
			asset = String(node[field])
			break
	if category == "people" and node.get("id") is String:
		asset = _whisper.npc_portrait_path(String(node.id))
	var address := "/".join(parts)
	_entries.append({"key": module_id + ":" + address,
		"id": String(node.get("id", address)), "category": category,
		"title": title, "subtitle": CATEGORIES[category], "asset": asset,
		"data": node, "module": module_id, "address": address})


func _image_path(path: String) -> bool:
	var lower := path.to_lower().split("?")[0]
	return lower.ends_with(".png") or lower.ends_with(".webp") \
		or lower.ends_with(".jpg") or lower.ends_with(".jpeg")
