extends RefCounted

# Read-only intake for browser localStorage exports. A preview never grants
# Godot run ownership; the later importer must validate and map each state.
const SLOT_KEYS := {
	"slot_1": "xiuxian_unlocks",
	"slot_2": "xiuxian_unlocks_slot_2",
	"slot_3": "xiuxian_unlocks_slot_3",
}
const SAVE_VERSION := 10
const CAUSAL_VERSION := 18
const QUEST_VERSION := 3
const EQUIPMENT_SLOTS := ["weapon", "armor", "accessory", "artifact"]


func inspect_text(raw_text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(raw_text) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "INVALID_JSON", "slots": []}
	var extracted: Dictionary = _extract_storage(parser.data)
	if extracted.is_empty():
		return {"ok": false, "error": "NO_BROWSER_SLOTS", "slots": []}
	var slots: Array = []
	var valid := true
	var single_save: bool = parser.data.has("saveVersion") \
		and parser.data.get("saveSlot") is Dictionary
	for slot_id in SLOT_KEYS:
		var key: String = SLOT_KEYS[slot_id]
		if not extracted.has(key):
			slots.append({"slotId": slot_id, "occupied": false, "valid": true})
			continue
		var source: Variant = extracted[key]
		var save_text: String = raw_text if single_save else (
			source if source is String else JSON.stringify(source))
		var decoded: Variant = JSON.parse_string(save_text)
		var preview := _inspect_slot(decoded, slot_id)
		preview["sourceSha256"] = String(save_text).sha256_text()
		preview["occupied"] = true
		slots.append(preview)
		if preview.get("valid") != true:
			valid = false
	var active_value: Variant = extracted.get("xiuxian_active_save_slot", "slot_1")
	var active: String = active_value if active_value is String else "slot_1" if active_value == null else ""
	if single_save:
		active = parser.data.saveSlot.id
	if active not in SLOT_KEYS:
		valid = false
	return {"ok": valid, "error": "" if valid else "INVALID_BROWSER_SAVE",
		"activeSlot": active, "slots": slots}


func read_slot(raw_text: String, slot_id: String) -> Dictionary:
	var preview := inspect_text(raw_text)
	if preview.get("ok") != true or not SLOT_KEYS.has(slot_id):
		return {"ok": false, "error": String(preview.get("error", "INVALID_SLOT"))}
	var row: Dictionary = preview.slots[SLOT_KEYS.keys().find(slot_id)]
	if row.get("occupied") != true:
		return {"ok": false, "error": "EMPTY_SLOT"}
	var root: Dictionary = JSON.parse_string(raw_text)
	var stored: Variant = _extract_storage(root)[SLOT_KEYS[slot_id]]
	var save: Variant = JSON.parse_string(stored) if stored is String else stored
	return {"ok": true, "source": save.duplicate(true),
		"sourceSha256": row.sourceSha256, "preview": row}


func _extract_storage(root: Dictionary) -> Dictionary:
	if root.has("saveVersion") and root.get("saveSlot") is Dictionary:
		var slot_id := String(root.saveSlot.get("id", ""))
		return {SLOT_KEYS[slot_id]: root} if SLOT_KEYS.has(slot_id) else {}
	if root.has("origins"):
		if not root.origins is Array:
			return {}
		var storage := {}
		for origin in root.origins:
			if not origin is Dictionary or not origin.get("localStorage") is Array:
				continue
			for row in origin.localStorage:
				if not row is Dictionary or not row.get("name") is String \
						or not row.get("value") is String:
					continue
				var key: String = row.name
				if key in SLOT_KEYS.values() or key == "xiuxian_active_save_slot":
					if storage.has(key):
						return {}
					storage[key] = row.value
		return storage
	var storage := {}
	for key in SLOT_KEYS.values() + ["xiuxian_active_save_slot"]:
		if root.has(key):
			storage[key] = root[key]
	return storage


