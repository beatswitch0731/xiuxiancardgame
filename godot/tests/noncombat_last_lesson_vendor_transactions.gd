extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const BattleGateway = preload("res://scripts/noncombat_battle_gateway.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")
const VENDOR_SCRIPT := "res://scripts/noncombat_last_lesson_vendor_flow.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var vendor_class = load(VENDOR_SCRIPT)
	if vendor_class == null:
		return _fail("last lesson source vendor consumer absent")
	var variants := {"purchase": "market_sword_purchased",
		"barter": "market_sword_bartered", "fallback": "sect_trial_sword_loan",
		"empty": "market_without_sword_purchase"}
	var enemies := {"purchase": "last_lesson_purchased_three_tone_sword",
		"barter": "last_lesson_bartered_three_tone_sword",
		"fallback": "last_lesson_sect_trial_sword",
		"empty": "last_lesson_market_ward_sword_intents"}
	for mode in variants:
		var flow = StoryThreads.new(Repository.new())
		var game = Domain.new(Registry.new(), null, "slot_2")
		if not game.start("sword"):
			return _fail("last lesson vendor fixture could not start")
		var state: Dictionary = game.state.duplicate(true)
		state.realm = "deity"
		state.phase = "FLOW_PENDING"
		state.flags = {}
		state.decisionCheckpoint = {"sourceCardId": "q_last_lesson_entry"}
		state.turn = 12
		state.runClock.decisionIndex = 12
		state.currentLocation = "宗门"
		state.resources.spiritStone = 0 if mode == "fallback" else 24
		state.itemInventory = {"剑穗": 1} if mode == "barter" else {}
		var prior: Dictionary = state.duplicate(true)
		prior.turn = 11
		prior.runClock.decisionIndex = 11
		if not flow.tick(prior, state):
			return _fail("last lesson vendor activation failed")
		for direction in ["left", "right"]:
			var current: Dictionary = flow.resume(state)
			state = flow.settle_choice(current, direction)
			if state.is_empty():
				return _fail("last lesson vendor prelude failed")
		var entry: Dictionary = flow.resume(state)
		if entry.get("currentCardId") != "thread_last_lesson_n2" \
				or not flow.choice_available(entry, "left"):
			return _fail("last lesson vendor direction was not offered")
		if mode == "purchase":
			var mixed: Dictionary = flow.settle_choice(entry, "left", {
				"mode": "vendor", "vendorSummary": {
					"purchaseCount": 2, "spiritStoneSpent": 26,
					"resolution": "purchased", "purchasedItemIds": [
						"shop_pill_healing", "last_lesson_three_tone_sword"]}})
			if mixed.is_empty():
				return _fail("valid mixed sword purchase receipt was rejected")
		elif mode == "empty":
			var mixed: Dictionary = flow.settle_choice(entry, "left", {
				"mode": "vendor", "vendorSummary": {
					"purchaseCount": 1, "spiritStoneSpent": 8,
					"resolution": "left_empty", "purchasedItemIds": [
						"shop_pill_healing"]}})
			if mixed.is_empty():
				return _fail("valid mixed purchase without sword was rejected")
		game.state = entry.duplicate(true)
		game._normal_roll_override = 0.0
		if mode == "purchase":
			var store = RunSession.new("user://tests/last_lesson_vendor_%d.json" %
				Time.get_ticks_usec(), "slot_2")
			var staged: Dictionary = store.commit_snapshot(entry, -1)
			if staged.get("ok") != true:
				return _fail("could not stage vendor atomicity state")
			game._store = store
			game._store_revision = int(staged.revision)
		if not game.choose("left", game.issue_choice_token()) \
				or game.state.get("phase") != "VENDOR_OPEN" \
				or game.vendor_offers().size() < 4:
			return _fail("domain did not open authored last lesson vendor: " + mode)
		if mode == "purchase":
			var before: Dictionary = game.state.duplicate(true)
			var before_bytes := FileAccess.get_file_as_string(game._store.v2_path)
			game._store.fail_promotion_once = true
			if game.purchase_vendor_offer("last_lesson_three_tone_sword",
					game.issue_choice_token()) or game.state != before \
					or FileAccess.get_file_as_string(game._store.v2_path) != before_bytes:
				return _fail("failed last lesson purchase changed state or slot bytes")
			var gift: Dictionary = {}
			for offer in game.state.marketState.activeSession.immutableOffers:
				if offer.get("type") == "gift":
					gift = offer
					break
			var gift_bought := not gift.is_empty() and game.purchase_vendor_offer(
				String(gift.id), game.issue_choice_token())
			if not gift_bought or int(game.state.get("itemInventory", {}).get(
					gift.get("effect", {}).get("giftItemId"), 0)) != int(gift.get(
					"effect", {}).get("quantity", 1)):
				return _fail("deity mixed gift purchase was not settled")
			var gift_id := String(gift.effect.giftItemId)
			var buyback_id := "regulated_buyback:" + gift_id
			var before_buyback := int(game.state.resources.spiritStone)
			if not game.vendor_actions().any(func(row: Variant) -> bool:
				return row.get("id") == buyback_id and row.get("enabled") == true) \
					or not _failed_action_keeps_bytes(game, buyback_id) \
					or not game.perform_vendor_action(buyback_id,
						game.issue_choice_token()) \
					or game.state.marketState.activeSession.summary.exchangeCount != 1 \
					or int(game.state.resources.spiritStone) != before_buyback + 2 \
					or int(game.state.itemInventory.get(gift_id, 0)) != 0 \
					or game.perform_vendor_action(buyback_id, game.issue_choice_token()):
				return _fail("last lesson regulated buyback service unavailable")
			if not game.purchase_vendor_offer("last_lesson_three_tone_sword",
					game.issue_choice_token()):
				return _fail("domain last lesson purchase failed")
		elif mode == "barter":
			var gift: Dictionary = {}
			for offer in game.state.marketState.activeSession.immutableOffers:
				if offer.get("type") == "gift":
					gift = offer
					break
			if gift.is_empty() or not game.purchase_vendor_offer(String(gift.id),
					game.issue_choice_token()) or not game.perform_vendor_action(
					"regulated_buyback:" + String(gift.effect.giftItemId),
					game.issue_choice_token()):
				return _fail("barter prelude buyback failed")
			if not game.perform_vendor_action("last_lesson_exchange_sword_tassel",
					game.issue_choice_token()) \
					or game.state.marketState.activeSession.summary.exchangeCount != 2 \
					or game.state.marketState.activeSession.summary.exchangedItems.size() != 2:
				return _fail("domain last lesson barter failed")
		elif mode == "fallback":
			if not game.perform_vendor_action("last_lesson_insufficient_sect_loan",
					game.issue_choice_token()):
				return _fail("domain last lesson fallback failed")
		elif mode == "empty":
			var pill: Dictionary = {}
			for offer in game.state.marketState.activeSession.immutableOffers:
				if offer.get("type") == "pill":
					pill = offer
					break
			if pill.is_empty() or not game.purchase_vendor_offer(String(pill.id),
					game.issue_choice_token()):
				return _fail("deity mixed pill purchase was not settled")
		if not game.close_vendor(game.issue_choice_token()) \
				or game.state.get("phase") != "VENDOR_RESULT_PENDING":
			return _fail("domain last lesson vendor close failed: " + mode)
		var domain_closed: Dictionary = game.state.duplicate(true)
		var domain_summary: Dictionary = domain_closed.storyThreadState.threads.bairen_last_lesson.choices[2].outcomeContext.vendorSummary
		if mode == "purchase" and (domain_summary.purchaseCount != 2 \
				or not domain_summary.purchasedItemIds.has("last_lesson_three_tone_sword")) \
				or mode == "empty" and (domain_summary.purchaseCount != 1 \
				or domain_summary.resolution != "left_empty"):
			return _fail("mixed vendor purchases did not enter story receipt: " + mode)
		var replay = Domain.new(Registry.new(), null, "slot_2")
		if not replay.start("sword"):
			return _fail("vendor replay fixture could not start")
		replay.state = entry.duplicate(true)
		replay._normal_roll_override = 0.0
		if not replay.choose("left", replay.issue_choice_token()) \
				or not replay._replay_vendor_actions(domain_closed) \
				or not replay.close_vendor(replay.issue_choice_token()) \
				or JSON.parse_string(JSON.stringify(replay.state)) != \
				JSON.parse_string(JSON.stringify(domain_closed)):
			return _fail("domain last lesson vendor event replay diverged: " + mode)
		if not game.choose("right", game.issue_choice_token()):
			return _fail("domain last lesson vendor dismiss failed: " + mode)
		var vendor = vendor_class.new(Repository.new(), flow)
		var catalog = Catalog.new(Repository.new())
		var ordinary: Array = catalog.generate_for_realm(entry, func() -> float:
			return 0.0)
		var opened: Dictionary = vendor.open(entry, ordinary)
		if opened.get("phase") != "VENDOR_OPEN" or vendor.available_offers(
				opened).size() < 4:
			return _fail("authored sword offer did not open")
		if mode == "empty":
			var body_heal: Dictionary = opened.duplicate(true)
			body_heal.path = "body"
			body_heal.attributes.health = int(body_heal.maxHealth)
			var healed: Dictionary = vendor.purchase(body_heal, "shop_pill_healing")
			if healed.is_empty() or int(healed.attributes.health) != int(
					body_heal.maxHealth) + 2:
				return _fail("body path max health passive was lost at healing purchase")
		var changed := opened
		if mode == "purchase":
			changed = vendor.purchase(opened, "last_lesson_three_tone_sword")
		elif mode == "barter":
			changed = vendor.interact(opened, "last_lesson_exchange_sword_tassel")
		elif mode == "fallback":
			changed = vendor.interact(opened, "last_lesson_insufficient_sect_loan")
		if changed.is_empty():
			return _fail("last lesson vendor transaction failed: " + mode)
		var closed: Dictionary = vendor.close(changed)
		if closed.get("phase") != "VENDOR_RESULT_PENDING":
			return _fail("last lesson vendor did not settle only on close: " + mode)
		var accepted: Array = closed.storyThreadState.threads.bairen_last_lesson.choices
		if accepted.size() != 3 or accepted[2].get("outcomeContext", {}).get(
				"mode") != "vendor":
			return _fail("vendor close did not append authored thread outcome: " + mode)
		var summary: Dictionary = accepted[2].outcomeContext.vendorSummary
		var purchased: Array = summary.get("purchasedItemIds", [])
		if summary.get("resolution") != ("purchased" if mode == "purchase" else \
				"bartered" if mode == "barter" else "sect_loan" if mode == "fallback" else "left_empty") \
				or purchased.has("last_lesson_three_tone_sword") != (mode == "purchase"):
			return _fail("vendor summary differs from source: " + mode)
		if int(closed.get("itemInventory", {}).get("last_lesson_three_tone_sword", 0)) != \
				(1 if mode in ["purchase", "barter"] else 0):
			return _fail("story sword inventory differs from source: " + mode)
		if mode == "purchase" and int(closed.resources.spiritStone) != 6:
			return _fail("story sword purchase did not charge once")
		if mode == "barter" and int(closed.itemInventory.get("剑穗", -1)) != 0:
			return _fail("story sword barter did not consume sword tassel")
		var location := "qingyun_trial_sword_terrace" if mode == "fallback" else \
			"deity_market_stone_street"
		if closed.get("currentLocation") != location:
			return _fail("story vendor close lost source destination: " + mode)
		var dismissed: Dictionary = vendor.dismiss(closed)
		var dispute: Dictionary = flow.resume(dismissed)
		if dispute.get("pendingThreadCard", {}).get("_threadVariantId") != variants[mode]:
			return _fail("vendor outcome did not select N3 source variant: " + mode)
		var battle_state := dispute.duplicate(true)
		battle_state["pendingThreadCombatDirection"] = "left"
		var resolution: Dictionary = BattleGateway.new(Registry.new(), Repository.new()
			).source_resolution_for_offer(battle_state)
		if resolution.get("choice", {}).get("enemy", {}).get("id") != enemies[mode] \
				or resolution.get("combatCard", {}).get("enemy", {}).get("id") != enemies[mode]:
			return _fail("vendor outcome lost N3 enemy variant: " + mode)
	if not _check_treasure_purchase():
		return _fail("last lesson ordinary treasure purchase/loadout/replay failed")
	print("NONCOMBAT_LAST_LESSON_VENDOR_TRANSACTIONS_PASS outcomes=4 goods=true buyback=true causal_order=true order_rollback=true deferred_loadout=true replay=true goods_action_rollback=true disk_read=true sword_rollback=true body_cap=true")
	quit(0)


