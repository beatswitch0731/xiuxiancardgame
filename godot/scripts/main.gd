extends Control

signal battle_finished(result: Dictionary)

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/combat_domain.gd")
const BrowserCombatActions = preload("res://scripts/noncombat_browser_combat_actions.gd")
const HandUI = preload("res://scripts/card_hand_ui.gd")
const CardPlacementDesk = preload("res://scripts/card_placement_desk.gd")
const ReferenceBattleHUD = preload("res://scripts/reference_battle_hud.gd")
const DUEL_STAGE_HD2D_PATH := "res://scenes/duel_stage_hd2d.tscn"
const PIXEL_DUNGEON_STAGE_PATH := "res://scenes/duel_stage_pixel_dungeon.tscn"
const QingyunPixelStageScene = preload("res://scenes/qingyun_pixel_battle_stage.tscn")
const SpellStageScene = preload("res://scenes/duel_stage_spell_2d.tscn")
const BodyStageScene = preload("res://scenes/duel_stage_body_2d.tscn")
const PillStageScene = preload("res://scenes/duel_stage_pill_2d.tscn")
const MountainStageScene = preload("res://scenes/duel_stage_mountain_2d.tscn")
const WhitefoxStageScene = preload("res://scenes/duel_stage_whitefox_2d.tscn")
const FellowStageScene = preload("res://scenes/duel_stage_fellow_2d.tscn")
const MissionStageScene = preload("res://scenes/duel_stage_mission_2d.tscn")
const GuardianStageScene = preload("res://scenes/duel_stage_guardian_2d.tscn")
const QiGateStageScene = preload("res://scenes/duel_stage_qi_gate_2d.tscn")
const FoundationGateStageScene = preload("res://scenes/duel_stage_foundation_gate_2d.tscn")
const GoldenGateStageScene = preload("res://scenes/duel_stage_golden_gate_2d.tscn")
const NascentGateStageScene = preload("res://scenes/duel_stage_nascent_gate_2d.tscn")
const DeityGateStageScene = preload("res://scenes/duel_stage_deity_gate_2d.tscn")
const TribulationGateStageScene = preload("res://scenes/duel_stage_tribulation_gate_2d.tscn")
const BanditStageScene = preload("res://scenes/duel_stage_bandit_2d.tscn")
const NascentHuntStageScene = preload("res://scenes/duel_stage_nascent_hunt_2d.tscn")
const NascentRuinsStageScene = preload("res://scenes/duel_stage_nascent_ruins_2d.tscn")
const TrialStageScene = preload("res://scenes/duel_stage_immortal_shadow_2d.tscn")
const FoundationCatalogStageScene = preload("res://scenes/duel_stage_foundation_catalog_2d.tscn")
const FactionWumengStageScene = preload("res://scenes/duel_stage_faction_wumeng_2d.tscn")
const CompanionOldMasterStageScene = preload("res://scenes/duel_stage_companion_old_master_2d.tscn")
const VillageStageScene = preload("res://scenes/duel_stage_village_2d.tscn")
const SwordTombStageScene = preload("res://scenes/duel_stage_sword_tomb_2d.tscn")
const LastLessonStageScene = preload("res://scenes/duel_stage_last_lesson_2d.tscn")
const StageRouter = preload("res://scripts/combat_stage_router.gd")
const GameSkin = preload("res://scripts/game_ui_skin.gd")
const IntentSlip = preload("res://scripts/battle_intent_slip.gd")
const INK_FONT = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const STATUS_PLAQUE = preload("res://assets/ui/hud_materials/status_plaque_v1.png")
const INTENT_SLIP = preload("res://assets/ui/hud_materials/intent_slip_v1.png")

var data: RefCounted
var combat: RefCounted
var duel_stage
var title_label: Label
var player_info_back: Panel
var enemy_info_back: Panel
var intent_slip
var state_slip_anchor: Control
var state_info_back: Panel
var player_health_track: ColorRect
var player_health_fill: ColorRect
var player_qi_track: ColorRect
var player_qi_fill: ColorRect
var enemy_health_track: ColorRect
var enemy_health_fill: ColorRect
var player_label: Label
var enemy_label: Label
var state_label: Label
var hand_row: HBoxContainer
var card_table: Control
var reference_hud: Control
var end_button: Button
var flee_button: Button
var return_button: Button
var battle_request: Dictionary = {}
var browser_combat_snapshot: Dictionary = {}
var browser_combat_authority: Dictionary = {}
var browser_combat_actions: Array = []
var browser_combat_commit_card: Callable
var browser_combat_commit_end_turn: Callable
var browser_combat_commit_reaction: Callable
var battle_plan: Dictionary = {}
var flee_allowed := true
var actor_study_selector: OptionButton
var armor_study_selector: OptionButton
var reaction_buttons: Array[Button] = []
var pending_presentations := 0
var presentation_problem := ""
var stage_assets_ready := true
var _held_enemy_hp := -1
var _held_enemy_block := -1
var _held_player_hp := -1
var _hold_outcome := false
var _state_wind_time := 0.0
var _state_drop_elapsed := 1.0
var _last_state_message := ""
var stage_context: Dictionary = {}
var battle_title := ""
var outdoor_candidate_preview := false
var trial_v4_candidate_preview := false
var trial_v5_candidate_preview := false
var trial_v6_candidate_preview := false
var trial_v7_candidate_preview := false
var trial_v8_candidate_preview := false
var trial_v9_candidate_preview := false
var trial_v10_candidate_preview := false
var trial_v11_candidate_preview := false
var trial_v13_candidate_preview := false
var trial_v14_candidate_preview := false
var trial_v15_candidate_preview := false
var trial_v16_candidate_preview := false
var trial_v17_candidate_preview := false
var breath_v17_candidate_preview := false
@export var pixel_dungeon_demo_preview := false
@export var modular_actor_demo_preview := false
@export var reference_frontend_preview := false


