class_name NoncombatContentRepository
extends RefCounted

# Read-only index over the copied browser data. Source JSON and the generated
# manifest remain the only authored content; this class stores references and
# defensive copies, never rewritten cards or narrative rules.
const CONTENT_ROOT := "res://content/"
const MANIFEST_PATH := "res://content/source_manifest.json"
const MILESTONE_CATALOG := "res://content/derived/companion_milestones.json"
const MILESTONE_SOURCE_SHA := "bd6386d3fb6bae095ce312c5bac520129bbee18f692ba25cb6ccc7f13104adcb"
const MILESTONE_CATALOG_SHA := "d2f02a0918fcb381d772a6d1239df312e134ecaa792d4eefb087dc7eb63211a5"
const NPC_TEMPLATE_PATH := "res://content/derived/npc_encounter_templates.json"
const NPC_TEMPLATE_SHA := "5d4ea3eb4483c3d9603ac2ffb62b21d1b16c26fc6c9b0699219fc48cbb4c7b85"
const NPC_RULE_SHA := "913ccdd6a3eb4464e3d3ce91ac1761c18cf8f2ce9346eb4929f2bf291046e6c8"
const COMPANION_ARC_CATALOG := "res://content/derived/companion_arc_cards.json"
const COMPANION_ARC_CATALOG_SHA := "5fada85fc5722e865e24aff4cb41c8f81e3abc27683b15bb73e1c276d13977ef"
const STORY_RULE_SHA := "08cd0d1ac24caeae35629210a0f2de0a24a563c7e3c4ea2da3ffe346f8f0a1e4"
const RIPPLE_RULE_SHA := "b4bb05e930b97e607059b7802b6f0feb0d3723a3ae87ae95310aa8072c065e4c"
const RIPPLE_CATALOG_SHA := "3679b95d6e3df93435f4f9caec44fbd0709c0439166f37a086d8cebec9bcc2e5"
const RIPPLE_CATALOG := "res://content/derived/karma_ripple_templates.json"
const GAME_RULE_SHA := "73d5038d1427433134a644e314d9d501d772c0ba79f67f61f9a46c3e4f8e093b"
const HINT_RULE_SHA := "67f2f543bbbc04f340cee18afb00d7f43cbae28dd9e65d3eb2a15cac31ef12c2"
const HINT_CATALOG := "res://content/derived/heavens_hint_pool.json"
const HINT_CATALOG_SHA := "16946a5d930631f36a610ceb42cbb063ea7b68d56c15a7b814f688427f4df209"
const MODULE_ALIASES := {
	"npcs:core": "data/npcs/core_npcs.json",
	"protagonist:core": "data/protagonist.json",
}

var _manifest_ready := false
var _indexed := false
var _source_meta: Dictionary = {}
var _documents: Dictionary = {}
var _art_paths: Dictionary = {}
var _audio_paths: Dictionary = {}
var _media: Dictionary = {}
var _indexes: Dictionary = {"card": {}, "quest": {}, "thread": {}, "npc": {},
	"portrait": {}, "audio": {}, "generated_card": {}}
var _scene_images: Dictionary = {}
var _errors: Array[String] = []
var _manifest: Dictionary = {}
var _manifest_path := MANIFEST_PATH


func _init(manifest_path: String = MANIFEST_PATH) -> void:
	_manifest_path = manifest_path


func errors() -> Array[String]:
	return _errors.duplicate()


func module_path(module_id: String) -> String:
	if not _ensure_manifest():
		return ""
	var path: String = MODULE_ALIASES.get(module_id, "")
	if path.is_empty():
		var parts := module_id.split(":")
		if parts.size() != 2 or not _safe_segment(parts[0]) or not _safe_segment(parts[1]):
			return ""
		path = "data/%s/%s.json" % [parts[0], parts[1]]
	return path if _source_meta.has(path) else ""


func read_module(module_id: String) -> Variant:
	var path := module_path(module_id)
	return _read_source(path) if not path.is_empty() else null


func source_sha256(module_id: String) -> String:
	var path := module_path(module_id)
	if path.is_empty():
		return ""
	# A document may already be cached. Recheck its current packaged bytes so
	# a fingerprint cannot outlive a source-file change in this process.
	if FileAccess.get_sha256(CONTENT_ROOT + path) != String(_source_meta[path]):
		_errors.append("Source SHA mismatch: " + path)
		return ""
	if _read_source(path) == null:
		return ""
	return String(_source_meta[path])


func build_index() -> bool:
	if _indexed:
		return true
	if not _ensure_manifest():
		return false
	_indexes = {"card": {}, "quest": {}, "thread": {}, "npc": {},
		"portrait": {}, "audio": {}, "generated_card": {}}
	_scene_images = {}
	var paths: Array = _source_meta.keys()
	paths.sort()
	for path_value in paths:
		var path := String(path_value)
		var doc: Variant = _read_source(path)
		if doc == null:
			return false
		_index_document(path, doc)
	_index_surfacing_generated_cards()
	_index_ripple_templates()
	_index_cross_rules()
	_index_generated_runtime_rules()
	if not _errors.is_empty():
		return false
	var media_meta: Dictionary = _manifest.get("narrativeMedia", {})
	var media_path := String(media_meta.get("runtimeJson", ""))
	var media_sha := String(media_meta.get("runtimeSha256", ""))
	if media_path.is_empty() or media_sha.length() != 64 \
			or FileAccess.get_sha256(CONTENT_ROOT + media_path) != media_sha:
		_errors.append("Narrative media manifest hash mismatch: " + media_path)
		return false
	var parsed: Variant = _parse_json(CONTENT_ROOT + media_path)
	if not parsed is Dictionary:
		_errors.append("Narrative media mapping invalid: " + media_path)
		return false
	_media = parsed
	_indexed = true
	return true


func find(kind: String, source_id: String) -> Dictionary:
	if not build_index() or not _indexes.has(kind):
		return {}
	var row: Dictionary = _indexes[kind].get(source_id, {})
	return row.duplicate(true)


func index_count(kind: String) -> int:
	if not build_index() or not _indexes.has(kind):
		return 0
	return _indexes[kind].size()


func media_for(source_image_path: String) -> Dictionary:
	if not build_index():
		return {}
	var row: Variant = _media.get(source_image_path, {})
	return row.duplicate(true) if row is Dictionary else {}


