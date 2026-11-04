extends RefCounted

# Desktop presentation tokens for battle and story choices. Scene lighting
# supplies the atmosphere; UI surfaces only protect text and active controls.
const PAPER := Color("eee5d1")
const MUTED_PAPER := Color("c9c3b4")
const JADE := Color("9fbcb1")
const BRASS := Color("bda77b")
const WARM_RED := Color("b66c61")
const ATTACK_READOUT := Color("f0c4a9")
const GUARD_READOUT := Color("c9e1d2")
const DEEP_INK := Color("141a19")


static func plaque(strength: float = 0.82) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.068, 0.083, 0.080, strength)
	box.border_color = Color(0.67, 0.58, 0.40, 0.46)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.shadow_color = Color(0.015, 0.018, 0.016, 0.28)
	box.shadow_size = 5
	box.shadow_offset = Vector2(0, 2)
	return box


static func action_button(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var fill := Color(0.105, 0.137, 0.130, 0.91)
	var rim := Color(accent.r, accent.g, accent.b, 0.78)
	match state:
		"hover", "focus":
			fill = Color(0.16, 0.20, 0.18, 0.96)
			rim = accent.lightened(0.23)
		"pressed":
			fill = Color(0.21, 0.24, 0.18, 0.98)
		"disabled":
			fill = Color(0.09, 0.11, 0.10, 0.70)
			rim = Color(0.46, 0.45, 0.39, 0.42)
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(3)
	if state == "focus":
		box.set_border_width_all(2)
	return box


static func apply_action_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", action_button(accent))
	button.add_theme_stylebox_override("hover", action_button(accent, "hover"))
	button.add_theme_stylebox_override("pressed", action_button(accent, "pressed"))
	button.add_theme_stylebox_override("focus", action_button(accent, "focus"))
	button.add_theme_stylebox_override("disabled", action_button(accent, "disabled"))
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color("aaa99e"))
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_text_input(input: LineEdit) -> void:
	var normal := plaque(0.94)
	normal.set_content_margin_all(9)
	normal.border_color = Color(BRASS, 0.72)
	var focused: StyleBoxFlat = normal.duplicate()
	focused.border_color = JADE.lightened(0.22)
	focused.set_border_width_all(2)
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focused)
	input.add_theme_color_override("font_color", PAPER)
	input.add_theme_color_override("font_placeholder_color", MUTED_PAPER)
	input.add_theme_color_override("caret_color", JADE)
	input.add_theme_color_override("selection_color", Color(JADE, 0.38))


static func paper_button(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.94, 0.91, 0.84, 0.88)
	box.border_color = Color(accent, 0.65)
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(3)
	if state in ["hover", "focus"]:
		box.bg_color = Color(0.98, 0.96, 0.90, 0.97)
		box.border_color = accent
		if state == "focus":
			box.set_border_width_all(2)
	elif state == "pressed":
		box.bg_color = Color(0.85, 0.82, 0.73, 0.98)
	elif state == "disabled":
		box.bg_color = Color(0.78, 0.77, 0.72, 0.52)
	return box


static func apply_paper_button(button: Button, accent: Color = BRASS) -> void:
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, paper_button(accent, state))
	button.add_theme_color_override("font_color", Color("292e2a"))
	button.add_theme_color_override("font_hover_color", Color("171d1a"))
	button.add_theme_color_override("font_pressed_color", Color("292e2a"))
	button.add_theme_color_override("font_disabled_color", Color("777972"))
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func path_card(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 0.99, 0.96, 0.32)
	box.border_color = Color(accent, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	match state:
		"hover", "focus":
			box.bg_color = Color(1, 0.99, 0.96, 0.72)
			box.border_color = accent
			box.set_border_width_all(2)
		"pressed":
			box.bg_color = Color(0.88, 0.87, 0.80, 0.80)
			box.border_color = accent
		"disabled":
			box.bg_color = Color(0.87, 0.87, 0.83, 0.24)
			box.border_color = Color(accent, 0.16)
	return box


static func apply_path_card(button: Button, accent: Color) -> void:
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, path_card(accent, state))
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
