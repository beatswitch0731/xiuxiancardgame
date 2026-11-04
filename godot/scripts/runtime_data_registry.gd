extends RefCounted

const CONTENT_ROOT := "res://content/"

var _documents: Dictionary = {}
var _cards: Dictionary = {}
var _texture_aliases: Dictionary = {}
var _texture_aliases_loaded := false


func read_json(relative_path: String) -> Dictionary:
	if _documents.has(relative_path):
		return _documents[relative_path]
	var path := CONTENT_ROOT + relative_path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing migrated runtime data: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid migrated runtime JSON: " + path)
		return {}
	_documents[relative_path] = parsed
	return parsed


func get_battle_card(card_id: String) -> Dictionary:
	if _cards.is_empty():
		for card in read_json("data/cards/battle_cards.json").get("battle_cards", []):
			if card is Dictionary and card.has("id"):
				_cards[String(card["id"])] = card
	if card_id.ends_with("+") and not _cards.has(card_id):
		var base_id := card_id.trim_suffix("+")
		if base_id.ends_with("+"):
			return {}
		var base: Dictionary = _cards.get(base_id, {})
		var rules: Dictionary = read_json("data/combat/deck_progression.json").get(
			"upgradeRules", {})
		if base.is_empty() or not rules.get("effectPriority") is Array \
				or not rules.get("effectDelta") is Dictionary:
			return {}
		var upgraded: Dictionary = base.duplicate(true)
		upgraded["id"] = card_id
		upgraded["name"] = String(base.get("name", base_id)) + "+"
		upgraded["cost"] = int(base.get("cost", 0))
		var selected_type := ""
		for effect_type in rules["effectPriority"]:
			if upgraded.get("effects", []).any(func(effect: Variant) -> bool:
				return effect is Dictionary and effect.get("type") == effect_type):
				selected_type = String(effect_type)
				break
		if not selected_type.is_empty():
			for effect in upgraded["effects"]:
				if effect.get("type") != selected_type:
					continue
				var before := int(effect.get("value", 0))
				var after := before + int(rules["effectDelta"].get(selected_type, 0))
				effect["value"] = after
				var labels := {"damage": "伤害", "block": "护盾", "heal": "恢复",
					"gain_qi": "真元"}
				var status_labels := {"sword_intent": "剑意", "spell_seal": "法印",
					"fortify": "金刚罡劲", "weak": "虚弱",
					"vulnerable": "易伤", "poison": "丹毒"}
				var label := String(status_labels.get(effect.get("statusId"),
					"状态层数")) if selected_type == "status" else String(
					labels.get(selected_type, selected_type))
				upgraded["description"] = String(base.get("description",
					base.get("desc", ""))) + "\n【强化后主效果：%s %d（原 %d）】" % [
						label, after, before]
				break
		else:
			upgraded["description"] = String(base.get("description",
				base.get("desc", ""))) + "\n【强化后：效果不变】"
		_cards[card_id] = upgraded
	return _cards.get(card_id, {})


func get_first_encounter() -> Dictionary:
	for encounter in read_json("data/combat/encounters.json").get("encounters", []):
		if encounter is Dictionary and encounter.get("id") == "enc_trial_sword_swift":
			return encounter
	return {}


func get_first_presentation() -> Dictionary:
	return read_json("data/combat/encounter_presentations.json").get("presentations", {}).get("enc_trial_sword_swift", {})


func get_sword_actor() -> Dictionary:
	return read_json("data/combat/path_presentations.json").get("paths", {}).get("sword", {}).get("actorCard", {})


## 缺失登记表：解析后的运行路径 -> 命中次数。由 missing_texture_report() 读取。
var missing_textures: Dictionary = {}
var missing_frame_count: int = 0
var _placeholder_texture_cache: Texture2D = null


func texture_for(source_path: String) -> Texture2D:
	if not source_path.begins_with("assets/"):
		return null
	if not _texture_aliases_loaded:
		_texture_aliases_loaded = true
		for entry in read_json("source_manifest.json").get("runtimeAliases", []):
			if entry is Dictionary and entry.get("sourcePath") is String \
					and entry.get("runtimePath") is String:
				_texture_aliases[entry["sourcePath"]] = entry["runtimePath"]
	var runtime_path: String = _texture_aliases.get(source_path, source_path)
	var resource = load(CONTENT_ROOT + runtime_path)
	if not resource is Texture2D:
		# 保持返回 null 的既有契约：战斗场景用 `texture_for(...) == null` 判定
		# 资源可用性，改成返回占位图会让这些校验永远通过、掩盖真实缺失。
		_record_missing(CONTENT_ROOT + runtime_path)
		return null
	return resource


func _record_missing(full_path: String) -> void:
	missing_textures[full_path] = int(missing_textures.get(full_path, 0)) + 1
	push_warning("[ASSET_MISSING][texture] " + full_path)


func missing_texture_report() -> Dictionary:
	return missing_textures.duplicate(true)


## 洋红占位纹理：让"缺图"在截图里一眼可见，而不是看起来正常的空白。
## 仅供需要显式暴露缺失的调用方使用（非战斗 UI 经各自的 wrapper 调用）；
## 不要用它替换 texture_for 的返回语义。
func placeholder_texture() -> Texture2D:
	if _placeholder_texture_cache != null:
		return _placeholder_texture_cache
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	image.fill(Color(1.0, 0.0, 1.0))
	_placeholder_texture_cache = ImageTexture.create_from_image(image)
	return _placeholder_texture_cache


func sprite_frames_for(source_path: String) -> SpriteFrames:
	if not source_path.begins_with("assets/"):
		return null
	for entry in read_json("source_manifest.json").get("animatedMedia", []):
		if not entry is Dictionary or entry.get("sourcePath") != source_path:
			continue
		var authored_frames: Array = entry.get("frames", [])
		if authored_frames.is_empty():
			return null
		var frames := SpriteFrames.new()
		frames.add_animation("play")
		frames.set_animation_speed("play", 1.0)
		frames.set_animation_loop("play", true)
		# 逐帧容错：单帧缺失时跳过该帧并登记，而不是让整段动画作废。
		# 历史上的拷贝是逐目录截断的（源 4 帧只拷 1~3 帧），"全或无"判定
		# 会把这类局部缺失放大成"敌人完全不动"。
		for frame in authored_frames:
			var frame_path := String(frame["path"]) if frame is Dictionary \
					and frame.get("path") is String else ""
			if frame_path.is_empty():
				missing_frame_count += 1
				push_warning("[ASSET_MISSING][frame] malformed frame in " + source_path)
				continue
			var texture = load(CONTENT_ROOT + frame_path)
			if not texture is Texture2D:
				missing_frame_count += 1
				push_warning("[ASSET_MISSING][frame] " + CONTENT_ROOT + frame_path)
				continue
			frames.add_frame("play", texture, float(frame.get("durationMs", 0)) / 1000.0)
		if frames.get_frame_count("play") == 0:
			push_warning("[ASSET_MISSING][animation] 0 frames survived: " + source_path)
			return null
		return frames
	return null
