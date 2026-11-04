extends SceneTree

const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source = ContentRepository.new()
	var flow = StoryThreads.new(source)
	var nodes: Array = source.read_module("threads:last_lesson_threads").threads[0].nodes
	var dispute: Dictionary = nodes[3]
	var bought: Dictionary = _variant(dispute, "market_sword_purchased")
	var empty: Dictionary = _variant(dispute, "market_without_sword_purchase")
	var sect: Dictionary = _variant(dispute, "sect_trial_sword_loan")
	if bought.is_empty() or empty.is_empty() or sect.is_empty():
		return _fail("last lesson source variants missing")
	var purchase := [{"nodeId": "ll_market_sword", "direction": "left",
		"outcomeContext": {"mode": "vendor", "vendorSummary": {
			"resolution": "purchased", "purchasedItemIds": ["last_lesson_three_tone_sword"]}}}]
	if not flow._matches_history(bought.when, purchase):
		return _fail("purchased sword did not select source variant")
	var other_item: Array = purchase.duplicate(true)
	other_item[0].outcomeContext.vendorSummary.purchasedItemIds = ["other_sword"]
	if flow._matches_history(bought.when, other_item):
		return _fail("unrelated purchase selected three-tone sword variant")
	var left_empty := [{"nodeId": "ll_market_sword", "direction": "left",
		"outcomeContext": {"mode": "vendor", "vendorSummary": {
			"resolution": "left_empty", "purchasedItemIds": []}}}]
	if not flow._matches_history(empty.when, left_empty) \
			or flow._matches_history(sect.when, left_empty):
		return _fail("empty market resolution selected wrong variant")
	var loan := [{"nodeId": "ll_market_sword", "direction": "right"}]
	if not flow._matches_history(sect.when, loan):
		return _fail("sect-loan anyOf did not select source variant")
	var bartered := [{"nodeId": "ll_market_sword", "direction": "left",
		"outcomeContext": {"mode": "vendor", "vendorSummary": {
			"resolution": "bartered", "purchasedItemIds": []}}}]
	for row in [[purchase, "market_sword_purchased"],
			[bartered, "market_sword_bartered"],
			[left_empty, "market_without_sword_purchase"],
			[loan, "sect_trial_sword_loan"]]:
		if _selected(flow, dispute, row[0]) != row[1]:
			return _fail("market source variant matrix diverged: " + str(row[1]))
	var letter: Dictionary = nodes[5]
	var victory: Dictionary = _variant(letter, "left_victory")
	var history := [{"nodeId": "ll_last_lesson", "direction": "left"},
		{"nodeId": "ll_sword_dispute", "direction": "left",
			"outcomeContext": {"mode": "combat", "combatOutcome": "victory"}}]
	if not flow._matches_history(victory.when, history):
		return _fail("combat victory did not select source letter")
	history[1].outcomeContext.mode = "vendor"
	if flow._matches_history(victory.when, history):
		return _fail("vendor context spoofed a combat result")
	for lesson_direction in ["left", "right"]:
		for outcome in ["victory", "defeat", "flee", "negotiated"]:
			var dispute_choice: Dictionary = {"nodeId": "ll_sword_dispute",
				"direction": "right" if outcome == "negotiated" else "left"}
			if outcome != "negotiated":
				dispute_choice["outcomeContext"] = {"mode": "combat",
					"combatOutcome": outcome}
			var lesson_history := [{"nodeId": "ll_last_lesson",
				"direction": lesson_direction}, dispute_choice]
			if _selected(flow, letter, lesson_history) != lesson_direction + "_" + outcome:
				return _fail("lesson/combat source variant matrix diverged: " +
					lesson_direction + "_" + outcome)
	if not _projected_matrix():
		return _fail("last lesson eight source echoes could not pass through active thread state")
	print("NONCOMBAT_LAST_LESSON_VARIANTS_PASS vendor=4 anyof=true combat=8 projected=8 choices=16")
	quit(0)


