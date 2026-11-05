extends SceneTree

## 屏幕震动验收（S5）。headless 纯数值，直接驱动 _step(delta)，
## 不依赖引擎帧循环，也不依赖 3D 相机。
##
## 覆盖：分级单调 / 加性与 clamp / 幅度上限 / 衰减归零 / 未知档位不生效 /
## 读 offset 不改变状态。

const CameraShakeScript = preload("res://scripts/combat_fx/camera_shake.gd")
const STEP := 1.0 / 60.0
const TIERS := ["light", "medium", "heavy", "crit"]

var _fails: Array[String] = []


func _initialize() -> void:
	_check_tier_monotonic()
	_check_trigger_sets_trauma()
	_check_additive_clamped()
	_check_amplitude_bound()
	_check_decay_to_zero()
	_check_unknown_tier()
	_check_read_does_not_advance()
	if _fails.is_empty():
		print("COMBAT_CAMERA_SHAKE_PASS tiers=%d decay=%s"
			% [TIERS.size(), str(camera_decay())])
		quit(0)
		return
	for f in _fails:
		printerr("COMBAT_CAMERA_SHAKE_FAIL " + f)
	quit(1)


func camera_decay() -> float:
	return float(CameraShakeScript.DECAY_PER_SEC)


func _check(message: String, condition: bool) -> void:
	if not condition:
		_fails.append(message)


func _check_tier_monotonic() -> void:
	var values: Array[float] = []
	for tier in TIERS:
		values.append(CameraShakeScript.tier_trauma(tier))
	for i in range(1, values.size()):
		_check("%s 的 trauma 应大于 %s" % [TIERS[i], TIERS[i - 1]],
			values[i] > values[i - 1])
	_check("crit trauma 应 > 0 且 <= 1", values[-1] > 0.0 and values[-1] <= 1.0)


func _check_trigger_sets_trauma() -> void:
	for tier in TIERS:
		var shake: Node = CameraShakeScript.new()
		shake.trigger(tier)
		_check("trigger(%s) 后 trauma 应等于配置值" % tier,
			is_equal_approx(shake.trauma(), CameraShakeScript.tier_trauma(tier)))
		_check("trigger(%s) 后应处于激活态" % tier, shake.is_active())
		shake.free()


func _check_additive_clamped() -> void:
	var shake: Node = CameraShakeScript.new()
	shake.trigger("crit")
	shake.trigger("crit")
	_check("连续 crit 的 trauma 不应超过 1.0", shake.trauma() <= 1.0)
	_check("连续 crit 应比单次更强（加性）",
		shake.trauma() > CameraShakeScript.tier_trauma("crit"))
	shake.free()


func _check_amplitude_bound() -> void:
	for tier in TIERS:
		var shake: Node = CameraShakeScript.new()
		shake.trigger(tier)
		var max_off: Vector2 = shake.max_offset
		var peak := Vector2.ZERO
		for _i in 120:
			var offset: Vector2 = shake._step(STEP)
			if absf(offset.x) > absf(peak.x):
				peak.x = offset.x
			if absf(offset.y) > absf(peak.y):
				peak.y = offset.y
		_check("%s 的 x 位移超出 max_offset" % tier,
			absf(peak.x) <= max_off.x + 0.001)
		_check("%s 的 y 位移超出 max_offset" % tier,
			absf(peak.y) <= max_off.y + 0.001)
		shake.free()
	# crit 满 trauma 时 x 峰值占屏高比例必须 <= 1.2%
	var probe: Node = CameraShakeScript.new()
	var max_x: float = (probe.max_offset as Vector2).x
	probe.free()
	_check("crit 峰值 %.2fpx 超过屏高 1.2%%（800px 的 1.2%% = 9.6px）" % max_x,
		max_x <= 9.6)


func _check_decay_to_zero() -> void:
	var shake: Node = CameraShakeScript.new()
	shake.trigger("crit")
	var frames := 0
	var last := Vector2.ZERO
	while shake.is_active() and frames < 600:
		last = shake._step(STEP)
		frames += 1
	_check("crit 应在 600 帧内衰减完，实际 %d 帧" % frames, frames < 600)
	_check("衰减结束后 offset 应精确为零",
		last == Vector2.ZERO and shake._step(STEP) == Vector2.ZERO)
	_check("衰减结束后 is_active 应为 false", not shake.is_active())
	shake.free()


func _check_unknown_tier() -> void:
	var shake: Node = CameraShakeScript.new()
	shake.trigger("nonexistent")
	_check("未知档位不应改变 trauma", shake.trauma() == 0.0)
	_check("未知档位不应激活", not shake.is_active())
	shake.free()


func _check_read_does_not_advance() -> void:
	var shake: Node = CameraShakeScript.new()
	shake.trigger("heavy")
	var before: float = shake.trauma()
	shake.offset()
	shake.offset()
	_check("读 offset 不应推进 trauma", is_equal_approx(shake.trauma(), before))
	shake.cancel()
	_check("cancel 后 trauma 归零", shake.trauma() == 0.0)
	shake.free()
