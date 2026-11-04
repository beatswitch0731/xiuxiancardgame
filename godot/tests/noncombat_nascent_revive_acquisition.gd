extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("source nascent run unavailable")
	game.state.realm = "nascent"
	game.state.resources.spiritStone = 100
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "n_trade_city"
	var source: Dictionary = game.get_current_card()
	if source.get("id") != "n_trade_city" \
			or source.get("choices", {}).get("left", {}).get(
				"effects", {}).get("treasure") != "涅槃羽" \
			or not game.choose("left", game.issue_choice_token()):
		return _fail("source nascent shop did not award nirvana artifact")
	var instance_id := "tr:涅槃羽:1"
	var instance: Dictionary = game.state.get("treasureInstances", {}).get(
		instance_id, {})
	var transaction_id := String(instance.get("transactionId", ""))
	if instance.get("definitionId") != "涅槃羽" \
			or instance.get("provenance", {}).get("source") != "narrative_effect" \
			or transaction_id.is_empty() \
			or not game.state.get("treasureCommandReceipts", {}).has(transaction_id) \
			or int(game.state.resources.spiritStone) != 70:
		return _fail("source nirvana ownership or payment diverged")
	game.state.phase = "NORMAL_PENDING"
	game.state.currentCardId = "n_awakening"
	game.state.attributes.daoHeart = 2
	var story: Control = load("res://scenes/noncombat_opening.tscn").instantiate()
	story.save_path = ""
	root.add_child(story)
	await process_frame
	story.opening = game
	story._render()
	if not story.equipment_button.visible:
		return _fail("owned nirvana artifact lacks desktop inventory entrance")
	story._open_treasure_inventory()
	var equip_button: Button = null
	for row in story.equipment_list.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button and child.text == "装备":
					equip_button = child
	if equip_button == null:
		return _fail("desktop inventory omitted source nirvana equip action")
	equip_button.pressed.emit()
	if game.state.equipment.artifact != instance_id:
		return _fail("desktop inventory did not equip owned nirvana artifact")
	story.queue_free()
	var decision_before := int(game.state.runClock.decisionIndex)
	if not game.choose("right", game.issue_choice_token()):
		return _fail("source nascent fatal choice rejected equipped nirvana")
	if game.state.get("dead") == true or game.state.get("phase") != "FLOW_PENDING" \
			or int(game.state.runClock.decisionIndex) != decision_before + 1 \
			or game.state.equipment.artifact != null \
			or game.state.treasureInstances.has(instance_id) \
			or game.state.get("treasureCommandReceipts", {}).get(
				transaction_id, {}).get("instanceId") != instance_id \
			or int(game.state.attributes.health) != int(game.state.maxHealth) \
			or int(game.state.attributes.daoHeart) != 0:
		return _fail("source acquired nirvana was not consumed on fatal choice")
	print("NONCOMBAT_NASCENT_REVIVE_ACQUISITION_PASS source=true equip=true revive=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
