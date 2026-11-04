extends Node2D

# Original, deterministic pixel masonry. Logical canvas: 640 x 400.
# The architecture, dressing and light locations are separate from combat state.

const VOID := Color("05070c")
const MORTAR := Color("202733")
const EDGE := Color("111821")

var _flame_time := 0.0


func _process(delta: float) -> void:
	_flame_time += delta
	queue_redraw()


func _draw() -> void:
	# Cover letterboxing when the combat window is taller than 16:10.
	draw_rect(Rect2(-1000, -1000, 2640, 2400), VOID)
	_draw_back_wall()
	_draw_floor()
	_draw_side_walls()
	_draw_architecture()
	_draw_dressing()
	for torch in [Vector2(145, 97), Vector2(495, 97), Vector2(145, 283), Vector2(495, 283)]:
		_draw_torch(torch)
	_draw_front_rim()


func _draw_back_wall() -> void:
	draw_rect(Rect2(63, 27, 514, 115), Color("0b111a"))
	draw_rect(Rect2(68, 33, 504, 98), Color("4a4b4b"))
	for row in 8:
		var y := 35 + row * 12
		var offset := 12 if row % 2 else 0
		for col in 25:
			var x := 69 + col * 24 - offset
			if x < 69 or x + 22 > 571:
				continue
			var n := _noise(col, row, 91)
			var shade := Color("62615b").darkened(float(n % 6) * 0.026)
			if row > 4:
				shade = shade.darkened(float(row - 4) * 0.07)
			draw_rect(Rect2(x, y, 22, 10), MORTAR)
			draw_rect(Rect2(x + 1, y + 1, 20, 8), shade)
			draw_line(Vector2(x + 2, y + 1), Vector2(x + 19, y + 1), shade.lightened(0.13), 1)
			if n % 13 == 0:
				draw_line(Vector2(x + 15, y + 5), Vector2(x + 18, y + 8), Color("363b3e"), 1)
	draw_rect(Rect2(69, 35, 502, 4), Color("969081"))
	draw_rect(Rect2(69, 126, 502, 7), Color("222a31"))
	for col in 16:
		var x := 70 + col * 31
		draw_rect(Rect2(x, 27, 29, 8), Color("343640"))
		draw_rect(Rect2(x + 1, 28, 27, 5), Color("74736d").darkened(float(col % 4) * 0.045))
		draw_line(Vector2(x + 3, 28), Vector2(x + 24, 28), Color("a09b86"), 1)
	# A recessed training hall door gives the back wall a readable focal point.
	draw_rect(Rect2(296, 53, 48, 77), Color("1a2029"))
	draw_rect(Rect2(299, 57, 42, 69), Color("2f3437"))
	draw_rect(Rect2(302, 60, 36, 64), Color("19252c"))
	for x in [307, 317, 327, 337]:
		draw_rect(Rect2(x, 66, 3, 43), Color("687170"))
	draw_rect(Rect2(298, 109, 44, 5), Color("6a675d"))
	draw_rect(Rect2(293, 122, 54, 6), Color("3a444a"))
	# Tiny jade seal, authored for the sect rather than copied from the reference.
	draw_rect(Rect2(311, 40, 18, 13), Color("171e22"))
	draw_rect(Rect2(313, 42, 14, 9), Color("315d57"))
	draw_rect(Rect2(317, 44, 6, 5), Color("b0c5a0"))


func _draw_floor() -> void:
	draw_rect(Rect2(46, 129, 548, 233), Color("28323a"))
	for row in 32:
		var y := 132 + row * 7
		var offset := 6 if row % 2 else 0
		for col in 44:
			var x := 48 + col * 13 - offset
			if x < 48 or x + 12 > 592:
				continue
			var n := _noise(col, row, 7)
			var base := Color("4c5355")
			if row < 9:
				base = Color("62625c")
			elif row > 25:
				base = Color("363f47")
			var color := base.darkened(float(n % 7) * 0.023)
			draw_rect(Rect2(x, y, 12, 6), color)
			draw_line(Vector2(x + 1, y), Vector2(x + 10, y), color.lightened(0.08), 1)
			if n % 31 == 0:
				draw_line(Vector2(x + 7, y + 3), Vector2(x + 9, y + 5), Color("30393d"), 1)
			if n % 47 == 0:
				draw_rect(Rect2(x + 3, y + 3, 2, 1), Color("77766a"))
	# Irregular repair patches and cracks break the tile repetition.
	for p in [Vector2(77, 203), Vector2(557, 187), Vector2(505, 314), Vector2(352, 326)]:
		draw_line(p, p + Vector2(7, 1), Color("222a31"), 1)
		draw_line(p + Vector2(7, 1), p + Vector2(10, 5), Color("222a31"), 1)


