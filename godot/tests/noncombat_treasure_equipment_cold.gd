extends "res://tests/noncombat_regulated_ordinary_natural.gd"

func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.get("phase") != "SHOP_PENDING" \
			or not game.choose("right", game.issue_choice_token()):
		return _fail("natural official shop did not open")
	var offer_id := ""
	for offer in game.vendor_offers():
		if String(offer.get("id", "")).begins_with("shop_treasure_dyn_"):
			offer_id = String(offer.id)
			break
	if offer_id.is_empty() or not game.purchase_vendor_offer(offer_id,
			game.issue_choice_token()):
		return _fail("natural official stock did not sell a treasure")
	var pending: Dictionary = game.state.get("pendingLoadoutDecision", {})
	var instance_id := String(pending.get("instanceId", ""))
	var slot := String(pending.get("targetSlot", ""))
	if instance_id.is_empty() or slot.is_empty() \
			or int(game.state.get("marketState", {}).get("activeSession", {}).get(
				"summary", {}).get("purchaseCount", 0)) != 1 \
			or not game.resolve_vendor_loadout("stash", game.issue_choice_token()) \
			or not game.close_vendor(game.issue_choice_token()):
		return _fail("natural purchased weapon could not be stashed and shop closed")
	for index in 20:
		if game.state.get("phase") in ["NORMAL_PENDING", "THREAD_PENDING"]:
			break
		if game.state.get("phase") == "FLOW_PENDING":
			if not game.resume_flow():
				return _fail("post-shop natural flow could not resume")
			continue
		if game.state.get("phase") == "VENDOR_OPEN":
			if not game.close_vendor(game.issue_choice_token()):
				return _fail("post-shop source vendor could not close")
			continue
		if game.state.get("phase") == "BATTLE_PENDING":
			var request: Dictionary = game.battle_request()
			if request.is_empty() or not game.submit_battle_result(
					_result_for(request, "victory")):
				return _fail("post-shop source battle could not return")
			continue
		var direction := "right" if game.state.get("phase") == "VENDOR_RESULT_PENDING" \
			else "left"
		if not game.can_choose_direction(direction):
			for alternate in ["right", "down", "up"]:
				if game.can_choose_direction(alternate):
					direction = alternate
					break
		if not game.can_choose_direction(direction) \
				or not game.choose(direction, game.issue_choice_token()):
			return _fail("post-shop source card could not settle: " + JSON.stringify({
				"phase": game.state.get("phase"), "card": game.get_current_card().get("id")}))
	if game.state.get("phase") not in ["NORMAL_PENDING", "THREAD_PENDING"]:
		return _fail("post-shop route did not reach equipment screen")
	var prior: Dictionary = game.state.duplicate(true)
	var prior_bytes := FileAccess.get_file_as_string(game._store.v2_path)
	game._store.fail_promotion_once = true
	if game.change_treasure_equipment("equip", instance_id, slot,
			game.issue_choice_token()) or not _same(game.state, prior) \
			or FileAccess.get_file_as_string(game._store.v2_path) != prior_bytes:
		return _fail("failed equipment write changed state or file")
	if not game.change_treasure_equipment("equip", instance_id, slot,
			game.issue_choice_token()) or game.state.equipment.get(slot) != instance_id \
			or game.state.get("treasureInventory", []).has(instance_id):
		return _fail("natural owned weapon could not equip outside vendor")
	var equipped: Dictionary = game.state.duplicate(true)
	var reopened = _shop_branch(FileAccess.get_file_as_bytes(
		game._store.v2_path), path)
	if reopened == null or not _same(reopened.state, equipped):
		return _fail("equipment command did not strictly replay")
	if not reopened.change_treasure_equipment("unequip", instance_id, slot,
			reopened.issue_choice_token()) \
			or reopened.state.equipment.get(slot) != null \
			or not reopened.state.get("treasureInventory", []).has(instance_id):
		return _fail("owned weapon could not unequip")
	var stashed: Dictionary = reopened.state.duplicate(true)
	var after = _shop_branch(FileAccess.get_file_as_bytes(
		reopened._store.v2_path), path)
	if after == null or not _same(after.state, stashed):
		return _fail("equipment removal did not strictly replay")
	print("NONCOMBAT_TREASURE_EQUIPMENT_COLD_PASS purchase=true equip=true unequip=true rollback=true replay=true")
	quit(0)
