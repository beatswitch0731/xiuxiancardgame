extends SceneTree

const Repository = preload("res://scripts/noncombat_content_repository.gd")
const Flow = preload("res://scripts/noncombat_ripple_flow.gd")
const TYPES := ["karma", "grudge", "bloodline", "fate"]

func _initialize() -> void:
	var repo = Repository.new()
	if not repo.build_index() or FileAccess.get_sha256(
			"res://tests/fixtures/source/src/systems/KarmaRippleSystem.js") != Flow.SOURCE_JS_SHA:
		return _fail("ripple source unavailable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/derived/karma_ripple_templates.json"))
	var flow = Flow.new(repo)
	for kind in TYPES:
		var template: Dictionary = catalog.templates[kind][0]
		var row: Dictionary = repo.find("generated_card", "karma_ripple_template:" + kind)
		if row.get("data") != template \
				or row.get("sourcePath") != "src/systems/KarmaRippleSystem.js" \
				or row.get("sourceSha256") != Flow.SOURCE_JS_SHA \
				or row.get("derivedCatalogPath") != "godot/content/derived/karma_ripple_templates.json" \
				or row.get("derivedCatalogPointer") != "$.templates.%s[0]" % kind \
				or row.get("derivedCatalogSha256") != Flow.DERIVED_SHA \
				or row.get("producerGodot") != "res://scripts/noncombat_ripple_flow.gd::_build_card":
			return _fail("ripple template source missing: " + kind)
		var state := {"runClock": {"lifeId": "slot_1:life:0"}}
		var card: Dictionary = flow._build_card(state, {"id": "seed:" + kind,
			"seedType": kind}, 5, template)
		if card.get("id") != "karma_ripple:slot_1:life:0:5:seed:" + kind:
			return _fail("registered ripple template did not reach producer: " + kind)
	var duplicate = Repository.new()
	if not duplicate.build_index():
		return _fail("duplicate baseline unavailable")
	duplicate._index_ripple_templates()
	if not duplicate.errors().any(func(message: String) -> bool:
		return message.contains("Duplicate generated_card ID: karma_ripple_template:karma")):
		return _fail("duplicate ripple template accepted")
	repo._indexes["generated_card"]["karma_ripple_template:karma"]["data"]["title"] = "forged"
	if not flow._build_card({"runClock": {"lifeId": "slot_1:life:0"}},
			{"id": "seed:karma", "seedType": "karma"}, 5,
			catalog.templates.karma[0]).is_empty():
		return _fail("ripple producer accepted forged template registration")
	print("NONCOMBAT_RIPPLE_TEMPLATE_REGISTRY_PASS templates=4 duplicate=rejected forged=rejected")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