func _ready() -> void:
	reference_frontend_preview = reference_frontend_preview or "--reference-battle-demo" in OS.get_cmdline_user_args()
	modular_actor_demo_preview = modular_actor_demo_preview or "--modular-actor-demo" in OS.get_cmdline_user_args()
	pixel_dungeon_demo_preview = pixel_dungeon_demo_preview or "--pixel-dungeon-demo" in OS.get_cmdline_user_args()
	pixel_dungeon_demo_preview = pixel_dungeon_demo_preview or modular_actor_demo_preview
	outdoor_candidate_preview = outdoor_candidate_preview or "--outdoor-candidate" in OS.get_cmdline_user_args()
	trial_v4_candidate_preview = trial_v4_candidate_preview or "--trial-v4-candidate" in OS.get_cmdline_user_args()
	trial_v5_candidate_preview = trial_v5_candidate_preview or "--trial-v5-candidate" in OS.get_cmdline_user_args()
	trial_v6_candidate_preview = trial_v6_candidate_preview or "--trial-v6-candidate" in OS.get_cmdline_user_args()
	trial_v7_candidate_preview = trial_v7_candidate_preview or "--trial-v7-candidate" in OS.get_cmdline_user_args()
	trial_v8_candidate_preview = trial_v8_candidate_preview or "--trial-v8-candidate" in OS.get_cmdline_user_args()
	trial_v9_candidate_preview = trial_v9_candidate_preview or "--trial-v9-candidate" in OS.get_cmdline_user_args()
	trial_v10_candidate_preview = trial_v10_candidate_preview or "--trial-v10-candidate" in OS.get_cmdline_user_args()
	trial_v11_candidate_preview = trial_v11_candidate_preview or "--trial-v11-candidate" in OS.get_cmdline_user_args()
	trial_v13_candidate_preview = trial_v13_candidate_preview or "--trial-v13-candidate" in OS.get_cmdline_user_args()
	trial_v14_candidate_preview = trial_v14_candidate_preview or "--trial-v14-candidate" in OS.get_cmdline_user_args()
	trial_v15_candidate_preview = trial_v15_candidate_preview or "--trial-v15-candidate" in OS.get_cmdline_user_args()
	trial_v16_candidate_preview = trial_v16_candidate_preview or "--trial-v16-candidate" in OS.get_cmdline_user_args()
	trial_v17_candidate_preview = trial_v17_candidate_preview or "--trial-v17-candidate" in OS.get_cmdline_user_args()
	breath_v17_candidate_preview = breath_v17_candidate_preview or "--breath-v17-candidate" in OS.get_cmdline_user_args()
	data = Registry.new()
	combat = Domain.new(data)
	var loaded: bool = combat.load_persisted_request(battle_request, battle_plan) \
		if not battle_request.is_empty() else combat.load_m0_opening()
	if not loaded:
		push_error("Persisted battle request could not load" if not battle_request.is_empty() \
			else "M0 browser combat state did not load")
		return
	if not browser_combat_snapshot.is_empty() and not combat.load_browser_first_sword_snapshot(
			browser_combat_snapshot, browser_combat_authority, battle_request):
		push_error("Imported browser combat snapshot could not hydrate")
		return
	if not browser_combat_snapshot.is_empty() and not browser_combat_actions.is_empty():
		var resumed: Dictionary = BrowserCombatActions.new().replay(
			browser_combat_snapshot, browser_combat_authority, battle_request,
			battle_plan, browser_combat_actions, data)
		if resumed.is_empty():
			push_error("Imported browser combat actions could not replay")
			return
		combat.state = resumed
	var inline_whitefox: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "q_whiteFox_3"
	var inline_fellow: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "q_fellow"
	var inline_mission: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "f_mission"
	var inline_bandit: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "ds_female_bandit"
	var inline_nascent: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") in ["n_hunt", "ar_boss"]
	var inline_trial: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "it_combat"
	var inline_guardian: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "realm_guardian"
	var qi_gate: bool = battle_request.get("encounterId") == "ch_qi_100" \
		and battle_request.get("sourceCardId") == "ch_qi_100"
	var foundation_gate: bool = battle_request.get("encounterId") == "ch_foundation_100" \
		and battle_request.get("sourceCardId") == "ch_foundation_100"
	var golden_gate: bool = battle_request.get("encounterId") == "ch_golden_100" \
		and battle_request.get("sourceCardId") == "ch_golden_100"
	var nascent_gate: bool = battle_request.get("encounterId") == "ch_nascent_100" \
		and battle_request.get("sourceCardId") == "ch_nascent_100"
	var deity_gate: bool = battle_request.get("encounterId") == "ch_deity_100" \
		and battle_request.get("sourceCardId") == "ch_deity_100"
	var tribulation_gate: bool = battle_request.get("encounterId") == "ch_tribulation_100" \
		and battle_request.get("sourceCardId") == "ch_tribulation_100"
	var catalog_encounter_id: Variant = battle_request.get("encounterId")
	var foundation_catalog: bool = battle_request.get("realm") == "foundation" \
		and catalog_encounter_id is String \
		and battle_request.get("sourceCardId") == "encounter_card_" + catalog_encounter_id
	var faction: bool = battle_request.get("sourceCardId") == "faction_wumeng_gatekeeper_call" \
		and battle_request.get("encounterId") == "enc_faction_wumeng_elite"
	var companion: bool = battle_request.get("sourceCardId") == "comp_jian_linger_jle_8_sword_tomb_old_master" \
		and battle_request.get("encounterId") == "enc_companion_jian_linger_tomb"
	var inline_village: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "thread_ab_village_3"
	var inline_sword_tomb: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") in ["thread_sword_tomb_2", "q_sword_3"]
	var inline_last_lesson: bool = battle_request.get("encounterId") == null \
		and battle_request.get("sourceCardId") == "thread_last_lesson_n3"
	if inline_whitefox or inline_fellow or inline_mission or inline_bandit or inline_nascent or inline_trial or inline_guardian or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or foundation_catalog or faction or companion or inline_village or inline_sword_tomb or inline_last_lesson:
		stage_context = StageRouter.new(data).resolve_choice(
			String(battle_request["sourceCardId"]), String(battle_request["direction"]),
			battle_request.get("pendingResolution", {}).get("combatCard", {}),
			String(battle_request["encounterInstanceId"]),
			battle_request.get("pendingResolution", {}), String(battle_request["path"]),
			String(battle_request["realm"]))
		battle_title = String(battle_request.get("pendingResolution", {}).get(
			"sourceCard", {}).get("title", ""))
	else:
		stage_context = StageRouter.new(data).resolve_encounter(String(combat.state["encounterId"]))
	if stage_context.is_empty():
		push_error("Source encounter lacks a valid battlefield presentation")
		return
	if not battle_request.is_empty():
		stage_context["path"] = battle_plan.get("path", "")
		stage_context["deck"] = battle_plan.get("deck", []).duplicate(true)
	for row in data.read_json("data/combat/encounters.json").get("encounters", []):
		if row is Dictionary and row.get("id") == combat.state["encounterId"]:
			battle_title = String(row.get("title", ""))
			break
	if not _build():
		return
	combat.changed.connect(_on_combat_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_render()
	print("MIGRATED_RUNTIME_READY encounter=", combat.state["encounterId"],
		" cards=", combat.state["hand"].size(),
		" stage=", "source_2d" if faction or inline_whitefox or inline_fellow or inline_mission or inline_bandit or inline_trial or inline_guardian or inline_village or inline_sword_tomb or inline_last_lesson or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or combat.state["encounterId"] in [
			"enc_trial_spell_seal", "enc_trial_body_iron", "enc_trial_pill_poison",
			"enc_patrol_qi_mountain_shadow"] else (
			"hd2d_actor_v1" if reference_frontend_preview else (
			"pixel_dungeon_demo" if pixel_dungeon_demo_preview else (
				"qingyun_pixel" if duel_stage.name == "QingyunPixelStage" else "hd2d"))),
		" assets_ready=", stage_assets_ready,
		" outdoor_candidate=", outdoor_candidate_preview)
	if trial_v4_candidate_preview:
		print("CANGMANG_V4_CANDIDATE_ACTIVE")
	if trial_v5_candidate_preview:
		print("CANGMANG_V5_CANDIDATE_ACTIVE")
	if trial_v6_candidate_preview:
		print("CANGMANG_V6_CANDIDATE_ACTIVE")
	if trial_v7_candidate_preview:
		print("QINGYUN_V7_CANDIDATE_ACTIVE")
	if trial_v8_candidate_preview:
		print("QINGYUN_V8_TEMPLE_CANDIDATE_ACTIVE")
	if trial_v9_candidate_preview:
		print("CANGMANG_V9_SCAN_RELIEF_CANDIDATE_ACTIVE")
	if trial_v10_candidate_preview:
		print("CANGMANG_V10_AUTHORED_PAVERS_CANDIDATE_ACTIVE")
	if trial_v11_candidate_preview:
		print("CANGMANG_V11_REFINED_PAVERS_CANDIDATE_ACTIVE")
	if trial_v13_candidate_preview:
		print("QINGYUN_V13_MATCHED_STANCE_AND_SLATE_CANDIDATE_ACTIVE")
	if trial_v14_candidate_preview:
		print("CANGMANG_V14_HALL_COMPOSITION_CANDIDATE_ACTIVE")
	if trial_v15_candidate_preview:
		print("CANGMANG_V15_IN_WORLD_PROP_CANDIDATE_ACTIVE")
	if trial_v16_candidate_preview:
		print("CANGMANG_V16_CONSOLE_WEAR_CANDIDATE_ACTIVE")
	if trial_v17_candidate_preview:
		print("QINGYUN_V17_TUTORIAL_HALL_CANDIDATE_ACTIVE")
	if breath_v17_candidate_preview:
		print("FIRST_FIGHT_BREATH_V17_CANDIDATE_ACTIVE")


func _build() -> bool:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC-VF.ttf")
	self.theme = theme
	var raw_encounter_id: Variant = combat.state.get("encounterId")
	var encounter_id := String(raw_encounter_id) if raw_encounter_id is String else ""
	var inline_whitefox: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "q_whiteFox_3"
	var inline_fellow: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "q_fellow"
	var inline_mission: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "f_mission"
	var inline_bandit: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "ds_female_bandit"
	var inline_nascent: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") in ["n_hunt", "ar_boss"]
	var inline_trial: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "it_combat"
	var inline_guardian: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "realm_guardian"
	var qi_gate: bool = raw_encounter_id == "ch_qi_100" \
		and battle_request.get("sourceCardId") == "ch_qi_100"
	var foundation_gate: bool = raw_encounter_id == "ch_foundation_100" \
		and battle_request.get("sourceCardId") == "ch_foundation_100"
	var golden_gate: bool = raw_encounter_id == "ch_golden_100" \
		and battle_request.get("sourceCardId") == "ch_golden_100"
	var nascent_gate: bool = raw_encounter_id == "ch_nascent_100" \
		and battle_request.get("sourceCardId") == "ch_nascent_100"
	var deity_gate: bool = raw_encounter_id == "ch_deity_100" \
		and battle_request.get("sourceCardId") == "ch_deity_100"
	var tribulation_gate: bool = raw_encounter_id == "ch_tribulation_100" \
		and battle_request.get("sourceCardId") == "ch_tribulation_100"
	var foundation_catalog: bool = battle_request.get("realm") == "foundation" \
		and battle_request.get("sourceCardId") == "encounter_card_" + encounter_id
	var faction: bool = battle_request.get("sourceCardId") == "faction_wumeng_gatekeeper_call" \
		and encounter_id == "enc_faction_wumeng_elite"
	var companion: bool = battle_request.get("sourceCardId") == "comp_jian_linger_jle_8_sword_tomb_old_master" \
		and encounter_id == "enc_companion_jian_linger_tomb"
	var inline_village: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "thread_ab_village_3"
	var inline_sword_tomb: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") in ["thread_sword_tomb_2", "q_sword_3"]
	var inline_last_lesson: bool = raw_encounter_id == null \
		and battle_request.get("sourceCardId") == "thread_last_lesson_n3"
	var source_stage: bool = encounter_id in [
		"enc_trial_spell_seal", "enc_trial_body_iron", "enc_trial_pill_poison",
		"enc_patrol_qi_mountain_shadow"] or faction or companion or inline_whitefox or inline_fellow or inline_mission or inline_bandit or inline_nascent or inline_trial or inline_guardian or qi_gate or foundation_gate or golden_gate or nascent_gate or deity_gate or tribulation_gate or foundation_catalog \
		or inline_village or inline_sword_tomb or inline_last_lesson
	var trial_candidate_preview := outdoor_candidate_preview or trial_v4_candidate_preview \
		or trial_v5_candidate_preview or trial_v6_candidate_preview or trial_v7_candidate_preview \
		or trial_v8_candidate_preview or trial_v9_candidate_preview or trial_v10_candidate_preview \
		or trial_v11_candidate_preview or trial_v13_candidate_preview or trial_v14_candidate_preview \
		or trial_v15_candidate_preview or trial_v16_candidate_preview or trial_v17_candidate_preview \
		or breath_v17_candidate_preview
	var qingyun_pixel := encounter_id == "enc_trial_sword_swift" and not source_stage \
		and not pixel_dungeon_demo_preview and not reference_frontend_preview \
		and not trial_candidate_preview
	if inline_whitefox:
		duel_stage = WhitefoxStageScene.instantiate()
	elif inline_fellow:
		duel_stage = FellowStageScene.instantiate()
	elif inline_mission:
		duel_stage = MissionStageScene.instantiate()
	elif inline_bandit:
		duel_stage = BanditStageScene.instantiate()
	elif inline_nascent:
		duel_stage = NascentHuntStageScene.instantiate() if battle_request.get(
			"sourceCardId") == "n_hunt" else NascentRuinsStageScene.instantiate()
	elif inline_trial:
		duel_stage = TrialStageScene.instantiate()
	elif inline_guardian:
		duel_stage = GuardianStageScene.instantiate()
	elif qi_gate:
		duel_stage = QiGateStageScene.instantiate()
	elif foundation_gate:
		duel_stage = FoundationGateStageScene.instantiate()
	elif golden_gate:
		duel_stage = GoldenGateStageScene.instantiate()
	elif nascent_gate:
		duel_stage = NascentGateStageScene.instantiate()
	elif deity_gate:
		duel_stage = DeityGateStageScene.instantiate()
	elif tribulation_gate:
		duel_stage = TribulationGateStageScene.instantiate()
	elif foundation_catalog:
		duel_stage = FoundationCatalogStageScene.instantiate()
	elif faction:
		duel_stage = FactionWumengStageScene.instantiate()
	elif companion:
		duel_stage = CompanionOldMasterStageScene.instantiate()
	elif inline_village:
		duel_stage = VillageStageScene.instantiate()
	elif inline_sword_tomb:
		duel_stage = SwordTombStageScene.instantiate()
	elif inline_last_lesson:
		duel_stage = LastLessonStageScene.instantiate()
	elif encounter_id == "enc_trial_spell_seal":
		duel_stage = SpellStageScene.instantiate()
	elif encounter_id == "enc_trial_body_iron":
		duel_stage = BodyStageScene.instantiate()
	elif encounter_id == "enc_trial_pill_poison":
		duel_stage = PillStageScene.instantiate()
	elif encounter_id == "enc_patrol_qi_mountain_shadow":
		duel_stage = MountainStageScene.instantiate()
	else:
		if pixel_dungeon_demo_preview:
			var pixel_scene: PackedScene = load(PIXEL_DUNGEON_STAGE_PATH)
			duel_stage = pixel_scene.instantiate()
		elif qingyun_pixel:
			duel_stage = QingyunPixelStageScene.instantiate()
		else:
			var hd2d_scene: PackedScene = load(DUEL_STAGE_HD2D_PATH)
			duel_stage = hd2d_scene.instantiate()
	duel_stage.name = "DuelStageSource2D" if source_stage else (
		"PixelDungeonStage" if pixel_dungeon_demo_preview else (
			"QingyunPixelStage" if qingyun_pixel else "DuelStageHD2D"))
	if reference_frontend_preview and not source_stage:
		duel_stage.use_reference_actor_style = true
	if modular_actor_demo_preview and not source_stage:
		duel_stage.modular_actor_demo_preview = true
	if not pixel_dungeon_demo_preview and not reference_frontend_preview and not source_stage and not qingyun_pixel:
		duel_stage.use_outdoor_candidate = outdoor_candidate_preview
		duel_stage.use_trial_v4_candidate = trial_v4_candidate_preview
		duel_stage.use_trial_v5_candidate = trial_v5_candidate_preview
		duel_stage.use_trial_v6_candidate = trial_v6_candidate_preview
		duel_stage.use_trial_v7_candidate = trial_v7_candidate_preview
		duel_stage.use_trial_v8_candidate = trial_v8_candidate_preview
		duel_stage.use_trial_v9_candidate = trial_v9_candidate_preview
		duel_stage.use_trial_v10_candidate = trial_v10_candidate_preview
		duel_stage.use_trial_v11_candidate = trial_v11_candidate_preview
		duel_stage.use_trial_v13_candidate = trial_v13_candidate_preview
		duel_stage.use_trial_v14_candidate = trial_v14_candidate_preview
		duel_stage.use_trial_v15_candidate = trial_v15_candidate_preview
		duel_stage.use_trial_v16_candidate = trial_v16_candidate_preview
		duel_stage.use_trial_v17_candidate = trial_v17_candidate_preview
		duel_stage.use_breath_v17_candidate = breath_v17_candidate_preview
	if not duel_stage.bind_stage_context(stage_context):
		push_error("No runnable art for battlefieldId=" + String(stage_context.get("battlefieldId", "")))
		return false
	add_child(duel_stage)
	duel_stage.presentation_finished.connect(_on_presentation_finished)
	duel_stage.presentation_missing.connect(_on_presentation_missing)
	duel_stage.contact_frame.connect(_on_contact_frame)
	stage_assets_ready = duel_stage.has_hd2d_assets()
	if not stage_assets_ready:
		presentation_problem = "首战场地或角色序列未就绪"
	var veil := ColorRect.new()
	veil.color = Color(0.035, 0.06, 0.075, 0.12)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var header := Panel.new()
	header.name = "Header"
	_add_material_panel(header, STATUS_PLAQUE)
	header.visible = false
	card_table = CardPlacementDesk.new()
	card_table.name = "CardTable"
	card_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_table)
	player_info_back = Panel.new()
	_add_status_panel(player_info_back)
	enemy_info_back = Panel.new()
	_add_status_panel(enemy_info_back)
	intent_slip = IntentSlip.new()
	add_child(intent_slip)
	state_slip_anchor = Control.new()
	state_slip_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(state_slip_anchor)
	state_info_back = Panel.new()
	_add_material_panel(state_info_back, INTENT_SLIP)
	state_info_back.reparent(state_slip_anchor)
	player_health_track = _bar(Color("27312e"))
	player_health_fill = _bar(GameSkin.WARM_RED)
	player_qi_track = _bar(Color("27312e"))
	player_qi_fill = _bar(GameSkin.JADE)
	enemy_health_track = _bar(Color("27312e"))
	enemy_health_fill = _bar(Color("c28b70"))
	title_label = _label(18, GameSkin.PAPER)
	title_label.add_theme_font_override("font", INK_FONT)
	title_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.02, 0.02, 0.9))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	player_label = _label(15, GameSkin.PAPER)
	enemy_label = _label(15, GameSkin.PAPER)
	player_label.add_theme_font_override("font", INK_FONT)
	enemy_label.add_theme_font_override("font", INK_FONT)
	state_label = _label(13, GameSkin.DEEP_INK)
	state_label.add_theme_font_override("font", INK_FONT)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.reparent(state_info_back)
	hand_row = HandUI.new()
	hand_row.card_selected.connect(card_table.confirm_card)
	hand_row.card_selected.connect(_play_card)
	hand_row.card_hovered.connect(card_table.set_hovered_card)
	add_child(hand_row)
	end_button = Button.new()
	end_button.text = "结束回合"
	GameSkin.apply_action_button(end_button, GameSkin.BRASS)
	end_button.add_theme_font_override("font", INK_FONT)
	end_button.pressed.connect(_end_turn)
	add_child(end_button)
	if not battle_request.is_empty():
		flee_button = Button.new()
		flee_button.name = "FleeBattle"
		flee_button.text = "撤离战场"
		GameSkin.apply_action_button(flee_button, GameSkin.JADE)
		flee_button.add_theme_font_override("font", INK_FONT)
		flee_button.pressed.connect(func() -> void: combat.flee())
		add_child(flee_button)
		return_button = Button.new()
		return_button.name = "ReturnToStory"
		return_button.text = "结算并返回剧情"
		GameSkin.apply_action_button(return_button, GameSkin.BRASS)
		return_button.add_theme_font_override("font", INK_FONT)
		return_button.pressed.connect(_return_to_story)
		add_child(return_button)
	if modular_actor_demo_preview:
		actor_study_selector = OptionButton.new()
		actor_study_selector.name = "ActorStudySelector"
		for label in ["A 原版整帧", "B 视觉候选·空手", "B 视觉候选·练习剑", "B 视觉候选·残剑"]:
			actor_study_selector.add_item(label)
		actor_study_selector.select(2)
		_style_study_selector(actor_study_selector)
		actor_study_selector.item_selected.connect(func(index: int) -> void:
			duel_stage.set_actor_study_variant(["old_frames", "unarmed", "practice_sword", "traded_rusted_sword"][index])
			armor_study_selector.disabled = index == 0)
		add_child(actor_study_selector)
		armor_study_selector = OptionButton.new()
		armor_study_selector.name = "ArmorStudySelector"
		armor_study_selector.add_item("无甲")
		armor_study_selector.add_item("玄铁甲")
		armor_study_selector.select(0)
		_style_study_selector(armor_study_selector)
		armor_study_selector.item_selected.connect(func(index: int) -> void:
			duel_stage.set_actor_study_armor("玄铁甲" if index == 1 else ""))
		add_child(armor_study_selector)
	for reaction_id in ["TAKE_HIT", "DEFLECT", "GUARD", "EVADE"]:
		var button := Button.new()
		button.name = "Reaction_" + reaction_id
		GameSkin.apply_paper_button(button, GameSkin.JADE)
		button.add_theme_font_override("font", INK_FONT)
		button.pressed.connect(_choose_reaction.bind(reaction_id))
		reaction_buttons.append(button)
		add_child(button)
	if reference_frontend_preview:
		reference_hud = ReferenceBattleHUD.new()
		add_child(reference_hud)
		reference_hud.set_registry(data)
		hand_row.card_hovered.connect(reference_hud.set_hovered_card)
		_apply_reference_skin()
	return true


