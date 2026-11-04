class_name BattleStub
extends Control

## Noncombat Battle Stub
## ---------------------------------------------------------------------
## Lets the noncombat flow be verified end-to-end while the real combat
## system is deliberately deferred. It emits a result that must pass
## noncombat_battle_gateway.validate_result() -- the same contract the real
## duel_stage_* scenes emit -- and nothing else.
##
## It never plays presentation, never loads a combat scene and never touches
## a combat rule. Enable through BATTLE_STUB_MODE in noncombat_opening_ui.gd;
## production runtime must keep that flag false.
##
## Contract fields below are assigned by noncombat_opening_ui._launch_battle()
## before add_child(), so they must stay plain public vars.

signal battle_finished(result: Dictionary)

## Test hook: "victory" | "defeat" | "flee". Empty means victory.
static var forced_outcome: String = ""

var battle_request: Dictionary = {}
var battle_plan: Dictionary = {}
var flee_allowed: bool = true
var browser_combat_snapshot: Dictionary = {}
var browser_combat_authority: Dictionary = {}
var browser_combat_actions: Array = []
var browser_combat_commit_card: Callable = Callable()
var browser_combat_commit_end_turn: Callable = Callable()
var browser_combat_commit_reaction: Callable = Callable()

var status_message: String = ""

const _PHASE := {"victory": "VICTORY", "defeat": "DEFEAT", "flee": "FLEE"}


func _ready() -> void:
	# Deferred so add_child() and the caller's signal connection both finish
	# before the result is emitted.
	call_deferred("_finish")


func _finish() -> void:
	var result := terminal_result()
	if result.is_empty():
		push_error("[BATTLE_STUB] cannot build a result: battle_request missing or off-contract")
		return
	battle_finished.emit(result)


## Mirrors main.gd:terminal_result() field for field, so the gateway accepts a
## stub result exactly as it accepts a real battle result.
func terminal_result() -> Dictionary:
	if battle_request.is_empty():
		return {}
	var request_contract: Variant = battle_request.get("contractVersion")
	if not request_contract is int:
		return {}
	var owner := String(battle_request.get("encounterInstanceId", ""))
	if owner.is_empty():
		return {}
	var outcome := "victory"
	if _PHASE.has(forced_outcome):
		outcome = forced_outcome
	if outcome == "flee" and not flee_allowed:
		outcome = "victory"
	return {
		"contractVersion": request_contract,
		"encounterInstanceId": owner,
		"sourceCardId": String(battle_request.get("sourceCardId", "")),
		"encounterId": String(battle_request.get("encounterId", "")),
		"sourceContentHash": String(battle_request.get("sourceContentHash", "")),
		"outcome": outcome,
		"combatReceipt": "combat:" + owner,
		"postBattleState": {
			"encounterInstanceId": owner,
			"terminal": true,
			"combatPhase": _PHASE[outcome],
			"playerHp": 1 if outcome == "victory" else 0,
			"enemyHp": 0 if outcome == "victory" else 1,
			"turn": 1,
		},
	}


## Called by noncombat_opening_ui._on_battle_finished() when settlement is
## rejected. Kept for interface parity with the real stage scenes.
func _set_state_message(message: String) -> void:
	status_message = message
	push_warning("[BATTLE_STUB] " + message)
