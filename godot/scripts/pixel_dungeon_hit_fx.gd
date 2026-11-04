extends Node2D

var _age := 1.0
var _left_to_right := true


func burst(at: Vector2, left_to_right: bool) -> void:
	position = at
	_left_to_right = left_to_right
	_age = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _age >= 0.28:
		return
	_age += delta
	queue_redraw()


func _draw() -> void:
	if _age >= 0.28:
		return
	var t := _age / 0.28
	var alpha := 1.0 - t
	var direction := 1.0 if _left_to_right else -1.0
	var reach := 12.0 + 15.0 * t
	draw_line(Vector2(-direction * reach, 10), Vector2(direction * reach, -13), Color(0.72, 0.98, 1.0, alpha), 3)
	draw_line(Vector2(-direction * (reach - 3), 12), Vector2(direction * (reach - 3), -11), Color(0.25, 0.72, 0.93, alpha * 0.7), 1)
	for i in 5:
		var angle := float(i) * TAU / 5.0 + 0.2
		var from := Vector2(cos(angle), sin(angle)) * (4.0 + t * 11.0)
		var to := from + Vector2(cos(angle), sin(angle)) * 5.0
		draw_line(from, to, Color(1.0, 0.79, 0.42, alpha), 2)