func _apply_reference_skin() -> void:
	var status := StyleBoxFlat.new()
	status.bg_color = Color(0.045, 0.071, 0.085, 0.94)
	status.border_color = Color("8c7956")
	status.set_border_width_all(1)
	status.set_corner_radius_all(3)
	player_info_back.add_theme_stylebox_override("panel", status)
	enemy_info_back.add_theme_stylebox_override("panel", status.duplicate())
	for button in reaction_buttons + [end_button]:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("172832")
		normal.border_color = Color("aa956d")
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(3)
		button.add_theme_stylebox_override("normal", normal)
		var highlighted := normal.duplicate() as StyleBoxFlat
		highlighted.bg_color = Color("294453")
		button.add_theme_stylebox_override("hover", highlighted)
		button.add_theme_stylebox_override("focus", highlighted)
		button.add_theme_stylebox_override("pressed", highlighted)
		button.add_theme_color_override("font_color", Color("f0e9d8"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
	intent_slip.visible = false
	state_slip_anchor.visible = false


func _style_study_selector(selector: OptionButton) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.055, 0.075, 0.94)
	panel.border_color = Color(0.53, 0.45, 0.29)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(7)
	selector.add_theme_stylebox_override("normal", panel)
	selector.add_theme_stylebox_override("hover", panel)
	selector.add_theme_stylebox_override("pressed", panel)
	selector.add_theme_color_override("font_color", Color(0.95, 0.92, 0.83))
	selector.add_theme_color_override("font_hover_color", Color.WHITE)
	selector.add_theme_color_override("font_pressed_color", Color.WHITE)


func _process(delta: float) -> void:
	if state_info_back == null:
		return
	_state_wind_time += delta
	_state_drop_elapsed = minf(1.0, _state_drop_elapsed + delta / 0.43)
	var remaining := 1.0 - _state_drop_elapsed
	var drop_y := -7.0 * remaining * remaining \
		+ 0.6 * sin(_state_drop_elapsed * TAU) * remaining
	state_info_back.position = Vector2(
		0.22 * sin(_state_wind_time * 1.08),
		drop_y + 0.34 * sin(_state_wind_time * 1.31 + 0.4))
	state_info_back.rotation = deg_to_rad(0.20 * sin(_state_wind_time * 1.04))


func _add_material_panel(panel: Panel, material: Texture2D) -> void:
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var texture := TextureRect.new()
	texture.texture = material
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(texture)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _add_status_panel(panel: Panel) -> void:
	panel.add_theme_stylebox_override("panel", GameSkin.plaque(0.94))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)


