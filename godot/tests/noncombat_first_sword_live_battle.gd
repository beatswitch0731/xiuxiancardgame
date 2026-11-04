extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const OpeningScene = preload("res://scenes/noncombat_opening.tscn")
const CombatDomain = preload("res://scripts/combat_domain.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")
const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://tests/first_sword_live_%d.json" % Time.get_ticks_usec()
	var game = Domain.new(Registry.new(), RunSession.new(save_path))
	if not game.start("sword") or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or not game.choose("left", game.issue_choice_token()) \
			or not game.choose("right", game.issue_choice_token()) \
			or game.state.get("phase") != "BATTLE_PENDING":
		_fail("source sword route did not persist the paid warning")
		return
	var request: Dictionary = game.battle_request()
	var before := FileAccess.get_file_as_string(game._store.v2_path)
	var direct = Domain.new(Registry.new(), RunSession.new(save_path))
	if not direct.restore():
		_fail("fresh domain cannot restore pending request: " + direct._store.last_error)
		return
	if not _victory_from_request(request, direct.state):
		return
	if not await _flee_from_request(request, direct.state):
		return
	var story: Control = OpeningScene.instantiate()
	story.save_path = save_path
	root.add_child(story)
	await process_frame
	var launch: Button = story.get_node_or_null(
		"DesktopMargin/ScreenStack/StoryScreen/SourceChoices/LaunchBattle")
	if launch == null or story.opening.state.get("phase") != "BATTLE_PENDING":
		_fail("desktop did not offer the persisted sword battle phase=%s status=%s store=%s name=%s" % [
			story.opening.state.get("phase"), story.status_label.text,
			story.opening_store.last_error, story.name_status_label.text])
		return
	launch.pressed.emit()
	await process_frame
	var battle: Control = story.active_battle
	if battle == null or battle.combat == null or battle.combat.state.get("phase") != "PLAYER_TURN" \
			or battle.combat.state.get("encounterId") != request.get("encounterId") \
			or battle.combat.state.get("player", {}).get("daoHeart") != \
				request.get("playerSnapshot", {}).get("attributes", {}).get("daoHeart") \
			or FileAccess.get_file_as_string(game._store.v2_path) != before:
		_fail("live battle did not load from the saved owner without settling it")
		return
	if story.opening_audio.bgm_player.stream == null \
			or not story.opening_audio.bgm_player.stream.resource_path.ends_with(
				"bgm/02_combat_pressure/bgm_02_combat_pressure.wav"):
		_fail("desktop battle did not switch to the source combat BGM")
		return
	for _turn in range(8):
		if battle.combat.state.get("phase") == "DEFEAT":
			break
		if battle.combat.state.get("phase") != "PLAYER_TURN":
			_fail("live battle left player turn without a terminal")
			return
		for index in range(battle.combat.state.get("hand", []).size()):
			var card_id: String = battle.combat.state["hand"][index]
			var card: Dictionary = battle.data.get_battle_card(card_id)
			if int(card.get("cost", 99)) <= 3 and card.get("type") == "attack":
				if not battle.combat.play_card(index):
					_fail("source attack card was rejected")
					return
				break
		battle.combat.input_locked = false
		if battle.combat.state.get("phase") == "VICTORY":
			_fail("defeat route unexpectedly defeated the enemy")
			return
		if not battle.combat.end_turn() or not battle.combat.choose_reaction("TAKE_HIT"):
			_fail("real combat actions could not advance the turn")
			return
		battle.combat.input_locked = false
	if battle.combat.state.get("phase") != "DEFEAT" \
			or battle.combat.state.get("outcome") != "defeat":
		_fail("source sword opening did not reach defeat from enemy damage")
		return
	var result_holder := {"value": {}}
	battle.battle_finished.connect(func(value: Dictionary) -> void:
		result_holder["value"] = value)
	battle.combat.input_locked = false
	battle.pending_presentations = 0
	battle._render()
	var return_button: Button = battle.get_node_or_null("ReturnToStory")
	if return_button == null or not return_button.visible or return_button.disabled:
		_fail("terminal desktop return button was unavailable")
		return
	story.opening_store.fail_promotion_once = true
	return_button.pressed.emit()
	await process_frame
	if story.active_battle != battle or story.opening.state.get("phase") != "BATTLE_PENDING" \
			or FileAccess.get_file_as_string(game._store.v2_path) != before \
			or not story.opening_audio.bgm_player.stream.resource_path.ends_with(
				"bgm/02_combat_pressure/bgm_02_combat_pressure.wav"):
		_fail("failed story write discarded the live combat terminal or changed the save")
		return
	return_button.pressed.emit()
	await process_frame
	var result: Dictionary = result_holder["value"]
	if result.get("outcome") != "defeat" or result.get("encounterInstanceId") != \
			request.get("encounterInstanceId") or result.get("postBattleState", {}).get(
			"playerHp") != 0 or story.opening.state.get("phase") == "BATTLE_PENDING" \
			or story.active_battle != null:
		_fail("real combat terminal did not commit once into story result=%s phase=%s active=%s" % [
			JSON.stringify(result).left(450), story.opening.state.get("phase"),
			story.active_battle != null])
		return
	if story.opening_audio.bgm_player.stream == null \
			or not story.opening_audio.bgm_player.stream.resource_path.ends_with(
				"bgm/01_sect_dawn/bgm_01_sect_dawn.wav"):
		_fail("desktop battle return did not restore the source sect BGM")
		return
	var restored = Domain.new(Registry.new(), RunSession.new(save_path))
	var restored_ok: bool = restored.restore()
	var same_state: bool = JSON.parse_string(JSON.stringify(restored.state)) == \
		JSON.parse_string(JSON.stringify(story.opening.state))
	if not restored_ok or not same_state or restored.submit_battle_result(result):
		_fail("terminal receipt was not durable or allowed duplicate settlement")
		return
	story.queue_free()
	await process_frame
	print("NONCOMBAT_FIRST_SWORD_LIVE_BATTLE_PASS desktop=true victory=true defeat=true flee=true replay=true")
	quit(0)