func scene_image_references(source_path: String, verify_media: bool = true) -> Array:
	if not build_index() or not _source_meta.has(source_path):
		return []
	var references: Array = []
	for row in _scene_images.get(source_path, []):
		var result: Dictionary = row.duplicate(true)
		if verify_media:
			result.merge(_image_status(String(row["assetPath"])), true)
		else:
			result["listedInManifest"] = _art_paths.has(String(row["assetPath"]))
		references.append(result)
	return references


func card_scene_image_status(card_id: String) -> Dictionary:
	var row := find("card", card_id)
	if row.is_empty():
		return {}
	var path := String(row.get("data", {}).get("sceneImage", ""))
	var result := {
		"cardId": card_id,
		"sceneImage": path,
		"sourcePath": row["sourcePath"],
		"jsonPointer": row["jsonPointer"],
	}
	result.merge(_image_status(path), true)
	return result


func asset_status(path: String) -> Dictionary:
	if not _ensure_manifest():
		return {}
	return _image_status(path)


func audio_status(audio_id: String) -> Dictionary:
	var row := find("audio", audio_id)
	if row.is_empty():
		return {}
	var runtime: Dictionary = row.get("data", {})
	if runtime.get("path") == null and runtime.get("procedural") is Dictionary:
		return {"sourcePath": row.sourcePath, "jsonPointer": row.jsonPointer,
			"runtimePath": "", "disposition": "generated_stream",
			"listedInManifest": false, "fileExists": false,
			"shaVerified": false, "streamLoadable": false}
	var source: Variant = read_module("audio:path_identity")
	if not source is Dictionary:
		return {}
	var path := String(source.get("assetRoot", "")) + String(runtime.get("path", ""))
	var meta: Dictionary = _audio_paths.get(path, {})
	var full_path := CONTENT_ROOT + path
	var exists := FileAccess.file_exists(full_path)
	var verified := exists and not meta.is_empty() \
		and FileAccess.get_sha256(full_path) == String(meta.get("sha256", ""))
	return {"sourcePath": row.sourcePath, "jsonPointer": row.jsonPointer,
		"runtimePath": path, "disposition": "packaged_stream",
		"listedInManifest": not meta.is_empty(),
		"fileExists": exists, "shaVerified": verified,
		"streamLoadable": verified and load(full_path) is AudioStream}


func _image_status(path: String) -> Dictionary:
	var media_meta: Dictionary = _art_paths.get(path, {})
	var runtime_path := String(media_meta.get("runtimePath", ""))
	var full_path := CONTENT_ROOT + runtime_path
	var file_exists := not runtime_path.is_empty() and FileAccess.file_exists(full_path)
	var sha_verified := file_exists and FileAccess.get_sha256(full_path) == \
		String(media_meta.get("sha256", ""))
	return {
		"listedInManifest": not media_meta.is_empty(),
		"fileExists": file_exists,
		"shaVerified": sha_verified,
		"textureLoadable": sha_verified and load(full_path) is Texture2D,
		"runtimePath": runtime_path,
	}


func _ensure_manifest() -> bool:
	if _manifest_ready:
		return true
	var raw: Variant = _parse_json(_manifest_path)
	if not raw is Dictionary or not raw.get("data") is Array:
		_errors.append("Missing or invalid source manifest")
		return false
	_manifest = raw
	for entry in _manifest["data"]:
		if not entry is Dictionary:
			_errors.append("Invalid source manifest data entry")
			return false
		var path := String(entry.get("path", ""))
		var sha := String(entry.get("sha256", ""))
		if not path.begins_with("data/") or not path.ends_with(".json") \
				or path.contains("..") or sha.length() != 64 or _source_meta.has(path):
			_errors.append("Invalid or duplicate source manifest path: " + path)
			return false
		_source_meta[path] = sha
	for entry in _manifest.get("art", []):
		if entry is Dictionary and entry.get("path") is String \
				and entry.get("sha256") is String:
			_art_paths[entry["path"]] = {
				"runtimePath": entry["path"], "sha256": entry["sha256"]}
	for entry in _manifest.get("runtimeAliases", []):
		if entry is Dictionary and entry.get("sourcePath") is String \
				and entry.get("runtimePath") is String and entry.get("sha256") is String:
			_art_paths[entry["sourcePath"]] = {
				"runtimePath": entry["runtimePath"], "sha256": entry["sha256"]}
	for entry in _manifest.get("audio", []):
		if entry is Dictionary and entry.get("path") is String \
				and entry.get("sha256") is String:
			_audio_paths[entry["path"]] = entry
	_manifest_ready = true
	return true


func _read_source(relative_path: String) -> Variant:
	if not _source_meta.has(relative_path):
		return null
	if _documents.has(relative_path):
		return _documents[relative_path].duplicate(true)
	var path := CONTENT_ROOT + relative_path
	if not FileAccess.file_exists(path):
		_errors.append("Missing source copy: " + relative_path)
		return null
	if FileAccess.get_sha256(path) != _source_meta[relative_path]:
		_errors.append("Source SHA mismatch: " + relative_path)
		return null
	var parsed: Variant = _parse_json(path)
	if not parsed is Dictionary and not parsed is Array:
		_errors.append("Invalid source JSON: " + relative_path)
		return null
	_documents[relative_path] = parsed
	return parsed.duplicate(true)


func _parse_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null


