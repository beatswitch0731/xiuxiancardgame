extends SceneTree

var demo: Control
var frame := 0

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	demo = load("res://scenes/actor_wearable_demo.tscn").instantiate()
	root.add_child(demo)
	process_frame.connect(_advance)

func _advance() -> void:
	frame += 1
	match frame:
		45: demo.sword_button.pressed.emit()
		80: demo.armor_button.pressed.emit()
		110: demo.attack()
		175: demo.toggle_close_view()
		200: demo.attack()
		260: demo.armor_button.pressed.emit()
		290: demo.attack()
		350: demo.sword_button.pressed.emit()
		400: quit()
