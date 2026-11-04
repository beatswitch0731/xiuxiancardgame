extends SceneTree

const BattleScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1024, 768)
	var battle: Control = BattleScene.instantiate()
	root.add_child(battle)
	for frame in 4:
		await process_frame
	var viewport_size := root.get_viewport().get_visible_rect().size
	if viewport_size != Vector2(1024, 768):
		push_error("Run this desktop regression at 1024x768")
		quit(1)
		return
	var hint: Panel = battle.state_info_back
	var cards: HBoxContainer = battle.hand_row
	if cards.get_child_count() < 1:
		push_error("Source hand is unavailable")
		quit(1)
		return
	var first_card := cards.get_child(0) as Button
	if hint.get_global_rect().intersects(first_card.get_global_rect()):
		push_error("Bottom hint overlaps the first selectable card")
		quit(1)
		return
	if hint.size.y > 40.0:
		push_error("Ordinary turn hint reserves excessive vertical space")
		quit(1)
		return
	cards._set_hover(first_card, true)
	await process_frame
	var detail: Panel = first_card.get_node("HoverDetail")
	var detail_rect := detail.get_global_rect()
	var left_hud_rect: Rect2 = battle.player_info_back.get_global_rect()
	var right_hud_rect: Rect2 = battle.enemy_info_back.get_global_rect()
	if not detail.visible or detail_rect.position.y < 70.0 \
			or detail_rect.end.y > 250.0 \
			or detail_rect.position.x <= left_hud_rect.end.x \
			or detail_rect.end.x >= right_hud_rect.position.x:
		push_error("Card inspect text obscures actors or status plaques")
		quit(1)
		return
	await create_timer(0.3).timeout
	if first_card.get_global_rect().position.y < 525.0:
		push_error("Hovered first card obscures the protagonist's planted feet: " + str(first_card.get_global_rect()))
		quit(1)
		return
	for card_node in cards.get_children():
		var card_button := card_node as Button
		if card_button == null:
			continue
		if card_button.get_global_rect().end.y > viewport_size.y - 8.0:
			push_error("Source card is clipped at the bottom: " + String(card_button.get_meta("source_card_id")))
			quit(1)
			return
		var rule_text := card_button.get_node("HoverDetail/FullEffect") as RichTextLabel
		if rule_text.get_content_height() > rule_text.size.y:
			push_error("Source card rules are cut off: " + String(card_button.get_meta("source_card_id")))
			quit(1)
			return
	var inspect_rules := first_card.get_node("HoverDetail/FullEffect") as RichTextLabel
	var source_cards: Array = battle.data.read_json("data/cards/battle_cards.json").get("battle_cards", [])
	for source_card in source_cards:
		if not source_card is Dictionary:
			continue
		inspect_rules.text = String(source_card.get("description", ""))
		await process_frame
		if inspect_rules.get_content_height() > inspect_rules.size.y:
			push_error("Reusable inspect panel cuts off source rules: " + String(source_card.get("id", "")))
			quit(1)
			return
	print("BATTLE_HUD_NARROW_LAYOUT_PASS hint=", hint.get_global_rect(),
		" first_card=", first_card.get_global_rect(), " inspect=", detail_rect,
		" source_cards=", source_cards.size())
	quit(0)