func _index_document(path: String, doc: Variant) -> void:
	# Browser content nests authored choices under locations, companions, world
	# events, threads and NPCs as well as ordinary card arrays. Index the same
	# choice-node shape everywhere and preserve the exact source pointer.
	# The source catalog treats data/combat/ as a separate rules namespace.
	if not path.begins_with("data/combat/"):
		_index_choice_nodes(doc, path, "$")
		_index_scene_images(doc, path, "$")
	if not doc is Dictionary:
		return
	if path == "data/companions/portrait_stages.json":
		_index_portrait_stages(doc, path)
	if path == "data/companions/events.json":
		_index_companion_generated_cards(doc, path)
	if path == "data/companions/arcs.json":
		_index_companion_arc_cards(doc)
		_index_mentor_generated_cards(doc)
		_index_ally_generated_cards(doc)
		_index_seer_generated_cards(doc)
	if path == "data/cards/chapter_milestones.json":
		_index_realm_arrival_cards(doc, path)
	if path == "data/npcs/core_npcs.json":
		_index_companion_milestones(doc)
		_index_npc_generated_cards(doc)
		_index_companion_generic_cards(doc)
		_index_surfacing_affection_cards(doc)
	if path == "data/world/factions.json":
		_index_faction_generated_cards(doc, path)
	if path == "data/audio/path_identity.json":
		if doc.get("assetRoot") != "assets/audio/":
			_errors.append("Invalid audio asset root: " + path)
		else:
			_index_audio_runtime(doc, path, "$")
	if path.begins_with("data/quests/") and doc.get("quest") is Dictionary:
		_index_record("quest", doc["quest"].get("id"), doc["quest"], path, "$.quest")
	if path.begins_with("data/threads/") and doc.get("threads") is Array:
		for i in range(doc["threads"].size()):
			var thread: Variant = doc["threads"][i]
			if thread is Dictionary:
				_index_record("thread", thread.get("threadId"), thread, path,
					"$.threads[%d]" % i)
	if path.begins_with("data/npcs/") and doc.get("npcs") is Array:
		for i in range(doc["npcs"].size()):
			var npc: Variant = doc["npcs"][i]
			if npc is Dictionary:
				_index_record("npc", npc.get("id"), npc, path, "$.npcs[%d]" % i)


func _index_portrait_stages(doc: Dictionary, path: String) -> void:
	var groups: Variant = doc.get("portraitStages")
	if not groups is Dictionary:
		_errors.append("Missing portrait stages: " + path)
		return
	for comp_id in groups:
		var definition: Variant = groups[comp_id]
		if not definition is Dictionary or not definition.get("stages") is Array:
			_errors.append("Invalid portrait stages: %s $.portraitStages.%s" % [
				path, comp_id])
			continue
		for i in range(definition["stages"].size()):
			var stage: Variant = definition["stages"][i]
			var pointer := "$.portraitStages.%s.stages[%d]" % [comp_id, i]
			if not stage is Dictionary or not stage.get("id") is String \
					or String(stage.get("id", "")).is_empty() \
					or not stage.get("asset") is String \
					or String(stage.get("asset", "")).is_empty():
				_errors.append("Invalid portrait stage: %s %s" % [path, pointer])
				continue
			_index_record("portrait", stage["id"], stage, path, pointer)


func _index_companion_generated_cards(doc: Dictionary, path: String) -> void:
	var companions: Variant = doc.get("companions")
	if not companions is Array:
		_errors.append("Missing companion event producers: " + path)
		return
	for i in range(companions.size()):
		var companion: Variant = companions[i]
		var owner_pointer := "$.companions[%d]" % i
		if not companion is Dictionary or not companion.get("id") is String \
				or String(companion.get("id", "")).is_empty() \
				or not companion.get("events") is Array:
			_errors.append("Invalid companion producer: %s %s" % [path, owner_pointer])
			continue
		for j in range(companion.events.size()):
			var event: Variant = companion.events[j]
			var pointer := owner_pointer + ".events[%d]" % j
			if not event is Dictionary or not event.get("id") is String \
					or String(event.get("id", "")).is_empty():
				_errors.append("Invalid companion event producer: %s %s" % [path, pointer])
				continue
			var card_id := "comp_%s_%s" % [companion.id, event.id]
			if _indexes["generated_card"].has(card_id):
				_index_record("generated_card", card_id, event, path, pointer)
				continue
			_index_record("generated_card", card_id, event, path, pointer)
			var row: Dictionary = _indexes["generated_card"][card_id]
			row["companionId"] = companion.id
			row["producerBrowser"] = "src/systems/CompanionSystem.js::_buildEventCard"
			row["producerGodot"] = "res://scripts/noncombat_companion_events.gd::_build_card"
			row["reachability"] = {
				"ownedCompanion": true, "physicalPresence": true,
				"minAffection": int(event.get("minAffection", 0)),
				"minBond": int(event.get("minBond", 0)),
				"realm": event.get("realm"),
				"requiredFlag": event.get("requiredFlag"),
				"forbiddenFlag": event.get("forbiddenFlag"),
				"once": event.get("once", true),
				"repeatPolicy": event.get("repeatPolicy"),
				"runtimeGates": ["cooldown", "draw_chance", "narrative_eligibility"],
				"choiceValidation": {
					"choiceType": "Dictionary",
					"effectsType": "Dictionary",
					"allowedEffectKeys": ["cultivation", "daoHeart", "health", "fortune",
						"karmaGood", "karmaBad"],
					"effectValueType": "integer",
					"consumer": "res://scripts/noncombat_companion_events.gd::_eligible"}}
			var encounter_refs := {}
			var choices: Variant = event.get("choices")
			if choices is Dictionary:
				for direction in choices:
					var choice: Variant = choices[direction]
					if choice is Dictionary and choice.has("encounterId"):
						encounter_refs[direction] = {"encounterId": choice.encounterId,
							"jsonPointer": pointer + ".choices." + String(direction)}
			if not encounter_refs.is_empty():
				row["reachability"]["encounterDependency"] = {
					"choiceRefs": encounter_refs,
					"allowedCompanionId": "jian_linger",
					"allowedEventId": "jle_8_sword_tomb_old_master",
					"allowedEncounterId": "enc_companion_jian_linger_tomb",
					"requiresResolvableEncounter": true,
					"consumer": "res://scripts/noncombat_companion_events.gd::_eligible"}


