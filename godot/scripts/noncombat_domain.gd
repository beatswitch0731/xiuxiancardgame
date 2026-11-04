extends RefCounted

# Bounded fresh-life story slice. Source JSON owns cards, routes and path bonuses;
# this script only implements the existing browser's opening settlement semantics.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const BattleReturnFlow = preload("res://scripts/noncombat_battle_return_flow.gd")
const FirstSessionRoute = preload("res://scripts/noncombat_first_session_route.gd")
const EncounterFlow = preload("res://scripts/noncombat_encounter_flow.gd")
const CadenceFlow = preload("res://scripts/noncombat_cadence_flow.gd")
const CatalogEncounter = preload("res://scripts/noncombat_catalog_encounter.gd")
const RealmGateFlow = preload("res://scripts/noncombat_realm_gate_flow.gd")
const NpcEncounterFlow = preload("res://scripts/noncombat_npc_encounter_flow.gd")
const NpcInteractionFlow = preload("res://scripts/noncombat_npc_interaction_flow.gd")
const NpcCrossFlow = preload("res://scripts/noncombat_npc_cross_flow.gd")
const AvoidFlow = preload("res://scripts/noncombat_avoid_flow.gd")
const MilestoneFlow = preload("res://scripts/noncombat_milestone_flow.gd")
const QuestFlow = preload("res://scripts/noncombat_quest_flow.gd")
const KarmaFlow = preload("res://scripts/noncombat_karma_flow.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const LegacyFragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const PathSkillFlow = preload("res://scripts/noncombat_path_skill_flow.gd")
const MentorFlow = preload("res://scripts/noncombat_mentor_flow.gd")
const DestinyWheelFlow = preload("res://scripts/noncombat_destiny_wheel.gd")
const TreasureAcquisition = preload("res://scripts/noncombat_treasure_acquisition.gd")
const EmergentFlow = preload("res://scripts/noncombat_emergent_flow.gd")
const MarketFlow = preload("res://scripts/noncombat_market_flow.gd")
const TradeRouteFlow = preload("res://scripts/noncombat_trade_route_flow.gd")
const VendorFlow = preload("res://scripts/noncombat_vendor_flow.gd")
const GhostVendorFlow = preload("res://scripts/noncombat_ghost_vendor_flow.gd")
const GhostDebtFlow = preload("res://scripts/noncombat_ghost_debt_flow.gd")
const RippleFlow = preload("res://scripts/noncombat_ripple_flow.gd")
const HintFlow = preload("res://scripts/noncombat_heavens_hint_flow.gd")
const NormalDrawPolicy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const NormalChoicePolicy = preload("res://scripts/noncombat_normal_choice_policy.gd")
const CompanionEvents = preload("res://scripts/noncombat_companion_events.gd")
const CompanionPortraits = preload("res://scripts/noncombat_companion_portraits.gd")
const SkillOpportunity = preload("res://scripts/noncombat_skill_opportunity.gd")
const CaveFlow = preload("res://scripts/noncombat_cave_flow.gd")
const FoundationDungeonFlow = preload("res://scripts/noncombat_foundation_dungeon_flow.gd")
const GoldenDungeonFlow = preload("res://scripts/noncombat_golden_dungeon_flow.gd")
const NascentCaveFlow = preload("res://scripts/noncombat_nascent_cave_flow.gd")
const NascentRuinsFlow = preload("res://scripts/noncombat_nascent_ruins_flow.gd")
const HigherDungeonFlow = preload("res://scripts/noncombat_higher_linear_dungeon_flow.gd")
const CampFlow = preload("res://scripts/noncombat_camp_flow.gd")
const RegulatedCatalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const RegulatedVendor = preload("res://scripts/noncombat_regulated_vendor_flow.gd")
const LastLessonVendor = preload("res://scripts/noncombat_last_lesson_vendor_flow.gd")
const CausalFactClock = preload("res://scripts/noncombat_causal_fact_clock.gd")
const LicensedDelivery = preload("res://scripts/noncombat_licensed_delivery.gd")
const DeathFlow = preload("res://scripts/noncombat_death_flow.gd")
const RebirthFlow = preload("res://scripts/noncombat_rebirth_flow.gd")
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")
const StoryThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const WorldPulse = preload("res://scripts/noncombat_world_pulse.gd")
const FactionEvents = preload("res://scripts/noncombat_faction_events.gd")
const SceneLayerFlow = preload("res://scripts/noncombat_scene_layer_flow.gd")
const ChoiceEchoFlow = preload("res://scripts/noncombat_choice_echo_flow.gd")
const AllyArcFlow = preload("res://scripts/noncombat_ally_arc_flow.gd")
const CompanionArcFlow = preload("res://scripts/noncombat_companion_arc_flow.gd")
const SeerArcFlow = preload("res://scripts/noncombat_seer_arc_flow.gd")
const NarrativeSurfacing = preload("res://scripts/noncombat_narrative_surfacing.gd")
const BrowserCombatSemantics = preload("res://scripts/noncombat_browser_combat_semantics.gd")
const BrowserCombatActions = preload("res://scripts/noncombat_browser_combat_actions.gd")
const BrowserCombatPlan = preload("res://scripts/battle_plan_resolver.gd")
signal changed(event: Dictionary)

class ReplaySnapshotStore extends RefCounted:
	var snapshot: Dictionary

	func _init(saved: Dictionary) -> void:
		snapshot = saved.duplicate(true)

	func load_snapshot() -> Dictionary:
		return {"state": snapshot.duplicate(true), "revision": 0}

	func mark_source_mismatch() -> void:
		pass

	func mark_source_unavailable() -> void:
		pass

const TUTORIAL_IDS := ["tutorial_1", "tutorial_2", "tutorial_3", "tutorial_4"]
const PATH_BONUS_KEYS := ["cultivation", "daoHeart", "health", "fortune", "spiritStone", "combatOpeningBlock"]
const TUTORIAL_EFFECT_KEYS := ["cultivation", "daoHeart", "health", "fortune", "spiritStone", "lifespan"]
const PROLOGUE_EFFECT_KEYS := TUTORIAL_EFFECT_KEYS + ["karmaGood", "karmaBad"]
const CHOICE_KEYS := ["text", "desc", "effects", "nextCard"]

var state: Dictionary = {}
var _projected_choice_markers: Array[String] = []
var _registry: RefCounted
var _content: RefCounted
var _battle_gateway: RefCounted
var _battle_return_flow: RefCounted
var _first_session_route: RefCounted
var _encounter_flow: RefCounted
var _avoid_flow: RefCounted
var _cadence_flow: RefCounted
var _realm_gate_flow: RefCounted
var _npc_encounter_flow: RefCounted
var _npc_interaction_flow: RefCounted
var _npc_cross_flow: RefCounted
var _milestone_flow: RefCounted
var _quest_flow: RefCounted
var _karma_flow: RefCounted
var _deck_acquisition: RefCounted
var _legacy_fragment_flow: RefCounted
var _mentor_flow: RefCounted
var _destiny_wheel_flow: RefCounted
var _emergent_flow: RefCounted
var _market_flow: RefCounted
var _trade_route_flow: RefCounted
var _vendor_flow: RefCounted
var _ghost_vendor_flow: RefCounted
var _ghost_debt_flow: RefCounted
var _ripple_flow: RefCounted
var _hint_flow: RefCounted
var _normal_draw_policy: RefCounted
var _normal_choice_policy: RefCounted
var _cave_flow: RefCounted
var _foundation_dungeon_flow: RefCounted
var _golden_dungeon_flow: RefCounted
var _nascent_cave_flow: RefCounted
var _nascent_ruins_flow: RefCounted
var _higher_dungeon_flow: RefCounted
var _camp_flow: RefCounted
var _regulated_catalog: RefCounted
var _regulated_vendor: RefCounted
var _last_lesson_vendor: RefCounted
var _causal_fact_clock: RefCounted
var _licensed_delivery: RefCounted
var _death_flow: RefCounted
var _rebirth_flow: RefCounted
var _lineage_flow: RefCounted
var _story_thread_flow: RefCounted
var _scene_layer_flow: RefCounted
var _choice_echo_flow: RefCounted
var _ally_arc_flow: RefCounted
var _companion_arc_flow: RefCounted
var _seer_arc_flow: RefCounted
var _narrative_surfacing: RefCounted
var _companion_events: RefCounted
var _faction_events: RefCounted
var _normal_roll_override := -1.0
var _normal_replay_seed := 0
var _normal_replay_draws: Array = []
var _normal_replay_priority_checks: Array = []
var _normal_replay_shop_entries: Array = []
var _normal_replay_source_pins: Dictionary = {}
const LEGACY_GAME_LOGIC_JS_SHA := "637d63a0e065729dc2743abf2da46264d8f90d430da1a04f74423e351733a881"
var _normal_choice_pin_activation_index := 0
var _market_skip_seed_tick_activation_index := 0
var _legacy_priority_replay := false
var _flow_card_count := 0
var _normal_starvation: Dictionary = {}
var _normal_flow_error := ""
var _mentor_state: Dictionary = MentorFlow.initial_state()
var _legacy_mentor_replay := false
var _legacy_mentor_stage_replay := false
var _legacy_mentor_heir_replay := false
var _mentor_heir_activation_index := 0
var _legacy_mentor_climax_replay := false
var _mentor_climax_activation_index := 0
var _legacy_faction_collection_replay := false
var _faction_collection_new_activation_index := 0
var _store: RefCounted
var _cards: Dictionary = {}
var _path_definition: Dictionary = {}
var _current_card_id := ""
var _choice_token := 0
var _cultivation_max := 100
var _slot_id := "slot_1"
var _store_revision := -1
var _legacy_karma_replay := false
var _legacy_karma_order_replay := false
var _legacy_deck_replay := false
var _legacy_fragment_replay := false
var _legacy_fragment_replay_activation_index := -1
var _legacy_fragment_replay_initial_seed := 0
var _boss_reward_activation_index := 0
var _boss_reward_marker_present := false
var _legacy_wheel_replay := false
var _legacy_wheel_replay_activation_index := -1
var _legacy_wheel_replay_initial_seed := 0
var _legacy_lifespan_replay := false
var _legacy_market_replay := false
var _legacy_market_replay_activation_index := -1
var _legacy_market_replay_initial_seed := 0
var _legacy_ripple_replay := false
var _legacy_ripple_replay_activation_index := -1
var _legacy_ripple_replay_initial_seed := 0
var _legacy_hint_replay := false
var _legacy_hint_replay_activation_index := -1
var _legacy_hint_replay_initial_seed := 0
var _q_market_choice_activation_index := 0
var _combat_scheduling_activation_index := 0
var _cadence_activation_index := 0
var _cadence_high_upgrade_index := 0
var _path_skill_activation_index := 1
var _path_skill_replay_marker_present := false
var _passive_regen_extension_activation_index := 1
var _passive_regen_extension_replay_marker_present := false
var _early_avoid_activation_index := 1
var _early_avoid_replay_marker_present := false
var _npc_activation_index := 0
var _npc_general_activation_index := 0
var _npc_cross_activation_index := 0
var _npc_cross_dynamic_activation_index := 0
var _scene_activation_index := 0
var _echo_activation_index := 0
var _ally_activation_index := 0
var _companion_arc_activation_index := 0
var _seer_activation_index := 0
var _surfacing_activation_index := 0
var _companion_activation_index := 0
var _companion_milestone_activation_index := 0
var _replaying_history := false
var _narrative_admission_activation_index := 0
var _world_continuity_activation_index := 0
var _world_pulse_activation_index := 0
var _faction_activation_index := 0


func _init(registry: RefCounted, store: RefCounted = null,
		slot_id: String = "slot_1", content: RefCounted = null) -> void:
	_registry = registry
	_content = content if content != null else ContentRepository.new()
	_battle_gateway = BattleGateway.new(registry, _content)
	_battle_return_flow = BattleReturnFlow.new(_content, _battle_gateway)
	_first_session_route = FirstSessionRoute.new(_content)
	_encounter_flow = EncounterFlow.new(_content, _battle_gateway)
	_avoid_flow = AvoidFlow.new(_content, _battle_gateway)
	_cadence_flow = CadenceFlow.new(_content, _battle_gateway)
	_realm_gate_flow = RealmGateFlow.new(_content)
	_npc_encounter_flow = NpcEncounterFlow.new(_content)
	_npc_interaction_flow = NpcInteractionFlow.new(_content)
	_npc_cross_flow = NpcCrossFlow.new(_content)
	_milestone_flow = MilestoneFlow.new(_content)
	_quest_flow = QuestFlow.new(_content)
	_karma_flow = KarmaFlow.new(_content)
	_deck_acquisition = DeckAcquisition.new(_content)
	_legacy_fragment_flow = LegacyFragmentFlow.new(_content, _deck_acquisition)
	_mentor_flow = MentorFlow.new(_content)
	_destiny_wheel_flow = DestinyWheelFlow.new(_content)
	_emergent_flow = EmergentFlow.new()
	_market_flow = MarketFlow.new(_content)
	_trade_route_flow = TradeRouteFlow.new(_content)
	_vendor_flow = VendorFlow.new(_content)
	_ghost_vendor_flow = GhostVendorFlow.new(_content, _market_flow)
	_ghost_debt_flow = GhostDebtFlow.new(_content)
	_ripple_flow = RippleFlow.new(_content)
	_hint_flow = HintFlow.new(_content)
	_normal_draw_policy = NormalDrawPolicy.new(_content)
	_normal_choice_policy = NormalChoicePolicy.new(_content)
	_companion_events = CompanionEvents.new(_content)
	_faction_events = FactionEvents.new(_content)
	_cave_flow = CaveFlow.new(_content)
	_foundation_dungeon_flow = FoundationDungeonFlow.new(_content)
	_golden_dungeon_flow = GoldenDungeonFlow.new(_content)
	_nascent_cave_flow = NascentCaveFlow.new(_content)
	_nascent_ruins_flow = NascentRuinsFlow.new(_content)
	_higher_dungeon_flow = HigherDungeonFlow.new(_content)
	_camp_flow = CampFlow.new(_content)
	_regulated_catalog = RegulatedCatalog.new(_content)
	_regulated_vendor = RegulatedVendor.new(_content)
	_causal_fact_clock = CausalFactClock.new(_content)
	_licensed_delivery = LicensedDelivery.new(_content)
	_death_flow = DeathFlow.new(_content)
	_rebirth_flow = RebirthFlow.new(_content)
	_lineage_flow = LineageFlow.new(_content)
	_story_thread_flow = StoryThreadFlow.new(_content)
	_last_lesson_vendor = LastLessonVendor.new(_content, _story_thread_flow)
	_scene_layer_flow = SceneLayerFlow.new(_content)
	_choice_echo_flow = ChoiceEchoFlow.new(_content)
	_ally_arc_flow = AllyArcFlow.new(_content)
	_companion_arc_flow = CompanionArcFlow.new(_content)
	_seer_arc_flow = SeerArcFlow.new(_content)
	_narrative_surfacing = NarrativeSurfacing.new(_content)
	_store = store
	_slot_id = slot_id


func start(path_id: String, authored_player_name: String = "叶凌云") -> bool:
	var player_name := authored_player_name.strip_edges()
	if player_name.is_empty():
		player_name = "叶凌云"
	if not state.is_empty() or _registry == null or path_id.is_empty() \
			or not _slot_id in ["slot_1", "slot_2", "slot_3"] \
			or player_name.length() > 4:
		return false
	var path_value: Variant = _content.read_module("config:paths")
	var qi_value: Variant = _content.read_module("cards:qi")
	var realm_value: Variant = _content.read_module("config:realms")
	if not path_value is Dictionary or not qi_value is Dictionary \
			or not realm_value is Dictionary:
		return false
	var path_doc: Dictionary = path_value
	var paths: Dictionary = path_doc.get("paths", {})
	var path: Dictionary = paths.get(path_id, {})
	var qi_doc: Dictionary = qi_value
	var realm_doc: Dictionary = realm_value
	var qi_realm: Dictionary = realm_doc.get("realms", {}).get("qi", {})
	if path.is_empty() or qi_doc.get("realm") != "qi" or qi_realm.is_empty():
		return false
	var starter_id := "q_start_" + path_id
	if path.get("startCard") != starter_id or not _valid_integer(qi_realm.get("cultivationThreshold")):
		return false
	var cultivation_max := int(qi_realm["cultivationThreshold"])
	if cultivation_max <= 0:
		return false
	var cards: Dictionary = {}
	for candidate in qi_doc.get("cards", []):
		if not candidate is Dictionary or not candidate.get("id") is String:
			return false
		var card_id: String = candidate["id"]
		if card_id.is_empty() or cards.has(card_id):
			return false
		cards[card_id] = candidate
	for required_id in TUTORIAL_IDS + [starter_id]:
		if not cards.has(required_id):
			return false
	var bonuses: Dictionary = path.get("bonuses", {})
	for key in bonuses:
		if not key in PATH_BONUS_KEYS or not _valid_integer(bonuses[key]):
			return false
	var opening := {
		"active": true, "phase": "TUTORIAL", "path": path_id,
		"playerName": player_name, "realm": "qi",
		"turn": 0, "cardsPlayed": [], "tutorialCompleted": false,
		"currentCardId": "tutorial_1", "maxHealth": 6, "maxDaoHeart": 3,
		"choiceHistory": [], "replayHistory": [], "recentCardTags": [],
		"decisionCheckpoint": null,
		"runClock": {
			"version": 1, "lifeId": _slot_id + ":life:0", "decisionIndex": 0,
			"decisionClockMigrationSource": null, "receipts": {},
		},
		"attributes": {
			"cultivation": 0, "daoHeart": 2, "karmaGood": 0,
			"karmaBad": 0, "fortune": 50, "health": 5,
			"aura": 0, "tianji": 0,
		},
		"resources": {
			"spiritStone": 10, "lifespan": 80,
			"pills": {}, "treasures": [], "companions": [],
		},
	}
	if _path_skill_activation_index == 1 and (
			not _replaying_history or _path_skill_replay_marker_present):
		opening["pathSkillActivationIndex"] = 1
	if _passive_regen_extension_activation_index == 1 and (
			not _replaying_history or _passive_regen_extension_replay_marker_present):
		opening["passiveRegenExtensionIndex"] = 1
	if _early_avoid_activation_index == 1 and (
			not _replaying_history or _early_avoid_replay_marker_present):
		opening["earlyAvoidActivationIndex"] = 1
	for key in bonuses:
		var amount := int(bonuses[key])
		match key:
			"health":
				opening["maxHealth"] = maxi(1, int(opening["maxHealth"]) + amount)
				opening["attributes"]["health"] = clampi(int(opening["attributes"]["health"]) + amount,
					0, int(opening["maxHealth"]))
			"daoHeart":
				opening["maxDaoHeart"] = maxi(1, int(opening["maxDaoHeart"]) + amount)
				opening["attributes"]["daoHeart"] = clampi(int(opening["attributes"]["daoHeart"]) + amount,
					0, int(opening["maxDaoHeart"]))
			"spiritStone":
				opening["resources"]["spiritStone"] = maxi(0,
					int(opening["resources"]["spiritStone"]) + amount)
			"cultivation", "fortune":
				var max_value: int = cultivation_max if key == "cultivation" else 100
				opening["attributes"][key] = clampi(int(opening["attributes"][key]) + amount,
					0, max_value)
			"combatOpeningBlock":
				# Browser GameLogic.start also skips this key; DeckCombatSystem owns it.
				pass
	if not _persist_snapshot(opening):
		return false
	_cards = cards
	_path_definition = path
	_cultivation_max = cultivation_max
	_current_card_id = "tutorial_1"
	_choice_token = 1
	state = opening
	changed.emit({"type": "STARTED", "path": path_id, "cardId": _current_card_id})
	return true


func restore() -> bool:
	if not state.is_empty() or _store == null:
		return false
	var uses_session := _store.has_method("load_snapshot")
	var record: Dictionary = _store.load_snapshot() if uses_session else {}
	var saved: Dictionary = record.get("state", {}) if uses_session else _store.load_state()
	if saved.has("bossRewardActivationIndex") and (
			not _valid_integer(saved.bossRewardActivationIndex)
			or int(saved.bossRewardActivationIndex) < 0
			or int(saved.bossRewardActivationIndex) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1))):
		return false
	if saved.has("pathSkillActivationIndex") \
			and not PathSkillFlow.new(_content).activation_valid(saved):
		return false
	if saved.has("passiveRegenExtensionIndex") \
			and (not _valid_integer(saved.passiveRegenExtensionIndex) \
				or int(saved.passiveRegenExtensionIndex) < 1 \
				or int(saved.passiveRegenExtensionIndex) > int(saved.get(
					"runClock", {}).get("decisionIndex", -1)) + 1):
		return false
	if saved.has("earlyAvoidActivationIndex") \
			and (not _valid_integer(saved.earlyAvoidActivationIndex) \
				or int(saved.earlyAvoidActivationIndex) < 1 \
				or int(saved.earlyAvoidActivationIndex) > int(saved.get(
					"runClock", {}).get("decisionIndex", -1)) + 1):
		return false
	if saved.has("marketSkipSeedTickActivationIndex") \
			and (not _valid_integer(saved.marketSkipSeedTickActivationIndex) \
				or int(saved.marketSkipSeedTickActivationIndex) < 1 \
				or int(saved.marketSkipSeedTickActivationIndex) > int(saved.get(
					"runClock", {}).get("decisionIndex", -1))):
		return false
	if saved.has("combatScheduling"):
		var scheduling: Variant = saved.combatScheduling
		if not scheduling is Dictionary or scheduling.get("version") != 1 \
				or not (scheduling.get("activationIndex") is int or scheduling.get("activationIndex") is float) \
				or float(scheduling.activationIndex) != floor(float(scheduling.activationIndex)) \
				or int(scheduling.activationIndex) < 0 \
				or int(scheduling.activationIndex) > int(saved.get("runClock", {}).get("decisionIndex", -1)):
			return false
	if saved.has("encounterCadence") and not _cadence_flow.validate_marker(saved):
		_mark_battle_return_failure(_cadence_flow)
		return false
	if saved.has("npcEncounterScheduling") \
			and not _npc_encounter_flow.validate_marker(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("npcInteractionHistory") and not saved.npcInteractionHistory is Array:
		return false
	if saved.has("npcCrossState") and not _npc_cross_flow.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("sceneLayerState") and not _scene_layer_flow.valid(saved):
		_mark_source_failure(_content)
		return false
	if saved.has("choiceEchoState") and not _choice_echo_flow.valid(saved):
		_mark_source_failure(_content)
		return false
	if saved.has("allyArcState") and not _ally_arc_flow.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("companionArcState") and not _companion_arc_flow.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("seerArcState") and not _seer_arc_flow.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("narrativeSurfacingState") and not _narrative_surfacing.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("companionProgress") and not _companion_events.valid(saved):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("normalNarrativeAdmission"):
		var admission: Variant = saved["normalNarrativeAdmission"]
		if not admission is Dictionary or admission.get("version") != 1 \
				or admission.get("ruleSha") != NormalDrawPolicy.NARRATIVE_LEDGER_JS_SHA \
				or not (admission.get("activationIndex") is int \
					or admission.get("activationIndex") is float) \
				or int(admission.get("activationIndex", -1)) < 1 \
				or int(admission.get("activationIndex", -1)) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1)) + 1:
			return false
	if not _restore_battle_sources(saved):
		return false
	if saved.get("phase") == "REBIRTH_PENDING" or int(saved.get("lifeCount", 0)) > 0 \
			and saved.get("phase") in ["CAMP_TARGET_PENDING", "FLOW_PENDING",
				"NORMAL_PENDING", "DEATH_PENDING", "MILESTONE_PENDING", "KARMA_PENDING", "THREAD_PENDING",
				"MARKET_PENDING", "VENDOR_OPEN", "VENDOR_RESULT_PENDING",
				"QUEST_PENDING", "MENTOR_PENDING", "NARRATIVE_RESULT_PENDING",
				"HINT_PENDING", "DESTINY_WHEEL_PENDING", "GHOST_DEBT_PENDING",
				"COMBAT_HANDOFF", "WARNING_PENDING", "BATTLE_PENDING", "BATTLE_RESULT_PENDING", "ENDING_PENDING", "UPPER_REALM_PENDING",
				"INNER_DEMON_PENDING", "NPC_PENDING", "NPC_CROSS_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING",
				"LOCATION_PENDING"] \
			and saved.get("lifeJournal") is Array:
		return _restore_rebirth(saved, record)
	if saved.is_empty() or not saved.get("path") is String \
			or not saved.get("choiceHistory") is Array:
		return false
	if saved.has("replayHistory") and (not saved["replayHistory"] is Array \
			or saved["replayHistory"].size() < saved["choiceHistory"].size() \
			or saved["replayHistory"].slice(
				maxi(0, saved["replayHistory"].size() - 30)) != saved["choiceHistory"]):
		return false
	if saved.has("campTargetHistory") and not saved["campTargetHistory"] is Array:
		return false
	if saved.has("dungeonActionHistory") and not saved["dungeonActionHistory"] is Array:
		return false
	if saved.has("treasureEquipmentHistory") and not saved["treasureEquipmentHistory"] is Array:
		return false
	if saved.has("companionPortraitHistory") and not saved["companionPortraitHistory"] is Array:
		return false
	if saved.has("regulatedEventHistory") and not saved["regulatedEventHistory"] is Array:
		return false
	if saved.has("lastLessonVendorEventHistory") \
			and not saved["lastLessonVendorEventHistory"] is Array:
		return false
	if saved.has("shopIdentifyRuleSourceSha") \
			and saved["shopIdentifyRuleSourceSha"] != LastLessonVendor.IDENTIFY_JS_SHA:
		return false
	if saved.has("lastLessonServiceVersion") and (
			saved.get("lastLessonServiceVersion") != 1 \
			or saved.get("regulatedCausalGraphSourceSha") != _content.source_sha256(
				"narrative:causal_graph")):
		return false
	if saved.has("storyThreadState") and (
			not saved["storyThreadState"] is Dictionary \
			or (saved["storyThreadState"].get("version") != 1 \
				and saved["storyThreadState"].get("version") != 2) \
			or not saved["storyThreadState"].get("activationIndex") is int \
				and not saved["storyThreadState"].get("activationIndex") is float \
			or int(saved["storyThreadState"].get("activationIndex", -1)) < 1 \
			or not _pinned_source_matches(StoryThreadFlow.MODULE,
				String(saved["storyThreadState"].get("sourceSha", "")))):
		return false
	if saved.get("storyThreadState", {}).get("version") == 2:
		if saved["storyThreadState"].get("lifeCount") != saved.get("lifeCount", 0):
			return false
		if saved["storyThreadState"].get("ruleSourcePins") != _story_thread_flow.source_rule_pins():
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		var upgrade: Variant = saved["storyThreadState"].get("upgradeIndex")
		if not (upgrade is int or upgrade is float and upgrade == floor(upgrade)) \
				or int(upgrade) < int(saved["storyThreadState"]["activationIndex"]) \
				or int(upgrade) > int(saved.get("runClock", {}).get("decisionIndex", -1)):
			return false
		var village_activation: Variant = saved["storyThreadState"].get("villageActivationIndex")
		var village_enabled: bool = saved["storyThreadState"].has("villageActivationIndex")
		if village_enabled and (not (village_activation is int or village_activation is float \
				and village_activation == floor(village_activation)) \
				or int(village_activation) < 1 \
				or int(village_activation) > int(saved.get("runClock", {}).get("decisionIndex", -1)) \
				or not saved["storyThreadState"].get("threads", {}).has("abandoned_village") \
				or not _pinned_source_matches("combat:migrated_presentations",
					String(saved["storyThreadState"].get("villagePresentationSha", "")))) \
				or not village_enabled and saved["storyThreadState"].get(
					"threads", {}).has("abandoned_village"):
			return false
		var sword_activation: Variant = saved["storyThreadState"].get("swordActivationIndex")
		var sword_enabled: bool = saved["storyThreadState"].has("swordActivationIndex")
		if sword_enabled and (not (sword_activation is int or sword_activation is float \
				and sword_activation == floor(sword_activation)) \
				or int(sword_activation) < 1 \
				or int(sword_activation) > int(saved.get("runClock", {}).get("decisionIndex", -1)) \
				or not saved["storyThreadState"].get("threads", {}).has("sword_tomb_trial")) \
				or not sword_enabled and saved["storyThreadState"].get(
					"threads", {}).has("sword_tomb_trial"):
			return false
		var mist_activation: Variant = saved["storyThreadState"].get("mistActivationIndex")
		var mist_enabled: bool = saved["storyThreadState"].has("mistActivationIndex")
		if mist_enabled and (not (mist_activation is int or mist_activation is float \
				and mist_activation == floor(mist_activation)) \
				or int(mist_activation) < 1 \
				or int(mist_activation) > int(saved.get("runClock", {}).get("decisionIndex", -1)) \
				or not saved["storyThreadState"].get("threads", {}).has("mist_valley")) \
				or not mist_enabled and saved["storyThreadState"].get(
					"threads", {}).has("mist_valley"):
			return false
		var higher_activation: Variant = saved["storyThreadState"].get("higherActivationIndex")
		var higher_enabled: bool = saved["storyThreadState"].has("higherActivationIndex")
		if higher_enabled and (not (higher_activation is int or higher_activation is float \
				and higher_activation == floor(higher_activation)) \
				or int(higher_activation) < 1 \
				or int(higher_activation) > int(saved.get("runClock", {}).get("decisionIndex", -1)) \
				or saved["storyThreadState"].get("higherSourcePins") != \
					_story_thread_flow.higher_source_pins()) \
				or not higher_enabled and saved["storyThreadState"].has("higherSourcePins"):
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		for higher_id in StoryThreadFlow.HIGHER_THREAD_IDS:
			if saved["storyThreadState"].get("threads", {}).has(higher_id) != higher_enabled:
				return false
		var lesson_activation: Variant = saved["storyThreadState"].get("lastLessonActivationIndex")
		var lesson_enabled: bool = saved["storyThreadState"].has("lastLessonActivationIndex")
		if lesson_enabled and (not _valid_integer(lesson_activation) \
				or int(lesson_activation) < 1 \
				or int(lesson_activation) > int(saved.get("runClock", {}).get(
					"decisionIndex", -1)) \
				or not _pinned_source_matches(StoryThreadFlow.LAST_LESSON_MODULE,
					String(saved["storyThreadState"].get("lastLessonSourceSha", "")))) \
				or not lesson_enabled and saved["storyThreadState"].has("lastLessonSourceSha") \
				or saved["storyThreadState"].get("threads", {}).has(
					StoryThreadFlow.LAST_LESSON_THREAD_ID) != lesson_enabled:
			return false
	if saved.has("worldContinuityActivationIndex") and (
			not _valid_integer(saved.worldContinuityActivationIndex) \
			or int(saved.worldContinuityActivationIndex) < 0 \
			or int(saved.worldContinuityActivationIndex) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1)) \
			or not saved.get("worldContinuityState") is Dictionary \
			or not _pinned_source_matches("npcs:core", String(saved.get(
				"worldContinuitySourceSha", "")))):
		return false
	if saved.has("worldPulseState") and (
			not WorldPulse.valid(saved.worldPulseState) \
			or int(saved.worldPulseState.get("activationIndex", -1)) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1))):
		return false
	if saved.has("factionEventState") and (
			not _faction_marker_source_matches(saved) \
			or not _faction_events.valid(saved) \
			or int(saved.factionEventState.get("activationIndex", -1)) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1))):
		return false
	var saved_normal: Variant = saved.get("normalFlow")
	if saved_normal != null:
		if not saved_normal is Dictionary or saved_normal.get("version") != 1 \
				or not saved_normal.get("sourcePins") is Dictionary \
				or not saved_normal.get("draws") is Array \
				or saved_normal.get("randomMode") not in ["seeded", "fixed"] \
				or not saved_normal.get("initialSeed") is int \
					and not saved_normal.get("initialSeed") is float \
				or int(saved_normal.get("initialSeed", 0)) <= 0 \
				or int(saved_normal.get("initialSeed", 0)) >= 2147483647:
			return false
		if saved_normal.get("randomMode") == "fixed" and (
				not (saved_normal.get("fixedRoll") is float \
					or saved_normal.get("fixedRoll") is int) \
				or float(saved_normal.get("fixedRoll", -1)) < 0.0 \
				or float(saved_normal.get("fixedRoll", -1)) >= 1.0):
			return false
		if saved_normal.has("priorityChecks") and (
				not saved_normal["priorityChecks"] is Array
				or not saved_normal.get("shopCooldown") is int
					and not saved_normal.get("shopCooldown") is float
				or int(saved_normal.get("shopCooldown", -1)) < 0
				or not _pinned_source_matches("cards:camp",
					String(saved_normal.get("priorityCampSourceSha", "")))):
			return false
		if saved_normal.has("shopEntries") and not saved_normal["shopEntries"] is Array:
			return false
		if saved_normal.has("goldenSourceSha") and not _pinned_source_matches(
				"cards:golden", String(saved_normal.goldenSourceSha)):
			return false
		if saved_normal.has("nascentSourceSha") and not _pinned_source_matches(
				"cards:nascent", String(saved_normal.nascentSourceSha)):
			return false
		if saved_normal.has("deitySourceSha") and not _pinned_source_matches(
				"cards:deity", String(saved_normal.deitySourceSha)):
			return false
		if saved_normal.has("tribulationSourceSha") and not _pinned_source_matches(
				"cards:tribulation", String(saved_normal.tribulationSourceSha)):
			return false
		if saved_normal.has("shopCatalogPins") and saved_normal["shopCatalogPins"] \
				!= _regulated_catalog.source_pins():
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		var actual_pins: Dictionary = _normal_draw_policy.source_pins()
		var legacy_pins: Dictionary = _normal_draw_policy.legacy_source_pins()
		if actual_pins.is_empty() or saved_normal.get("sourcePins") not in [
				actual_pins, legacy_pins] \
				or saved_normal.get("flowRuleSha") != NormalDrawPolicy.FLOW_DIRECTOR_JS_SHA \
				or saved_normal.get("cardRuleSha") != NormalDrawPolicy.CARD_SYSTEM_JS_SHA \
				or saved_normal.get("choiceRuleSha") != NormalChoicePolicy.GAME_LOGIC_JS_SHA \
				and not (record.get("version") == 2 \
					and saved.get("noncombatFlow", {}).get("scope") in [
						"first_session_avoid", "first_session_combat", "rebirth_new_life"] \
					and saved_normal.get("choiceRuleSha") == LEGACY_GAME_LOGIC_JS_SHA) \
				or saved_normal.get("stateRuleSha") != NormalChoicePolicy.GAME_STATE_JS_SHA \
				or saved_normal.get("effectRuleSha") != NormalChoicePolicy.EFFECT_SERVICE_JS_SHA:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
	# Replay from the current source JSON. A malformed or stale snapshot cannot
	# become runtime authority just by naming a known card ID.
	var rebuilt = get_script().new(_registry, null, _slot_id, _content)
	rebuilt._replaying_history = true
	if saved_normal is Dictionary and saved_normal.get("choiceRuleSha") == LEGACY_GAME_LOGIC_JS_SHA:
		rebuilt._normal_choice_pin_activation_index = int(saved.runClock.decisionIndex) + 1
	rebuilt._market_skip_seed_tick_activation_index = int(saved.get(
		"marketSkipSeedTickActivationIndex", rebuilt._normal_choice_pin_activation_index))
	rebuilt._path_skill_replay_marker_present = saved.has("pathSkillActivationIndex")
	rebuilt._path_skill_activation_index = int(saved.get(
		"pathSkillActivationIndex", int(saved.get("runClock", {}).get(
			"decisionIndex", 0)) + (2 if saved.get("phase") in [
				"WARNING_PENDING", "BATTLE_PENDING"] else 1)))
	rebuilt._passive_regen_extension_replay_marker_present = saved.has(
		"passiveRegenExtensionIndex")
	rebuilt._passive_regen_extension_activation_index = int(saved.get(
		"passiveRegenExtensionIndex", int(saved.get("runClock", {}).get(
			"decisionIndex", 0)) + 1))
	rebuilt._early_avoid_replay_marker_present = saved.has("earlyAvoidActivationIndex")
	rebuilt._early_avoid_activation_index = int(saved.get(
		"earlyAvoidActivationIndex", int(saved.get("runClock", {}).get(
			"decisionIndex", 0)) + 1))
	rebuilt._last_lesson_vendor.legacy_service_replay = _saved_legacy_lesson_session(saved)
	rebuilt._world_continuity_activation_index = int(saved.get(
		"worldContinuityActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._world_pulse_activation_index = int(saved.get("worldPulseState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._faction_activation_index = int(saved.get("factionEventState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._scene_activation_index = int(saved.get("sceneLayerState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._echo_activation_index = int(saved.get("choiceEchoState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._ally_activation_index = int(saved.get("allyArcState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._companion_arc_activation_index = int(saved.get("companionArcState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._seer_activation_index = int(saved.get("seerArcState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._surfacing_activation_index = int(saved.get("narrativeSurfacingState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._companion_activation_index = int(saved.get("companionProgress", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._companion_milestone_activation_index = int(saved.get(
		"companionProgress", {}).get("milestoneActivationIndex",
		-1 if saved.has("companionProgress") else 0))
	rebuilt._narrative_admission_activation_index = 0 if saved.get("phase") == "TUTORIAL" \
		and int(saved.get("runClock", {}).get("decisionIndex", -1)) == 0 \
		and saved.has("normalNarrativeAdmission") else int(saved.get(
		"normalNarrativeAdmission", {}).get("activationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._normal_draw_policy.legacy_narrative_admission_replay = \
		not saved.has("normalNarrativeAdmission")
	rebuilt._cadence_activation_index = int(saved.get("encounterCadence", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._cadence_high_upgrade_index = int(saved.get("encounterCadence", {}).get(
		"higherRealmActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._npc_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._npc_general_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
		"generalActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._npc_encounter_flow.roll_override_sequence = saved.get(
		"npcEncounterScheduling", {}).get("rollTape", []).duplicate(true)
	rebuilt._npc_cross_activation_index = int(saved.get("npcCrossState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._npc_cross_dynamic_activation_index = int(saved.get("npcCrossState", {}).get(
		"dynamicActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._npc_cross_flow.roll_override_sequence = saved.get(
		"npcCrossState", {}).get("rollTape", []).duplicate(true)
	rebuilt._npc_encounter_flow.legacy_schedule_metadata = int(saved.get(
		"worldContinuityActivationIndex", 2)) > 1 \
		and saved.get("worldContinuityState", {}).get(
			"npcs", {}).get("bai_ren", {}).get("reason") == "schedule"
	rebuilt._combat_scheduling_activation_index = int(saved.get("combatScheduling", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.activation_index = int(saved.get(
		"storyThreadState", {}).get("activationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.upgrade_index = int(saved.get(
		"storyThreadState", {}).get("upgradeIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.village_activation_index = int(saved.get(
		"storyThreadState", {}).get("villageActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.sword_activation_index = int(saved.get(
		"storyThreadState", {}).get("swordActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.mist_activation_index = int(saved.get(
		"storyThreadState", {}).get("mistActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.higher_activation_index = int(saved.get(
		"storyThreadState", {}).get("higherActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	rebuilt._story_thread_flow.last_lesson_activation_index = int(saved.get(
		"storyThreadState", {}).get("lastLessonActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	var saved_trade_activation: Variant = saved.get("tradeRouteActivationIndex", 0)
	if saved.has("tradeRouteVersion"):
		if saved.get("tradeRouteVersion") != 1 \
				or not (saved_trade_activation is int or saved_trade_activation is float) \
				or int(saved_trade_activation) < 0 \
				or int(saved_trade_activation) > int(saved.get("runClock", {}).get(
					"decisionIndex", -1)) \
				or saved.get("tradeRouteSourcePins") != _trade_route_flow.source_pins() \
				or saved.get("tradeRouteRuleSourceSha") != TradeRouteFlow.SOURCE_JS_SHA \
				or not saved.get("tradeRouteState") is Dictionary \
				or not saved.get("tradeRouteLegacyUnverified") is bool:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		rebuilt._trade_route_flow.activation_index = int(saved_trade_activation)
		rebuilt._trade_route_flow.legacy_initial_trusted = \
			saved.get("tradeRouteLegacyUnverified") == false
	else:
		if saved.has("tradeRouteState") or saved.has("tradeRouteSourcePins"):
			return false
		rebuilt._trade_route_flow.activation_index = int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1
		rebuilt._trade_route_flow.legacy_initial_trusted = \
			_trade_route_flow.legacy_prefix_trusted(saved)
	if saved_normal is Dictionary:
		rebuilt._normal_replay_seed = int(saved_normal["initialSeed"])
		rebuilt._normal_replay_draws = saved_normal["draws"].duplicate(true)
		if saved_normal.has("priorityChecks"):
			rebuilt._normal_replay_priority_checks = saved_normal["priorityChecks"].duplicate(true)
		if saved_normal.has("shopEntries"):
			rebuilt._normal_replay_shop_entries = saved_normal["shopEntries"].duplicate(true)
		if saved_normal["sourcePins"] == _normal_draw_policy.legacy_source_pins():
			rebuilt._normal_replay_source_pins = saved_normal["sourcePins"].duplicate(true)
		if saved_normal.get("randomMode") == "fixed":
			rebuilt._normal_roll_override = float(saved_normal["fixedRoll"])
	rebuilt._legacy_priority_replay = not saved_normal is Dictionary \
		or not saved_normal.has("priorityChecks")
	rebuilt._legacy_mentor_replay = not saved.has("mentorArcState")
	var saved_mentor: Variant = saved.get("mentorArcState", {})
	if saved_mentor is Dictionary and not saved_mentor.is_empty():
		var mentor_version: Variant = saved_mentor.get("version")
		if not (mentor_version is int or mentor_version is float) \
				or float(mentor_version) != float(int(mentor_version)) \
				or not int(mentor_version) in [1, 2, 3, 4]:
			return false
		rebuilt._legacy_mentor_stage_replay = int(mentor_version) == 1
		rebuilt._legacy_mentor_heir_replay = int(mentor_version) < 3
		rebuilt._legacy_mentor_climax_replay = int(mentor_version) < 4
		rebuilt._legacy_faction_collection_replay = int(mentor_version) < 4 \
			and saved.has("factionEventState")
		rebuilt._faction_collection_new_activation_index = int(saved.get(
			"factionCollectionNewActivationIndex", int(saved.get("runClock", {}).get(
				"decisionIndex", 0)) + 1)) if rebuilt._legacy_faction_collection_replay \
			else 0
		if int(mentor_version) >= 3:
			var heir_index: Variant = saved_mentor.get("heirActivationIndex")
			if not (heir_index is int or heir_index is float) \
					or float(heir_index) != float(int(heir_index)) \
					or int(heir_index) < 0 \
					or int(heir_index) > int(saved.get("runClock", {}).get(
						"decisionIndex", -1)):
				return false
			rebuilt._mentor_heir_activation_index = int(heir_index)
			rebuilt._mentor_state["version"] = 2 if int(heir_index) > 0 else 3
			if int(heir_index) > 0:
				rebuilt._mentor_state.erase("heirActivationIndex")
		else:
			rebuilt._mentor_state["version"] = int(mentor_version)
			rebuilt._mentor_state.erase("heirActivationIndex")
		if int(mentor_version) == 4:
			var climax_index: Variant = saved_mentor.get("climaxActivationIndex")
			if not (climax_index is int or climax_index is float) \
					or float(climax_index) != float(int(climax_index)) \
					or int(climax_index) < 0 \
					or int(climax_index) > int(saved.get("runClock", {}).get(
						"decisionIndex", -1)) \
					or not saved_mentor.get("pendingClimaxes") is Array \
					or not saved_mentor.get("climaxTriggered") is bool:
				return false
			rebuilt._mentor_climax_activation_index = int(climax_index)
			if int(climax_index) > 0:
				rebuilt._mentor_state["version"] = 2 \
					if int(saved_mentor.get("heirActivationIndex", 0)) > 0 else 3
				rebuilt._mentor_state.erase("climaxActivationIndex")
				rebuilt._mentor_state.erase("pendingClimaxes")
				rebuilt._mentor_state.erase("climaxTriggered")
			else:
				rebuilt._mentor_state["version"] = 4
		else:
			rebuilt._mentor_state.erase("climaxActivationIndex")
			rebuilt._mentor_state.erase("pendingClimaxes")
			rebuilt._mentor_state.erase("climaxTriggered")
	if saved.has("factionCollectionNewActivationIndex"):
		if not _valid_integer(saved.factionCollectionNewActivationIndex) \
				or int(saved.factionCollectionNewActivationIndex) < 1 \
				or int(saved.factionCollectionNewActivationIndex) > int(saved.get(
					"runClock", {}).get("decisionIndex", -1)):
			return false
		rebuilt._legacy_faction_collection_replay = true
		rebuilt._faction_collection_new_activation_index = int(
			saved.factionCollectionNewActivationIndex)
	rebuilt._legacy_deck_replay = not saved.has("deckStateVersion")
	rebuilt._legacy_fragment_replay = not saved.has("legacyFragmentVersion")
	rebuilt._boss_reward_marker_present = saved.has("bossRewardActivationIndex")
	rebuilt._boss_reward_activation_index = int(saved.get("bossRewardActivationIndex",
		saved.get("runClock", {}).get("decisionIndex", 0)))
	if not rebuilt._boss_reward_marker_present:
		var past_rewards: Variant = saved.get("bossFragmentClaimActions", [])
		if past_rewards is Array and not past_rewards.is_empty():
			rebuilt._boss_reward_activation_index = int(past_rewards[0].get(
				"decisionIndex", rebuilt._boss_reward_activation_index))
		elif not saved.get("legacyRunState", {}).get("pendingBossFragmentReward") is Dictionary:
			rebuilt._boss_reward_activation_index += 1
	rebuilt._legacy_fragment_flow.roll_override = _legacy_fragment_flow.roll_override
	rebuilt._legacy_wheel_replay = not saved.has("destinyWheelVersion")
	rebuilt._legacy_market_replay = not saved.has("marketStateVersion")
	rebuilt._market_flow.roll_override = _market_flow.roll_override
	rebuilt._ripple_flow.roll_override = _ripple_flow.roll_override
	rebuilt._hint_flow.roll_override = _hint_flow.roll_override
	rebuilt._legacy_hint_replay = not saved.has("hintStateVersion")
	var hint_activation: Variant = saved.get("hintActivationIndex",
		int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1)
	if not (hint_activation is int or hint_activation is float) \
			or float(hint_activation) != float(int(hint_activation)) \
			or int(hint_activation) < 0:
		return false
	rebuilt._legacy_hint_replay_activation_index = int(hint_activation)
	if saved.has("hintStateVersion"):
		if saved.get("hintRuleSourceSha") != HintFlow.SOURCE_JS_SHA \
				or saved.get("hintDerivedSha") != HintFlow.DERIVED_SHA \
				or _hint_flow.derived_sha() != HintFlow.DERIVED_SHA:
			if _hint_flow.source_missing() and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if saved.get("hintStateVersion") != 1 or not saved.get("hintRngState") is Dictionary:
			return false
		var hint_seed: Variant = saved["hintRngState"].get("initialSeed")
		if not (hint_seed is int or hint_seed is float) \
				or float(hint_seed) != float(int(hint_seed)) \
				or int(hint_seed) <= 0 or int(hint_seed) >= HintFlow.RNG_MODULUS:
			return false
		rebuilt._legacy_hint_replay_initial_seed = int(
			hint_seed)
	rebuilt._legacy_ripple_replay = not saved.has("rippleStateVersion")
	rebuilt._legacy_ripple_replay_activation_index = int(saved.get(
		"rippleActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	if saved.has("rippleStateVersion"):
		if saved.get("rippleRuleSourceSha") != RippleFlow.SOURCE_JS_SHA \
				or saved.get("rippleDerivedSha") != RippleFlow.DERIVED_SHA \
				or _ripple_flow.derived_sha() != RippleFlow.DERIVED_SHA:
			if _ripple_flow.source_missing() and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if saved.get("rippleStateVersion") != 1 \
				or not saved.get("rippleRngState") is Dictionary:
			return false
		rebuilt._legacy_ripple_replay_initial_seed = int(
			saved["rippleRngState"].get("initialSeed", 0))
	if saved.has("marketVendorGameSourceSha") and (
			saved.get("marketVendorGameSourceSha") != VendorFlow.GAME_JS_SHA \
			or saved.get("marketVendorShopSourceSha") != VendorFlow.SHOP_JS_SHA):
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("regulatedProfileSourceSha") and (
			saved.get("regulatedProfileSourceSha") != _content.source_sha256(
				"markets:vendor_profiles") or saved.get("regulatedCatalogPins") \
				!= _regulated_catalog.source_pins()):
		return false
	if saved.has("regulatedCausalServiceVersion") and (
			saved.get("regulatedCausalServiceVersion") != 1 \
			or not saved.get("regulatedCausalActivationIndex") is float \
				and not saved.get("regulatedCausalActivationIndex") is int \
			or int(saved.get("regulatedCausalActivationIndex", -1)) <= 0 \
			or int(saved.get("regulatedCausalActivationIndex", -1)) > int(
				saved.get("runClock", {}).get("decisionIndex", -1)) + 1 \
			or not _pinned_source_matches(
				"narrative:causal_graph", String(saved.get(
					"regulatedCausalGraphSourceSha", "")))):
		return false
	if saved.has("causalFactClockVersion") and (
			saved.get("causalFactClockVersion") != 1 \
			or not (saved.get("causalFactClockActivationIndex") is int \
				or saved.get("causalFactClockActivationIndex") is float) \
			or int(saved.get("causalFactClockActivationIndex", -1)) <= 0 \
			or int(saved.get("causalFactClockActivationIndex", -1)) > int(
				saved.get("runClock", {}).get("decisionIndex", -1))):
		return false
	if saved.has("qMarketChoiceVersion") and (
			saved.get("qMarketChoiceVersion") != 1 \
			or not saved.get("qMarketChoiceActivationIndex") is float \
				and not saved.get("qMarketChoiceActivationIndex") is int \
			or int(saved.get("qMarketChoiceActivationIndex", -1)) <= 0 \
			or int(saved.get("qMarketChoiceActivationIndex", -1)) > int(
				saved.get("runClock", {}).get("decisionIndex", -1)) + 1):
		return false
	if saved.has("marketStateVersion"):
		if saved.get("marketRuleSourceSha") != MarketFlow.SOURCE_JS_SHA:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if saved.get("marketStateVersion") != 1 \
				or not saved.get("marketActivationIndex") is float \
					and not saved.get("marketActivationIndex") is int \
				or not saved.get("marketRngState") is Dictionary \
				or not _pinned_source_matches("markets:vendor_profiles",
					String(saved.get("marketProfileSourceSha", ""))):
			return false
		rebuilt._legacy_market_replay_activation_index = int(saved["marketActivationIndex"])
		rebuilt._legacy_market_replay_initial_seed = int(
			saved["marketRngState"].get("initialSeed", 0))
	if saved.has("ghostPlanVersion"):
		var ghost_activation: Variant = saved.get("ghostPlanActivationIndex")
		if not saved.has("marketStateVersion") or saved.get("ghostPlanVersion") != 1 \
				or not (ghost_activation is int or ghost_activation is float) \
				or float(ghost_activation) != float(int(ghost_activation)) \
				or int(ghost_activation) < int(saved.get("marketActivationIndex", 0)) \
				or int(ghost_activation) > int(saved.get("runClock", {}).get(
					"decisionIndex", -1)):
			return false
		rebuilt._market_flow.ghost_plan_activation_index = int(ghost_activation)
	else:
		if saved.has("ghostPlanActivationIndex") or saved.has("pendingGhostPlan"):
			return false
		rebuilt._market_flow.ghost_plan_activation_index = int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1
	rebuilt._destiny_wheel_flow.roll_override = _destiny_wheel_flow.roll_override
	rebuilt._market_flow.roll_override = _market_flow.roll_override
	rebuilt._ripple_flow.roll_override = _ripple_flow.roll_override
	rebuilt._hint_flow.roll_override = _hint_flow.roll_override
	rebuilt._quest_flow.opportunity_flow.roll_override = \
		_quest_flow.opportunity_flow.roll_override
	rebuilt._quest_flow.opportunity_flow.initial_seed_override = int(saved.get(
		"opportunityRngState", {}).get("initialSeed", 0))
	if saved.has("destinyWheelVersion"):
		if saved.get("destinyWheelRuleSourceSha") != DestinyWheelFlow.SOURCE_JS_SHA:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if saved.get("destinyWheelVersion") != 1 \
				or not saved.get("destinyWheelActivationIndex") is float \
					and not saved.get("destinyWheelActivationIndex") is int \
				or not saved.get("destinyWheelRngState") is Dictionary:
			return false
		rebuilt._legacy_wheel_replay_activation_index = int(saved["destinyWheelActivationIndex"])
		rebuilt._legacy_wheel_replay_initial_seed = int(
			saved["destinyWheelRngState"].get("initialSeed", 0))
	if saved.has("treasureRuleSourceSha") and \
			saved.get("treasureRuleSourceSha") != TreasureAcquisition.SOURCE_JS_SHA:
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.has("treasureRuleSourceSha") and not _pinned_source_matches(
			"shops:treasures", String(saved.get("treasureSourceSha", ""))):
		return false
	if saved.has("legacyFragmentVersion"):
		if saved.get("legacyRuleSourceSha") != LegacyFragmentFlow.SOURCE_JS_SHA:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if saved.get("legacyFragmentVersion") != 1 \
				or not saved.get("legacyFragmentActivationIndex") is float \
					and not saved.get("legacyFragmentActivationIndex") is int \
				or not saved.get("legacyRngState") is Dictionary:
			return false
		rebuilt._legacy_fragment_replay_activation_index = int(
			saved["legacyFragmentActivationIndex"])
		rebuilt._legacy_fragment_replay_initial_seed = int(
			saved["legacyRngState"].get("initialSeed", 0))
	if saved.has("deckStateVersion") and (saved.get("deckStateVersion") != 1 \
			or not saved.get("deckProgressionSourceSha") is String \
			or not saved.get("battleCardSourceSha") is String \
			or not _pinned_source_matches("combat:deck_progression",
				String(saved["deckProgressionSourceSha"])) \
			or not _pinned_source_matches("cards:battle_cards",
				String(saved["battleCardSourceSha"]))):
		return false
	if saved.has("playerName") and (not saved["playerName"] is String \
			or String(saved["playerName"]).is_empty()):
		return false
	if not rebuilt.start(String(saved["path"]), String(saved.get("playerName", "叶凌云"))):
		_mark_source_failure(rebuilt._content)
		return false
	rebuilt._battle_return_flow.legacy_qi_spine_victory_replay = \
		_legacy_qi_spine_victory(saved)
	# Old official sessions keep their frozen service list during replay. A new
	# session after an old save is restored sets the activation point explicitly.
	if saved.has("regulatedCausalServiceVersion"):
		rebuilt._regulated_vendor.causal_activation_index = int(saved[
			"regulatedCausalActivationIndex"])
	else:
		rebuilt._regulated_vendor.causal_activation_index = int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + (2 if saved.get(
			"phase") == "VENDOR_OPEN" and saved.get("marketState", {}).get(
				"activeSession", {}).get("vendorId") == RegulatedVendor.VENDOR_ID else 1)
	rebuilt._causal_fact_clock.activation_index = int(saved.get(
		"causalFactClockActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	if saved.has("qMarketChoiceVersion"):
		rebuilt._q_market_choice_activation_index = int(saved[
			"qMarketChoiceActivationIndex"])
	else:
		# Replaying a pre-upgrade save must preserve its completed source choices.
		# An old open session settles its q_market choice one decision later.
		rebuilt._q_market_choice_activation_index = int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + (2 if saved.get(
			"phase") == "VENDOR_OPEN" and saved.get("marketState", {}).get(
				"activeSession", {}).get("entryCardId") == "q_market" else 1)
	# N3b snapshots predate the decision-based karma clock. Replay their exact
	# historical state, then upgrade only when the restored run advances.
	var saved_flow: Variant = saved.get("noncombatFlow", {})
	if saved_flow is Dictionary:
		rebuilt._hint_flow.legacy_clue_sink = saved_flow.has("hintClues")
		rebuilt._quest_flow.legacy_tianshu_replay = not saved_flow.has(
			"tianshuSourceSha")
		for historical_choice in saved.get("replayHistory", saved.get(
				"choiceHistory", [])):
			if not historical_choice is Dictionary:
				continue
			if String(historical_choice.get("cardId", "")).begins_with("q_spell_"):
				rebuilt._quest_flow.replay_first_foundation_quest_module = \
					"quests:spell_codex"
				break
			if String(historical_choice.get("cardId", "")).begins_with("q_tianshu_"):
				break
		if saved.get("phase") == "QUEST_PENDING" and String(saved.get(
				"currentCardId", "")).begins_with("q_spell_") and rebuilt._quest_flow.replay_first_foundation_quest_module.is_empty():
			rebuilt._quest_flow.replay_first_foundation_quest_module = \
				"quests:spell_codex"
	# Earlier saves were scheduled before the due-karma lane existed. Replay
	# their exact card order, then use the new priority on live continuation.
	rebuilt._legacy_karma_order_replay = saved_flow is Dictionary \
		and not saved_flow.has("karmaArbitrationVersion")
	if not _restore_flow_sources(saved_flow, saved):
		return false
	if saved.get("phase") == "QUEST_PENDING" \
			and saved.get("currentCardId") == "q_whiteFox_quest" \
			and saved_flow is Dictionary and not saved_flow.has("npcSourceSha") \
			and not saved.has("worldContinuityState"):
		rebuilt._quest_flow.legacy_entry_replay = true
	if saved_flow is Dictionary and saved_flow.get("scope") == "first_session_avoid":
		if not saved_flow.has("karmaClockVersion"):
			rebuilt._legacy_karma_replay = true
			rebuilt._avoid_flow.legacy_replay = true
		if not saved_flow.has("lifespanCostVersion"):
			rebuilt._legacy_lifespan_replay = true
			rebuilt._avoid_flow.legacy_lifespan_replay = true
		if not saved_flow.has("promise") and (not saved_flow.has("karmaClockVersion") \
				or saved_flow.get("legacySchemaVersion") == 0):
			rebuilt._avoid_flow.legacy_schema_replay = true
	var replay_history: Array = saved.get("replayHistory", saved["choiceHistory"])
	var dungeon_actions: Array = saved.get("dungeonActionHistory", [])
	for action in dungeon_actions:
		if not action is Dictionary:
			return false
	var dungeon_action_index := 0
	var equipment_action_index := 0
	for entry in replay_history:
		rebuilt.state = rebuilt._replay_npc_interactions(saved, rebuilt.state,
			int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
		if rebuilt.state.is_empty():
			return false
		rebuilt.state = rebuilt._replay_legacy_focus_actions(saved, rebuilt.state,
			int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
		if rebuilt.state.is_empty():
			return false
		rebuilt.state = rebuilt._replay_portrait_actions(saved, rebuilt.state,
			int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
		if rebuilt.state.is_empty():
			return false
		rebuilt.state = rebuilt._replay_boss_claims(saved, rebuilt.state,
			int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
		if rebuilt.state.is_empty():
			return false
		if not rebuilt._replay_deferred_last_lesson_loadout(saved):
			return false
		if dungeon_action_index < dungeon_actions.size() and \
				int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)) == \
				int(dungeon_actions[dungeon_action_index].get("decisionIndex", -2)):
			if not _replay_dungeon_action(rebuilt, dungeon_actions[dungeon_action_index]):
				return false
			dungeon_action_index += 1
		equipment_action_index = _replay_equipment_actions(saved, rebuilt,
			equipment_action_index)
		if equipment_action_index < 0:
			return false
		if not entry is Dictionary or not entry.get("direction") is String:
			return false
		if entry.has("combatOutcome"):
			if not _restore_battle_record(saved, entry, rebuilt):
				return false
			continue
		if rebuilt.state.get("phase") == "FLOW_PENDING" \
				and (String(entry.get("cardId", "")).begins_with("ch_") \
					or String(entry.get("cardId", "")).begins_with("q_whiteFox_") \
					or String(entry.get("cardId", "")).begins_with("q_sword_") \
					or String(entry.get("cardId", "")).begins_with("q_body_") \
					or String(entry.get("cardId", "")).begins_with("q_spell_") \
					or String(entry.get("cardId", "")).begins_with("q_pill_") \
					or String(entry.get("cardId", "")).begins_with("q_tianshu_") \
					or String(entry.get("cardId", "")).begins_with("encounter_card_") \
					or String(entry.get("cardId", "")).begins_with("kx_") \
					or String(entry.get("cardId", "")).begins_with("k_chapter_") \
					or String(entry.get("cardId", "")) == KarmaFlow.BODY_CARD_ID \
					or String(entry.get("cardId", "")) in [
						KarmaFlow.BODY_ECHO_CARD_ID, KarmaFlow.BODY_ASCENSION_CARD_ID] \
					or String(entry.get("cardId", "")).begins_with("em_") \
					or String(entry.get("cardId", "")).begins_with("karma_ripple:") \
					or String(entry.get("cardId", "")).begins_with("heavens_hint:") \
					or String(entry.get("cardId", "")).begins_with("loc_") \
					or String(entry.get("cardId", "")).begins_with("echo_echo_") \
					or String(entry.get("cardId", "")).begins_with("ally_xuesha_laozu_") \
					or String(entry.get("cardId", "")).begins_with("seer_tianji_laoren_") \
					or String(entry.get("cardId", "")).begins_with("surface_") \
					or String(entry.get("cardId", "")).begins_with("comp_") \
					or String(entry.get("cardId", "")).begins_with("faction_") \
					or String(entry.get("cardId", "")).begins_with("thread_") \
					or String(entry.get("cardId", "")) == MarketFlow.BAZAAR_ID \
					or String(entry.get("cardId", "")) == MarketFlow.GHOST_ID \
					or String(entry.get("cardId", "")) == CampFlow.CARD_ID \
					or String(entry.get("cardId", "")) == "destiny_wheel" \
					or String(entry.get("cardId", "")) == RegulatedCatalog.CARD_ID \
					or String(entry.get("cardId", "")) == "q_market" \
					or String(entry.get("cardId", "")).begins_with(
						"regulated_rusted_sword_delivery:") \
					or String(entry.get("cardId", "")).begins_with("ghost_debt_due:") \
					or String(entry.get("cardId", "")).begins_with("mentor_") \
					or String(entry.get("cardId", "")).begins_with("npc_encounter_") \
					or String(entry.get("cardId", "")).begins_with("npc_cross_") \
					or _normal_history_has_card(saved_normal, String(entry.get("cardId", "")))) \
				and not rebuilt.resume_flow():
			_mark_source_failure(rebuilt._content)
			if (not rebuilt._milestone_flow.last_error.is_empty() \
					or not rebuilt._quest_flow.last_error.is_empty() \
					or not rebuilt._karma_flow.last_error.is_empty() \
					or not rebuilt._mentor_flow.last_error.is_empty()) \
					and _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			_mark_ripple_failure(rebuilt._ripple_flow)
			_mark_thread_failure(rebuilt._story_thread_flow)
			return false
		var replay_id := String(rebuilt.state.get("currentCardId", "")) if \
			rebuilt.state.get("phase") == "COMBAT_HANDOFF" else \
			String(rebuilt.get_current_card().get("id", ""))
		if entry.get("cardId") != replay_id \
				or not rebuilt.choose(String(entry["direction"]), rebuilt.issue_choice_token()):
			_mark_source_failure(rebuilt._content)
			_mark_battle_return_failure(rebuilt._first_session_route)
			if (not rebuilt._quest_flow.last_error.is_empty() \
					or not rebuilt._milestone_flow.last_error.is_empty() \
					or not rebuilt._karma_flow.last_error.is_empty() \
					or not rebuilt._mentor_flow.last_error.is_empty()) \
					and _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			_mark_ripple_failure(rebuilt._ripple_flow)
			_mark_thread_failure(rebuilt._story_thread_flow)
			return false
		if entry.get("cardId") == MarketFlow.BAZAAR_ID \
				and entry.get("direction") == "left":
			if not rebuilt._replay_vendor_actions(saved) \
					or not rebuilt.close_vendor(rebuilt.issue_choice_token()):
				return false
		if entry.get("cardId") == LastLessonVendor.ENTRY_ID \
				and entry.get("direction") == "left":
			if not rebuilt._replay_vendor_actions(saved) \
					or not rebuilt.close_vendor(rebuilt.issue_choice_token()):
				return false
		if entry.get("cardId") == MarketFlow.GHOST_ID \
				and entry.get("direction") == "left":
			if not rebuilt._replay_vendor_actions(saved) \
					or not rebuilt.close_vendor(rebuilt.issue_choice_token()):
				return false
		if (entry.get("cardId") == RegulatedCatalog.CARD_ID \
				and entry.get("direction") == "right" or entry.get("cardId") == "q_market" \
				and entry.get("direction") == "left" or entry.get("cardId") == FirstSessionRoute.MARKET_ID \
				and entry.get("direction") == "left"):
			if not rebuilt._replay_vendor_actions(saved) \
					or not rebuilt.close_vendor(rebuilt.issue_choice_token()):
				return false
		if String(entry.get("cardId", "")).begins_with(
				"regulated_rusted_sword_delivery:"):
			var pending_loadout: Dictionary = rebuilt.state.get(
				"pendingLoadoutDecision", {})
			var loadout_token := String(pending_loadout.get(
				"purchaseReceiptToken", ""))
			var matches: Array = saved.get("loadoutResolutionHistory", []).filter(
				func(row: Variant) -> bool:
					return row is Dictionary and row.get("purchaseReceiptToken") \
						== loadout_token)
			if loadout_token.is_empty() or matches.size() > 1:
				return false
			if matches.size() == 1 and not rebuilt.resolve_vendor_loadout(
					String(matches[0].get("action", "")),
					rebuilt.issue_choice_token()):
				return false
		if entry.get("cardId") == CampFlow.CARD_ID \
				and entry.get("direction") in ["right", "down"] \
				or entry.get("cardId") in ["q_shop", "f_shop", "g_shop"] \
					and entry.get("direction") == "up":
			var matching: Array = []
			for target in saved.get("campTargetHistory", []):
				if not target is Dictionary:
					return false
				if target.get("decisionIndex") == entry.get("decisionIndex"):
					matching.append(target)
			if matching.size() > 1:
				return false
			if matching.size() == 1:
				var target: Dictionary = matching[0]
				if entry.get("cardId") in ["q_shop", "f_shop", "g_shop"] and target.get(
						"sourceCardId") != entry.get("cardId") or entry.get("cardId") \
						== CampFlow.CARD_ID and target.has("sourceCardId"):
					return false
				if target.get("action") == "cancel":
					if not rebuilt.cancel_camp_target(rebuilt.issue_choice_token()):
						return false
				elif target.get("action") == rebuilt.state.get("pendingCampAction"):
					if not rebuilt.resolve_camp_target(int(target.get("index", -1)),
							String(target.get("cardId", "")), rebuilt.issue_choice_token()):
						return false
				else:
					return false
	if dungeon_action_index < dungeon_actions.size() and \
			int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)) == \
			int(dungeon_actions[dungeon_action_index].get("decisionIndex", -2)):
		if not _replay_dungeon_action(rebuilt, dungeon_actions[dungeon_action_index]):
			return false
		dungeon_action_index += 1
	if dungeon_action_index != dungeon_actions.size():
		return false
	if not _restore_encounter_actions(saved, rebuilt):
		return false
	if saved.get("phase") == "COMBAT_HANDOFF" and saved.has("pendingCadenceCard") \
			and rebuilt.state.get("phase") == "FLOW_PENDING" and not rebuilt.resume_flow():
		_mark_battle_return_failure(rebuilt._cadence_flow)
		return false
	if saved.get("phase") == "MILESTONE_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		_mark_source_failure(rebuilt._content)
		if not rebuilt._milestone_flow.last_error.is_empty() \
				and _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "QUEST_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		_mark_source_failure(rebuilt._content)
		if not rebuilt._quest_flow.last_error.is_empty() and _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "MENTOR_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		_mark_source_failure(rebuilt._content)
		if not rebuilt._mentor_flow.last_error.is_empty() and _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "KARMA_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		_mark_source_failure(rebuilt._content)
		if not rebuilt._karma_flow.last_error.is_empty() and _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "EMERGENT_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		if not FileAccess.file_exists(EmergentFlow.DERIVED_PATH) \
				and _store.has_method("mark_source_unavailable"):
			_store.mark_source_unavailable()
		elif _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "MARKET_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "RIPPLE_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		if rebuilt._ripple_flow.source_missing() and _store.has_method("mark_source_unavailable"):
			_store.mark_source_unavailable()
		elif _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "HINT_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		if rebuilt._hint_flow.source_missing() and _store.has_method("mark_source_unavailable"):
			_store.mark_source_unavailable()
		elif _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	if saved.get("phase") == "THREAD_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		_mark_thread_failure(rebuilt._story_thread_flow)
		return false
	if saved.get("phase") in ["NPC_PENDING", "NPC_CROSS_PENDING"] \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "NORMAL_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	equipment_action_index = _replay_equipment_actions(saved, rebuilt,
		equipment_action_index)
	if equipment_action_index < 0 or equipment_action_index != saved.get(
			"treasureEquipmentHistory", []).size():
		return false
	if saved.get("phase") == "LOCATION_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "CHOICE_ECHO_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "ALLY_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "COMPANION_ARC_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "SEER_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "SURFACING_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "COMPANION_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "FACTION_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "CAMP_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "SHOP_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "LICENSED_DELIVERY_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "GHOST_DEBT_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if saved.get("phase") == "VENDOR_OPEN":
		if rebuilt.state.get("phase") == "FLOW_PENDING" and not rebuilt.resume_flow():
			return false
		var lesson: bool = saved.get("marketState", {}).get(
			"activeSession", {}).get("entryCardId") == LastLessonVendor.ENTRY_ID
		var regulated: bool = saved.get("marketState", {}).get("activeSession", {}).get(
			"vendorId") == RegulatedVendor.VENDOR_ID
		var vendor_direction := String(saved.get("marketState", {}).get(
			"activeSession", {}).get("direction", ""))
		var first_market: bool = saved.get("marketState", {}).get("activeSession", {}).get("entryCardId") == FirstSessionRoute.MARKET_ID
		if rebuilt.state.get("phase") != ("THREAD_PENDING" if lesson else \
				("FIRST_SESSION_ROUTE_PENDING" if first_market else \
				("SHOP_PENDING" if regulated else "MARKET_PENDING"))) \
				or not rebuilt.choose("left" if lesson else vendor_direction,
					rebuilt.issue_choice_token()) \
				or not rebuilt._replay_vendor_actions(saved):
			return false
	if saved.get("phase") == "DESTINY_WHEEL_PENDING" \
			and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if not rebuilt._replay_deferred_last_lesson_loadout(saved):
		return false
	rebuilt.state = rebuilt._replay_npc_interactions(saved, rebuilt.state,
		int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
	if rebuilt.state.is_empty():
		return false
	# Godot JSON parses integral numbers as floats; normalize both sides before
	# comparing the complete replayed state.
	# Earlier Godot v1 openings had no name field; they retain the browser
	# default until the next committed decision upgrades the snapshot.
	if not saved.has("playerName"):
		rebuilt.state.erase("playerName")
	if not saved.has("replayHistory"):
		rebuilt.state.erase("replayHistory")
	if not saved.has("regulatedEventHistory"):
		rebuilt.state.erase("regulatedEventHistory")
	if not saved.has("lastLessonVendorEventHistory"):
		rebuilt.state.erase("lastLessonVendorEventHistory")
	rebuilt.state = rebuilt._replay_legacy_focus_actions(saved, rebuilt.state,
		int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
	if rebuilt.state.is_empty():
		return false
	rebuilt.state = rebuilt._replay_portrait_actions(saved, rebuilt.state,
		int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
	if rebuilt.state.is_empty():
		return false
	rebuilt.state = rebuilt._replay_boss_claims(saved, rebuilt.state,
		int(rebuilt.state.get("runClock", {}).get("decisionIndex", -1)))
	if saved.has("factionCollectionNewActivationIndex"):
		rebuilt.state["factionCollectionNewActivationIndex"] = \
			rebuilt._faction_collection_new_activation_index
	if saved.has("browserCombatSnapshot") or saved.has("browserCombatAuthority"):
		if not saved.get("browserCombatSnapshot") is Dictionary \
				or not saved.get("browserCombatAuthority") is Dictionary \
				or rebuilt.state.get("phase") != "BATTLE_PENDING" \
				or not BrowserCombatSemantics.new().verify_first_sword_card(
					saved.browserCombatSnapshot, saved.browserCombatAuthority, _registry):
			return false
		var authority: Dictionary = saved.browserCombatAuthority
		if authority.get("path") != rebuilt.state.get("path") \
				or authority.get("realm") != rebuilt.state.get("realm") \
				or authority.get("lifeCount") != 0 \
				or rebuilt.state.get("runClock", {}).get("lifeId") \
					!= "%s:life:0" % _slot_id \
				or authority.get("runClock", {}).get("decisionIndex") \
					!= rebuilt.state.get("runClock", {}).get("decisionIndex") \
				or authority.get("maxHealth") != rebuilt.state.get("maxHealth") \
				or authority.get("deck") != rebuilt.state.get("deck"):
			return false
		for key in ["health", "daoHeart", "aura"]:
			if authority.get("attributes", {}).get(key) \
					!= rebuilt.state.get("attributes", {}).get(key):
				return false
		var imported_request: Dictionary = rebuilt.battle_request()
		var source_card := String(saved.browserCombatSnapshot.get(
			"originalCard", {}).get("id", ""))
		if imported_request.get("sourceCardId") != source_card \
				or imported_request.get("encounterInstanceId") != "enc:%s:life:0:5:%s:1" % [
				_slot_id, source_card]:
			return false
		if saved.has("browserCombatActions"):
			if not saved.browserCombatActions is Array:
				return false
			var imported_plan: Dictionary = BrowserCombatPlan.new(_registry).resolve_persisted(
				rebuilt.state)
			if BrowserCombatActions.new().replay(saved.browserCombatSnapshot,
					saved.browserCombatAuthority, imported_request, imported_plan,
					saved.browserCombatActions, _registry).is_empty():
				return false
			rebuilt.state["browserCombatActions"] = saved.browserCombatActions.duplicate(true)
		rebuilt.state["browserCombatSnapshot"] = saved.browserCombatSnapshot.duplicate(true)
		rebuilt.state["browserCombatAuthority"] = saved.browserCombatAuthority.duplicate(true)
	elif saved.has("browserCombatActions"):
		return false
	if _legacy_mortal_npc_pin(saved, saved_flow) \
			and not _project_legacy_mortal_replay(rebuilt.state):
		return false
	if rebuilt.state.is_empty() or JSON.parse_string(JSON.stringify(rebuilt.state)) != saved:
		return false
	_cards = rebuilt._cards
	_path_definition = rebuilt._path_definition
	_cultivation_max = rebuilt._cultivation_max
	_current_card_id = rebuilt._current_card_id
	_choice_token = rebuilt._choice_token
	_store_revision = int(record.get("revision", -1))
	_mentor_state = rebuilt._mentor_state.duplicate(true)
	_flow_card_count = rebuilt._flow_card_count
	_normal_starvation = rebuilt._normal_starvation.duplicate(true)
	_normal_choice_pin_activation_index = rebuilt._normal_choice_pin_activation_index
	_market_skip_seed_tick_activation_index = rebuilt._market_skip_seed_tick_activation_index
	_regulated_vendor.causal_activation_index = rebuilt._regulated_vendor.causal_activation_index
	_trade_route_flow.activation_index = rebuilt._trade_route_flow.activation_index
	_trade_route_flow.legacy_initial_trusted = \
		rebuilt._trade_route_flow.legacy_initial_trusted
	_market_flow.ghost_plan_activation_index = \
		rebuilt._market_flow.ghost_plan_activation_index
	_causal_fact_clock.activation_index = rebuilt._causal_fact_clock.activation_index
	_q_market_choice_activation_index = rebuilt._q_market_choice_activation_index
	_story_thread_flow.activation_index = rebuilt._story_thread_flow.activation_index
	_story_thread_flow.upgrade_index = rebuilt._story_thread_flow.upgrade_index
	_story_thread_flow.village_activation_index = rebuilt._story_thread_flow.village_activation_index
	_story_thread_flow.sword_activation_index = rebuilt._story_thread_flow.sword_activation_index
	_story_thread_flow.mist_activation_index = rebuilt._story_thread_flow.mist_activation_index
	_story_thread_flow.higher_activation_index = rebuilt._story_thread_flow.higher_activation_index
	_story_thread_flow.last_lesson_activation_index = rebuilt._story_thread_flow.last_lesson_activation_index
	_world_continuity_activation_index = rebuilt._world_continuity_activation_index
	_world_pulse_activation_index = rebuilt._world_pulse_activation_index
	_faction_activation_index = rebuilt._faction_activation_index
	_legacy_faction_collection_replay = rebuilt._legacy_faction_collection_replay
	_faction_collection_new_activation_index = \
		rebuilt._faction_collection_new_activation_index
	_cadence_activation_index = rebuilt._cadence_activation_index
	_cadence_high_upgrade_index = rebuilt._cadence_high_upgrade_index
	_path_skill_activation_index = rebuilt._path_skill_activation_index
	_boss_reward_activation_index = rebuilt._boss_reward_activation_index
	_boss_reward_marker_present = rebuilt._boss_reward_marker_present
	_passive_regen_extension_activation_index = \
		rebuilt._passive_regen_extension_activation_index
	_early_avoid_activation_index = rebuilt._early_avoid_activation_index
	_npc_activation_index = rebuilt._npc_activation_index
	_npc_general_activation_index = rebuilt._npc_general_activation_index
	_npc_encounter_flow.roll_override_sequence = \
		rebuilt._npc_encounter_flow.roll_override_sequence.duplicate(true)
	_npc_cross_activation_index = rebuilt._npc_cross_activation_index
	_npc_cross_dynamic_activation_index = rebuilt._npc_cross_dynamic_activation_index
	_npc_cross_flow.roll_override_sequence = \
		rebuilt._npc_cross_flow.roll_override_sequence.duplicate(true)
	_combat_scheduling_activation_index = rebuilt._combat_scheduling_activation_index
	_scene_activation_index = rebuilt._scene_activation_index
	_echo_activation_index = rebuilt._echo_activation_index
	_ally_activation_index = rebuilt._ally_activation_index
	_companion_arc_activation_index = rebuilt._companion_arc_activation_index
	_seer_activation_index = rebuilt._seer_activation_index
	_surfacing_activation_index = rebuilt._surfacing_activation_index
	_companion_activation_index = rebuilt._companion_activation_index
	_companion_milestone_activation_index = rebuilt._companion_milestone_activation_index
	_narrative_admission_activation_index = rebuilt._narrative_admission_activation_index
	state = saved.duplicate(true)
	changed.emit({"type": "RESTORED", "cardId": _current_card_id})
	return true


func _legacy_qi_spine_victory(saved: Dictionary) -> bool:
	var flow: Variant = saved.get("noncombatFlow")
	if not flow is Dictionary:
		return false
	var life := int(saved.get("lifeCount", 0))
	var facts: Dictionary = flow.get("spineFacts", {})
	var consumptions: Dictionary = flow.get("spineConsumptions", {})
	if life < 0 or facts.get("fact:%d:qi_main_trial" % life, {}).get("status") != "active" \
			or facts.get("fact:%d:qi_sword_master_stance" % life, {}).get("status") != "active" \
			or facts.has("fact:%d:qi_main_outcome" % life) \
			or consumptions.has("fact:%d:qi_main_trial:qi_main_trial_resolution" % life) \
			or consumptions.has("fact:%d:qi_sword_master_stance:qi_sword_master_stance_resolution" % life):
		return false
	for entry in saved.get("battleResultHistory", []):
		if entry is Dictionary and entry.get("result", {}).get("sourceCardId") == \
				RealmGateFlow.CARD_ID and entry.get("result", {}).get("outcome") == "victory":
			return true
	return false


func _restore_battle_sources(saved: Dictionary) -> bool:
	if saved.has("opportunitySourceSha") and not _pinned_source_matches(
			"progression:acquisition_opportunities",
			String(saved.opportunitySourceSha)):
		return false
	if saved.has("battleResultHistory"):
		if not saved.battleResultHistory is Array or saved.battleResultHistory.is_empty() \
				or saved.battleResultHistory.any(func(value: Variant) -> bool: return not value is Dictionary):
			return false
		if saved.get("battleReturnRulePins") != BattleReturnFlow.RULE_PINS:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
	if saved.has("battleVictoryRulePins"):
		if saved.battleVictoryRulePins != BattleReturnFlow.VictoryFlow.RULE_PINS:
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
		if not _pinned_source_matches("combat:visual_worlds", String(saved.get("battleVictoryWorldSha", ""))):
			return false
	if saved.has("battleQuestRulePins") and saved.battleQuestRulePins != QuestFlow.BATTLE_RULE_PINS:
		if _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	for module_id in saved.get("noncombatFlow", {}).get("firstSessionRouteSourceHashes", {}):
		if not _pinned_source_matches(module_id, String(saved.noncombatFlow.firstSessionRouteSourceHashes[module_id])):
			return false
	return true


func _restore_flow_sources(saved_flow: Variant, saved: Dictionary = {}) -> bool:
	# This older flow used one broad encounter/battle content digest. A newer
	# battle-card source cannot reproduce its saved hash, so preserve the file
	# as source drift instead of letting replay equality classify it as corrupt.
	if saved_flow is Dictionary and saved_flow.get("sourceContentHash") is String \
			and String(saved_flow["sourceContentHash"]).length() == 64 \
			and saved_flow["sourceContentHash"] != _battle_gateway.source_content_hash():
		if _gateway_source_unavailable(_content) \
				and _store.has_method("mark_source_unavailable"):
			_store.mark_source_unavailable()
		elif _store.has_method("mark_source_mismatch"):
			_store.mark_source_mismatch()
		return false
	# The v2 opening fingerprint intentionally excludes documents first used
	# after the opening. Each scheduled flow pins its own sources. Check all pins
	# before replay; otherwise a coherent authored update looks like a bad save.
	if saved_flow is Dictionary:
		if saved_flow.has("emergentSourceSha") or saved_flow.has("emergentDerivedSha"):
			if not FileAccess.file_exists(EmergentFlow.DERIVED_PATH) \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
				return false
			if saved_flow.get("emergentSourceSha") != EmergentFlow.SOURCE_JS_SHA \
					or saved_flow.get("emergentDerivedSha") != _emergent_flow.derived_sha():
				if _store.has_method("mark_source_mismatch"):
					_store.mark_source_mismatch()
				return false
		for pin in [
			["milestoneSourceSha", "cards:chapter_milestones"],
			["realmGateSourceSha", "cards:chapter_milestones"],
			["causalGraphSourceSha", "narrative:causal_graph"],
			["questSourceSha", "quests:white_fox"],
			["foundationQuestSourceSha", String(saved_flow.get(
				"foundationQuestModule", "quests:sword_legacy"))],
			["tianshuSourceSha", "quests:tianshu_codex"],
			["factionSourceSha", "world:factions"],
			["karmaExpansionSourceSha", "cards:karma_expansion"],
			["karmaBodySourceSha", "cards:qi"],
			["karmaSourceSha", "cards:karma"],
			["deckProgressionSourceSha", "combat:deck_progression"],
			["battleCardSourceSha", "cards:battle_cards"],
			["npcSourceSha", "npcs:core"],
			["mentorArcSourceSha", "companions:arcs"],
			["mentorPortraitSourceSha", "companions:portrait_stages"]
		]:
			if pin[0] == "npcSourceSha" and _legacy_mortal_npc_pin(saved, saved_flow):
				continue
			if saved_flow.get(pin[0]) is String \
					and String(saved_flow[pin[0]]).length() == 64 \
					and not _pinned_source_matches(String(pin[1]), String(saved_flow[pin[0]])):
				return false
	return true


func _legacy_mortal_npc_pin(saved: Dictionary, saved_flow: Dictionary) -> bool:
	const old_sha := "c3fdcf69963a2ec921183e52bb441d616a13e8b8c9f4be42937241369b0579ab"
	if saved_flow.get("npcSourceSha") != old_sha \
			or saved.has("worldContinuityActivationIndex"):
		return false
	var world: Variant = saved.get("worldContinuityState")
	if not world is Dictionary or world.get("version") != 1 \
			or not world.get("npcs") is Dictionary \
			or world.npcs.has("mortal"):
		return false
	var core: Variant = _content.read_module("npcs:core")
	return core is Dictionary and core.get("npcs", []).any(
		func(row: Variant) -> bool: return row is Dictionary \
			and row.get("id") == "mortal")


func _project_legacy_mortal_replay(replayed: Dictionary) -> bool:
	var flow: Variant = replayed.get("noncombatFlow")
	var world: Variant = replayed.get("worldContinuityState")
	if not flow is Dictionary or not world is Dictionary \
			or flow.get("npcSourceSha") != _content.source_sha256("npcs:core") \
			or not world.get("npcs") is Dictionary:
		return false
	var mortal: Variant = world.npcs.get("mortal")
	if not mortal is Dictionary or mortal.get("revision") != 16 \
			or mortal.get("changedByNode") != "npc_registered" \
			or mortal.get("reason") != "initial_presence" \
			or int(world.get("revision", 0)) < 16:
		return false
	world.npcs.erase("mortal")
	world.revision = int(world.revision) - 1
	for npc_id in world.npcs:
		var entry: Variant = world.npcs[npc_id]
		if entry is Dictionary and int(entry.get("revision", 0)) > 16:
			entry.revision = int(entry.revision) - 1
	flow.npcSourceSha = "c3fdcf69963a2ec921183e52bb441d616a13e8b8c9f4be42937241369b0579ab"
	return true


func _upgrade_legacy_mortal_world(candidate: Dictionary) -> bool:
	var current: Dictionary = WorldContinuity.initial(_content,
		int(candidate.get("lifeCount", 0)))
	var world: Variant = candidate.get("worldContinuityState")
	var mortal: Variant = current.get("state", {}).get("npcs", {}).get("mortal")
	if current.is_empty() or not world is Dictionary \
			or not world.get("npcs") is Dictionary \
			or world.npcs.has("mortal") or not mortal is Dictionary \
			or int(world.get("revision", 0)) < 15:
		return false
	for npc_id in world.npcs:
		var entry: Variant = world.npcs[npc_id]
		if entry is Dictionary and int(entry.get("revision", 0)) >= 16:
			entry.revision = int(entry.revision) + 1
	world.npcs.mortal = mortal.duplicate(true)
	world.revision = int(world.revision) + 1
	candidate.noncombatFlow.npcSourceSha = _content.source_sha256("npcs:core")
	return true


func _restore_battle_record(saved: Dictionary, entry: Dictionary, rebuilt: RefCounted) -> bool:
	if rebuilt.state.get("phase") == "FLOW_PENDING" and (entry.get("cardId") in ["q_whiteFox_3", "q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "it_combat", "thread_ab_village_3", "thread_sword_tomb_2", "thread_last_lesson_n3", BattleGateway.FACTION_GATE_SOURCE_ID, BattleGateway.COMPANION_OLD_MASTER_SOURCE_ID, RealmGateFlow.CARD_ID, RealmGateFlow.FOUNDATION_CARD_ID, RealmGateFlow.GOLDEN_CARD_ID, RealmGateFlow.NASCENT_CARD_ID, RealmGateFlow.DEITY_CARD_ID] \
			or String(entry.get("cardId", "")).begins_with("encounter_card_")) \
			and not rebuilt.resume_flow():
		return false
	var battle_history: Variant = saved.get("battleResultHistory")
	if not battle_history is Array:
		return false
	var matching: Array = battle_history.filter(func(value: Variant) -> bool:
		return value is Dictionary and value.get("decisionIndex") == entry.get("decisionIndex"))
	if matching.size() != 1:
		return false
	var battle_record: Dictionary = matching[0]
	if entry.get("cardId") in [RealmGateFlow.CARD_ID, RealmGateFlow.FOUNDATION_CARD_ID, RealmGateFlow.GOLDEN_CARD_ID, RealmGateFlow.NASCENT_CARD_ID, RealmGateFlow.DEITY_CARD_ID]:
		if rebuilt.state.get("phase") != "WARNING_PENDING" \
				or battle_record.get("result", {}).get("outcome") != entry.get("combatOutcome") \
				or not rebuilt.choose(String(battle_record.get("warningDirection", "")),
					rebuilt.issue_choice_token()) \
				or not rebuilt.submit_battle_result(battle_record.result):
			return false
		return true
	var source_direction := "right" if entry.get("cardId") in ["q_fellow", "f_mission"] \
		else String(entry.get("direction")) if entry.get("cardId") in [
			"q_sword_3", "realm_guardian", "thread_ab_village_3", "thread_sword_tomb_2"] else "left"
	var combat_command := String(entry.get("direction", ""))
	if String(entry.get("cardId", "")).begins_with("encounter_card_"):
		var offer: Dictionary = rebuilt._battle_gateway.offer_from_state(rebuilt.state)
		if offer.is_empty():
			return false
		source_direction = String(offer.get("originDirection", ""))
		combat_command = "left"
	if rebuilt.state.get("phase") not in ["COMBAT_HANDOFF", "FIRST_SESSION_ROUTE_PENDING", "QUEST_PENDING", "NORMAL_PENDING", "THREAD_PENDING", "FACTION_PENDING"] \
			or entry.get("cardId") != rebuilt.state.get("currentCardId") \
			or entry.get("direction") != source_direction \
			or battle_record.get("decisionIndex") != entry.get("decisionIndex") \
			or not battle_record.get("result") is Dictionary \
			or battle_record.result.get("outcome") != entry.get("combatOutcome") \
			or not rebuilt.choose(combat_command, rebuilt.issue_choice_token()) \
			or not rebuilt.choose(String(battle_record.get("warningDirection", "")), rebuilt.issue_choice_token()) \
			or not rebuilt.submit_battle_result(battle_record.result):
		_mark_source_failure(rebuilt._content)
		_mark_battle_return_failure(rebuilt._battle_return_flow)
		_mark_battle_return_failure(rebuilt._battle_gateway)
		return false
	return true


func _restore_encounter_actions(saved: Dictionary, rebuilt: RefCounted) -> bool:
	var encounter_actions: Variant = saved.get("encounterActionHistory", [])
	if not encounter_actions is Array or encounter_actions.size() > 2:
		return false
	if saved.has("pendingRealmGateCard") and rebuilt.state.get("phase") == "FLOW_PENDING" \
			and not rebuilt.resume_flow():
		return false
	if not encounter_actions.is_empty():
		var pending_value: Variant = saved.get("pendingWarning", saved.get("pendingBattle", {}))
		if not pending_value is Dictionary:
			return false
		var saved_pending: Dictionary = pending_value
		if saved_pending.get("sourceContentHash") != rebuilt._battle_gateway.source_content_hash():
			if _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
			return false
	for index in range(encounter_actions.size()):
		var action: Variant = encounter_actions[index]
		if rebuilt.state.get("phase") == "FLOW_PENDING" and (saved.get("currentCardId") in ["q_whiteFox_3", "q_sword_3", "q_fellow", "f_mission", "ds_female_bandit", "realm_guardian", "n_hunt", "ar_boss", "thread_ab_village_3", "thread_sword_tomb_2"] \
				or saved.has("pendingCadenceCard") or saved.has("pendingFactionCard")) \
				and not rebuilt.resume_flow():
			return false
		# The first history value is the source card's origin direction, not
		# the encounter offer's accept command. Accepted offers always use left.
		var command := String(action)
		if index == 0 and rebuilt.state.get("phase") == "COMBAT_HANDOFF":
			var offer: Dictionary = rebuilt._battle_gateway.offer_from_state(rebuilt.state)
			if offer.is_empty() or action != offer.get("originDirection"):
				return false
			command = "left"
		if not action is String or not rebuilt.choose(command, rebuilt.issue_choice_token()):
			_mark_source_failure(rebuilt._content)
			_mark_battle_return_failure(rebuilt._battle_gateway)
			return false
	return true


func _replay_dungeon_action(rebuilt: RefCounted, action: Variant) -> bool:
	var run: Variant = rebuilt.state.get("dungeonRun")
	if not run is Dictionary:
		return false
	if not action is Dictionary or action.get("kind") != "abandon" \
			or action.get("decisionIndex") != rebuilt.state.get("runClock", {}).get("decisionIndex") \
			or action.get("sessionId") != run.get("sessionId") \
			or not rebuilt.abandon_dungeon(rebuilt.issue_choice_token()):
		return false
	var actual: Variant = JSON.parse_string(JSON.stringify(
		rebuilt.state.get("dungeonActionHistory", []).back()))
	return actual == action


func _replay_equipment_actions(saved: Dictionary, rebuilt: RefCounted,
		cursor: int) -> int:
	var actions: Array = saved.get("treasureEquipmentHistory", [])
	while cursor < actions.size():
		var event: Variant = actions[cursor]
		if not event is Dictionary or event.get("version") != 1 \
				or not event.get("decisionIndex") is int and not event.get(
					"decisionIndex") is float \
				or not event.get("instanceId") is String \
				or not event.get("cardId") is String \
				or event.get("operation") not in ["equip", "unequip"] \
				or event.get("slot") not in TreasureAcquisition.SLOTS:
			return -1
		var current_index := int(rebuilt.state.get("runClock", {}).get(
			"decisionIndex", -1))
		var event_index := int(event.decisionIndex)
		if event_index > current_index:
			return cursor
		if event_index < current_index:
			return -1
		# A shop's result card must be chosen before equipment can be changed on
		# the next normal card, even though both states share this decision index.
		if rebuilt.state.get("phase") == "VENDOR_RESULT_PENDING":
			return cursor
		if rebuilt.state.get("phase") == "FLOW_PENDING" and not rebuilt.resume_flow():
			return -1
		if rebuilt.state.get("phase") not in ["NORMAL_PENDING", "THREAD_PENDING"] \
				or rebuilt.state.get("phase") != event.get("phase") \
				or rebuilt.state.get("currentCardId") != event.cardId:
			return -1
		if not rebuilt.change_treasure_equipment(String(event.operation),
				String(event.instanceId), String(event.slot),
				rebuilt.issue_choice_token()):
			return -1
		if JSON.parse_string(JSON.stringify(rebuilt.state.get(
				"treasureEquipmentHistory", []).back())) != event:
			return -1
		cursor += 1
	return cursor


func _restore_rebirth(saved: Dictionary, record: Dictionary) -> bool:
	# The archived death must be source-replayable before it can authorize any
	# new-life projection. A valid envelope alone only proves intact bytes.
	if saved.has("worldContinuityActivationIndex") and (
			not _valid_integer(saved.worldContinuityActivationIndex) \
			or int(saved.worldContinuityActivationIndex) < 0 \
			or int(saved.worldContinuityActivationIndex) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1)) \
			or not saved.get("worldContinuityState") is Dictionary \
			or not _pinned_source_matches("npcs:core", String(saved.get(
				"worldContinuitySourceSha", "")))):
		return false
	if saved.has("worldPulseState") and (
			not WorldPulse.valid(saved.worldPulseState) \
			or int(saved.worldPulseState.get("activationIndex", -1)) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1))):
		return false
	if saved.has("factionEventState") and (
			not _faction_marker_source_matches(saved) \
			or not _faction_events.valid(saved) \
			or int(saved.factionEventState.get("activationIndex", -1)) > int(saved.get(
				"runClock", {}).get("decisionIndex", -1))):
		return false
	if not _restore_flow_sources(saved.get("noncombatFlow", {}), saved):
		return false
	var legacy_hint_life: bool = int(saved.get("lifeCount", 0)) > 0 \
		and saved.get("heavensHintState") is Dictionary \
		and saved.get("heavensHintState", {}).get("lifeCount") == 0
	var journal: Variant = saved.get("lifeJournal")
	if not journal is Array or journal.is_empty() or not journal.back() is Dictionary:
		return false
	var last: Dictionary = journal.back()
	if not last.get("terminalState") is Dictionary \
			or last.get("deathDirection") not in ["left", "right"]:
		return false
	var archived: Dictionary = last["terminalState"].duplicate(true)
	if journal.size() > 1:
		archived["lifeJournal"] = journal.slice(0, journal.size() - 1)
	var prior = get_script().new(_registry, ReplaySnapshotStore.new(archived),
		_slot_id, _content)
	prior._normal_roll_override = _normal_roll_override
	prior._npc_activation_index = _npc_activation_index
	prior._npc_general_activation_index = _npc_general_activation_index
	prior._npc_encounter_flow.roll_override_sequence = \
		_npc_encounter_flow.roll_override_sequence.duplicate(true)
	prior._npc_cross_activation_index = _npc_cross_activation_index
	prior._npc_cross_dynamic_activation_index = _npc_cross_dynamic_activation_index
	prior._npc_cross_flow.roll_override_sequence = \
		_npc_cross_flow.roll_override_sequence.duplicate(true)
	prior._market_flow.roll_override = _market_flow.roll_override
	prior._destiny_wheel_flow.roll_override = _destiny_wheel_flow.roll_override
	prior._ripple_flow.roll_override = _ripple_flow.roll_override
	prior._hint_flow.roll_override = _hint_flow.roll_override
	if not prior.restore():
		_mark_source_failure(_content)
		return false
	var inheritance_version: Variant = saved.get("rebirthInheritanceVersion", 0)
	if not (inheritance_version is int or inheritance_version is float) \
			or float(inheritance_version) != float(int(inheritance_version)) \
			or int(inheritance_version) not in [0, 1, 2, 3, 4, 5]:
		return false
	var expected: Dictionary = _rebirth_flow.voluntary_new_life(prior.state,
		prior.get_current_card(), _slot_id, int(inheritance_version)) \
		if last.get("voluntaryReincarnation") == true else (
		_rebirth_flow.ending_new_life(prior.state, prior.get_current_card(),
			String(last["deathDirection"]), _slot_id, int(inheritance_version)) \
		if last.get("endingReincarnation") == true else (
		_rebirth_flow.upper_new_life(prior.state, prior.get_current_card(),
			String(last["deathDirection"]), _slot_id, int(inheritance_version)) \
		if last.get("upperReincarnation") == true else _rebirth_flow.new_life(
			prior.state, prior.get_current_card(), String(last["deathDirection"]),
			_slot_id, int(inheritance_version))))
	if expected.is_empty():
		_mark_source_failure(_content)
		return false
	if not saved.has("worldContinuityActivationIndex"):
		expected.erase("worldContinuityState")
		expected.erase("worldContinuityActivationIndex")
		expected.erase("worldContinuitySourceSha")
	if not saved.has("worldPulseState"):
		expected.erase("worldPulseState")
	if not saved.has("factionEventState"):
		expected.erase("factionEventState")
		if not saved.has("factionProgress"):
			expected.erase("factionProgress")
	var selected_path: Variant = saved.get("path")
	if selected_path != null:
		if not selected_path is String:
			return false
		expected = _rebirth_flow.select_path(expected, String(selected_path))
	var path_bundle := {}
	if selected_path != null:
		path_bundle = _rebirth_path_bundle(String(selected_path))
		if path_bundle.is_empty():
			return false
	expected = _replay_lineage_actions(saved, expected, 0)
	if expected.is_empty():
		return false
	var saved_mentor_arc: Variant = saved.get("mentorArcState")
	var rebirth_mentor_version := int(saved_mentor_arc.get("version", 0)) \
		if saved_mentor_arc is Dictionary else 0
	var faction_new_activation := int(saved.get("factionCollectionNewActivationIndex", 0))
	if saved.has("factionCollectionNewActivationIndex"):
		if not _valid_integer(saved.factionCollectionNewActivationIndex) \
				or faction_new_activation < 1 \
				or faction_new_activation > int(saved.get("runClock", {}).get(
					"decisionIndex", -1)):
			return false
		expected["factionCollectionNewActivationIndex"] = faction_new_activation
	elif rebirth_mentor_version in [1, 2, 3] \
			and saved.has("factionEventState"):
		faction_new_activation = int(saved.get("runClock", {}).get(
			"decisionIndex", 0)) + 1
	if rebirth_mentor_version in [1, 2, 3] \
			and expected.get("mentorArcState") is Dictionary:
		var legacy_arc: Dictionary = expected.mentorArcState.duplicate(true)
		legacy_arc.version = rebirth_mentor_version
		if rebirth_mentor_version < 3:
			legacy_arc.erase("heirActivationIndex")
		legacy_arc.erase("climaxActivationIndex")
		legacy_arc.erase("pendingClimaxes")
		legacy_arc.erase("climaxTriggered")
		expected.mentorArcState = legacy_arc
	var replay_token: int = prior._choice_token + 1 + (1 if selected_path != null else 0)
	var settled: Dictionary = {}
	if saved.get("phase") != "REBIRTH_PENDING":
		var history: Variant = saved.get("replayHistory")
		if not history is Array or history.is_empty() \
				or not saved.get("choiceHistory") is Array \
				or history.slice(maxi(0, history.size() - 30)) \
					!= saved["choiceHistory"] \
				or not history[0] is Dictionary \
				or history[0].get("cardId") != "rebirth_boon" \
				or history[0].get("direction") not in ["left", "right", "down"]:
			return false
		var projected = get_script().new(_registry, null, _slot_id, _content)
		projected._legacy_mentor_stage_replay = rebirth_mentor_version == 1
		projected._legacy_mentor_heir_replay = rebirth_mentor_version in [1, 2]
		projected._legacy_mentor_climax_replay = rebirth_mentor_version in [1, 2, 3]
		projected._legacy_faction_collection_replay = faction_new_activation > 0
		projected._faction_collection_new_activation_index = faction_new_activation
		if rebirth_mentor_version in [1, 2, 3, 4]:
			var initial_legacy_mentor: Dictionary = MentorFlow.initial_state()
			var saved_heir_index := int(saved_mentor_arc.get("heirActivationIndex", 0))
			var saved_climax_index := int(saved_mentor_arc.get("climaxActivationIndex", 0))
			projected._mentor_heir_activation_index = saved_heir_index
			projected._mentor_climax_activation_index = saved_climax_index
			initial_legacy_mentor.version = rebirth_mentor_version
			if rebirth_mentor_version < 3 or saved_heir_index > 0:
				initial_legacy_mentor.version = mini(rebirth_mentor_version, 2)
				initial_legacy_mentor.erase("heirActivationIndex")
			if rebirth_mentor_version < 4 or saved_climax_index > 0:
				initial_legacy_mentor.version = mini(int(initial_legacy_mentor.version), 3)
				initial_legacy_mentor.erase("climaxActivationIndex")
				initial_legacy_mentor.erase("pendingClimaxes")
				initial_legacy_mentor.erase("climaxTriggered")
			projected._mentor_state = initial_legacy_mentor
		projected._last_lesson_vendor.legacy_service_replay = _saved_legacy_lesson_session(saved)
		projected._replaying_history = true
		projected._path_skill_activation_index = int(saved.get(
			"pathSkillActivationIndex", int(saved.get("runClock", {}).get(
				"decisionIndex", 0)) + (2 if saved.get("phase") in [
					"WARNING_PENDING", "BATTLE_PENDING"] else 1)))
		projected._passive_regen_extension_replay_marker_present = saved.has(
			"passiveRegenExtensionIndex")
		projected._passive_regen_extension_activation_index = int(saved.get(
			"passiveRegenExtensionIndex", int(saved.get("runClock", {}).get(
				"decisionIndex", 0)) + 1))
		projected._early_avoid_activation_index = int(saved.get(
			"earlyAvoidActivationIndex", int(saved.get("runClock", {}).get(
				"decisionIndex", 0)) + 1))
		projected._world_continuity_activation_index = int(saved.get(
			"worldContinuityActivationIndex", int(saved.get(
				"runClock", {}).get("decisionIndex", 0)) + 1))
		projected._world_pulse_activation_index = int(saved.get("worldPulseState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._faction_activation_index = int(saved.get("factionEventState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._cadence_activation_index = int(saved.get("encounterCadence", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._cadence_high_upgrade_index = int(saved.get("encounterCadence", {}).get(
			"higherRealmActivationIndex", int(saved.get(
				"runClock", {}).get("decisionIndex", 0)) + 1))
		projected._npc_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._npc_general_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
			"generalActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._npc_encounter_flow.roll_override_sequence = saved.get(
			"npcEncounterScheduling", {}).get("rollTape", []).duplicate(true)
		projected._npc_cross_activation_index = int(saved.get("npcCrossState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._npc_cross_dynamic_activation_index = int(saved.get("npcCrossState", {}).get(
			"dynamicActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._npc_cross_flow.roll_override_sequence = saved.get(
			"npcCrossState", {}).get("rollTape", []).duplicate(true)
		projected._combat_scheduling_activation_index = int(saved.get("combatScheduling", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._scene_activation_index = int(saved.get("sceneLayerState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._echo_activation_index = int(saved.get("choiceEchoState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._ally_activation_index = int(saved.get("allyArcState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._companion_arc_activation_index = int(saved.get(
			"companionArcState", {}).get("activationIndex", int(saved.get(
				"runClock", {}).get("decisionIndex", 0)) + 1))
		projected._seer_activation_index = int(saved.get("seerArcState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._surfacing_activation_index = int(saved.get("narrativeSurfacingState", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._companion_activation_index = int(saved.get("companionProgress", {}).get(
			"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
		projected._companion_milestone_activation_index = int(saved.get(
			"companionProgress", {}).get("milestoneActivationIndex",
			-1 if saved.has("companionProgress") else 0))
		projected._narrative_admission_activation_index = int(saved.get(
			"normalNarrativeAdmission", {}).get("activationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
		var thread_marker: Dictionary = saved.get("storyThreadState", {})
		var next_activation := int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1
		projected._story_thread_flow.activation_index = int(thread_marker.get(
			"activationIndex", next_activation))
		projected._story_thread_flow.upgrade_index = int(thread_marker.get(
			"upgradeIndex", next_activation))
		projected._story_thread_flow.village_activation_index = int(thread_marker.get(
			"villageActivationIndex", next_activation))
		projected._story_thread_flow.sword_activation_index = int(thread_marker.get(
			"swordActivationIndex", next_activation))
		projected._story_thread_flow.mist_activation_index = int(thread_marker.get(
			"mistActivationIndex", next_activation))
		projected._story_thread_flow.higher_activation_index = int(thread_marker.get(
			"higherActivationIndex", next_activation))
		projected._story_thread_flow.last_lesson_activation_index = int(thread_marker.get(
			"lastLessonActivationIndex", next_activation))
		projected._normal_draw_policy.legacy_narrative_admission_replay = \
			not saved.has("normalNarrativeAdmission")
		projected.state = expected.duplicate(true)
		projected._install_rebirth_path_bundle(path_bundle)
		projected._current_card_id = "rebirth_boon"
		projected._choice_token = replay_token
		projected._market_flow.ghost_plan_activation_index = 1
		projected._trade_route_flow.activation_index = 1
		projected._normal_roll_override = _normal_roll_override
		projected._market_flow.roll_override = _market_flow.roll_override
		projected._market_flow.rebirth_archive_verified = true
		projected._ghost_vendor_flow.trust_rebirth_archive()
		projected._destiny_wheel_flow.roll_override = _destiny_wheel_flow.roll_override
		projected._ripple_flow.roll_override = _ripple_flow.roll_override
		projected._hint_flow.roll_override = _hint_flow.roll_override
		projected._hint_flow.legacy_life_count = legacy_hint_life
		projected._trade_route_flow.legacy_initial_trusted = \
			saved.get("tradeRouteLegacyUnverified") != true
		projected._legacy_market_replay_initial_seed = int(saved.get(
			"marketRngState", {}).get("initialSeed", 0))
		projected._legacy_wheel_replay_initial_seed = int(saved.get(
			"destinyWheelRngState", {}).get("initialSeed", 0))
		projected._legacy_ripple_replay_initial_seed = int(saved.get(
			"rippleRngState", {}).get("initialSeed", 0))
		projected._legacy_hint_replay_initial_seed = int(saved.get(
			"hintRngState", {}).get("initialSeed", 0))
		if not projected.choose(String(history[0]["direction"]), replay_token):
			return false
		projected.state = _replay_lineage_actions(saved, projected.state,
			int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
		if projected.state.is_empty():
			return false
		if String(history[0]["direction"]) == "down" \
				and (saved.get("phase") in ["FLOW_PENDING", "NORMAL_PENDING"] \
					or history.size() > 1):
			var targets: Variant = saved.get("campTargetHistory")
			if not targets is Array or targets.size() != 1 \
					or not targets[0] is Dictionary:
				return false
			var target: Dictionary = targets[0]
			if target.get("action") == "cancel":
				if not projected.cancel_camp_target(projected.issue_choice_token()):
					return false
			elif target.get("action") == "remove":
				if not projected.resolve_camp_target(int(target.get("index", -1)),
						String(target.get("cardId", "")), projected.issue_choice_token()):
					return false
			else:
				return false
			projected.state = _replay_lineage_actions(saved, projected.state,
				int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
			if projected.state.is_empty():
				return false
		if history.size() > 1 or saved.get("phase") in [
				"NORMAL_PENDING", "MILESTONE_PENDING", "KARMA_PENDING",
				"MARKET_PENDING", "THREAD_PENDING", "VENDOR_OPEN", "VENDOR_RESULT_PENDING",
			"QUEST_PENDING", "MENTOR_PENDING", "NARRATIVE_RESULT_PENDING",
			"HINT_PENDING", "DESTINY_WHEEL_PENDING", "GHOST_DEBT_PENDING",
			"COMBAT_HANDOFF", "WARNING_PENDING", "BATTLE_PENDING", "BATTLE_RESULT_PENDING", "ENDING_PENDING", "UPPER_REALM_PENDING",
			"NPC_PENDING", "NPC_CROSS_PENDING", "LOCATION_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING"]:
			var normal: Variant = saved.get("normalFlow")
			if projected.state.get("phase") != "FLOW_PENDING" \
					or normal != null and not normal is Dictionary:
				return false
			if normal is Dictionary:
				if not normal.get("draws") is Array:
					return false
				projected._normal_replay_seed = int(normal.get("initialSeed", 0))
				projected._normal_replay_draws = normal["draws"].duplicate(true)
				projected._normal_replay_priority_checks = normal.get(
					"priorityChecks", []).duplicate(true)
				projected._normal_replay_shop_entries = normal.get(
					"shopEntries", []).duplicate(true)
			for index in range(1, history.size()):
				var entry: Variant = history[index]
				projected.state = _replay_lineage_actions(saved, projected.state,
					int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
				if projected.state.is_empty():
					return false
				if not projected._replay_deferred_last_lesson_loadout(saved):
					return false
				if not entry is Dictionary or not entry.get("cardId") is String \
						or not entry.get("direction") is String:
					return false
				if projected.state.get("phase") == "FLOW_PENDING" \
						and not projected.resume_flow():
					return false
				projected.state = _replay_lineage_actions(saved, projected.state,
					int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
				if projected.state.is_empty():
					return false
				if entry.has("combatOutcome"):
					if not _restore_battle_record(saved, entry, projected):
						return false
					continue
				var current: Dictionary = projected.get_current_card()
				if projected.state.get("phase") not in [
						"NORMAL_PENDING", "MILESTONE_PENDING", "KARMA_PENDING",
						"MARKET_PENDING", "THREAD_PENDING", "VENDOR_RESULT_PENDING", "QUEST_PENDING",
					"MENTOR_PENDING", "NARRATIVE_RESULT_PENDING",
					"HINT_PENDING", "DESTINY_WHEEL_PENDING",
					"GHOST_DEBT_PENDING", "COMBAT_HANDOFF", "BATTLE_RESULT_PENDING", "ENDING_PENDING", "UPPER_REALM_PENDING",
					"NPC_PENDING", "NPC_CROSS_PENDING", "LOCATION_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING"] \
						or current.get("id") != entry["cardId"] \
						or not projected.choose(String(entry["direction"]),
							projected.issue_choice_token()):
					return false
				if entry.get("cardId") in [MarketFlow.BAZAAR_ID,
						MarketFlow.GHOST_ID] \
						and entry.get("direction") == "left":
					if not projected._replay_vendor_actions(saved) \
							or not projected.close_vendor(projected.issue_choice_token()):
						return false
				if entry.get("cardId") == LastLessonVendor.ENTRY_ID \
						and entry.get("direction") == "left":
					if not projected._replay_vendor_actions(saved) \
							or not projected.close_vendor(projected.issue_choice_token()):
						return false
			projected.state = _replay_lineage_actions(saved, projected.state,
				int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
			if projected.state.is_empty() or not _restore_encounter_actions(saved,
				projected):
				return false
			if saved.get("phase") in ["NORMAL_PENDING", "MILESTONE_PENDING",
					"KARMA_PENDING", "MARKET_PENDING", "THREAD_PENDING", "VENDOR_OPEN",
					"QUEST_PENDING", "MENTOR_PENDING", "HINT_PENDING",
					"GHOST_DEBT_PENDING", "COMBAT_HANDOFF", "NPC_PENDING", "NPC_CROSS_PENDING",
					"LOCATION_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING"] \
					and projected.state.get("phase") == "FLOW_PENDING" \
					and not projected.resume_flow():
				return false
			if saved.get("phase") == "VENDOR_OPEN":
				var vendor_id := String(saved.get("marketState", {}).get(
					"activeSession", {}).get("vendorId", ""))
				var lesson: bool = saved.get("marketState", {}).get(
					"activeSession", {}).get("entryCardId") == LastLessonVendor.ENTRY_ID
				var entry_id := LastLessonVendor.ENTRY_ID if lesson else \
					MarketFlow.GHOST_ID if vendor_id == "ghost_market" \
					else MarketFlow.BAZAAR_ID if vendor_id == "public_bazaar" else ""
				if entry_id.is_empty() or projected.state.get("phase") != (
					"THREAD_PENDING" if lesson else "MARKET_PENDING") \
						or projected.get_current_card().get("id") != entry_id \
						or not projected.choose("left", projected.issue_choice_token()) \
						or not projected._replay_vendor_actions(saved):
					return false
			if not projected._replay_deferred_last_lesson_loadout(saved):
				return false
			projected.state = _replay_lineage_actions(saved, projected.state,
				int(projected.state.get("runClock", {}).get("decisionIndex", -1)))
			if projected.state.is_empty():
				return false
		expected = projected.state.duplicate(true)
		settled = {"token": projected._choice_token,
			"mentor": projected._mentor_state.duplicate(true),
			"cardCount": projected._flow_card_count,
			"starvation": projected._normal_starvation.duplicate(true),
			"marketActivation": projected._market_flow.ghost_plan_activation_index,
			"tradeActivation": projected._trade_route_flow.activation_index}
	# v1 dynamic cross snapshots predate per-card issuance. Replay still builds
	# the current ledger; compare the old snapshot against its exact old shape.
	var saved_cross: Dictionary = saved.get("npcCrossState", {})
	if saved_cross.get("version") == 1 \
			and saved_cross.has("dynamicActivationIndex") \
			and not saved_cross.has("issuedCards") \
			and expected.get("npcCrossState") is Dictionary:
		expected.npcCrossState.version = 1
		expected.npcCrossState.erase("issuedCards")
	if expected.is_empty() or JSON.parse_string(JSON.stringify(expected)) != saved:
		return false
	_store_revision = int(record.get("revision", -1))
	_current_card_id = String(saved.get("currentCardId", "rebirth_boon"))
	_choice_token = int(settled.get("token", replay_token))
	_mentor_state = settled.get("mentor", _mentor_state).duplicate(true)
	_flow_card_count = int(settled.get("cardCount", 0))
	_normal_starvation = settled.get("starvation", {}).duplicate(true)
	_market_flow.ghost_plan_activation_index = int(settled.get("marketActivation", 1))
	_market_flow.rebirth_archive_verified = true
	_ghost_vendor_flow.trust_rebirth_archive()
	_trade_route_flow.activation_index = int(settled.get("tradeActivation", 1))
	_trade_route_flow.legacy_initial_trusted = \
		saved.get("tradeRouteLegacyUnverified") != true
	_hint_flow.legacy_life_count = legacy_hint_life
	_cadence_activation_index = int(saved.get("encounterCadence", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_cadence_high_upgrade_index = int(saved.get("encounterCadence", {}).get(
		"higherRealmActivationIndex", int(saved.get(
			"runClock", {}).get("decisionIndex", 0)) + 1))
	_path_skill_activation_index = int(saved.get("pathSkillActivationIndex",
		int(saved.get("runClock", {}).get("decisionIndex", 0)) + (
			2 if saved.get("phase") in ["WARNING_PENDING", "BATTLE_PENDING"] else 1)))
	_passive_regen_extension_activation_index = int(saved.get(
		"passiveRegenExtensionIndex", int(saved.get("runClock", {}).get(
			"decisionIndex", 0)) + 1))
	_early_avoid_activation_index = int(saved.get("earlyAvoidActivationIndex",
		int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_world_continuity_activation_index = int(saved.get(
		"worldContinuityActivationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_world_pulse_activation_index = int(saved.get("worldPulseState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_faction_activation_index = int(saved.get("factionEventState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_legacy_faction_collection_replay = faction_new_activation > 0
	_faction_collection_new_activation_index = faction_new_activation
	_npc_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_npc_general_activation_index = int(saved.get("npcEncounterScheduling", {}).get(
		"generalActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_npc_encounter_flow.roll_override_sequence = saved.get(
		"npcEncounterScheduling", {}).get("rollTape", []).duplicate(true)
	_npc_cross_activation_index = int(saved.get("npcCrossState", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_npc_cross_dynamic_activation_index = int(saved.get("npcCrossState", {}).get(
		"dynamicActivationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_npc_cross_flow.roll_override_sequence = saved.get(
		"npcCrossState", {}).get("rollTape", []).duplicate(true)
	_combat_scheduling_activation_index = int(saved.get("combatScheduling", {}).get(
		"activationIndex", int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_scene_activation_index = int(saved.get("sceneLayerState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_echo_activation_index = int(saved.get("choiceEchoState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_ally_activation_index = int(saved.get("allyArcState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_companion_arc_activation_index = int(saved.get("companionArcState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_seer_activation_index = int(saved.get("seerArcState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_surfacing_activation_index = int(saved.get("narrativeSurfacingState", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_companion_activation_index = int(saved.get("companionProgress", {}).get(
		"activationIndex", 0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	_companion_milestone_activation_index = int(saved.get(
		"companionProgress", {}).get("milestoneActivationIndex",
		-1 if saved.has("companionProgress") else 0))
	_narrative_admission_activation_index = int(saved.get(
		"normalNarrativeAdmission", {}).get("activationIndex",
		0 if saved.get("phase") == "REBIRTH_PENDING" else \
			int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1))
	var thread_marker: Dictionary = saved.get("storyThreadState", {})
	var next_activation := int(saved.get("runClock", {}).get("decisionIndex", 0)) + 1
	_story_thread_flow.activation_index = int(thread_marker.get("activationIndex", next_activation))
	_story_thread_flow.upgrade_index = int(thread_marker.get("upgradeIndex", next_activation))
	_story_thread_flow.village_activation_index = int(thread_marker.get("villageActivationIndex", next_activation))
	_story_thread_flow.sword_activation_index = int(thread_marker.get("swordActivationIndex", next_activation))
	_story_thread_flow.mist_activation_index = int(thread_marker.get("mistActivationIndex", next_activation))
	_story_thread_flow.higher_activation_index = int(thread_marker.get("higherActivationIndex", next_activation))
	_story_thread_flow.last_lesson_activation_index = int(thread_marker.get("lastLessonActivationIndex", next_activation))
	if not path_bundle.is_empty():
		_install_rebirth_path_bundle(path_bundle)
	state = saved.duplicate(true)
	changed.emit({"type": "RESTORED", "cardId": _current_card_id})
	return true


func _rebirth_path_bundle(path_id: String) -> Dictionary:
	var paths: Variant = _content.read_module("config:paths")
	var qi: Variant = _content.read_module("cards:qi")
	var realms: Variant = _content.read_module("config:realms")
	if not paths is Dictionary or not qi is Dictionary or not realms is Dictionary:
		return {}
	var definition: Dictionary = paths.get("paths", {}).get(path_id, {})
	var cards: Array = qi.get("cards", [])
	var realm: Dictionary = realms.get("realms", {}).get("qi", {})
	if definition.is_empty() or cards.is_empty() or realm.is_empty():
		return {}
	var card_map := {}
	for card in cards:
		if not card is Dictionary or not card.get("id") is String:
			return {}
		card_map[card["id"]] = card
	return {"cards": card_map, "path": definition,
		"cultivationMax": int(realm.get("cultivationThreshold", 100))}


func _install_rebirth_path_bundle(bundle: Dictionary) -> void:
	_cards = bundle["cards"]
	_path_definition = bundle["path"]
	_cultivation_max = int(bundle["cultivationMax"])


func _mark_source_failure(repository: RefCounted) -> void:
	if _store == null or not _store.has_method("mark_source_mismatch") \
			or repository == null or not repository.has_method("errors"):
		return
	for error in repository.errors():
		var detail := String(error)
		if detail.begins_with("Source SHA mismatch:") \
				or detail.begins_with("Missing source copy:") \
				or detail.begins_with("Invalid source JSON:") \
				or detail.begins_with("Missing or invalid source manifest") \
				or detail.begins_with("Invalid or duplicate source manifest path:"):
			_store.mark_source_mismatch()
			return

func _mark_ripple_failure(flow: RefCounted) -> void:
	if _store == null or flow == null or String(flow.last_error).is_empty():
		return
	if flow.source_missing() and _store.has_method("mark_source_unavailable"):
		_store.mark_source_unavailable()
	elif _store.has_method("mark_source_mismatch"):
		_store.mark_source_mismatch()


func _mark_thread_failure(flow: RefCounted) -> void:
	if _store == null or flow == null or String(flow.last_error).is_empty():
		return
	if flow.source_missing() and _store.has_method("mark_source_unavailable"):
		_store.mark_source_unavailable()
	elif _store.has_method("mark_source_mismatch"):
		_store.mark_source_mismatch()


func _gateway_source_unavailable(repository: RefCounted) -> bool:
	for source_path_value in BattleGateway.CONTENT_FILES:
		var source_path := String(source_path_value)
		var module_id := source_path.trim_prefix("data/").trim_suffix(".json").replace("/", ":")
		if repository.module_path(module_id).is_empty() \
				or not FileAccess.file_exists(ContentRepository.CONTENT_ROOT + source_path):
			return true
	return false


func _pinned_source_matches(module_id: String, pinned_sha: String) -> bool:
	var current_sha: String = _content.source_sha256(module_id)
	if current_sha == pinned_sha:
		return true
	var source_path: String = _content.module_path(module_id)
	var source_missing := source_path.is_empty() or not FileAccess.file_exists(
		ContentRepository.CONTENT_ROOT + source_path)
	if source_missing and _store != null and _store.has_method("mark_source_unavailable"):
		_store.mark_source_unavailable()
	elif _store != null and _store.has_method("mark_source_mismatch"):
		_store.mark_source_mismatch()
	return false


func _faction_marker_source_matches(saved: Dictionary) -> bool:
	var marker_value: Variant = saved.get("factionEventState")
	if not marker_value is Dictionary or not marker_value.get("sourceSha") is String \
			or String(marker_value.sourceSha).length() != 64:
		return true # Structural validation reports malformed markers separately.
	return _pinned_source_matches("world:factions", marker_value.sourceSha)


func get_current_card() -> Dictionary:
	if not state.get("active", false):
		return {}
	if state.get("phase") == "COMBAT_HANDOFF" and state.has("pendingCadenceCard"):
		var invitation: Dictionary = _cadence_flow.card(state)
		if invitation.is_empty():
			_mark_battle_return_failure(_cadence_flow)
		return invitation
	if state.get("phase") == "FIRST_SESSION_ROUTE_PENDING":
		var route_card: Dictionary = _first_session_route.card(state)
		if route_card.is_empty():
			_mark_battle_return_failure(_first_session_route)
		return route_card
	if state.get("phase") == "BATTLE_RESULT_PENDING":
		return _battle_return_flow.card(state)
	if state.get("phase") == "ENDING_PENDING":
		return _realm_gate_flow.ending_card(state)
	if state.get("phase") == "UPPER_REALM_PENDING":
		return _realm_gate_flow.upper_card(state)
	if state.get("phase") == "DEATH_PENDING":
		return _death_flow.card(state)
	if state.get("phase") == "REBIRTH_PENDING":
		return _rebirth_flow.boon_card(state)
	if state.get("phase") == "WARNING_PENDING":
		var warning: Dictionary = _encounter_flow.warning_card(state)
		if warning.is_empty():
			_mark_battle_return_failure(_battle_gateway)
		return warning
	if state.get("phase") == "NARRATIVE_RESULT_PENDING":
		var result: Variant = state.get("pendingNarrativeResult")
		return result.duplicate(true) if result is Dictionary else {}
	if state.get("phase") == "INNER_DEMON_PENDING":
		return _realm_gate_flow.inner_demon_card(state)
	if state.get("phase") == "NPC_PENDING":
		return _npc_encounter_flow.card(state)
	if state.get("phase") == "NPC_CROSS_PENDING":
		return _npc_cross_flow.card(state)
	if state.get("phase") == "REALM_ARRIVAL_PENDING":
		var arrival: Dictionary = _realm_gate_flow.arrival_card(state)
		return arrival if JSON.parse_string(JSON.stringify(arrival)) == JSON.parse_string(
			JSON.stringify(state.get("pendingRealmArrivalCard"))) else {}
	if state.get("phase") == "MILESTONE_PENDING":
		var milestone: Variant = state.get("pendingMilestoneCard")
		return milestone.duplicate(true) if milestone is Dictionary else {}
	if state.get("phase") == "QUEST_PENDING":
		var quest_card: Variant = state.get("pendingQuestCard")
		return quest_card.duplicate(true) if quest_card is Dictionary else {}
	if state.get("phase") == "KARMA_PENDING":
		var karma_card: Variant = state.get("pendingKarmaCard")
		return karma_card.duplicate(true) if karma_card is Dictionary else {}
	if state.get("phase") == "EMERGENT_PENDING":
		var emergent_card: Variant = state.get("pendingEmergentCard")
		return emergent_card.duplicate(true) if emergent_card is Dictionary else {}
	if state.get("phase") == "MARKET_PENDING":
		var market_card: Variant = state.get("pendingMarketChoiceCard")
		return market_card.duplicate(true) if market_card is Dictionary else {}
	if state.get("phase") == "LICENSED_DELIVERY_PENDING":
		return _licensed_delivery.delivery_card(state)
	if state.get("phase") == "LICENSED_LOADOUT_PENDING":
		return _licensed_delivery.loadout_card(state)
	if state.get("phase") == "GHOST_DEBT_PENDING":
		return _ghost_debt_flow.due_card(state)
	if state.get("phase") == "RIPPLE_PENDING":
		var ripple_card: Variant = state.get("pendingRippleChoiceCard")
		return ripple_card.duplicate(true) if ripple_card is Dictionary else {}
	if state.get("phase") == "HINT_PENDING":
		var hint_card: Variant = state.get("pendingHintChoiceCard")
		return hint_card.duplicate(true) if hint_card is Dictionary else {}
	if state.get("phase") == "LOCATION_PENDING":
		return _scene_layer_flow.card(state)
	if state.get("phase") == "CHOICE_ECHO_PENDING":
		return _choice_echo_flow.card(state)
	if state.get("phase") == "ALLY_PENDING":
		return _ally_arc_flow.card(state)
	if state.get("phase") == "COMPANION_ARC_PENDING":
		return _companion_arc_flow.card(state)
	if state.get("phase") == "SEER_PENDING":
		return _seer_arc_flow.card(state)
	if state.get("phase") == "SURFACING_PENDING":
		return _narrative_surfacing.card(state)
	if state.get("phase") == "COMPANION_PENDING":
		return _companion_events.card(state)
	if state.get("phase") == "FACTION_PENDING":
		return _faction_events.card(state)
	if state.get("phase") == "THREAD_PENDING":
		return _story_thread_flow.card(state)
	if state.get("phase") == "NORMAL_PENDING":
		var normal_id := String(state.get("currentCardId", ""))
		if state.get("dungeonRun") is Dictionary:
			if state.dungeonRun.get("dungeonId") == NascentCaveFlow.DUNGEON_ID:
				return _nascent_cave_flow.node_card(state)
			if state.dungeonRun.get("dungeonId") == NascentRuinsFlow.DUNGEON_ID:
				return _nascent_ruins_flow.node_card(state)
			if HigherDungeonFlow.REALMS.has(state.dungeonRun.get("dungeonId")):
				return _higher_dungeon_flow.node_card(state)
			if state.dungeonRun.get("realm") == "golden":
				return _golden_dungeon_flow.node_card(state)
			return _foundation_dungeon_flow.node_card(state) if state.dungeonRun.get(
				"dungeonId") == FoundationDungeonFlow.DUNGEON_ID else \
				_cave_flow.node_card(state)
		if normal_id == "q_fellow":
			return _battle_gateway.fellow_source_card(state)
		if normal_id == "f_mission":
			return _battle_gateway.mission_source_card(state)
		return _normal_draw_policy.source_card(state, normal_id)
	if state.get("phase") == "CAMP_TARGET_PENDING" and state.get(
			"currentCardId") == "rebirth_boon":
		return _rebirth_flow.boon_card(state)
	if state.get("phase") == "CAMP_TARGET_PENDING" and state.get(
			"currentCardId") in ["q_shop", "f_shop", "g_shop"]:
		return _normal_draw_policy.source_card(state,
			String(state.get("currentCardId")))
	if state.get("phase") in ["CAMP_PENDING", "CAMP_TARGET_PENDING"]:
		return _camp_flow.card()
	if state.get("phase") == "SHOP_PENDING":
		return _normal_draw_policy.source_card(state, "q_market") if state.get(
			"currentCardId") == "q_market" else _regulated_catalog.card(state)
	if state.get("phase") == "VENDOR_OPEN":
		if _last_lesson_vendor_active():
			return _last_lesson_vendor.pending_card(state)
		return _ghost_vendor_flow.pending_card(state) if _ghost_vendor_active() else (
			_regulated_vendor.pending_card(state) if _regulated_vendor_active() \
			else _vendor_flow.pending_card(state))
	if state.get("phase") == "VENDOR_RESULT_PENDING":
		if _last_lesson_vendor_active():
			return _last_lesson_vendor.result_card(state)
		var vendor_result: Variant = state.get("pendingVendorResultCard")
		return vendor_result.duplicate(true) if vendor_result is Dictionary else {}
	if state.get("phase") == "MENTOR_PENDING":
		var mentor_card: Variant = state.get("pendingMentorCard")
		return mentor_card.duplicate(true) if mentor_card is Dictionary else {}
	if state.get("phase") == "DESTINY_WHEEL_PENDING":
		return _destiny_wheel_flow.card(state)
	var card: Dictionary = _cards.get(_current_card_id, {})
	return card.duplicate(true)


func issue_choice_token() -> int:
	if state.get("phase") == "FIRST_SESSION_ROUTE_PENDING":
		return _choice_token if not _first_session_route.card(state).is_empty() else 0
	if state.get("phase") == "BATTLE_RESULT_PENDING":
		return _choice_token if not _battle_return_flow.card(state).is_empty() else 0
	if state.get("phase") == "ENDING_PENDING":
		return _choice_token if not _realm_gate_flow.ending_card(state).is_empty() else 0
	if state.get("phase") == "UPPER_REALM_PENDING":
		return _choice_token if not _realm_gate_flow.upper_card(state).is_empty() else 0
	if state.get("phase") == "INNER_DEMON_PENDING":
		return _choice_token if not _realm_gate_flow.inner_demon_card(state).is_empty() else 0
	if state.get("phase") == "NPC_PENDING":
		return _choice_token if not _npc_encounter_flow.card(state).is_empty() else 0
	if state.get("phase") == "NPC_CROSS_PENDING":
		return _choice_token if not _npc_cross_flow.card(state).is_empty() else 0
	if state.get("phase") == "FACTION_PENDING":
		return _choice_token if not _faction_events.card(state).is_empty() else 0
	if state.get("phase") == "REALM_ARRIVAL_PENDING":
		return _choice_token if not get_current_card().is_empty() else 0
	if state.get("phase") == "DEATH_PENDING":
		return _choice_token if not _death_flow.card(state).is_empty() else 0
	if state.get("phase") == "REBIRTH_PENDING":
		for boon_direction in ["left", "right", "down"]:
			if _rebirth_flow.choice_available(state, boon_direction):
				return _choice_token
		return 0
	if state.get("phase") == "QUEST_PENDING":
		return _choice_token if _quest_flow.choice_available(state) else 0
	if state.get("phase") == "KARMA_PENDING":
		return _choice_token if _karma_flow.choice_available(state) else 0
	if state.get("phase") == "EMERGENT_PENDING":
		return _choice_token if state.get("currentCardId") == EmergentFlow.CARD_ID else 0
	if state.get("phase") == "MARKET_PENDING":
		return _choice_token if _market_flow.choice_available(state, "right") \
			or _market_flow.choice_available(state, "left") else 0
	if state.get("phase") == "RIPPLE_PENDING":
		return _choice_token if state.get("pendingRippleChoiceCard") is Dictionary else 0
	if state.get("phase") == "HINT_PENDING":
		return _choice_token if _hint_flow.choice_available(state, "left") \
			or _hint_flow.choice_available(state, "right") else 0
	if state.get("phase") == "LOCATION_PENDING":
		return _choice_token if not _scene_layer_flow.card(state).is_empty() else 0
	if state.get("phase") == "CHOICE_ECHO_PENDING":
		return _choice_token if not _choice_echo_flow.card(state).is_empty() else 0
	if state.get("phase") == "ALLY_PENDING":
		return _choice_token if not _ally_arc_flow.card(state).is_empty() else 0
	if state.get("phase") == "COMPANION_ARC_PENDING":
		return _choice_token if not _companion_arc_flow.card(state).is_empty() else 0
	if state.get("phase") == "SEER_PENDING":
		return _choice_token if not _seer_arc_flow.card(state).is_empty() else 0
	if state.get("phase") == "SURFACING_PENDING":
		return _choice_token if not _narrative_surfacing.card(state).is_empty() else 0
	if state.get("phase") == "COMPANION_PENDING":
		return _choice_token if not _companion_events.card(state).is_empty() else 0
	if state.get("phase") == "THREAD_PENDING":
		return _choice_token if _story_thread_flow.choice_available(state, "left") \
			or _story_thread_flow.choice_available(state, "right") else 0
	if state.get("phase") == "NORMAL_PENDING":
		var normal_card: Dictionary = get_current_card()
		if state.get("dungeonRun") is Dictionary \
				and state.dungeonRun.get("status") == "active" \
				and not normal_card.is_empty():
			return _choice_token
		for normal_direction in normal_card.get("choices", {}):
			if can_choose_direction(String(normal_direction)):
				return _choice_token
		return 0
	if state.get("phase") == "CAMP_PENDING":
		for camp_direction in ["left", "right", "down", "up"]:
			if _camp_flow.available(state, camp_direction):
				return _choice_token
		return 0
	if state.get("phase") == "SHOP_PENDING":
		return _choice_token if not get_current_card().is_empty() else 0
	if state.get("phase") == "LICENSED_DELIVERY_PENDING":
		return _choice_token if not get_current_card().is_empty() else 0
	if state.get("phase") == "LICENSED_LOADOUT_PENDING":
		return _choice_token if not get_current_card().is_empty() else 0
	if state.get("phase") == "GHOST_DEBT_PENDING":
		return _choice_token if _ghost_debt_flow.choice_available(state, "right") else 0
	if state.get("phase") == "CAMP_TARGET_PENDING":
		return _choice_token if not String(state.get("pendingCampAction", "")).is_empty() else 0
	if state.get("phase") in ["VENDOR_OPEN", "VENDOR_RESULT_PENDING"]:
		if _last_lesson_vendor_active():
			return _choice_token if _last_lesson_vendor.source_valid(state) else 0
		return _choice_token if (_ghost_vendor_flow.source_valid(state) \
			if _ghost_vendor_active() else (_regulated_vendor.source_valid(state) \
			if _regulated_vendor_active() else _vendor_flow.source_valid(state))) else 0
	if state.get("phase") == "MENTOR_PENDING":
		return _choice_token if MentorFlow.is_stage_card_id(String(
			state.get("currentCardId", ""))) else 0
	if state.get("phase") == "DESTINY_WHEEL_PENDING":
		return _choice_token if not _destiny_wheel_flow.card(state).is_empty() else 0
	if _last_lesson_loadout_pending() or _regulated_loadout_pending():
		return _choice_token
	return _choice_token if state.get("phase") in ["TUTORIAL", "STARTER_BOUNDARY",
		"COMBAT_HANDOFF", "WARNING_PENDING", "NARRATIVE_RESULT_PENDING",
		"MILESTONE_PENDING"] else 0


func choose(direction: String, expected_token: int) -> bool:
	var prior: Dictionary = state
	_projected_choice_markers.clear()
	var next_index := int(state.get("runClock", {}).get("decisionIndex", -1)) + 1
	var advances: bool = state.get("phase") not in ["WARNING_PENDING",
		"DESTINY_WHEEL_PENDING"] and not (state.get("phase") == "COMBAT_HANDOFF"
			and direction == "left")
	var projected := false
	if advances and not state.is_empty():
		if not state.has("pathSkillActivationIndex") \
				and next_index >= _path_skill_activation_index \
				or not state.has("earlyAvoidActivationIndex") \
				and next_index >= _early_avoid_activation_index:
			state = state.duplicate(true)
			projected = true
			if not state.has("pathSkillActivationIndex") \
					and next_index >= _path_skill_activation_index:
				state["pathSkillActivationIndex"] = _path_skill_activation_index
				_projected_choice_markers.append("pathSkillActivationIndex")
			if not state.has("earlyAvoidActivationIndex") \
					and next_index >= _early_avoid_activation_index:
				state["earlyAvoidActivationIndex"] = _early_avoid_activation_index
				_projected_choice_markers.append("earlyAvoidActivationIndex")
	var committed := _choose_internal(direction, expected_token)
	if not committed and projected:
		state = prior
	_projected_choice_markers.clear()
	return committed


func _choose_internal(direction: String, expected_token: int) -> bool:
	if state.get("phase") == "FIRST_SESSION_ROUTE_PENDING":
		if expected_token <= 0 or expected_token != _choice_token:
			return false
		if direction == "left" and state.get("currentCardId") == FirstSessionRoute.ROUTE_ID:
			return _commit_encounter_transition(_encounter_flow.accept(state), "ENCOUNTER_WARNING")
		if direction == "left" and state.get("currentCardId") == FirstSessionRoute.MARKET_ID:
			return _choose_shop(direction)
		if direction != "right":
			return false
		var route_base := state.duplicate(true)
		if not _normal_choice_policy._apply_passive_regen(route_base):
			return false
		return _commit_encounter_transition(_first_session_route.settle_right(route_base), "FIRST_SESSION_ROUTE_CHOSEN")
	if state.get("phase") == "BATTLE_RESULT_PENDING":
		return expected_token > 0 and expected_token == _choice_token \
			and _commit_encounter_transition(_battle_return_flow.dismiss(state, direction), "BATTLE_RESULT_ACKNOWLEDGED")
	if state.get("phase") == "ENDING_PENDING":
		if expected_token <= 0 or expected_token != _choice_token:
			return false
		var ending_card: Dictionary = _realm_gate_flow.ending_card(state)
		var choice: Dictionary = ending_card.get("choices", {}).get(direction, {})
		if choice.get("enterUpperRealm") == true:
			return _commit_encounter_transition(
				_realm_gate_flow.continue_after_ending(state), "UPPER_REALM_ENTERED")
		if choice.get("effects", {}).get("reincarnate") == true:
			return _commit_rebirth_candidate(_rebirth_flow.ending_new_life(
				state, ending_card, direction, _slot_id), direction)
		return false
	if state.get("phase") == "UPPER_REALM_PENDING":
		if expected_token <= 0 or expected_token != _choice_token:
			return false
		var upper_card: Dictionary = _realm_gate_flow.upper_card(state)
		if upper_card.get("choices", {}).get(direction, {}).get(
				"effects", {}).get("reincarnate") == true:
			return _commit_rebirth_candidate(_rebirth_flow.upper_new_life(state,
				upper_card, direction, _slot_id), direction)
		var upper_candidate: Dictionary = _realm_gate_flow.settle_upper(state, direction)
		if upper_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				upper_candidate):
			return false
		return _commit_encounter_transition(upper_candidate, "UPPER_REALM_CHOSEN")
	if state.get("phase") == "INNER_DEMON_PENDING":
		return expected_token > 0 and expected_token == _choice_token \
			and _commit_encounter_transition(_realm_gate_flow.settle_inner_demon(
				state, direction, _death_flow), "INNER_DEMON_CHOSEN")
	if state.get("phase") == "NPC_PENDING":
		return expected_token > 0 and expected_token == _choice_token \
			and _commit_encounter_transition(_npc_encounter_flow.settle(state, direction),
				"NPC_ENCOUNTER_CHOSEN")
	if state.get("phase") == "NPC_CROSS_PENDING":
		if expected_token <= 0 or expected_token != _choice_token:
			return false
		var cross_candidate: Dictionary = _npc_cross_flow.settle(state, direction)
		if cross_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				cross_candidate, int(cross_candidate.get("runClock", {}).get(
					"decisionIndex", -1))):
			return false
		return _commit_encounter_transition(cross_candidate, "NPC_CROSS_CHOSEN")
	if state.get("phase") == "REALM_ARRIVAL_PENDING":
		return expected_token > 0 and expected_token == _choice_token \
			and _commit_encounter_transition(_realm_gate_flow.settle_epiphany(state, direction),
				"REALM_EPIPHANY_CHOSEN")
	if not state.get("phase") in ["TUTORIAL", "STARTER_BOUNDARY",
			"DEATH_PENDING", "REBIRTH_PENDING", "INNER_DEMON_PENDING",
			"COMBAT_HANDOFF", "WARNING_PENDING", "NARRATIVE_RESULT_PENDING",
			"MILESTONE_PENDING", "QUEST_PENDING", "KARMA_PENDING", "EMERGENT_PENDING", "MARKET_PENDING", "RIPPLE_PENDING", "HINT_PENDING", "LOCATION_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING", "NORMAL_PENDING", "CAMP_PENDING", "SHOP_PENDING", "VENDOR_RESULT_PENDING", "MENTOR_PENDING",
			"DESTINY_WHEEL_PENDING", "LICENSED_DELIVERY_PENDING",
			"GHOST_DEBT_PENDING", "THREAD_PENDING", "FACTION_PENDING"] or expected_token <= 0 \
			or expected_token != _choice_token or not direction in ["left", "right", "up", "down"]:
		return false
	if state.get("phase") == "DEATH_PENDING":
		return _choose_death(direction)
	if state.get("phase") == "REBIRTH_PENDING":
		return _choose_rebirth_boon(direction)
	if state.get("phase") == "DESTINY_WHEEL_PENDING":
		return _commit_encounter_transition(_destiny_wheel_flow.flip(state, direction),
			"DESTINY_WHEEL_FLIPPED")
	if state.get("phase") == "LICENSED_DELIVERY_PENDING":
		return _commit_encounter_transition(_licensed_delivery.claim(state),
			"LICENSED_DELIVERY_CLAIMED") if direction == "left" else false
	if state.get("phase") == "GHOST_DEBT_PENDING":
		return _commit_encounter_transition(_ghost_debt_flow.settle_choice(
			state, direction), "GHOST_DEBT_SETTLED")
	if state.get("phase") == "THREAD_PENDING":
		if state.get("currentCardId") == LastLessonVendor.ENTRY_ID \
				and direction == "left":
			return _open_last_lesson_vendor()
		if state.get("currentCardId") in ["thread_ab_village_3", "thread_sword_tomb_2"] \
				and direction in ["left", "right"]:
			var battle_candidate: Dictionary = state.duplicate(true)
			battle_candidate["pendingThreadCombatDirection"] = direction
			return _commit_encounter_transition(_encounter_flow.accept(battle_candidate),
				"ENCOUNTER_WARNING")
		if state.get("currentCardId") == "thread_last_lesson_n3" \
				and direction == "left" and _story_thread_flow.choice_available(
					state, direction):
			var battle_candidate: Dictionary = state.duplicate(true)
			battle_candidate["pendingThreadCombatDirection"] = direction
			return _commit_encounter_transition(_encounter_flow.accept(battle_candidate),
				"ENCOUNTER_WARNING")
		var thread_choice: Dictionary = _story_thread_flow.settle_choice(state, direction)
		if thread_choice.is_empty():
			_mark_thread_failure(_story_thread_flow)
			return false
		return _commit_encounter_transition(thread_choice, "THREAD_CHOSEN")
	if state.get("phase") == "NORMAL_PENDING":
		return _choose_normal(direction)
	if state.get("phase") == "CAMP_PENDING":
		return _choose_camp(direction)
	if state.get("phase") == "SHOP_PENDING":
		return _choose_shop(direction)
	if direction == "down" and not (state.get("phase") == "NORMAL_PENDING" \
			or state.get("phase") == "CAMP_PENDING" \
			or state.get("phase") == "QUEST_PENDING" \
			and state.get("currentCardId") in ["q_whiteFox_3", "q_sword_3"]):
		return false
	if state.get("phase") == "COMBAT_HANDOFF":
		if direction == "left":
			return _commit_encounter_transition(_encounter_flow.accept(state),
				"ENCOUNTER_WARNING")
		var avoided: Dictionary = _cadence_flow.avoid(state) if state.has("pendingCadenceCard") else _avoid_flow.settle(state)
		if avoided.is_empty() and state.has("pendingCadenceCard"):
			_mark_battle_return_failure(_cadence_flow)
		var avoidance_text: Variant = state.get("pendingCadenceCard", {}).get(
			"choices", {}).get("right", {}).get("narrativeBlock")
		if not avoided.is_empty() and state.has("pendingCadenceCard") \
				and avoidance_text is String and not avoidance_text.strip_edges().is_empty():
			var result := _narrative_result_from_choice(avoided, state.pendingCadenceCard)
			if result.is_empty():
				return false
			avoided.noncombatFlow.cadencePromise = {"id": result.promiseId,
				"status": "pending", "sourceCardId": state.pendingCadenceCard.id,
				"followUpCardId": result.id,
				"createdDecisionIndex": avoided.runClock.decisionIndex}
			avoided.noncombatFlow.pendingResultCard = result.duplicate(true)
			avoided.pendingNarrativeResult = result.duplicate(true)
			avoided.phase = "NARRATIVE_RESULT_PENDING"
			avoided.currentCardId = result.id
			avoided.decisionCheckpoint = {"version": 1, "cardId": result.id,
				"sourceCardId": state.pendingCadenceCard.id,
				"turn": avoided.turn, "decisionIndex": avoided.runClock.decisionIndex}
		return _commit_encounter_transition(avoided, "ENCOUNTER_AVOIDED")
	if state.get("phase") == "WARNING_PENDING":
		if state.get("pendingRealmGateCard", {}).get("id") == RealmGateFlow.TRIBULATION_CARD_ID \
				and direction == "right":
			return _choose_voluntary_rebirth()
		return _commit_encounter_transition(_encounter_flow.confirm(state, direction),
			"BATTLE_REQUEST_READY")
	if state.get("phase") == "NARRATIVE_RESULT_PENDING":
		return _acknowledge_narrative_result(direction)
	if state.get("phase") == "MILESTONE_PENDING":
		var milestone_candidate: Dictionary = state.duplicate(true)
		_upgrade_avoid_lifespan(milestone_candidate)
		var settled_milestone: Dictionary = _milestone_flow.settle(
			milestone_candidate, direction)
		if settled_milestone.is_empty():
			return false
		if int(settled_milestone.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(settled_milestone.get("attributes", {}).get("health", 1)) <= 0 \
				or int(settled_milestone.get("resources", {}).get("lifespan", 1)) <= 0:
			var revival: Dictionary = TreasureAcquisition.new(
				_content).revive_equipped(settled_milestone)
			if revival.is_empty():
				return false
			if revival.get("revived") == true:
				settled_milestone = revival["state"]
			else:
				settled_milestone["phase"] = "MILESTONE_PENDING"
				settled_milestone = _death_flow.prepare_death(
					settled_milestone, String(state.get("currentCardId", "")))
				return _commit_encounter_transition(settled_milestone,
					"DEATH_NARRATIVE") if not settled_milestone.is_empty() else false
		return _commit_encounter_transition(settled_milestone, "MILESTONE_CHOSEN")
	if state.get("phase") == "QUEST_PENDING":
		if state.get("currentCardId") == "q_sword_3" and direction in ["left", "right"]:
			var sword_trial: Dictionary = state.duplicate(true)
			sword_trial["pendingQuestCombatDirection"] = direction
			return _commit_encounter_transition(_encounter_flow.accept(sword_trial),
				"ENCOUNTER_WARNING")
		if state.get("currentCardId") == "q_whiteFox_3" and direction == "left":
			return _commit_encounter_transition(_encounter_flow.accept(state), "ENCOUNTER_WARNING")
		var quest_source := String(state.get("currentCardId", ""))
		return _commit_encounter_transition(_quest_flow.settle(state, direction),
			"QUEST_CHOSEN", quest_source if quest_source.begins_with("q_body_") \
				or quest_source.begins_with("q_sword_") \
				or quest_source.begins_with("q_spell_") \
				or quest_source.begins_with("q_pill_") \
				or quest_source.begins_with("q_tianshu_") else "")
	if state.get("phase") == "KARMA_PENDING":
		var karma_source := String(state.get("currentCardId", ""))
		var settled_karma: Dictionary = _karma_flow.settle(state, direction)
		var depleted := not settled_karma.is_empty() and (
			int(settled_karma.get("attributes", {}).get("health", 1)) <= 0
			or int(settled_karma.get("attributes", {}).get("daoHeart", 1)) <= 0
			or int(settled_karma.get("resources", {}).get("lifespan", 1)) <= 0)
		return _commit_encounter_transition(settled_karma,
			"KARMA_CHOSEN", karma_source if depleted or karma_source in [
				KarmaFlow.BODY_ECHO_CARD_ID, KarmaFlow.BODY_ASCENSION_CARD_ID] else "")
	if state.get("phase") == "EMERGENT_PENDING":
		return _commit_encounter_transition(_emergent_flow.settle(state, direction),
			"EMERGENT_CHOSEN")
	if state.get("phase") == "RIPPLE_PENDING":
		var ripple_candidate: Dictionary = _ripple_flow.settle_choice(state,
			direction)
		if ripple_candidate.is_empty():
			return false
		var choice_index := int(state.runClock.decisionIndex) + 1
		if choice_index >= _passive_regen_extension_activation_index \
				and not _normal_choice_policy._apply_passive_regen(
					ripple_candidate, choice_index):
			return false
		return _commit_encounter_transition(ripple_candidate, "RIPPLE_CHOSEN")
	if state.get("phase") == "HINT_PENDING":
		var hint_candidate: Dictionary = _hint_flow.settle_choice(state, direction)
		if hint_candidate.is_empty():
			return false
		var choice_index := int(state.runClock.decisionIndex) + 1
		if choice_index >= _passive_regen_extension_activation_index \
				and not _normal_choice_policy._apply_passive_regen(
					hint_candidate, choice_index):
			return false
		return _commit_encounter_transition(hint_candidate, "HINT_CHOSEN")
	if state.get("phase") == "LOCATION_PENDING":
		var scene_candidate: Dictionary = _scene_layer_flow.settle(state, direction)
		if scene_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				scene_candidate):
			return false
		return _commit_encounter_transition(scene_candidate, "LOCATION_CHOSEN")
	if state.get("phase") == "CHOICE_ECHO_PENDING":
		var echo_candidate: Dictionary = _choice_echo_flow.settle(state, direction)
		if echo_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				echo_candidate):
			return false
		return _commit_encounter_transition(echo_candidate, "CHOICE_ECHO_CHOSEN")
	if state.get("phase") == "ALLY_PENDING":
		var ally_candidate: Dictionary = _ally_arc_flow.settle(state, direction)
		if ally_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				ally_candidate):
			return false
		return _commit_encounter_transition(ally_candidate, "ALLY_CHOSEN")
	if state.get("phase") == "COMPANION_ARC_PENDING":
		return _commit_encounter_transition(
			_companion_arc_flow.settle(state, direction), "COMPANION_ARC_CHOSEN")
	if state.get("phase") == "SEER_PENDING":
		var seer_candidate: Dictionary = _seer_arc_flow.settle(state, direction)
		if seer_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				seer_candidate):
			return false
		return _commit_encounter_transition(seer_candidate, "SEER_CHOSEN")
	if state.get("phase") == "SURFACING_PENDING":
		var surface_candidate: Dictionary = _narrative_surfacing.settle(state, direction)
		if surface_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				surface_candidate):
			return false
		return _commit_encounter_transition(surface_candidate, "SURFACING_CHOSEN")
	if state.get("phase") == "COMPANION_PENDING":
		if direction == "left" and state.get("currentCardId") \
				== BattleGateway.COMPANION_OLD_MASTER_SOURCE_ID:
			return _commit_encounter_transition(_encounter_flow.accept(state),
				"ENCOUNTER_WARNING")
		var companion_input: Dictionary = state
		if not _replaying_history and state.has("companionProgress") \
				and not state.companionProgress.has("milestoneActivationIndex"):
			companion_input = state.duplicate(true)
			companion_input.companionProgress.milestoneActivationIndex = int(
				state.runClock.decisionIndex) + 1
		var companion_candidate: Dictionary = _companion_events.settle(
			companion_input, direction)
		if companion_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				companion_candidate):
			return false
		return _commit_encounter_transition(companion_candidate, "COMPANION_CHOSEN",
			String(state.get("currentCardId", "")))
	if state.get("phase") == "FACTION_PENDING":
		if direction == "left" and state.get("currentCardId") \
				== BattleGateway.FACTION_GATE_SOURCE_ID:
			return _commit_encounter_transition(_encounter_flow.accept(state),
				"ENCOUNTER_WARNING")
		return _commit_encounter_transition(_faction_events.settle(state, direction),
			"FACTION_CHOSEN", String(state.get("currentCardId", "")))
	if state.get("phase") == "MARKET_PENDING":
		if direction == "left":
			if not _vendor_state_committed():
				return false
			return _commit_encounter_transition((_ghost_vendor_flow.open(state) \
				if state.get("currentCardId") == MarketFlow.GHOST_ID \
				else _vendor_flow.open(state)), "VENDOR_OPENED")
		var historical_seed_tick := not (_replaying_history
			and _market_skip_seed_tick_activation_index > int(state.get(
				"runClock", {}).get("decisionIndex", -1)) + 1)
		return _commit_encounter_transition(_market_flow.settle_skip(
			state, direction, historical_seed_tick),
			"MARKET_SKIPPED")
	if state.get("phase") == "VENDOR_RESULT_PENDING":
		if _last_lesson_vendor_active():
			return direction == "right" and _commit_encounter_transition(
				_last_lesson_vendor.dismiss(state), "VENDOR_DISMISSED")
		return _commit_encounter_transition((_ghost_vendor_flow.dismiss(state) \
			if _ghost_vendor_active() else (_regulated_vendor.dismiss(state) \
			if _regulated_vendor_active() else _vendor_flow.dismiss(state))), "VENDOR_DISMISSED") \
			if direction == "right" else false
	if state.get("phase") == "MENTOR_PENDING":
		return _commit_encounter_transition(_mentor_flow.settle(state, direction,
			int(state.runClock.decisionIndex) + 1 >= \
				_passive_regen_extension_activation_index),
			"MENTOR_CHOSEN")
	if state.get("phase") == "STARTER_BOUNDARY":
		return _choose_prologue(direction)
	var card: Dictionary = _cards.get(_current_card_id, {})
	if not _current_card_id in TUTORIAL_IDS or card.is_empty() \
			or card.get("type") != "NORMAL" or not card.get("choices") is Dictionary:
		return false
	var choice: Dictionary = card["choices"].get(direction, {})
	if choice.is_empty() or not _validate_choice(choice):
		return false
	var next_id := ""
	if choice.has("nextCard"):
		next_id = String(choice["nextCard"])
		if not next_id in TUTORIAL_IDS or TUTORIAL_IDS.find(next_id) <= TUTORIAL_IDS.find(_current_card_id):
			return false
	elif _current_card_id == "tutorial_4":
		next_id = String(_path_definition.get("startCard", ""))
	else:
		return false
	if not _cards.has(next_id):
		return false
	var next_state: Dictionary = state.duplicate(true)
	var effects: Dictionary = choice.get("effects", {})
	for key in effects:
		if not _apply_effect(next_state, key, int(effects[key])):
			return false
	# GameLogic._shouldConsumeLifespan: harmful health/daoHeart choices age one year.
	if int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		next_state["resources"]["lifespan"] = maxi(0,
			int(next_state["resources"]["lifespan"]) - 1)
	return _commit_choice(next_state, card, direction, next_id, "")


func _commit_encounter_transition(candidate: Dictionary, event_type: String,
		death_source_id: String = "") -> bool:
	if candidate.is_empty() and event_type in ["ENCOUNTER_WARNING", "BATTLE_REQUEST_READY"]:
		_mark_battle_return_failure(_battle_gateway)
		return false
	var nested_milestone: bool = event_type == "MILESTONE_CHOSEN" \
		and candidate.get("phase") == "MILESTONE_PENDING" \
		and candidate.get("currentCardId") != state.get("currentCardId")
	if nested_milestone and candidate.has("normalFlow"):
		var cursor: Dictionary = _normal_draw_policy.phase_cursor_after(_flow_card_count + 1)
		candidate["normalFlow"]["cardCount"] = _flow_card_count + 1
		candidate["normalFlow"]["phase"] = cursor.get("phase")
		candidate["normalFlow"]["phaseProgress"] = cursor.get("phaseProgress")
	if not candidate.is_empty() and not _replaying_history \
			and candidate.get("companionProgress") is Dictionary \
			and not candidate.companionProgress.has("milestoneActivationIndex") \
			and int(candidate.get("runClock", {}).get("decisionIndex", 0)) > int(
				state.get("runClock", {}).get("decisionIndex", 0)):
		candidate.companionProgress.milestoneActivationIndex = int(
			candidate.runClock.decisionIndex) + 1
	if not candidate.is_empty() and candidate.get("companionProgress") is Dictionary \
			and int(candidate.get("runClock", {}).get("decisionIndex", 0)) > int(
				state.get("runClock", {}).get("decisionIndex", 0)):
		if not candidate.has("companionArcState") and int(candidate.runClock.decisionIndex) \
				>= _companion_arc_activation_index:
			var arc_marker: Dictionary = _companion_arc_flow.marker(
				_companion_arc_activation_index, int(candidate.get("lifeCount", 0)))
			if arc_marker.is_empty():
				_mark_source_failure(_content)
				return false
			candidate["companionArcState"] = arc_marker
		if candidate.has("companionArcState") \
				and not _companion_arc_flow.advance(state, candidate):
			_mark_source_failure(_content)
			return false
	if candidate.is_empty() or not _persist_snapshot(candidate, death_source_id):
		return false
	var prior_id := _current_card_id
	_current_card_id = String(candidate.get("currentCardId", prior_id))
	state = candidate
	_choice_token += 1
	if nested_milestone:
		_flow_card_count += 1
		_tick_normal_starvation("milestone")
	changed.emit({"type": "DEATH_NARRATIVE" if not death_source_id.is_empty() \
		and state.get("phase") == "DEATH_PENDING" else event_type, "sourceCardId": prior_id,
		"cardId": _current_card_id, "turn": state["turn"]})
	return true


func battle_request() -> Dictionary:
	var request: Dictionary = _battle_gateway.build_request(state)
	if request.is_empty():
		_mark_battle_return_failure(_battle_gateway)
	return request


func commit_browser_combat_card(hand_index: int, card_id: String,
		combat_before: Dictionary) -> bool:
	if state.get("phase") != "BATTLE_PENDING" \
			or not state.get("browserCombatSnapshot") is Dictionary \
			or not state.get("browserCombatAuthority") is Dictionary \
			or not state.get("browserCombatActions", []) is Array:
		return false
	var actions: Array = state.get("browserCombatActions", [])
	var request: Dictionary = battle_request()
	var plan: Dictionary = BrowserCombatPlan.new(_registry).resolve_persisted(state)
	if request.is_empty() or plan.get("launchAuthorized") != true:
		return false
	var replay = BrowserCombatActions.new()
	var before: Dictionary = replay.replay(state.browserCombatSnapshot,
		state.browserCombatAuthority, request, plan, actions, _registry)
	if before.is_empty() or JSON.parse_string(JSON.stringify(before)) \
			!= JSON.parse_string(JSON.stringify(combat_before)):
		return false
	var next_actions: Array = actions.duplicate(true)
	next_actions.append({"type": "PLAY_CARD", "handIndex": hand_index,
		"cardId": card_id})
	if replay.replay(state.browserCombatSnapshot, state.browserCombatAuthority,
			request, plan, next_actions, _registry).is_empty():
		return false
	var candidate: Dictionary = state.duplicate(true)
	candidate["browserCombatActions"] = next_actions
	if not _persist_snapshot(candidate):
		return false
	state = candidate
	return true


func commit_browser_combat_end_turn(combat_before: Dictionary) -> bool:
	if state.get("phase") != "BATTLE_PENDING" \
			or not state.get("browserCombatSnapshot") is Dictionary \
			or not state.get("browserCombatAuthority") is Dictionary \
			or not state.get("browserCombatActions", []) is Array:
		return false
	var actions: Array = state.get("browserCombatActions", [])
	var request: Dictionary = battle_request()
	var plan: Dictionary = BrowserCombatPlan.new(_registry).resolve_persisted(state)
	var replay = BrowserCombatActions.new()
	if request.is_empty() or plan.get("launchAuthorized") != true \
			or replay.replay(state.browserCombatSnapshot,
				state.browserCombatAuthority, request, plan, actions, _registry) \
				!= combat_before:
		return false
	var next_actions: Array = actions.duplicate(true)
	next_actions.append({"type": "END_TURN"})
	if replay.replay(state.browserCombatSnapshot, state.browserCombatAuthority,
			request, plan, next_actions, _registry).is_empty():
		return false
	var candidate: Dictionary = state.duplicate(true)
	candidate["browserCombatActions"] = next_actions
	if not _persist_snapshot(candidate):
		return false
	state = candidate
	return true


func commit_browser_combat_reaction(reaction_id: String,
		combat_before: Dictionary) -> Dictionary:
	if reaction_id != "TAKE_HIT" or state.get("phase") != "BATTLE_PENDING" \
			or not state.get("browserCombatSnapshot") is Dictionary \
			or not state.get("browserCombatAuthority") is Dictionary \
			or not state.get("browserCombatActions", []) is Array:
		return {}
	var actions: Array = state.get("browserCombatActions", [])
	var request: Dictionary = battle_request()
	var plan: Dictionary = BrowserCombatPlan.new(_registry).resolve_persisted(state)
	var replay = BrowserCombatActions.new()
	if request.is_empty() or plan.get("launchAuthorized") != true \
			or replay.replay(state.browserCombatSnapshot,
				state.browserCombatAuthority, request, plan, actions, _registry) \
				!= combat_before:
		return {}
	var proposed: Dictionary = replay.propose_reaction(state.browserCombatSnapshot,
		state.browserCombatAuthority, request, plan, actions, _registry)
	if proposed.is_empty():
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var next_actions: Array = actions.duplicate(true)
	next_actions.append(proposed.action)
	candidate["browserCombatActions"] = next_actions
	if not _persist_snapshot(candidate):
		return {}
	state = candidate
	return proposed.action.duplicate(true)


func submit_battle_result(result: Dictionary) -> bool:
	var request: Dictionary = _battle_gateway.build_request(state)
	var candidate: Dictionary = _battle_return_flow.settle(state, result)
	if candidate.is_empty():
		_mark_battle_return_failure(_battle_return_flow)
		return false
	if state.has("browserCombatSnapshot"):
		candidate.erase("browserCombatSnapshot")
		candidate.erase("browserCombatAuthority")
		candidate.erase("browserCombatActions")
	if result.get("outcome") == "victory" and candidate.has("legacyFragmentVersion") \
			and (not _replaying_history or int(candidate.get("runClock", {}).get(
				"decisionIndex", -1)) >= _boss_reward_activation_index):
		if not _legacy_fragment_flow.begin_boss_reward(candidate, request):
			return false
		if candidate.get("legacyRunState", {}).get("pendingBossFragmentReward") is Dictionary \
				and (not _replaying_history or _boss_reward_marker_present):
			candidate["bossRewardActivationIndex"] = _boss_reward_activation_index
	return _commit_encounter_transition(candidate, "BATTLE_RESULT_COMMITTED")


func _mark_battle_return_failure(flow: RefCounted) -> void:
	if _store == null:
		return
	if flow.source_error == "SOURCE_UNAVAILABLE" and _store.has_method("mark_source_unavailable"):
		_store.mark_source_unavailable()
	elif flow.source_error == "SOURCE_MISMATCH" and _store.has_method("mark_source_mismatch"):
		_store.mark_source_mismatch()


func resume_flow() -> bool:
	if state.get("phase") != "FLOW_PENDING" \
			or state.get("noncombatFlow", {}).get("sourceContentHash") != _battle_gateway.source_content_hash():
		return false
	var candidate: Dictionary = state.duplicate(true)
	if not candidate.has("mentorArcState") and not _legacy_mentor_replay:
		candidate["mentorArcState"] = _mentor_state.duplicate(true)
	_upgrade_avoid_lifespan(candidate)
	if not _legacy_karma_replay and not candidate["noncombatFlow"].has("karmaClockVersion"):
		# Old acknowledged N3b saves missed the avoid and result decision ticks.
		MilestoneFlow.tick_seeds(candidate)
		MilestoneFlow.tick_seeds(candidate)
		candidate["noncombatFlow"]["karmaClockVersion"] = 1
		if not candidate["noncombatFlow"].has("promise"):
			candidate["noncombatFlow"]["legacySchemaVersion"] = 0
	var legacy_faction_tick: bool = _legacy_faction_collection_replay \
		and int(candidate.get("runClock", {}).get("decisionIndex", 0)) < \
		_faction_collection_new_activation_index
	if legacy_faction_tick and candidate.has("factionEventState"):
		var legacy_faction_collected: Dictionary = _faction_events.collect(candidate)
		if legacy_faction_collected.is_empty():
			_mark_source_failure(_content)
			return false
		candidate = legacy_faction_collected
	var next: Dictionary = _ghost_debt_flow.resume(candidate)
	if next.is_empty() and candidate.has("pendingGhostDebtId"):
		return false
	if next.is_empty():
		next = _licensed_delivery.resume(candidate)
	if next.is_empty() and candidate.has("pendingLicensedDeliveryOrderId"):
		return false
	if next.is_empty() and int(candidate.runClock.decisionIndex) >= _cadence_activation_index:
		var scheduled: Dictionary = _cadence_flow.resume(candidate)
		if not _cadence_flow.last_error.is_empty():
			_mark_battle_return_failure(_cadence_flow)
			return false
		if scheduled.get("phase") == "COMBAT_HANDOFF":
			next = scheduled
		elif not scheduled.is_empty():
			candidate = scheduled
	if next.is_empty():
		var realm_gate: Dictionary = _realm_gate_flow.resume(candidate)
		if not _realm_gate_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if not realm_gate.is_empty():
			next = _encounter_flow.accept(realm_gate)
			if next.is_empty():
				_mark_battle_return_failure(_battle_gateway)
				return false
			# The source terminal milestone opens its warning automatically;
			# there is no player choice before the warning checkpoint.
			next["encounterActionHistory"] = []
	if next.is_empty():
		next = _milestone_flow.resume(candidate)
	if not _milestone_flow.last_error.is_empty():
		_mark_source_failure(_content)
		if _store != null:
			var missing := false
			for module_id in ["cards:chapter_milestones", "narrative:causal_graph"]:
				var source_path: String = _content.module_path(module_id)
				if source_path.is_empty() or not FileAccess.file_exists(
						ContentRepository.CONTENT_ROOT + source_path):
					missing = true
					break
			if missing and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif _store.has_method("mark_source_mismatch"):
				_store.mark_source_mismatch()
		return false
	if next.is_empty():
		next = _quest_flow.resume(candidate)
	if next.is_empty() and _quest_flow.last_error.is_empty():
		next = _story_thread_flow.resume(candidate)
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and not _legacy_karma_order_replay:
		_karma_flow.close_redundant_companion_seeds(candidate)
		next = _karma_flow.resume(candidate)
	if next.is_empty() and candidate.has("factionEventState") \
			and not legacy_faction_tick:
		var faction_collected: Dictionary = _faction_events.collect(candidate)
		if faction_collected.is_empty():
			_mark_source_failure(_content)
			return false
		candidate = faction_collected
	if next.is_empty() and int(candidate.runClock.decisionIndex) >= _npc_activation_index:
		var collected_npc: Dictionary = _npc_encounter_flow.collect(candidate)
		if not _npc_encounter_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if not collected_npc.is_empty():
			candidate = collected_npc
	if next.is_empty() and int(candidate.runClock.decisionIndex) >= _npc_cross_activation_index:
		var collected_cross: Dictionary = _npc_cross_flow.collect(candidate)
		if not _npc_cross_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if not collected_cross.is_empty():
			candidate = collected_cross
	if next.is_empty() and candidate.has("companionArcState"):
		var companion_climax: Dictionary = _companion_arc_flow.take(candidate, "climax")
		if not _companion_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if companion_climax.get("phase") == "COMPANION_ARC_PENDING":
			next = companion_climax
		elif not companion_climax.is_empty():
			candidate = companion_climax
	if next.is_empty() and candidate.has("mentorArcState"):
		next = _mentor_flow.resume(candidate, false, "climax")
		if not _mentor_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	if next.is_empty() and candidate.has("companionArcState"):
		var companion_stage: Dictionary = _companion_arc_flow.take(candidate, "event")
		if not _companion_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if companion_stage.get("phase") == "COMPANION_ARC_PENDING":
			next = companion_stage
		elif not companion_stage.is_empty():
			candidate = companion_stage
	if next.is_empty() and candidate.has("allyArcState"):
		next = _ally_arc_flow.take(candidate, "climax")
		if not _ally_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	# Source NPC card can already be queued when em_heaven_gaze raises the
	# TRUSTED threshold. Let that older NPC card resolve before the new stage;
	# the earlier INNER_DISCIPLE stage still keeps its normal priority.
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and not (
				candidate.get("mentorArcState", {}).get("pendingStages", []).has("TRUSTED")
				and candidate.get("npcEncounterScheduling", {}).get("queuedCard") is Dictionary):
		next = _mentor_flow.resume(candidate, not _legacy_mentor_stage_replay)
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty():
		next = _emergent_flow.resume(candidate)
	if next.is_empty() and candidate.has("seerArcState"):
		next = _seer_arc_flow.take(candidate, "climax")
		if not _seer_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	if next.is_empty() and candidate.has("companionProgress"):
		var companion_event: Dictionary = _companion_events.take(candidate)
		if not _companion_events.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if companion_event.get("phase") == "COMPANION_PENDING":
			next = companion_event
		elif not companion_event.is_empty():
			candidate = companion_event
	if next.is_empty() and candidate.has("factionEventState") \
			and candidate.get("pendingFactionCard", {}).get(
				"deliveryClass") != "location_combat_invitation":
		var faction_next: Dictionary = _faction_events.take(candidate)
		if not _faction_events.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if faction_next.get("phase") == "FACTION_PENDING":
			next = faction_next
	if next.is_empty() and candidate.has("allyArcState"):
		next = _ally_arc_flow.take(candidate, "event")
		if not _ally_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	if next.is_empty() and candidate.has("seerArcState"):
		next = _seer_arc_flow.take(candidate, "event")
		if not _seer_arc_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	if next.is_empty() and candidate.has("choiceEchoState"):
		next = _choice_echo_flow.take(candidate)
		if not _choice_echo_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
	if next.is_empty() and candidate.has("narrativeSurfacingState"):
		var surfaced: Dictionary = _narrative_surfacing.take(candidate)
		if not _narrative_surfacing.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if surfaced.get("phase") == "SURFACING_PENDING":
			next = surfaced
		elif not surfaced.is_empty():
			candidate = surfaced
	if next.is_empty() and int(candidate.runClock.decisionIndex) >= _npc_cross_activation_index:
		var cross_next: Dictionary = _npc_cross_flow.take(candidate)
		if not _npc_cross_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if cross_next.get("phase") == "NPC_CROSS_PENDING":
			next = cross_next
		elif not cross_next.is_empty():
			candidate = cross_next
	if next.is_empty() and int(candidate.runClock.decisionIndex) >= _npc_activation_index:
		var npc_next: Dictionary = _npc_encounter_flow.take(candidate)
		if not _npc_encounter_flow.last_error.is_empty():
			_mark_source_failure(_content)
			return false
		if npc_next.get("phase") == "NPC_PENDING":
			next = npc_next
		elif not npc_next.is_empty():
			candidate = npc_next
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty():
		next = _mentor_flow.resume(candidate, not _legacy_mentor_stage_replay)
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty():
		if candidate.has("factionEventState") \
				and candidate.get("pendingFactionCard", {}).get(
					"deliveryClass") == "location_combat_invitation":
			var held_faction: Dictionary = _faction_events.take(candidate)
			if not _faction_events.last_error.is_empty():
				_mark_source_failure(_content)
				return false
			if held_faction.get("phase") == "FACTION_PENDING":
				next = held_faction
			elif not held_faction.is_empty():
				candidate = held_faction
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty():
		candidate = _check_prepriority_encounters(candidate)
		if candidate.is_empty():
			return false
		next = candidate if candidate.get("phase") in ["CAMP_PENDING", "SHOP_PENDING"] \
			else _market_flow.resume(candidate)
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty() and _market_flow.last_error.is_empty():
		next = _ripple_flow.resume(candidate)
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty() and _market_flow.last_error.is_empty() \
			and _ripple_flow.last_error.is_empty():
		next = _hint_flow.resume(candidate)
	if next.has("pendingMilestoneCard") and not _legacy_market_replay \
			and next.get("pendingMilestoneCard") is Dictionary:
		var scene_location := String(next["pendingMilestoneCard"].get("location", ""))
		if not scene_location.is_empty() and next.has("marketStateVersion"):
			next["currentLocation"] = scene_location
	if next.is_empty() and _story_thread_flow.last_error.is_empty() \
			and _quest_flow.last_error.is_empty() \
			and _karma_flow.last_error.is_empty() \
			and _mentor_flow.last_error.is_empty() \
			and _emergent_flow.last_error.is_empty() \
			and _market_flow.last_error.is_empty() \
			and _ripple_flow.last_error.is_empty() \
			and _hint_flow.last_error.is_empty():
		var promise: Dictionary = candidate.get("pendingNormalContinuation", {})
		var promised_id := String(promise.get("cardId", ""))
		if not promised_id.is_empty():
			if promise.get("sourceCardId") != "dp_demon_recruit_again" \
					or promised_id != "dp_demon_truth":
				return false
			var promised: Dictionary = _normal_choice_policy.source_card(
				promised_id, candidate)
			if promised.is_empty():
				return false
			next = candidate.duplicate(true)
			next.erase("pendingNormalContinuation")
			next["phase"] = "NORMAL_PENDING"
			next["currentCardId"] = promised_id
			next["decisionCheckpoint"] = {"version": 1,
				"cardId": promised_id,
				"sourceCardId": promise.sourceCardId, "turn": next.turn,
				"decisionIndex": next.runClock.decisionIndex,
				"flowSource": "authored:nextCard"}
		else:
			if candidate.has("sceneLayerState"):
				var scene_visit: Dictionary = _scene_layer_flow.visit(candidate)
				if scene_visit.is_empty():
					_mark_source_failure(_content)
					return false
				if scene_visit.get("phase") == "LOCATION_PENDING":
					next = scene_visit
				else:
					candidate = scene_visit
			if next.is_empty() and candidate.has("pendingDestinyWheel"):
				next = _destiny_wheel_flow.resume_deferred(candidate)
				if next.is_empty():
					return false
			if next.is_empty():
				next = _draw_normal_after_priorities(candidate)
	if next.is_empty():
		_mark_source_failure(_content)
		if (not _story_thread_flow.last_error.is_empty() \
				or not _quest_flow.last_error.is_empty() \
				or not _karma_flow.last_error.is_empty() \
				or not _mentor_flow.last_error.is_empty() \
				or not _emergent_flow.last_error.is_empty() \
				or not _market_flow.last_error.is_empty() \
				or not _ripple_flow.last_error.is_empty() \
				or not _hint_flow.last_error.is_empty()) and _store != null \
				and _store.has_method("mark_source_mismatch"):
			if not _story_thread_flow.last_error.is_empty() \
					and _story_thread_flow.source_missing() \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif not _emergent_flow.last_error.is_empty() \
					and not FileAccess.file_exists(EmergentFlow.DERIVED_PATH) \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif not _market_flow.last_error.is_empty() and _market_flow.source_missing() \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif not _ripple_flow.last_error.is_empty() and _ripple_flow.source_missing() \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			elif not _hint_flow.last_error.is_empty() and _hint_flow.source_missing() \
					and _store.has_method("mark_source_unavailable"):
				_store.mark_source_unavailable()
			else:
				_store.mark_source_mismatch()
	if int(state.get("lifeCount", 0)) > 0 \
			and next.get("phase") not in ["NORMAL_PENDING", "MILESTONE_PENDING",
				"KARMA_PENDING", "MARKET_PENDING", "QUEST_PENDING", "THREAD_PENDING",
				"MENTOR_PENDING", "HINT_PENDING", "LOCATION_PENDING", "GHOST_DEBT_PENDING", "COMBAT_HANDOFF",
				"NPC_PENDING", "NPC_CROSS_PENDING", "FACTION_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING",
				"SURFACING_PENDING", "COMPANION_PENDING", "CHOICE_ECHO_PENDING",
				"EMERGENT_PENDING", "CAMP_PENDING", "SHOP_PENDING",
				"DESTINY_WHEEL_PENDING", "LICENSED_DELIVERY_PENDING"]:
		return false
	if next.has("normalFlow"):
		var cursor: Dictionary = _normal_draw_policy.phase_cursor_after(_flow_card_count + 1)
		next["normalFlow"]["cardCount"] = _flow_card_count + 1
		next["normalFlow"]["phase"] = cursor.get("phase")
		next["normalFlow"]["phaseProgress"] = cursor.get("phaseProgress")
	var committed := _commit_encounter_transition(next, "FLOW_CARD_READY")
	if committed:
		_flow_card_count += 1
		_tick_normal_starvation(_source_for_card(next))
	return committed


func _draw_normal_after_priorities(candidate: Dictionary) -> Dictionary:
	_normal_flow_error = ""
	if candidate.get("realm") not in NormalDrawPolicy.REALMS:
		_normal_flow_error = "ordinary draw realm is not yet audited"
		return {}
	var next: Dictionary = candidate.duplicate(true)
	var flow: Dictionary = _prepare_normal_flow(next)
	if flow.is_empty():
		return {}
	var card_count := _flow_card_count + 1
	var cursor: Dictionary = _normal_draw_policy.phase_cursor_after(card_count)
	if cursor.is_empty():
		_normal_flow_error = "ordinary draw phase cursor invalid"
		return {}
	var row_index: int = flow["draws"].size()
	var recorded: Dictionary = {}
	if row_index < _normal_replay_draws.size():
		var recorded_value: Variant = _normal_replay_draws[row_index]
		if not recorded_value is Dictionary or recorded_value.get("cardCount") != card_count \
				or recorded_value.get("phase") != cursor.get("phase"):
			_normal_flow_error = "ordinary draw replay receipt mismatch"
			return {}
		recorded = recorded_value
	var row: Dictionary = {"cardCount": card_count, "phase": cursor["phase"]}
	var turn := int(candidate.get("turn", 0))
	if not flow.has("priorityChecks") and turn % 8 == 0:
		var p25_roll := _sample_normal_roll(flow, recorded, "p25ShopRoll")
		if p25_roll < 0.0:
			_normal_flow_error = "P25 shop roll differs from seed"
			return {}
		row["p25ShopRoll"] = p25_roll
		if p25_roll < 0.10:
			_normal_flow_error = "P25 shop encounter consumer is not migrated"
			return {}
	if not flow.has("priorityChecks") and turn % 15 == 0:
		var p24_roll := _sample_normal_roll(flow, recorded, "p24CampRoll")
		if p24_roll < 0.0:
			_normal_flow_error = "P24 camp roll differs from seed"
			return {}
		row["p24CampRoll"] = p24_roll
		if p24_roll < 0.30:
			_normal_flow_error = "P24 camp encounter consumer is not migrated"
			return {}
	var source_roll := _sample_normal_roll(flow, recorded, "sourceRoll")
	if source_roll < 0.0:
		_normal_flow_error = "ordinary source roll differs from seed"
		return {}
	var sampled_starvation := _normal_starvation.duplicate(true)
	for name in ["normal", "lightStory", "story", "shop", "exploration",
			"combat", "combatLight", "challenge", "reward", "narrative",
			"karma", "quest", "milestone"]:
		sampled_starvation[name] = int(sampled_starvation.get(name, 0)) + 1
	var source: String = _normal_draw_policy.select_source(candidate,
		String(cursor["phase"]), sampled_starvation, source_roll)
	if source.is_empty():
		_normal_flow_error = "ordinary source lottery failed"
		return {}
	row["source"] = source
	row["sourceRoll"] = source_roll
	if source == "shop":
		var secondary_shop := _secondary_shop_check(flow, recorded, row, turn)
		if secondary_shop < 0:
			_normal_flow_error = "phase shop roll or cooldown differs from seed"
			return {}
		if secondary_shop > 0:
			if not _sample_discarded_shop(next, flow, recorded, row):
				return {}
			if not recorded.is_empty() and JSON.parse_string(JSON.stringify(row)) != recorded:
				_normal_flow_error = "phase shop replay receipt mismatch"
				return {}
			flow["draws"].append(row)
			flow["cardCount"] = card_count
			flow["phase"] = cursor["phase"]
			flow["phaseProgress"] = cursor["phaseProgress"]
			next["normalFlow"] = flow
			return _pending_shop(next, "ordinary:shop")
	var bucket_roll := _sample_normal_roll(flow, recorded, "bucketRoll")
	var card_roll := _sample_normal_roll(flow, recorded, "cardRoll")
	if bucket_roll < 0.0 or card_roll < 0.0:
		_normal_flow_error = "ordinary card roll differs from seed"
		return {}
	var card_id: String = _normal_draw_policy.pick(candidate, bucket_roll,
		card_roll, _normal_draw_policy.preferred_tags_for(source))
	# FlowDirector falls back to CardSystem._drawNormal when no eligible card
	# remains; CardSystem then returns the authored qi meditation card.
	if card_id.is_empty() and _normal_draw_policy.last_error.is_empty():
		card_id = "q_meditation"
	var card: Dictionary = _normal_draw_policy.source_card(candidate, card_id)
	if card_id.is_empty() or card.is_empty():
		_normal_flow_error = _normal_draw_policy.last_error
		return {}
	var choice_supported := false
	for direction in card.get("choices", {}):
		if _normal_choice_policy.choice_available(candidate, card, String(direction)):
			choice_supported = true
			break
	if card_id == "q_market" and card.get("choices", {}).get("left", {}).get(
			"action", {}).get("type") == "ENTER_VENDOR":
		choice_supported = true
	if not choice_supported:
		_normal_flow_error = "selected ordinary card needs an unmigrated choice consumer: " + card_id
		return {}
	if row_index < _normal_replay_draws.size() and recorded.get("cardId") != card_id:
		_normal_flow_error = "ordinary draw card differs from replay receipt"
		return {}
	row["bucketRoll"] = bucket_roll
	row["cardRoll"] = card_roll
	row["cardId"] = card_id
	flow["draws"].append(row)
	flow["cardCount"] = card_count
	flow["phase"] = cursor["phase"]
	flow["phaseProgress"] = cursor["phaseProgress"]
	next["normalFlow"] = flow
	next["phase"] = "SHOP_PENDING" if card_id == "q_market" else "NORMAL_PENDING"
	next["currentCardId"] = card_id
	next["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
		"sourceCardId": candidate.get("decisionCheckpoint", {}).get("sourceCardId"),
		"turn": candidate.get("turn"),
		"decisionIndex": candidate.get("runClock", {}).get("decisionIndex")}
	return next


func _secondary_shop_check(flow: Dictionary, recorded: Dictionary,
		row: Dictionary, turn: int) -> int:
	# FlowDirector._drawBySource('shop') calls CardSystem._checkShopEncounter
	# again. Old recorded draws predate this cooldown correction; replay their
	# historical behaviour exactly and apply the source rule to new decisions.
	var legacy_receipt := not recorded.is_empty() and not recorded.has(
		"phaseShopCooldownBefore")
	var cooldown := int(flow.get("shopCooldown", 0))
	if not legacy_receipt:
		row["phaseShopCooldownBefore"] = cooldown
	if not legacy_receipt and cooldown > 0:
		flow["shopCooldown"] = cooldown - 1
	elif turn % 8 == 0:
		var shop_roll := _sample_normal_roll(flow, recorded, "phaseShopRoll")
		if shop_roll < 0.0:
			return -1
		row["phaseShopRoll"] = shop_roll
		if shop_roll < 0.10:
			flow["shopCooldown"] = 6
			if not legacy_receipt:
				row["phaseShopCooldownAfter"] = 6
			return 1
	if not legacy_receipt:
		row["phaseShopCooldownAfter"] = int(flow.get("shopCooldown", 0))
	return 0


func _prepare_normal_flow(candidate: Dictionary) -> Dictionary:
	var pins: Dictionary = _normal_replay_source_pins if not _normal_replay_source_pins.is_empty() \
		else _normal_draw_policy.source_pins()
	if pins.is_empty():
		_normal_flow_error = _normal_draw_policy.last_error
		return {}
	var flow: Dictionary = candidate.get("normalFlow", {})
	if flow.is_empty():
		var seed := _normal_replay_seed if _normal_replay_seed > 0 else \
			int(candidate.get("marketRngState", {}).get("initialSeed", 0))
		if seed <= 0 or seed >= 2147483647:
			var identity := "%s|%s|%s" % [_slot_id,
				String(candidate.get("runClock", {}).get("lifeId", "")),
				String(candidate.get("path", ""))]
			seed = 1 + absi(int(identity.hash())) % 2147483646
		flow = {"version": 1, "sourcePins": pins,
			"flowRuleSha": NormalDrawPolicy.FLOW_DIRECTOR_JS_SHA,
			"cardRuleSha": NormalDrawPolicy.CARD_SYSTEM_JS_SHA,
			"choiceRuleSha": LEGACY_GAME_LOGIC_JS_SHA if _normal_choice_pin_activation_index > 0 \
				and int(candidate.get("runClock", {}).get("decisionIndex", 0)) \
				< _normal_choice_pin_activation_index else NormalChoicePolicy.GAME_LOGIC_JS_SHA,
			"stateRuleSha": NormalChoicePolicy.GAME_STATE_JS_SHA,
			"effectRuleSha": NormalChoicePolicy.EFFECT_SERVICE_JS_SHA,
			"randomMode": "fixed" if _normal_roll_override >= 0.0 else "seeded",
			"fixedRoll": _normal_roll_override if _normal_roll_override >= 0.0 else null,
			"initialSeed": seed, "rngState": seed, "draws": []}
	elif flow.get("version") == 1 \
			and flow.get("sourcePins") == _normal_draw_policy.legacy_source_pins() \
			and _normal_replay_source_pins.is_empty():
		flow["sourcePins"] = pins
	elif flow.get("version") != 1 or flow.get("sourcePins") != pins:
		_normal_flow_error = "ordinary draw source changed"
		return {}
	if candidate.get("realm") == "golden":
		var golden_sha: String = _content.source_sha256("cards:golden")
		if golden_sha.length() != 64 or flow.has("goldenSourceSha") \
				and flow.goldenSourceSha != golden_sha:
			_normal_flow_error = "golden draw source changed"
			return {}
		flow["goldenSourceSha"] = golden_sha
	if candidate.get("realm") == "nascent":
		var nascent_sha: String = _content.source_sha256("cards:nascent")
		if nascent_sha.length() != 64 or flow.has("nascentSourceSha") \
				and flow.nascentSourceSha != nascent_sha:
			_normal_flow_error = "nascent draw source changed"
			return {}
		flow["nascentSourceSha"] = nascent_sha
	if candidate.get("realm") == "deity":
		var deity_sha: String = _content.source_sha256("cards:deity")
		if deity_sha.length() != 64 or flow.has("deitySourceSha") \
				and flow.deitySourceSha != deity_sha:
			_normal_flow_error = "deity draw source changed"
			return {}
		flow["deitySourceSha"] = deity_sha
	if candidate.get("realm") == "tribulation":
		var tribulation_sha: String = _content.source_sha256("cards:tribulation")
		if tribulation_sha.length() != 64 or flow.has("tribulationSourceSha") \
				and flow.tribulationSourceSha != tribulation_sha:
			_normal_flow_error = "tribulation draw source changed"
			return {}
		flow["tribulationSourceSha"] = tribulation_sha
	if not flow.has("priorityChecks") and not _legacy_priority_replay:
		flow["priorityChecks"] = []
		flow["shopCooldown"] = 0
		flow["priorityCampSourceSha"] = _content.source_sha256("cards:camp")
	if flow.has("priorityChecks") and (
			not flow["priorityChecks"] is Array
			or not _pinned_source_matches("cards:camp",
				String(flow.get("priorityCampSourceSha", "")))):
		_normal_flow_error = "priority encounter source changed"
		return {}
	candidate["normalFlow"] = flow
	return flow


func _check_prepriority_encounters(candidate: Dictionary) -> Dictionary:
	_normal_flow_error = ""
	if _legacy_priority_replay:
		return candidate
	var turn := int(candidate.get("turn", 0))
	var previous: Dictionary = candidate.get("normalFlow", {})
	var cooldown := int(previous.get("shopCooldown", 0))
	if turn % 8 != 0 and turn % 15 != 0 and cooldown <= 0:
		return candidate
	var next: Dictionary = candidate.duplicate(true)
	var flow: Dictionary = _prepare_normal_flow(next)
	if flow.is_empty():
		return {}
	var card_count := _flow_card_count + 1
	var row_index: int = flow["priorityChecks"].size()
	var recorded: Dictionary = {}
	if row_index < _normal_replay_priority_checks.size():
		var value: Variant = _normal_replay_priority_checks[row_index]
		if not value is Dictionary or value.get("cardCount") != card_count \
				or value.get("turn") != turn:
			_normal_flow_error = "priority encounter replay receipt mismatch"
			return {}
		recorded = value
	var row := {"cardCount": card_count, "turn": turn,
		"cooldownBefore": cooldown}
	if cooldown > 0:
		flow["shopCooldown"] = cooldown - 1
	elif turn % 8 == 0:
		var shop_roll := _sample_normal_roll(flow, recorded, "p25ShopRoll")
		if shop_roll < 0.0:
			_normal_flow_error = "P25 shop roll differs from seed"
			return {}
		row["p25ShopRoll"] = shop_roll
		if shop_roll < 0.10:
			flow["shopCooldown"] = 6
			if not _sample_discarded_shop(next, flow, recorded, row):
				return {}
			row["cooldownAfter"] = 6
			if not recorded.is_empty() and JSON.parse_string(JSON.stringify(row)) != recorded:
				_normal_flow_error = "priority shop replay receipt mismatch"
				return {}
			flow["priorityChecks"].append(row)
			next["normalFlow"] = flow
			return _pending_shop(next, "priority:25")
	if turn % 15 == 0:
		var camp_roll := _sample_normal_roll(flow, recorded, "p24CampRoll")
		if camp_roll < 0.0:
			_normal_flow_error = "P24 camp roll differs from seed"
			return {}
		row["p24CampRoll"] = camp_roll
		if camp_roll < 0.30:
			if _camp_flow.card().is_empty():
				_normal_flow_error = _camp_flow.last_error
				return {}
			next["phase"] = "CAMP_PENDING"
			next["currentCardId"] = CampFlow.CARD_ID
	row["cooldownAfter"] = int(flow.get("shopCooldown", 0))
	if not recorded.is_empty() and JSON.parse_string(JSON.stringify(row)) != recorded:
		_normal_flow_error = "priority encounter replay receipt mismatch"
		return {}
	flow["priorityChecks"].append(row)
	next["normalFlow"] = flow
	return next


func _sample_discarded_shop(candidate: Dictionary, flow: Dictionary,
		recorded: Dictionary, row: Dictionary) -> bool:
	var pins: Dictionary = _regulated_catalog.source_pins()
	if pins.is_empty():
		_normal_flow_error = "regulated catalog source unavailable"
		return false
	var counter := [0]
	var offers: Array = _regulated_catalog.generate_for_realm(candidate, func() -> float:
		var key := "shopPrefetchRoll%d" % counter[0]
		counter[0] += 1
		var value := _sample_normal_roll(flow, recorded, key)
		row[key] = value
		return value, flow.get("shopPillPrices", {}))
	if offers.is_empty():
		_normal_flow_error = "regulated catalog draw invalid: " + _regulated_catalog.last_error
		return false
	var prices := {}
	for offer in offers:
		if offer.get("type") == "pill":
			prices[offer["id"]] = offer["price"]
	var cumulative: Dictionary = flow.get("shopPillPrices", {}).duplicate(true)
	for pill_id in prices:
		cumulative[pill_id] = prices[pill_id]
	flow["shopPillPrices"] = cumulative
	row["shopPrefetchIds"] = offers.map(func(offer: Dictionary) -> Variant:
		return offer.get("id"))
	row["shopCatalogPins"] = pins
	flow["shopCatalogPins"] = pins
	flow["pendingShopDiscarded"] = {"pillPrices": prices,
		"offerIds": row["shopPrefetchIds"].duplicate(true)}
	return true


func _pending_shop(candidate: Dictionary, source: String) -> Dictionary:
	if _regulated_catalog.card(candidate).is_empty():
		_normal_flow_error = _regulated_catalog.last_error
		return {}
	candidate["phase"] = "SHOP_PENDING"
	candidate["currentCardId"] = RegulatedCatalog.CARD_ID
	var prior_checkpoint: Dictionary = candidate.get("decisionCheckpoint") \
		if candidate.get("decisionCheckpoint") is Dictionary else {}
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": RegulatedCatalog.CARD_ID,
		"sourceCardId": prior_checkpoint.get("sourceCardId"),
		"turn": candidate["turn"], "decisionIndex": candidate["runClock"]["decisionIndex"],
		"flowSource": source}
	return candidate


func _normal_next_roll(flow: Dictionary) -> float:
	var state_value := int(flow.get("rngState", 1))
	state_value = int((int(state_value) * 48271) % 2147483647)
	flow["rngState"] = state_value
	return float(state_value) / 2147483647.0


func _sample_normal_roll(flow: Dictionary, recorded: Dictionary, key: String) -> float:
	var generated := _normal_next_roll(flow)
	var expected := float(flow.get("fixedRoll", -1.0)) if flow.get("randomMode") == "fixed" \
		else generated
	if expected < 0.0 or expected >= 1.0:
		return -1.0
	if not recorded.is_empty():
		var saved_roll: Variant = recorded.get(key)
		if not (saved_roll is float or saved_roll is int) \
				or not is_equal_approx(float(saved_roll), expected):
			return -1.0
	return expected


func _source_for_card(next: Dictionary) -> String:
	match String(next.get("phase", "")):
		"COMBAT_HANDOFF": return "combat"
		"MILESTONE_PENDING": return "milestone"
		"QUEST_PENDING": return "quest"
		"KARMA_PENDING": return "karma"
		"MARKET_PENDING", "SHOP_PENDING", "VENDOR_OPEN":
			if next.get("phase") == "SHOP_PENDING" and next.get(
					"currentCardId") == "q_market":
				var draws: Array = next.get("normalFlow", {}).get("draws", [])
				return String(draws.back().get("source", "normal")) if not draws.is_empty() \
					else "normal"
			return "shop"
		"CAMP_PENDING": return "exploration"
		"MENTOR_PENDING", "EMERGENT_PENDING", "THREAD_PENDING", "LOCATION_PENDING", "CHOICE_ECHO_PENDING", "ALLY_PENDING", "COMPANION_ARC_PENDING", "SEER_PENDING", "SURFACING_PENDING", "COMPANION_PENDING": return "narrative"
		"FACTION_PENDING": return "narrative"
		"NPC_PENDING", "NPC_CROSS_PENDING": return "narrative"
	return "normal"


func _tick_normal_starvation(source: String) -> void:
	for name in ["normal", "lightStory", "story", "shop", "exploration",
			"combat", "combatLight", "challenge", "reward", "narrative",
			"karma", "quest", "milestone"]:
		_normal_starvation[name] = int(_normal_starvation.get(name, 0)) + 1
	_normal_starvation[source] = 0
	if source == "normal":
		_normal_starvation["lightStory"] = 0


func _normal_history_has_card(saved_normal: Variant, card_id: String) -> bool:
	if not saved_normal is Dictionary:
		return false
	for row in saved_normal.get("draws", []):
		if row is Dictionary and row.get("cardId") == card_id:
			return true
	return false


func _choose_normal(direction: String) -> bool:
	var card: Dictionary = get_current_card()
	if _realm_gate_flow.upper_normal_choice_available(state, direction) \
			and card == _realm_gate_flow._upper_source_card(String(card.get("id", ""))):
		var upper_candidate: Dictionary = _realm_gate_flow.settle_upper(state, direction, true)
		if upper_candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(
				upper_candidate):
			return false
		return _commit_encounter_transition(upper_candidate, "UPPER_REALM_CHOSEN")
	if card.get("id") == "pa_ending_reform" and direction == "left" \
			and state.get("flags", {}).get("post_ascension_active") == true:
		return _commit_rebirth_candidate(_rebirth_flow.upper_new_life(state,
			card, direction, _slot_id), direction)
	if card.is_empty() or not _normal_choice_policy.choice_available(
			state, card, direction):
		return false
	if card.get("id") in ["q_fellow", "f_mission"] and direction == "right":
		return _commit_encounter_transition(_encounter_flow.accept(state), "ENCOUNTER_WARNING")
	if card.get("id") == "ds_female_bandit" and direction == "left":
		return _commit_encounter_transition(_encounter_flow.accept(state), "ENCOUNTER_WARNING")
	if card.get("id") in ["n_hunt", "ar_boss", "it_combat"] and direction == "left":
		return _commit_encounter_transition(_encounter_flow.accept(state), "ENCOUNTER_WARNING")
	if card.get("id") == FoundationDungeonFlow.NODE_CARDS["boss"]:
		var boss_state := state.duplicate(true)
		boss_state["pendingDungeonBossDirection"] = direction
		return _commit_encounter_transition(_encounter_flow.accept(boss_state),
			"ENCOUNTER_WARNING")
	if int(state.get("lifeCount", 0)) > 0 and (
			card.get("id") == "q_shop" and direction == "up"):
		return false
	var candidate: Dictionary = _normal_choice_policy.settle(state,
		String(card["id"]), direction)
	if candidate.is_empty():
		return false
	if card.get("id") == "ds_female_bandit" and direction == "right":
		var skill_flow := SkillOpportunity.new(_content)
		var offer: Dictionary = skill_flow.preview(candidate)
		if offer.is_empty():
			return false
		if offer.get("eligible") == true:
			var normal_flow: Dictionary = candidate.get("normalFlow", {})
			if normal_flow.is_empty():
				return false
			candidate = skill_flow.resolve(candidate,
				int(state.runClock.decisionIndex) + 1,
				_normal_next_roll(normal_flow))
			if candidate.is_empty():
				return false
	var next_index := int(state["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"],
		card["id"], next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return false
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": card["id"], "kind": "choice"}
	var tags: Array = card.get("tags", [])
	_append_choice_record(candidate, {"cardId": card["id"],
		"cardType": card.get("type"), "direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": tags.duplicate(true)})
	for tag in tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(card["id"])
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	if card.get("choices", {}).get(
			direction, {}).has("karmaSeed"):
		var authored_seed: Variant = card.choices[direction].karmaSeed
		var seeds: Array = authored_seed if authored_seed is Array else [authored_seed]
		for seed in seeds:
			var one_choice: Dictionary = card.choices[direction].duplicate(true)
			one_choice["karmaSeed"] = seed
			if not _milestone_flow._plant_seed(candidate, card, one_choice,
					direction, next_index):
				return false
	MilestoneFlow.tick_seeds(candidate)
	if card.get("id") == "q_cave" and direction == "right":
		if not _cave_flow.enter(candidate, card, next_index):
			return false
		if int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			if not _cave_flow.complete(candidate, "failure", next_index):
				return false
			return _commit_dungeon_fatal_or_revived(candidate, "q_cave")
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if card.get("id") == "f_trial" and direction == "right":
		if not _foundation_dungeon_flow.enter(candidate, card, next_index):
			return false
		if int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			if not _foundation_dungeon_flow.complete(candidate, "failure", next_index):
				return false
			return _commit_dungeon_fatal_or_revived(candidate, "f_trial")
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if card.get("id") in GoldenDungeonFlow.ENTRIES and card.get(
			"choices", {}).get(direction, {}).has("dungeon"):
		if not _golden_dungeon_flow.enter(candidate, card, direction, next_index):
			return false
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if card.get("id") == NascentCaveFlow.ENTRY_CARD_ID and direction == "left":
		if not _nascent_cave_flow.enter(candidate, card, direction, next_index):
			return false
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if card.get("id") == NascentRuinsFlow.ENTRY_CARD_ID and direction == "left":
		if not _nascent_ruins_flow.enter(candidate, card, direction, next_index):
			return false
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if HigherDungeonFlow.ENTRIES.has(card.get("id")) and direction == "left":
		if not _higher_dungeon_flow.enter(candidate, card, direction, next_index):
			return false
		return _commit_encounter_transition(candidate, "DUNGEON_ENTERED")
	if card.has("_dungeonId"):
		var dungeon_flow: RefCounted = _nascent_cave_flow if card.get(
			"_dungeonId") == NascentCaveFlow.DUNGEON_ID else (
			_nascent_ruins_flow if card.get("_dungeonId") == NascentRuinsFlow.DUNGEON_ID
			else _higher_dungeon_flow if HigherDungeonFlow.REALMS.has(card.get(
				"_dungeonId")) else _golden_dungeon_flow)
		if int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			if not dungeon_flow.complete(candidate, "failure", next_index):
				return false
			return _commit_dungeon_fatal_or_revived(candidate, String(card.id))
		if not dungeon_flow.advance(candidate, String(card.id), next_index):
			return false
		return _commit_encounter_transition(candidate, "DUNGEON_ADVANCED")
	if card.get("id") in CaveFlow.NODE_IDS:
		var cult_roll := 0.0
		var stone_roll := 0.0
		if card.get("id") == "cave_reward":
			var normal_flow: Dictionary = candidate.get("normalFlow", {})
			if normal_flow.is_empty():
				return false
			cult_roll = _normal_next_roll(normal_flow)
			stone_roll = _normal_next_roll(normal_flow)
		if not _cave_flow.advance(candidate, String(card["id"]), next_index,
				cult_roll, stone_roll):
			return false
		if int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			return _commit_dungeon_fatal_or_revived(candidate, String(card["id"]))
		return _commit_encounter_transition(candidate, "DUNGEON_ADVANCED")
	if card.get("id") in FoundationDungeonFlow.NODE_CARDS.values() \
			or card.get("id") == FoundationDungeonFlow.FORK_CARD_ID:
		var cult_roll := -1.0
		var stone_roll := -1.0
		if card.get("id") == "realm_treasure":
			var normal_flow: Dictionary = candidate.get("normalFlow", {})
			if normal_flow.is_empty():
				return false
			cult_roll = _normal_next_roll(normal_flow)
			stone_roll = _normal_next_roll(normal_flow)
		if not _foundation_dungeon_flow.advance(candidate, String(card["id"]),
				direction, next_index, cult_roll, stone_roll):
			return false
		if int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			if not _foundation_dungeon_flow.complete(candidate, "failure", next_index):
				return false
			return _commit_dungeon_fatal_or_revived(candidate, String(card["id"]))
		return _commit_encounter_transition(candidate, "DUNGEON_ADVANCED")
	if int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
			or int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
			or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
		var revival: Dictionary = TreasureAcquisition.new(
			_content).revive_equipped(candidate)
		if revival.is_empty():
			return false
		if revival.get("revived") == true:
			candidate = revival["state"]
		else:
			candidate["phase"] = "NORMAL_PENDING"
			return _commit_dungeon_fatal_or_revived(candidate, String(card["id"]))
	if card.get("id") == "dp_demon_recruit_again" and direction == "left":
		candidate["authoredNormalNext"] = {"cardId": "dp_demon_truth",
			"sourceCardId": "dp_demon_recruit_again"}
	var pending_remove: bool = card.get("id") in ["q_shop", "f_shop", "g_shop"] \
		and direction == "up"
	candidate["phase"] = "CAMP_TARGET_PENDING" if pending_remove else "FLOW_PENDING"
	candidate["currentCardId"] = card["id"] if pending_remove else ""
	if pending_remove:
		candidate["pendingCampAction"] = "remove"
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": card["id"] if pending_remove else null,
		"sourceCardId": card["id"], "turn": next_index,
		"decisionIndex": next_index, "flowPending": not pending_remove}
	return _commit_encounter_transition(candidate, "NORMAL_CHOSEN")


func _commit_dungeon_fatal_or_revived(candidate: Dictionary,
		source_card_id: String) -> bool:
	var revival: Dictionary = TreasureAcquisition.new(
		_content).revive_equipped(candidate)
	if revival.is_empty():
		return false
	if revival.get("revived") == true:
		return _commit_encounter_transition(revival["state"], "DUNGEON_ADVANCED")
	var fatal: Dictionary = _death_flow.prepare_death(candidate, source_card_id)
	return _commit_encounter_transition(fatal, "DEATH_NARRATIVE") \
		if not fatal.is_empty() else false


func abandon_dungeon(expected_token: int) -> bool:
	var run: Variant = state.get("dungeonRun")
	if state.get("phase") != "NORMAL_PENDING" or not run is Dictionary \
			or run.get("status") != "active" or expected_token <= 0 \
			or expected_token != _choice_token:
		return false
	var candidate := state.duplicate(true)
	var decision := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	var dungeon_flow: RefCounted = _nascent_cave_flow if run.get(
		"dungeonId") == NascentCaveFlow.DUNGEON_ID else (
		_nascent_ruins_flow if run.get("dungeonId") == NascentRuinsFlow.DUNGEON_ID else (
		_higher_dungeon_flow if HigherDungeonFlow.REALMS.has(run.get(
			"dungeonId")) else (
		_golden_dungeon_flow if run.get("realm") == "golden" else (
		_foundation_dungeon_flow if run.get(
			"dungeonId") == FoundationDungeonFlow.DUNGEON_ID else _cave_flow))))
	if decision < 0 or not dungeon_flow.complete(candidate, "abandon", decision):
		return false
	var actions: Array = candidate.get("dungeonActionHistory", []).duplicate(true)
	actions.append({"kind": "abandon", "sessionId": run["sessionId"],
		"decisionIndex": decision})
	candidate["dungeonActionHistory"] = actions
	return _commit_encounter_transition(candidate, "DUNGEON_ABANDONED")


func _choose_death(direction: String) -> bool:
	if direction not in ["left", "right"]:
		return false
	var death_card: Dictionary = _death_flow.card(state)
	if death_card.is_empty():
		return false
	var candidate: Dictionary = _rebirth_flow.new_life(state, death_card,
		direction, _slot_id)
	return _commit_rebirth_candidate(candidate, direction)


func change_rebirth_tree(node_id: String, refund: bool = false) -> bool:
	var candidate := _lineage_action_candidate(state,
		"refund" if refund else "unlock", node_id)
	if candidate.is_empty():
		return false
	if _store != null:
		if not _store.has_method("commit_snapshot"):
			return false
		var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
	state = candidate
	changed.emit({"type": "REBIRTH_TREE_CHANGED", "nodeId": node_id,
		"refunded": refund})
	return true


func rebirth_tree_view() -> Dictionary:
	var tree: Variant = state.get("rebirthTree")
	var nodes: Dictionary = _lineage_flow.source_nodes()
	var source: Variant = _content.read_module("progression:rebirth_tree")
	if nodes.is_empty() or not _lineage_flow.valid_tree(tree) \
			or not source is Dictionary or not source.get("branches") is Array:
		return {}
	var unlocked: Array = tree.unlockedNodeIds
	var branches: Array = []
	for branch in source.branches:
		var projected: Dictionary = {"name": branch.get("name", ""),
			"description": branch.get("description", ""), "nodes": []}
		for node in branch.get("nodes", []):
			var id := String(node.get("id", ""))
			var owned: bool = unlocked.has(id)
			var refundable := owned
			for other in nodes.values():
				if unlocked.has(other.get("id")) and other.get("requires", []).has(id):
					refundable = false
			var ready := not owned and int(tree.insight) >= int(node.get("cost", 0))
			for required in node.get("requires", []):
				ready = ready and unlocked.has(required)
			projected.nodes.append({"id": id, "name": node.get("name", id),
				"effectText": node.get("effectText", ""),
				"cost": int(node.get("cost", 0)), "requires": node.get("requires", []),
				"unlocked": owned, "canUnlock": ready, "canRefund": refundable})
		branches.append(projected)
	return {"insight": int(tree.insight), "spentInsight": int(tree.spentInsight),
		"branches": branches, "lineageEntries": state.get("lineageEntries", []).duplicate(true)}


func boss_fragment_options() -> Array[Dictionary]:
	return _legacy_fragment_flow.boss_reward_options(state)


func legacy_focus_options() -> Array[Dictionary]:
	return _legacy_fragment_flow.focus_options(state)


func portrait_options(comp_id: String) -> Array[Dictionary]:
	var canonical: String = CompanionPortraits.canonical_id(comp_id)
	return CompanionPortraits.new(_content).unlocked(canonical,
		_portrait_affection(state, canonical))


func selected_portrait(comp_id: String, allow_intimate: bool = false) -> Dictionary:
	var canonical: String = CompanionPortraits.canonical_id(comp_id)
	return CompanionPortraits.new(_content).selected(state, canonical,
		_portrait_affection(state, canonical), allow_intimate)


func explicitly_selected_portrait_id(comp_id: String) -> String:
	var canonical: String = CompanionPortraits.canonical_id(comp_id)
	return String(state.get("companionCosmetics", {}).get(
		"selectedPortraitByNpc", {}).get(canonical, ""))


func _portrait_affection(run: Dictionary, comp_id: String) -> int:
	return int(run.get("npcAffection", {}).get(comp_id,
		run.get("npcEncounterScheduling", {}).get("affections", {}).get(
			comp_id, 0)))


func npc_roster() -> Array:
	return _npc_interaction_flow.roster(state)


func npc_panel(npc_id: String) -> Dictionary:
	return _npc_interaction_flow.panel(state, npc_id)


func interact_npc(npc_id: String, action: String, item_id: String = "") -> bool:
	if state.get("active") != true or _store == null \
			or not _store.has_method("commit_snapshot"):
		return false
	var candidate: Dictionary = _npc_interaction_flow.apply(state, npc_id,
		action, item_id)
	if candidate.is_empty():
		return false
	var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
	if committed.get("ok") != true:
		return false
	_store_revision = int(committed.get("revision", -1))
	state = candidate
	changed.emit({"type": "NPC_INTERACTION", "npcId": npc_id,
		"action": action, "result": candidate.npcInteractionHistory.back()})
	return true


func _replay_npc_interactions(saved: Dictionary, base: Dictionary,
		decision_index: int) -> Dictionary:
	var rows: Variant = saved.get("npcInteractionHistory", [])
	if not rows is Array:
		return {}
	var cursor: int = base.get("npcInteractionHistory", []).size()
	var candidate: Dictionary = base
	while cursor < rows.size():
		var row: Variant = rows[cursor]
		if not row is Dictionary or row.get("version") != 1 \
				or not _valid_integer(row.get("decisionIndex")) \
				or not row.get("npcId") is String \
				or not row.get("action") is String \
				or not row.get("itemId") is String:
			return {}
		if int(row.decisionIndex) > decision_index:
			break
		if int(row.decisionIndex) < decision_index \
				or row.get("lifeId") != candidate.get("runClock", {}).get("lifeId"):
			return {}
		if row.get("phase") != candidate.get("phase") \
				or row.get("cardId") != candidate.get("currentCardId"):
			break
		candidate = _npc_interaction_flow.apply(candidate, String(row.npcId),
			String(row.action), String(row.itemId))
		if candidate.is_empty() or JSON.parse_string(JSON.stringify(
			candidate.npcInteractionHistory.back())) != row:
			return {}
		cursor += 1
	return candidate


func select_portrait(comp_id: String, stage_id: String) -> bool:
	var canonical: String = CompanionPortraits.canonical_id(comp_id)
	var candidate := _portrait_candidate(state, canonical, stage_id)
	if candidate.is_empty() or _store == null \
			or not _store.has_method("commit_snapshot"):
		return false
	var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
	if committed.get("ok") != true:
		return false
	_store_revision = int(committed.get("revision", -1))
	state = candidate
	changed.emit({"type": "COMPANION_PORTRAIT_SELECTED",
		"companionId": canonical, "stageId": stage_id})
	return true


func _portrait_candidate(base: Dictionary, comp_id: String,
		stage_id: String) -> Dictionary:
	if base.get("active") != true or not base.get("runClock") is Dictionary:
		return {}
	comp_id = CompanionPortraits.canonical_id(comp_id)
	var stages := CompanionPortraits.new(_content).unlocked(comp_id,
		_portrait_affection(base, comp_id))
	var found := false
	for stage in stages:
		if stage.id == stage_id:
			found = true
			break
	if not found:
		return {}
	var candidate := base.duplicate(true)
	var cosmetics: Dictionary = candidate.get("companionCosmetics", {}).duplicate(true)
	var selected: Dictionary = cosmetics.get("selectedPortraitByNpc", {}).duplicate(true)
	if selected.get(comp_id) == stage_id:
		return {}
	selected[comp_id] = stage_id
	cosmetics["selectedPortraitByNpc"] = selected
	candidate["companionCosmetics"] = cosmetics
	var actions: Array = candidate.get("companionPortraitHistory", []).duplicate(true)
	actions.append({"version": 1, "compId": comp_id, "stageId": stage_id,
		"decisionIndex": int(base.runClock.decisionIndex),
		"lifeId": base.runClock.lifeId, "phase": base.get("phase"),
		"cardId": base.get("currentCardId")})
	candidate["companionPortraitHistory"] = actions
	return candidate


func _replay_portrait_actions(saved: Dictionary, base: Dictionary,
		decision_index: int) -> Dictionary:
	var rows: Variant = saved.get("companionPortraitHistory", [])
	if not rows is Array:
		return {}
	var cursor: int = base.get("companionPortraitHistory", []).size()
	if cursor >= rows.size():
		return base
	var candidate := base.duplicate(true)
	while cursor < rows.size():
		var row: Variant = rows[cursor]
		if not row is Dictionary or row.get("version") != 1 \
				or not _valid_integer(row.get("decisionIndex")) \
				or not row.get("compId") is String \
				or not row.get("stageId") is String:
			return {}
		if int(row.decisionIndex) > decision_index:
			break
		if int(row.decisionIndex) < decision_index:
			return {}
		if row.get("phase") != candidate.get("phase") \
				or row.get("cardId") != candidate.get("currentCardId"):
			break
		if row.get("lifeId") != candidate.get("runClock", {}).get("lifeId"):
			return {}
		candidate = _portrait_candidate(candidate, String(row.compId),
			String(row.stageId))
		if candidate.is_empty() or JSON.parse_string(JSON.stringify(
			candidate.companionPortraitHistory.back())) != row:
			return {}
		cursor += 1
	return candidate


func set_legacy_focus(set_id: String) -> bool:
	var candidate := _legacy_focus_candidate(state, set_id)
	if candidate.is_empty():
		return false
	if _store != null:
		if not _store.has_method("commit_snapshot"):
			return false
		var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
	state = candidate
	changed.emit({"type": "LEGACY_FOCUS_CHANGED", "setId": set_id})
	return true


func _legacy_focus_candidate(base: Dictionary, set_id: String) -> Dictionary:
	if base.get("active") != true or not base.get("runClock") is Dictionary:
		return {}
	var candidate := base.duplicate(true)
	if not _legacy_fragment_flow.set_focus(candidate, set_id):
		return {}
	var actions: Array = candidate.get("legacyFocusActions", []).duplicate(true)
	actions.append({"setId": set_id, "decisionIndex": int(base.runClock.decisionIndex),
		"lifeId": base.runClock.lifeId, "phase": base.get("phase"),
		"cardId": base.get("currentCardId")})
	candidate["legacyFocusActions"] = actions
	return candidate


func _replay_legacy_focus_actions(saved: Dictionary, base: Dictionary,
		decision_index: int) -> Dictionary:
	var rows: Variant = saved.get("legacyFocusActions", [])
	if not rows is Array:
		return {}
	var cursor: int = base.get("legacyFocusActions", []).size()
	if cursor >= rows.size():
		return base
	var candidate := base.duplicate(true)
	while cursor < rows.size():
		var row: Variant = rows[cursor]
		if not row is Dictionary or not _valid_integer(row.get("decisionIndex")):
			return {}
		if int(row.decisionIndex) > decision_index:
			break
		if int(row.decisionIndex) < decision_index:
			return {}
		if row.get("phase") != candidate.get("phase") \
				or row.get("cardId") != candidate.get("currentCardId"):
			break
		if row.get("lifeId") != candidate.get("runClock", {}).get("lifeId"):
			return {}
		candidate = _legacy_focus_candidate(candidate, String(row.get("setId", "")))
		if candidate.is_empty() or JSON.parse_string(JSON.stringify(
				candidate.legacyFocusActions.back())) != row:
			return {}
		cursor += 1
	return candidate


func claim_boss_fragment(set_id: String) -> bool:
	var candidate := _boss_claim_candidate(state, set_id)
	if candidate.is_empty():
		return false
	if _store != null:
		if not _store.has_method("commit_snapshot"):
			return false
		var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
	state = candidate
	changed.emit({"type": "BOSS_FRAGMENT_CLAIMED", "setId": set_id})
	return true


func _boss_claim_candidate(base: Dictionary, set_id: String) -> Dictionary:
	if base.get("active") != true or not base.get("runClock") is Dictionary:
		return {}
	var candidate := base.duplicate(true)
	var pending: Variant = candidate.get("legacyRunState", {}).get("pendingBossFragmentReward")
	if not pending is Dictionary or not _legacy_fragment_flow.claim_boss_reward(
			candidate, set_id):
		return {}
	var actions: Array = candidate.get("bossFragmentClaimActions", []).duplicate(true)
	actions.append({"setId": set_id, "encounterInstanceId": pending.encounterInstanceId,
		"decisionIndex": int(base.runClock.decisionIndex), "lifeId": base.runClock.lifeId,
		"phase": base.get("phase"), "cardId": base.get("currentCardId")})
	candidate["bossFragmentClaimActions"] = actions
	if not candidate.has("bossRewardActivationIndex") and not _replaying_history:
		candidate["bossRewardActivationIndex"] = _boss_reward_activation_index
	return candidate


func _replay_boss_claims(saved: Dictionary, base: Dictionary,
		decision_index: int) -> Dictionary:
	var rows: Variant = saved.get("bossFragmentClaimActions", [])
	if not rows is Array:
		return {}
	var cursor: int = base.get("bossFragmentClaimActions", []).size()
	if cursor >= rows.size():
		return base
	var candidate := base.duplicate(true)
	while cursor < rows.size():
		var row: Variant = rows[cursor]
		if not row is Dictionary or not _valid_integer(row.get("decisionIndex")):
			return {}
		if int(row.decisionIndex) > decision_index:
			break
		if int(row.decisionIndex) < decision_index:
			return {}
		if row.get("phase") != candidate.get("phase") \
				or row.get("cardId") != candidate.get("currentCardId"):
			break
		var pending: Variant = candidate.get("legacyRunState", {}).get(
			"pendingBossFragmentReward")
		if not pending is Dictionary or pending.get("encounterInstanceId") != row.get(
				"encounterInstanceId") or row.get("lifeId") != candidate.get(
				"runClock", {}).get("lifeId"):
			return {}
		candidate = _boss_claim_candidate(candidate, String(row.get("setId", "")))
		if candidate.is_empty() or JSON.parse_string(JSON.stringify(
				candidate.bossFragmentClaimActions.back())) != row:
			return {}
		cursor += 1
	return candidate


func _lineage_action_candidate(base: Dictionary, kind: String,
		node_id: String) -> Dictionary:
	if base.get("active") != true or not base.get("rebirthTreeActions") is Array \
			or not base.get("runClock") is Dictionary:
		return {}
	var candidate: Dictionary = _lineage_flow.refund(base, node_id) \
		if kind == "refund" else _lineage_flow.unlock(base, node_id) \
		if kind == "unlock" else {}
	if candidate.is_empty():
		return {}
	candidate.rebirthTreeActions.append({"kind": kind, "nodeId": node_id,
		"decisionIndex": int(base.runClock.decisionIndex),
		"lifeId": base.runClock.lifeId,
		"phase": base.get("phase"), "cardId": base.get("currentCardId")})
	return candidate


func _replay_lineage_actions(saved: Dictionary, base: Dictionary,
		decision_index: int) -> Dictionary:
	var rows: Variant = saved.get("rebirthTreeActions", [])
	if not rows is Array:
		return {}
	var candidate := base.duplicate(true)
	var cursor: int = candidate.get("rebirthTreeActions", []).size()
	while cursor < rows.size():
		var row: Variant = rows[cursor]
		if not row is Dictionary or not _valid_integer(row.get("decisionIndex")):
			return {}
		if int(row.decisionIndex) > decision_index:
			break
		if int(row.decisionIndex) < decision_index:
			return {}
		if row.get("phase") != candidate.get("phase") \
				or row.get("cardId") != candidate.get("currentCardId"):
			break
		candidate = _lineage_action_candidate(candidate, String(row.get(
			"kind", "")), String(row.get("nodeId", "")))
		if candidate.is_empty() or JSON.parse_string(JSON.stringify(
				candidate.rebirthTreeActions.back())) != row:
			return {}
		cursor += 1
	candidate = _replay_legacy_focus_actions(saved, candidate, decision_index)
	candidate = _replay_portrait_actions(saved, candidate, decision_index)
	return _replay_boss_claims(saved, candidate, decision_index) \
		if not candidate.is_empty() else {}


func _commit_rebirth_candidate(candidate: Dictionary, direction: String) -> bool:
	if candidate.is_empty():
		return false
	if _store != null:
		if not _store.has_method("commit_life_transition"):
			return false
		var committed: Dictionary = _store.commit_life_transition(candidate,
			_store_revision, direction)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
	state = candidate
	_reset_new_life_runtime()
	_current_card_id = "rebirth_boon"
	_choice_token += 1
	changed.emit({"type": "REBIRTH_PATH_REQUIRED", "cardId": _current_card_id,
		"lifeCount": candidate["lifeCount"]})
	return true


func _choose_voluntary_rebirth() -> bool:
	var warning_card: Dictionary = _encounter_flow.warning_card(state)
	var candidate: Dictionary = _rebirth_flow.voluntary_new_life(state,
		warning_card, _slot_id)
	return _commit_rebirth_candidate(candidate, "right")


func _reset_new_life_runtime() -> void:
	# Source resetForNewLife replaces per-life systems. A live reincarnation
	# must begin with the same runtime cursors as a cold restored new life.
	_mentor_state = MentorFlow.initial_state()
	_story_thread_flow.activation_index = 1
	_story_thread_flow.upgrade_index = 1
	_story_thread_flow.village_activation_index = 1
	_story_thread_flow.sword_activation_index = 1
	_story_thread_flow.mist_activation_index = 1
	_story_thread_flow.higher_activation_index = 1
	_story_thread_flow.last_lesson_activation_index = 1
	_normal_replay_seed = 0
	_normal_replay_draws = []
	_normal_replay_priority_checks = []
	_normal_replay_shop_entries = []
	_normal_replay_source_pins = {}
	_normal_choice_pin_activation_index = 0
	_market_skip_seed_tick_activation_index = 0
	_flow_card_count = 0
	_normal_starvation = {}
	_normal_flow_error = ""
	_legacy_priority_replay = false
	_legacy_mentor_replay = false
	_legacy_mentor_stage_replay = false
	_legacy_mentor_heir_replay = false
	_mentor_heir_activation_index = 0
	_legacy_mentor_climax_replay = false
	_legacy_faction_collection_replay = false
	_faction_collection_new_activation_index = 0
	_mentor_climax_activation_index = 0
	_scene_activation_index = 0
	_echo_activation_index = 0
	_ally_activation_index = 0
	_companion_arc_activation_index = 0
	_seer_activation_index = 0
	_surfacing_activation_index = 0
	_companion_activation_index = 0
	_companion_milestone_activation_index = 0
	_narrative_admission_activation_index = 0
	_legacy_karma_replay = false
	_legacy_karma_order_replay = false
	_legacy_deck_replay = false
	_legacy_fragment_replay = false
	_legacy_fragment_replay_activation_index = -1
	_legacy_fragment_replay_initial_seed = 0
	_boss_reward_activation_index = 0
	_boss_reward_marker_present = false
	_legacy_wheel_replay = false
	_legacy_wheel_replay_activation_index = -1
	_legacy_wheel_replay_initial_seed = 0
	_legacy_lifespan_replay = false
	_legacy_market_replay = false
	_legacy_market_replay_activation_index = -1
	_legacy_market_replay_initial_seed = 0
	_legacy_ripple_replay = false
	_legacy_ripple_replay_activation_index = -1
	_legacy_ripple_replay_initial_seed = 0
	_legacy_hint_replay = false
	_legacy_hint_replay_activation_index = -1
	_legacy_hint_replay_initial_seed = 0
	_hint_flow.legacy_life_count = false
	_q_market_choice_activation_index = 0
	_combat_scheduling_activation_index = 0
	_cadence_activation_index = 0
	_cadence_high_upgrade_index = 0
	_path_skill_activation_index = 1
	_path_skill_replay_marker_present = false
	_passive_regen_extension_activation_index = 1
	_passive_regen_extension_replay_marker_present = false
	_early_avoid_activation_index = 1
	_early_avoid_replay_marker_present = false
	_npc_activation_index = 0
	_npc_general_activation_index = 0
	_npc_encounter_flow.roll_override_sequence = []
	_npc_cross_activation_index = 0
	_npc_cross_dynamic_activation_index = 0
	_npc_cross_flow.roll_override_sequence = []
	_avoid_flow.legacy_replay = false
	_avoid_flow.legacy_schema_replay = false
	_avoid_flow.legacy_lifespan_replay = false
	_quest_flow.legacy_entry_replay = false
	_causal_fact_clock.activation_index = 1
	_regulated_vendor.causal_activation_index = 0
	_market_flow.ghost_plan_activation_index = 1
	_market_flow.rebirth_archive_verified = true
	_ghost_vendor_flow.trust_rebirth_archive()
	_trade_route_flow.activation_index = 1
	_trade_route_flow.legacy_initial_trusted = true


func _choose_rebirth_boon(direction: String) -> bool:
	if direction not in ["left", "right", "down"]:
		return false
	var candidate: Dictionary = _rebirth_flow.settle_boon(state, direction)
	var source_hash: String = _battle_gateway.source_content_hash()
	if candidate.is_empty() or source_hash.length() != 64:
		return false
	candidate["noncombatFlow"] = {"version": 1,
		"scope": "rebirth_new_life", "sourceContentHash": source_hash,
		"karmaClockVersion": 1, "lifespanCostVersion": 1}
	if _cadence_activation_index == 0:
		var director: Dictionary = _cadence_flow.initial_state(int(candidate.get("lifeCount", -1)))
		if director.is_empty():
			return false
		candidate["noncombatFlow"]["encounterDirectorState"] = director
	return _commit_encounter_transition(candidate, "REBIRTH_BOON_CHOSEN") \
		if not candidate.is_empty() else false


func select_rebirth_path(path_id: String) -> bool:
	var candidate: Dictionary = _rebirth_flow.select_path(state, path_id)
	var bundle: Dictionary = _rebirth_path_bundle(path_id)
	if candidate.is_empty() or bundle.is_empty():
		return false
	if _store != null:
		if not _store.has_method("commit_snapshot"):
			return false
		var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
	_install_rebirth_path_bundle(bundle)
	state = candidate
	_choice_token += 1
	changed.emit({"type": "REBIRTH_PATH_SELECTED", "cardId": "rebirth_boon",
		"path": path_id, "lifeCount": candidate["lifeCount"]})
	return true


func _open_last_lesson_vendor() -> bool:
	if not _vendor_state_committed():
		return false
	var candidate := state.duplicate(true)
	var flow: Dictionary = _prepare_normal_flow(candidate)
	if flow.is_empty():
		return false
	flow["shopEntries"] = flow.get("shopEntries", []).duplicate(true)
	var index: int = flow.shopEntries.size()
	var saved_row: Dictionary = {}
	if index < _normal_replay_shop_entries.size():
		if not _normal_replay_shop_entries[index] is Dictionary:
			return false
		saved_row = _normal_replay_shop_entries[index]
	var row := {"decisionIndex": int(candidate.runClock.decisionIndex) + 1,
		"cardId": LastLessonVendor.ENTRY_ID}
	var counter := [0]
	var offers: Array = _regulated_catalog.generate_for_realm(candidate,
		func() -> float:
			var key := "lessonEntryRoll%d" % counter[0]
			counter[0] += 1
			var value := _sample_normal_roll(flow, saved_row, key)
			row[key] = value
			return value, flow.get("shopPillPrices", {}))
	if offers.is_empty():
		return false
	var prices: Dictionary = flow.get("shopPillPrices", {}).duplicate(true)
	var quote: Array = []
	for offer in offers:
		if offer.get("type") == "pill":
			prices[offer.id] = offer.price
		quote.append({"id": offer.get("id"), "price": offer.get("price")})
	flow["shopPillPrices"] = prices
	row["quote"] = quote
	if not saved_row.is_empty() and JSON.parse_string(JSON.stringify(row)) != saved_row:
		return false
	flow.shopEntries.append(row)
	candidate.normalFlow = flow
	return _commit_encounter_transition(_last_lesson_vendor.open(candidate,
		offers), "VENDOR_OPENED")


func _choose_shop(direction: String) -> bool:
	var first_market: bool = state.get("currentCardId") == FirstSessionRoute.MARKET_ID
	var authored: bool = state.get("currentCardId") == "q_market" or first_market
	var q_market_index := int(state.get("runClock", {}).get("decisionIndex", 0)) + 1
	var modern_q_market := authored and not first_market and q_market_index >= _q_market_choice_activation_index
	var card: Dictionary = get_current_card()
	if card.is_empty() or direction not in (["left", "right", "down"] if authored \
			else ["left", "right"]) or not authored and state.get(
			"normalFlow", {}).get("shopCatalogPins") != _regulated_catalog.source_pins():
		return false
	if authored and (card.get("type") != ("LOCATION" if first_market else "NORMAL") or card.get(
			"choices", {}).get("left", {}).get("action", {}).get(
			"vendorId") != RegulatedVendor.VENDOR_ID):
		return false
	if direction == ("left" if authored else "right"):
		if not _vendor_state_committed():
			return false
		var candidate := state.duplicate(true)
		if modern_q_market:
			candidate["qMarketChoiceVersion"] = 1
			if not candidate.has("qMarketChoiceActivationIndex"):
				candidate["qMarketChoiceActivationIndex"] = q_market_index
		var flow: Dictionary = _prepare_normal_flow(candidate) if first_market else candidate.get("normalFlow", {})
		if flow.is_empty():
			return false
		var discarded: Dictionary = flow.get("pendingShopDiscarded", {})
		if not authored and discarded.is_empty():
			return false
		flow["shopEntries"] = flow.get("shopEntries", []).duplicate(true)
		var index: int = flow["shopEntries"].size()
		var saved_row: Dictionary = {}
		if index < _normal_replay_shop_entries.size():
			if not _normal_replay_shop_entries[index] is Dictionary:
				return false
			saved_row = _normal_replay_shop_entries[index]
		var row := {"decisionIndex": int(candidate["runClock"]["decisionIndex"]) + 1}
		if authored:
			row["cardId"] = card.id
		var counter := [0]
		var offers: Array = _regulated_catalog.generate_for_realm(candidate, func() -> float:
			var key := "entryRoll%d" % counter[0]
			counter[0] += 1
			var value := _sample_normal_roll(flow, saved_row, key)
			row[key] = value
			return value, flow.get("shopPillPrices", {}))
		if offers.is_empty():
			return false
		var cumulative: Dictionary = flow.get("shopPillPrices", {}).duplicate(true)
		for offer in offers:
			if offer.get("type") == "pill":
				cumulative[offer["id"]] = offer["price"]
		flow["shopPillPrices"] = cumulative
		var quote: Array = []
		for offer in offers:
			quote.append({"id": offer.get("id"), "price": offer.get("price")})
		row["quote"] = quote
		if not saved_row.is_empty() and JSON.parse_string(JSON.stringify(row)) != saved_row:
			return false
		flow["shopEntries"].append(row)
		candidate["normalFlow"] = flow
		return _commit_encounter_transition(_regulated_vendor.open(candidate, offers,
			card if authored else {}),
			"VENDOR_OPENED")
	var next := state.duplicate(true)
	if not _normal_choice_policy._apply_passive_regen(next):
		return false
	var next_index := int(next["runClock"]["decisionIndex"]) + 1
	var source_id := "q_market" if authored else RegulatedCatalog.CARD_ID
	var receipt := "decision:%s:choice:%s:%d" % [next["runClock"]["lifeId"],
		source_id, next_index]
	if next["runClock"]["receipts"].has(receipt):
		return false
	next["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": source_id,
		"kind": "choice"}
	var tags: Array = card.get("tags", [])
	_append_choice_record(next, {"cardId": source_id,
		"cardType": card.get("type"), "direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": tags.duplicate(true)})
	if authored:
		for tag in tags:
			next["recentCardTags"].append(tag)
		while next["recentCardTags"].size() > 20:
			next["recentCardTags"].pop_front()
	next["cardsPlayed"].append(source_id)
	next["turn"] = next_index
	next["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(next)
	if not authored:
		next["normalFlow"].erase("pendingShopDiscarded")
	elif modern_q_market:
		var flags: Dictionary = next.get("flags", {}).duplicate(true)
		flags["choice:q_market:" + direction] = true
		next["flags"] = flags
		next["qMarketChoiceVersion"] = 1
		if not next.has("qMarketChoiceActivationIndex"):
			next["qMarketChoiceActivationIndex"] = next_index
	if modern_q_market and direction == "right":
		var result := _narrative_result_from_choice(next, card)
		var flow: Variant = next.get("noncombatFlow")
		if result.is_empty() or not flow is Dictionary \
				or flow.get("sourceContentHash") != _battle_gateway.source_content_hash():
			return false
		var existing: Variant = flow.get("qMarketPromise")
		if not existing is Dictionary or existing.get("id") != result["promiseId"]:
			if flow.has("pendingResultCard"):
				return false
			flow["qMarketPromise"] = {"id": result["promiseId"],
				"status": "pending", "sourceCardId": source_id,
				"sourceSemanticKey": "card:" + source_id,
				"choiceDirection": direction, "createdDecisionIndex": next_index,
				"followUpCardId": result["id"]}
			flow["pendingResultCard"] = result.duplicate(true)
			next["pendingNarrativeResult"] = result.duplicate(true)
			next["phase"] = "NARRATIVE_RESULT_PENDING"
			next["currentCardId"] = result["id"]
			next["decisionCheckpoint"] = {"version": 1, "cardId": result["id"],
				"sourceCardId": source_id, "turn": next_index,
				"decisionIndex": next_index}
			return _commit_encounter_transition(next, "MARKET_NARRATIVE_RESULT")
	next["phase"] = "FLOW_PENDING"
	next["currentCardId"] = ""
	next["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": source_id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	return _commit_encounter_transition(next, "SHOP_SKIPPED")


func _narrative_result_from_choice(candidate: Dictionary, card: Dictionary) -> Dictionary:
	var text: String = String(card.get("choices", {}).get("right", {}).get(
		"narrativeBlock", "")).strip_edges()
	if text.is_empty():
		return {}
	var life_id: String = String(candidate.get("runClock", {}).get("lifeId", ""))
	var life_count: String = life_id.get_slice(":", 2)
	if not life_count.is_valid_int() or int(life_count) < 0:
		return {}
	var source_id: String = String(card.get("id", ""))
	var semantic: String = String(card.get("semanticKey", "card:" + source_id))
	var promise_id := "promise:%08x" % _avoid_flow._fnv32(
		"life:%s|%s|%s|right" % [life_count, semantic, source_id])
	var result_id := "promise_result_%08x" % _avoid_flow._fnv32(promise_id)
	return {"id": result_id, "semanticKey": "promise-result:" + promise_id,
		"type": "NARRATIVE_RESULT", "title": String(card["title"]) + "·回应",
		"description": text, "promiseId": promise_id,
		"originCardId": source_id, "originChoice": "right",
		"_narrativeLane": "primary", "_narrativeThreadKey": "promise:" + promise_id,
		"_narrativeSticky": true, "narrativeTtlTurns": 4, "once": true,
		"tags": ["narrative_result", "promise_resolution"],
		"choices": {"left": {"text": "记下这段回应", "effects": {},
			"resolution": {"kind": "promise_resolved", "promiseId": promise_id},
			"feedbackCue": {"kind": "promise_resolved", "text": text,
				"lane": "narrative"}}}}


func _choose_camp(direction: String) -> bool:
	var card: Dictionary = _camp_flow.card()
	if card.is_empty() or not _camp_flow.available(state, direction):
		return false
	var candidate: Dictionary = _camp_flow.settle(state, direction)
	if candidate.is_empty() or not _normal_choice_policy._apply_passive_regen(candidate):
		return false
	var next_index := int(state["runClock"]["decisionIndex"]) + 1
	var receipt := "decision:%s:choice:%s:%d" % [state["runClock"]["lifeId"],
		CampFlow.CARD_ID, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return false
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": CampFlow.CARD_ID, "kind": "choice"}
	var tags: Array = card.get("tags", [])
	_append_choice_record(candidate, {"cardId": CampFlow.CARD_ID,
		"cardType": card.get("type"), "direction": direction, "turn": next_index - 1,
		"decisionIndex": next_index, "tags": tags.duplicate(true)})
	for tag in tags:
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(CampFlow.CARD_ID)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	MilestoneFlow.tick_seeds(candidate)
	var action := "remove" if direction == "right" else (
		"upgrade" if direction == "down" else "")
	candidate["phase"] = "CAMP_TARGET_PENDING" if not action.is_empty() else "FLOW_PENDING"
	candidate["currentCardId"] = CampFlow.CARD_ID if not action.is_empty() else ""
	if not action.is_empty():
		candidate["pendingCampAction"] = action
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": CampFlow.CARD_ID if not action.is_empty() else null,
		"sourceCardId": CampFlow.CARD_ID, "turn": next_index,
		"decisionIndex": next_index, "flowPending": action.is_empty()}
	return _commit_encounter_transition(candidate, "CAMP_CHOSEN")


func camp_targets() -> Array:
	if state.get("phase") != "CAMP_TARGET_PENDING":
		return []
	return _deck_acquisition.camp_targets(state,
		String(state.get("pendingCampAction", "")))


func resolve_camp_target(index: int, expected_card_id: String,
		expected_token: int) -> bool:
	if state.get("phase") != "CAMP_TARGET_PENDING" or expected_token <= 0 \
			or expected_token != _choice_token:
		return false
	var action := String(state.get("pendingCampAction", ""))
	var options := camp_targets()
	if index < 0 or index >= options.size() or not options[index].get("allowed", false) \
			or options[index].get("cardId") != expected_card_id:
		return false
	var candidate: Dictionary = _deck_acquisition.settle_camp_target(state, action, index)
	if candidate.is_empty():
		return false
	var record := {"decisionIndex": int(state["runClock"]["decisionIndex"]),
		"action": action, "index": index, "cardId": expected_card_id}
	if state.get("currentCardId") in ["q_shop", "f_shop", "g_shop"]:
		record["sourceCardId"] = state["currentCardId"]
	return _commit_camp_target(candidate, record, "CAMP_TARGET_SELECTED")


func cancel_camp_target(expected_token: int) -> bool:
	if state.get("phase") != "CAMP_TARGET_PENDING" or expected_token <= 0 \
			or expected_token != _choice_token:
		return false
	var candidate := state.duplicate(true)
	var record := {"decisionIndex": int(state["runClock"]["decisionIndex"]),
		"action": "cancel", "index": -1, "cardId": ""}
	if state.get("currentCardId") in ["q_shop", "f_shop", "g_shop"]:
		record["sourceCardId"] = state["currentCardId"]
	return _commit_camp_target(candidate, record, "CAMP_TARGET_CANCELLED")


func _commit_camp_target(candidate: Dictionary, record: Dictionary,
		event_type: String) -> bool:
	var source_card_id := String(candidate.get("currentCardId", ""))
	if not source_card_id in [CampFlow.CARD_ID, "q_shop", "f_shop", "g_shop", "rebirth_boon"]:
		return false
	if candidate.get("campTargetHistory", []).any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("decisionIndex") == record["decisionIndex"]):
		return false
	candidate["campTargetHistory"] = candidate.get("campTargetHistory", []).duplicate(true)
	candidate["campTargetHistory"].append(record)
	candidate.erase("pendingCampAction")
	candidate["phase"] = "FLOW_PENDING"
	candidate["currentCardId"] = ""
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": source_card_id,
		"turn": int(candidate["runClock"]["decisionIndex"]),
		"decisionIndex": int(candidate["runClock"]["decisionIndex"]),
		"flowPending": true}
	return _commit_encounter_transition(candidate, event_type)


func flow_failure_reason() -> String:
	if not _cadence_flow.last_error.is_empty():
		return _cadence_flow.last_error
	if not _battle_return_flow.last_error.is_empty():
		return _battle_return_flow.last_error
	if not _normal_flow_error.is_empty():
		return _normal_flow_error
	if not _story_thread_flow.last_error.is_empty():
		return _story_thread_flow.last_error
	return _milestone_flow.last_error if not _milestone_flow.last_error.is_empty() \
		else (_quest_flow.last_error if not _quest_flow.last_error.is_empty() \
			else (_karma_flow.last_error if not _karma_flow.last_error.is_empty() \
				else (_mentor_flow.last_error if not _mentor_flow.last_error.is_empty() \
					else (_emergent_flow.last_error if not _emergent_flow.last_error.is_empty() \
						else (_market_flow.last_error if not _market_flow.last_error.is_empty() \
							else (_ripple_flow.last_error if not _ripple_flow.last_error.is_empty() \
								else _hint_flow.last_error))))))


func opportunity_preview(direction: String) -> String:
	if state.get("phase") != "QUEST_PENDING":
		return ""
	var card := get_current_card()
	var spec: Variant = card.get("choices", {}).get(direction, {}).get(
		"effects", {}).get("opportunityReward")
	if not spec is Dictionary:
		return ""
	return _quest_flow.opportunity_flow.format_preview(state,
		String(spec.get("opportunityId", "")), String(spec.get("profile", "")),
		String(card.get("id", "")))


func can_choose_direction(direction: String) -> bool:
	if state.get("phase") == "COMBAT_HANDOFF" and state.has("pendingCadenceCard"):
		return direction in get_current_card().get("choices", {})
	if state.get("phase") == "QUEST_PENDING" \
			and (String(state.get("currentCardId", "")).begins_with("q_sword_") \
				or String(state.get("currentCardId", "")).begins_with("q_body_") \
				or String(state.get("currentCardId", "")).begins_with("q_spell_") \
				or String(state.get("currentCardId", "")).begins_with("q_pill_") \
				or String(state.get("currentCardId", "")).begins_with("q_tianshu_")):
		if state.get("currentCardId") == "q_sword_3" and direction in ["left", "right"]:
			var sword_offer: Dictionary = state.duplicate(true)
			sword_offer["pendingQuestCombatDirection"] = direction
			return not _battle_gateway.offer_from_state(sword_offer).is_empty()
		return _quest_flow.choice_direction_available(state, direction)
	if state.get("phase") == "QUEST_PENDING" and state.get("currentCardId") == "q_whiteFox_3" and direction == "left":
		return not _battle_gateway.offer_from_state(state).is_empty()
	if state.get("phase") == "FIRST_SESSION_ROUTE_PENDING":
		return not get_current_card().is_empty() and (direction == "right" \
			or direction == "left" and (state.get("currentCardId") == FirstSessionRoute.MARKET_ID \
				or not _battle_gateway.offer_from_state(state).is_empty()))
	if state.get("phase") == "REBIRTH_PENDING":
		return _rebirth_flow.choice_available(state, direction)
	if state.get("phase") == "GHOST_DEBT_PENDING":
		return _ghost_debt_flow.choice_available(state, direction)
	if state.get("phase") == "SHOP_PENDING":
		return direction in (["left", "right", "down"] if state.get(
			"currentCardId") == "q_market" else ["left", "right"]) \
			and not get_current_card().is_empty()
	if state.get("phase") == "MARKET_PENDING":
		return _market_flow.choice_available(state, direction)
	if state.get("phase") == "VENDOR_RESULT_PENDING":
		if _last_lesson_vendor_active():
			return direction == "right" and _last_lesson_vendor.source_valid(state)
		return direction == "right" and (_ghost_vendor_flow.source_valid(state) \
			if _ghost_vendor_active() else (_regulated_vendor.source_valid(state) \
			if _regulated_vendor_active() else _vendor_flow.source_valid(state)))
	if state.get("phase") == "KARMA_PENDING":
		return _karma_flow.choice_available(state, direction)
	if state.get("phase") == "MENTOR_PENDING":
		return _mentor_flow.choice_available(state, direction)
	if state.get("phase") == "HINT_PENDING":
		return _hint_flow.choice_available(state, direction)
	if state.get("phase") == "LOCATION_PENDING":
		return direction in _scene_layer_flow.card(state).get("choices", {})
	if state.get("phase") == "CHOICE_ECHO_PENDING":
		return direction in _choice_echo_flow.card(state).get("choices", {})
	if state.get("phase") == "ALLY_PENDING":
		return _ally_arc_flow.choice_available(state, direction)
	if state.get("phase") == "COMPANION_ARC_PENDING":
		return _companion_arc_flow.choice_available(state, direction)
	if state.get("phase") == "SEER_PENDING":
		return _seer_arc_flow.choice_available(state, direction)
	if state.get("phase") == "SURFACING_PENDING":
		return _narrative_surfacing.choice_available(state, direction)
	if state.get("phase") == "COMPANION_PENDING":
		if direction == "left" and state.get("currentCardId") \
				== BattleGateway.COMPANION_OLD_MASTER_SOURCE_ID:
			return not _battle_gateway.offer_from_state(state).is_empty()
		return _companion_events.choice_available(state, direction)
	if state.get("phase") == "FACTION_PENDING":
		if direction == "left" and state.get("currentCardId") \
				== BattleGateway.FACTION_GATE_SOURCE_ID:
			return not _battle_gateway.offer_from_state(state).is_empty()
		return _faction_events.choice_available(state, direction)
	if state.get("phase") == "THREAD_PENDING":
		return _story_thread_flow.choice_available(state, direction)
	if state.get("phase") == "NORMAL_PENDING":
		var normal_card: Dictionary = get_current_card()
		if _realm_gate_flow.upper_normal_choice_available(state, direction) \
				and normal_card == _realm_gate_flow._upper_source_card(
					String(normal_card.get("id", ""))):
			return true
		if normal_card.get("id") == "pa_ending_reform" and direction == "left" \
				and state.get("flags", {}).get("post_ascension_active") == true:
			return normal_card == _realm_gate_flow._upper_source_card(
				"pa_ending_reform") \
				and normal_card.get("choices", {}).get("left", {}).get(
					"effects", {}).get("reincarnate") == true
		if int(state.get("lifeCount", 0)) > 0 \
				and normal_card.get("id") == "q_shop" \
				and direction == "up":
			return false
		if int(state.get("lifeCount", 0)) > 0 \
				and normal_card.get("id") == "q_love" and direction == "right":
			var preview: Dictionary = _normal_choice_policy.settle(state,
				"q_love", direction)
			if not preview.is_empty() and (
					int(preview.get("attributes", {}).get("daoHeart", 1)) <= 0 \
					or int(preview.get("resources", {}).get("lifespan", 1)) <= 0):
				return false
		return _normal_choice_policy.choice_available(state, normal_card, direction)
	if state.get("phase") == "CAMP_PENDING":
		return _camp_flow.available(state, direction)
	return direction in get_current_card().get("choices", {})

func vendor_actions() -> Array:
	if _last_lesson_vendor_active():
		return _last_lesson_vendor.available_actions(state)
	return _ghost_vendor_flow.available_actions(state) if _ghost_vendor_active() else (
		_regulated_vendor.available_actions(state) if _regulated_vendor_active() \
		else _vendor_flow.available_actions(state))

func vendor_offers() -> Array:
	if _last_lesson_vendor_active():
		return _last_lesson_vendor.available_offers(state)
	return _ghost_vendor_flow.available_offers(state) if _ghost_vendor_active() else (
		_regulated_vendor.available_offers(state) if _regulated_vendor_active() \
		else _vendor_flow.available_offers(state))


func change_treasure_equipment(operation: String, instance_id: String,
		slot: String, expected_token: int) -> bool:
	if state.get("phase") not in ["NORMAL_PENDING", "THREAD_PENDING"] \
			or expected_token <= 0 \
			or expected_token != _choice_token or instance_id.is_empty() \
			or slot not in TreasureAcquisition.SLOTS \
			or operation not in ["equip", "unequip"]:
		return false
	var candidate: Dictionary = state.duplicate(true)
	var treasures := TreasureAcquisition.new(_content)
	if operation == "equip" and not treasures.equip_owned(candidate,
			instance_id, slot) or operation == "unequip" \
			and not treasures.unequip_owned(candidate, instance_id, slot):
		return false
	candidate["treasureEquipmentHistory"] = candidate.get(
		"treasureEquipmentHistory", []).duplicate(true)
	candidate["treasureEquipmentHistory"].append({"version": 1,
		"decisionIndex": int(state.runClock.decisionIndex),
		"cardId": String(state.currentCardId), "phase": String(state.phase),
		"operation": operation,
		"instanceId": instance_id, "slot": slot})
	return _commit_encounter_transition(candidate, "TREASURE_EQUIPMENT_CHANGED")

func perform_vendor_action(action_id: String, expected_token: int) -> bool:
	if expected_token <= 0 or expected_token != _choice_token \
			or not _vendor_state_committed():
		return false
	if _last_lesson_vendor_active():
		return _commit_encounter_transition(_last_lesson_vendor.interact(state,
			action_id), "VENDOR_ACTION")
	return _commit_encounter_transition((_ghost_vendor_flow.inspect_seal(
		state, action_id) if _ghost_vendor_active() else \
		_regulated_vendor.interact(state, action_id) \
		if _regulated_vendor_active() else _vendor_flow.interact(state, action_id)),
		"VENDOR_ACTION")

func purchase_vendor_offer(offer_id: String, expected_token: int,
		cost_mode_id: String = "", identify_rolls: Dictionary = {}) -> bool:
	if expected_token <= 0 or expected_token != _choice_token \
			or not _vendor_state_committed():
		return false
	if _last_lesson_vendor_active():
		return _commit_encounter_transition(_last_lesson_vendor.purchase(state,
			offer_id, cost_mode_id, identify_rolls), "VENDOR_PURCHASED")
	if _regulated_vendor_active():
		return _commit_encounter_transition(_regulated_vendor.purchase(state,
			offer_id, cost_mode_id, identify_rolls), "VENDOR_PURCHASED")
	if not identify_rolls.is_empty():
		return false
	return _commit_encounter_transition((_ghost_vendor_flow.purchase_oath(
			state, offer_id, cost_mode_id) if _ghost_vendor_active() else \
		_vendor_flow.purchase_offer(state, offer_id, cost_mode_id)),
		"VENDOR_PURCHASED")

func close_vendor(expected_token: int) -> bool:
	if expected_token <= 0 or expected_token != _choice_token \
			or not _vendor_state_committed():
		return false
	if _last_lesson_vendor_active():
		return _commit_encounter_transition(_last_lesson_vendor.close(state),
			"VENDOR_CLOSED")
	return _commit_encounter_transition((_regulated_vendor.close(state) \
		if _regulated_vendor_active() else _ghost_vendor_flow.close(state) \
		if _ghost_vendor_active() else _vendor_flow.close(state)), "VENDOR_CLOSED")

func resolve_vendor_loadout(action: String, expected_token: int) -> bool:
	if expected_token <= 0 or expected_token != _choice_token \
			or not _vendor_state_committed():
		return false
	return _commit_encounter_transition((_licensed_delivery.resolve_loadout(state,
		action) if state.get("phase") == "LICENSED_LOADOUT_PENDING" \
		else _last_lesson_vendor.resolve_loadout(state, action) if _last_lesson_loadout_pending() \
		else _regulated_vendor.resolve_loadout(state, action) if _regulated_loadout_pending() \
		else _ghost_vendor_flow.resolve_loadout(state, action) if _ghost_vendor_active() \
		else _vendor_flow.resolve_loadout(state, action)),
		"VENDOR_LOADOUT_RESOLVED")

func _replay_vendor_actions(saved: Dictionary) -> bool:
	var session: Dictionary = state.get("marketState", {}).get("activeSession", {})
	var session_key := String(session.get("sessionKey", ""))
	if session_key.is_empty():
		return false
	if _last_lesson_vendor_active():
		var events: Variant = saved.get("lastLessonVendorEventHistory", [])
		if not events is Array:
			return false
		for event in events:
			if not event is Dictionary:
				return false
			if event.get("sessionKey") != session_key:
				continue
			if event.get("kind") == "purchase":
				var item_id := String(event.get("itemId", ""))
				if item_id in ["shop_treasure_box", "shop_treasure_mysterious"] \
						and not event.has("identifyRoll"):
					return false
				if not purchase_vendor_offer(item_id,
						issue_choice_token(), "", event if item_id in [
							"shop_treasure_box", "shop_treasure_mysterious"] else {}):
					return false
			elif event.get("kind") == "action":
				if not perform_vendor_action(String(event.get("itemId", "")),
						issue_choice_token()):
					return false
			elif event.get("kind") == "loadout":
				if event.get("phase", "VENDOR_OPEN") != "VENDOR_OPEN":
					continue
				if not resolve_vendor_loadout(String(event.get("action", "")),
						issue_choice_token()):
					return false
			else:
				return false
		return true
	if session.get("vendorId") == "ghost_market":
		var ordered: Variant = saved.get("ghostVendorEventHistory", [])
		if not ordered is Array:
			return false
		var matching: Array = ordered.filter(func(row: Variant) -> bool:
			return row is Dictionary and row.get("sessionKey") == session_key)
		if not matching.is_empty():
			for event in matching:
				match event.get("kind"):
					"purchase":
						if not purchase_vendor_offer(String(event.get("offerId", "")),
								issue_choice_token()):
							return false
					"loadout":
						if not resolve_vendor_loadout(String(event.get("action", "")),
								issue_choice_token()):
							return false
					"action":
						if not perform_vendor_action(String(event.get("actionId", "")),
								issue_choice_token()):
							return false
					_:
						return false
			return true
		if saved.get("marketActionHistory", []).any(func(row: Variant) -> bool:
			return row is Dictionary and row.get("sessionKey") == session_key):
			return false
		for purchase in saved.get("marketPurchaseHistory", []):
			if not purchase is Dictionary:
				return false
			if purchase.get("sessionKey") == session_key and not purchase_vendor_offer(
					String(purchase.get("offerId", "")), issue_choice_token()):
				return false
		for resolution in saved.get("loadoutResolutionHistory", []):
			if not resolution is Dictionary:
				return false
			var pending: Dictionary = state.get("pendingLoadoutDecision", {})
			if pending.get("purchaseReceiptToken") == resolution.get(
				"purchaseReceiptToken") and not resolve_vendor_loadout(
				String(resolution.get("action", "")), issue_choice_token()):
				return false
		return true
	if session.get("vendorId") == RegulatedVendor.VENDOR_ID:
		var events: Array = saved.get("regulatedEventHistory", [])
		var matching: Array = events.filter(func(event: Variant) -> bool:
			return event is Dictionary and event.get("sessionKey") == session_key)
		if not matching.is_empty():
			for event in events:
				if not event is Dictionary:
					return false
				if event.get("sessionKey") != session_key:
					continue
				if event.get("kind") == "purchase":
					var offer_id := String(event.get("offerId", ""))
					if offer_id in ["shop_treasure_box", "shop_treasure_mysterious"] \
							and not event.has("identifyRoll"):
						return false
					if not purchase_vendor_offer(offer_id, issue_choice_token(), "",
							event if offer_id in ["shop_treasure_box",
								"shop_treasure_mysterious"] else {}):
						return false
				elif event.get("kind") == "action":
					if not perform_vendor_action(String(event.get("actionId", "")),
							issue_choice_token()):
						return false
				elif event.get("kind") == "loadout":
					if event.get("phase", "VENDOR_OPEN") != "VENDOR_OPEN":
						continue
					if not resolve_vendor_loadout(String(event.get("action", "")),
							issue_choice_token()):
						return false
				else:
					return false
			return true
		# Historical N9u saves only had the purchase ledger. Keep their exact
		# replay path; a newer action-bearing snapshot requires ordered events.
		for purchase in saved.get("marketPurchaseHistory", []):
			if not purchase is Dictionary:
				return false
			if purchase.get("sessionKey") == session_key and not purchase_vendor_offer(
					String(purchase.get("offerId", "")), issue_choice_token()):
				return false
		return true
	for event in saved.get("marketActionHistory", []):
		if not event is Dictionary:
			return false
		if event.get("sessionKey") == session_key and not perform_vendor_action(
				String(event.get("actionId", "")), issue_choice_token()):
			return false
	for purchase in saved.get("marketPurchaseHistory", []):
		if not purchase is Dictionary:
			return false
		if purchase.get("sessionKey") == session_key and not purchase_vendor_offer(
				String(purchase.get("offerId", "")), issue_choice_token(),
				String(purchase.get("costMode", ""))):
			return false
	for resolution in saved.get("loadoutResolutionHistory", []):
		if not resolution is Dictionary:
			return false
		var pending: Dictionary = state.get("pendingLoadoutDecision", {})
		if pending.get("purchaseReceiptToken") == resolution.get("purchaseReceiptToken") \
				and not resolve_vendor_loadout(String(resolution.get("action", "")),
					issue_choice_token()):
			return false
	return true

func _vendor_state_committed() -> bool:
	if _store == null:
		return true # Strict restore rebuilds with no store, then compares all fields.
	var committed: Dictionary = _store.load_snapshot() if _store.has_method(
		"load_snapshot") else {"state": _store.load_state()}
	return committed.get("state") is Dictionary and \
		JSON.parse_string(JSON.stringify(committed["state"])) == \
			JSON.parse_string(JSON.stringify(state))

func _regulated_vendor_active() -> bool:
	return state.get("phase") == "VENDOR_OPEN" and state.get("marketState", {}).get(
		"activeSession", {}).get("vendorId") == RegulatedVendor.VENDOR_ID \
		or state.get("phase") == "VENDOR_RESULT_PENDING" and state.get(
			"decisionCheckpoint", {}).get("sourceCardId") in [RegulatedCatalog.CARD_ID,
			"q_market", FirstSessionRoute.MARKET_ID]

func _last_lesson_vendor_active() -> bool:
	return state.get("phase") in ["VENDOR_OPEN", "VENDOR_RESULT_PENDING"] \
		and state.get("marketState", {}).get("activeSession", {}).get(
			"entryCardId") == LastLessonVendor.ENTRY_ID

func _last_lesson_loadout_pending() -> bool:
	var pending: Variant = state.get("pendingLoadoutDecision")
	return pending is Dictionary and String(pending.get(
		"sourceVendorSessionKey", "")).ends_with(
		":" + LastLessonVendor.ENTRY_ID + ":" + LastLessonVendor.VENDOR_ID)

func _regulated_loadout_pending() -> bool:
	var pending: Variant = state.get("pendingLoadoutDecision")
	if not pending is Dictionary:
		return false
	var key := String(pending.get("sourceVendorSessionKey", ""))
	for entry_id in [RegulatedCatalog.CARD_ID, "q_market", FirstSessionRoute.MARKET_ID]:
		if key.ends_with(":" + entry_id + ":" + RegulatedVendor.VENDOR_ID):
			return true
	return false

func _saved_legacy_lesson_session(saved: Dictionary) -> bool:
	if saved.has("lastLessonServiceVersion"):
		return false
	var session: Variant = saved.get("marketState", {}).get("activeSession")
	if session is Dictionary and session.get("entryCardId") == LastLessonVendor.ENTRY_ID:
		return true
	for entry in saved.get("replayHistory", saved.get("choiceHistory", [])):
		if entry is Dictionary and entry.get("cardId") == LastLessonVendor.ENTRY_ID \
				and entry.get("direction") == "left":
			return true
	return false

func _replay_deferred_last_lesson_loadout(saved: Dictionary) -> bool:
	if not _last_lesson_loadout_pending() and not _regulated_loadout_pending():
		return true
	var pending: Dictionary = state.pendingLoadoutDecision
	var events: Array = saved.get("lastLessonVendorEventHistory", []) \
		if _last_lesson_loadout_pending() else saved.get("regulatedEventHistory", [])
	for event in events:
		if not event is Dictionary or event.get("kind") != "loadout" \
				or event.get("sessionKey") != pending.sourceVendorSessionKey \
				or event.get("phase", "VENDOR_OPEN") == "VENDOR_OPEN":
			continue
		if event.get("phase") == state.get("phase") \
				and int(event.get("decisionIndex", -1)) == int(state.get(
					"runClock", {}).get("decisionIndex", -2)):
			return resolve_vendor_loadout(String(event.get("action", "")),
				issue_choice_token())
	return true

func _ghost_vendor_active() -> bool:
	return state.get("phase") == "VENDOR_OPEN" and state.get("marketState", {}).get(
		"activeSession", {}).get("vendorId") == "ghost_market" \
		or state.get("phase") == "VENDOR_RESULT_PENDING" and state.get(
			"decisionCheckpoint", {}).get("sourceCardId") == MarketFlow.GHOST_ID


func _acknowledge_narrative_result(direction: String) -> bool:
	var result: Dictionary = get_current_card()
	if direction != "left" or result.get("type") != "NARRATIVE_RESULT" \
			or result.get("id") != _current_card_id:
		return false
	var flow: Variant = state.get("noncombatFlow")
	if not flow is Dictionary or String(flow.get("sourceContentHash", "")).length() != 64 \
			or flow.get("sourceContentHash") != _battle_gateway.source_content_hash() \
			or JSON.stringify(flow.get("pendingResultCard", {})) != JSON.stringify(result):
		return false
	if MentorFlow.is_stage_card_id(String(result.get("originCardId", ""))):
		var art: Dictionary = _content.asset_status(String(result.get("sceneImage", "")))
		if flow.get("mentorArcSourceSha") != _content.source_sha256("companions:arcs") \
				or flow.get("mentorPortraitSourceSha") != _content.source_sha256(
					"companions:portrait_stages") \
				or not art.get("shaVerified", false) or not art.get("textureLoadable", false):
			return false
	var candidate: Dictionary = state.duplicate(true)
	_upgrade_avoid_lifespan(candidate)
	var base_index := int(candidate["runClock"].get("decisionIndex", -1))
	if base_index < 0:
		return false
	var next_index := base_index + 1
	var result_id := String(result["id"])
	var promise_key := "qMarketPromise" if result.get("originCardId") == "q_market" \
		else ("mentorPromise" if MentorFlow.is_stage_card_id(String(
			result.get("originCardId", ""))) else "promise")
	if result.get("originCardId") == FirstSessionRoute.MARKET_ID:
		promise_key = "firstSessionRoutePromise"
	if candidate["noncombatFlow"].has("cadencePromise") \
			and candidate["noncombatFlow"]["cadencePromise"].get("followUpCardId") == result_id:
		promise_key = "cadencePromise"
	var promise: Variant = candidate["noncombatFlow"].get(promise_key)
	if promise is Dictionary:
		if promise.get("status") != "pending" \
				or promise.get("id") != result.get("promiseId") \
				or promise.get("followUpCardId") != result_id:
			return false
	elif candidate["noncombatFlow"].get("scope") != "first_session_avoid" \
			or result.get("originChoice") != "right" \
			or String(result.get("promiseId", "")).is_empty() \
			or candidate["choiceHistory"].is_empty() \
			or result.get("originCardId") != candidate["choiceHistory"].back().get("cardId"):
		return false
	var receipt := "decision:%s:choice:%s:%d" % [
		candidate["runClock"]["lifeId"], result_id, next_index]
	if candidate["runClock"]["receipts"].has(receipt):
		return false
	candidate["runClock"]["receipts"][receipt] = {"token": receipt,
		"decisionIndex": next_index, "sourceCardId": result_id, "kind": "choice"}
	_append_choice_record(candidate, {"cardId": result_id,
		"cardType": "NARRATIVE_RESULT", "direction": "left",
		"turn": base_index, "decisionIndex": next_index,
		"tags": result.get("tags", []).duplicate(true)})
	for tag in result.get("tags", []):
		candidate["recentCardTags"].append(tag)
	while candidate["recentCardTags"].size() > 20:
		candidate["recentCardTags"].pop_front()
	candidate["cardsPlayed"].append(result_id)
	candidate["turn"] = next_index
	candidate["runClock"]["decisionIndex"] = next_index
	if not _legacy_karma_replay:
		if not candidate["noncombatFlow"].has("karmaClockVersion"):
			MilestoneFlow.tick_seeds(candidate)
		MilestoneFlow.tick_seeds(candidate)
		candidate["noncombatFlow"]["karmaClockVersion"] = 1
		if not promise is Dictionary:
			candidate["noncombatFlow"]["legacySchemaVersion"] = 0
	candidate["noncombatFlow"]["acknowledgedResultCardId"] = result_id
	if promise is Dictionary:
		candidate["noncombatFlow"][promise_key]["status"] = "resolved"
		candidate["noncombatFlow"][promise_key]["resolvedDecisionIndex"] = next_index
		candidate["noncombatFlow"][promise_key]["resolutionCardId"] = result_id
	candidate["noncombatFlow"].erase("pendingResultCard")
	candidate.erase("pendingNarrativeResult")
	candidate["currentCardId"] = ""
	candidate["phase"] = "FLOW_PENDING"
	candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
		"sourceCardId": result_id, "turn": next_index,
		"decisionIndex": next_index, "flowPending": true}
	if not _persist_snapshot(candidate):
		return false
	_current_card_id = ""
	_choice_token += 1
	state = candidate
	changed.emit({"type": "RESULT_ACKNOWLEDGED", "sourceCardId": result_id,
		"cardId": "", "turn": next_index})
	return true


func _upgrade_avoid_lifespan(candidate: Dictionary) -> void:
	if _legacy_lifespan_replay:
		return
	var flow: Variant = candidate.get("noncombatFlow", {})
	if flow is Dictionary and flow.get("scope") == "first_session_avoid" \
			and not flow.has("lifespanCostVersion"):
		candidate["resources"]["lifespan"] = maxi(0,
			int(candidate["resources"].get("lifespan", 0)) - 1)
		flow["lifespanCostVersion"] = 1


func _choose_prologue(direction: String) -> bool:
	var card: Dictionary = _cards.get(_current_card_id, {})
	if _current_card_id != String(_path_definition.get("startCard", "")) \
			or card.get("type") != "PROLOGUE" or not card.get("choices") is Dictionary:
		return false
	var choice: Dictionary = card["choices"].get(direction, {})
	if choice.is_empty() or not choice.get("effects") is Dictionary \
			or not choice.has("karmaSeed"):
		return false
	for key in choice:
		if not key in ["text", "desc", "effects", "karmaSeed"]:
			return false
	for key in choice["effects"]:
		if not key in PROLOGUE_EFFECT_KEYS or not _valid_integer(choice["effects"][key]):
			return false
	var first_session_value: Variant = _content.read_module("progression:first_session_cohesion")
	var encounters_value: Variant = _content.read_module("combat:encounters")
	if not first_session_value is Dictionary or not encounters_value is Dictionary:
		return false
	var first_session: Dictionary = first_session_value
	var route: Dictionary = first_session.get("paths", {}).get(state.get("path", ""), {})
	var encounter_id := String(route.get("teachingEncounterId", ""))
	if route.get("prologueCardId") != _current_card_id or encounter_id.is_empty():
		return false
	var encounters: Array = encounters_value.get("encounters", [])
	var found_encounter := false
	for encounter in encounters:
		if encounter is Dictionary and encounter.get("id") == encounter_id:
			found_encounter = true
			break
	if not found_encounter:
		return false
	var next_state: Dictionary = state.duplicate(true)
	var effects: Dictionary = choice["effects"]
	for key in effects:
		if not _apply_effect(next_state, key, int(effects[key])):
			return false
	if int(effects.get("health", 0)) < 0 or int(effects.get("daoHeart", 0)) < 0:
		next_state["resources"]["lifespan"] = maxi(0,
			int(next_state["resources"]["lifespan"]) - 1)
	if not _plant_prologue_seed(next_state, card, choice, direction):
		return false
	var committed := _commit_choice(next_state, card, direction,
		"encounter_card_" + encounter_id, "COMBAT_HANDOFF")
	if committed:
		_flow_card_count += 1
		_tick_normal_starvation("normal")
	return committed


func _plant_prologue_seed(target: Dictionary, card: Dictionary,
		choice: Dictionary, direction: String) -> bool:
	var authored: Variant = choice["karmaSeed"]
	var seed_spec: Dictionary = {}
	if authored is String:
		seed_spec = {"id": authored, "seedType": "karma", "delay": 5, "priority": 1}
	elif authored is Dictionary:
		seed_spec = authored
	else:
		return false
	var seed_id := String(seed_spec.get("id", ""))
	if seed_id.is_empty() or not _valid_integer(seed_spec.get("delay", 5)) \
			or not _valid_integer(seed_spec.get("priority", 0)):
		return false
	var realm := String(target.get("realm", ""))
	# KarmaSystem adjusts delay at planting, then the same choice ticks once.
	var realm_factor := 1.5 if realm == "qi" else 1.0
	var remaining := maxi(1, roundi(int(seed_spec.get("delay", 5)) * realm_factor)) - 1
	var source_realm: Variant = seed_spec.get("realm")
	var source_path: Variant = seed_spec.get("path")
	var seed := {
		"id": seed_id,
		"seedType": seed_spec.get("seedType", "karma"),
		"delay": remaining,
		"realm": source_realm,
		"path": source_path,
		"priority": int(seed_spec.get("priority", 0)),
		"originTurn": int(target["runClock"]["decisionIndex"]) + 1,
		"originLife": 0,
		"originCard": card["id"],
		"originChoice": direction,
		"originThread": seed_spec.get("originThread"),
		"originQuest": seed_spec.get("originQuest"),
		"originOutcome": seed_spec.get("originOutcome"),
		"description": seed_spec.get("description"),
		"tags": seed_spec.get("tags", []),
		"payoffEvent": seed_spec.get("payoffEvent"),
		"context": {
			"sourceTitle": card.get("title", card["id"]),
			"choiceText": choice.get("text", direction),
			"realm": source_realm if source_realm != null else card.get("realm", realm),
			"path": source_path if source_path != null else card.get("path", target["path"]),
		},
		"consumed": false,
		"mergeGroup": seed_spec.get("mergeGroup"),
		"cancelGroup": seed_spec.get("cancelGroup"),
	}
	target["karmaSeeds"] = [seed]
	target["pendingKarmaSeeds"] = [seed.duplicate(true)]
	target["karmaPromiseFlags"] = {seed_id: true}
	return true


func _append_choice_record(candidate: Dictionary, record: Dictionary) -> void:
	if not candidate.has("replayHistory"):
		# A strictly restored pre-journal save still has its complete short history.
		candidate["replayHistory"] = candidate["choiceHistory"].duplicate(true)
	candidate["replayHistory"].append(record.duplicate(true))
	candidate["choiceHistory"].append(record)
	while candidate["choiceHistory"].size() > 30:
		candidate["choiceHistory"].pop_front()


func _sync_replay_history(candidate: Dictionary) -> bool:
	if not candidate.has("replayHistory"):
		candidate["replayHistory"] = state.get(
			"replayHistory", state.get("choiceHistory", [])).duplicate(true)
	var recent: Array = candidate["choiceHistory"]
	var ledger: Array = state.get("replayHistory", state.get("choiceHistory", [])).duplicate(true)
	if ledger.size() < 30 and recent.size() <= 30:
		candidate["replayHistory"] = recent.duplicate(true)
		return true
	var overlap := -1
	for count in range(mini(ledger.size(), recent.size()), -1, -1):
		if ledger.slice(ledger.size() - count) == recent.slice(0, count):
			overlap = count
			break
	if overlap <= 0 and not ledger.is_empty():
		return false
	for index in range(overlap, recent.size()):
		ledger.append(recent[index].duplicate(true))
	candidate["replayHistory"] = ledger
	return true


func _commit_choice(next_state: Dictionary, card: Dictionary, direction: String,
		next_id: String, next_phase: String) -> bool:
	if not next_state.has("playerName"):
		next_state["playerName"] = "叶凌云"
	var current_turn := int(next_state["turn"])
	var next_decision_index := int(next_state["runClock"]["decisionIndex"]) + 1
	var tags: Array = card.get("tags", [])
	_append_choice_record(next_state, {
		"cardId": _current_card_id, "cardType": card.get("type"),
		"direction": direction, "turn": current_turn,
		"decisionIndex": next_decision_index, "tags": tags.duplicate(true),
	})
	for tag in tags:
		next_state["recentCardTags"].append(tag)
	while next_state["recentCardTags"].size() > 20:
		next_state["recentCardTags"].pop_front()
	next_state["cardsPlayed"].append(_current_card_id)
	next_state["turn"] = next_decision_index
	next_state["runClock"]["decisionIndex"] = next_decision_index
	var receipt_token := "decision:%s:choice:%s:%d" % [
		next_state["runClock"]["lifeId"], _current_card_id, next_decision_index]
	next_state["runClock"]["receipts"][receipt_token] = {
		"token": receipt_token, "decisionIndex": next_decision_index,
		"sourceCardId": _current_card_id, "kind": "choice",
	}
	next_state["decisionCheckpoint"] = {
		"version": 1, "cardId": next_id, "turn": next_decision_index,
		"decisionIndex": next_decision_index, "sourceCardId": _current_card_id,
	}
	next_state["currentCardId"] = next_id
	if next_id == String(_path_definition["startCard"]):
		next_state["tutorialCompleted"] = true
		next_state["phase"] = "STARTER_BOUNDARY"
	elif not next_phase.is_empty():
		next_state["phase"] = next_phase
	if not _persist_snapshot(next_state):
		return false
	var prior_id := _current_card_id
	_current_card_id = next_id
	_choice_token += 1
	state = next_state
	changed.emit({"type": "CHOICE_COMMITTED", "sourceCardId": prior_id,
		"direction": direction, "nextCardId": next_id, "turn": state["turn"]})
	return true


func _delivery_eligible_for_tick(prior: Dictionary, candidate: Dictionary) -> bool:
	# Browser GameLogic._queueDueLicensedSwordDelivery is skipped while the
	# combat coordinator owns the run and during the authored inheritance handoff.
	return candidate.get("phase") != "BATTLE_PENDING" \
		and not (prior.get("currentCardId") == "breakthrough_reward" \
			and candidate.get("realmTransition") is Dictionary \
			and candidate.get("realmTransition", {}).get("status") \
				== "inheritance_pending")


func _persist_snapshot(candidate: Dictionary, death_source_id: String = "") -> bool:
	var mentor_cultivation_events: Array = candidate.get("_mentorCultivationEvents", [])
	candidate.erase("_mentorCultivationEvents")
	var dungeon_visible: bool = candidate.get("phase") == "NORMAL_PENDING" \
		and candidate.get("dungeonRun") is Dictionary \
		and candidate.dungeonRun.get("status") == "active"
	var dungeon_card_id := String(candidate.get("currentCardId", "")) if dungeon_visible else ""
	var dungeon_checkpoint: Dictionary = candidate.get("decisionCheckpoint", {}).duplicate(true) \
		if dungeon_visible else {}
	var prior_index := int(state.get("runClock", {}).get("decisionIndex", -1))
	var candidate_index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
	if _market_skip_seed_tick_activation_index > 0 \
			and candidate_index >= _market_skip_seed_tick_activation_index:
		candidate["marketSkipSeedTickActivationIndex"] = \
			_market_skip_seed_tick_activation_index
	if candidate_index > prior_index and candidate_index >= _normal_choice_pin_activation_index \
			and candidate.get("normalFlow") is Dictionary \
			and candidate.normalFlow.get("choiceRuleSha") == LEGACY_GAME_LOGIC_JS_SHA:
		candidate.normalFlow.choiceRuleSha = NormalChoicePolicy.GAME_LOGIC_JS_SHA
	if candidate_index <= prior_index:
		for marker in _projected_choice_markers:
			candidate.erase(marker)
	if candidate_index > prior_index:
		if not candidate.has("pathSkillActivationIndex") \
				and candidate_index >= _path_skill_activation_index:
			candidate["pathSkillActivationIndex"] = _path_skill_activation_index
		if not candidate.has("passiveRegenExtensionIndex") \
				and candidate_index >= _passive_regen_extension_activation_index:
			candidate["passiveRegenExtensionIndex"] = \
					_passive_regen_extension_activation_index
		if not candidate.has("earlyAvoidActivationIndex") \
				and candidate_index >= _early_avoid_activation_index:
			candidate["earlyAvoidActivationIndex"] = _early_avoid_activation_index
	if candidate.has("pathSkillActivationIndex") \
			and not PathSkillFlow.new(_content).activation_valid(candidate):
		return false
	if candidate.has("passiveRegenExtensionIndex") \
			and (not _valid_integer(candidate.passiveRegenExtensionIndex) \
				or int(candidate.passiveRegenExtensionIndex) < 1 \
				or int(candidate.passiveRegenExtensionIndex) > candidate_index + 1):
		return false
	if candidate.has("earlyAvoidActivationIndex") \
			and (not _valid_integer(candidate.earlyAvoidActivationIndex) \
				or int(candidate.earlyAvoidActivationIndex) < 1 \
				or int(candidate.earlyAvoidActivationIndex) > candidate_index + 1):
		return false
	if not candidate.has("worldContinuityActivationIndex") \
			and candidate_index >= _world_continuity_activation_index \
			and candidate_index > prior_index:
		var source_sha: String = _content.source_sha256("npcs:core")
		if source_sha.length() != 64:
			_mark_source_failure(_content)
			return false
		if not candidate.has("worldContinuityState"):
			var world: Dictionary = WorldContinuity.initial(_content,
				int(candidate.get("lifeCount", 0)))
			if world.is_empty():
				_mark_source_failure(_content)
				return false
			candidate["worldContinuityState"] = world["state"]
		elif _legacy_mortal_npc_pin(candidate, candidate.get("noncombatFlow", {})) \
				and not _upgrade_legacy_mortal_world(candidate):
			return false
		candidate["worldContinuityActivationIndex"] = _world_continuity_activation_index
		candidate["worldContinuitySourceSha"] = source_sha
	if candidate.has("worldContinuityActivationIndex") and (
			candidate.get("worldContinuitySourceSha") != _content.source_sha256("npcs:core") \
			or not candidate.get("worldContinuityState") is Dictionary):
		_mark_source_failure(_content)
		return false
	if candidate_index > prior_index and candidate.has("worldContinuityActivationIndex") \
			and candidate.has("npcEncounterScheduling") \
			and candidate.has("worldContinuityState"):
		candidate["worldContinuityState"] = _npc_encounter_flow.tick_schedule(
			candidate, maxi(0, int(state.get("turn", 0)))).get(
				"worldContinuityState", candidate.worldContinuityState)
	if not candidate.has("normalNarrativeAdmission") \
			and candidate_index >= _narrative_admission_activation_index \
			and candidate_index > int(state.get("runClock", {}).get("decisionIndex", -1)):
		candidate["normalNarrativeAdmission"] = {"version": 1,
			"activationIndex": maxi(1, _narrative_admission_activation_index),
			"ruleSha": NormalDrawPolicy.NARRATIVE_LEDGER_JS_SHA}
	if candidate.has("normalNarrativeAdmission") and (
			candidate["normalNarrativeAdmission"].get("version") != 1 \
			or candidate["normalNarrativeAdmission"].get("ruleSha") \
				!= NormalDrawPolicy.NARRATIVE_LEDGER_JS_SHA):
		return false
	if not candidate.has("sceneLayerState") and candidate_index >= _scene_activation_index:
		var scene_marker: Dictionary = _scene_layer_flow.marker(_scene_activation_index)
		if scene_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["sceneLayerState"] = scene_marker
		if not candidate.has("currentLocation"):
			candidate["currentLocation"] = "宗门"
		if not candidate.has("visitedLocations"):
			candidate["visitedLocations"] = [candidate["currentLocation"]]
		if not candidate.has("locationStates"):
			candidate["locationStates"] = {}
	if candidate.has("sceneLayerState") and not _scene_layer_flow.valid(candidate):
		_mark_source_failure(_content)
		return false
	if not candidate.has("choiceEchoState") and candidate_index >= _echo_activation_index:
		var echo_marker: Dictionary = _choice_echo_flow.marker(_echo_activation_index)
		if echo_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["choiceEchoState"] = echo_marker
		candidate["choiceEchoes"] = []
	if candidate.has("choiceEchoState") and not _choice_echo_flow.valid(candidate):
		_mark_source_failure(_content)
		return false
	if not candidate.has("allyArcState") and candidate_index >= _ally_activation_index:
		var ally_marker: Dictionary = _ally_arc_flow.marker(_ally_activation_index)
		if ally_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["allyArcState"] = ally_marker
	if candidate.has("allyArcState") and not _ally_arc_flow.valid(candidate):
		_mark_source_failure(_content)
		return false
	if not candidate.has("companionArcState") \
			and candidate_index >= _companion_arc_activation_index:
		var companion_arc_marker: Dictionary = _companion_arc_flow.marker(
			_companion_arc_activation_index, int(candidate.get("lifeCount", 0)))
		if companion_arc_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["companionArcState"] = companion_arc_marker
	if candidate.has("companionArcState") and not _companion_arc_flow.valid(candidate):
		_mark_source_failure(_content)
		return false
	if not candidate.has("seerArcState") and candidate_index >= _seer_activation_index:
		var seer_marker: Dictionary = _seer_arc_flow.marker(_seer_activation_index)
		if seer_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["seerArcState"] = seer_marker
	if candidate.has("seerArcState") and not _seer_arc_flow.valid(candidate):
		_mark_source_failure(_content)
		return false
	if not candidate.has("narrativeSurfacingState") \
			and candidate_index >= _surfacing_activation_index:
		var surface_marker: Dictionary = _narrative_surfacing.marker(
			_surfacing_activation_index)
		if surface_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["narrativeSurfacingState"] = surface_marker
	if candidate.has("narrativeSurfacingState") and not _narrative_surfacing.valid(candidate):
		_mark_source_failure(_content)
		return false
	var companion_activated := not candidate.has("companionProgress")
	if companion_activated \
			and candidate_index >= _companion_activation_index:
		var companion_marker: Dictionary = _companion_events.marker(
			_companion_activation_index, int(candidate.get("turn", 0)),
			_companion_milestone_activation_index)
		if companion_marker.is_empty():
			_mark_source_failure(_content)
			return false
		candidate["companionProgress"] = companion_marker
	if candidate.has("companionProgress") and not _companion_events.valid(candidate):
		_mark_source_failure(_content)
		return false
	if candidate.has("companionProgress"):
		var prior_companions: Array = state.get("resources", {}).get("companions", [])
		for companion_id in candidate.get("resources", {}).get("companions", []):
			if companion_id is String and (companion_activated \
					or not prior_companions.has(companion_id)):
				# Browser resource grant precedes register; unknown raw IDs stay owned
				# without a fabricated CompanionSystem profile.
				_companion_events.register(candidate, companion_id,
					int(state.get("turn", 0)) if not companion_activated else \
					int(candidate.get("turn", 0)))
		if candidate_index > prior_index:
			var decisions: Array = candidate.get("choiceHistory", [])
			if not decisions.is_empty() and decisions.back() is Dictionary \
					and decisions.back().get("cardId") == state.get("currentCardId"):
				var source_card: Dictionary = get_current_card()
				if not _companion_events.queue_crisis(candidate, source_card,
						String(decisions.back().get("direction", ""))):
					_mark_source_failure(_content)
					return false
	if candidate.has("choiceEchoState") and candidate_index > prior_index \
			and candidate.get("choiceHistory", []) is Array \
			and not candidate["choiceHistory"].is_empty():
		var last_choice: Dictionary = candidate["choiceHistory"].back()
		if int(last_choice.get("decisionIndex", -1)) == candidate_index \
				and not _choice_echo_flow.plant(candidate,
					get_current_card(), String(last_choice.get("direction", ""))):
			_mark_source_failure(_content)
			return false
	if candidate.has("sceneLayerState") and candidate.get("currentCardId") \
			!= state.get("currentCardId") and candidate.get("phase") != "FLOW_PENDING":
		var arriving: Dictionary = _content.find("card", String(
			candidate.get("currentCardId", "")))
		var source_card: Dictionary = arriving.get("data", {})
		var card_location := String(source_card.get("location", ""))
		if not card_location.is_empty() and not source_card.get(
				"requiresPlayerPresence", false) and candidate.get(
				"currentLocation") != card_location:
			candidate["currentLocation"] = card_location
			var visited: Array = candidate.get("visitedLocations", [])
			if not visited.has(card_location):
				visited.append(card_location)
			candidate["visitedLocations"] = visited
	var death_checkpoint: Variant = candidate.get("decisionCheckpoint", {}).duplicate(true) \
		if candidate.get("phase") == "DEATH_PENDING" else null
	# Source _resolveCombatOutcome skips ordinary choice hooks. Old saves replay
	# their already-issued rewards unchanged; the next decision enables this rule.
	if candidate_index >= _npc_activation_index \
			and not candidate.has("npcEncounterScheduling"):
		var npc_marker: Dictionary = _npc_encounter_flow.marker(candidate,
			_npc_activation_index, _npc_general_activation_index)
		if npc_marker.is_empty():
			return false
		candidate["npcEncounterScheduling"] = npc_marker
	if candidate_index >= _npc_general_activation_index \
			and candidate.has("npcEncounterScheduling") \
			and not candidate.npcEncounterScheduling.has("generalActivationIndex"):
		var general_marker: Dictionary = _npc_encounter_flow.activate_general(
			candidate.npcEncounterScheduling, candidate, _npc_general_activation_index)
		if general_marker.is_empty():
			return false
		candidate["npcEncounterScheduling"] = general_marker
	if candidate_index >= _npc_cross_activation_index \
			and not candidate.has("npcCrossState"):
		var cross_marker: Dictionary = _npc_cross_flow.marker(candidate,
			_npc_cross_activation_index, _npc_cross_dynamic_activation_index)
		if cross_marker.is_empty():
			return false
		candidate["npcCrossState"] = cross_marker
	if candidate_index >= _npc_cross_dynamic_activation_index \
			and candidate.has("npcCrossState") \
			and not candidate.npcCrossState.has("dynamicActivationIndex"):
		var dynamic_marker: Dictionary = _npc_cross_flow.activate_dynamic(
			candidate.npcCrossState, _npc_cross_dynamic_activation_index)
		if dynamic_marker.is_empty():
			return false
		candidate["npcCrossState"] = dynamic_marker
	if candidate_index >= _cadence_activation_index:
		if candidate.get("noncombatFlow") is Dictionary \
				and not candidate["noncombatFlow"].get("encounterDirectorState") is Dictionary:
			var initial_director: Dictionary = _cadence_flow.initial_state(
				int(candidate.get("lifeCount", 0)))
			if initial_director.is_empty():
				return false
			candidate["noncombatFlow"]["encounterDirectorState"] = initial_director
		var cadence_marker: Dictionary = _cadence_flow.marker(_cadence_activation_index,
			_cadence_high_upgrade_index if candidate_index >= _cadence_high_upgrade_index else -1)
		if cadence_marker.is_empty():
			_mark_battle_return_failure(_cadence_flow)
			return false
		candidate["encounterCadence"] = cadence_marker
	var combat_commit := false
	if candidate_index >= _combat_scheduling_activation_index:
		candidate["combatScheduling"] = {"version": 1,
			"activationIndex": _combat_scheduling_activation_index}
		if candidate_index > prior_index:
			for receipt in candidate.get("runClock", {}).get("receipts", {}).values():
				if receipt.get("kind") == "combat" and receipt.get("decisionIndex") == candidate_index:
					combat_commit = true
					break
	if candidate_index > prior_index and not _causal_fact_clock.settle(
			candidate, candidate_index):
		return false
	if candidate.has("normalFlow"):
		var normal: Variant = candidate["normalFlow"]
		if normal is Dictionary and normal.has("goldenSourceSha") \
				and not _pinned_source_matches("cards:golden",
					String(normal.goldenSourceSha)):
			return false
		if normal is Dictionary and normal.has("nascentSourceSha") \
				and not _pinned_source_matches("cards:nascent",
					String(normal.nascentSourceSha)):
			return false
		if normal is Dictionary and normal.has("deitySourceSha") \
				and not _pinned_source_matches("cards:deity",
					String(normal.deitySourceSha)):
			return false
		if normal is Dictionary and normal.has("tribulationSourceSha") \
				and not _pinned_source_matches("cards:tribulation",
					String(normal.tribulationSourceSha)):
			return false
		if normal is Dictionary and normal.get("version") == 1 \
				and normal.get("sourcePins") == _normal_draw_policy.legacy_source_pins() \
				and _normal_replay_source_pins.is_empty():
			normal["sourcePins"] = _normal_draw_policy.source_pins()
		if not normal is Dictionary or normal.get("version") != 1 \
				or normal.get("sourcePins") != (_normal_replay_source_pins \
					if not _normal_replay_source_pins.is_empty() \
					else _normal_draw_policy.source_pins()) \
				or normal.get("flowRuleSha") != NormalDrawPolicy.FLOW_DIRECTOR_JS_SHA \
				or normal.get("cardRuleSha") != NormalDrawPolicy.CARD_SYSTEM_JS_SHA \
				or normal.get("choiceRuleSha") != (LEGACY_GAME_LOGIC_JS_SHA \
					if _normal_choice_pin_activation_index > 0 \
					and candidate_index < _normal_choice_pin_activation_index \
					else NormalChoicePolicy.GAME_LOGIC_JS_SHA) \
				or normal.get("stateRuleSha") != NormalChoicePolicy.GAME_STATE_JS_SHA \
				or normal.get("effectRuleSha") != NormalChoicePolicy.EFFECT_SERVICE_JS_SHA \
				or normal.has("priorityChecks") and not _pinned_source_matches(
					"cards:camp", String(normal.get("priorityCampSourceSha", ""))):
			return false
	var causal_pin: Variant = candidate.get("noncombatFlow", {}).get("causalGraphSourceSha")
	if causal_pin is String and String(causal_pin).length() == 64 \
			and not _pinned_source_matches("narrative:causal_graph", String(causal_pin)):
		return false
	if candidate.has("treasureRuleSourceSha") and (
			candidate.get("treasureRuleSourceSha") != TreasureAcquisition.SOURCE_JS_SHA \
			or not _pinned_source_matches("shops:treasures",
				String(candidate.get("treasureSourceSha", "")))):
		return false
	if candidate.has("shopIdentifyRuleSourceSha") \
			and candidate.shopIdentifyRuleSourceSha != LastLessonVendor.IDENTIFY_JS_SHA:
		return false
	if candidate.has("lastLessonServiceVersion") and (
			candidate.lastLessonServiceVersion != 1 \
			or candidate.get("regulatedCausalGraphSourceSha") != _content.source_sha256(
				"narrative:causal_graph")):
		return false
	if not _legacy_deck_replay:
		if not candidate.has("deckStateVersion"):
			var deck_ready: Dictionary = _deck_acquisition.ensure_starter(candidate)
			if deck_ready.is_empty():
				return false
			candidate.merge(deck_ready, true)
		elif candidate.get("deckStateVersion") != 1 \
				or not candidate.get("deckProgressionSourceSha") is String \
				or not candidate.get("battleCardSourceSha") is String \
				or not _pinned_source_matches("combat:deck_progression",
					String(candidate["deckProgressionSourceSha"])) \
				or not _pinned_source_matches("cards:battle_cards",
					String(candidate["battleCardSourceSha"])):
			return false
	if not combat_commit and not _legacy_fragment_flow.settle(state, candidate, _legacy_fragment_replay,
			_legacy_fragment_replay_activation_index,
			_legacy_fragment_replay_initial_seed):
		return false
	var next_mentor: Dictionary = MentorFlow.advance(state, candidate, _mentor_state,
		not _legacy_mentor_stage_replay, mentor_cultivation_events,
		not _legacy_mentor_heir_replay and int(candidate.get("runClock", {}).get(
			"decisionIndex", 0)) >= _mentor_heir_activation_index,
		not _legacy_mentor_climax_replay and int(candidate.get("runClock", {}).get(
			"decisionIndex", 0)) >= _mentor_climax_activation_index)
	if not _legacy_mentor_replay:
		candidate["mentorArcState"] = next_mentor.duplicate(true)
	if candidate.has("allyArcState") and not _ally_arc_flow.advance(state, candidate):
		_mark_source_failure(_content)
		return false
	if candidate.has("companionArcState") \
			and not _companion_arc_flow.advance(state, candidate):
		_mark_source_failure(_content)
		return false
	if candidate.has("seerArcState") and not _seer_arc_flow.advance(state, candidate):
		_mark_source_failure(_content)
		return false
	var contractual_tick_allowed := _delivery_eligible_for_tick(state, candidate)
	if not _ghost_debt_flow.settle(state, candidate, contractual_tick_allowed):
		return false
	var ghost_debt_queued: bool = candidate.has("pendingGhostDebtId")
	var serial_route: bool = state.get("phase") == "FIRST_SESSION_ROUTE_PENDING" \
		and state.get("currentCardId") == FirstSessionRoute.ROUTE_ID \
		and candidate.get("currentCardId") == FirstSessionRoute.MARKET_ID
	if not combat_commit and not ghost_debt_queued and not serial_route:
		if not _destiny_wheel_flow.settle(state, candidate, _legacy_wheel_replay,
				_legacy_wheel_replay_activation_index, _legacy_wheel_replay_initial_seed):
			return false
		if not _ripple_flow.settle(state, candidate, _legacy_ripple_replay,
				_legacy_ripple_replay_activation_index, _legacy_ripple_replay_initial_seed):
			return false
		if not _hint_flow.settle(state, candidate, _legacy_hint_replay,
				_legacy_hint_replay_activation_index, _legacy_hint_replay_initial_seed):
			return false
	if not _licensed_delivery.settle(state, candidate, contractual_tick_allowed):
		return false
	if not _trade_route_flow.settle(state, candidate):
		return false
	var delivery_queued: bool = candidate.get("pendingLicensedDeliveryOrderId") != null \
		and candidate.get("pendingLicensedDeliveryOrderId") != state.get(
			"pendingLicensedDeliveryOrderId")
	if not serial_route and not _market_flow.settle(state, candidate, _legacy_market_replay,
			_legacy_market_replay_activation_index, _legacy_market_replay_initial_seed,
			(delivery_queued and not combat_commit) or ghost_debt_queued or not contractual_tick_allowed):
		return false
	if not _story_thread_flow.tick(state, candidate):
		_mark_thread_failure(_story_thread_flow)
		return false
	if candidate_index > prior_index and not _settle_first_session_continuation(candidate, serial_route):
		return false
	if candidate_index > prior_index and not _settle_normal_continuation(candidate):
		return false
	if death_checkpoint is Dictionary:
		# Due ambient cards may be queued on the same decision, but death remains
		# the visible, durable checkpoint until the player resolves it.
		candidate["phase"] = "DEATH_PENDING"
		candidate["currentCardId"] = candidate.get("deathCauseId")
		candidate["decisionCheckpoint"] = death_checkpoint
	if not death_source_id.is_empty() and candidate_index > prior_index:
		if int(candidate.get("attributes", {}).get("daoHeart", 1)) > 0 \
				and int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				and int(candidate.get("maxHealth", 1)) > 1 \
				and int(candidate.get("maxDaoHeart", 1)) > 1:
			candidate["maxHealth"] = int(candidate.maxHealth) - 1
			candidate["maxDaoHeart"] = int(candidate.maxDaoHeart) - 1
			candidate.attributes.health = 1
			candidate.attributes.daoHeart = mini(int(candidate.attributes.daoHeart),
				int(candidate.maxDaoHeart))
		elif int(candidate.get("attributes", {}).get("daoHeart", 1)) <= 0 \
				or int(candidate.get("attributes", {}).get("health", 1)) <= 0 \
				or int(candidate.get("resources", {}).get("lifespan", 1)) <= 0:
			var fatal: Dictionary = _death_flow.prepare_death(candidate, death_source_id)
			if fatal.is_empty():
				return false
			candidate.clear()
			candidate.merge(fatal, true)
	if dungeon_visible and candidate.get("dungeonRun") is Dictionary \
			and candidate.dungeonRun.get("status") == "active" \
			and candidate.get("phase") != "DEATH_PENDING":
		candidate["phase"] = "NORMAL_PENDING"
		candidate["currentCardId"] = dungeon_card_id
		candidate["decisionCheckpoint"] = dungeon_checkpoint
	if not candidate.has("worldPulseState") \
			and candidate_index >= _world_pulse_activation_index \
			and candidate_index > prior_index:
		candidate["worldPulseState"] = WorldPulse.initial(state if not state.is_empty()
			else candidate, _world_pulse_activation_index)
	if candidate.has("worldPulseState"):
		if not WorldPulse.valid(candidate.worldPulseState):
			return false
		var pulse_event: Dictionary = _world_pulse_choice(candidate, prior_index,
			candidate_index)
		if not WorldPulse.settle(state, candidate, pulse_event.get("card", {}),
				pulse_event.get("choice", {}), String(pulse_event.get("outcome", ""))):
			return false
	if not candidate.has("factionEventState") \
			and candidate_index >= _faction_activation_index \
			and (state.is_empty() or candidate_index > prior_index):
		candidate["factionEventState"] = _faction_events.marker(
			_faction_activation_index)
		if not candidate.has("factionProgress"):
			candidate["factionProgress"] = _faction_events.baseline_progress()
	if candidate.has("factionEventState") and not _faction_events.valid(candidate):
		return false
	if not _replaying_history and _legacy_faction_collection_replay \
			and _faction_collection_new_activation_index > 0 \
			and candidate.has("factionEventState") \
			and candidate_index >= _faction_collection_new_activation_index \
			and not candidate.has("factionCollectionNewActivationIndex"):
		candidate["factionCollectionNewActivationIndex"] = \
			_faction_collection_new_activation_index
	if not _sync_replay_history(candidate):
		return false
	if _store == null:
		_mentor_state = next_mentor
		return true
	if _store.has_method("commit_snapshot"):
		var committed: Dictionary = _store.commit_snapshot(candidate, _store_revision)
		if committed.get("ok") != true:
			return false
		_store_revision = int(committed.get("revision", -1))
		if _store_revision < 0:
			return false
		_mentor_state = next_mentor
		return true
	var saved: bool = _store.save_state(candidate)
	if saved:
		_mentor_state = next_mentor
	return saved


func _world_pulse_choice(candidate: Dictionary, prior_index: int,
		candidate_index: int) -> Dictionary:
	if candidate_index <= prior_index or candidate.get("choiceHistory", []).is_empty():
		return {}
	var record: Dictionary = candidate.choiceHistory.back()
	if int(record.get("decisionIndex", -1)) != candidate_index:
		return {}
	var card: Dictionary = {}
	var choice: Dictionary = {}
	if state.get("phase") == "COMBAT_HANDOFF" \
			and String(record.get("cardId", "")).begins_with("encounter_card_") \
			and candidate_index >= int(candidate.get(
				"earlyAvoidActivationIndex", 2147483647)):
		card = CatalogEncounter.new(_content).card(state, String(record.cardId))
		choice = card.get("choices", {}).get(String(record.get("direction", "")), {})
	if state.get("phase") == "BATTLE_PENDING":
		var resolution: Dictionary = state.get("pendingBattle", {}).get(
			"pendingResolution", {})
		card = resolution.get("sourceCard", {})
		choice = resolution.get("choice", {})
	if card.is_empty():
		card = get_current_card()
	var record_card_id := String(record.get("cardId", ""))
	if card.get("id") != record_card_id or (record_card_id.begins_with(
			"encounter_card_") and String(card.get("title", "")).is_empty()):
		var found: Dictionary = _content.find("card", record_card_id)
		card = found.get("data", {})
		if card.is_empty() and record_card_id.begins_with("encounter_card_"):
			card = CatalogEncounter.new(_content).card(state,
				record_card_id)
	if choice.is_empty():
		choice = card.get("choices", {}).get(String(record.get("direction", "")), {})
	return {"card": card, "choice": choice,
		"outcome": record.get("combatOutcome", "")}


func _settle_normal_continuation(candidate: Dictionary) -> bool:
	var promise: Dictionary = candidate.get("authoredNormalNext",
		state.get("pendingNormalContinuation", {}))
	if promise.is_empty():
		return true
	if promise.get("sourceCardId") != "dp_demon_recruit_again" \
			or promise.get("cardId") != "dp_demon_truth":
		return false
	var source: Dictionary = _normal_choice_policy.source_card(
		String(promise.cardId), candidate)
	if source.is_empty():
		return false
	var interrupted: bool = candidate.get("phase") != "FLOW_PENDING"
	for key in ["pendingGhostDebtId", "pendingLicensedDeliveryOrderId",
			"pendingRippleCard", "pendingHintCard", "pendingDestinyWheel",
			"pendingMarketCard"]:
		interrupted = interrupted or candidate.get(key) != null \
			and candidate.get(key) != state.get(key)
	candidate.erase("authoredNormalNext")
	if interrupted:
		candidate["pendingNormalContinuation"] = promise.duplicate(true)
		return true
	candidate.erase("pendingNormalContinuation")
	candidate["phase"] = "NORMAL_PENDING"
	candidate["currentCardId"] = promise.cardId
	candidate["decisionCheckpoint"] = {"version": 1,
		"cardId": promise.cardId, "sourceCardId": promise.sourceCardId,
		"turn": candidate.turn,
		"decisionIndex": candidate.runClock.decisionIndex,
		"flowSource": "authored:nextCard"}
	return true


func _settle_first_session_continuation(candidate: Dictionary, serial_route: bool) -> bool:
	# Source game.js: a continuation held on entry returns after one inserted
	# decision. A newly queued ambient event can suspend an explicit nextCard;
	# merely having an eligible chapter does not take that nextCard away.
	var target := String(state.get("firstSessionContinuation", ""))
	var returning := not target.is_empty()
	if target.is_empty():
		target = String(candidate.get("authoredFirstSessionNext", ""))
	if serial_route:
		target = FirstSessionRoute.MARKET_ID
	if target.is_empty():
		return true
	if target not in [FirstSessionRoute.ROUTE_ID, FirstSessionRoute.MARKET_ID]:
		return false
	var interrupted := false
	for key in ["pendingGhostDebtId", "pendingLicensedDeliveryOrderId"]:
		interrupted = interrupted or candidate.get(key) != null and candidate.get(key) != state.get(key)
	if not serial_route:
		for key in ["pendingRippleCard", "pendingHintCard", "pendingDestinyWheel", "pendingMarketCard"]:
			interrupted = interrupted or candidate.get(key) != null and candidate.get(key) != state.get(key)
		interrupted = interrupted or candidate.get("phase") == "DESTINY_WHEEL_PENDING"
	candidate.erase("authoredFirstSessionNext")
	if interrupted and not returning:
		candidate["firstSessionContinuation"] = target
		if candidate.get("phase") != "DESTINY_WHEEL_PENDING":
			candidate["phase"] = "FLOW_PENDING"
			candidate["currentCardId"] = ""
			candidate["decisionCheckpoint"] = {"version": 1, "cardId": null,
				"sourceCardId": state.get("currentCardId"), "turn": candidate.turn,
				"decisionIndex": candidate.runClock.decisionIndex, "flowPending": true}
		return true
	if target == FirstSessionRoute.ROUTE_ID and not returning and not serial_route \
			and candidate.get("encounterCadence", {}).get("activationIndex") == 0:
		# The first combat reward can queue a due chapter before its authored
		# mountain-route continuation. Keep that destination across the insert.
		candidate["firstSessionContinuation"] = target
		var chapter: Dictionary = _milestone_flow.resume(candidate)
		if not _milestone_flow.last_error.is_empty():
			return false
		if not chapter.is_empty():
			candidate.clear()
			candidate.merge(chapter, true)
			return true
		candidate.erase("firstSessionContinuation")
	var next: Dictionary = _first_session_route.enter(candidate, target)
	if next.is_empty():
		_mark_source_failure(_content)
		_mark_battle_return_failure(_first_session_route)
		return false
	next.erase("firstSessionContinuation")
	candidate.clear()
	candidate.merge(next, true)
	return true


func _validate_choice(choice: Dictionary) -> bool:
	for key in choice:
		if not key in CHOICE_KEYS:
			return false
	if choice.has("nextCard") and (not choice["nextCard"] is String or String(choice["nextCard"]).is_empty()):
		return false
	if not choice.get("effects", {}) is Dictionary:
		return false
	var effects: Dictionary = choice.get("effects", {})
	for key in effects:
		if not key in TUTORIAL_EFFECT_KEYS or not _valid_integer(effects[key]):
			return false
	return true


func _apply_effect(target: Dictionary, key: String, amount: int) -> bool:
	var attributes: Dictionary = target["attributes"]
	var resources: Dictionary = target["resources"]
	if key in ["cultivation", "daoHeart", "health", "fortune", "karmaGood", "karmaBad"]:
		amount = LegacyFragmentFlow.effective_delta(target, key, amount)
		var maximum := 100
		match key:
			"cultivation": maximum = _cultivation_max
			"daoHeart": maximum = LegacyFragmentFlow.actual_max_dao_heart(target)
			"health": maximum = LegacyFragmentFlow.actual_max_health(target)
		if key == "health" and amount < 0 and int(attributes["aura"]) > 0:
			var absorbed := mini(int(attributes["aura"]), -amount)
			attributes["aura"] = int(attributes["aura"]) - absorbed
			amount += absorbed
		attributes[key] = clampi(int(attributes[key]) + amount, 0, maximum)
		return true
	if key in ["spiritStone", "lifespan"]:
		resources[key] = maxi(0, int(resources[key]) + amount)
		return true
	return false


func _valid_integer(value: Variant) -> bool:
	# Godot JSON parses authored integral numbers as floats.
	return value is int or (value is float and value == floor(value) and absf(value) < 1000000000.0)
