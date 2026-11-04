extends SceneTree

const HandUI = preload("res://scripts/card_hand_ui.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry := Registry.new()
	var hand := HandUI.new()
	hand.size = Vector2(1130, 240)
	root.add_child(hand)
	var ids := ["sword_probe", "sword_followthrough", "sword_guard", "sword_sheath_guard", "sword_edge"]
	var restored_art := {
		"sword_probe": "assets/combat/cards/pc98_starter_v3/sword_probe_pc98.png",
		"sword_followthrough": "assets/combat/cards/card_sword_followthrough_agc_v3.png",
		"sword_guard": "assets/combat/cards/pc98_starter_v2/sword_guard_pc98.png",
		"sword_sheath_guard": "assets/combat/cards/card_sword_sheath_guard_pc98.png",
		"sword_edge": "assets/combat/cards/card_sword_edge_pc98.png",
	}
	hand.render_hand(registry, ids, 3, "PLAYER_TURN", false)
	await process_frame
	await process_frame
	assert(hand.get_child_count() == ids.size(), "Source hand was not rendered")
	var first_card := hand.get_child(0) as Button
	var last_card := hand.get_child(ids.size() - 1) as Button
	assert(first_card.size.x / first_card.size.y < 0.75, "Hand cards regressed to the wide, flat layout")
	assert(absf((first_card.position.x + last_card.position.x + last_card.size.x) * 0.5 - hand.size.x * 0.5) < 2.0, "Portrait hand is no longer centered")
	assert((hand.get_child(1) as Button).position.x - first_card.position.x < first_card.size.x, "Compact hand no longer overlaps")
	assert(is_equal_approx(first_card.position.y, (hand.get_child(2) as Button).position.y), "Compact text is no longer aligned to clean pixels")
	assert(not (first_card.get_node("SourceEffects") as Label).text.contains("1.0"), "Whole source effect value has an unwanted decimal")
	assert((first_card.get_node("SourceEffects") as Label).text == "伤害1 · 破绽1", "Opening status lost its source meaning on the compact card")
	assert(first_card.get_node_or_null("SourceDescription") == null, "Dense source rules returned to the compact face")
	assert((first_card.get_node("SourceEffects") as Label).get_theme_font_size("font_size") >= 12, "Effect summary is too small to read")
	for i in range(ids.size()):
		var card := hand.get_child(i) as Button
		var source: Dictionary = registry.get_battle_card(ids[i])
		assert(String(source["cardArt"]["image"]) == restored_art[ids[i]], "Original card illustration mapping was replaced: " + ids[i])
		assert(String(card.get_meta("source_card_id")) == ids[i], "Card order drift")
		assert(String(card.get_meta("source_art")) == String(source["cardArt"]["image"]), "Card art mapping drift")
		assert((card.get_node("SourceCardArt") as TextureRect).texture != null, "Source art failed to load")
		var card_surface := card.get_node_or_null("CardSurface") as ColorRect
		assert(card_surface != null and card_surface.material is ShaderMaterial,
			"Card face lacks the dedicated textured material layer")
		if i > 0:
			assert(card_surface.material != (first_card.get_node("CardSurface") as ColorRect).material,
				"Card material uniforms are shared across unrelated cards")
		assert(is_zero_approx(hand._rest_rotation(i)), "Idle card rotation makes small glyphs look muddy")
		var name_label := card.get_node("CardName") as Label
		assert(name_label.get_theme_constant("shadow_offset_y") == 0, "Small title glyphs retain a dirty shadow")
		assert(name_label.get_theme_font_size("font_size") >= 14, "Card title became too small to read")
		assert(not card.disabled, "Affordable card unavailable")
	hand._set_hover(first_card, true)
	hand._process(0.2)
	assert(float(((first_card.get_node("CardSurface") as ColorRect).material as ShaderMaterial).get_shader_parameter("hover_strength")) > 0.5,
		"Hover does not raise the card's material glint")
	var detail := first_card.get_node("HoverDetail") as Panel
	assert(detail.visible and (detail.get_node("FullEffect") as RichTextLabel).text == String(registry.get_battle_card(ids[0])["description"]), "Full source effect must be readable on card hover")
	var hover_text := detail.get_node("FullEffect") as RichTextLabel
	assert(hover_text.size.x <= detail.size.x - 20.0, "Full source effect overflows hover panel")
	assert(hover_text.get_content_height() <= hover_text.size.y, "Full source effect is cut off at the bottom of the hover panel")
	hand._set_hover(first_card, false)
	var selected := [-1]
	hand.card_selected.connect(func(index: int) -> void: selected[0] = index)
	(hand.get_child(2) as Button).pressed.emit()
	assert(selected[0] == 2, "Selected hand index drift")
	var key := InputEventKey.new()
	key.keycode = KEY_5
	key.pressed = true
	hand._unhandled_key_input(key)
	assert(selected[0] == 4, "Source 1-5 shortcut drift")
	hand.render_hand(registry, ids, 0, "PLAYER_TURN", false)
	assert((hand.get_child(0) as Button).disabled, "Unpaid card remained playable")
	assert(is_zero_approx(float((((hand.get_child(0) as Button).get_node("CardSurface") as ColorRect).material as ShaderMaterial).get_shader_parameter("available"))),
		"Unpaid card keeps the active material finish")
	hand.render_hand(registry, ids, 3, "REACTION_OPEN", false)
	assert((hand.get_child(0) as Button).disabled, "Reaction window failed to lock hand")
	hand.show_committed(registry, "sword_probe")
	var notation := hand.get_node("CommittedLayer/CommittedNotation") as Control
	assert(String(notation.get_meta("source_card_id")) == "sword_probe", "Committed card ID drift")
	assert(String(notation.get_meta("source_art")) == String(registry.get_battle_card("sword_probe")["cardArt"]["image"]), "Committed art provenance drift")
	assert((notation.get_node("SourceCardArt") as TextureRect).texture != null, "Committed source art missing")
	assert((notation.get_node("SourceCardName") as Label).text == String(registry.get_battle_card("sword_probe")["name"]), "Committed source name drift")
	hand.render_hand(registry, ids.slice(1), 2, "PLAYER_TURN", false)
	assert(hand.get_node_or_null("CommittedLayer/CommittedNotation") == notation, "Hand redraw erased the committed cue")
	await create_timer(0.20).timeout
	hand.show_committed(registry, "sword_followthrough")
	var replacement := hand.get_node("CommittedLayer/CommittedNotation") as Control
	assert(String(replacement.get_meta("source_card_id")) == "sword_followthrough", "New commit did not replace prior cue")
	await create_timer(0.32).timeout
	assert(hand.get_node_or_null("CommittedLayer/CommittedNotation") == replacement, "Prior timer erased newer commit")
	await create_timer(0.72).timeout
	assert(hand.get_node_or_null("CommittedLayer/CommittedNotation") == null, "Committed notation did not expire")
	print("CARD_HAND_UI_PASS cards=5 source_art=5 click=ok keys=ok qi_lock=ok phase_lock=ok commit_source=ok commit_lifecycle=ok")
	quit(0)
