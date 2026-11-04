extends RefCounted

# Bounded fitting-room combat adapter. Ownership uses the existing Godot ledger
# command; definitions and cards are read from the project source catalog.
# Does not load or save user state. Recovery hooks are explicit candidates:
# the browser deck runtime currently leaves these two authored stats unused.
signal changed(event: Dictionary)

const Ownership = preload("res://scripts/noncombat_treasure_acquisition.gd")
const ITEM_IDS := ["问道剑", "brokenSword", "玄铁甲", "灵纹法袍", "灵泉葫芦", "青云剑匣"]
const SLOTS := ["weapon", "armor", "accessory", "artifact"]
const CARD_IDS := ["sword_probe", "sword_guard"]
const SOURCE_NOTES := [
	"问道剑攻击+3、会心+5；剑冢残剑攻击+1。会心先作用于卡牌基础伤害，再加装备攻击。",
	"玄铁甲常驻减伤1；灵纹法袍常驻减伤2。减伤先于护盾，不会给格挡牌额外加盾。",
	"青云剑匣每3张剑标签牌触发。当前浏览器实际规则是基础5加武器攻击，并会被护盾吸收；与描述中的穿透5有差异。",
	"葫芦回血、法袍回灵按目录数值接入本演示；当前浏览器卡牌战斗尚未消费这两个属性，这两项属于候选接线。",
	"演示回合：木人固定攻击3 → 葫芦回血 → 新回合清盾、基础真元补至3 → 法袍额外回灵。木人与初始护体值用于换装比较。"
]

class SourceCatalog extends RefCounted:
	var root_path := ""
	func _init() -> void:
		root_path = ProjectSettings.globalize_path("res://").path_join("../")
		if not FileAccess.file_exists(root_path.path_join("data/shops/treasures.json")):
			root_path = "res://content/"
	func read_module(module_id: String) -> Variant:
		return JSON.parse_string(FileAccess.get_file_as_string(module_path(module_id)))
	func module_path(module_id: String) -> String:
		return root_path.path_join("data/" + module_id.replace(":", "/") + ".json")
	func source_sha256(module_id: String) -> String:
		return FileAccess.get_sha256(module_path(module_id))

var last_error := ""
var critical_roll_override := -1.0
var _content: RefCounted
var _ownership: RefCounted
var _catalog_sha := ""
var _cards_sha := ""
var _definitions: Dictionary = {}
var _cards: Dictionary = {}
var _state: Dictionary = {}
var _stats: Dictionary = {}
var _counters: Dictionary = {}
var _events: Array[Dictionary] = []
var _history: Array[String] = []
var _sequence := 0
var _rng := RandomNumberGenerator.new()
var _hp := 8
var _max_hp := 12
var _qi := 3
var _max_qi := 3
var _block := 0
var _enemy_hp := 120
var _enemy_block := 0
var _opening := 0
var _turn := 1
var _last_action := "idle"

func _init(content: RefCounted = null) -> void:
	_content = content if content != null else SourceCatalog.new()
	_ownership = Ownership.new(_content)
	_catalog_sha = _content.source_sha256("shops:treasures")
	_cards_sha = _content.source_sha256("cards:battle_cards")
	for row in _content.read_module("shops:treasures").get("treasures", []):
		if row.get("id") in ITEM_IDS:
			_definitions[row.id] = row.duplicate(true)
	for row in _content.read_module("cards:battle_cards").get("battle_cards", []):
		if row.get("id") in CARD_IDS:
			_cards[row.id] = row.duplicate(true)
	_state = {"resources": {"treasures": ITEM_IDS.duplicate()}, "treasureInstances": {},
		"equipment": {}, "treasureInventory": [], "treasureCooldowns": {},
		"treasureCommandReceipts": {}}
	for slot in SLOTS:
		_state.equipment[slot] = null
	for id in ITEM_IDS:
		var instance_id: String = "equipment-demo:" + id
		_state.treasureInstances[instance_id] = {"instanceId": instance_id,
			"definitionId": id, "lifecycle": "owned", "acquiredDecision": 0,
			"provenance": {"source": "equipment_demo"}}
		_state.treasureInventory.append(instance_id)
	_rng.randomize()
	_refresh_stats()

func equip(slot: String, definition_id: String) -> bool:
	last_error = ""
	if slot not in SLOTS:
		last_error = "无效装备槽"
		return false
	if not definition_id.is_empty() and (not _definitions.has(definition_id) \
			or _definitions[definition_id].get("type") != slot):
		last_error = "该装备不能装入这个槽位"
		return false
	var old_id: String = _equipped_definition(slot)
	if old_id == definition_id:
		return true
	var instance_id := "equipment-demo:" + definition_id
	if definition_id.is_empty():
		instance_id = ""
		_state.equipment[slot] = null
		_state.treasureInventory = []
		for owned_id in _state.treasureInstances:
			if not _state.equipment.values().has(owned_id):
				_state.treasureInventory.append(owned_id)
	elif not _ownership.equip_owned(_state, instance_id, slot):
		last_error = _ownership.last_error
		return false
	# Each new fitting starts the removed item's progress afresh. Do not carry
	# an unequipped sword-box receipt into a newly equipped copy.
	if slot == "artifact":
		_counters.clear()
	_refresh_stats()
	_events.clear()
	_record("EQUIP", definition_id, 0, {"slot": slot, "oldDefinitionId": old_id,
		"instanceId": instance_id}, "装备「%s」：%s" % [slot,
		_definitions.get(definition_id, {}).get("name", "卸下")])
	_publish("EQUIP")
	return true

