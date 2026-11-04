extends RefCounted

# The browser's checkDeath cause priority and authored death-card projection.
# The domain owns the decision receipt and durable commit.
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const DEATH_SOURCE := "data/cards/death.json"
const CAUSES := {
	"death_dao_collapse": "道心崩碎，走火入魔",
	"death_blood_loss": "气血耗尽，身死道消",
	"death_lifespan": "寿元耗尽，坐化而终",
}

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted = null) -> void:
	_content = content if content != null else ContentRepository.new()


func source_card(card_id: String) -> Dictionary:
	last_error = ""
	if not CAUSES.has(card_id):
		last_error = "death cause unsupported"
		return {}
	var row: Dictionary = _content.find("card", card_id)
	var card: Variant = row.get("data")
	var art: Dictionary = _content.card_scene_image_status(card_id)
	if row.get("sourcePath") != DEATH_SOURCE or not card is Dictionary \
			or card.get("id") != card_id or card.get("reason") != CAUSES[card_id] \
			or not card.get("choices") is Dictionary \
			or not card["choices"].has("left") or not card["choices"].has("right") \
			or art.get("sceneImage") != card.get("sceneImage") \
			or art.get("textureLoadable") != true:
		last_error = "death card or original art unavailable"
		return {}
	return card.duplicate(true)


func prepare_death(candidate: Dictionary, source_card_id: String) -> Dictionary:
	last_error = ""
	var cave_fatal: bool = source_card_id in ["q_cave", "cave_spirit", "cave_beast",
		"cave_reward", "f_trial", "_dungeon_fork_fork", "realm_elder",
		"realm_prepare", "realm_treasure", "realm_guardian", "n_cave",
		"nc_trap", "nc_treasure", "n_ancient_ruins", "ar_entrance",
		"ar_hall", "ar_secret", "ar_boss", "ir_gate", "ir_test",
		"ir_treasure", "ir_truth", "it_entrance", "it_combat",
		"it_reward", "it_blessing"] and candidate.get("phase") == "FLOW_PENDING"
	if cave_fatal:
		var receipts: Array = candidate.get("dungeonOutcomeReceipts", [])
		cave_fatal = not receipts.is_empty() and receipts.back().get(
			"outcome") == "failure" and receipts.back().get(
				"settledDecisionIndex") == candidate.get("runClock", {}).get(
					"decisionIndex")
	var sword_trial_fatal: bool = candidate.get("phase") == "BATTLE_PENDING" \
		and candidate.get("battleResultHistory", []) is Array \
		and not candidate.get("battleResultHistory", []).is_empty() \
		and candidate.battleResultHistory.back().get("result", {}).get("sourceCardId") == source_card_id \
		and candidate.battleResultHistory.back().get("decisionIndex") == candidate.get(
			"runClock", {}).get("decisionIndex")
	var choice_fatal: bool = candidate.get("phase") in [
		"NORMAL_PENDING", "MILESTONE_PENDING"] \
		or source_card_id in ["q_sword_1", "q_sword_2",
		"q_sword_3", "q_sword_4", "q_body_1", "q_body_2", "q_body_3",
		"q_body_4", "q_spell_1", "q_spell_2", "q_spell_3", "q_spell_4",
		"q_pill_1", "q_pill_2", "q_pill_3", "q_pill_4",
		"q_tianshu_1", "q_tianshu_2", "q_tianshu_3", "q_tianshu_4",
		"k_body_echo", "k_body_ascension"]
	if choice_fatal:
		var decision_index := int(candidate.get("runClock", {}).get("decisionIndex", -1))
		var history: Array = candidate.get("choiceHistory", [])
		var life_id := String(candidate.get("runClock", {}).get("lifeId", ""))
		var receipt_id := "decision:%s:choice:%s:%d" % [
			life_id, source_card_id, decision_index]
		var receipt: Dictionary = candidate.get("runClock", {}).get(
			"receipts", {}).get(receipt_id, {})
		choice_fatal = decision_index >= 0 and not history.is_empty() \
			and history.back().get("cardId") == source_card_id \
			and int(history.back().get("decisionIndex", -1)) == decision_index \
			and receipt.get("sourceCardId") == source_card_id \
			and receipt.get("kind") == "choice" \
			and int(receipt.get("decisionIndex", -1)) == decision_index
	if candidate.is_empty() or not (cave_fatal or sword_trial_fatal \
			or choice_fatal \
			or source_card_id == "inner_demon" and candidate.get(
				"phase") == "INNER_DEMON_PENDING") \
			or candidate.get("dead", false) == true \
			or _artifact_can_revive_or_unknown(candidate):
		last_error = "death source or revival boundary unsupported"
		return {}
	var attributes: Dictionary = candidate.get("attributes", {})
	var resources: Dictionary = candidate.get("resources", {})
	var cause := ""
	if int(attributes.get("daoHeart", 1)) <= 0:
		cause = "death_dao_collapse"
	elif int(attributes.get("health", 1)) <= 0:
		cause = "death_blood_loss"
	elif int(resources.get("lifespan", 1)) <= 0:
		cause = "death_lifespan"
	if cause.is_empty():
		last_error = "no fatal source condition"
		return {}
	var card := source_card(cause)
	var source_sha: String = _content.source_sha256("cards:death")
	if card.is_empty() or source_sha.length() != 64:
		last_error = "death source missing or changed"
		return {}
	var next: Dictionary = candidate.duplicate(true)
	next["dead"] = true
	next["deadReason"] = CAUSES[cause]
	next["deathCauseId"] = cause
	next["deathSourceSha"] = source_sha
	next["lifePhase"] = "DYING_NARRATIVE"
	next["lifeCount"] = int(String(next.get("runClock", {}).get(
		"lifeId", "")).get_slice(":", 2))
	next["phase"] = "DEATH_PENDING"
	next["currentCardId"] = cause
	var decision_index := int(next.get("runClock", {}).get("decisionIndex", -1))
	next["decisionCheckpoint"] = {"version": 1, "cardId": cause,
		"sourceCardId": source_card_id, "turn": decision_index,
		"decisionIndex": decision_index, "deathCauseId": cause}
	return next


func _artifact_can_revive_or_unknown(candidate: Dictionary) -> bool:
	var instance_id: Variant = candidate.get("equipment", {}).get("artifact")
	if instance_id == null or instance_id == "":
		return false
	var instance: Variant = candidate.get("treasureInstances", {}).get(instance_id)
	if not instance is Dictionary or instance.get("lifecycle") != "owned":
		return true
	var definitions: Variant = _content.read_module("shops:treasures")
	if not definitions is Dictionary:
		return true
	for row in definitions.get("treasures", []):
		if row is Dictionary and row.get("id") == instance.get("definitionId") \
				and row.get("type") == "artifact":
			return row.get("revive") is Dictionary
	return true


func card(state: Dictionary) -> Dictionary:
	if state.get("phase") != "DEATH_PENDING" or state.get("dead") != true \
			or state.get("lifePhase") != "DYING_NARRATIVE":
		return {}
	var source_sha: String = _content.source_sha256("cards:death")
	if source_sha.is_empty() or state.get("deathSourceSha") != source_sha:
		last_error = "death source pin mismatch"
		return {}
	var cause := String(state.get("deathCauseId", ""))
	if state.get("currentCardId") != cause or state.get("deadReason") != \
			CAUSES.get(cause) or state.get("decisionCheckpoint", {}).get(
				"cardId") != cause:
		last_error = "death state mismatch"
		return {}
	return source_card(cause)