func _label(font_size: int, tint: Color) -> Label:
	var item := Label.new()
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", tint)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	return item


func _bar(tint: Color) -> ColorRect:
	var item := ColorRect.new()
	item.color = tint
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(item)
	return item


func _layout() -> void:
	var size_now := get_viewport().get_visible_rect().size
	var hand_width := minf(620.0 if reference_frontend_preview and size_now.x >= 1120.0 else 520.0 if reference_frontend_preview else 540.0, size_now.x - 74.0)
	var hand_left := (size_now.x - hand_width) * 0.5
	$Header.position = Vector2(18, 10)
	$Header.size = Vector2(260, 34)
	_layout_card_table()
	player_info_back.position = Vector2(18, 49)
	player_info_back.size = Vector2(306, 68)
	enemy_info_back.position = Vector2(size_now.x - 324, 49)
	enemy_info_back.size = Vector2(306, 68)
	intent_slip.position = Vector2(size_now.x - 324, 124)
	intent_slip.size.x = 306
	title_label.position = Vector2(21, 9)
	title_label.size = Vector2(300, 29)
	player_label.position = Vector2(31, 57)
	player_label.size = Vector2(279, 24)
	enemy_label.position = Vector2(size_now.x - 311, 57)
	enemy_label.size = Vector2(279, 24)
	player_health_track.position = Vector2(31, 88)
	player_health_track.size = Vector2(279, 7)
	player_health_fill.position = player_health_track.position
	player_qi_track.position = Vector2(31, 101)
	player_qi_track.size = Vector2(279, 4)
	player_qi_fill.position = player_qi_track.position
	enemy_health_track.position = Vector2(size_now.x - 311, 88)
	enemy_health_track.size = Vector2(279, 7)
	enemy_health_fill.position = enemy_health_track.position
	hand_row.position = Vector2(hand_left, size_now.y - 190.0)
	hand_row.size = Vector2(hand_width, 176)
	_layout_state_hint()
	end_button.position = Vector2(size_now.x - 128, 12)
	end_button.size = Vector2(110, 34)
	if flee_button != null:
		flee_button.position = Vector2(size_now.x - 155, size_now.y - 140)
		flee_button.size = Vector2(130, 38)
	if return_button != null:
		return_button.position = Vector2(size_now.x - 205, 12)
		return_button.size = Vector2(187, 34)
	if actor_study_selector != null:
		actor_study_selector.position = Vector2(maxf(330.0, (size_now.x - 230.0) * 0.5), 9)
		actor_study_selector.size = Vector2(230, 35)
		armor_study_selector.position = actor_study_selector.position + Vector2(240, 0)
		armor_study_selector.size = Vector2(150, 35)
	for index in range(reaction_buttons.size()):
		reaction_buttons[index].position = Vector2(size_now.x - 420 + index * 102, 12)
		reaction_buttons[index].size = Vector2(94, 34)
	if reference_frontend_preview:
		reference_hud.layout_for(size_now)
		end_button.position = Vector2(size_now.x - 144, size_now.y - 63)
		end_button.size = Vector2(126, 42)
		if flee_button != null:
			flee_button.position = Vector2(size_now.x - 148, size_now.y - 111)
			flee_button.size = Vector2(130, 36)
		for index in range(reaction_buttons.size()):
			reaction_buttons[index].position = Vector2((size_now.x - 408) * 0.5 + index * 102, size_now.y - 236)
	_update_health_bars()
	_render_hand()