func attack() -> bool:
	return _play_card("sword_probe", "attack")

func guard() -> bool:
	return _play_card("sword_guard", "guard")

func _play_card(card_id: String, action: String) -> bool:
	last_error = ""
	var card: Dictionary = _cards.get(card_id, {})
	if card.is_empty() or _hp <= 0 or _enemy_hp <= 0:
		last_error = "请重置演练后继续"
		return false
	if _qi < int(card.cost):
		last_error = "真元不足，请结束回合"
		return false
	_events.clear()
	_last_action = action
	_qi -= int(card.cost)
	_record("CARD_PLAY", "", int(card.cost), {"cardId": card_id,
		"action": action, "cardName": card.name}, "%s · 消耗真元%d" % [card.name, card.cost])
	# The source browser invokes equipment hooks BEFORE authored card effects.
	_trigger_card_passives(card)
	if _enemy_hp <= 0:
		_publish("CARD_PLAY")
		return true
	for effect in card.effects:
		if effect.type == "damage":
			var amount := int(effect.value)
			var roll := critical_roll_override if critical_roll_override >= 0.0 else _rng.randf()
			var critical := roll * 100.0 < float(_stats.get("critRate", 0))
			if critical:
				amount = floori(amount * 1.5)
			_deal_enemy_damage(amount, true, _equipped_definition("weapon"),
				{"cardId": card_id, "critical": critical, "cause": "card"})
		elif effect.type == "block":
			_block += int(effect.value)
			_record("BLOCK", "", int(effect.value), {"cardId": card_id},
				"护盾 +%d" % int(effect.value))
		elif effect.type == "status" and effect.get("statusId") == "opening":
			_opening = mini(int(effect.get("maxStacks", 1)), _opening + int(effect.value))
			_record("STATUS", "", _opening, {"cardId": card_id, "statusId": "opening"}, "木人破绽1")
	_publish("CARD_PLAY")
	return true

func _trigger_card_passives(card: Dictionary) -> void:
	var definition_id := _equipped_definition("artifact")
	if definition_id.is_empty():
		return
	for passive in _definitions[definition_id].get("passives", []):
		if passive.get("hook") != "onCardPlay" or passive.get("cardTag") not in card.tags:
			continue
		var instance_id: String = _state.equipment.artifact
		_counters[instance_id] = int(_counters.get(instance_id, 0)) + 1
		var threshold := int(passive.triggerCount)
		if _counters[instance_id] < threshold:
			_record("ARTIFACT_PROGRESS", definition_id, _counters[instance_id],
				{"threshold": threshold}, "青云剑匣 · 剑式 %d/%d" % [_counters[instance_id], threshold])
			continue
		_counters[instance_id] = 0
		_record("ARTIFACT_TRIGGER", definition_id, int(passive.value),
			{"cardId": card.id, "baseDamage": int(passive.value)}, "青云剑匣 · 飞剑出匣")
		_deal_enemy_damage(int(passive.value), false, definition_id,
			{"cardId": card.id, "cause": "artifact", "baseDamage": int(passive.value)})

func _deal_enemy_damage(base: int, consume_opening: bool, definition_id: String, extra: Dictionary) -> void:
	var opening_bonus := mini(1, _opening) if consume_opening else 0
	_opening -= opening_bonus
	var attack_bonus := int(_stats.get("atk", 0))
	var incoming := base + opening_bonus + attack_bonus
	var absorbed := mini(_enemy_block, incoming)
	_enemy_block -= absorbed
	var damage := incoming - absorbed
	_enemy_hp -= damage
	extra.merge({"baseDamage": base, "weaponBonus": attack_bonus,
		"openingBonus": opening_bonus, "blockSpent": absorbed, "target": "enemy"}, true)
	_record("DAMAGE", definition_id, damage, extra,
		"%s：基础%d + 武器%d + 破绽%d，命中%d" % [
			"飞剑" if extra.get("cause") == "artifact" else "剑击", base, attack_bonus, opening_bonus, damage])