func _index_companion_milestones(npc_catalog: Dictionary) -> void:
	if FileAccess.get_sha256(MILESTONE_CATALOG).to_lower() != MILESTONE_CATALOG_SHA:
		_errors.append("Companion milestone catalog SHA mismatch")
		return
	var catalog: Variant = _parse_json(MILESTONE_CATALOG)
	if not catalog is Dictionary or catalog.get("sourceSha") != MILESTONE_SOURCE_SHA \
			or not catalog.get("milestones") is Array \
			or not npc_catalog.get("npcs") is Array:
		_errors.append("Companion milestone producer source invalid")
		return
	for companion in npc_catalog.npcs:
		if not companion is Dictionary or not companion.get("id") is String:
			continue
		for j in range(catalog.milestones.size()):
			var spec: Variant = catalog.milestones[j]
			if not spec is Dictionary or not spec.get("id") is String \
					or not spec.get("card") is Dictionary:
				_errors.append("Invalid companion milestone template: %d" % j)
				continue
			var card_id := "comp_%s_milestone_%s" % [companion.id, spec.id]
			if _indexes["generated_card"].has(card_id):
				_errors.append("Duplicate generated_card ID: " + card_id)
				continue
			_indexes["generated_card"][card_id] = {
				"data": spec.duplicate(true),
				"sourcePath": "src/systems/CompanionSystem.js",
				"sourceLocation": "_buildMilestoneCard:milestoneData." + String(spec.id),
				"sourceSha256": MILESTONE_SOURCE_SHA,
				"derivedCatalogPath": "godot/content/derived/companion_milestones.json",
				"derivedCatalogPointer": "$.milestones[%d]" % j,
				"derivedCatalogSha256": MILESTONE_CATALOG_SHA,
				"companionId": companion.id,
				"producerBrowser": "src/systems/CompanionSystem.js::_buildMilestoneCard",
				"producerGodot": "res://scripts/noncombat_companion_events.gd::_milestone_card",
				"reachability": {"affectionThreshold": spec.get("threshold"),
					"direction": spec.get("direction"), "onceFlag":
					"comp_milestone_%s_%s" % [companion.id, spec.id],
					"requiresPhysicalPresenceAtDelivery": true,
					"sourceChoiceCrossing": true}}


func _index_npc_generated_cards(npc_catalog: Dictionary) -> void:
	if FileAccess.get_sha256(NPC_TEMPLATE_PATH).to_lower() != NPC_TEMPLATE_SHA:
		_errors.append("NPC generated card catalog SHA mismatch")
		return
	var catalog: Variant = _parse_json(NPC_TEMPLATE_PATH)
	if not catalog is Dictionary or catalog.get("sourceSha") != NPC_RULE_SHA \
			or not catalog.get("templates") is Dictionary:
		_errors.append("NPC generated card source invalid")
		return
	for npc in npc_catalog.get("npcs", []):
		if not npc is Dictionary or not npc.get("id") is String:
			continue
		var npc_id: String = npc.id
		var paths: Variant = catalog.templates.get(npc_id)
		if not paths is Dictionary or not paths.get("sword") is Dictionary:
			_errors.append("NPC generated card templates missing: " + npc_id)
			continue
		for scene in paths.sword:
			var card_id := "npc_encounter_%s_%s" % [npc_id, scene]
			if _indexes["generated_card"].has(card_id):
				_errors.append("Duplicate generated_card ID: " + card_id)
				continue
			var variants := {}
			for path in paths:
				variants[path] = {}
				var emotions: Variant = paths[path].get(scene)
				if not emotions is Dictionary:
					_errors.append("NPC generated card scene missing: " + card_id)
					continue
				for emotion in emotions:
					var card: Variant = emotions[emotion]
					if not card is Dictionary or card.get("id") != card_id:
						_errors.append("NPC generated card ID mismatch: " + card_id)
						continue
					variants[path][emotion] = {"pointer": "$.templates.%s.%s.%s.%s" % [
						npc_id, path, scene, emotion], "card": card.duplicate(true)}
			_indexes["generated_card"][card_id] = {
				"sourcePath": "src/systems/NpcSystem.js",
				"sourceLocation": "_buildEncounterCard:encounterCards." + String(scene),
				"sourceSha256": NPC_RULE_SHA,
				"derivedCatalogPath": "godot/content/derived/npc_encounter_templates.json",
				"derivedCatalogSha256": NPC_TEMPLATE_SHA,
				"npcSourcePath": "data/npcs/core_npcs.json",
				"npcSourceSha256": _source_meta.get("data/npcs/core_npcs.json"),
				"npcId": npc_id, "scene": scene, "variants": variants,
				"producerBrowser": "src/systems/NpcSystem.js::_buildEncounterCard",
				"producerGodot": "res://scripts/noncombat_npc_encounter_flow.gd::_general_card",
				"reachability": {"physicalPresence": true,
					"singleEncounterCap": 6, "sceneFromMemoriesAndAffection": true,
					"pathAndEmotionAtBuild": true}}


func _index_companion_generic_cards(npc_catalog: Dictionary) -> void:
	var authored: Variant = _documents.get("data/companions/events.json")
	if not authored is Dictionary or not authored.get("companions") is Array:
		_errors.append("Generic companion source owners unavailable")
		return
	var authored_ids := {}
	for row in authored.companions:
		if row is Dictionary and row.get("id") is String:
			authored_ids[row.id] = true
	var kinds := ["generic_daily", "generic_emo", "generic_help"]
	for npc in npc_catalog.get("npcs", []):
		if not npc is Dictionary or not npc.get("id") is String \
				or authored_ids.has(npc.id):
			continue
		for i in range(kinds.size()):
			var kind: String = kinds[i]
			var card_id := "comp_%s_%s" % [npc.id, kind]
			if _indexes["generated_card"].has(card_id):
				_errors.append("Duplicate generated_card ID: " + card_id)
				continue
			_indexes["generated_card"][card_id] = {
				"companionId": npc.id, "eventId": kind,
				"sourcePath": "src/systems/CompanionSystem.js",
				"sourceLocation": "_getGenericEvent:pool[%d]" % i,
				"sourceSha256": MILESTONE_SOURCE_SHA,
				"npcSourcePath": "data/npcs/core_npcs.json",
				"npcSourceSha256": _source_meta.get("data/npcs/core_npcs.json"),
				"producerBrowser": "src/systems/CompanionSystem.js::_getGenericEvent/_buildEventCard",
				"producerGodot": "res://scripts/noncombat_companion_events.gd::_generic_events/_build_card",
				"reachability": {"ownedCompanion": true,
					"noAuthoredEventPool": true, "physicalPresence": true,
					"repeatPolicy": {"mode": "cooldown", "cooldownTurns": 12},
					"runtimeGates": ["draw_chance", "narrative_eligibility"]}}


