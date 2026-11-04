extends Node2D

# Visual-only contact feedback. CombatDomain remains the sole damage/block owner.
var last_profile := ""
var last_style := ""
var last_start := Vector2.ZERO
var last_end := Vector2.ZERO

var _profiles: Dictionary = {}
var _selected_id := ""
var _selected: Dictionary = {}
var _age := 1.0
var _duration := 0.2
var _direction := 1.0


func configure(document: Dictionary) -> bool:
	if document.get("contractId") != "qingyun_pixel_first_fight_fx_v1" \
			or not document.get("profiles") is Dictionary:
		return false
	_profiles = document["profiles"]
	return true


func set_profile(profile_id: String) -> bool:
	_selected_id = profile_id
	_selected = _profiles.get(profile_id, {})
	return not _selected.is_empty()


func burst(at: Vector2, left_to_right: bool) -> void:
	if _selected.is_empty():
		return
	last_start = at
	last_end = at
	position = at + (Vector2(-11, 6) if _selected_id == "sword_edge" else Vector2(0, -25))
	_direction = 1.0 if left_to_right else -1.0
	_duration = float(_selected.get("durationMs", 200)) / 1000.0
	_age = 0.0
	last_profile = _selected_id
	last_style = String(_selected.get("style", ""))
	queue_redraw()


func burst_segment(start: Vector2, end: Vector2, left_to_right: bool) -> void:
	if _selected.is_empty():
		return
	last_start = start
	last_end = end
	position = end
	_direction = 1.0 if left_to_right else -1.0
	_duration = float(_selected.get("durationMs", 200)) / 1000.0
	_age = 0.0
	last_profile = _selected_id
	last_style = String(_selected.get("style", ""))
	queue_redraw()


func _process(delta: float) -> void:
	if _age >= _duration:
		return
	_age += delta
	queue_redraw()


func _draw() -> void:
	if _age >= _duration or _selected.is_empty():
		return
	var progress := _age / _duration
	var fade := 1.0 - progress * progress
	var radius := float(_selected.get("radiusPx", 28))
	var primary := Color(String(_selected.get("primary", "#a8e9ff")))
	var accent := Color(String(_selected.get("accent", "#5b8cb7")))
	primary.a = fade
	accent.a = fade * 0.75
	match last_style:
		"probe_opening":
			var from := last_start - last_end
			draw_line(from, Vector2.ZERO, accent, 3.0, false)
			draw_line(from + Vector2(3 * _direction, 0), Vector2.ZERO,
				primary, 1.0, false)
			draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), primary)
			draw_rect(Rect2(Vector2(3 * _direction, -4), Vector2(2, 2)), accent)
		"edge_intent":
			var point := Vector2(16 * _direction, 4)
			draw_line(Vector2(-18 * _direction, -4), point, primary, 3.0, false)
			draw_line(Vector2(-9 * _direction, -8), point, accent, 2.0, false)
			draw_rect(Rect2(point + Vector2(3 * _direction, -6), Vector2(4, 4)), primary)
			draw_rect(Rect2(point + Vector2(8 * _direction, -2), Vector2(3, 3)), accent)
		"followthrough":
			_arc(-76, 116, radius - 7, radius, accent, 12)
			_arc(-65, 125, radius - 2, radius + 2, primary, 12)
			_arc(-92, 80, radius - 15, radius - 12, accent, 12)
		"guard_aegis":
			_arc(-155, 145, radius - 1, radius + 1, primary, 12)
			_arc(-145, 135, radius - 9, radius - 7, accent, 12)
			for dot in [-1, 0, 1]:
				draw_rect(Rect2(Vector2(dot * 9 - 1, -radius - 5), Vector2(3, 3)), primary)
		"sheath_guard":
			_arc(-90, 52, radius - 3, radius, primary, 10)
			draw_line(Vector2(-16, 9), Vector2(13, -11), accent, 3.0, false)
		"enemy_slash":
			_arc(-58, 92, radius - 4, radius, primary, 8)
			draw_line(Vector2(-16 * _direction, 8), Vector2(15 * _direction, -8), accent, 2.0, false)
		"enemy_guard":
			_arc(-145, 145, radius - 2, radius, primary, 12)
			draw_rect(Rect2(Vector2(-3, -radius - 5), Vector2(6, 5)), accent)


func _arc(start_degrees: int, end_degrees: int, inner: float,
		outer: float, tint: Color, step_degrees: int) -> void:
	for degrees in range(start_degrees, end_degrees, step_degrees):
		var first := deg_to_rad(float(degrees))
		var last := deg_to_rad(float(mini(degrees + step_degrees, end_degrees)))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cos(first) * _direction, sin(first)) * inner,
			Vector2(cos(first) * _direction, sin(first)) * outer,
			Vector2(cos(last) * _direction, sin(last)) * outer,
			Vector2(cos(last) * _direction, sin(last)) * inner,
		]), tint)