func _layout_state_hint() -> void:
	var size_now := get_viewport().get_visible_rect().size
	var hand_width := minf(540.0, size_now.x - 74.0)
	var hand_left := (size_now.x - hand_width) * 0.5
	var height := 48.0 if not presentation_problem.is_empty() else 32.0
	var width := minf(248.0 if not presentation_problem.is_empty() else 166.0,
		hand_left - 34.0)
	state_slip_anchor.position = Vector2(18, size_now.y - 45.0 - height)
	state_slip_anchor.size = Vector2(width, height)
	state_info_back.size = Vector2(width, height)
	state_label.position = Vector2(22, 5)
	state_label.size = state_info_back.size - Vector2(30, 9)


func _render() -> void:
	var run: Dictionary = combat.state
	title_label.text = battle_title
	player_label.text = "叶凌云  气血 %d/%d  护盾 %d  真元 %d/%d" % [_held_player_hp if _held_player_hp >= 0 else run["player"]["hp"], run["player"]["maxHp"], run["player"]["block"], run["qi"], run["maxQi"]]
	enemy_label.text = "%s  气血 %d/%d  护盾 %d" % [run["enemy"]["name"], _held_enemy_hp if _held_enemy_hp >= 0 else run["enemy"]["hp"], run["enemy"]["maxHp"], _held_enemy_block if _held_enemy_block >= 0 else run["enemy"]["block"]]
	intent_slip.set_intent(int(run["turn"]), run["enemyIntent"])
	var phase := String(run["phase"])
	var state_message := "选择卡牌出招"
	if _hold_outcome and phase in ["VICTORY", "DEFEAT"]:
		state_message = "招式结算中"
	elif phase == "VICTORY":
		state_message = "战斗胜利"
	elif phase == "DEFEAT":
		state_message = "战斗失败"
	elif phase == "FLEE":
		state_message = "已经撤离战场"
	elif phase == "REACTION_OPEN":
		state_message = "敌袭 · 选择反应"
	elif not browser_combat_snapshot.is_empty() and int(run.get("turn", 1)) > 1:
		state_message = "已接过敌方一击；后续回合尚未开放，可撤离结算"
	if not presentation_problem.is_empty():
		state_message = presentation_problem
	_set_state_message(state_message)
	_layout_state_hint()
	_update_health_bars()
	end_button.visible = phase == "PLAYER_TURN"
	var imported_end_supported: bool = browser_combat_actions.size() == 2 \
		and browser_combat_actions[0].get("cardId") == "sword_edge" \
		and browser_combat_actions[1].get("cardId") == "sword_followthrough"
	end_button.disabled = phase != "PLAYER_TURN" or combat.input_locked \
		or (not browser_combat_snapshot.is_empty() \
			and not imported_end_supported)
	if flee_button != null:
		flee_button.visible = flee_allowed and phase in ["PLAYER_TURN", "REACTION_OPEN"]
		flee_button.disabled = combat.input_locked
	if return_button != null:
		return_button.visible = phase in ["VICTORY", "DEFEAT", "FLEE"]
		return_button.disabled = combat.input_locked or pending_presentations > 0
	if actor_study_selector != null:
		actor_study_selector.visible = phase != "REACTION_OPEN"
		armor_study_selector.visible = phase != "REACTION_OPEN"
	var options: Array = combat.reaction_options()
	for index in range(reaction_buttons.size()):
		var option: Dictionary = options[index] if index < options.size() else {}
		reaction_buttons[index].text = String(option.get("label", ["承受", "偏斩", "格挡", "闪避"][index]))
		reaction_buttons[index].visible = phase == "REACTION_OPEN"
		reaction_buttons[index].disabled = not option.get("available", false)
	_render_hand()
	if reference_hud != null:
		reference_hud.render_source(run)


