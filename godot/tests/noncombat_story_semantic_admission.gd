extends SceneTree

const Policy = preload("res://scripts/noncombat_normal_draw_policy.gd")
const WorldContinuity = preload("res://scripts/noncombat_world_continuity.gd")
const FIXTURE := "res://tests/fixtures/normal_draw_decision27.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:
		return _fail("normal draw fixture absent")
	var policy := Policy.new()
	var state: Dictionary = fixture.state.duplicate(true)
	state["realm"] = "foundation"
	state["flags"] = {"bai_luoxuan_met": true}
	state["cardsPlayed"] = []
	var soup: Dictionary = policy.source_card(state, "sd_fd_bai_luo_soup")
	if soup.is_empty() or not policy.eligible(soup, state, []):
		return _fail("living fox first meeting was blocked")
	var registered: Dictionary = state.duplicate(true)
	registered.worldContinuityState = WorldContinuity.initial(policy._content, 0).get("state", {})
	if not policy.eligible(soup, registered, []):
		return _fail("registered current-life fox was blocked")
	var absent: Dictionary = registered.duplicate(true)
	absent.worldContinuityState.npcs.erase("bai_luoxuan")
	if policy.eligible(soup, absent, []):
		return _fail("unregistered fox received a physical dialogue")
	var old_life: Dictionary = registered.duplicate(true)
	old_life.lifeCount = 1
	if policy.eligible(soup, old_life, []):
		return _fail("prior-life fox received a physical dialogue")
	var dead: Dictionary = state.duplicate(true)
	dead["worldContinuityState"] = {"npcs": {"bai_luoxuan": {
		"lifecycle": "DEAD", "manifestation": "ECHO_ONLY"}}}
	if policy.eligible(soup, dead, []):
		return _fail("dead fox received a physical dialogue")
	var stage_done: Dictionary = state.duplicate(true)
	stage_done["cardsPlayed"] = ["arc_bai_luoxuan_stage_ACQUAINTANCE"]
	if policy.eligible(soup, stage_done, []):
		return _fail("duplicate semantic first meeting was admitted")
	var nascent: Dictionary = state.duplicate(true)
	nascent["realm"] = "nascent"
	var trust: Dictionary = policy.source_card(nascent, "sd_nd_luoxuan_trust")
	if trust.is_empty() or policy.eligible(trust, nascent, []):
		return _fail("unresolved first meeting did not gate later trust")
	nascent["cardsPlayed"] = ["sd_fd_bai_luo_soup"]
	if not policy.eligible(trust, nascent, []):
		return _fail("authored first meeting did not unlock later trust")
	nascent["cardsPlayed"] = ["arc_bai_luoxuan_stage_ACQUAINTANCE"]
	if not policy.eligible(trust, nascent, []):
		return _fail("arc first meeting did not unlock later trust")
	var repeatable: Dictionary = policy.source_card(state, "atm_qi_tea_rumor")
	var recent: Dictionary = state.duplicate(true)
	recent["runClock"] = {"decisionIndex": 27}
	recent["replayHistory"] = [{"cardId": "atm_qi_tea_rumor", "decisionIndex": 20}]
	if repeatable.is_empty() or policy.eligible(repeatable, recent, []):
		return _fail("narrative cooldown ignored a recent resolved card")
	recent["replayHistory"][0]["decisionIndex"] = 14
	if not policy.eligible(repeatable, recent, []):
		return _fail("expired narrative cooldown still blocked the card")
	print("NONCOMBAT_STORY_SEMANTIC_ADMISSION_PASS death=true once=true prerequisite=true cooldown=true")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
