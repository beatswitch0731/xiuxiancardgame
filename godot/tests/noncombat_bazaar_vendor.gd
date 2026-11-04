extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const RunSession = preload("res://scripts/noncombat_run_session.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://tests/bazaar_vendor_%d.json" % Time.get_ticks_usec()
	var store = RunSession.new(path, "slot_3")
	var game = Domain.new(Registry.new(), store, "slot_3")
	game._market_flow.roll_override = 0.0
	game._destiny_wheel_flow.roll_override = 0.0
	if not game.start("sword") or not _reach_bazaar(game):
		return _fail("real source route did not reach bazaar")
	var before: Dictionary = game.state.duplicate(true)
	var before_bytes := FileAccess.get_file_as_string(store.v2_path)
	var token: int = game.issue_choice_token()
	game.state["marketActionHistory"] = [{"sessionKey":
		"vendor:forged:1:bazaar_encounter:public_bazaar", "actionId": "assist_han"}]
	game.state["marketState"]["vendorRelations"] = {"han_peddler": 1}
	if game.choose("left", token) or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("forged past visit gained a source price discount")
	game.state = before.duplicate(true)
	store.fail_promotion_once = true
	if game.choose("left", token) or not _same(game.state, before) \
			or FileAccess.get_file_as_string(store.v2_path) != before_bytes:
		return _fail("failed vendor open changed state or save")
	if not game.choose("left", token) or game.state.get("phase") != "VENDOR_OPEN" \
			or game.state.get("runClock", {}).get("decisionIndex") != 21 \
			or game.state.get("choiceHistory", []).size() != before.get("choiceHistory", []).size():
		return _fail("left did not open a no-clock vendor session")
	var session: Dictionary = game.state.get("marketState", {}).get("activeSession", {})
	if session.get("status") != "open" or session.get("marketType") != "public_bazaar" \
			or session.get("stalls", []).size() != 3 \
			or session.get("immutableOffers", []).size() != 4 \
			or session.get("interactionBudget", {}).get("remaining") != 2:
		return _fail("source vendor stock/stalls/budget not frozen")
	var opened: Dictionary = game.state.duplicate(true)
	var authentic_bytes := FileAccess.get_file_as_string(store.v2_path)
	game.state["marketState"]["activeSession"]["stalls"][0]["action"]["relationDelta"] = 100
	if game.perform_vendor_action("assist_han", game.issue_choice_token()) \
			or FileAccess.get_file_as_string(store.v2_path) != authentic_bytes:
		return _fail("mutated live vendor action bypassed source authority")
	game.state["marketState"]["activeSession"]["stalls"][0]["action"]["relationDelta"] = 1
	game.state["marketState"]["activeSession"]["immutableOffers"][0]["name"] = "假货"
	if game.close_vendor(game.issue_choice_token()) \
			or FileAccess.get_file_as_string(store.v2_path) != authentic_bytes:
		return _fail("mutated live offer bypassed close source authority")
	var reopened = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	reopened._market_flow.roll_override = 0.0
	reopened._destiny_wheel_flow.roll_override = 0.0
	if not reopened.restore() or not _same(reopened.state, opened):
		return _fail("open vendor session did not strictly replay")
	var action_token: int = reopened.issue_choice_token()
	var action_bytes := FileAccess.get_file_as_string(store.v2_path)
	reopened._store.fail_promotion_once = true
	if reopened.perform_vendor_action("assist_han", action_token) \
			or not _same(reopened.state, opened) \
			or FileAccess.get_file_as_string(store.v2_path) != action_bytes:
		return _fail("failed vendor interaction changed state or save")
	if not reopened.perform_vendor_action("assist_han", action_token) \
			or reopened.perform_vendor_action("assist_han", reopened.issue_choice_token()):
		return _fail("assist_han action failed or repeated")
	var interacted: Dictionary = reopened.state.duplicate(true)
	if interacted.get("marketState", {}).get("vendorRelations", {}).get("han_peddler") != 1 \
			or interacted.get("marketState", {}).get("activeSession", {}).get(
				"interactionBudget", {}).get("remaining") != 1 \
			or interacted.get("runClock", {}).get("decisionIndex") != 21:
		return _fail("assist_han relation/budget/clock differs")
	var replay_action = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_action._market_flow.roll_override = 0.0
	replay_action._destiny_wheel_flow.roll_override = 0.0
	if not replay_action.restore() or not _same(replay_action.state, interacted):
		return _fail("vendor action did not strictly replay")
	var close_token: int = replay_action.issue_choice_token()
	var close_bytes := FileAccess.get_file_as_string(store.v2_path)
	replay_action._store.fail_promotion_once = true
	if replay_action.close_vendor(close_token) or not _same(replay_action.state, interacted) \
			or FileAccess.get_file_as_string(store.v2_path) != close_bytes:
		return _fail("failed vendor close changed state or save")
	if not replay_action.close_vendor(close_token) \
			or replay_action.state.get("phase") != "VENDOR_RESULT_PENDING" \
			or replay_action.state.get("runClock", {}).get("decisionIndex") != 22 \
			or replay_action.get_current_card().get("title") != "集市 · 摊主记名":
		return _fail("vendor close did not settle one decision and result")
	var visit: Dictionary = replay_action.state.get("marketState", {}).get("visitHistory", []).back()
	if visit.get("outcome") != "interacted" or not visit.get("refused") \
			or visit.get("missedOffers", []).size() != 4:
		return _fail("vendor visit receipt differs")
	var closed: Dictionary = replay_action.state.duplicate(true)
	var replay_closed = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_closed._market_flow.roll_override = 0.0
	replay_closed._destiny_wheel_flow.roll_override = 0.0
	if not replay_closed.restore() or not _same(replay_closed.state, closed):
		return _fail("closed vendor result did not strictly replay")
	if not replay_closed.choose("right", replay_closed.issue_choice_token()) \
			or replay_closed.state.get("runClock", {}).get("decisionIndex") != 22 \
			or replay_closed.state.get("marketState", {}).get("activeSession") != null:
		return _fail("result dismissal did not preserve decision clock")
	var dismissed: Dictionary = replay_closed.state.duplicate(true)
	var replay_dismissed = Domain.new(Registry.new(), RunSession.new(path, "slot_3"), "slot_3")
	replay_dismissed._market_flow.roll_override = 0.0
	replay_dismissed._destiny_wheel_flow.roll_override = 0.0
	if not replay_dismissed.restore() or not _same(replay_dismissed.state, dismissed):
		return _fail("dismissed vendor result did not strictly replay")
	# A source-card projection checks that a legitimate remembered favor still
	# affects the next stock. The next actual market visit is beyond this route.
	var later: Dictionary = dismissed.duplicate(true)
	later["phase"] = "MARKET_PENDING"
	later["currentCardId"] = "bazaar_encounter"
	later["runClock"]["decisionIndex"] = 23
	later["turn"] = 23
	later["pendingMarketChoiceCard"] = replay_dismissed._market_flow._bazaar_card(
		"洞府", "qi")
	var remembered: Dictionary = replay_dismissed._vendor_flow.open(later)
	var remembered_session: Dictionary = remembered.get("marketState", {}).get(
		"activeSession", {})
	if remembered_session.get("immutableOffers", []).size() != 5 \
			or remembered_session.get("immutableOffers", [])[0].get("price") != 3 \
			or remembered_session.get("stalls", [])[0].get("relation") != 1:
		return _fail("legitimate remembered vendor favor did not affect next stock")
	var long_market: Dictionary = before.duplicate(true)
	long_market["turn"] = 48
	long_market["runClock"]["decisionIndex"] = 48
	long_market["marketState"]["vendorRelations"] = {"han_peddler": 48}
	long_market["marketActionHistory"] = []
	for decision in range(1, 49):
		var prior_key := "vendor:%s:%d:bazaar_encounter:public_bazaar" % [
			long_market["runClock"]["lifeId"], decision]
		long_market["marketState"]["visitHistory"].append({"sessionKey": prior_key,
			"vendorId": "public_bazaar", "marketType": "public_bazaar",
			"decisionIndex": decision, "seen": true, "outcome": "interacted"})
		long_market["marketActionHistory"].append({"sessionKey": prior_key,
			"actionId": "assist_han"})
	var long_open: Dictionary = replay_dismissed._vendor_flow.open(long_market)
	var long_interact: Dictionary = replay_dismissed._vendor_flow.interact(long_open,
		"assist_han")
	var long_closed: Dictionary = replay_dismissed._vendor_flow.close(long_interact)
	if long_closed.is_empty():
		return _fail("49th legitimate market visit failed before pruning")
	long_closed["phase"] = "MARKET_PENDING"
	long_closed["currentCardId"] = "bazaar_encounter"
	long_closed["marketState"]["activeSession"] = null
	long_closed["pendingMarketChoiceCard"] = replay_dismissed._market_flow._bazaar_card(
		"洞府", "qi")
	if replay_dismissed._vendor_flow.open(long_closed).is_empty():
		return _fail("49th visit pruning invalidated legitimate next vendor")
	var empty = Domain.new(Registry.new(), null, "slot_1")
	empty._market_flow.roll_override = 0.0
	empty._destiny_wheel_flow.roll_override = 0.0
	if not empty.start("sword") or not _reach_bazaar(empty) \
			or not empty.choose("left", empty.issue_choice_token()) \
			or not empty.close_vendor(empty.issue_choice_token()) \
			or empty.get_current_card().get("description") != \
				"三处摊位各有来路。你没有出手，也未留下新的口信；错过了 行脚回春散、旧商路札记、集市易手残剑 等线索。" \
			or empty.state.get("marketState", {}).get("visitHistory", []).back().get(
				"outcome") != "declined":
		return _fail("empty vendor close differs from browser")
	var scene_resource = load("res://scenes/noncombat_opening.tscn")
	var ui: Control = scene_resource.instantiate()
	ui.save_path = ""
	var audio_settings := "user://tests/bazaar_vendor_audio_%d.cfg" % Time.get_ticks_usec()
	ui.audio_settings_path = audio_settings
	root.add_child(ui)
	await process_frame
	ui.opening._market_flow.roll_override = 0.0
	ui.opening._destiny_wheel_flow.roll_override = 0.0
	if not ui.opening.start("sword") or not _reach_bazaar(ui.opening) \
			or not ui.opening.choose("left", ui.opening.issue_choice_token()):
		return _fail("desktop vendor route did not open")
	await process_frame
	var row: HBoxContainer = ui.get_node("DesktopMargin/ScreenStack/StoryScreen/SourceChoices")
	var vendor_art: TextureRect = ui.get_node(
		"DesktopMargin/ScreenStack/StoryScreen/SourceContent/SourceSceneImage")
	if row.get_node_or_null("VendorAction_assist_han") == null \
			or row.get_node_or_null("VendorClose") == null or vendor_art.texture == null:
		return _fail("desktop vendor action, close, or source backdrop unavailable")
	var market_audio: Node = ui.opening_audio.market_audio
	if not market_audio.ambience_player.playing \
			or market_audio.ambience_player.get_meta("ambience_id", "") != "amb_market_bazaar":
		return _fail("desktop bazaar did not start its authored ambience")
	(row.get_node("VendorAction_assist_han") as Button).pressed.emit()
	await process_frame
	var desktop_relation := int(ui.opening.state.get("marketState", {}).get(
		"vendorRelations", {}).get("han_peddler", -1))
	if desktop_relation != 1 or market_audio.transaction_player.stream == null:
		return _fail("desktop vendor interaction did not reach authoritative state: relation=%d audio_stream=%s" % [
			desktop_relation, str(market_audio.transaction_player.stream != null)])
	(row.get_node("VendorClose") as Button).pressed.emit()
	await process_frame
	if ui.opening.get_current_card().get("type") != "VENDOR_RESULT" \
			or row.get_node_or_null("Choice_right") == null \
			or market_audio.ambience_player.playing:
		return _fail("desktop vendor close did not show result choice")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(audio_settings))
	print("NONCOMBAT_BAZAAR_VENDOR_PASS open=true action=true close=true replay=true rollback=true")
	quit(0)

func _reach_bazaar(game: RefCounted) -> bool:
	for i in 5:
		if not game.choose("left", game.issue_choice_token()): return false
	return game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("right", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("down", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("right", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.choose("left", game.issue_choice_token()) \
		and game.resume_flow() and game.get_current_card().get("id") == "bazaar_encounter"

func _same(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
