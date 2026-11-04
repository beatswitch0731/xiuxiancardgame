extends "res://scripts/duel_stage_village_2d.gd"

const LAST_LESSON_SCENE := "res://scenes/duel_stage_last_lesson_2d.tscn"
const InlineStage = preload("res://scripts/duel_stage_village_2d.gd")


static func source_assets_ready(registry: RefCounted, context: Dictionary) -> bool:
	if context.get("sourceCardId") != "thread_last_lesson_n3" \
			or context.get("direction") != "left" \
			or not InlineStage.source_assets_ready(registry, context):
		return false
	var assist: Dictionary = context.get("pendingResolution", {}).get(
		"choice", {}).get("combatPresentation", {}).get("storyAssist", {})
	var card: Dictionary = registry.get_battle_card(String(assist.get("cardId", "")))
	return assist.get("openingHand") == true \
		and assist.get("compId") == "jian_linger" \
		and not card.is_empty() \
		and registry.texture_for(String(card.get("cardArt", {}).get("image", ""))) != null


func _expected_scene() -> String:
	return LAST_LESSON_SCENE