func _check_treasure_purchase() -> bool:
	var flow = StoryThreads.new(Repository.new())
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return false
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "deity"
	state.phase = "FLOW_PENDING"
	state.flags = {}
	state.decisionCheckpoint = {"sourceCardId": "q_last_lesson_entry"}
	state.turn = 12
	state.runClock.decisionIndex = 12
	state.currentLocation = "宗门"
	state.resources.spiritStone = 100
	state.attributes.fortune = 100
	var prior: Dictionary = state.duplicate(true)
	prior.turn = 11
	prior.runClock.decisionIndex = 11
	if not flow.tick(prior, state):
		return false
	for direction in ["left", "right"]:
		state = flow.settle_choice(flow.resume(state), direction)
		if state.is_empty():
			return false
	game.state = flow.resume(state)
	var causal_entry: Dictionary = game.state.duplicate(true)
	var fact_id := "fact:0:rumor_rusted_sword_origin"
	causal_entry["noncombatFlow"] = {"spineFacts": {}, "spineConsumptions": {}}
	causal_entry.itemInventory = {"剑穗": 1}
	causal_entry.noncombatFlow.spineFacts[fact_id] = {
		"factInstanceId": fact_id, "factTypeId": "rumor_rusted_sword_origin",
		"status": "active", "createdDecisionIndex": int(
			causal_entry.runClock.decisionIndex) - 2,
		"payload": {"sellerLeadId": "luo_trader"}}
	var causal_vendor = load(VENDOR_SCRIPT).new(Repository.new(), flow)
	var causal_offers: Array = Catalog.new(Repository.new()).generate_for_realm(
		causal_entry, func() -> float: return 0.0)
	var causal_open: Dictionary = causal_vendor.open(causal_entry, causal_offers)
	var causal_action := "causal_fact:regulated_rusted_sword_order:" + fact_id
	var causal_treasure: Dictionary = {}
	for raw in causal_open.get("marketState", {}).get("activeSession", {}).get(
			"immutableOffers", []):
		if raw.get("effect", {}).has("treasureId"):
			causal_treasure = raw
			break
	if causal_treasure.is_empty():
		return false
	causal_open = causal_vendor.purchase(causal_open, String(causal_treasure.id))
	if causal_open.is_empty() or causal_open.get("pendingLoadoutDecision") == null:
		return false
	if causal_open.is_empty() or not causal_vendor.available_actions(
			causal_open).any(func(row: Variant) -> bool:
				return row.get("id") == causal_action and row.get("enabled") == true):
		push_warning("causal quote absent: " + str(causal_vendor.available_actions(causal_open))
			+ " error=" + causal_vendor.last_error)
		return false
	var order_store = RunSession.new("user://tests/last_lesson_order_%d.json" %
		Time.get_ticks_usec(), "slot_2")
	var order_staged: Dictionary = order_store.commit_snapshot(causal_open, -1)
	if order_staged.get("ok") != true:
		return false
	var order_game = Domain.new(Registry.new(), null, "slot_2")
	if not order_game.start("sword"):
		return false
	order_game.state = causal_open.duplicate(true)
	order_game._store = order_store
	order_game._store_revision = int(order_staged.revision)
	if not _failed_action_keeps_bytes(order_game, causal_action):
		push_warning("causal order failed promotion changed in-memory state or original bytes")
		return false
	if not order_game.perform_vendor_action(causal_action, order_game.issue_choice_token()):
		push_warning("causal order retry failed: " + str(
			order_game._last_lesson_vendor.last_error))
		return false
	if order_game.state.get("marketState", {}).get("rustedSwordOrders", []).size() != 1 \
			or order_game.state.noncombatFlow.spineFacts[fact_id].status != "consumed" \
			or order_game.state.resources.spiritStone != 100 - int(causal_treasure.price) - 12:
		push_warning("causal order durable state has wrong goods, fact, or balance")
		return false
	var saved_order: Dictionary = order_store.load_snapshot().get("state", {})
	if JSON.parse_string(JSON.stringify(saved_order)) != \
			JSON.parse_string(JSON.stringify(order_game.state)):
		push_warning("causal order disk read differs from committed state")
		return false
	var causal_order: Dictionary = causal_vendor.interact(causal_open, causal_action)
	if causal_order.is_empty() or causal_order.get("marketState", {}).get(
			"rustedSwordOrders", []).size() != 1 \
			or causal_order.noncombatFlow.spineFacts[fact_id].status != "consumed" \
			or causal_order.resources.spiritStone != 100 - int(
				causal_treasure.price) - 12:
		push_warning("causal settle failed: " + str(causal_order.get("marketState", {}).get(
			"rustedSwordOrders", [])) + " error=" + causal_vendor.last_error)
		return false
	var causal_barter: Dictionary = causal_vendor.interact(causal_order,
		"last_lesson_exchange_sword_tassel")
	if causal_barter.is_empty() or causal_barter.marketState.activeSession.summary.exchangeCount != 2 \
			or causal_barter.marketState.activeSession.summary.exchangedItems.size() != 2 \
			or causal_barter.marketState.activeSession.summary.exchangedItems[0].get(
				"direction") != "causal_order":
		return false
	var goods_store = RunSession.new("user://tests/last_lesson_goods_%d.json" %
		Time.get_ticks_usec(), "slot_2")
	var goods_staged: Dictionary = goods_store.commit_snapshot(game.state, -1)
	if goods_staged.get("ok") != true:
		return false
	game._store = goods_store
	game._store_revision = int(goods_staged.revision)
	game._normal_roll_override = 0.0
	if not game.choose("left", game.issue_choice_token()):
		return false
	var offer: Dictionary = {}
	for raw in game.state.marketState.activeSession.immutableOffers:
		if raw.get("type") == "treasure" and raw.get("effect", {}).has("treasureId"):
			offer = raw
			break
	if offer.is_empty() or not game.vendor_offers().any(func(row: Variant) -> bool:
		return row.get("id") == offer.id and row.get("enabled") == true):
		return false
	if not _failed_purchase_keeps_bytes(game, String(offer.id)) \
			or not game.purchase_vendor_offer(String(offer.id), game.issue_choice_token()):
		return false
	var pending: Variant = game.state.get("pendingLoadoutDecision")
	if not pending is Dictionary or pending.get("targetSlot") not in [
			"weapon", "armor", "accessory", "artifact"]:
		return false
	var receipt: Dictionary = game.state.get("treasureCommandReceipts", {}).get(
		pending.purchaseReceiptToken, {})
	var instance: Dictionary = game.state.get("treasureInstances", {}).get(
		pending.instanceId, {})
	if receipt.get("instanceId") != pending.instanceId \
			or instance.get("definitionId") != offer.effect.treasureId \
			or instance.get("provenance", {}).get("source") != "shop_purchase":
		return false
	var card_offer: Dictionary = {}
	for raw in game.state.marketState.activeSession.immutableOffers:
		if raw.get("type") == "card":
			card_offer = raw
			break
	if card_offer.is_empty() or not _failed_purchase_keeps_bytes(game,
			String(card_offer.id)) or not game.purchase_vendor_offer(String(card_offer.id),
			game.issue_choice_token()):
		push_warning("card purchase failed: " + String(game._last_lesson_vendor.last_error))
		return false
	var card_id := String(card_offer.effect.deckCard.cardId)
	if not game.state.deck.has(card_id) or game.state.get(
			"skillAcquisitions", {}).get(card_id, {}).get(
			"sourceType") != "shop_path_slot":
		return false
	var box: Dictionary = {}
	for raw in game.state.marketState.activeSession.immutableOffers:
		if raw.get("id") == "shop_treasure_box":
			box = raw
			break
	if box.is_empty() or not _failed_purchase_keeps_bytes(game, String(box.id)) \
			or not game.purchase_vendor_offer(String(box.id),
			game.issue_choice_token()):
		return false
	if game.state.get("treasureInstances", {}).size() != 2 \
			or not game.state.get("lastLessonVendorEventHistory", []).any(
				func(row: Variant) -> bool:
					return row.get("itemId") == "shop_treasure_box" \
						and row.has("identifyRoll") and row.has("itemRoll")):
		return false
	if not game.close_vendor(game.issue_choice_token()) \
			or game.state.get("pendingLoadoutDecision") == null \
			or not game.choose("right", game.issue_choice_token()):
		push_warning("close/dismiss failed phase=" + String(game.state.get("phase")))
		return false
	var saved: Dictionary = game.state.duplicate(true)
	if not game.resolve_vendor_loadout("equip", game.issue_choice_token()) \
			or game.state.get("pendingLoadoutDecision") != null:
		push_warning("deferred equip failed")
		return false
	var equipped: Dictionary = game.state.duplicate(true)
	var cold_record: Dictionary = game._store.load_snapshot()
	if JSON.parse_string(JSON.stringify(cold_record.get("state", {}))) != \
			JSON.parse_string(JSON.stringify(equipped)):
		push_warning("last lesson mixed goods save did not cold read")
		return false
	var replay = Domain.new(Registry.new(), null, "slot_2")
	if not replay.start("sword"):
		return false
	replay.state = flow.resume(state)
	replay._normal_roll_override = 0.0
	if not replay.choose("left", replay.issue_choice_token()):
		push_warning("replay opening failed")
		return false
	if not replay._replay_vendor_actions(equipped):
		push_warning("replay actions failed")
		return false
	if not replay.close_vendor(replay.issue_choice_token()):
		push_warning("replay close failed")
		return false
	if not replay.choose("right", replay.issue_choice_token()):
		push_warning("replay dismiss failed")
		return false
	if not replay._replay_deferred_last_lesson_loadout(equipped):
		push_warning("replay deferred loadout failed")
		return false
	if JSON.parse_string(JSON.stringify(replay.state)) != \
			JSON.parse_string(JSON.stringify(equipped)):
		push_warning("replay final state mismatch")
		return false
	return saved.get("pendingLoadoutDecision") != null


func _failed_purchase_keeps_bytes(game: RefCounted, offer_id: String) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	return not game.purchase_vendor_offer(offer_id, game.issue_choice_token()) \
		and game.state == before \
		and FileAccess.get_file_as_string(game._store.v2_path) == bytes


func _failed_action_keeps_bytes(game: RefCounted, action_id: String) -> bool:
	var before: Dictionary = game.state.duplicate(true)
	var bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	return not game.perform_vendor_action(action_id, game.issue_choice_token()) \
		and game.state == before \
		and FileAccess.get_file_as_string(game._store.v2_path) == bytes


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
