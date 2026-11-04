extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const EvidenceAtlas = preload("res://scripts/noncombat_evidence_atlas.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("evidence atlas source run could not start")
	var atlas = EvidenceAtlas.new(Repository.new())
	var initial: Dictionary = atlas.project(game.state)
	if initial.get("sourceSha256", "").length() != 64 \
			or initial.get("totalClues") != 5 \
			or initial.get("discoveredClues", []).size() != 0 \
			or initial.get("hypotheses", []).size() != 4 \
			or initial.get("endings", []).size() != 3 \
			or _find(initial.hypotheses, "heaven_harvest").get("confidence") != 0 \
			or _find(initial.endings, "ascension").get("eligible") != false:
		return _fail("initial source catalog or locked ending is wrong")
	var advanced: Dictionary = game.state.duplicate(true)
	advanced["clues"] = [{"id": "century_war_truth", "source": "test",
		"life": 1, "turn": 7}, {"id": "ancient_prophecy_warning",
		"source": "test", "life": 2, "turn": 9}]
	advanced["noncombatFlow"] = {"hintClues": [{"id": "ancient_sword_manual",
		"sourceCardId": "old_save"}]}
	advanced["realm"] = "tribulation"
	advanced["npcAffection"] = {"bai_ren": 63}
	var found: Dictionary = atlas.project(advanced)
	if found.get("discoveredClues", []).size() != 3 \
			or _find(found.hypotheses, "heaven_harvest").get("confidence") != 100 \
			or _find(found.hypotheses, "reincarnation_anchor").get("confidence") != 50 \
			or _find(found.hypotheses, "reincarnation_anchor").get("status") != "plausible" \
			or _find(found.endings, "chaos").get("eligible") != false \
			or _find(found.endings, "ascension").get("progress") != 50:
		return _fail("clue discovery, old-save clue or terminal gate projection is wrong")
	advanced["clues"].append({"id": "xuesha_laozu_past_love", "source": "test",
		"life": 2, "turn": 13})
	advanced["terminalContext"] = {"gateId": "tribulation_finale",
		"encounterId": "ch_tribulation_100", "encounterInstanceId": "atlas-test",
		"victoryToken": "combat:atlas-test", "outcome": "victory",
		"stage": "REWARD_PENDING", "consumed": false,
		"eligibilitySnapshot": {"version": 1, "realm": "tribulation",
			"clueIds": ["century_war_truth", "ancient_prophecy_warning",
				"ancient_sword_manual", "xuesha_laozu_past_love"],
			"hypothesisConfidence": {"heaven_harvest": 100,
				"reincarnation_anchor": 100, "bond_exception": 100},
			"maxBond": 63}}
	var unfrozen: Dictionary = advanced.duplicate(true)
	unfrozen.terminalContext.erase("eligibilitySnapshot")
	if _find(atlas.project(unfrozen).endings, "ascension").get("eligible") != false:
		return _fail("terminal victory without a frozen snapshot appeared eligible")
	var victorious: Dictionary = atlas.project(advanced)
	for ending_id in ["ascension", "red_dust", "chaos"]:
		if _find(victorious.endings, ending_id).get("eligible") != true:
			return _fail("valid final victory did not unlock " + ending_id)
	advanced["terminalContext"]["eligibilitySnapshot"]["maxBond"] = 59
	if _find(atlas.project(advanced).endings, "red_dust").get("eligible") != false:
		return _fail("frozen final-victory bond was replaced by live affection")
	advanced["terminalContext"]["stage"] = "EPILOGUE"
	if _find(atlas.project(advanced).endings, "ascension").get("eligible") != false:
		return _fail("consumed terminal gate still appeared eligible")
	var view: Control = OpeningScene.instantiate()
	view.save_path = ""
	root.add_child(view)
	await process_frame
	view.opening = game
	view.story_screen.visible = true
	view._render()
	var before: Dictionary = game.state.duplicate(true)
	var button: Button = view.get_node_or_null(
		"DesktopMargin/ScreenStack/StoryScreen/StoryUtilities/OpenEvidenceAtlas")
	if button == null:
		return _fail("desktop story has no evidence atlas entry")
	button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog = view.evidence_atlas_dialog
	var tabs: TabContainer = dialog.find_child("EvidenceAtlasTabs", true, false)
	var pulse_label: Label = dialog.find_child("EvidenceWorldPulse", true, false)
	if not dialog.visible or tabs == null or tabs.get_tab_count() != 3 \
			or pulse_label == null or not pulse_label.text.contains("灵脉平稳") \
			or dialog.find_child("AtlasHypothesis_heaven_harvest", true, false) == null \
			or dialog.find_child("AtlasEnding_chaos", true, false) == null \
			or not String(dialog.find_child("EvidenceAtlasSummary", true, false).text).contains("0/5") \
			or game.state != before:
		return _fail("desktop atlas did not show source sections or mutated the run")
	tabs.current_tab = 1
	await process_frame
	var hypothesis_card: PanelContainer = dialog.find_child(
		"AtlasHypothesis_heaven_harvest", true, false)
	if not hypothesis_card.is_visible_in_tree() \
			or not String(hypothesis_card.get_child(0).get_child(0).text).contains(
				"天劫并非考验，而是收割") \
			or not String(hypothesis_card.get_child(0).get_child(2).text).contains(
				"筛选和回收高阶神魂"):
		return _fail("source hypothesis wording is not visible in its desktop tab")
	tabs.current_tab = 2
	await process_frame
	var ending_card: PanelContainer = dialog.find_child(
		"AtlasEnding_chaos", true, false)
	if not ending_card.is_visible_in_tree() \
			or not String(ending_card.get_child(0).get_child(3).text).contains(
				"通过终局门禁"):
		return _fail("ending reasons are not visible in the desktop tab")
	dialog.hide()
	game.state["clues"] = advanced["clues"].duplicate(true)
	game.state["noncombatFlow"] = advanced["noncombatFlow"].duplicate(true)
	button.pressed.emit()
	await process_frame
	var clue_card: PanelContainer = view.evidence_atlas_dialog.find_child(
		"AtlasClue_century_war_truth", true, false)
	var old_clue_card: PanelContainer = view.evidence_atlas_dialog.find_child(
		"AtlasClue_ancient_sword_manual", true, false)
	if clue_card == null or old_clue_card == null \
			or not clue_card.is_visible_in_tree() \
			or not String(clue_card.get_child(0).get_child(0).text).contains(
				"百年旧战真相") \
			or not String(clue_card.get_child(0).get_child(1).text).contains(
				"战争更像一次针对修士的筛选") \
			or not String(old_clue_card.get_child(0).get_child(2).text).contains(
				"旧版留存证据") \
			or not String(view.evidence_atlas_dialog.find_child(
				"EvidenceAtlasSummary", true, false).text).contains("4/5"):
		return _fail("reopening the atlas did not project newly acquired clues")
	view.evidence_atlas_dialog.hide()
	view.queue_free()
	await process_frame
	print("NONCOMBAT_EVIDENCE_ATLAS_PASS clues=5 hypotheses=4 endings=3 desktop=true read_only=true")
	quit(0)


func _find(rows: Array, item_id: String) -> Dictionary:
	for row in rows:
		if row.get("id") == item_id:
			return row
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
