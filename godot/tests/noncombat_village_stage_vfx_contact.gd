extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const StageScene = preload("res://scenes/duel_stage_village_2d.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/abandoned_village_source.json"))
	var resolution: Dictionary = source["entry"]["pendingResolution"]
	var registry = Registry.new()
	var context: Dictionary = StageRouter.new(registry).resolve_choice(
		"thread_ab_village_3", "left", resolution["combatCard"],
		String(source["battleOwner"]), resolution, "sword", "qi")
	context["deck"] = source["entry"]["battle"]["masterDeck"].duplicate(true)
	var stage: Control = StageScene.instantiate()
	if not stage.bind_stage_context(context):
		return _fail("village source stage could not bind browser-authored visuals")
	root.add_child(stage)
	await process_frame
	var visual: Dictionary = resolution["combatCard"]["combatPresentation"]
	var enemy_frame: Texture2D = registry.texture_for(visual["actorCards"]["enemy"][
		"intentFrames"]["debuff"])
	var weak_frame: Texture2D = registry.texture_for(visual["vfx"]["weak"]["frames"][0])
	var enemy: TextureRect = stage.find_child("SourceEnemy", true, false)
	var effect: TextureRect = stage.find_child("SourceVfx", true, false)
	if enemy == null or effect == null or enemy_frame == null or weak_frame == null \
			or not stage.present_action({"type": "ENEMY_ACTION",
				"intent": {"type": "debuff", "statusId": "weak", "value": 1},
				"reactionId": "TAKE_HIT", "hpLoss": 0}):
		return _fail("village weak actor/action could not start")
	var saw_overlap := false
	var saw_effect := false
	var saw_enemy := false
	for _frame in range(100):
		await create_timer(0.01).timeout
		saw_enemy = saw_enemy or enemy.texture == enemy_frame
		saw_effect = saw_effect or effect.visible and effect.texture == weak_frame
		if enemy.texture == enemy_frame and effect.visible and effect.texture == weak_frame:
			saw_overlap = true
			break
	if not saw_overlap:
		return _fail("village weak effect missed enemy contact: enemy=%s effect=%s" % [
			saw_enemy, saw_effect])
	print("NONCOMBAT_VILLAGE_STAGE_VFX_CONTACT_PASS weak=true actor_overlap=true")
	quit(0)


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