func _victory_from_request(request: Dictionary, pending: Dictionary) -> bool:
	var registry = Registry.new()
	var plan: Dictionary = BattlePlanResolver.new(registry).resolve_persisted(pending)
	var battle = CombatDomain.new(registry)
	var unsupported := request.duplicate(true)
	unsupported["lifeId"] = "slot_1:life:1"
	if battle.load_first_sword_request(unsupported, plan):
		_fail("later-life sword battle incorrectly entered the first-life combat slice")
		return false
	var source: Dictionary = registry.read_json("fixtures/m0_full_battle_expected.json")
	# The first five values reproduce the source opening hand. The remaining
	# values are the recorded post-opening draw tape from the source fight.
	var random_values := [0.20833, 0.25, 0.5625, 0.75, 0.125]
	random_values.append_array(source.get("randomValues", []))
	if not battle.set_replay_random_values(random_values) \
			or not battle.load_first_sword_request(request, plan):
		_fail("persisted sword battle could not start for victory route")
		return false
	var expected_hand := ["sword_probe", "sword_followthrough", "sword_guard",
		"sword_sheath_guard", "sword_edge"]
	if battle.state.get("hand") != expected_hand:
		_fail("request-derived opening hand diverged from the source deck shuffle")
		return false
	for step in source.get("steps", []):
		var action := String(step.get("action", ""))
		var accepted := false
		if action == "END_TURN":
			accepted = battle.end_turn()
		elif action == "TAKE_HIT":
			accepted = battle.choose_reaction("TAKE_HIT")
		else:
			accepted = battle.play_card(battle.state.get("hand", []).find(action))
		if not accepted:
			_fail("request-derived source action was rejected: " + action)
			return false
	if battle.state.get("phase") != "VICTORY" or battle.state.get("outcome") != "victory" \
			or battle.state.get("enemy", {}).get("hp") != 0:
		_fail("request-derived source actions did not produce victory")
		return false
	var battle_ui: Control = BattleScene.instantiate()
	battle_ui.combat = battle
	battle_ui.battle_request = request
	var victory_result: Dictionary = battle_ui.terminal_result()
	var next = Domain.new(Registry.new())
	if victory_result.get("outcome") != "victory" \
			or not next.start("sword") \
			or not next.choose("right", next.issue_choice_token()) \
			or not next.choose("left", next.issue_choice_token()) \
			or not next.choose("right", next.issue_choice_token()) \
			or not next.choose("left", next.issue_choice_token()) \
			or not next.choose("right", next.issue_choice_token()) \
			or next.battle_request().get("encounterInstanceId") != request.get(
				"encounterInstanceId") \
			or not next.submit_battle_result(victory_result) \
			or next.submit_battle_result(victory_result):
		_fail("actual sword victory was not accepted once by the story owner")
		return false
	battle_ui.free()
	return true


func _flee_from_request(request: Dictionary, pending: Dictionary) -> bool:
	var plan: Dictionary = BattlePlanResolver.new(Registry.new()).resolve_persisted(pending)
	var battle_ui: Control = BattleScene.instantiate()
	battle_ui.battle_request = request.duplicate(true)
	battle_ui.battle_plan = plan
	root.add_child(battle_ui)
	await process_frame
	var flee_button: Button = battle_ui.get_node_or_null("FleeBattle")
	if flee_button == null or not flee_button.visible or flee_button.disabled:
		_fail("source sword battle did not offer an active flee decision")
		return false
	flee_button.pressed.emit()
	var result: Dictionary = battle_ui.terminal_result()
	if battle_ui.combat.state.get("phase") != "FLEE" \
			or result.get("outcome") != "flee" \
			or result.get("postBattleState", {}).get("combatPhase") != "FLEE":
		_fail("real flee input did not produce a v2 terminal result")
		return false
	battle_ui.queue_free()
	await process_frame
	var story = Domain.new(Registry.new())
	if not story.start("sword") or not story.choose("right", story.issue_choice_token()) \
			or not story.choose("left", story.issue_choice_token()) \
			or not story.choose("right", story.issue_choice_token()) \
			or not story.choose("left", story.issue_choice_token()) \
			or not story.choose("right", story.issue_choice_token()) \
			or not story.submit_battle_result(result) \
			or story.submit_battle_result(result):
		_fail("real flee result was not settled exactly once")
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
