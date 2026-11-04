extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Repository = preload("res://scripts/noncombat_content_repository.gd")
const DeckAcquisition = preload("res://scripts/noncombat_deck_acquisition.gd")
const FragmentFlow = preload("res://scripts/noncombat_legacy_fragment_flow.gd")
const LineageFlow = preload("res://scripts/noncombat_lineage_flow.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repository = Repository.new()
	var lineage = LineageFlow.new(repository)
	var fragments = FragmentFlow.new(repository, DeckAcquisition.new(repository))
	var tree: Dictionary = lineage.initial_tree()
	var base := {"rebirthTree": tree.duplicate(true)}
	var baseline: Dictionary = fragments.pacing_contract(base)
	if baseline.get("pityMissLimit") != 7 \
			or baseline.get("focusedWeight") != 0.60 \
			or baseline.get("ordinaryDropRates", {}).get("qi") != 0.08:
		return _fail("browser baseline fragment pacing changed")
	tree["unlockedNodeIds"] = ["fragments_echo", "fragments_thread",
		"fragments_resonance", "fragments_boss_choice"]
	var boosted := {"rebirthTree": tree}
	var pacing: Dictionary = fragments.pacing_contract(boosted)
	if pacing.get("pityMissLimit") != 6 \
			or absf(float(pacing.get("focusedWeight", 0)) - 0.70) > 0.00001 \
			or absf(float(pacing.get("ordinaryDropRates", {}).get("qi", 0))
				- 0.09) > 0.00001:
		return _fail("source fragment nodes did not change pacing")
	var sets := ["sword_heart", "pill_way", "array_way", "heaven_book"]
	if fragments.boss_candidate_set_ids(base, sets, "sword_heart",
			"boss:example") != ["sword_heart", "array_way", "pill_way"] \
			or fragments.boss_candidate_set_ids(boosted, sets, "sword_heart",
			"boss:example") != ["sword_heart", "array_way", "pill_way",
			"heaven_book"]:
		return _fail("source boss candidate ordering or extra choice differs")
	var game = Domain.new(Registry.new(), null, "slot_3")
	if not game.start("sword") or not game.choose("left",
			game.issue_choice_token()):
		return _fail("source fragment state unavailable")
	var prior: Dictionary = game.state.duplicate(true)
	var previous_count := _total(prior)
	var pity_candidate: Dictionary = _next_candidate(prior, tree)
	pity_candidate.legacyRunState.ordinaryMissStreak = 6
	fragments.roll_override = 0.99
	if not fragments.settle(prior, pity_candidate, false, -1, 0) \
			or pity_candidate.legacyRunState.ordinaryMissStreak != 0 \
			or _total(pity_candidate) != previous_count + 1:
		return _fail("six misses did not force the next source fragment")
	var rate_candidate: Dictionary = _next_candidate(prior, tree)
	fragments.roll_override = 0.085
	if not fragments.settle(prior, rate_candidate, false, -1, 0) \
			or _total(rate_candidate) != previous_count + 1:
		return _fail("ordinary drop node did not affect the actual draw")
	var focused_candidate: Dictionary = _next_candidate(prior, tree)
	focused_candidate.legacyRunState.ordinaryMissStreak = 6
	focused_candidate.legacyRunState.focusedSetId = "sword_heart"
	fragments.roll_override = 0.65
	if not fragments.settle(prior, focused_candidate, false, -1, 0) \
			or int(focused_candidate.legacyArchive.fragmentsBySet.sword_heart) \
				!= int(prior.legacyArchive.fragmentsBySet.sword_heart) + 1:
		return _fail("focused-weight node did not affect actual set selection")
	var bad_tree := tree.duplicate(true)
	bad_tree.sourceSha = "f".repeat(64)
	var bad_candidate: Dictionary = _next_candidate(prior, bad_tree)
	if fragments.settle(prior, bad_candidate, false, -1, 0):
		return _fail("fragment draw accepted a changed tree source")
	print("NONCOMBAT_LINEAGE_FRAGMENTS_PASS pity=6 weight=0.70 rate=0.09 boss=4 draw=true")
	quit(0)


func _next_candidate(prior: Dictionary, tree: Dictionary) -> Dictionary:
	var candidate := prior.duplicate(true)
	var index := int(candidate.runClock.decisionIndex) + 1
	candidate.runClock.decisionIndex = index
	candidate.choiceHistory.append({"cardId": "q_cultivate", "cardType": "NORMAL",
		"decisionIndex": index, "direction": "left", "turn": index - 1,
		"tags": []})
	candidate.rebirthTree = tree.duplicate(true)
	return candidate


func _total(state: Dictionary) -> int:
	var result := 0
	for count in state.legacyArchive.fragmentsBySet.values():
		result += int(count)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
