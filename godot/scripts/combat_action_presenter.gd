extends Node

# Presentation only. CombatDomain remains the sole owner of HP, block, qi and turn state.
# Frame and cue authority: data/combat/action_presentations.json.
# This first encounter serializes actions; wider state-machine interrupt rules remain outside this slice.
signal presentation_finished(event_type: String)
signal impact(source: String, target: String, action_family: String)
signal presentation_error(reason: String)

const ENCOUNTER_ID := "enc_trial_sword_swift"
const PATH_ID := "sword"
const CONTENT_ROOT := "res://content/"
const MELEE_HITSTOP_MS := 40.0

var data: RefCounted
var player_actor: TextureRect
var enemy_actor: TextureRect
var busy := false

var _catalog: Dictionary = {}
var _world: Dictionary = {}
var _static_metrics: Dictionary = {}
var _resting_textures: Dictionary = {}
var _pending_events: Array = []
var _current_event: Dictionary = {}
var _steps: Array = []
var _step: Dictionary = {}
var _frame_index := 0
var _frame_elapsed_ms := 0.0
var _impact_emitted := false
var _active_fx: Array = []


func _init(registry: RefCounted, player: TextureRect, enemy: TextureRect) -> void:
	data = registry
	player_actor = player
	enemy_actor = enemy
	_catalog = data.read_json("data/combat/action_presentations.json")
	var presentation: Dictionary = data.get_first_presentation()
	_world = data.read_json("data/combat/visual_worlds.json").get("worlds", {}).get(String(presentation.get("visualWorldId", "")), {})
	_resting_textures = {"player": player.texture, "enemy": enemy.texture}
	_static_metrics = {
		"player": _find_static_metric(data.get_sword_actor()),
		"enemy": _find_static_metric(presentation.get("actorCards", {}).get("enemy", {})),
	}
	set_process(false)


func play_event(event: Dictionary, combat_state: Dictionary = {}) -> bool:
	var event_type := String(event.get("type", ""))
	var requests: Array = []
	if event_type == "CARD_PLAY":
		var card_id := String(event.get("cardId", ""))
		var card_presentation := _card_presentation(card_id)
		if card_presentation.is_empty():
			return _error("No existing action presentation for card " + card_id)
		requests.append({"source": "player", "target": "enemy", "entry": card_presentation,
			"family": String(card_presentation.get("actionFamily", "guard"))})
		var hp_loss := 0
		for effect in event.get("effects", []):
			if effect is Dictionary and effect.get("type") == "damage":
				hp_loss += int(effect.get("hpLoss", 0))
		var cue_ids: Array = []
		for cue in _catalog.get("cardEffectPresentations", {}).get(card_id, []):
			if cue is Dictionary and cue.get("placement") == "contact":
				cue_ids.append(String(cue.get("cueId", "")))
		if hp_loss > 0:
			cue_ids.append("damage")
		var attack_request: Dictionary = requests[0]
		attack_request["vfx"] = cue_ids
		requests[0] = attack_request
		if String(combat_state.get("phase", "")) == "VICTORY":
			requests.append({"source": "enemy", "target": "enemy", "entry": _enemy_presentation("defeat"), "family": "defeat", "terminal": true})
		elif hp_loss > 0:
			requests.append({"source": "enemy", "target": "enemy", "entry": _enemy_presentation("hurt"), "family": "hurt"})
	elif event_type == "ENEMY_ACTION":
		var intent: Dictionary = event.get("intent", {})
		var reaction_id := String(event.get("reactionId", "TAKE_HIT"))
		if reaction_id != "TAKE_HIT":
			requests.append({"source": "player", "target": "player", "entry": _player_presentation("reaction"), "family": "reaction"})
		var family := "attack" if intent.get("type") == "attack" else "guard"
		requests.append({"source": "enemy", "target": "player" if family == "attack" else "enemy", "entry": _enemy_presentation(family), "family": family})
		if int(event.get("hpLoss", 0)) > 0:
			var enemy_request: Dictionary = requests[requests.size() - 1]
			enemy_request["vfx"] = ["damage"]
			requests[requests.size() - 1] = enemy_request
			requests.append({"source": "player", "target": "player", "entry": _player_presentation("hurt"), "family": "hurt"})
	elif event_type == "DEFEAT":
		requests.append({"source": "player", "target": "player", "entry": _player_presentation("defeat"), "family": "defeat", "terminal": true})
	else:
		return false

	# Resolve every image before displaying the first pose. Missing source assets
	# must leave the resting actor visible and make the migration failure explicit.
	var resolved: Array = []
	for request in requests:
		var step := _resolve_step(request)
		if step.is_empty():
			return false
		resolved.append(step)
	_pending_events.append({"type": event_type, "steps": resolved})
	if not busy:
		_start_next_event()
	return true


