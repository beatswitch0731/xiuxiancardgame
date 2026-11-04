extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const StoryThreads = preload("res://scripts/noncombat_story_threads_v2_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow = StoryThreads.new(Repository.new())
	if not flow.has_method("_required_node_gap") or not flow.has_method(
			"_node_eligible_for_state") or not flow.has_method("_append_history_echoes"):
		return _fail("source priority, presence, or history echo rule absent")
	var definition: Dictionary = Repository.new().read_module(
		"threads:last_lesson_threads").threads[0]
	var nodes: Array = definition.nodes
	if flow._required_node_gap(definition, nodes[0]) != 0 \
			or flow._required_node_gap(definition, nodes[6]) != 8 \
			or flow._required_node_gap({"priority": 52}, nodes[0]) != 2:
		return _fail("source priority gap or authored epilogue gap changed")
	var state := {"currentLocation": "qingyun_sword_tomb"}
	if flow._node_eligible_for_state(nodes[1], [], state):
		return _fail("last lesson node ignored required prior node")
	var n0 := [{"nodeId": "ll_sword_tomb_afterglow", "direction": "left"}]
	state.currentLocation = "sect_gate"
	if flow._node_eligible_for_state(nodes[1], n0, state):
		return _fail("last lesson node ignored physical player location")
	state.currentLocation = "qingyun_sword_tomb"
	if not flow._node_eligible_for_state(nodes[1], n0, state):
		return _fail("last lesson node rejected required node at source location")
	state.currentLocation = null
	if flow._node_eligible_for_state(nodes[1], n0, state):
		return _fail("last lesson node admitted absent player location")
	var n4 := [{"nodeId": "ll_heaven_gate_farewell", "direction": "left"}]
	var card := {"description": "base"}
	flow._append_history_echoes(card, nodes[5], n4)
	if not String(card.description).contains(String(nodes[5].historyEchoes[0].text)) \
			or String(card.description).contains(String(nodes[5].historyEchoes[1].text)):
		return _fail("last lesson farewell echo did not use accepted direction")
	print("NONCOMBAT_STORY_HIGH_PRIORITY_RULES_PASS gap=true location=true history=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