func _set_state_message(message: String) -> void:
	if message == _last_state_message:
		return
	_last_state_message = message
	state_label.text = message
	_state_drop_elapsed = 0.0


func _update_health_bars() -> void:
	if combat == null or combat.state.is_empty() or player_health_track == null:
		return
	var run: Dictionary = combat.state
	var player: Dictionary = run.get("player", {})
	var enemy: Dictionary = run.get("enemy", {})
	var player_hp := _held_player_hp if _held_player_hp >= 0 else int(player.get("hp", 0))
	var enemy_hp := _held_enemy_hp if _held_enemy_hp >= 0 else int(enemy.get("hp", 0))
	var player_fraction := clampf(float(player_hp) / maxf(1.0, float(player.get("maxHp", 1))), 0.0, 1.0)
	var enemy_fraction := clampf(float(enemy_hp) / maxf(1.0, float(enemy.get("maxHp", 1))), 0.0, 1.0)
	player_health_fill.size = Vector2(player_health_track.size.x * player_fraction, player_health_track.size.y)
	var qi_fraction := clampf(float(run.get("qi", 0)) / maxf(1.0, float(run.get("maxQi", 1))), 0.0, 1.0)
	player_qi_fill.size = Vector2(player_qi_track.size.x * qi_fraction, player_qi_track.size.y)
	enemy_health_fill.size = Vector2(enemy_health_track.size.x * enemy_fraction, enemy_health_track.size.y)


