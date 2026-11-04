extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")

func _initialize() -> void:
	var script = load("res://scripts/noncombat_content_repository.gd")
	if script == null:
		_fail("noncombat source content repository is absent")
		return
	var repo = script.new()
	if not repo.build_index():
		_fail("source content and manifest failed to index: " + str(repo.errors()))
		return
	if repo.index_count("card") != 588:
		_fail("authored choice-node index is incomplete: " + str(repo.index_count("card")))
		return
	for variant in ["good", "bad"]:
		var crisis: Dictionary = repo.find("card", "qi_karma_crisis_" + variant)
		if crisis.get("sourcePath") != "data/companions/qi_crisis.json" \
				or crisis.get("jsonPointer") != "$.variants." + variant \
				or crisis.get("data", {}).get("id") != "qi_karma_crisis_" + variant \
				or crisis.get("sourceSha256") != repo.source_sha256("companions:qi_crisis"):
			_fail("qi crisis variant lost exact source pointer: " + variant)
			return
	if repo.module_path("npcs:core") != "data/npcs/core_npcs.json" \
			or repo.module_path("protagonist:core") != "data/protagonist.json" \
			or repo.module_path("cards:qi") != "data/cards/qi.json" \
			or not repo.module_path("cards:../qi").is_empty() \
			or not repo.module_path("unknown:thing").is_empty():
		_fail("browser DataLoader module ID or alias resolved incorrectly")
		return
	var qi = repo.read_module("cards:qi")
	var npcs = repo.read_module("npcs:core")
	var protagonist = repo.read_module("protagonist:core")
	if not qi is Dictionary or qi.get("realm") != "qi" \
			or not npcs is Dictionary or npcs.get("npcs", []).size() != 16 \
			or not protagonist is Dictionary or not protagonist.has("identity"):
		_fail("module data was not read from source-backed JSON")
		return
	qi["realm"] = "forged"
	if repo.read_module("cards:qi").get("realm") != "qi":
		_fail("caller changed cached source module")
		return
	var expected := {
		"card": ["q_start_sword", "camp_meditation", "q_sword_3",
			"loc_market_first", "thread_heaven_net_1", "blx_1"],
		"quest": ["white_fox_line"],
		"thread": ["abandoned_village", "bairen_last_lesson"],
		"npc": ["bai_luoxuan"],
	}
	for kind in expected:
		for source_id in expected[kind]:
			var found: Dictionary = repo.find(kind, source_id)
			if found.get("data", {}).get("id", found.get("data", {}).get("threadId")) != source_id \
					or String(found.get("sourcePath", "")).is_empty() \
					or String(found.get("jsonPointer", "")).is_empty() \
					or String(found.get("sourceSha256", "")).length() != 64:
				_fail("stable source lookup lost provenance: %s/%s" % [kind, source_id])
				return
	var generated: Dictionary = repo.find("generated_card", "comp_bai_luoxuan_blx_1")
	if repo.index_count("generated_card") != 317 \
			or generated.get("sourcePath") != "data/companions/events.json" \
			or generated.get("jsonPointer") != "$.companions[0].events[0]" \
			or generated.get("data", {}).get("id") != "blx_1" \
			or generated.get("companionId") != "bai_luoxuan" \
			or generated.get("sourceSha256") != repo.source_sha256("companions:events") \
			or generated.get("reachability", {}).get("minAffection") != 30 \
			or generated.get("reachability", {}).get("minBond") != 1 \
			or generated.get("producerBrowser") != "src/systems/CompanionSystem.js::_buildEventCard" \
			or generated.get("producerGodot") != "res://scripts/noncombat_companion_events.gd::_build_card":
		_fail("generated companion card lost source or reachability provenance")
		return
	for rule in [
		{"id": "vendor_rule:pending", "path": "src/game.js",
			"symbol": "Game._buildVendorPendingCard", "prefix": "vendor_pending:",
			"producer": "res://scripts/noncombat_vendor_flow.gd"},
		{"id": "vendor_rule:result", "path": "src/game.js",
			"symbol": "Game._buildVendorResultCard", "prefix": "vendor_result:",
			"producer": "res://scripts/noncombat_vendor_flow.gd"},
		{"id": "heavens_hint_rule", "path": "src/systems/HeavensHintSystem.js",
			"symbol": "HeavensHintSystem._buildHintCard", "prefix": "heavens_hint:",
			"producer": "res://scripts/noncombat_heavens_hint_flow.gd"},
		{"id": "ghost_debt_rule", "path": "src/game.js",
			"symbol": "Game._buildGhostDebtDueCard", "prefix": "ghost_debt_due:",
			"producer": "res://scripts/noncombat_ghost_debt_flow.gd"},
		{"id": "licensed_delivery_rule", "path": "src/game.js",
			"symbol": "Game._buildLicensedRustedSwordDeliveryCard",
			"prefix": "regulated_rusted_sword_delivery:",
			"producer": "res://scripts/noncombat_licensed_delivery.gd"}
	]:
		var identity: Dictionary = repo.find("generated_card", rule.id)
		if identity.get("sourcePath") != rule.path \
				or identity.get("sourceSymbol") != rule.symbol \
				or identity.get("instancePrefix") != rule.prefix \
				or String(identity.get("sourceSha256", "")).length() != 64 \
				or not identity.get("producerGodot", []).has(rule.producer) \
				or identity.get("reachability", {}).get("instanceIdDynamic") != true:
			_fail("generated producer rule lost source or Godot consumer: " + rule.id)
			return
	for arrival in [
		{"realm": "golden", "source": "ch_foundation_100"},
		{"realm": "nascent", "source": "ch_golden_100"},
		{"realm": "deity", "source": "ch_nascent_100"},
		{"realm": "tribulation", "source": "ch_deity_100"},
	]:
		var arrival_id := "realm_arrival_" + String(arrival.realm)
		var row: Dictionary = repo.find("generated_card", arrival_id)
		var source_card: Dictionary = repo.read_module(
			"cards:chapter_milestones").get(String(arrival.source), {})
		if row.get("sourcePath") != "data/cards/chapter_milestones.json" \
				or row.get("jsonPointer") != "$." + String(arrival.source) \
				or row.get("sourceSha256") != repo.source_sha256(
					"cards:chapter_milestones") \
				or row.get("sourceCardId") != arrival.source \
				or row.get("ruleSourcePath") != "src/game.js" \
				or String(row.get("ruleSourceSha256", "")).length() != 64 \
				or row.get("producerBrowser") != "src/game.js::Game._buildRealmArrivalCard" \
				or row.get("producerGodot") != "res://scripts/noncombat_realm_gate_flow.gd::arrival_card" \
				or row.get("sceneImage") != source_card.get(
					"combatPresentation", {}).get("sceneImage"):
			_fail("realm arrival lost source battle card or scene: " + arrival_id)
			return
	var sword_tomb: Dictionary = repo.find(
		"generated_card", "comp_jian_linger_jle_8_sword_tomb_old_master")
	var tomb_reachability: Dictionary = sword_tomb.get("reachability", {})
	if sword_tomb.get("jsonPointer") != "$.companions[1].events[7]" \
			or tomb_reachability.get("realm") != "golden" \
			or tomb_reachability.get("minAffection") != 60 \
			or tomb_reachability.get("minBond") != 2 \
			or tomb_reachability.get("encounterDependency", {}).get(
				"choiceRefs", {}).get("left", {}).get("encounterId") != \
				"enc_companion_jian_linger_tomb" \
			or tomb_reachability.get("encounterDependency", {}).get(
				"choiceRefs", {}).get("left", {}).get("jsonPointer") != \
				"$.companions[1].events[7].choices.left" \
			or tomb_reachability.get("encounterDependency", {}).get(
				"requiresResolvableEncounter") != true \
			or tomb_reachability.get("choiceValidation", {}).get("effectValueType") != "integer" \
			or not tomb_reachability.get("choiceValidation", {}).get(
				"allowedEffectKeys", []).has("daoHeart"):
		_fail("sword tomb generated card lost encounter or choice eligibility rules")
		return
	var portrait: Dictionary = repo.find("portrait", "bai_luoxuan_trapped")
	var portrait_asset := "assets/characters/stages/bai_luoxuan_trapped.png"
	if portrait.get("sourcePath") != "data/companions/portrait_stages.json" \
			or portrait.get("jsonPointer") != "$.portraitStages.bai_luoxuan.stages[0]" \
			or portrait.get("data", {}).get("asset") != portrait_asset \
			or portrait.get("sourceSha256") != repo.source_sha256(
				"companions:portrait_stages"):
		_fail("portrait stage ID lost source and asset provenance")
		return
	var portrait_media: Dictionary = repo.asset_status(portrait_asset)
	if portrait_media.get("shaVerified") != true \
			or portrait_media.get("textureLoadable") != true:
		_fail("declared portrait stage image is not loadable")
		return
	var bgm: Dictionary = repo.find("audio", "bgm_sect")
	if repo.index_count("audio") != 40 \
			or bgm.get("sourcePath") != "data/audio/path_identity.json" \
			or bgm.get("jsonPointer") != "$.bgmStates.bgm_sect.runtime" \
			or bgm.get("data", {}).get("path") != "bgm/01_sect_dawn/bgm_01_sect_dawn.wav" \
			or bgm.get("sourceSha256") != repo.source_sha256("audio:path_identity"):
		_fail("audio ID lost source and runtime path provenance")
		return
	var bgm_media: Dictionary = repo.audio_status("bgm_sect")
	if bgm_media.get("shaVerified") != true \
			or bgm_media.get("streamLoadable") != true \
			or bgm_media.get("runtimePath") != "assets/audio/bgm/01_sect_dawn/bgm_01_sect_dawn.wav":
		_fail("declared audio ID did not resolve to the verified stream")
		return
	var market_cue: Dictionary = repo.find("audio", "sfx_market_regulated")
	var market_status: Dictionary = repo.audio_status("sfx_market_regulated")
	if market_cue.get("sourcePath") != "data/audio/path_identity.json" \
			or market_cue.get("jsonPointer") != "$.sharedAssets.market.regulated.runtime" \
			or market_cue.get("data", {}).get("path", "missing") != null \
			or not market_cue.get("data", {}).get("procedural") is Dictionary \
			or market_cue.get("sourceSha256") != repo.source_sha256("audio:path_identity") \
			or market_status.get("disposition") != "generated_stream" \
			or market_status.get("runtimePath") != "" \
			or market_status.get("fileExists") != false \
			or market_status.get("shaVerified") != false \
			or market_status.get("streamLoadable") != false:
		_fail("procedural market audio ID was mistaken for a missing file")
		return
	var bad_audio_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	for entry in bad_audio_manifest["audio"]:
		if entry.get("path") == bgm_media.runtimePath:
			entry["sha256"] = "0".repeat(64)
			break
	var bad_audio_manifest_path := "user://noncombat_bad_audio_manifest_test.json"
	var bad_audio_file := FileAccess.open(bad_audio_manifest_path, FileAccess.WRITE)
	bad_audio_file.store_string(JSON.stringify(bad_audio_manifest))
	bad_audio_file.close()
	var bad_audio_repo = script.new(bad_audio_manifest_path)
	var rejected_audio: Dictionary = bad_audio_repo.audio_status("bgm_sect")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_audio_manifest_path))
	if rejected_audio.get("sourcePath") != "data/audio/path_identity.json" \
			or rejected_audio.get("jsonPointer") != "$.bgmStates.bgm_sect.runtime" \
			or rejected_audio.get("fileExists") != true \
			or rejected_audio.get("shaVerified") != false \
			or rejected_audio.get("streamLoadable") != false:
		_fail("audio ID accepted a drifted packaged stream")
		return
	var altered: Dictionary = repo.find("card", "q_start_sword")
	altered["data"]["title"] = "forged"
	if repo.find("card", "q_start_sword").get("data", {}).get("title") == "forged":
		_fail("caller changed cached card identity")
		return
	var cross_boundary: Dictionary = repo.card_scene_image_status("q_sword_3")
	var present: Dictionary = repo.card_scene_image_status("q_start_sword")
	if cross_boundary.get("listedInManifest") != true \
			or cross_boundary.get("fileExists") != true \
			or cross_boundary.get("shaVerified") != true \
			or cross_boundary.get("textureLoadable") != true \
			or not String(cross_boundary.get("sceneImage", "")).begins_with("assets/combat/") \
			or cross_boundary.get("sourcePath") != "data/quests/sword_legacy.json" \
			or present.get("listedInManifest") != true \
			or present.get("fileExists") != true \
			or present.get("shaVerified") != true \
			or present.get("textureLoadable") != true:
		_fail("cross-boundary story scene image was not imported with source provenance")
		return
	for card_id in ["ds_female_bandit", "realm_guardian", "q_body_4",
			"q_pill_4", "q_spell_4", "q_sword_3"]:
		var status: Dictionary = repo.card_scene_image_status(card_id)
		if status.get("listedInManifest") != true \
				or status.get("shaVerified") != true \
				or status.get("textureLoadable") != true \
				or not String(status.get("sceneImage", "")).begins_with("assets/combat/"):
			_fail("cross-boundary story image was not loadable: " + card_id)
			return
	var sword_media: Array = repo.scene_image_references("data/quests/sword_legacy.json")
	var village_media: Array = repo.scene_image_references("data/threads/qi_threads.json")
	if not _has_scene_ref(sword_media,
			"$.cards[2].choices.left.combatPresentation.sceneImage", true) \
			or not _has_scene_ref(village_media,
			"$.threads[0].nodes[3].variants[0].card.sceneImage", true):
		_fail("conditional and combat-presentation scene media lost source pointers")
		return
	var source_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	var scene_count := 0
	var unlisted_count := 0
	var unlisted_paths: Dictionary = {}
	var cross_boundary_paths: Dictionary = {}
	for entry in source_manifest["data"]:
		var source_path := String(entry.get("path", ""))
		if source_path.begins_with("data/combat/"):
			continue
		for image in repo.scene_image_references(source_path, false):
			scene_count += 1
			if String(image.get("assetPath", "")).begins_with("assets/combat/"):
				cross_boundary_paths[image["assetPath"]] = true
			if image.get("listedInManifest") != true:
				unlisted_count += 1
				unlisted_paths[image["assetPath"]] = true
	var texture_registry = Registry.new()
	if cross_boundary_paths.size() < 13:
		_fail("cross-boundary story image references disappeared from source data")
		return
	for image_path in cross_boundary_paths:
		if texture_registry.texture_for(String(image_path)) == null:
			_fail("cross-boundary story image cannot load as a Godot texture: " + image_path)
			return
	if scene_count != 553 or unlisted_count != 0 or unlisted_paths.size() != 0:
		_fail("scene-image index omitted source variants or failed to import cross-boundary media: %d/%d/%d" % [
			scene_count, unlisted_count, unlisted_paths.size()])
		return
	var media: Dictionary = repo.media_for(
		"assets/cards/characters/collected/jian_linger_pc98.png")
	if not String(media.get("display", "")).begins_with("assets/card-illustrations/"):
		_fail("source secondary narrative media mapping is missing")
		return
	if not repo.find("card", "does_not_exist").is_empty() \
			or repo.read_module("cards:does_not_exist") != null:
		_fail("unknown content silently resolved")
		return
	var manifest_file := FileAccess.open("res://content/source_manifest.json", FileAccess.READ)
	var corrupt: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	for entry in corrupt["data"]:
		if entry.get("path") == "data/cards/qi.json":
			entry["sha256"] = "0".repeat(64)
			break
	var fixture_path := "user://noncombat_corrupt_manifest_test.json"
	var fixture := FileAccess.open(fixture_path, FileAccess.WRITE)
	if fixture == null:
		_fail("cannot create isolated corrupt-manifest fixture")
		return
	fixture.store_string(JSON.stringify(corrupt))
	fixture.close()
	var invalid_repo = script.new(fixture_path)
	var accepted: Variant = invalid_repo.read_module("cards:qi")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	if accepted != null or not str(invalid_repo.errors()).contains("Source SHA mismatch: data/cards/qi.json"):
		_fail("source SHA drift was not rejected at runtime")
		return
	var companion_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	for entry in companion_manifest["data"]:
		if entry.get("path") == "data/companions/events.json":
			entry["sha256"] = "0".repeat(64)
			break
	var companion_fixture_path := "user://noncombat_corrupt_companion_manifest_test.json"
	var companion_fixture := FileAccess.open(companion_fixture_path, FileAccess.WRITE)
	if companion_fixture == null:
		_fail("cannot create isolated companion-manifest fixture")
		return
	companion_fixture.store_string(JSON.stringify(companion_manifest))
	companion_fixture.close()
	var stale_companion_repo = script.new(companion_fixture_path)
	var stale_generated: Dictionary = stale_companion_repo.find(
		"generated_card", "comp_bai_luoxuan_blx_1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(companion_fixture_path))
	if not stale_generated.is_empty() or not str(stale_companion_repo.errors()).contains(
			"Source SHA mismatch: data/companions/events.json"):
		_fail("companion producer source SHA drift was accepted")
		return
	var art_manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/source_manifest.json"))
	for entry in art_manifest["art"]:
		if entry.get("path") == present.get("sceneImage"):
			entry["sha256"] = "0".repeat(64)
			break
	var art_fixture_path := "user://noncombat_corrupt_art_manifest_test.json"
	var art_fixture := FileAccess.open(art_fixture_path, FileAccess.WRITE)
	art_fixture.store_string(JSON.stringify(art_manifest))
	art_fixture.close()
	var stale_image: Dictionary = script.new(art_fixture_path).card_scene_image_status("q_start_sword")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(art_fixture_path))
	if stale_image.get("listedInManifest") != true \
			or stale_image.get("fileExists") != true \
			or stale_image.get("shaVerified") != false \
			or stale_image.get("textureLoadable") != false:
		_fail("listed story image was mistaken for verified display media")
		return
	var duplicate_repo = script.new()
	if duplicate_repo.read_module("companions:portrait_stages") == null:
		_fail("portrait source fixture could not resolve")
		return
	duplicate_repo._index_document("data/companions/portrait_stages.json",
		{"portraitStages": {"bai_luoxuan": {
			"stages": [portrait.data, portrait.data.duplicate(true)]}}})
	if not str(duplicate_repo.errors()).contains(
			"Duplicate portrait ID bai_luoxuan_trapped"):
		_fail("duplicate authored portrait ID was accepted")
		return
	var duplicate_generated_repo = script.new()
	if duplicate_generated_repo.read_module("companions:events") == null:
		_fail("companion source fixture could not resolve")
		return
	duplicate_generated_repo._index_document("data/companions/events.json", {
		"companions": [{"id": "bai_luoxuan", "events": [
			generated.data, generated.data.duplicate(true)]}]})
	if not str(duplicate_generated_repo.errors()).contains(
			"Duplicate generated_card ID comp_bai_luoxuan_blx_1"):
		_fail("duplicate generated companion card ID was accepted")
		return
	var duplicate_audio_repo = script.new()
	if duplicate_audio_repo.read_module("audio:path_identity") == null:
		_fail("audio source fixture could not resolve")
		return
	duplicate_audio_repo._index_document("data/audio/path_identity.json", {
		"assetRoot": "assets/audio/", "first": {"runtime": {
		"id": "same_audio", "path": "sfx/ui/card_snap.mp3"}},
		"second": {"runtime": {"id": "same_audio",
		"path": "sfx/ui/card_snap.mp3"}}})
	var duplicate_audio_error := str(duplicate_audio_repo.errors())
	if not duplicate_audio_error.contains("Duplicate audio ID same_audio") \
			or not duplicate_audio_error.contains("$.first.runtime") \
			or not duplicate_audio_error.contains("$.second.runtime"):
		_fail("duplicate authored audio ID was accepted")
		return
	print("NONCOMBAT_CONTENT_REPOSITORY_PASS modules=75 cards=588 quests=6 threads=12 scene_refs=553 unlisted=0")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _has_scene_ref(rows: Array, pointer: String, verified: bool) -> bool:
	for row in rows:
		if row.get("jsonPointer") == pointer:
			return row.get("shaVerified") == verified \
				and row.get("sourcePath") is String \
				and row.get("assetPath") is String
	return false