func _draw_side_walls() -> void:
	for side in [0, 1]:
		var x0 := 0 if side == 0 else 574
		draw_rect(Rect2(x0, 134, 66, 100), Color("151c27"))
		for row in 7:
			for col in 4:
				var x := x0 + col * 17 + (8 if row % 2 else 0)
				var y := 139 + row * 13
				if x + 16 > x0 + 66:
					continue
				draw_rect(Rect2(x, y, 16, 12), Color("323b46").darkened(float((col + row) % 4) * 0.06))
		draw_rect(Rect2(x0, 132, 66, 8), Color("687078"))
		draw_line(Vector2(x0, 133), Vector2(x0 + 66, 133), Color("9b9b8b"), 1)
		draw_rect(Rect2(x0, 225, 66, 9), Color("0e1520"))


func _draw_architecture() -> void:
	for x in [125, 515]:
		for y in [107, 294]:
			_draw_pillar(x, y)
	# Floor edge and cutaway wall depth.
	draw_rect(Rect2(45, 359, 550, 9), Color("17202b"))
	draw_rect(Rect2(46, 360, 548, 3), Color("6a6760"))
	for x in range(55, 590, 28):
		draw_rect(Rect2(x, 365, 27, 8), Color("343843"))


func _draw_pillar(x: int, foot_y: int) -> void:
	draw_rect(Rect2(x - 15, foot_y - 47, 30, 50), Color("151b21"))
	draw_rect(Rect2(x - 10, foot_y - 49, 20, 47), Color("565956"))
	draw_rect(Rect2(x - 8, foot_y - 47, 4, 43), Color("77756b"))
	draw_rect(Rect2(x + 6, foot_y - 47, 3, 43), Color("323b40"))
	draw_rect(Rect2(x - 18, foot_y - 4, 36, 6), Color("78756a"))
	draw_rect(Rect2(x - 19, foot_y + 2, 38, 6), Color("313a43"))
	draw_line(Vector2(x - 15, foot_y - 50), Vector2(x + 14, foot_y - 50), Color("b2a48a"), 1)
	# Chiselled notch and weathering.
	draw_line(Vector2(x - 3, foot_y - 35), Vector2(x - 2, foot_y - 18), Color("30393a"), 1)
	draw_rect(Rect2(x + 10, foot_y - 14, 2, 7), Color("999084"))


func _draw_dressing() -> void:
	# Training chest, barrel and loose stones are placed at the perimeter.
	draw_rect(Rect2(72, 94, 25, 30), Color("10141a"))
	draw_rect(Rect2(75, 97, 19, 25), Color("513b30"))
	draw_rect(Rect2(76, 98, 17, 3), Color("a17b53"))
	draw_rect(Rect2(80, 109, 9, 5), Color("b89a59"))
	draw_rect(Rect2(84, 109, 2, 5), Color("35302b"))
	draw_rect(Rect2(545, 89, 25, 32), Color("171b20"))
	draw_rect(Rect2(548, 91, 19, 29), Color("644333"))
	for y in [96, 111]:
		draw_rect(Rect2(546, y, 23, 3), Color("b19a6d"))
	for p in [Vector2(522, 314), Vector2(537, 310), Vector2(88, 327)]:
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(8, -4), p + Vector2(14, 2), p + Vector2(11, 8), p + Vector2(2, 8)]), Color("484a49"))
		draw_line(p + Vector2(2, 1), p + Vector2(8, -3), Color("777569"), 1)
	# Scratched sword practice marks lead the eye between fighters.
	draw_line(Vector2(294, 198), Vector2(311, 190), Color("313c43"), 1)
	draw_line(Vector2(301, 205), Vector2(317, 199), Color("313c43"), 1)
	# Small scattered bone and talisman hints.
	draw_line(Vector2(451, 157), Vector2(459, 154), Color("a9a38b"), 2)
	draw_rect(Rect2(461, 151, 2, 2), Color("ded0a4"))
	draw_rect(Rect2(392, 143, 9, 13), Color("6b5840"))
	draw_rect(Rect2(394, 145, 5, 9), Color("c4ac72"))
	draw_rect(Rect2(396, 148, 1, 5), Color("336d69"))


func _draw_torch(center: Vector2) -> void:
	# Bracket, heat source and a four-frame-like flicker, all at integer pixels.
	draw_rect(Rect2(center.x - 5, center.y + 3, 10, 3), Color("252b30"))
	draw_rect(Rect2(center.x - 3, center.y - 2, 6, 7), Color("8b683f"))
	draw_rect(Rect2(center.x - 2, center.y - 2, 4, 2), Color("c3a265"))
	var sway := int(round(sin(_flame_time * 8.0 + center.x) * 2.0))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-4, -2), center + Vector2(-4, -9),
		center + Vector2(sway - 1, -17), center + Vector2(4, -10),
		center + Vector2(3, -2)]), Color("dc5a23"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-2, -3), center + Vector2(-1, -11),
		center + Vector2(sway, -14), center + Vector2(2, -8),
		center + Vector2(2, -3)]), Color("ffc052"))
	draw_rect(Rect2(center.x - 1, center.y - 8, 2, 6), Color("fff4b0"))


func _draw_front_rim() -> void:
	draw_rect(Rect2(0, 372, 640, 28), VOID)
	draw_rect(Rect2(44, 369, 552, 5), Color("0f1721"))
	draw_rect(Rect2(0, 0, 640, 20), VOID)


func _noise(x: int, y: int, seed: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ seed) % 97