func _render_hand() -> void:
	if hand_row == null or combat == null:
		return
	var imported_later_turn: bool = not browser_combat_snapshot.is_empty() \
		and int(combat.state.get("turn", 1)) > 1
	hand_row.render_hand(data, combat.state.get("hand", []), int(combat.state["qi"]), String(combat.state["phase"]), combat.input_locked or imported_later_turn)
	_layout_card_table()


func _layout_card_table() -> void:
	if card_table == null or combat == null:
		return
	var size_now := get_viewport().get_visible_rect().size
	var count := (combat.state.get("hand", []) as Array).size()
	var width := minf(size_now.x - 64.0, maxf(310.0, float(count) * 102.0 + 86.0))
	card_table.visible = count > 0
	var desk_height := 64.0
	card_table.size = Vector2(width, desk_height)
	card_table.position = Vector2((size_now.x - width) * 0.5, size_now.y - desk_height)
	card_table.set_card_count(count)


func _play_card(index: int) -> void:
	if not browser_combat_snapshot.is_empty():
		if combat.input_locked or int(combat.state.get("turn", 1)) > 1:
			return
		var hand: Array = combat.state.get("hand", [])
		if index < 0 or index >= hand.size() \
				or not browser_combat_commit_card.is_valid() \
				or not browser_combat_commit_card.call(index, String(hand[index]),
					combat.state.duplicate(true)):
			_set_state_message("战斗动作未存入玉简；本次出牌未执行")
			return
		browser_combat_actions.append({"type": "PLAY_CARD", "handIndex": index,
			"cardId": String(hand[index])})
	if not combat.play_card(index):
		_set_state_message("该输入未被规则层接受")


