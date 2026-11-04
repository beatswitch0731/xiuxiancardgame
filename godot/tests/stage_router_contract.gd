extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")


func _initialize() -> void:
	var router = StageRouter.new(Registry.new())
	var trial: Dictionary = router.resolve_encounter("enc_trial_sword_swift", "enc:0:0:trial:1")
	if trial.get("battlefieldId") != "battlefield_enc_trial_sword_swift_native_v1" \
			or trial.get("sceneImage") != \
			"assets/combat/battlefields/battlefield_enc_trial_sword_swift_agc_v2.png":
		_fail("real first fight no longer resolves the browser battlefield")
		return
	var pending := {"choice": {"reward": "unchanged"}}
	var dummy_card := {"id": "thread_ab_village_3", "combatPresentation": {"battlefieldId": "wrong-card-media"}}
	var village_left: Dictionary = router.resolve_choice("thread_ab_village_3", "left",
		dummy_card, "enc:0:7:thread_ab_village_3:1", pending, "sword", "qi")
	var village_right: Dictionary = router.resolve_choice("thread_ab_village_3", "right",
		dummy_card, "enc:0:7:thread_ab_village_3:1", pending, "sword", "qi")
	if village_left.is_empty() or village_right.is_empty() \
			or village_left["battlefieldId"] == village_right["battlefieldId"] \
			or dummy_card["combatPresentation"]["battlefieldId"] != "wrong-card-media":
		_fail("left/right village branches lost migrated-media precedence or mutated source")
		return
	var tomb_left: Dictionary = router.resolve_choice("thread_sword_tomb_2", "left",
		{"id": "thread_sword_tomb_2"}, "enc:0:9:tomb:1", pending, "sword", "foundation")
	var tomb_right: Dictionary = router.resolve_choice("thread_sword_tomb_2", "right",
		{"id": "thread_sword_tomb_2"}, "enc:0:9:tomb:1", pending, "sword", "foundation")
	if tomb_left.is_empty() or tomb_right.is_empty() \
			or tomb_left["battlefieldId"] != tomb_right["battlefieldId"] \
			or tomb_left["presentationId"] == tomb_right["presentationId"]:
		_fail("sword-tomb branches lost shared geometry or distinct branch presentation")
		return
	village_left["pendingResolution"]["choice"]["reward"] = "mutated"
	if pending["choice"]["reward"] != "unchanged" \
			or not router.resolve_choice("thread_ab_village_3", "none", dummy_card,
			"enc:bad", pending, "sword", "qi").is_empty():
		_fail("launch context mutated a pending story settlement or accepted an invalid direction")
		return
	print("STAGE_ROUTER_CONTRACT_PASS encounter=1 branch_cases=4")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
