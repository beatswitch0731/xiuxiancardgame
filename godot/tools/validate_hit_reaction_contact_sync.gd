extends SceneTree

# The victim must begin the authored hurt clip at the attacker's contact event,
# not after the attacker's full 526 ms animation completes.
var _frame_index := 0
var _contact_frame := -1
var _hurt_start_frame := -1
var _enemy_clip_at_contact := ""
var _finished := false


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var stage: Node = game.duel_stage
	stage.contact_frame.connect(func(side: String) -> void:
		if side == "player":
			_contact_frame = _frame_index
			_enemy_clip_at_contact = String(stage.get_actor_sprite("enemy").animation))
	stage.presentation_started.connect(func(_kind: String, side: String, clip: String) -> void:
		if side == "enemy" and clip == "hurt":
			_hurt_start_frame = _frame_index)
	stage.presentation_finished.connect(func(_kind: String) -> void: _finished = true)
	for tick in 16:
		await process_frame
	(game.hand_row.get_child(0) as Button).pressed.emit()
	for tick in 150:
		_frame_index += 1
		if _finished:
			break
		await process_frame
	if _contact_frame < 0 or _hurt_start_frame < 0 or not _finished:
		push_error("Missing contact, hurt clip, or completed card presentation")
		quit(1)
		return
	if _enemy_clip_at_contact != "hurt" or absi(_hurt_start_frame - _contact_frame) > 1:
		push_error("HIT_REACTION_SYNC_FAIL contact=%d hurt=%d enemy_at_contact=%s" % [
			_contact_frame, _hurt_start_frame, _enemy_clip_at_contact])
		quit(1)
		return
	print("HIT_REACTION_SYNC_PASS contact=%d hurt=%d enemy_at_contact=%s" % [
		_contact_frame, _hurt_start_frame, _enemy_clip_at_contact])
	quit(0)