func _card_presentation(card_id: String) -> Dictionary:
	var authored: Dictionary = _catalog.get("cardActions", {}).get(card_id, {})
	if not authored.is_empty():
		return authored
	# The original system resolves this card through the sword path's guard
	# family. There is no card-specific action entry for sword_guard.
	if card_id == "sword_guard":
		return _player_presentation("guard")
	return {}


func _player_presentation(family: String) -> Dictionary:
	return _catalog.get("paths", {}).get(PATH_ID, {}).get(family, {})


func _enemy_presentation(family: String) -> Dictionary:
	return _catalog.get("encounters", {}).get(ENCOUNTER_ID, {}).get(family, {})


func _resolve_step(request: Dictionary) -> Dictionary:
	var entry: Dictionary = request.get("entry", {})
	var animation: Dictionary = entry.get("animation", {})
	var source := String(request.get("source", ""))
	if animation.get("kind") != "frame_sequence" or animation.get("motionApproved") != true:
		_error("Unapproved or absent frame sequence for " + source + "/" + String(entry.get("timelineId", "unknown")))
		return {}
	var paths: Array = animation.get("frames", [])
	var authored_durations: Array = animation.get("frameDurations", [])
	if paths.size() < 2 or paths.size() != authored_durations.size():
		_error("Invalid authored frame timing for " + String(animation.get("frameSetId", "unknown")))
		return {}
	var textures: Array = []
	var durations: Array = []
	var action_metric := _resolve_action_metric(animation, paths, source)
	if action_metric.is_empty():
		return {}
	for index in range(paths.size()):
		var source_path := String(paths[index])
		if not source_path.begins_with("assets/"):
			_error("Invalid original action frame path: " + source_path)
			return {}
		var texture: Texture2D = data.texture_for(source_path)
		if texture == null:
			_error("Missing migrated action frame: " + CONTENT_ROOT + source_path)
			return {}
		textures.append(texture)
		var duration := float(authored_durations[index])
		if duration < 16.0:
			_error("Invalid original frame duration: " + source_path)
			return {}
		durations.append(duration)
	var impact_index := int(animation.get("impactFrameIndex", -1))
	if impact_index < 0 or impact_index >= paths.size():
		impact_index = int(floor(float(paths.size()) / 2.0)) if paths.size() >= 3 else -1
	if impact_index >= 0:
		var authored_hold := float(animation.get("contactHoldMs", 0))
		if authored_hold >= 20.0 and authored_hold <= 40.0:
			durations[impact_index] = authored_hold
		else:
			var hitstop := MELEE_HITSTOP_MS if entry.get("stage", {}).get("contact", "melee") == "melee" else 20.0
			durations[impact_index] += hitstop
			if impact_index + 1 < durations.size():
				durations[impact_index + 1] = maxf(16.0, durations[impact_index + 1] - hitstop)
	# Original UI leaves the final pose on screen for one paint beat.
	durations[durations.size() - 1] += 32.0
	var vfx: Array = []
	for cue_id in request.get("vfx", []):
		var cue := _resolve_vfx(String(cue_id))
		if cue.is_empty():
			return {}
		vfx.append(cue)
	return {
		"source": source, "target": String(request.get("target", "")),
		"family": String(request.get("family", entry.get("actionFamily", ""))),
		"frame_set_id": String(animation.get("frameSetId", "")),
		"textures": textures, "durations": durations,
		"metric": action_metric,
		"impact_index": impact_index, "terminal": bool(request.get("terminal", false)),
		"vfx": vfx,
	}


