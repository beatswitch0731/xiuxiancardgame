extends RefCounted

# Source SkillCardAcquisitionSystem opportunity for the bandit-fort card.
# A failed eligible roll is still a once-per-life attempt; the caller commits
# this candidate together with the source choice.
const OFFER_ID := "opportunity_tiger_queen_break_stance_v1"
const SOURCE_ID := "ds_female_bandit"
const OFFER_MODULE := "combat:skill_acquisitions"
const CARD_MODULE := "cards:battle_cards"

var last_error := ""
var _content: RefCounted


func _init(content: RefCounted) -> void:
	_content = content


func preview(state: Dictionary) -> Dictionary:
	last_error = ""
	var document: Variant = _content.read_module(OFFER_MODULE)
	var cards: Variant = _content.read_module(CARD_MODULE)
	var source_sha: String = _content.source_sha256(OFFER_MODULE)
	if not document is Dictionary or not cards is Dictionary \
			or source_sha.length() != 64:
		last_error = "skill opportunity source unavailable"
		return {}
	var offer: Dictionary = document.get("offers", {}).get(OFFER_ID, {})
	var definition: Dictionary = {}
	for row in cards.get("battle_cards", []):
		if row is Dictionary and row.get("id") == offer.get("cardId"):
			definition = row
			break
	if offer.get("sourceCardId") != SOURCE_ID \
			or offer.get("cardId") != "tiger_break_stance" \
			or offer.get("oncePerLife") != true or definition.is_empty():
		last_error = "skill opportunity contract invalid"
		return {}
	var result := {"eligible": false, "reason": "", "sourceSha": source_sha,
		"offer": offer, "definition": definition}
	if not definition.get("tags", []).has(state.get("path")):
		result.reason = "path_mismatch"
		return result
	var order: Array = document.get("realmOrder", [])
	if not order.has(state.get("realm")) or not order.has(offer.get("minRealm")) \
			or order.find(state.get("realm")) < order.find(offer.get("minRealm")):
		result.reason = "realm_locked"
		return result
	if state.get("deck", []).has(offer.cardId) \
			or state.get("skillAcquisitions", {}).has(offer.cardId):
		result.reason = "already_acquired"
		return result
	if state.get("skillOpportunityAttempts", {}).has(OFFER_ID):
		result.reason = "already_attempted"
		return result
	var formula: Dictionary = offer.get("formula", {})
	var attributes: Dictionary = state.get("attributes", {})
	var raw := float(formula.get("baseChance", 0)) \
		+ float(order.find(state.realm) - order.find(offer.minRealm)) * float(formula.get("realmStep", 0)) \
		+ (float(attributes.get("fortune", 0)) - float(formula.get("fortuneCenter", 0))) * float(formula.get("fortuneScale", 0)) \
		+ (float(attributes.get("daoHeart", 0)) - float(formula.get("daoHeartCenter", 0))) * float(formula.get("daoHeartScale", 0)) \
		+ float(attributes.get("cultivation", 0)) * float(formula.get("cultivationScale", 0)) \
		+ float(attributes.get("karmaBad", 0)) * float(formula.get("karmaBadScale", 0)) \
		+ float(attributes.get("karmaGood", 0)) * float(formula.get("karmaGoodScale", 0)) \
		+ float(formula.get("pathBonuses", {}).get(state.path, 0))
	result.eligible = true
	result.reason = "eligible"
	# JavaScript Math.round chooses the larger integer at positive half steps.
	result.chance = clampi(floori(raw + 0.5), int(formula.get("minChance", 0)),
		int(formula.get("maxChance", 100)))
	return result


