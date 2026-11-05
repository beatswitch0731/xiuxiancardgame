extends SceneTree

## 受击闪白曲线验收（S6）。headless 纯数值，直接验 duel_stage_hd2d.hit_tint()。
##
## 曲线设计：0~0.05s 过曝白 → 0.05~0.13s 线性衰减到偏红 → 0.13~0.16s 保持红
## → 0.16s 起归白。测试断言各段端点，并验证"纯红段不被 fade 吞掉"这个曾经的
## 设计缺陷（FADE 过长会让 RED 段变成死分支）。

const StageScript = preload("res://scripts/duel_stage_hd2d.gd")
const FLASH_SEC := 0.05
const FADE_SEC := 0.07
const TOTAL_SEC := 0.16

var _fails: Array[String] = []


func _initialize() -> void:
	_check_constants()
	_check_flash_segment()
	_check_fade_segment()
	_check_red_hold_segment()
	_check_white_after()
	if _fails.is_empty():
		print("DUEL_HIT_TINT_PASS flash=%.3f fade=%.3f total=%.3f"
			% [FLASH_SEC, FADE_SEC, TOTAL_SEC])
		quit(0)
		return
	for f in _fails:
		printerr("DUEL_HIT_TINT_FAIL " + f)
	quit(1)


func _check(message: String, condition: bool) -> void:
	if not condition:
		_fails.append(message)


func _tint(t: float) -> Color:
	return StageScript.hit_tint(t)


func _check_constants() -> void:
	_check("常量与测试假设不一致",
		is_equal_approx(StageScript.HIT_TINT_FLASH_SEC, FLASH_SEC)
		and is_equal_approx(StageScript.HIT_TINT_FADE_SEC, FADE_SEC)
		and is_equal_approx(StageScript.HIT_TINT_TOTAL_SEC, TOTAL_SEC))
	# 纯红段必须存在：fade 结束必须早于 total
	_check("FADE 过长会把纯红段变成死分支（flash+fade 必须 < total）",
		FLASH_SEC + FADE_SEC < TOTAL_SEC)


func _check_flash_segment() -> void:
	_check("t<0 应为白色", _tint(-0.01) == Color.WHITE)
	_check("t=0 应为过曝白", _tint(0.0) == StageScript.HIT_TINT_FLASH)
	_check("t=0.049 仍应为过曝白",
		_tint(FLASH_SEC - 0.001) == StageScript.HIT_TINT_FLASH)
	_check("过曝白分量应 >1（这是闪烁的物理来源）",
		StageScript.HIT_TINT_FLASH.r > 1.0)


func _check_fade_segment() -> void:
	var start := _tint(FLASH_SEC)
	_check("fade 起点应接近过曝白", start.is_equal_approx(StageScript.HIT_TINT_FLASH))
	var mid := _tint(FLASH_SEC + FADE_SEC * 0.5)
	_check("fade 中点应介于白与红之间",
		mid.r < StageScript.HIT_TINT_FLASH.r and mid.g > StageScript.HIT_TINT_RED.g)
	var end := _tint(FLASH_SEC + FADE_SEC)
	_check("fade 终点应接近红", end.is_equal_approx(StageScript.HIT_TINT_RED))


func _check_red_hold_segment() -> void:
	var hold_start := FLASH_SEC + FADE_SEC
	var hold_end := TOTAL_SEC - 0.001
	_check("纯红段起点应为红", _tint(hold_start).is_equal_approx(StageScript.HIT_TINT_RED))
	_check("纯红段中点应为红", _tint((hold_start + hold_end) * 0.5)
		.is_equal_approx(StageScript.HIT_TINT_RED))
	_check("纯红段末点应为红", _tint(hold_end)
		.is_equal_approx(StageScript.HIT_TINT_RED))
	_check("纯红段时长应至少 2 帧（33ms）",
		TOTAL_SEC - (FLASH_SEC + FADE_SEC) >= 0.033)


func _check_white_after() -> void:
	_check("t=total 应回归白色", _tint(TOTAL_SEC) == Color.WHITE)
	_check("t=1.0 应保持白色", _tint(1.0) == Color.WHITE)