func _inspect_slot(source: Variant, slot_id: String) -> Dictionary:
	var result := {"slotId": slot_id, "valid": false, "error": "INVALID_SLOT"}
	if not source is Dictionary or source.get("saveVersion") != SAVE_VERSION \
			or not source.get("saveSlot") is Dictionary \
			or source.saveSlot.get("version") != 1 \
			or source.saveSlot.get("id") != slot_id:
		return result
	var quest: Variant = source.get("questState")
	if quest != null and (not quest is Dictionary \
			or quest.get("saveVersion") != QUEST_VERSION \
			or not quest.get("activeQuests") is Array \
			or not quest.get("completedQuests") is Array \
			or not quest.get("closedQuests") is Array \
			or not quest.get("questOutcomes") is Dictionary):
		result.error = "INVALID_QUEST_SIDECAR"
		return result
	var snapshot: Variant = source.get("causalSessionState")
	if snapshot == null:
		return {"slotId": slot_id, "valid": true, "error": "",
			"label": String(source.saveSlot.get("label", "")),
			"hasRun": false, "requiresAnchor": false,
			"combatActive": false}
	if not snapshot is Dictionary or snapshot.get("version") != CAUSAL_VERSION \
			or not snapshot.get("runClock") is Dictionary \
			or not _nonnegative_integer(snapshot.get("lifeCount")) \
			or snapshot.get("lifeCount") != source.get("lifeCount") \
			or not _nonnegative_integer(snapshot.get("turn")) \
			or not snapshot.get("choiceHistory") is Array \
			or not snapshot.get("attributes") is Dictionary \
			or not snapshot.get("resources") is Dictionary \
			or not snapshot.get("treasureInstances") is Dictionary \
			or not snapshot.get("equipment") is Dictionary:
		result.error = "INVALID_CAUSAL_SNAPSHOT"
		return result
	var clock: Dictionary = snapshot.runClock
	if clock.get("version") != 1 \
			or not _nonnegative_integer(clock.get("decisionIndex")) \
			or not clock.get("receipts") is Dictionary \
			or clock.get("lifeId") != "%s:life:%d" % [slot_id,
				int(snapshot.lifeCount)]:
		result.error = "INVALID_RUN_CLOCK"
		return result
	if snapshot.get("path") not in [null, "sword", "spell", "body", "pill"] \
			or snapshot.get("realm") not in ["qi", "foundation", "golden",
				"nascent", "deity", "tribulation"]:
		result.error = "INVALID_RUN_IDENTITY"
		return result
	var previous_index := 0
	for choice in snapshot.choiceHistory:
		if not choice is Dictionary or not choice.get("cardId") is String \
				or not choice.get("direction") is String \
				or not _nonnegative_integer(choice.get("decisionIndex")):
			result.error = "INVALID_CHOICE_HISTORY"
			return result
		var index := int(choice.decisionIndex)
		if index < previous_index or index > int(clock.decisionIndex):
			result.error = "INVALID_CHOICE_HISTORY"
			return result
		previous_index = index
	var ownership: Dictionary = snapshot.treasureInstances
	for instance_id in ownership:
		var instance: Variant = ownership[instance_id]
		if not instance is Dictionary or instance.get("instanceId") != instance_id \
				or not instance.get("definitionId") is String \
				or instance.get("lifecycle") != "owned":
			result.error = "INVALID_TREASURE_OWNERSHIP"
			return result
	for slot in EQUIPMENT_SLOTS:
		var equipped: Variant = snapshot.equipment.get(slot)
		if equipped != null and not ownership.has(equipped):
			result.error = "INVALID_TREASURE_OWNERSHIP"
			return result
	var combat: Variant = snapshot.get("combatSession")
	var combat_active: bool = combat is Dictionary and combat.get("active") == true
	if combat != null:
		if not combat is Dictionary or combat.get("version") != 3 \
				or combat.get("active") != true \
				or not combat.get("originalCard") is Dictionary \
				or not combat.get("encounterContext") is Dictionary \
				or not combat.get("authoritySeal") is String:
			result.error = "INVALID_COMBAT_SESSION"
			return result
		var card_id := String(combat.originalCard.get("id", ""))
		var owner := "enc:%d:%d:%s:1" % [int(snapshot.lifeCount),
			int(snapshot.turn), card_id]
		if card_id.is_empty() or combat.encounterContext.get(
				"encounterInstanceId") != owner:
			result.error = "INVALID_COMBAT_OWNER"
			return result
	return {"slotId": slot_id, "valid": true, "error": "",
		"label": String(source.saveSlot.get("label", "")),
		"hasRun": true, "path": snapshot.path, "realm": snapshot.realm,
		"lifeCount": int(snapshot.lifeCount), "turn": int(snapshot.turn),
		"decisionIndex": int(clock.decisionIndex),
		"currentCardId": String(snapshot.get("decisionCheckpoint", {}).get(
			"cardId", "")) if snapshot.get("decisionCheckpoint") is Dictionary else "",
		"requiresAnchor": int(clock.decisionIndex) > snapshot.choiceHistory.size(),
		"combatActive": combat_active,
		"combatSealVerified": false}


func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) >= 0
