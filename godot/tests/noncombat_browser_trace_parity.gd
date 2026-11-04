extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const TRACE_PATH := "res://content/fixtures/noncombat_opening_source_trace.json"


func _initialize() -> void:
	var file := FileAccess.open(TRACE_PATH, FileAccess.READ)
	if file == null:
		_fail("Live browser source trace was not synced")
		return
	var source = JSON.parse_string(file.get_as_text())
	if not source is Dictionary or source.get("path") != "sword" \
			or source.get("directions") != ["right", "left"] \
			or source.get("trace", []).size() != 3:
		_fail("Browser trace has an unexpected route")
		return
	var game = Domain.new(Registry.new())
	if not game.start("sword"):
		_fail("Godot could not start the browser source path")
		return
	for index in 3:
		if index > 0 and not game.choose(source["directions"][index - 1], game.issue_choice_token()):
			_fail("Godot rejected source choice at step %d" % index)
			return
		var state: Dictionary = game.state
		var actual := {
			"currentCardId": game.get_current_card().get("id"),
			"path": state["path"], "realm": state["realm"], "turn": state["turn"],
			"maxHealth": state["maxHealth"], "maxDaoHeart": state["maxDaoHeart"],
			"attributes": state["attributes"],
			"resources": {
				"spiritStone": state["resources"]["spiritStone"],
				"lifespan": state["resources"]["lifespan"],
			},
			"cardsPlayed": state["cardsPlayed"],
			"choiceHistory": state["choiceHistory"],
			"recentCardTags": state["recentCardTags"],
			"runClock": state["runClock"],
			"decisionCheckpoint": state["decisionCheckpoint"],
			"tutorialCompleted": state["tutorialCompleted"],
		}
		var normalized = JSON.parse_string(JSON.stringify(actual))
		for key in source["trace"][index]:
			if normalized.get(key) != source["trace"][index][key]:
				_fail("Live browser parity mismatch step=%d key=%s actual=%s source=%s" % [
					index, key, str(normalized.get(key)), str(source["trace"][index][key])])
				return
	print("NONCOMBAT_BROWSER_TRACE_PARITY_PASS steps=3 current=tutorial_1>tutorial_4>q_start_sword")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
