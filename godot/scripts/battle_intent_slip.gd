extends Control

# A reusable, presentation-only view of the combat domain's current intent.
# Its subtle motion moves paper and writing together; it never delays combat.
const INK_FONT: Font = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const PAPER: Texture2D = preload("res://assets/ui/hud_materials/intent_slip_v1.png")
const INK := Color("302d29")
const FADED_INK := Color("4f493e")
const ATTACK_INK := Color("803d31")
const GUARD_INK := Color("315c4c")

const PAPER_WIDTH := 306.0
const MIN_HEIGHT := 84.0
const MAX_HEIGHT := 120.0

var paper: TextureRect
var phase_label: Label
var value_label: Label
var description_label: Label
var accent: ColorRect
var intent_revision := 0

var _drop_layer: Control
var _breeze_layer: Control
var _drop_tween: Tween
var _wind_time := 0.0
var _signature := ""


func _ready() -> void:
	name = "BattleIntentSlip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_layer = Control.new()
	_drop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_layer)
	_breeze_layer = Control.new()
	_breeze_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_layer.add_child(_breeze_layer)
	paper = TextureRect.new()
	paper.texture = PAPER
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breeze_layer.add_child(paper)
	accent = ColorRect.new()
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breeze_layer.add_child(accent)
	phase_label = _paper_label(15, FADED_INK)
	value_label = _paper_label(17, ATTACK_INK)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	description_label = _paper_label(17, INK)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_constant_override("line_spacing", 1)
	resized.connect(_layout)
	if size == Vector2.ZERO:
		size = Vector2(PAPER_WIDTH, MIN_HEIGHT)
	_layout()


func _process(delta: float) -> void:
	_wind_time += delta
	# The sheet is held at both ends. Keep the drift slow and under two pixels;
	# smooth waves read as a breeze, frame-random offsets read as vibration.
	_breeze_layer.position = Vector2(
		0.35 * sin(_wind_time * 1.13) + 0.18 * sin(_wind_time * 2.07),
		0.60 * sin(_wind_time * 1.29 + 0.6))
	_breeze_layer.rotation = deg_to_rad(
		0.34 * sin(_wind_time * 1.03) + 0.10 * sin(_wind_time * 1.91 + 0.5))


func set_intent(turn: int, intent: Dictionary) -> void:
	var description := String(intent.get("desc", ""))
	var intent_type := String(intent.get("type", ""))
	var value := int(intent.get("value", 0))
	var signature := "%d|%s|%s|%s|%d" % [turn,
		String(intent.get("planState", "")), description, intent_type, value]
	if signature == _signature:
		return
	_signature = signature
	intent_revision += 1
	phase_label.text = "第 %d 回合 · %s" % [turn, String(intent.get("planStateLabel", ""))]
	description_label.text = description
	value_label.text = "%d 伤害" % value if intent_type == "attack" \
		else ("%d 护盾" % value if intent_type == "defend" else "")
	value_label.add_theme_color_override("font_color", ATTACK_INK if intent_type == "attack" else GUARD_INK)
	accent.color = ATTACK_INK if intent_type == "attack" else GUARD_INK
	_fit_text(description)
	_drop_in()


func _paper_label(font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", INK_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breeze_layer.add_child(label)
	return label


func _fit_text(description: String) -> void:
	var font_size := 17
	var text_height := 0.0
	for candidate in [17, 16, 15, 14]:
		font_size = candidate
		text_height = INK_FONT.get_multiline_string_size(
			description, HORIZONTAL_ALIGNMENT_LEFT, size.x - 64.0, font_size).y
		if text_height <= MAX_HEIGHT - 53.0:
			break
	description_label.add_theme_font_size_override("font_size", font_size)
	size.y = clampf(52.0 + text_height, MIN_HEIGHT, MAX_HEIGHT)
	_layout()
	if text_height > description_label.size.y:
		push_warning("Enemy intent needs more than one paper slip: " + description)


func _layout() -> void:
	if _drop_layer == null:
		return
	_drop_layer.size = size
	_breeze_layer.size = size
	_breeze_layer.pivot_offset = Vector2(size.x * 0.5, 7.0)
	paper.size = size
	accent.position = Vector2(26, 16)
	accent.size = Vector2(2, maxf(37.0, size.y - 35.0))
	phase_label.position = Vector2(32, 15)
	phase_label.size = Vector2(145, 23)
	value_label.position = Vector2(size.x - 134, 14)
	value_label.size = Vector2(94, 26)
	description_label.position = Vector2(32, 42)
	description_label.size = Vector2(size.x - 64, size.y - 48)


func _drop_in() -> void:
	if _drop_tween != null and _drop_tween.is_running():
		_drop_tween.kill()
	_drop_layer.position.y = clampf(_drop_layer.position.y - 9.0, -13.0, -7.0)
	_drop_layer.rotation = deg_to_rad(-0.65)
	_drop_layer.modulate.a = 0.88
	_drop_tween = create_tween().set_parallel(true)
	_drop_tween.tween_property(_drop_layer, "position:y", 0.0, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_property(_drop_layer, "rotation", 0.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_tween.tween_property(_drop_layer, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