func resolve(state: Dictionary, decision_index: int, roll: float) -> Dictionary:
	var offer_preview := preview(state)
	if offer_preview.get("eligible") != true or roll < 0.0 or roll >= 1.0 \
			or decision_index != int(state.get("runClock", {}).get("decisionIndex", -2)) + 1:
		last_error = "skill opportunity unavailable"
		return {}
	var candidate := state.duplicate(true)
	var offer: Dictionary = offer_preview.offer
	var roll_percent := floori(roll * 100.0) + 1
	var acquired := roll_percent <= int(offer_preview.chance)
	var attempt := {"offerId": OFFER_ID, "sourceId": SOURCE_ID,
		"sourceType": offer.sourceType, "locationId": offer.locationId,
		"realm": state.realm, "turn": int(state.get("turn", 0)),
		"chance": offer_preview.chance, "roll": roll_percent,
		"outcome": "acquired" if acquired else "failed"}
	candidate["skillOpportunityAttempts"] = candidate.get("skillOpportunityAttempts", {})
	candidate.skillOpportunityAttempts[OFFER_ID] = attempt
	candidate["skillOpportunitySourceSha"] = offer_preview.sourceSha
	if not acquired:
		return candidate
	var card_id: String = offer.cardId
	candidate["deck"].append(card_id)
	candidate["skillAcquisitions"][card_id] = {"cardId": card_id,
		"cardName": offer.cardName, "offerId": OFFER_ID, "sourceId": SOURCE_ID,
		"sourceType": offer.sourceType, "locationId": offer.locationId,
		"realm": state.realm, "path": state.path, "turn": int(state.get("turn", 0)),
		"mode": "random", "chance": offer_preview.chance, "roll": roll_percent}
	candidate["deckOperations"].append({"operation": "acquire",
		"sourceType": offer.sourceType, "sourceId": SOURCE_ID,
		"path": state.path, "realm": state.realm,
		"turn": int(state.get("turn", 0)), "cardId": card_id,
		"mode": "random"})
	if candidate.deckOperations.size() > 100:
		candidate.deckOperations = candidate.deckOperations.slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate.battleLoadout.deck = candidate.deck.duplicate(true)
	return candidate


func acquire_guaranteed(state: Dictionary, decision_index: int) -> Dictionary:
	var offer_preview := preview(state)
	if offer_preview.get("eligible") != true \
			or decision_index != int(state.get("runClock", {}).get("decisionIndex", -2)) + 1:
		last_error = "guaranteed skill opportunity unavailable"
		return {}
	var candidate: Dictionary = state.duplicate(true)
	var offer: Dictionary = offer_preview.offer
	var card_id := String(offer.cardId)
	var record := {"cardId": card_id, "cardName": offer.cardName,
		"offerId": OFFER_ID, "sourceId": SOURCE_ID,
		"sourceType": offer.sourceType, "locationId": offer.locationId,
		"realm": state.realm, "path": state.path,
		"turn": int(state.get("turn", 0)), "mode": "guaranteed",
		"chance": 100, "roll": 0}
	candidate["skillOpportunityAttempts"] = candidate.get("skillOpportunityAttempts", {})
	candidate.skillOpportunityAttempts[OFFER_ID] = {"offerId": OFFER_ID,
		"sourceId": SOURCE_ID, "sourceType": offer.sourceType,
		"locationId": offer.locationId, "realm": state.realm,
		"turn": int(state.get("turn", 0)), "chance": 100, "roll": 0,
		"outcome": "acquired"}
	candidate["skillOpportunitySourceSha"] = offer_preview.sourceSha
	candidate["deck"].append(card_id)
	candidate["skillAcquisitions"][card_id] = record
	candidate["deckOperations"].append({"operation": "acquire",
		"sourceType": offer.sourceType, "sourceId": SOURCE_ID,
		"path": state.path, "realm": state.realm,
		"turn": record.turn, "cardId": card_id, "mode": "guaranteed"})
	if candidate.deckOperations.size() > 100:
		candidate.deckOperations = candidate.deckOperations.slice(-100)
	if candidate.get("battleLoadout") is Dictionary:
		candidate.battleLoadout.deck = candidate.deck.duplicate(true)
	return candidate
