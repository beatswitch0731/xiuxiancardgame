extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const Catalog = preload("res://scripts/noncombat_regulated_shop_catalog.gd")
const Vendor = preload("res://scripts/noncombat_last_lesson_vendor_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var content = Repository.new()
	var flow = StoryThreads.new(content)
	var game = Domain.new(Registry.new(), null, "slot_2")
	if not game.start("sword"):
		return _fail("identify fixture start failed")
	var state: Dictionary = game.state.duplicate(true)
	state.realm = "deity"
	state.phase = "FLOW_PENDING"
	state.flags = {}
	state.decisionCheckpoint = {"sourceCardId": "q_last_lesson_entry"}
	state.turn = 12
	state.runClock.decisionIndex = 12
	state.currentLocation = "宗门"
	state.resources.spiritStone = 100
	state.attributes.fortune = 0
	var prior: Dictionary = state.duplicate(true)
	prior.turn = 11
	prior.runClock.decisionIndex = 11
	if not flow.tick(prior, state):
		return _fail("identify story activation failed")
	for direction in ["left", "right"]:
		state = flow.settle_choice(flow.resume(state), direction)
		if state.is_empty():
			return _fail("identify story prelude failed")
	var entry: Dictionary = flow.resume(state)
	var vendor = Vendor.new(content, flow)
	var catalog = Catalog.new(content)
	for box in [true, false]:
		var count := [0]
		var ordinary: Array = catalog.generate_for_realm(entry, func() -> float:
			count[0] += 1
			return 0.9 if count[0] == 6 and not box else 0.0)
		var offer_id := "shop_treasure_box" if box else "shop_treasure_mysterious"
		for raw_roll in ([0.0, 0.4, 0.6, 0.9] if box else [0.0, 0.5, 0.75, 0.95]):
			var opened: Dictionary = vendor.open(entry, ordinary)
			if opened.is_empty() or not opened.marketState.activeSession.immutableOffers.any(
					func(raw: Variant) -> bool: return raw.get("id") == offer_id):
				return _fail("identify source offer absent")
			var before_deck: int = opened.deck.size()
			var result: Dictionary = vendor.purchase(opened, offer_id, "",
				{"identifyRoll": raw_roll, "itemRoll": 0.0})
			if result.is_empty():
				return _fail("identify purchase failed box=%s roll=%s" % [box, raw_roll])
			var event: Dictionary = result.lastLessonVendorEventHistory.back()
			if event.get("identifyRoll") != raw_roll or result.get(
					"shopIdentifyRuleSourceSha") != Vendor.IDENTIFY_JS_SHA \
					or result.marketState.activeSession.immutableOffers.any(
						func(row: Variant) -> bool: return row is Dictionary \
							and row.get("id") == offer_id):
				return _fail("identify roll or source pin absent")
			if box and raw_roll == 0.0:
				if result.deck.size() != before_deck + 1 \
						or result.skillAcquisitions.get(result.deck.back(), {}).get(
							"sourceType") != "treasure_box_backlash_reward" \
						or not result.get("treasureInstances", {}).is_empty():
					return _fail("box backlash did not grant source path card")
			elif not box and raw_roll == 0.0:
				if result.resources.spiritStone != 100 - int(ordinary.back().price) + 2 \
						or not result.get("treasureInstances", {}).is_empty():
					return _fail("antique waste return differs from source")
			else:
				if result.get("treasureInstances", {}).size() != 1 or event.get("itemRoll") != 0.0:
					return _fail("identified treasure receipt absent")
				var instance: Dictionary = result.get("treasureInstances", {}).values()[0]
				if instance.get("provenance", {}).get("source") != "shop_identify" \
						or instance.get("provenance", {}).get("sourceId") != \
							String(opened.marketState.activeSession.sessionKey) + ":" + offer_id:
					return _fail("identified treasure provenance differs from source")
	print("NONCOMBAT_LAST_LESSON_IDENTIFY_PASS box=4 antique=4 backlash=true provenance=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
