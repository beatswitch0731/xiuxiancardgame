extends Node

# A skeleton-relative action pack. AnimationPlayer owns editable Godot clips;
# AnimationTree owns idle/action transitions. Only semantic requests and the
# authored contact marker are handled in code, never per-frame bone posing.
signal action_contact(action_name: String)
signal action_finished(action_name: String)

const ACTIONS: AnimationLibrary = preload(
	"res://assets/actor_image3d_mvp/yelingyun_s1_actions.tres")
const IDLE := "idle_breath"

var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _current_action := ""
var _contact_emitted := false
var _contact_gate: Callable


func bind_skeleton(skeleton: Skeleton3D, action_pack: AnimationLibrary = ACTIONS) -> bool:
	if skeleton == null or _player != null:
		return false
	_skeleton = skeleton
	for bone in ["pelvis", "spine", "chest", "head", "upper_arm_L",
			"forearm_L", "hand_L"]:
		if skeleton.find_bone(bone) < 0:
			return false
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.root_node = _player.get_path_to(skeleton)
	_player.add_animation_library("", action_pack)

	var state_machine := AnimationNodeStateMachine.new()
	for clip_name in [IDLE, "sword_attack", "hurt"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		state_machine.add_node(clip_name, node)
	for route in [[IDLE, "sword_attack", 0.08],
			["sword_attack", IDLE, 0.14],
			[IDLE, "hurt", 0.05], ["hurt", IDLE, 0.12]]:
		var transition := AnimationNodeStateMachineTransition.new()
		transition.xfade_time = float(route[2])
		state_machine.add_transition(String(route[0]), String(route[1]), transition)

	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.tree_root = state_machine
	_tree.animation_finished.connect(_on_animation_finished)
	_tree.active = true
	_playback = _tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if _playback == null:
		return false
	_playback.start(IDLE)
	set_process(true)
	return true


func play_action(action_name: String) -> bool:
	if _playback == null or not is_idle():
		return false
	if action_name == IDLE:
		_playback.travel(IDLE)
		return true
	if action_name not in ["sword_attack", "hurt"]:
		return false
	_current_action = action_name
	_contact_emitted = false
	_playback.travel(action_name)
	return true


func set_contact_gate(gate: Callable) -> void:
	_contact_gate = gate


func is_idle() -> bool:
	return _current_action.is_empty() and _playback != null \
		and _playback.get_current_node() == IDLE


func current_action() -> String:
	return _current_action


func playback_position() -> float:
	if _playback == null:
		return 0.0
	# travel() schedules a state change. During its transition frame the state
	# machine still reports the previous idle time, which is not action time.
	if not _current_action.is_empty() and _playback.get_current_node() != _current_action:
		return 0.0
	return _playback.get_current_play_position()


func _process(_delta: float) -> void:
	if _current_action != "sword_attack" or _contact_emitted \
			or _playback.get_current_node() != "sword_attack":
		return
	var attack: Animation = _player.get_animation("sword_attack")
	if not attack.has_marker("contact"):
		return
	var action_time := _playback.get_current_play_position()
	var marker_time := attack.get_marker_time("contact")
	if action_time >= marker_time and action_time <= marker_time + 0.12 \
			and _contact_gate.is_valid() and _contact_gate.call():
		_contact_emitted = true
		action_contact.emit("sword_attack")


func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name) != _current_action:
		return
	var finished_length: float = _player.get_animation(_current_action).length
	if _playback.get_current_play_position() < finished_length - 0.05:
		return
	var finished := _current_action
	_current_action = ""
	# Defer the state reset until the current animation evaluation is complete.
	# A reset inside animation_finished can be overwritten by the same frame's
	# AnimationTree update and make the next request finish at time zero.
	_return_to_idle.call_deferred(finished)


func _return_to_idle(finished: String) -> void:
	_playback.start(IDLE, true)
	await get_tree().process_frame
	action_finished.emit(finished)