func end_turn() -> bool:
	last_error = ""
	if _hp <= 0 or _enemy_hp <= 0:
		last_error = "请重置演练后继续"
		return false
	_events.clear()
	_last_action = "hurt"
	var reduction := mini(3, int(_stats.get("def", 0)))
	var after_armor := 3 - reduction
	var absorbed := mini(_block, after_armor)
	_block -= absorbed
	var lost := after_armor - absorbed
	_hp = maxi(0, _hp - lost)
	_record("INCOMING", _equipped_definition("armor"), lost,
		{"incoming": 3, "armorReduced": reduction, "blockSpent": absorbed, "target": "player"},
		"木人攻击3：衣甲减%d，护盾挡%d，受伤%d" % [reduction, absorbed, lost])
	if _hp <= 0:
		_record("DEFEAT", "", 0, {}, "演练结束 · 请重置后继续")
		_publish("DEFEAT")
		return true
	_apply_candidate_recovery("accessory", "hpRegen", "HEAL")
	_turn += 1
	_block = 0
	_opening = maxi(0, _opening - 1)
	_qi = _max_qi
	_apply_candidate_recovery("armor", "qiRegen", "QI")
	_record("TURN_START", "", _turn, {}, "第%d回合 · 真元%d" % [_turn, _qi])
	_publish("TURN_START")
	return true

func _apply_candidate_recovery(slot: String, stat: String, kind: String) -> void:
	var definition_id := _equipped_definition(slot)
	var authored := int(_definitions.get(definition_id, {}).get("passive", {}).get(stat, 0))
	if authored <= 0:
		return
	var applied := 0
	if kind == "HEAL":
		applied = mini(authored, _max_hp - _hp)
		_hp += applied
	else:
		applied = mini(authored, _max_qi + 5 - _qi)
		_qi += applied
	_record(kind, definition_id, applied, {"ruleStatus": "candidate_data_hook", "stat": stat,
		"authoredAmount": authored}, "%s：%s +%d（目录属性接线）" % [
		_definitions[definition_id].name, "护体值" if kind == "HEAL" else "真元", applied])

func reset() -> void:
	_hp = 8
	_qi = _max_qi
	_block = 0
	_enemy_hp = 120
	_enemy_block = 0
	_opening = 0
	_turn = 1
	_last_action = "idle"
	_counters.clear()
	_events.clear()
	_history.clear()
	last_error = ""
	_record("RESET", "", 0, {}, "演练重置 · 保留当前穿戴")
	_publish("RESET")

func snapshot() -> Dictionary:
	var equipment := {}
	var instances := {}
	for slot in SLOTS:
		equipment[slot] = _equipped_definition(slot)
		instances[slot] = _state.equipment.get(slot) if _state.equipment.get(slot) != null else ""
	return {"hp": _hp, "maxHp": _max_hp, "qi": _qi, "maxQi": _max_qi,
		"block": _block, "enemyHp": _enemy_hp, "enemyMaxHp": 120, "enemyBlock": _enemy_block,
		"opening": _opening, "turn": _turn, "equipment": equipment,
		"equipmentInstances": instances, "inventory": _state.treasureInventory.duplicate(),
		"stats": _stats.duplicate(), "artifactCounter": int(_counters.get(instances.artifact, 0)),
		"artifactThreshold": 3, "events": _events.duplicate(true), "log": _history.duplicate(),
		"lastAction": _last_action, "lastError": last_error, "sequence": _sequence,
		"definitions": _definitions.duplicate(true), "sourceNotes": SOURCE_NOTES.duplicate(),
		"sourceRules": {"catalogSha256": _catalog_sha,
			"cardsSha256": _cards_sha,
			"equipment": "NoncombatTreasureAcquisition.equip_owned",
			"damage": "DeckCombatSystem._resolveEffect/_dealDamage",
			"artifact": "DeckCombatSystem._triggerEquipmentPassives",
			"recovery": "candidate_data_hook"}}

func _equipped_definition(slot: String) -> String:
	var instance: Variant = _state.equipment.get(slot)
	return String(_state.treasureInstances.get(instance, {}).get("definitionId", "")) if instance != null else ""

func _refresh_stats() -> void:
	_stats = {"atk": 0, "def": 0, "critRate": 0, "hpRegen": 0, "qiRegen": 0}
	for slot in SLOTS:
		var item: Dictionary = _definitions.get(_equipped_definition(slot), {})
		for key in item.get("passive", {}):
			_stats[key] = int(_stats.get(key, 0)) + int(item.passive[key])

func _record(kind: String, definition_id: String, amount: int, extra: Dictionary, text: String) -> void:
	var event := {"kind": kind, "definitionId": definition_id,
		"instanceId": "equipment-demo:" + definition_id if not definition_id.is_empty() else "",
		"amount": amount, "ruleStatus": "browser_source", "text": text}
	event.merge(extra, true)
	_events.append(event)
	_history.append(text)
	if _history.size() > 60:
		_history.pop_front()

func _publish(kind: String) -> void:
	_sequence += 1
	for index in range(_events.size()):
		_events[index]["eventId"] = "equipment-demo:%d:%d" % [_sequence, index]
	changed.emit({"kind": kind, "action": _last_action, "events": _events.duplicate(true),
		"snapshot": snapshot(), "sequence": _sequence})
