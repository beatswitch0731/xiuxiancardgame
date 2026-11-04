extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Slip = preload("res://scripts/battle_intent_slip.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data: RefCounted = Registry.new()
	var source: Dictionary = data.read_json("data/cards/battle_cards.json")
	var enemy: Dictionary = {}
	for item in source.get("enemies", []):
		if item.get("id", "") == "trial_aggressor_qi":
			enemy = item
			break
	if enemy.is_empty():
		_fail("First-battle enemy source is missing")
		return
	var slip: Control = Slip.new()
	root.add_child(slip)
	slip.position = Vector2(640, 145)
	slip.size.x = 306.0
	var plans: Dictionary = enemy["planGraph"]["states"]
	for state_id in plans:
		var plan: Dictionary = plans[state_id]
		var intent: Dictionary = plan["intent"].duplicate(true)
		intent["planState"] = state_id
		intent["planStateLabel"] = plan["label"]
		slip.set_intent(1, intent)
		await process_frame
		if not _text_fits(slip):
			_fail("Intent text clips for source state " + state_id)
			return
	var last_revision: int = slip.intent_revision
	var same_plan: Dictionary = plans["BROKEN"]
	var same_intent: Dictionary = same_plan["intent"].duplicate(true)
	same_intent["planState"] = "BROKEN"
	same_intent["planStateLabel"] = same_plan["label"]
	slip.set_intent(1, same_intent)
	if slip.intent_revision != last_revision:
		_fail("An unchanged combat redraw restarted the paper animation")
		return
	var long_intent := {"planState": "LONG", "planStateLabel": "蓄势观察",
		"type": "attack", "value": 12,
		"desc": "剑锋先试探左肩，再踏入中门，连追三式；若气息未稳，最后一剑将由下方挑起。"}
	slip.set_intent(2, long_intent)
	await process_frame
	if not _text_fits(slip) or slip.size.y > 120.0:
		_fail("Long reusable intent does not fit within the controlled paper height")
		return
	var drop: Control = slip.get("_drop_layer")
	if drop.position.y >= -0.5:
		_fail("Changed intent did not descend from above")
		return
	await create_timer(0.65).timeout
	if absf(drop.position.y) > 0.1 or absf(drop.rotation) > 0.01:
		_fail("The paper did not settle after its update")
		return
	var breeze: Control = slip.get("_breeze_layer")
	var prior := breeze.position
	await create_timer(0.25).timeout
	if breeze.position.distance_to(prior) < 0.04 or breeze.position.length() > 1.5:
		_fail("The idle breeze is absent or too strong")
		return
	print("BATTLE_INTENT_SLIP_UI_PASS source_states=", plans.size(),
		" revision=", slip.intent_revision, " height=", slip.size.y,
		" wind_delta=", breeze.position.distance_to(prior))
	quit(0)


func _text_fits(slip: Control) -> bool:
	var description: Label = slip.description_label
	var phase: Label = slip.phase_label
	var value: Label = slip.value_label
	var font: Font = phase.get_theme_font("font")
	return description.get_line_count() == description.get_visible_line_count() \
		and description.position.y + description.size.y <= slip.size.y - 5.0 \
		and font.get_string_size(phase.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= phase.size.x \
		and font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= value.size.x


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
