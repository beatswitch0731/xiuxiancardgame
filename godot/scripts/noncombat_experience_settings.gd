extends RefCounted

const DEFAULTS := {
	"effects": "high",
	"steadyCamera": false,
	"highContrast": false,
	"readableFont": false,
	"textScale": "normal",
}

var settings: Dictionary = DEFAULTS.duplicate(true)
var _path := ""


func _init(path: String) -> void:
	_path = path
	var saved := ConfigFile.new()
	if saved.load(_path) != OK:
		return
	for key in DEFAULTS:
		set_option(key, saved.get_value("experience", key, DEFAULTS[key]), false)


func get_option(key: String) -> Variant:
	return settings.get(key, DEFAULTS.get(key))


func set_option(key: String, value: Variant, persist := true) -> bool:
	if not DEFAULTS.has(key):
		return false
	if key == "effects":
		if value not in ["low", "balanced", "high"]:
			return false
	elif key == "textScale":
		if value not in ["small", "normal", "large"]:
			return false
	elif not value is bool:
		return false
	settings[key] = value
	if persist:
		_save()
	return true


func reset() -> void:
	settings = DEFAULTS.duplicate(true)
	_save()


func text_multiplier() -> float:
	return {"small": 0.92, "normal": 1.0, "large": 1.14}[settings.textScale]


func _save() -> void:
	var file := ConfigFile.new()
	for key in DEFAULTS:
		file.set_value("experience", key, settings[key])
	file.save(_path)
