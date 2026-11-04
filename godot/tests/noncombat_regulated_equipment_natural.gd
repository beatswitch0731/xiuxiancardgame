extends "res://tests/noncombat_regulated_ordinary_natural.gd"


func _verify_shop_natural(game: RefCounted, path: String) -> void:
	if game.state.get("phase") != "SHOP_PENDING":
		return _fail("natural official shop card unavailable")
	var pending: Dictionary = game.state.duplicate(true)
	var cold = _shop_branch(FileAccess.get_file_as_bytes(game._store.v2_path), path)
	if cold == null or not _same(cold.state, pending) \
			or not cold.choose("right", cold.issue_choice_token()):
		return _fail("natural official shop could not open from cold save")
	var treasure_offer := ""
	for offer in cold.vendor_offers():
		if String(offer.get("id", "")).begins_with("shop_treasure_dyn_"):
			treasure_offer = String(offer.id)
			break
	if treasure_offer.is_empty() or not cold.purchase_vendor_offer(
			treasure_offer, cold.issue_choice_token()):
		return _fail("natural official treasure could not be bought")
	var pending_loadout: Dictionary = cold.state.get("pendingLoadoutDecision", {})
	var instance_id := String(pending_loadout.get("instanceId", ""))
	var slot := String(pending_loadout.get("targetSlot", ""))
	if instance_id.is_empty() or slot.is_empty() \
			or not cold.resolve_vendor_loadout("equip", cold.issue_choice_token()) \
			or cold.state.get("equipment", {}).get(slot) != instance_id \
			or cold.state.get("treasureInventory", []).has(instance_id):
		return _fail("source purchase did not equip its owned instance")
	if not cold.close_vendor(cold.issue_choice_token()):
		return _fail("equipped official vendor could not close")
	var committed: Dictionary = cold.state.duplicate(true)
	var reopened = _shop_branch(FileAccess.get_file_as_bytes(
		cold._store.v2_path), path)
	if reopened == null or not _same(reopened.state, committed) \
			or reopened.state.get("equipment", {}).get(slot) != instance_id:
		return _fail("natural purchase and equip failed strict cold replay")
	print("NONCOMBAT_REGULATED_EQUIPMENT_NATURAL_PASS offer=%s slot=%s replay=true" % [
		treasure_offer, slot])
	quit(0)
