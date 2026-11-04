extends SceneTree

const KarmaJournal = preload("res://scripts/noncombat_karma_journal.gd")
const OpeningUI = preload("res://scripts/noncombat_opening_ui.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seeds := [{"id": "seed_good", "seedType": "karma", "delay": 3,
		"realm": "foundation", "priority": 42, "originTurn": 8,
		"originCard": "q_kind", "description": "救人之因"},
		{"id": "seed_grudge", "seedType": "grudge", "delay": -2},
		{"id": "seed_blood", "seedType": "bloodline", "delay": 4},
		{"id": "seed_fate", "seedType": "fate", "delay": 5}]
	var entries: Array[Dictionary] = KarmaJournal.new().entries({"karmaSeeds": seeds})
	if entries.size() != 4 or entries[0].seedTypeName != "善因" \
			or entries[0].delay != 3 or entries[0].description != "救人之因" \
			or entries[1].seedTypeName != "恶因" or entries[1].delay != 0 \
			or entries[1].description != "在入世之初种下的恶因" \
			or entries[2].seedTypeName != "血脉因果" \
			or entries[3].seedTypeName != "宿命因果":
		return _fail("source KarmaSystem.getPlantedSeeds projection differs")
	var ui = OpeningUI.new()
	ui.save_path = ""
	root.add_child(ui)
	await process_frame
	if not ui.opening.start("sword"):
		return _fail("source story did not start")
	var button: Button = ui.find_child("OpenKarmaJournal", true, false)
	if button == null or not button.visible:
		return _fail("karma journal has no visible player entry")
	var before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	var dialog: AcceptDialog = ui.find_child("KarmaJournal", true, false)
	var list: VBoxContainer = dialog.find_child("KarmaJournalEntries", true, false)
	if not dialog.visible or list.get_child_count() != 1 \
			or not String(list.get_child(0).text).contains("暂无发芽中的因果种子") \
			or ui.opening.state != before:
		return _fail("empty source karma journal mutated run or showed wrong text")
	ui.opening.state.karmaSeeds = seeds.duplicate(true)
	var seeded_before: Dictionary = ui.opening.state.duplicate(true)
	button.pressed.emit()
	await process_frame
	if list.get_child_count() != 4 \
			or not String(list.get_child(0).text).contains("救人之因") \
			or not String(list.get_child(0).text).contains("第 8 次") \
			or not String(list.get_child(2).text).begins_with("seed_blood · 血脉\n") \
			or not String(list.get_child(3).text).begins_with("seed_fate · 宿命\n") \
			or ui.opening.state != seeded_before:
		return _fail("source planted seeds were not displayed read-only")
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.get_window().size = resolution
		await process_frame
		await process_frame
		if button.get_global_rect().end.x > resolution.x \
				or button.get_global_rect().end.y > resolution.y \
				or dialog.position.x + dialog.size.x > resolution.x \
				or dialog.position.y + dialog.size.y > resolution.y:
			return _fail("karma journal clipped at %s" % resolution)
	print("NONCOMBAT_KARMA_JOURNAL_PASS source=true empty=true seeded=true ui=true sizes=2")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
