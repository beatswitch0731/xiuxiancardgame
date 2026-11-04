extends RefCounted

# Source-backed visual identity ledger. Unbuilt scenes never fall back to M0.
const CATALOG := "res://art_direction/battlefield_art_catalog.json"

var _entries: Dictionary = {}


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if parsed is Dictionary:
		_entries = parsed.get("battlefields", {})


func resolve(stage_context: Dictionary, candidate: String = "") -> Dictionary:
	var battlefield_id := String(stage_context.get("battlefieldId", ""))
	var presentation_id := String(stage_context.get("presentationId", ""))
	var source_image := String(stage_context.get("sceneImage", ""))
	var entry: Dictionary = _entries.get(battlefield_id, {})
	if entry.is_empty():
		return {}
	var source_matches := false
	for source in entry.get("sources", []):
		if source is Dictionary and source.get("presentationId") == presentation_id \
				and source.get("sceneImage") == source_image:
			source_matches = true
			break
	if not source_matches:
		return {}
	var scene_path := String(entry.get("runtimeScene", ""))
	if not candidate.is_empty():
		scene_path = String(entry.get("candidateScenes", {}).get(candidate, ""))
		if scene_path.is_empty():
			return {}
	var result := entry.duplicate(true)
	result["presentationId"] = presentation_id
	result["selectedScene"] = scene_path
	result["candidate"] = candidate
	var story_brief: Dictionary = result.get("designBrief", {})
	if story_brief.has("canonicalStoryLocation"):
		result["canonicalStoryLocation"] = story_brief["canonicalStoryLocation"]
		result["canonicalWarningTitle"] = story_brief.get("canonicalWarningTitle", "")
		result["canonicalEnemy"] = story_brief.get("canonicalEnemy", "")
		result["sourceConflict"] = story_brief.get("sourceConflict", "")
		result["sourceReconciliationStatus"] = story_brief.get("sourceReconciliationStatus", "")
	return result
