extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Store = preload("res://scripts/noncombat_opening_store.gd")
const Slots = preload("res://scripts/noncombat_save_slots.gd")


func _initialize() -> void:
	var root_path := "user://tests/noncombat_slots_%d" % Time.get_ticks_usec()
	var slots = Slots.new(root_path)
	if Slots.new().save_path_for("slot_1") != "user://noncombat_opening_v1.json":
		_fail("the previous Godot opening save lost its original slot-one path")
		return
	if slots.active_slot() != "slot_1" or slots.select_slot("unknown") \
			or slots.save_path_for("unknown") != "":
		_fail("the source three-slot IDs or default are not enforced")
		return
	var slot_one_path: String = slots.save_path_for("slot_1")
	var first = Domain.new(Registry.new(), Store.new(slot_one_path), "slot_1")
	if not first.start("sword") or not first.choose("right", first.issue_choice_token()):
		_fail("slot one could not hold the existing opening save format")
		return
	if not slots.inspect_slot("slot_1").get("occupied") \
			or slots.inspect_slot("slot_2").get("occupied") \
			or slots.inspect_slot("slot_1").get("playerName") != "叶凌云":
		_fail("slot presence leaked across source slot IDs")
		return
	if not slots.select_slot("slot_2") or Slots.new(root_path).active_slot() != "slot_2":
		_fail("active slot selection did not survive reopen")
		return
	var slot_two_path: String = slots.save_path_for("slot_2")
	var second = Domain.new(Registry.new(), Store.new(slot_two_path), "slot_2")
	if not second.start("body") or not second.choose("left", second.issue_choice_token()):
		_fail("slot two could not own an independent source run")
		return
	var reopened_one = Domain.new(Registry.new(), Store.new(slot_one_path), "slot_1")
	var reopened_two = Domain.new(Registry.new(), Store.new(slot_two_path), "slot_2")
	if not reopened_one.restore() or not reopened_two.restore() \
			or reopened_one.state.get("path") != "sword" \
			or reopened_one.state.get("currentCardId") != "tutorial_4" \
			or reopened_two.state.get("path") != "body" \
			or reopened_two.state.get("currentCardId") != "tutorial_2":
		_fail("switching slots overwrote an existing run")
		return
	if reopened_one.state["runClock"]["lifeId"] != "slot_1:life:0" \
			or reopened_two.state["runClock"]["lifeId"] != "slot_2:life:0" \
			or not reopened_two.state["runClock"]["receipts"].has(
			"decision:slot_2:life:0:choice:tutorial_1:1"):
		_fail("decision identity or receipt token collided across slots")
		return
	var corrupted_path: String = slots.save_path_for("slot_3")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(corrupted_path).get_base_dir())
	var file := FileAccess.open(corrupted_path, FileAccess.WRITE)
	file.store_string("{source bytes must survive")
	file.close()
	var third: Dictionary = slots.inspect_slot("slot_3")
	if not third.get("occupied") or not third.get("corrupted") \
			or FileAccess.get_file_as_string(corrupted_path) != "{source bytes must survive":
		_fail("corrupt occupied slot was treated as free or overwritten")
		return
	var active_path := root_path + "/noncombat_active_slot_v1.json"
	var bad_index := FileAccess.open(active_path, FileAccess.WRITE)
	bad_index.store_string("{broken active index")
	bad_index.close()
	if not slots.select_slot("slot_3") or slots.active_slot() != "slot_3" \
			or slots.last_archived_index.is_empty() \
			or FileAccess.get_file_as_string(slots.last_archived_index) != "{broken active index":
		_fail("damaged active-slot index trapped the player or destroyed its bytes")
		return
	print("NONCOMBAT_SAVE_SLOTS_PASS slots=3 isolated=2 active_reopen=true corrupt_preserved=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
