class_name CameraShake
extends Node

## 屏幕震动（S5，打击感五件套第五层）。
##
## 通道所有权：本节点只产出 offset，不碰任何相机；Engine.time_scale 归
## HitStopController。相机应用由宿主负责（duel_stage_hd2d.pulse_camera）。
##
## 模型：trauma ∈ [0,1]，幅度 = trauma²（二次衰减比线性更"脆"），
## trauma 每秒按 DECAY_PER_SEC 线性回落。用确定性正弦叠加而非随机数，
## 这样同一个 seed/时序下可复现，测试与截图对比才有意义。

signal shake_started(tier: String)

## tier → 初始 trauma。与 HitStopController 的分级同一套（light/medium/heavy/crit）。
const TIER_TRAUMA := {
	"light": 0.18,
	"medium": 0.32,
	"heavy": 0.55,
	"crit": 0.80,
}
const DECAY_PER_SEC := 1.4
## 两个不成整数比的正弦频率叠加，避免震动呈现明显规律。
const FREQ_X := 21.0
const FREQ_Y := 28.7
const FREQ_MIX := 37.3

## 最大位移（像素）。crit 满 trauma 时 x=9.0px，屏高 800 的 1.125%，
## 保持在 1.2% 以内以防画面穿帮。
var max_offset := Vector2(9.0, 6.0)

var _trauma: float = 0.0
var _time: float = 0.0


func trigger(tier: String) -> void:
	if not TIER_TRAUMA.has(tier):
		push_warning("[CameraShake] unknown tier: " + tier)
		return
	# 加性但 clamp 到 1.0：连续重击会更强，但不会无限累积成癫痫
	_trauma = minf(1.0, _trauma + float(TIER_TRAUMA[tier]))
	shake_started.emit(tier)


## 单步推进并返回本帧位移。
##
## 刻意不实现 _process：本节点是被动组件，由宿主每帧调一次 _step(delta)。
## 若自己也跑 _process，会与宿主形成双驱动，trauma 衰减速度翻倍且时序不定。
func _step(delta: float) -> Vector2:
	if _trauma <= 0.0:
		return Vector2.ZERO
	_trauma = maxf(0.0, _trauma - DECAY_PER_SEC * delta)
	if _trauma <= 0.0:
		_time = 0.0
		return Vector2.ZERO
	_time += delta
	var amplitude := _trauma * _trauma
	var x := (sin(_time * FREQ_X) + 0.35 * sin(_time * FREQ_MIX)) / 1.35
	var y := cos(_time * FREQ_Y) * 0.85
	return Vector2(x * max_offset.x * amplitude, y * max_offset.y * amplitude)


func offset() -> Vector2:
	return _step(0.0)


func trauma() -> float:
	return _trauma


func is_active() -> bool:
	return _trauma > 0.0


func cancel() -> void:
	_trauma = 0.0
	_time = 0.0


## 分级初始 trauma 的静态查询（测试与调试用）。
static func tier_trauma(tier: String) -> float:
	return float(TIER_TRAUMA.get(tier, 0.0))
