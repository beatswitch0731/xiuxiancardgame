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
	var blue := Color(0.30, 0.69, 0.90, fade * 0.8)
	var white := Color(0.87, 0.97, 1.0, fade)
	# Compact opening arc and spark centred on the blade/target contact.
	for degrees in range(18, 153, 9):
		var a := deg_to_rad(float(degrees))
		var b := deg_to_rad(float(degrees + 9))
		var va := Vector2(cos(a) * _direction, sin(a))
		var vb := Vector2(cos(b) * _direction, sin(b))
		draw_colored_polygon(PackedVector2Array([va * 27, va * 33, vb * 33, vb * 27]), blue)
		draw_colored_polygon(PackedVector2Array([va * 27, va * 30, vb * 30, vb * 27]), white)
	draw_line(Vector2(-7 * _direction, 1), Vector2(7 * _direction, -1), white, 2.0, false)
	draw_line(Vector2(0, -5), Vector2(0, 5), white, 2.0, false)
