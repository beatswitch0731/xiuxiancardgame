extends "res://tests/noncombat_golden_normal_pool.gd"

func _run() -> void:
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("spell"):
		return _fail("nascent seductress fixture could not start")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "nascent"
	state.resources.spiritStone = 200
	var policy = ChoicePolicy.new(ContentRepository.new())
	var auction: Dictionary = policy.source_card("ds_demonic_auction", state)
	var trade: Dictionary = policy.source_card("ds_pill_master_trade", state)
	if auction.is_empty() or trade.is_empty() \
			or not policy.choice_available(state, auction, "left") \
			or not policy.choice_available(state, trade, "right"):
		return _fail("nascent authored source choices unavailable")
	var purchase: Dictionary = policy.settle(state, "ds_demonic_auction", "left")
	if purchase.is_empty() or int(purchase.resources.spiritStone) != 100 \
			or not purchase.resources.companions.has("ds_demoness") \
			or int(purchase.attributes.karmaGood) != int(state.attributes.karmaGood) + 5 \
			or int(purchase.attributes.karmaBad) != int(state.attributes.karmaBad) + 5:
		return _fail("demonic auction companion or numeric effects invalid: " +
			JSON.stringify({"error": policy.last_error, "stone": purchase.get(
				"resources", {}).get("spiritStone"), "companions": purchase.get(
				"resources", {}).get("companions"), "good": purchase.get(
				"attributes", {}).get("karmaGood"), "bad": purchase.get(
				"attributes", {}).get("karmaBad")}))
	game.state = state
	purchase.runClock.decisionIndex = int(state.runClock.decisionIndex) + 1
	purchase.turn = purchase.runClock.decisionIndex
	purchase.choiceHistory.append({"cardId": "ds_demonic_auction", "cardType": "NORMAL",
		"direction": "left", "turn": int(state.turn),
		"decisionIndex": int(purchase.runClock.decisionIndex), "tags": []})
	if not game._persist_snapshot(purchase) \
			or not purchase.get("companionProgress", {}).get("states", {}).has("ds_demoness") \
			or int(purchase.companionProgress.cooldowns.get("ds_demoness", 0)) != 8:
		return _fail("demonic auction did not register its source NPC companion")
	var poor: Dictionary = state.duplicate(true)
	poor.resources.spiritStone = 99
	if policy.choice_available(poor, auction, "left"):
		return _fail("demonic auction admitted insufficient stones")
	var secret: Dictionary = policy.settle(state, "ds_pill_master_trade", "right")
	if secret.is_empty() or int(secret.attributes.cultivation) \
			!= mini(100, int(state.attributes.cultivation) + 15) \
			or int(secret.attributes.karmaBad) \
			!= mini(100, int(state.attributes.karmaBad) + 8) \
			or not trade.choices.right.get("narrativeBlock") is String:
		return _fail("pill master narrative or effect settlement invalid")
	print("NONCOMBAT_NASCENT_SEDUCTRESS_CHOICES_PASS companion=true secret=true")
	quit(0)
