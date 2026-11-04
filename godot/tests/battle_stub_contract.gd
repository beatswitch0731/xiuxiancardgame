extends SceneTree

## 战斗桩契约测试。
## 验证 BattleStub 产出的 result 形状与 main.gd:terminal_result() 一致，
## 且满足 noncombat_battle_gateway.validate_result() 的字段要求。
## 不构造完整 state（那需要一局真实存档），只锁形状与守卫逻辑。

const StubScript = preload("res://scripts/battle_stub.gd")

const _STUB_FIELDS := ["contractVersion", "encounterInstanceId", "sourceCardId",
	"encounterId", "sourceContentHash", "outcome", "combatReceipt", "postBattleState"]
const _POST_FIELDS := ["encounterInstanceId", "terminal", "combatPhase",
	"playerHp", "enemyHp", "turn"]


func _initialize() -> void:
	var failures: Array[String] = []
	_check_victory(failures)
	_check_defeat(failures)
	_check_flee_guard(failures)
	_check_rejects_bad_request(failures)
	if failures.is_empty():
		print("BATTLE_STUB_CONTRACT_PASS")
		quit(0)
		return
	for line in failures:
		printerr(line)
	quit(1)


func _make_stub(outcome: String = "", flee_allowed: bool = true) -> Control:
	StubScript.forced_outcome = outcome
	var stub: Control = StubScript.new()
	stub.battle_request = {
		"contractVersion": 2,
		"encounterInstanceId": "enc_instance_1",
		"sourceCardId": "ch_qi_100",
		"encounterId": "enc_trial_sword_swift",
		"sourceContentHash": "sha256:abc",
	}
	stub.flee_allowed = flee_allowed
	return stub


func _check_shape(result: Dictionary, label: String, failures: Array[String]) -> void:
	for field in _STUB_FIELDS:
		if not result.has(field):
			failures.append("%s: 缺少字段 %s" % [label, field])
	if not result.get("postBattleState") is Dictionary:
		failures.append("%s: postBattleState 不是 Dictionary" % label)
		return
	var post: Dictionary = result["postBattleState"]
	for field in _POST_FIELDS:
		if not post.has(field):
			failures.append("%s: postBattleState 缺少字段 %s" % [label, field])
	if post.get("terminal") != true:
		failures.append("%s: terminal 必须为 true" % label)


func _check_victory(failures: Array[String]) -> void:
	var stub := _make_stub()
	var result: Dictionary = stub.terminal_result()
	_check_shape(result, "victory", failures)
	if result.get("outcome") != "victory":
		failures.append("victory: outcome 应为 victory")
	if result.get("combatReceipt") != "combat:enc_instance_1":
		failures.append("victory: combatReceipt 格式不符")
	if result.get("postBattleState", {}).get("combatPhase") != "VICTORY":
		failures.append("victory: combatPhase 应为 VICTORY")
	if result.get("contractVersion") != 2:
		failures.append("victory: contractVersion 应取自 request")
	if result.get("encounterId") != "enc_trial_sword_swift":
		failures.append("victory: encounterId 应取自 request")
	stub.free()


func _check_defeat(failures: Array[String]) -> void:
	var stub := _make_stub("defeat")
	var result: Dictionary = stub.terminal_result()
	_check_shape(result, "defeat", failures)
	if result.get("outcome") != "defeat":
		failures.append("defeat: outcome 应为 defeat")
	if result.get("postBattleState", {}).get("combatPhase") != "DEFEAT":
		failures.append("defeat: combatPhase 应为 DEFEAT")
	stub.free()


func _check_flee_guard(failures: Array[String]) -> void:
	var allowed := _make_stub("flee", true)
	var allowed_result: Dictionary = allowed.terminal_result()
	if allowed_result.get("outcome") != "flee":
		failures.append("flee: 允许撤离时应产出 flee")
	if allowed_result.get("postBattleState", {}).get("combatPhase") != "FLEE":
		failures.append("flee: combatPhase 应为 FLEE")
	allowed.free()
	# fleeAllowed=false 时不得产出 flee，否则 gateway 会以 FLEE_FORBIDDEN 拒绝。
	var blocked := _make_stub("flee", false)
	var blocked_result: Dictionary = blocked.terminal_result()
	if blocked_result.get("outcome") == "flee":
		failures.append("flee guard: 禁止撤离时不应产出 flee")
	blocked.free()


func _check_rejects_bad_request(failures: Array[String]) -> void:
	var empty_stub: Control = StubScript.new()
	if not empty_stub.terminal_result().is_empty():
		failures.append("空 battle_request 应返回空字典")
	empty_stub.free()
	var bad_version := _make_stub()
	bad_version.battle_request["contractVersion"] = "2"
	if not bad_version.terminal_result().is_empty():
		failures.append("contractVersion 非整数时应返回空字典")
	bad_version.free()
	var no_owner := _make_stub()
	no_owner.battle_request["encounterInstanceId"] = ""
	if not no_owner.terminal_result().is_empty():
		failures.append("encounterInstanceId 为空时应返回空字典")
	no_owner.free()