func _resolve_vfx(cue_id: String) -> Dictionary:
	# The original combat system checks encounter-owned presentation VFX first.
	var entry: Dictionary = data.get_first_presentation().get("vfx", {}).get(cue_id, {})
	if entry.is_empty():
		entry = _catalog.get("semanticVfx", {}).get(cue_id, {})
	var paths: Array = entry.get("frames", [])
	if paths.is_empty():
		_error("Missing original VFX cue " + cue_id)
		return {}
	var textures: Array = []
	for source_path in paths:
		var texture: Texture2D = data.texture_for(String(source_path))
		if texture == null:
			_error("Missing migrated VFX frame: " + CONTENT_ROOT + String(source_path))
			return {}
		textures.append(texture)
	return {"id": cue_id, "textures": textures,
		"asset_id": String(entry.get("id", "")),
		"frame_ms": float(entry.get("durationMs", 0)) / float(paths.size())}


func _find_static_metric(actor_card: Dictionary) -> Dictionary:
	var source_path := String(actor_card.get("image", ""))
	var profile_id := String(actor_card.get("scaleProfileId", ""))
	for candidate in _world.get("carrierMetrics", {}).values():
		if candidate is Dictionary and candidate.get("assetPath") == source_path \
				and candidate.get("bodyProfileId") == profile_id:
			return candidate
	return {}


func _resolve_action_metric(animation: Dictionary, paths: Array, source: String) -> Dictionary:
	var frame_set_id := String(animation.get("frameSetId", ""))
	var metric: Dictionary = _world.get("actionCarrierMetrics", {}).get(frame_set_id, {})
	var static_metric: Dictionary = _static_metrics.get(source, {})
	if _resting_textures.get(source) == null:
		_error("Missing static actor texture needed for matched body scale: " + source)
		return {}
	var frame_files: Array = metric.get("frameFiles", [])
	var ground_y: Array = metric.get("groundAnchor", {}).get("frameY", [])
	var profile_id := String(static_metric.get("bodyProfileId", ""))
	if static_metric.is_empty() or metric.is_empty() or profile_id.is_empty() \
			or metric.get("bodyProfileId") != profile_id \
			or not _world.get("actorBodyProfiles", {}).has(profile_id) \
			or frame_files.size() != paths.size() or ground_y.size() != paths.size() \
			or float(metric.get("referenceHeight", 0)) <= 0.0 \
			or float(static_metric.get("bodyBounds", {}).get("height", 0)) <= 0.0:
		_error("Missing compatible body/feet metrics for " + frame_set_id)
		return {}
	for index in range(paths.size()):
		if frame_files[index].get("path") != paths[index] \
				or float(ground_y[index]) <= 0.0 or float(ground_y[index]) > 1.0:
			_error("Action frame/feet metric mismatch for " + frame_set_id)
			return {}
	return metric


func _start_next_event() -> void:
	if _pending_events.is_empty():
		busy = false
		set_process(not _active_fx.is_empty())
		return
	busy = true
	_current_event = _pending_events.pop_front()
	_steps = _current_event["steps"].duplicate()
	_start_next_step()
	set_process(true)


func _start_next_step() -> void:
	if _steps.is_empty():
		var completed_type := String(_current_event.get("type", ""))
		_current_event = {}
		presentation_finished.emit(completed_type)
		_start_next_event()
		return
	_step = _steps.pop_front()
	var actor: TextureRect = player_actor if _step["source"] == "player" else enemy_actor
	_step["rest"] = {"position": actor.position, "size": actor.size}
	_frame_index = 0
	_frame_elapsed_ms = 0.0
	_impact_emitted = false
	_show_frame()


func _show_frame() -> void:
	var actor: TextureRect = player_actor if _step["source"] == "player" else enemy_actor
	_apply_matched_geometry(actor)
	actor.texture = _step["textures"][_frame_index]
	if _frame_index == int(_step["impact_index"]) and not _impact_emitted:
		_impact_emitted = true
		for cue in _step["vfx"]:
			_start_fx(cue, String(_step["target"]))
		impact.emit(String(_step["source"]), String(_step["target"]), String(_step["family"]))


