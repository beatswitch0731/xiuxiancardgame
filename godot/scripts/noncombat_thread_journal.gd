extends RefCounted

# Read-only StoryThreadEngine sidebar projection over the current life's
# persisted thread runtimes and active karma seeds.
const ThreadFlow = preload("res://scripts/noncombat_story_threads_v2_flow.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")

var _flow: RefCounted


func _init(repository: RefCounted = null) -> void:
	_flow = ThreadFlow.new(repository if repository != null else ContentRepository.new())


func project(state: Dictionary) -> Dictionary:
	var active: Array[Dictionary] = []
	var recent_closed: Array[Dictionary] = []
	for thread_id in ThreadFlow.THREAD_IDS:
		var runtime: Dictionary = _flow.thread_state(state, thread_id)
		if runtime.is_empty():
			continue
		var definition: Dictionary = _flow._definition_for(thread_id)
		if definition.is_empty():
			continue
		var nodes: Array = definition.get("nodes", [])
		var title: String = String(definition.get("title", thread_id))
		if runtime.get("status") == "active":
			var index := int(runtime.get("nodeIndex", 0))
			var phase := "active"
			if not nodes.is_empty():
				phase = String(nodes[clampi(index, 0, nodes.size() - 1)].get(
					"phase", "active"))
			active.append({"threadId": thread_id, "title": title, "phase": phase,
				"progress": "%d/%d" % [index, nodes.size()],
				"dominantDirection": _dominant(runtime.get("choices", [])),
				"startedTurn": int(runtime.get("startedTurn", 0))})
		elif runtime.get("status") in ["completed", "declined", "timeout", "failed", "realm_expired"]:
			var receipt: Dictionary = runtime.get("receipt", {}) \
				if runtime.get("receipt") is Dictionary else {}
			var note: String = "「%s」故事线完成。" % title
			var completed_index := clampi(int(runtime.get("nodeIndex", 1)) - 1,
				0, maxi(0, nodes.size() - 1))
			if not nodes.is_empty():
				var authored_note: Variant = nodes[completed_index].get(
					"consequences", {}).get("onComplete", {}).get("note")
				if authored_note is String and not authored_note.is_empty():
					note = authored_note
			if receipt.get("note") is String and not String(receipt.note).is_empty():
				note = String(receipt.note)
			recent_closed.append({"threadId": thread_id, "title": title,
				"status": runtime.status,
				"turn": int(receipt.get("closedTurn", 0)), "note": note})
	recent_closed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.turn > b.turn)
	if recent_closed.size() > 5:
		recent_closed.resize(5)
	var completed: Array[Dictionary] = []
	for entry in recent_closed:
		if entry.status == "completed":
			completed.append(entry)
	var seeds: Array[Dictionary] = []
	for seed in state.get("karmaSeeds", []):
		if not seed is Dictionary or seed.get("sprouted") == true:
			continue
		var origin := "未知"
		for field in ["originQuest", "originThread", "sourceThread", "originCard"]:
			if seed.get(field) is String and not String(seed[field]).is_empty():
				origin = String(seed[field])
				break
		seeds.append({"title": String(seed.get("desc", seed.get("description",
			seed.get("id", "")))), "origin": origin})
		if seeds.size() == 5:
			break
	return {"active": active, "completed": completed, "seeds": seeds}


func _dominant(choices: Variant) -> String:
	if not choices is Array:
		return ""
	var counts := {}
	var best := ""
	var maximum := 0
	for choice in choices:
		if not choice is Dictionary:
			continue
		var direction := String(choice.get("threadDirection", ""))
		counts[direction] = int(counts.get(direction, 0)) + 1
		if counts[direction] > maximum:
			maximum = counts[direction]
			best = direction
	return best