func _end_turn() -> void:
	if not browser_combat_snapshot.is_empty():
		if combat.input_locked or not browser_combat_commit_end_turn.is_valid() \
				or not browser_combat_commit_end_turn.call(combat.state.duplicate(true)):
			_set_state_message("战斗回合未存入玉简；本次收势未执行")
			return
		browser_combat_actions.append({"type": "END_TURN"})
	if not combat.end_turn():
		_set_state_message("该输入未被规则层接受")


func _return_to_story() -> void:
	if battle_request.is_empty() or combat.input_locked or pending_presentations > 0:
		return
	var result := terminal_result()
	if not result.is_empty():
		battle_finished.emit(result)


func terminal_result() -> Dictionary:
	if battle_request.is_empty() or combat == null or combat.state.is_empty():
		return {}
	var phase := String(combat.state.get("phase", ""))
	var outcome := String(combat.state.get("outcome", ""))
	if not ((phase == "VICTORY" and outcome == "victory") \
			or (phase == "DEFEAT" and outcome == "defeat") \
			or (phase == "FLEE" and outcome == "flee")):
		return {}
	var owner := String(battle_request.get("encounterInstanceId", ""))
	return {"contractVersion": battle_request["contractVersion"],
		"encounterInstanceId": owner,
		"sourceCardId": battle_request["sourceCardId"],
		"encounterId": battle_request["encounterId"],
		"sourceContentHash": battle_request["sourceContentHash"],
		"outcome": outcome, "combatReceipt": "combat:" + owner,
		"postBattleState": {"encounterInstanceId": owner, "terminal": true,
			"combatPhase": phase,
			"playerHp": combat.state["player"]["hp"],
			"enemyHp": combat.state["enemy"]["hp"],
			"turn": combat.state["turn"]}}


func _choose_reaction(reaction_id: String) -> void:
	if not browser_combat_snapshot.is_empty():
		if combat.input_locked or not browser_combat_commit_reaction.is_valid():
			_set_state_message("敌方行动未存入玉简；本次回应未执行")
			return
		var receipt: Dictionary = browser_combat_commit_reaction.call(
			reaction_id, combat.state.duplicate(true))
		if receipt.is_empty() or not combat.set_replay_random_values(
			receipt.get("randomValues", [])):
			_set_state_message("敌方行动未存入玉简；本次回应未执行")
			return
		browser_combat_actions.append(receipt)
	if not combat.choose_reaction(reaction_id):
		_set_state_message("该反应不满足旧版规则条件")


func _on_combat_changed(event: Dictionary) -> void:
	var kind := String(event.get("type", ""))
	if kind == "BOSS_PHASE_CHANGED":
		if duel_stage.has_method("show_boss_phase"):
			duel_stage.show_boss_phase(int(event.get("phase", 0)))
		_render()
		return
	if kind == "STORY_ASSIST_COMMITTED":
		_set_state_message("【%s·援护】%s" % [event.get("companionName", "剑灵儿"),
			event.get("unlockText", "冰心共鸣")])
		_render()
		return
	if kind == "CARD_PLAY":
		hand_row.show_committed(data, String(event.get("cardId", "")))
		if reference_hud != null:
			reference_hud.record_played_card(String(event.get("cardId", "")))
		var damage := 0
		var block_spent := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				damage += int(effect.get("hpLoss", 0))
				block_spent += int(effect.get("blockSpent", 0))
		_held_enemy_hp = int(event.get("enemyHpBefore", combat.state["enemy"]["hp"])) if damage > 0 else -1
		_held_enemy_block = int(event.get("enemyBlockBefore", combat.state["enemy"]["block"])) if block_spent > 0 else -1
		_hold_outcome = String(combat.state["phase"]) == "VICTORY"
	elif kind == "ENEMY_ACTION":
		var hp_loss := int(event.get("hpLoss", 0))
		_held_player_hp = int(combat.state["player"]["hp"]) + hp_loss if hp_loss > 0 else -1
		_hold_outcome = String(combat.state["phase"]) == "DEFEAT"
	if kind in ["CARD_PLAY", "ENEMY_ACTION", "DEFEAT"]:
		var visual_event: Dictionary = event.duplicate(true)
		if kind == "CARD_PLAY":
			visual_event["victory"] = combat.state.get("phase") == "VICTORY"
		if duel_stage.present_action(visual_event):
			pending_presentations += 1
			combat.input_locked = true
			if stage_assets_ready:
				presentation_problem = ""
		else:
			_held_enemy_hp = -1
			_held_enemy_block = -1
			_held_player_hp = -1
			_hold_outcome = false
			presentation_problem = "角色动作缺失或未接入"
	if combat.state.get("phase") == "VICTORY" and duel_stage.has_method("queue_victory_cue"):
		duel_stage.queue_victory_cue()
	_render()


func _on_presentation_finished(_event_type: String) -> void:
	_held_enemy_hp = -1
	_held_enemy_block = -1
	_held_player_hp = -1
	_hold_outcome = false
	pending_presentations = maxi(0, pending_presentations - 1)
	call_deferred("_sync_presentation_lock")


func _sync_presentation_lock() -> void:
	combat.input_locked = pending_presentations > 0
	_render()


func _on_presentation_missing(_event_type: String, reason: String) -> void:
	presentation_problem = "战斗演出缺少角色动作"
	push_warning(reason)


func _on_contact_frame(side: String) -> void:
	if side == "player" and (_held_enemy_hp >= 0 or _held_enemy_block >= 0 or _hold_outcome):
		_held_enemy_hp = -1
		_held_enemy_block = -1
		_hold_outcome = false
		_render()
	elif side == "enemy" and (_held_player_hp >= 0 or _hold_outcome):
		_held_player_hp = -1
		_hold_outcome = false
		_render()