func _index_companion_arc_cards(authored: Dictionary) -> void:
	if FileAccess.get_sha256(COMPANION_ARC_CATALOG).to_lower() != COMPANION_ARC_CATALOG_SHA:
		_errors.append("Companion arc derived catalog SHA mismatch")
		return
	var catalog: Variant = _parse_json(COMPANION_ARC_CATALOG)
	var author_sha: String = String(_source_meta.get("data/companions/arcs.json", ""))
	if not catalog is Dictionary or catalog.get("ruleSha") != STORY_RULE_SHA \
			or catalog.get("dataSha") != author_sha \
			or not catalog.get("cards") is Dictionary \
			or not authored.get("companionArcs") is Dictionary:
		_errors.append("Companion arc producer source invalid")
		return
	for comp_id in catalog.cards:
		var rows: Variant = catalog.cards[comp_id]
		if not rows is Array or not authored.companionArcs.get(comp_id) is Dictionary:
			_errors.append("Companion arc owner source missing: " + String(comp_id))
			continue
		for i in range(rows.size()):
			var card: Variant = rows[i]
			if not card is Dictionary or not card.get("id") is String:
				_errors.append("Companion arc derived card invalid: %s[%d]" % [comp_id,i])
				continue
			var card_id: String = card.id
			if _indexes["generated_card"].has(card_id):
				_errors.append("Duplicate generated_card ID: " + card_id)
				continue
			var suffix: String = card_id.trim_prefix("arc_%s_" % comp_id)
			var author_key: String = suffix.trim_prefix("stage_") if suffix.begins_with("stage_") \
				else {"secret_reveal": "secretReveal", "tribulation": "tribulationClimax",
					"destiny": "destinyClimax"}.get(suffix, "")
			var author_branch: String = "arcStages." + author_key if suffix.begins_with(
				"stage_") else author_key
			var author_row: Variant = authored.companionArcs[comp_id].get(
				"arcStages", {}).get(author_key) if suffix.begins_with("stage_") \
				else authored.companionArcs[comp_id].get(author_key)
			if author_key.is_empty() or not author_row is Dictionary:
				_errors.append("Companion arc author pointer missing: " + card_id)
				continue
			_indexes["generated_card"][card_id] = {
				"data": card.duplicate(true), "companionId": comp_id,
				"sourcePath": "src/systems/StoryNetworkSystem.js",
				"sourceSha256": STORY_RULE_SHA,
				"authorPath": "data/companions/arcs.json",
				"authorPointer": "$.companionArcs.%s.%s" % [comp_id,author_branch],
				"authorSha256": author_sha,
				"derivedCatalogPath": "godot/content/derived/companion_arc_cards.json",
				"derivedCatalogPointer": "$.cards.%s[%d]" % [comp_id,i],
				"derivedCatalogSha256": COMPANION_ARC_CATALOG_SHA,
				"producerBrowser": "src/systems/StoryNetworkSystem.js",
				"producerGodot": "res://scripts/noncombat_companion_arc_flow.gd::_project",
				"reachability": {"ownedCompanion": true,
					"physicalPresenceAtDelivery": true,
					"arcStageOrClimax": suffix}}