func _projected_matrix() -> bool:
	for lesson_direction in ["left", "right"]:
		for outcome in ["victory", "defeat", "flee", "negotiated"]:
			var game = Domain.new(Registry.new(), null, "slot_2")
			if not game.start("sword"):
				return false
			var flow = StoryThreads.new(ContentRepository.new())
			var state: Dictionary = game.state.duplicate(true)
			state.realm = "deity"
			state.phase = "FLOW_PENDING"
			state.flags = {}
			state.decisionCheckpoint = {"sourceCardId": "last_lesson_variant_matrix"}
			state.turn = 12
			state.runClock.decisionIndex = 12
			state.currentLocation = "宗门"
			var prior := state.duplicate(true)
			prior.turn = 11
			prior.runClock.decisionIndex = 11
			if not flow.tick(prior, state):
				push_warning("matrix tick failed " + lesson_direction + "/" + outcome)
				return false
			for direction in ["left", lesson_direction, "right"]:
				var pending := flow.resume(state)
				state = flow.settle_choice(pending, direction)
				if state.is_empty():
					push_warning("matrix prelude failed " + lesson_direction + "/" + outcome +
						" card=" + String(pending.get("currentCardId", "")))
					return false
			var dispute := flow.resume(state)
			if dispute.get("currentCardId") != "thread_last_lesson_n3":
				push_warning("matrix dispute absent " + lesson_direction + "/" + outcome)
				return false
			if outcome == "negotiated":
				state = flow.settle_choice(dispute, "right")
			else:
				state = flow.settle_combat(dispute, "left", outcome,
					int(dispute.runClock.decisionIndex) + 1)
				if state.is_empty():
					push_warning("matrix combat settle failed " + lesson_direction + "/" + outcome)
					return false
				state.turn += 1
				state.runClock.decisionIndex += 1
				state.phase = "FLOW_PENDING"
				state.currentCardId = ""
				state.currentLocation = "upper_realm_heaven_gate"
			if state.is_empty():
				push_warning("matrix dispute settle empty " + lesson_direction + "/" + outcome)
				return false
			var farewell := flow.resume(state)
			if farewell.get("currentCardId") != "thread_last_lesson_n4":
				push_warning("matrix farewell absent " + lesson_direction + "/" + outcome +
					" card=" + String(farewell.get("currentCardId", "")))
				return false
			state = flow.settle_choice(farewell, "left")
			if state.is_empty():
				push_warning("matrix farewell settle failed " + lesson_direction + "/" + outcome)
				return false
			var echo := flow.resume(state)
			if echo.get("currentCardId") != "thread_last_lesson_n5" \
					or echo.get("pendingThreadCard", {}).get("_threadVariantId") != \
						lesson_direction + "_" + outcome:
				push_warning("matrix echo failed " + lesson_direction + "/" + outcome +
					" variant=" + String(echo.get("pendingThreadCard", {}).get(
						"_threadVariantId", "")))
				return false
			var prior_insight := int(echo.get("knowledge", {}).get("sword", 0))
			var settled: Dictionary = flow.settle_choice(echo, "left")
			var expected_insight := 2 if lesson_direction == "left" else 1
			if settled.is_empty() or outcome == "victory" and int(settled.get(
					"knowledge", {}).get("sword", 0)) != prior_insight + expected_insight:
				push_warning("matrix source echo effect failed " + lesson_direction + "/" + outcome)
				return false
			var kept_watch: Dictionary = flow.settle_choice(echo, "right")
			if kept_watch.get("currentLocation") != "qingyun_sword_tomb" \
					or int(kept_watch.get("attributes", {}).get("daoHeart", 0)) < \
						int(echo.get("attributes", {}).get("daoHeart", 0)):
				push_warning("matrix watch branch failed " + lesson_direction + "/" + outcome)
				return false
	return true


func _variant(node: Dictionary, variant_id: String) -> Dictionary:
	for row in node.get("variants", []):
		if row.get("id") == variant_id:
			return row
	return {}


func _selected(flow: RefCounted, node: Dictionary, history: Array) -> String:
	for row in node.get("variants", []):
		if flow._matches_history(row.get("when", {}), history):
			return String(row.get("id", ""))
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
