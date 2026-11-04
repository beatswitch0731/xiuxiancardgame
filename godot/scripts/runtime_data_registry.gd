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
	return resource if resource is Texture2D else null


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
		for frame in authored_frames:
			if not frame is Dictionary or not frame.get("path") is String:
				return null
			var texture = load(CONTENT_ROOT + String(frame["path"]))
			if not texture is Texture2D:
				return null
			frames.add_frame("play", texture, float(frame.get("durationMs", 0)) / 1000.0)
		return frames
	return null
