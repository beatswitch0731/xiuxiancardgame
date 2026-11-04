extends "res://tests/noncombat_death_rebirth_journey.gd"

const Resolver = preload("res://scripts/battle_plan_resolver.gd")
const Combat = preload("res://scripts/combat_domain.gd")

class BrokenSource extends "res://scripts/noncombat_content_repository.gd":
	var missing_quest := false
	var changed_warning := false
	func source_sha256(module_id: String) -> String:
		return "" if missing_quest and module_id == "quests:white_fox" else super.source_sha256(module_id)
	func module_path(module_id: String) -> String:
		return "" if missing_quest and module_id == "quests:white_fox" else super.module_path(module_id)
	func asset_status(path: String) -> Dictionary:
		var status: Dictionary = super.asset_status(path)
		if changed_warning and path.ends_with("battlefield_hound_wilderness_pc98_v1.png"):
			status.shaVerified = false
			status.textureLoadable = false
		return status


func _run() -> void:
	var base = _second_life_third()
	if base == null:
		return
	base = _reload(base, "third_quest")
	if base == null:
		return
	var third: Dictionary = base.state.duplicate(true)
	for outcome in ["victory", "defeat", "flee"]:
		var store = RunSession.new("user://tests/whitefox_rebirth_%s_%d.json" % [
			outcome, Time.get_ticks_usec()], "slot_3")
		if store.commit_snapshot(third, -1).get("ok") != true:
			return _fail("could not stage second-life branch")
		var game = Domain.new(Registry.new(), store, "slot_3")
		_stabilize_ambient(game)
		if not game.restore() or not game.choose("left", game.issue_choice_token()):
			return _fail("second-life left could not create warning")
		if outcome == "victory":
			game = _reload(game, "warning")
			if game == null:
				return
			if not _broken_restore(game, true, "SOURCE_UNAVAILABLE"):
				return
		var direction := "right" if outcome == "victory" else "left"
		var before: Dictionary = game.state.duplicate(true)
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("second-life warning confirmation")
		var request: Dictionary = game.battle_request()
		if request.is_empty() or not String(request.encounterInstanceId).contains("slot_3:life:1:") \
				or game.state.turn != before.turn or not _same(game.state.questState, before.questState) \
				or not _same(request.playerSnapshot.battleLoadout.deck, before.deck) \
				or int(game.state.resources.spiritStone) != int(before.resources.spiritStone) - (10 if direction == "right" else 0):
			return _fail("second-life preparation owner/deck/quest/cost")
		if outcome == "victory":
			game = _reload(game, "paid_pending")
			if game == null or not _same(game.battle_request(), request):
				return _fail("second-life pending request changed across restart")
			if not _broken_restore(game, false, "SOURCE_MISMATCH"):
				return
			var plan: Dictionary = Resolver.new(Registry.new()).resolve_persisted(game.state)
			var combat = Combat.new(Registry.new())
			if plan.get("launchAuthorized") != true \
					or not combat.load_persisted_request(request, plan) \
					or combat.state.get("enemy", {}).get("def", {}).get("id") != "hound_pack_qi":
				return _fail("second-life authored hound battle could not launch")
		var result := _battle_result(request, outcome)
		if not game.submit_battle_result(result):
			return _fail("second-life outcome settlement: " + outcome)
		game = _reload(game, outcome + "_result")
		if game == null:
			return
		if outcome == "victory":
			if game.state.questState.questOutcomes.get("white_fox_line") != "completed" \
					or not _forged_result_rejected(game, "duplicate_history") \
					or not _forged_result_rejected(game, "foreign_owner"):
				return _fail("second-life quest completion/history forgery")
		elif game.state.questState.activeQuests.size() != 1 \
				or game.state.questState.activeQuests[0].step != 2:
			return _fail("second-life nonwin closed the quest")
		var acknowledgement := "left" if outcome == "victory" else "down"
		if not game.choose(acknowledgement, game.issue_choice_token()):
			return _fail("second-life result acknowledgement: " + outcome)
		game = _reload(game, outcome + "_acknowledged")
		if game == null or not game.resume_flow():
			return _fail("second-life acknowledged flow did not continue")
		if outcome != "victory":
			if not _return_to_third(game):
				return _fail("second-life nonwin could not return to active third quest")
			if not game.choose("left", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()):
				return _fail("second-life repeated challenge blocked")
			var retried: Dictionary = game.battle_request()
			var retry_state: Dictionary = game.state.duplicate(true)
			if retried.is_empty() or retried.encounterInstanceId == request.encounterInstanceId \
					or game.submit_battle_result(result) or not _same(game.state, retry_state):
				return _fail("second-life old result owner accepted on repeat")
			game = _reload(game, outcome + "_retry_pending")
			if game == null or not game.submit_battle_result(_battle_result(retried, "victory")):
				return _fail("second-life repeated battle could not settle")
			game = _reload(game, outcome + "_retry_victory")
			if game == null or game.state.battleResultHistory.size() != 2:
				return _fail("second-life repeated battle history was lost")
		print("WHITEFOX_REBIRTH_OUTCOME_PASS " + outcome)
	print("NONCOMBAT_WHITEFOX_REBIRTH_PASS life=1 inheritance=1 warning=true paid=true outcomes=3 retry=2 source=true forged=true replay=true")
	quit(0)