func _index_mentor_generated_cards(authored: Dictionary) -> void:
	var mentor: Variant = authored.get("mentorArc", {}).get("bai_ren")
	if not mentor is Dictionary or not mentor.get("arcStages") is Dictionary:
		_errors.append("Mentor generated card source invalid")
		return
	var specs := []
	for stage in ["INNER_DISCIPLE", "TRUSTED", "HEIR", "LEGACY"]:
		specs.append({"id": "mentor_bai_ren_stage_" + stage,
			"authorKey": "arcStages." + stage, "data": mentor.arcStages.get(stage),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::_buildStageEvent"})
	for pair in [{"id": "mentor_bai_ren_tribulation",
			"key": "tribulationClimax", "producer": "_buildTribulationClimax"},
			{"id": "mentor_bai_ren_destiny", "key": "destinyClimax",
			"producer": "_buildDestinyClimax"}]:
		specs.append({"id": pair.id, "authorKey": pair.key,
			"data": mentor.get(pair.key),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::" + pair.producer})
	for spec in specs:
		var card_id: String = spec.id
		if not spec.data is Dictionary:
			_errors.append("Mentor generated card author field missing: " + card_id)
			continue
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": spec.data.duplicate(true), "npcId": "bai_ren",
			"sourcePath": "src/systems/StoryNetworkSystem.js",
			"sourceSha256": STORY_RULE_SHA,
			"authorPath": "data/companions/arcs.json",
			"authorPointer": "$.mentorArc.bai_ren." + String(spec.authorKey),
			"authorSha256": _source_meta.get("data/companions/arcs.json"),
			"producerBrowser": spec.producerBrowser,
			"producerGodot": "res://scripts/noncombat_mentor_flow.gd::_project_card",
			"reachability": {"physicalMentor": true,
				"progressionOrRealmGate": true, "authorKey": spec.authorKey}}


func _index_ally_generated_cards(authored: Dictionary) -> void:
	var ally: Variant = authored.get("allyArc", {}).get("xuesha_laozu")
	if not ally is Dictionary or not ally.get("arcStages") is Dictionary:
		_errors.append("Ally generated card source invalid")
		return
	var specs := []
	for stage in ["RECOGNITION", "TRUST", "COMRADE", "LEGACY"]:
		specs.append({"id": "ally_xuesha_laozu_stage_" + stage,
			"authorKey": "arcStages." + stage, "data": ally.arcStages.get(stage),
			"producer": "_buildStageEvent",
			"reachability": {"alignmentThreshold": {
				"RECOGNITION": 20, "TRUST": 40, "COMRADE": 60,
				"LEGACY": 80}[stage]}})
	for pair in [{"id": "ally_xuesha_laozu_revelation",
			"key": "revelation", "producer": "_buildRevelation",
			"minStageIndex": 3},
			{"id": "ally_xuesha_laozu_tribulation",
			"key": "tribulationClimax", "producer": "_buildTribulationClimax",
			"minStageIndex": 3, "minRealm": "golden"},
			{"id": "ally_xuesha_laozu_destiny",
			"key": "destinyClimax", "producer": "_buildDestinyClimax",
			"minStageIndex": 4, "minRealm": "deity"}]:
		var gate := {"minStageIndex": pair.minStageIndex}
		if pair.has("minRealm"):
			gate["minRealm"] = pair.minRealm
		specs.append({"id": pair.id, "authorKey": pair.key,
			"data": ally.get(pair.key), "producer": pair.producer,
			"reachability": gate})
	for spec in specs:
		var card_id: String = spec.id
		if not spec.data is Dictionary:
			_errors.append("Ally generated card author field missing: " + card_id)
			continue
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": spec.data.duplicate(true), "npcId": "xuesha_laozu",
			"sourcePath": "src/systems/StoryNetworkSystem.js",
			"sourceSha256": STORY_RULE_SHA,
			"authorPath": "data/companions/arcs.json",
			"authorPointer": "$.allyArc.xuesha_laozu." + String(spec.authorKey),
			"authorSha256": _source_meta.get("data/companions/arcs.json"),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::" + spec.producer,
			"producerGodot": "res://scripts/noncombat_ally_arc_flow.gd::_project",
			"reachability": {"physicalAlly": true,
				"gate": spec.reachability}}


func _index_seer_generated_cards(authored: Dictionary) -> void:
	var seer: Variant = authored.get("seerArc", {}).get("tianji_laoren")
	if not seer is Dictionary or not seer.get("arcStages") is Dictionary:
		_errors.append("Seer generated card source invalid")
		return
	var specs := []
	for stage in ["REVELATION", "UNVEILING", "SACRIFICE", "FINAL_PROPHECY"]:
		specs.append({"id": "seer_tianji_laoren_stage_" + stage,
			"authorKey": "arcStages." + stage, "data": seer.arcStages.get(stage),
			"producer": "_buildStageEvent",
			"reachability": {"revelationThreshold": {
				"REVELATION": 20, "UNVEILING": 40, "SACRIFICE": 60,
				"FINAL_PROPHECY": 80}[stage]}})
	for pair in [{"id": "seer_tianji_laoren_revelation",
			"key": "revelation", "producer": "_buildRevelation",
			"minStageIndex": 3},
			{"id": "seer_tianji_laoren_tribulation",
			"key": "tribulationClimax", "producer": "_buildTribulationClimax",
			"minStageIndex": 3, "minRealm": "golden"},
			{"id": "seer_tianji_laoren_destiny",
			"key": "destinyClimax", "producer": "_buildDestinyClimax",
			"minStageIndex": 4, "minRealm": "deity"}]:
		var gate := {"minStageIndex": pair.minStageIndex}
		if pair.has("minRealm"):
			gate["minRealm"] = pair.minRealm
		specs.append({"id": pair.id, "authorKey": pair.key,
			"data": seer.get(pair.key), "producer": pair.producer,
			"reachability": gate})
	for spec in specs:
		var card_id: String = spec.id
		if not spec.data is Dictionary:
			_errors.append("Seer generated card author field missing: " + card_id)
			continue
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": spec.data.duplicate(true), "npcId": "tianji_laoren",
			"sourcePath": "src/systems/StoryNetworkSystem.js",
			"sourceSha256": STORY_RULE_SHA,
			"authorPath": "data/companions/arcs.json",
			"authorPointer": "$.seerArc.tianji_laoren." + String(spec.authorKey),
			"authorSha256": _source_meta.get("data/companions/arcs.json"),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::" + spec.producer,
			"producerGodot": "res://scripts/noncombat_seer_arc_flow.gd::_project",
			"reachability": {"physicalSeer": true,
				"gate": spec.reachability}}


func _index_surfacing_generated_cards() -> void:
	# These two fixed cards are authored in the browser rule itself, with no JSON
	# payload. Keep their rule identity separate from dynamic affection IDs.
	for spec in [{"id": "surface_bairen_memory", "browser": "_checkWorldChange",
			"godot": "_world_card", "gate": "bairen_zhenren death + 3 turns"},
			{"id": "surface_karma_burden", "browser": "_checkKarmaSurface",
			"godot": "_karma_card", "gate": "karmaSeeds >= 4"}]:
		var card_id: String = spec.id
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": {"id": card_id},
			"sourcePath": "src/systems/StoryNetworkSystem.js",
			"sourceSha256": STORY_RULE_SHA,
			"sourceSymbol": "NarrativeSurfacing." + String(spec.browser),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::NarrativeSurfacing." + String(spec.browser),
			"producerGodot": "res://scripts/noncombat_narrative_surfacing.gd::" + String(spec.godot),
			"reachability": {"checkIntervalTurns": 5, "cooldownDecisions": 12,
				"gate": spec.gate}}


func _index_surfacing_affection_cards(npc_catalog: Dictionary) -> void:
	var npcs: Variant = npc_catalog.get("npcs")
	if not npcs is Array:
		_errors.append("Surfacing affection owner source invalid")
		return
	for i in range(npcs.size()):
		var npc: Variant = npcs[i]
		if not npc is Dictionary or not npc.get("id") is String:
			_errors.append("Surfacing affection owner invalid: $.npcs[%d]" % i)
			continue
		var npc_id: String = npc.id
		var card_id := "surface_%s_near_20" % npc_id
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": {"id": card_id}, "companionId": npc_id,
			"sourcePath": "src/systems/StoryNetworkSystem.js",
			"sourceSha256": STORY_RULE_SHA,
			"sourceSymbol": "NarrativeSurfacing._checkAffectionSurface",
			"npcSourcePath": "data/npcs/core_npcs.json",
			"npcSourcePointer": "$.npcs[%d]" % i,
			"npcSourceSha256": _source_meta.get("data/npcs/core_npcs.json"),
			"producerBrowser": "src/systems/StoryNetworkSystem.js::NarrativeSurfacing._checkAffectionSurface",
			"producerGodot": "res://scripts/noncombat_narrative_surfacing.gd::_affection_card",
			"reachability": {"ownedCompanion": true, "registeredCompanion": true,
				"affectionMin": 18, "affectionMaxExclusive": 20,
				"onceFlag": "surface_pushed_%s_20" % npc_id,
				"checkIntervalTurns": 5}}


func _index_ripple_templates() -> void:
	if FileAccess.get_sha256(RIPPLE_CATALOG) != RIPPLE_CATALOG_SHA:
		_errors.append("Karma ripple derived catalog SHA mismatch")
		return
	var catalog: Variant = _parse_json(RIPPLE_CATALOG)
	if not catalog is Dictionary or catalog.get("source") != "src/systems/KarmaRippleSystem.js" \
			or catalog.get("sourceSha256") != RIPPLE_RULE_SHA \
			or not catalog.get("templates") is Dictionary:
		_errors.append("Karma ripple template source invalid")
		return
	for seed_type in ["karma", "grudge", "bloodline", "fate"]:
		var rows: Variant = catalog.templates.get(seed_type)
		if not rows is Array or rows.size() != 1 or not rows[0] is Dictionary:
			_errors.append("Karma ripple template family invalid: " + seed_type)
			continue
		var card_id: String = "karma_ripple_template:" + seed_type
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": rows[0].duplicate(true), "seedType": seed_type,
			"sourcePath": "src/systems/KarmaRippleSystem.js",
			"sourceSha256": RIPPLE_RULE_SHA,
			"producerBrowser": "src/systems/KarmaRippleSystem.js::_rippleTemplates/_buildRippleCard",
			"derivedCatalogPath": "godot/content/derived/karma_ripple_templates.json",
			"derivedCatalogPointer": "$.templates.%s[0]" % seed_type,
			"derivedCatalogSha256": RIPPLE_CATALOG_SHA,
			"producerGodot": "res://scripts/noncombat_ripple_flow.gd::_build_card",
			"reachability": {"activeKarmaSeed": true, "seedType": seed_type,
				"instanceIdDynamic": true, "cooldownDecisions": 8}}