func _process(delta: float) -> void:
	_tick_fx(delta * 1000.0)
	if not busy or _step.is_empty():
		return
	_frame_elapsed_ms += delta * 1000.0
	while busy and not _step.is_empty():
		var hold := float(_step["durations"][_frame_index])
		if _frame_elapsed_ms < hold:
			break
		_frame_elapsed_ms -= hold
		_frame_index += 1
		if _frame_index < _step["textures"].size():
			_show_frame()
			continue
		var actor: TextureRect = player_actor if _step["source"] == "player" else enemy_actor
		if not bool(_step["terminal"]):
			actor.position = _step["rest"]["position"]
			actor.size = _step["rest"]["size"]
			actor.texture = _resting_textures[String(_step["source"])]
		_step = {}
		_start_next_step()
		# The next action starts on its own clock, avoiding an accidental skipped pose.
		break


func _apply_matched_geometry(actor: TextureRect) -> void:
	var source := String(_step["source"])
	var static_metric: Dictionary = _static_metrics[source]
	var action_metric: Dictionary = _step["metric"]
	var rest: Dictionary = _step["rest"]
	var static_texture: Texture2D = _resting_textures[source]
	if static_texture == null:
		_error("Missing static actor texture needed for matched body scale: " + source)
		return
	var static_natural := static_texture.get_size()
	var static_box: Vector2 = rest["size"]
	var static_scale := minf(static_box.x / static_natural.x, static_box.y / static_natural.y)
	var static_canvas := static_natural * static_scale
	var static_canvas_start: Vector2 = rest["position"] + (static_box - static_canvas) * 0.5
	var static_ground: Dictionary = static_metric["groundAnchor"]
	var static_feet := static_canvas_start + Vector2(
		static_canvas.x * float(static_ground.get("x", 0.5)),
		static_canvas.y * float(static_ground["y"]))
	var static_body_height := static_canvas.y * float(static_metric["bodyBounds"]["height"])
	var action_canvas_height := static_body_height / float(action_metric["referenceHeight"])
	var action_natural: Vector2 = _step["textures"][_frame_index].get_size()
	var action_canvas := Vector2(action_canvas_height * action_natural.x / action_natural.y, action_canvas_height)
	var ground_y: Array = action_metric["groundAnchor"]["frameY"]
	var ground_x := 0.5
	var ground_points: Array = action_metric["groundAnchor"].get("framePoints", [])
	if ground_points.size() == _step["textures"].size():
		ground_x = float(ground_points[_frame_index]["x"])
	actor.size = action_canvas
	actor.position = static_feet - Vector2(action_canvas.x * ground_x,
		action_canvas.y * float(ground_y[_frame_index]))


func _start_fx(cue: Dictionary, target: String) -> void:
	var target_actor: TextureRect = player_actor if target == "player" else enemy_actor
	var fx := TextureRect.new()
	fx.name = "OriginalCombatVfx_" + String(cue["id"])
	fx.texture = cue["textures"][0]
	fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.z_index = 20
	var extent := minf(220.0, maxf(120.0, target_actor.size.x * 0.72))
	fx.size = Vector2(extent, extent)
	var contact_x := 0.2 if target == "enemy" else 0.8
	fx.position = target_actor.position + Vector2(target_actor.size.x * contact_x - extent * 0.5,
		target_actor.size.y * 0.47 - extent * 0.5)
	target_actor.get_parent().add_child(fx)
	_active_fx.append({"node": fx, "textures": cue["textures"],
		"frame_ms": maxf(16.0, float(cue["frame_ms"])), "elapsed": 0.0})
	set_process(true)


func _tick_fx(delta_ms: float) -> void:
	for index in range(_active_fx.size() - 1, -1, -1):
		var fx: Dictionary = _active_fx[index]
		fx["elapsed"] = float(fx["elapsed"]) + delta_ms
		var frame_index := int(floor(float(fx["elapsed"]) / float(fx["frame_ms"])))
		if frame_index >= fx["textures"].size():
			fx["node"].queue_free()
			_active_fx.remove_at(index)
		else:
			fx["node"].texture = fx["textures"][frame_index]
	if not busy and _active_fx.is_empty():
		set_process(false)


func _error(reason: String) -> bool:
	push_error("CombatActionPresenter: " + reason)
	presentation_error.emit(reason)
	return false
