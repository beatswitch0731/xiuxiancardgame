extends SceneTree

const Quest = preload("res://scripts/noncombat_quest_flow.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source: Dictionary = Repository.new().read_module("quests:sword_legacy")
	var card: Dictionary = source.get("cards", [])[2]
	var choice: Dictionary = card.choices.left
	var target := {"realm": "foundation", "lifeCount": 0,
		"karmaSeeds": [], "karmaPromiseFlags": {}, "flags": {}}
	if not Quest.new(Repository.new())._plant_quest_seed(target, choice.karmaSeed,
			card, choice, "left", 36, false, "victory"):
		return _fail("source quest seed could not be planted")
	var seed: Dictionary = target.karmaSeeds[0]
	if int(seed.get("delay", -1)) != 7 or int(seed.get("originTurn", -1)) != 36:
		return _fail("foundation seed did not match browser adjusted delay: " + JSON.stringify(seed))
	print("NONCOMBAT_FOUNDATION_SWORD_SEED_DELAY_PASS foundation=7 origin=36")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