func _index_cross_rules() -> void:
	# These are finite producer-rule identities, not turn-specific card IDs.
	for branch in ["rival", "ally", "ambient"]:
		var card_id: String = "npc_cross_rule:" + branch
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		var statuses: Array = ["rival"] if branch == "rival" else \
			["ally", "master-disciple"] if branch == "ally" else \
			["neutral", "estranged"]
		_indexes["generated_card"][card_id] = {
			"data": {"id": card_id}, "templateIdentity": true,
			"branch": branch, "relationStatuses": statuses,
			"sourcePath": "src/systems/NpcSystem.js",
			"sourceSha256": NPC_RULE_SHA,
			"sourceSymbol": "NpcSystem._emitCrossCard",
			"producerBrowser": "src/systems/NpcSystem.js::_emitCrossCard",
			"producerGodot": "res://scripts/noncombat_npc_cross_flow.gd::_dynamic_card",
			"relationSourcePath": "data/npcs/npc_relations.json",
			"relationSourceSha256": _source_meta.get("data/npcs/npc_relations.json"),
			"npcSourcePath": "data/npcs/core_npcs.json",
			"npcSourceSha256": _source_meta.get("data/npcs/core_npcs.json"),
			"reachability": {"physicalPair": true, "scheduledSameLocation": true,
				"repeatCooldownTurns": 12, "instanceIdDynamic": true}}


func _index_generated_runtime_rules() -> void:
	if FileAccess.get_sha256(HINT_CATALOG) != HINT_CATALOG_SHA:
		_errors.append("Heavens hint derived catalog SHA mismatch")
		return
	var hint_catalog: Variant = _parse_json(HINT_CATALOG)
	if not hint_catalog is Dictionary \
			or hint_catalog.get("source") != "src/systems/HeavensHintSystem.js" \
			or hint_catalog.get("sourceSha256") != HINT_RULE_SHA \
			or not hint_catalog.get("pool") is Array \
			or hint_catalog.pool.is_empty():
		_errors.append("Heavens hint producer source invalid")
		return
	var vendor_producers := [
		"res://scripts/noncombat_vendor_flow.gd",
		"res://scripts/noncombat_regulated_vendor_flow.gd",
		"res://scripts/noncombat_ghost_vendor_flow.gd",
		"res://scripts/noncombat_last_lesson_vendor_flow.gd",
	]
	for spec in [
		{"id": "vendor_rule:pending", "symbol": "Game._buildVendorPendingCard",
			"prefix": "vendor_pending:"},
		{"id": "vendor_rule:result", "symbol": "Game._buildVendorResultCard",
			"prefix": "vendor_result:"},
	]:
		var card_id: String = spec.id
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": {"id": card_id}, "templateIdentity": true,
			"instancePrefix": spec.prefix,
			"sourcePath": "src/game.js", "sourceSha256": GAME_RULE_SHA,
			"sourceSymbol": spec.symbol,
			"producerBrowser": "src/game.js::" + String(spec.symbol),
			"producerGodot": vendor_producers.duplicate(),
			"reachability": {"vendorSession": true, "instanceIdDynamic": true}}
	for spec in [
		{"id": "ghost_debt_rule", "symbol": "Game._buildGhostDebtDueCard",
			"prefix": "ghost_debt_due:",
			"godot": "res://scripts/noncombat_ghost_debt_flow.gd",
			"gate": "market debt due"},
		{"id": "licensed_delivery_rule",
			"symbol": "Game._buildLicensedRustedSwordDeliveryCard",
			"prefix": "regulated_rusted_sword_delivery:",
			"godot": "res://scripts/noncombat_licensed_delivery.gd",
			"gate": "licensed order due"},
	]:
		var card_id: String = spec.id
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": {"id": card_id}, "templateIdentity": true,
			"instancePrefix": spec.prefix,
			"sourcePath": "src/game.js", "sourceSha256": GAME_RULE_SHA,
			"sourceSymbol": spec.symbol,
			"producerBrowser": "src/game.js::" + String(spec.symbol),
			"producerGodot": [spec.godot],
			"reachability": {"gate": spec.gate, "instanceIdDynamic": true}}
	var hint_id := "heavens_hint_rule"
	if _indexes["generated_card"].has(hint_id):
		_errors.append("Duplicate generated_card ID: " + hint_id)
		return
	_indexes["generated_card"][hint_id] = {
		"data": {"id": hint_id}, "templateIdentity": true,
		"instancePrefix": "heavens_hint:",
		"sourcePath": "src/systems/HeavensHintSystem.js",
		"sourceSha256": HINT_RULE_SHA,
		"sourceSymbol": "HeavensHintSystem._buildHintCard",
		"producerBrowser": "src/systems/HeavensHintSystem.js::HeavensHintSystem._buildHintCard",
		"producerGodot": ["res://scripts/noncombat_heavens_hint_flow.gd"],
		"derivedCatalogPath": "godot/content/derived/heavens_hint_pool.json",
		"derivedCatalogPointer": "$.pool",
		"derivedCatalogSha256": HINT_CATALOG_SHA,
		"reachability": {"hintPoolSize": hint_catalog.pool.size(),
			"instanceIdDynamic": true}}