func _second_life_third() -> RefCounted:
	var path := "user://tests/whitefox_rebirth_base_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store.v2_path).get_base_dir())
	var file := FileAccess.open(store.v2_path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var prior = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(prior)
	if not prior.restore():
		_fail("second-life source death route restore")
		return null
	if not prior.resume_flow():
		_fail("second-life source death route resume: " + prior.flow_failure_reason())
		return null
	if not prior.choose("right", prior.issue_choice_token()):
		_fail("second-life source death route choice: " + String(prior.get_current_card().get("id", "")))
		return null
	# The supported v1 inheritance archive predates persistent closed quests.
	var old_life: Dictionary = prior._rebirth_flow.new_life(prior.state,
		prior.get_current_card(), "right", "slot_3", 1)
	if old_life.get("rebirthInheritanceVersion") != 1 \
			or store.commit_life_transition(old_life, prior._store_revision, "right").get("ok") != true:
		_fail("could not stage supported old inheritance")
		return null
	var game = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	_stabilize_ambient(game)
	if not game.restore():
		_fail("old inheritance continuation restore")
		return null
	if not game.select_rebirth_path("body"):
		_fail("old inheritance continuation select path")
		return null
	if not game.choose("down", game.issue_choice_token()):
		_fail("old inheritance continuation boon choice")
		return null
	if not game.cancel_camp_target(game.issue_choice_token()):
		_fail("old inheritance continuation camp cancel")
		return null
	for expected in ["q_fortune", "ch_qi_20"]:
		if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
			_fail("second-life route resume: " + expected + " / " + game.flow_failure_reason())
			return null
		if game.get_current_card().get("id") != expected \
				or not game.choose("left", game.issue_choice_token()):
			_fail("second-life route source: expected=%s actual=%s phase=%s index=%d" % [
				expected, game.get_current_card().get("id"), game.state.get("phase"),
				int(game.state.get("runClock", {}).get("decisionIndex", -1))])
			return null
	if game.state.phase == "FLOW_PENDING" and not game.resume_flow():
		_fail("second-life due catalog did not surface")
		return null
	if not _avoid_due_second_life_catalog(game):
		_fail("second-life due catalog could not be avoided")
		return null
	if not game.resume_flow() or game.get_current_card().get("id") != "q_whiteFox_quest":
		_fail("second-life quest entry: " + String(game.get_current_card().get("id", "")))
		return null
	if not game.choose("right", game.issue_choice_token()):
		_fail("second-life quest entry choice")
		return null
	if not game.choose("left", game.issue_choice_token()) \
			or game.state.currentCardId != "q_whiteFox_3":
		_fail("second-life natural third quest: " + String(game.state.get("currentCardId", "")))
		return null
	print("WHITEFOX_REBIRTH_CASE_PASS natural_second_life_third")
	return game


func _reload(game: RefCounted, label: String) -> RefCounted:
	var bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var reopened = Domain.new(Registry.new(), RunSession.new(game._store.legacy_path, "slot_3"), "slot_3")
	_stabilize_ambient(reopened)
	if not reopened.restore() or not _same(reopened.state, game.state) \
			or FileAccess.get_file_as_bytes(game._store.v2_path) != bytes:
		_fail("second-life strict reload %s: %s" % [label, reopened._store.last_error])
		return null
	print("WHITEFOX_REBIRTH_CASE_PASS " + label)
	return reopened


func _return_to_third(game: RefCounted) -> bool:
	for i in 8:
		if game.state.currentCardId == "q_whiteFox_3":
			return true
		if game.state.phase == "FLOW_PENDING":
			if not game.resume_flow():
				return false
		elif game.state.phase == "MILESTONE_PENDING":
			if not game.choose("left", game.issue_choice_token()):
				return false
		else:
			return false
	return false


func _broken_restore(game: RefCounted, missing: bool, expected: String) -> bool:
	var content := BrokenSource.new()
	content.missing_quest = missing
	content.changed_warning = not missing
	var store = RunSession.new(game._store.legacy_path, "slot_3")
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var broken = Domain.new(Registry.new(), store, "slot_3", content)
	_stabilize_ambient(broken)
	if broken.restore() or not broken.state.is_empty() or store.last_error != expected \
			or not store.archive_unrestorable().is_empty() \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		_fail("second-life source classification/preservation: " + expected + "/" + store.last_error)
		return false
	print("WHITEFOX_REBIRTH_CASE_PASS source " + expected)
	return true


func _forged_result_rejected(game: RefCounted, kind: String) -> bool:
	var forged: Dictionary = game.state.duplicate(true)
	if kind == "duplicate_history":
		forged.battleResultHistory.append(forged.battleResultHistory.back().duplicate(true))
	else:
		forged.battleResultHistory[0].result.encounterInstanceId = "enc:slot_3:life:0:8:q_whiteFox_3:1"
	var store = RunSession.new("user://tests/whitefox_rebirth_forged_%s_%d.json" % [
		kind, Time.get_ticks_usec()], "slot_3")
	if store.commit_snapshot(forged, -1).get("ok") != true:
		return false
	var bytes := FileAccess.get_file_as_bytes(store.v2_path)
	var rejected = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(rejected)
	if rejected.restore() or not rejected.state.is_empty() \
			or FileAccess.get_file_as_bytes(store.v2_path) != bytes:
		_fail("second-life forged battle accepted: " + kind)
		return false
	print("WHITEFOX_REBIRTH_CASE_PASS forged " + kind)
	return true


func _battle_result(request: Dictionary, outcome: String) -> Dictionary:
	return {"contractVersion": 2, "encounterInstanceId": request.encounterInstanceId,
		"sourceCardId": request.sourceCardId, "encounterId": request.encounterId,
		"sourceContentHash": request.sourceContentHash, "outcome": outcome,
		"combatReceipt": "combat:" + String(request.encounterInstanceId),
		"postBattleState": {"encounterInstanceId": request.encounterInstanceId,
			"terminal": true, "combatPhase": outcome.to_upper()}}


func _same(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
