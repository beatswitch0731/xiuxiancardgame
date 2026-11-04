extends "res://tests/noncombat_market_arrival.gd"

const FIXTURE := "res://tests/fixtures/spirit_mine_pending_v1.json"


func _run() -> void:
	var path := "user://tests/spirit_mine_thread_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var staged := FileAccess.open(store.v2_path, FileAccess.WRITE)
	if staged == null:
		return _fail("cannot stage natural spirit mine checkpoint")
	staged.store_string(FileAccess.get_file_as_string(FIXTURE))
	staged.close()
	var game = Domain.new(Registry.new(), store, "slot_3")
	_stabilize_ambient(game)
	if not game.restore() or game.state.get("phase") != "NORMAL_PENDING" \
			or game.get_current_card().get("id") != "q_spiritStone" \
			or game.state.get("storyThreadState", {}).get("activationIndex") != 1:
		return _fail("source checkpoint did not strictly restore")
	if not game.choose("right", game.issue_choice_token()):
		return _fail("natural mine decision did not accept right choice")
	var visited := 0
	for step in 18:
		if game.state.get("phase") == "FLOW_PENDING" and not game.resume_flow():
			return _fail("story flow stopped at %d: %s" % [step,
				game.flow_failure_reason()])
		var card: Dictionary = game.get_current_card()
		var card_id := String(card.get("id", ""))
		if card_id.is_empty():
			return _fail("story flow emitted an empty card")
		if game.state.get("phase") == "THREAD_PENDING":
			visited += 1
			if card_id != "thread_spirit_mine_%d" % visited \
					or card.get("sceneImage") not in [
						"assets/cards/keyframes/scene_key_spirit_mine_arrival_v2.png",
						"assets/cards/keyframes/scene_key_spirit_mine_ledger_choice_v1.png"]:
				return _fail("thread node or original scene image differed")
			var pending: Dictionary = game.state.duplicate(true)
			var reopened = Domain.new(Registry.new(), RunSession.new(path,
				"slot_3"), "slot_3")
			_stabilize_ambient(reopened)
			if not reopened.restore() or not _same(reopened.state, pending) \
					or reopened.get_current_card() != card:
				return _fail("thread pending node failed strict restart")
			if visited == 2:
				var authored: Dictionary = game._content.read_module(
					"threads:qi_threads")["threads"][1]["nodes"][1]
				if not String(card.get("description", "")).ends_with(String(
						authored["variants"][0]["card"]["description"])):
					return _fail("second node lost the original first-choice variant")
				var branch_path := "user://tests/spirit_mine_branch_%d.json" % \
					Time.get_ticks_usec()
				var branch_store = RunSession.new(branch_path, "slot_3")
				if branch_store.commit_snapshot(pending, -1).get("ok") != true:
					return _fail("cannot stage alternate thread resolution")
				var branch = Domain.new(Registry.new(), branch_store, "slot_3")
				_stabilize_ambient(branch)
				var stone_before := int(pending["resources"]["spiritStone"])
				var seed_id := String(card["choices"]["right"]["karmaSeed"]["id"])
				if not branch.restore() or not branch.can_choose_direction("right") \
						or not branch.choose("right", branch.issue_choice_token()) \
						or int(branch.state["resources"]["spiritStone"]) != stone_before - 10 \
						or _mine_runtime(branch.state).get("status") != "completed" \
						or branch.state.get("flags", {}).get("mine_dispute_resolved") != true \
						or not branch.state.get("karmaSeeds", []).any(func(seed: Variant) -> bool:
							return seed is Dictionary and seed.get("id") == seed_id):
					return _fail("alternate thread reward or karma promise diverged")
				var branch_reopen = Domain.new(Registry.new(), RunSession.new(
					branch_path, "slot_3"), "slot_3")
				_stabilize_ambient(branch_reopen)
				if not branch_reopen.restore() or not _same(branch_reopen.state,
						branch.state):
					return _fail("alternate thread resolution failed strict restart")
			var bytes := FileAccess.get_file_as_string(store.v2_path)
			var token := game.issue_choice_token()
			game._store.fail_promotion_once = true
			if game.choose("left", token) or not _same(game.state, pending) \
					or FileAccess.get_file_as_string(store.v2_path) != bytes \
					or not game.choose("left", token):
				return _fail("thread choice rollback or settlement failed")
			var settled = Domain.new(Registry.new(), RunSession.new(path,
				"slot_3"), "slot_3")
			_stabilize_ambient(settled)
			if not settled.restore() or not _same(settled.state, game.state):
				return _fail("thread settled node failed strict restart")
			if visited == 2:
				var thread: Dictionary = _mine_runtime(game.state)
				var pill := String(card.get("choices", {}).get("left", {}).get(
					"effects", {}).get("pills", ""))
				if thread.get("status") != "completed" \
						or thread.get("receipt", {}).get("nodes", []).size() != 2 \
						or game.state.get("flags", {}).get("mine_dispute_resolved") != true \
						or pill.is_empty() or int(game.state.get("resources", {}).get(
							"pills", {}).get(pill, 0)) < 1:
					return _fail("source thread completion or pill reward missing")
				print("NONCOMBAT_STORY_SPIRIT_MINE_PASS nodes=2 branches=2 replay=true rollback=true")
				quit(0)
				return
			continue
		var direction := "right" if game.can_choose_direction("right") else "left"
		if card_id == "q_love" and game.can_choose_direction("right"):
			direction = "right"
		if not game.choose(direction, game.issue_choice_token()):
			return _fail("interstitial source card stopped thread: " + card_id)
	return _fail("source story thread did not complete within eighteen cards")


func _mine_runtime(snapshot: Dictionary) -> Dictionary:
	var bundle: Dictionary = snapshot.get("storyThreadState", {})
	return bundle if bundle.get("version") == 1 else bundle.get("threads", {}).get("spirit_mine", {})