func _index_realm_arrival_cards(chapters: Dictionary, path: String) -> void:
	for spec in [
		{"realm": "golden", "source": "ch_foundation_100"},
		{"realm": "nascent", "source": "ch_golden_100"},
		{"realm": "deity", "source": "ch_nascent_100"},
		{"realm": "tribulation", "source": "ch_deity_100"},
	]:
		var card_id := "realm_arrival_" + String(spec.realm)
		var source_card: Variant = chapters.get(spec.source)
		var scene: Variant = source_card.get("combatPresentation", {}).get(
			"sceneImage") if source_card is Dictionary else null
		if not source_card is Dictionary or source_card.get("id") != spec.source \
				or not scene is String or String(scene).is_empty():
			_errors.append("Realm arrival source missing: %s at %s $.%s" % [
				card_id, path, spec.source])
			continue
		if _indexes["generated_card"].has(card_id):
			_errors.append("Duplicate generated_card ID: " + card_id)
			continue
		_indexes["generated_card"][card_id] = {
			"data": source_card.duplicate(true), "sourceCardId": spec.source,
			"realm": spec.realm, "sceneImage": scene,
			"sceneImageSourcePointer": "$.%s.combatPresentation.sceneImage" % spec.source,
			"sourcePath": path, "jsonPointer": "$." + String(spec.source),
			"sourceSha256": _source_meta.get(path, ""),
			"ruleSourcePath": "src/game.js", "ruleSourceSha256": GAME_RULE_SHA,
			"ruleSourceSymbol": "Game._buildRealmArrivalCard",
			"producerBrowser": "src/game.js::Game._buildRealmArrivalCard",
			"producerGodot": "res://scripts/noncombat_realm_gate_flow.gd::arrival_card",
			"reachability": {"realm": spec.realm, "requiresBreakthroughVictory": true}}


func _index_faction_generated_cards(doc: Dictionary, path: String) -> void:
	var factions: Variant = doc.get("factions")
	if not factions is Array:
		_errors.append("Missing faction event producers: " + path)
		return
	for i in range(factions.size()):
		var faction: Variant = factions[i]
		var owner_pointer := "$.factions[%d]" % i
		if not faction is Dictionary or not faction.get("id") is String \
				or String(faction.get("id", "")).is_empty() \
				or not faction.get("events") is Array:
			_errors.append("Invalid faction producer: %s %s" % [path, owner_pointer])
			continue
		for j in range(faction.events.size()):
			var event: Variant = faction.events[j]
			var pointer := owner_pointer + ".events[%d]" % j
			if not event is Dictionary or not event.get("id") is String \
					or String(event.get("id", "")).is_empty():
				_errors.append("Invalid faction event producer: %s %s" % [path, pointer])
				continue
			var card_id := "faction_" + String(event.id)
			if _indexes["generated_card"].has(card_id):
				_index_record("generated_card", card_id, event, path, pointer)
				continue
			_index_record("generated_card", card_id, event, path, pointer)
			var row: Dictionary = _indexes["generated_card"][card_id]
			row["factionId"] = faction.id
			row["producerBrowser"] = "src/systems/FactionSystem.js::_buildFactionCard"
			row["producerGodot"] = "res://scripts/noncombat_faction_events.gd::_build"
			row["reachability"] = {
				"minRealm": event.get("minRealm"),
				"location": event.get("location"),
				"requiresPlayerPresence": event.get("requiresPlayerPresence") == true,
				"deliveryClass": event.get("deliveryClass"),
				"pathRestriction": event.get("pathRestriction"),
				"minReputation": int(event.get("minReputation", -100)),
				"once": event.get("once", true),
				"requiresFlag": event.get("requiresFlag"),
				"undercurrentId": event.get("undercurrentId"),
				"undercurrentStage": int(event.get("undercurrentStage", 1)),
				"weight": event.get("weight", 10),
				"runtimeGates": ["cadence_15_ticks", "weighted_selection",
					"fortune_and_path_weight", "narrative_eligibility",
					"source_pin", "pending_card_and_location_validation"],
				"consumer": "res://scripts/noncombat_faction_events.gd::_eligible"}


func _index_audio_runtime(value: Variant, path: String, pointer: String) -> void:
	if value is Dictionary:
		var runtime: Variant = value.get("runtime")
		if runtime is Dictionary and runtime.get("id") is String \
				and (runtime.get("path") is String or (runtime.get("path") == null \
				and runtime.get("procedural") is Dictionary)):
			_index_record("audio", runtime.id, runtime, path, pointer + ".runtime")
		for key in value:
			_index_audio_runtime(value[key], path, pointer + "." + String(key))
	elif value is Array:
		for i in range(value.size()):
			_index_audio_runtime(value[i], path, pointer + "[%d]" % i)


func _index_choice_nodes(value: Variant, path: String, pointer: String) -> void:
	if value is Dictionary:
		if value.get("id") is String and value.get("choices") is Dictionary:
			_index_record("card", value["id"], value, path, pointer)
		for key in value:
			_index_choice_nodes(value[key], path, pointer + "." + String(key))
	elif value is Array:
		for i in range(value.size()):
			_index_choice_nodes(value[i], path, pointer + "[%d]" % i)


func _index_scene_images(value: Variant, path: String, pointer: String) -> void:
	if value is Dictionary:
		for key in value:
			var child_pointer := pointer + "." + String(key)
			var child: Variant = value[key]
			if key == "sceneImage" and child is String and not String(child).is_empty():
				if not _scene_images.has(path):
					_scene_images[path] = []
				_scene_images[path].append({
					"sourcePath": path, "jsonPointer": child_pointer,
					"assetPath": child,
				})
			_index_scene_images(child, path, child_pointer)
	elif value is Array:
		for i in range(value.size()):
			_index_scene_images(value[i], path, pointer + "[%d]" % i)


func _index_record(kind: String, raw_id: Variant, payload: Dictionary,
		path: String, pointer: String) -> void:
	if not raw_id is String or String(raw_id).is_empty():
		return
	var source_id := String(raw_id)
	if _indexes[kind].has(source_id):
		_errors.append("Duplicate %s ID %s: %s %s and %s %s" % [kind, source_id,
			_indexes[kind][source_id]["sourcePath"],
			_indexes[kind][source_id]["jsonPointer"], path, pointer])
		return
	_indexes[kind][source_id] = {
		"data": payload.duplicate(true), "sourcePath": path,
		"jsonPointer": pointer, "sourceSha256": _source_meta[path],
	}


func _safe_segment(segment: String) -> bool:
	if segment.is_empty():
		return false
	for letter in segment:
		if not (letter >= "a" and letter <= "z") \
				and not (letter >= "0" and letter <= "9") and letter != "_":
			return false
	return true
