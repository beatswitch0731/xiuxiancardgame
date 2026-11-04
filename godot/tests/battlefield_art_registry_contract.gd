extends SceneTree

const DataRegistry = preload("res://scripts/runtime_data_registry.gd")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const ArtRegistry = preload("res://scripts/battlefield_art_registry.gd")
const DuelStage = preload("res://scenes/duel_stage_hd2d.tscn")


func _initialize() -> void:
	var visual = ArtRegistry.new()
	var router = StageRouter.new(DataRegistry.new())
	var first: Dictionary = router.resolve_encounter("enc_trial_sword_swift")
	var first_stage: Dictionary = visual.resolve(first)
	if first_stage.get("runtimeScene") != "res://assets/hd2d/world_v17/qingyun_tutorial_hall_v17.glb" \
			or first_stage.get("selectedScene") != first_stage.get("runtimeScene") \
			or first_stage.get("artStatus") != "candidate_visual_fail" \
			or first_stage.get("approvedForFinalArt") != false:
		_fail("first fight must use the V17 tutorial scene without claiming final art approval")
		return
	if visual.resolve(first, "trial_v16").get("selectedScene") != \
			"res://assets/hd2d/world_v16/cangmang_trial_hall_v16.glb":
		_fail("the V16 hall must remain available for first-fight comparison")
		return
	if visual.resolve(first, "trial_v7").get("selectedScene") != \
			"res://assets/hd2d/world_v7/qingyun_trial_hall_v7.glb":
		_fail("V7 may be selected only as first-fight candidate")
		return
	var pending := {"choice": {"reward": "unchanged"}}
	var card := {"id": "thread_ab_village_3"}
	var left: Dictionary = router.resolve_choice("thread_ab_village_3", "left", card,
		"enc:0:7:village:left", pending, "sword", "qi")
	var right: Dictionary = router.resolve_choice("thread_ab_village_3", "right", card,
		"enc:0:7:village:right", pending, "sword", "qi")
	var l: Dictionary = visual.resolve(left)
	var r: Dictionary = visual.resolve(right)
	if left.get("battlefieldId") == right.get("battlefieldId") \
			or l.get("productionFamily") != "village_well_chamber" \
			or r.get("productionFamily") != "village_well_chamber" \
			or l.get("designBrief", {}).get("status") != "source_brief_ready_geometry_candidate" \
			or r.get("designBrief", {}).get("status") != "source_brief_ready_geometry_unbuilt" \
			or not String(l.get("designBrief", {}).get("identity", "")).contains("石室") \
			or not String(r.get("designBrief", {}).get("identity", "")).contains("石室") \
			or l.get("designBrief", {}).get("canonicalWarningTitle") != "荒村旧怨 · 以剑破执" \
			or r.get("designBrief", {}).get("canonicalWarningTitle") != "荒村旧怨 · 清心超度" \
			or l.get("designBrief", {}).get("canonicalEnemy") != "怨念之影" \
			or r.get("designBrief", {}).get("canonicalEnemy") != "怨念之影" \
			or l.get("sourceReconciliationStatus") != "presentation_conflict_pending_source_reconciliation" \
			or r.get("sourceReconciliationStatus") != "presentation_conflict_pending_source_reconciliation" \
			or String(l.get("designBrief", {}).get("sourceConflict", "")).is_empty() \
			or String(r.get("designBrief", {}).get("sourceConflict", "")).is_empty() \
			or l.get("designBrief", {}).get("midground") == r.get("designBrief", {}).get("midground") \
			or l.get("selectedScene") != "res://scenes/duel_stage_village_2d.tscn" \
			or r.get("selectedScene") != "res://scenes/duel_stage_village_2d.tscn":
		_fail("village branches must preserve the source well chamber with distinct combat direction")
		return
	if not visual.resolve(left, "trial_v7").is_empty() \
			or not visual.resolve({"battlefieldId": "forged"}).is_empty():
		_fail("unknown or wrong-candidate battlefield was silently accepted")
		return
	var village_candidate: Dictionary = visual.resolve(left, "village_well_v1")
	if village_candidate.get("selectedScene") != "res://scenes/village_well_chamber_candidate.tscn" \
			or not visual.resolve(right, "village_well_v1").is_empty() \
			or not visual.resolve(left, "village_shrine_v1").is_empty():
		_fail("well chamber candidate must resolve only for its source left branch")
		return
	var village_scene := load(String(village_candidate["selectedScene"])) as PackedScene
	if village_scene == null:
		_fail("well chamber candidate is not a loadable Godot 3D scene")
		return
	var unbuilt_stage: Node = DuelStage.instantiate()
	unbuilt_stage.use_trial_v7_candidate = true
	if unbuilt_stage.bind_stage_context(left) or not unbuilt_stage.stage_art.is_empty():
		_fail("Godot scene binder accepted trial hall for the village")
		return
	unbuilt_stage.free()
	var tomb_left: Dictionary = router.resolve_choice("thread_sword_tomb_2", "left",
		{"id": "thread_sword_tomb_2"}, "enc:0:9:tomb:left", pending, "sword", "foundation")
	var tomb_right: Dictionary = router.resolve_choice("thread_sword_tomb_2", "right",
		{"id": "thread_sword_tomb_2"}, "enc:0:9:tomb:right", pending, "sword", "foundation")
	if tomb_left.get("battlefieldId") != tomb_right.get("battlefieldId") \
			or tomb_left.get("presentationId") == tomb_right.get("presentationId"):
		_fail("tomb shared geometry lost distinct presentation identities")
		return
	print("BATTLEFIELD_ART_REGISTRY_PASS first=v17_tutorial candidate=v16,v7 village=well_chamber_candidate tomb=shared")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
