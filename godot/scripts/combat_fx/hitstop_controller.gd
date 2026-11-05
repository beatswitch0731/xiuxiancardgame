class_name HitStopController
extends Node

## 打击停顿（hit-stop）的唯一拥有者（VFX 方案批次 V1 / §3.5）。
## 通道所有权铁律：全项目只有本节点可以写 Engine.time_scale。
##
## 用法（宿主在命中结算处调用一次）：
##   add_child(HitStopController.new())  # 每个战斗场景挂一个
##   hitstop.trigger("heavy")
##
## 设计要点（业界参数，60fps 口径）：
##   轻击 2~4 帧 / 中击 3~5 帧 / 重击 6~10 帧 / 暴击格挡 8~15 帧
##   time_scale 不设 0，压到 0.05 让粒子系统继续走（视觉不断电）。

signal hitstop_started(tier: String, frames: int)
signal hitstop_ended(tier: String)

const SCALE := 0.05
## 60fps 口径的停顿帧数；帧数 = 停顿秒数 × 60。
const TIERS := {
	"light": {"frames": 3, "scale": 0.08},
	"medium": {"frames": 5, "scale": 0.06},
	"heavy": {"frames": 8, "scale": 0.05},
	"crit": {"frames": 12, "scale": 0.05},
}

var _remaining_frames: int = 0
var _active_tier: String = ""
var _enabled: bool = true


func _exit_tree() -> void:
	# 节点被移除时必须恢复全局时间，否则整个引擎留在慢动作里。
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


## 按伤害分级触发一次停顿。重复触发会重置为新的分级（不叠加）。
func trigger(tier: String) -> void:
	if not _enabled:
		return
	if not TIERS.has(tier):
		push_warning("[HitStop] unknown tier: " + tier)
		return
	var cfg: Dictionary = TIERS[tier]
	_active_tier = tier
	_remaining_frames = int(cfg["frames"])
	Engine.time_scale = float(cfg["scale"])
	hitstop_started.emit(tier, _remaining_frames)


func _process(_delta: float) -> void:
	if _remaining_frames <= 0:
		return
	# 计数按真实时间走：time_scale 被压低时 _process 的 delta 也变小，
	# 所以用"真实帧"计数（引擎每渲染一帧算一帧）。
	_remaining_frames -= 1
	if _remaining_frames <= 0:
		Engine.time_scale = 1.0
		hitstop_ended.emit(_active_tier)
		_active_tier = ""


## 调试/安全阀：立即结束当前停顿。
func cancel() -> void:
	_remaining_frames = 0
	Engine.time_scale = 1.0


func is_active() -> bool:
	return _remaining_frames > 0


func active_tier() -> String:
	return _active_tier


## 分级映射的静态查询（测试与 UI 预览用）。
static func tier_frames(tier: String) -> int:
	return int(TIERS.get(tier, {}).get("frames", 0))
