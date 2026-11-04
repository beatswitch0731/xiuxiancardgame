extends RefCounted

# Only resolves source-authored presentation identity. It never starts combat,
# mutates the story choice or commits its eventual reward.

var registry: RefCounted


func _init(data_registry: RefCounted) -> void:
	registry = data_registry


func resolve_encounter(encounter_id: String, encounter_instance_id: String = "") -> Dictionary:
	var presentations: Dictionary = registry.read_json(
		"data/combat/encounter_presentations.json").get("presentations", {})
	var entry: Dictionary = presentations.get(encounter_id, {})
	if entry.is_empty():
		return {}
	return _context(entry, encounter_id, "", "", encounter_instance_id, {}, "", "")


func resolve_choice(source_card_id: String, direction: String,
		resolved_combat_card: Dictionary, encounter_instance_id: String,
		pending_resolution: Dictionary, path_id: String, realm_id: String) -> Dictionary:
	if source_card_id.is_empty() or not direction in ["left", "right", "up", "down"] \
			or resolved_combat_card.is_empty() or encounter_instance_id.is_empty():
		return {}
	var authored: Dictionary = resolved_combat_card.get("combatPresentation", {}).duplicate(true)
	var catalog: Dictionary = registry.read_json(
		"data/combat/migrated_presentations.json").get("presentations", {})
	var migrated: Dictionary = catalog.get("%s:%s" % [source_card_id, direction], {})
	# CardSystem.hydrateCombatCardPresentation gives migrated media ownership of
	# colliding visual fields. This applies the same precedence after a choice is
	# resolved, while keeping authored nonvisual combat promises untouched.
	var visual := authored.duplicate(true)
	for field in ["presentationId", "battlefieldId", "battlefield", "sceneImage",
			"warningTitle", "mechanic", "enemyType", "difficultyLabel"]:
		if migrated.has(field):
			visual[field] = migrated[field]
	var raw_encounter_id: Variant = resolved_combat_card.get("encounterId")
	var encounter_id := String(raw_encounter_id) if raw_encounter_id is String else ""
	if visual.get("battlefieldId", "") == "":
		var encounter_context := resolve_encounter(encounter_id, encounter_instance_id)
		if not encounter_context.is_empty():
			for field in ["presentationId", "battlefieldId", "battlefield", "sceneImage"]:
				if visual.get(field, "") == "":
					visual[field] = encounter_context.get(field, "")
	return _context(visual, encounter_id,
		source_card_id, direction, encounter_instance_id,
		pending_resolution, path_id, realm_id)


func _context(presentation: Dictionary, encounter_id: String,
		source_card_id: String, direction: String, encounter_instance_id: String,
		pending_resolution: Dictionary, path_id: String, realm_id: String) -> Dictionary:
	var presentation_id := String(presentation.get("presentationId", ""))
	var battlefield_id := String(presentation.get("battlefieldId", ""))
	var scene_image := String(presentation.get("sceneImage", ""))
	if presentation_id.is_empty() or battlefield_id.is_empty() or not scene_image.begins_with("assets/"):
		return {}
	return {
		"encounterId": encounter_id,
		"sourceCardId": source_card_id,
		"direction": direction,
		"encounterInstanceId": encounter_instance_id,
		"presentationId": presentation_id,
		"battlefieldId": battlefield_id,
		"battlefield": String(presentation.get("battlefield", "")),
		"sceneImage": scene_image,
		"path": path_id,
		"realm": realm_id,
		"pendingResolution": pending_resolution.duplicate(true),
	}
