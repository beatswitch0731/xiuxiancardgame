extends "res://scripts/duel_stage_village_2d.gd"

const SWORD_SOURCE_IDS := ["thread_sword_tomb_2", "q_sword_3"]
const SWORD_TOMB_SCENE := "res://scenes/duel_stage_sword_tomb_2d.tscn"
const InlineStage = preload("res://scripts/duel_stage_village_2d.gd")


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	return context.get("sourceCardId") in SWORD_SOURCE_IDS \
		and InlineStage.source_assets_ready(registry, context)


func _expected_scene() -> String:
	return SWORD_TOMB_SCENE
