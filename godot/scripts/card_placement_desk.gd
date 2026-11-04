extends Control

# A low physical rest for the source hand. Its artwork is kept separate from
# card rules and can shrink or disappear as the source hand changes.
const DESK_ART: Texture2D = preload("res://assets/ui/card_placement_desk_v4.png")
const ART_LEFT := Rect2(16, 178, 274, 385)
const ART_MIDDLE := Rect2(290, 178, 1592, 385)
const ART_RIGHT := Rect2(1882, 178, 274, 385)

var card_count := 0
var hover_index := -1
var hover_strength := 0.0
var confirm_strength := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	var target := 1.0 if hover_index >= 0 and card_count > 0 else 0.0
	var new_hover := move_toward(hover_strength, target, delta * 6.0)
	var new_confirm := move_toward(confirm_strength, 0.0, delta * 3.8)
	if not is_equal_approx(new_hover, hover_strength) or not is_equal_approx(new_confirm, confirm_strength):
		hover_strength = new_hover
		confirm_strength = new_confirm
		queue_redraw()


func set_card_count(value: int) -> void:
	card_count = maxi(0, value)
	# HandUI recreates card Buttons on each source combat state change.
	hover_index = -1
	queue_redraw()


func set_hovered_card(index: int, active: bool) -> void:
	if active:
		hover_index = index
	elif hover_index == index:
		hover_index = -1
	queue_redraw()


func confirm_card(_index: int) -> void:
	confirm_strength = 1.0
	queue_redraw()


func _draw() -> void:
	if card_count == 0:
		return
	# Keep the inkstone and booklet at a stable size as the source hand shrinks.
	var end_width := minf(84.0, size.x * 0.25)
	draw_texture_rect_region(DESK_ART, Rect2(0, 0, end_width, size.y), ART_LEFT)
	draw_texture_rect_region(DESK_ART, Rect2(end_width, 0, size.x - 2.0 * end_width, size.y), ART_MIDDLE)
	draw_texture_rect_region(DESK_ART, Rect2(size.x - end_width, 0, end_width, size.y), ART_RIGHT)
	if hover_strength > 0.001 and hover_index >= 0:
		var spread := minf(115.0, (size.x - 150.0) / maxf(1.0, float(card_count)))
		var center := size.x * 0.5 + (float(hover_index) - float(card_count - 1) * 0.5) * spread
		# Local light appears only when a card lifts from its cloth recess.
		draw_line(Vector2(center - 27.0, size.y * 0.36), Vector2(center + 27.0, size.y * 0.36), Color(1.0, 0.78, 0.48, 0.38 * hover_strength), 2.0)
	if confirm_strength > 0.001:
		var center := size.x * 0.5
		var gleam := Color(1.0, 0.74, 0.39, 0.34 * confirm_strength)
		draw_line(Vector2(center - 17.0, size.y * 0.74), Vector2(center + 17.0, size.y * 0.74), gleam, 2.0)
