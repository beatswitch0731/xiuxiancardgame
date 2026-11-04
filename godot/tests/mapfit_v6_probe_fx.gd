extends Node2D

# Temporary visual-only study, used solely by mapfit_v5_motion_study.gd.
var last_profile := ""
var last_style := ""
var _age := 1.0
var _duration := 0.20
var _direction := 1.0

func configure(document: Dictionary) -> bool:
	return document.get("contractId") == "qingyun_pixel_first_fight_fx_v1"

func set_profile(profile_id: String) -> bool:
	last_profile = profile_id
	last_style = "probe_opening"
	return profile_id == "sword_probe"

func burst(at: Vector2, left_to_right: bool) -> void:
	position = at
	_direction = 1.0 if left_to_right else -1.0
	_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _age < _duration:
		_age += delta
		queue_redraw()

func _draw() -> void:
	if _age >= _duration:
		return
	var fade := clampf(1.0 - _age / _duration, 0.0, 1.0)
	var blue := Color(0.38, 0.74, 0.9, fade * 0.75)
	var white := Color(0.90, 0.98, 1.0, fade)
	# A straight thrust travels toward the target; no sideways slash arc.
	draw_line(Vector2(-13 * _direction, 0), Vector2(3 * _direction, 0), blue, 3.0, false)
	draw_line(Vector2(-10 * _direction, 0), Vector2(3 * _direction, 0), white, 1.0, false)
	draw_line(Vector2(0, -3), Vector2(0, 3), white, 1.0, false)
