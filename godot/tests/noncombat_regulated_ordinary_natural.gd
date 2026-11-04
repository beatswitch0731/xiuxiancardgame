extends "res://tests/noncombat_foundation_shop_natural.gd"


func _target_card_id() -> String:
	return "shop_encounter"

func _fixed_roll() -> float:
	return -1.0

func _normal_seed() -> int:
	return 2

func _iteration_limit() -> int:
	return 210

func _battle_outcome_for_request(request: Dictionary) -> String:
	return "flee" if request.get("sourceCardId") == "ch_foundation_100" else "victory"


func _target_ready(game: RefCounted) -> bool:
	return game.state.get("realm") == "foundation"

func _fight_fellow_before_camp() -> bool:
	return true


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.get("phase") != "SHOP_PENDING":
		return _fail("natural foundation official shop did not reach pending card")
	var pending: Dictionary = game.state.duplicate(true)
	var pending_bytes := FileAccess.get_file_as_bytes(game._store.v2_path)
	var cold = _shop_branch(pending_bytes, path)
	if cold == null or not _same(cold.state, pending) \
			or not cold.choose("right", cold.issue_choice_token()):
		return _fail("natural foundation official shop could not restore and open")
	var treasure_offer := ""
	var card_offer := ""
	var identify_offer := ""
	for offer in cold.vendor_offers():
		if String(offer.get("id", "")).begins_with("shop_treasure_dyn_"):
			treasure_offer = String(offer.id)
		elif String(offer.get("id", "")).begins_with("card_"):
			card_offer = String(offer.id)
		elif offer.get("id") in ["shop_treasure_box", "shop_treasure_mysterious"]:
			identify_offer = String(offer.id)
	if treasure_offer.is_empty() or card_offer.is_empty() or identify_offer.is_empty():
		return _fail("natural foundation official stock missed treasure, path card or antique")
	var total_price := 0
	for offer in cold.vendor_offers():
		if offer.get("id") in [treasure_offer, card_offer, identify_offer]:
			total_price += int(offer.get("price", 0))
	if int(cold.state.resources.spiritStone) < total_price:
		return _fail("natural official shop lacked %d source-earned stones" % total_price)
	if not cold.purchase_vendor_offer(treasure_offer,
			cold.issue_choice_token()) \
			or not cold.state.get("pendingLoadoutDecision") is Dictionary \
			or not cold.purchase_vendor_offer(card_offer,
				cold.issue_choice_token()) \
			or not cold.purchase_vendor_offer(identify_offer,
				cold.issue_choice_token(), "", {"identifyRoll": 0.9,
					"itemRoll": 0.0}) \
			or not cold.close_vendor(cold.issue_choice_token()) \
			or not cold.resolve_vendor_loadout("stash", cold.issue_choice_token()):
		return _fail("natural official treasure/card/antique or deferred stash did not commit")
	var committed: Dictionary = cold.state.duplicate(true)
	var restored = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if restored == null or not _same(restored.state, committed) \
			or not restored.choose("right", restored.issue_choice_token()):
		return _fail("natural official mixed goods failed strict cold restore")
	print("NONCOMBAT_REGULATED_ORDINARY_NATURAL_PASS draw=true treasure=true card=true identify=true deferred_stash=true replay=true")
	quit(0)
