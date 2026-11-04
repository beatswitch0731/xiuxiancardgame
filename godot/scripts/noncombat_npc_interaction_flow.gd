extends RefCounted

const MODULE := "npcs:core"
const LIMITED := ["赠礼", "请教", "论道"]
const MILESTONES := [0, 30, 55, 75, 90, 100]

var _content: RefCounted
var roll_override_sequence: Array = []


func _init(content: RefCounted) -> void:
	_content = content


func roster(state: Dictionary) -> Array:
	var source: Variant = _content.read_module(MODULE)
	if not source is Dictionary:
		return []
	var result := []
	for raw in source.get("npcs", []):
		if not raw is Dictionary or not raw.get("id") is String:
			return []
		var npc: Dictionary = raw
		var npc_id := String(npc.id)
		if not _physical(state, npc_id) or not npc.get("appearRealms", []).has(
			state.get("realm")):
			continue
		var presence: Dictionary = state.get("worldContinuityState", {}).get(
			"npcs", {}).get(npc_id, {})
		result.append({"id": npc_id, "name": npc.get("name", npc_id),
			"title": npc.get("title", ""), "location": presence.get(
				"locationId", npc.get("defaultLocation", "")),
			"canInteract": _physical(state, npc_id)})
	return result


func panel(state: Dictionary, npc_id: String) -> Dictionary:
	var npc := _npc(npc_id)
	if npc.is_empty():
		return {}
	var marker: Dictionary = state.get("npcEncounterScheduling", {})
	var affection := int(state.get("npcAffection", {}).get(npc_id,
		marker.get("affections", {}).get(npc_id, npc.get("startAffection", 0))))
	var memories: Array = marker.get("memories", {}).get(npc_id, [])
	var secrets := []
	var unlocked: Array = state.get("npcInteractionSecrets", {}).get(npc_id, [])
	for secret in npc.get("secrets", []):
		if secret is Dictionary and unlocked.has(int(secret.get("level", -1))):
			secrets.append(secret)
	var info := []
	for item in npc.get("knownInfo", []):
		if item is Dictionary:
			info.append({"text": item.get("text", "") if affection >= int(
				item.get("requiredAffection", -50)) else "尚未知晓",
				"unlocked": affection >= int(item.get("requiredAffection", -50))})
	var actions := ["闲聊", "告辞"] if _physical(state, npc_id) else ["告辞"]
	if actions.has("闲聊"):
		if affection >= 0:
			actions.insert(1, "赠礼")
		if npc.get("teachable") == true and affection >= 15:
			actions.insert(1, "请教")
		if state.get("realm") != "qi" and affection >= 30:
			actions.insert(2, "论道")
	var bond := int(marker.get("bonds", {}).get(npc_id, 0))
	var overall := "至交" if affection >= 90 and bond >= 4 else \
		"亲近" if affection >= 70 else "友善" if affection >= 40 else \
		"认识" if affection >= 15 else "厌恶" if affection < -20 else "陌路"
	return {"npc": npc, "emotion": marker.get("emotions", {}).get(npc_id,
		npc.get("defaultEmotion", "平静")), "mindset": npc.get(
		"defaultMindset", "通明"), "affection": affection,
		"bond": bond, "impression": {"overall": overall,
			"interactionCount": memories.size(), "lastInteraction": int(
				memories.back().get("turn", 0)) if not memories.is_empty() else 0},
		"trust": npc.get("startTrust", 0), "giftPrefs": npc.get("giftPrefs"),
		"secrets": secrets, "knownInfo": info,
		"recentInteractions": memories.slice(maxi(0, memories.size() - 5)),
		"dialogue": _dialogue(npc, "闲聊", affection, String(marker.get(
			"emotions", {}).get(npc_id, npc.get("defaultEmotion", "平静"))),
			String(npc.get("defaultMindset", "通明")), 0.0) if _physical(
			state, npc_id) else "",
		"availableActions": actions, "canInteract": _physical(state, npc_id),
		"location": state.get("worldContinuityState", {}).get("npcs", {}).get(
			npc_id, {}).get("locationId", npc.get("defaultLocation", ""))}


func apply(base: Dictionary, npc_id: String, action: String,
		item_id: String = "") -> Dictionary:
	var view := panel(base, npc_id)
	if view.is_empty() or not view.availableActions.has(action) or action == "告辞" \
			or not base.get("npcEncounterScheduling") is Dictionary:
		return {}
	var marker: Dictionary = base.npcEncounterScheduling
	if not marker.get("memories", {}).has(npc_id):
		return {}
	var turn := int(base.get("turn", 0))
	if LIMITED.has(action):
		if base.get("interactionBudget", {}).get(npc_id, {}).has(str(turn)):
			return {}
	if action == "赠礼" and (item_id.is_empty() or int(base.get(
			"itemInventory", {}).get(item_id, 0)) < 1):
		return {}
	var next: Dictionary = base.duplicate(true)
	var npc: Dictionary = view.npc
	var old_aff := int(view.affection)
	var count: int = next.get("npcInteractionHistory", []).size()
	var roll := _roll(next, npc_id, action, count, "affection", 0)
	var delta := 0
	if action == "闲聊":
		delta = floori(roll * 6.0) - 1
	elif action == "请教":
		delta = 5
	elif action == "论道":
		delta = floori(roll * 11.0)
	elif action == "赠礼":
		var prefs: Dictionary = npc.get("giftPrefs", {})
		var multiplier := 2.0 if prefs.get("love", []).has(item_id) else \
			1.5 if prefs.get("like", []).has(item_id) else \
			0.1 if prefs.get("hate", []).has(item_id) else 1.0
		var proud := int(npc.get("personality", {}).get("proud", 50))
		var character := 0.7 if proud >= 80 else 1.2 if proud <= 30 else 1.0
		var timing: float = {"欣喜": 1.3, "愤怒": 0.5, "哀伤": 1.2,
			"兴奋": 1.5}.get(String(view.emotion), 1.0)
		delta = roundi(5.0 * multiplier * (1.0 + old_aff / 200.0) * character * timing)
		var inventory: Dictionary = next.get("itemInventory", {})
		inventory[item_id] = int(inventory[item_id]) - 1
		if inventory[item_id] == 0:
			inventory.erase(item_id)
		next.itemInventory = inventory
	var reaction := _dialogue(npc, action, old_aff, String(view.emotion),
		String(view.mindset), _roll(next, npc_id, action, count, "dialogue", 1))
	if action == "赠礼":
		var prefs: Dictionary = npc.get("giftPrefs", {})
		reaction = "眼中闪过一丝惊喜——这正是ta最喜欢的。" if prefs.get(
			"love", []).has(item_id) else "微微点头，看起来还算满意。" if prefs.get(
			"like", []).has(item_id) else "皱眉，似乎很不喜欢这个礼物。" if prefs.get(
			"hate", []).has(item_id) else "收下了。"
	if reaction.is_empty():
		reaction = "%s与你闲聊了几句。" % npc.name if action == "闲聊" else \
			"%s悉心指点你的修行，你获益匪浅。" % npc.name if action == "请教" else \
			"与%s论道一番，豁然开朗。" % npc.name if action == "论道" else "收下了。"
	var affection := clampi(old_aff + delta, -50, 100)
	next.npcEncounterScheduling.affections[npc_id] = affection
	var root: Dictionary = next.get("npcAffection", {})
	root[npc_id] = affection
	next.npcAffection = root
	if next.get("npcCrossState") is Dictionary and next.npcCrossState.get(
			"affections", {}).has(npc_id):
		next.npcCrossState.affections[npc_id] = affection
	var memories: Array = next.npcEncounterScheduling.memories[npc_id]
	memories.append({"turn": turn, "action": action, "reaction": reaction,
		"affectionDelta": delta})
	if memories.size() > 20:
		memories.pop_front()
	next.npcEncounterScheduling.memories[npc_id] = memories
	for index in range(1, MILESTONES.size()):
		if affection >= MILESTONES[index]:
			next.npcEncounterScheduling.bonds[npc_id] = maxi(index,
				int(next.npcEncounterScheduling.bonds.get(npc_id, 0)))
	if action == "闲聊" and memories.filter(func(m: Variant) -> bool:
		return m is Dictionary and m.get("action") == "闲聊").size() >= 3:
		var secrets: Dictionary = next.get("npcInteractionSecrets", {})
		var levels: Array = secrets.get(npc_id, [])
		if not levels.has(1):
			levels.append(1)
		secrets[npc_id] = levels
		next.npcInteractionSecrets = secrets
	if action == "闲聊" and affection >= 40 and not npc.get(
			"gossipTopics", []).is_empty():
		var gossip_roll := _roll(next, npc_id, action, count, "gossip", 2)
		if gossip_roll < 0.3:
			var topics: Array = npc.gossipTopics
			var topic_roll := _roll(next, npc_id, action, count, "topic", 3)
			var topic := String(topics[mini(floori(topic_roll * topics.size()),
				topics.size() - 1)])
			var known: Array = next.get("npcInteractionGossip", [])
			if not known.has(topic):
				known.append(topic)
				next.npcInteractionGossip = known
				reaction += "\n\nta不经意间透露了一些消息：\"%s\"" % topic
	if action == "赠礼" and npc.get("giftPrefs", {}).get("love", []).has(item_id) \
			and int(next.npcEncounterScheduling.bonds.get(npc_id, 0)) >= 2:
		var secrets: Dictionary = next.get("npcInteractionSecrets", {})
		var levels: Array = secrets.get(npc_id, [])
		if not levels.has(2):
			levels.append(2)
		secrets[npc_id] = levels
		next.npcInteractionSecrets = secrets
		reaction += "\n\nta看着礼物，沉默了许久，似乎在想什么往事..."
	if LIMITED.has(action):
		var budget: Dictionary = next.get("interactionBudget", {})
		budget[npc_id] = {str(turn): {"action": action,
			"consumedAtTurn": turn}}
		next.interactionBudget = budget
	var history: Array = next.get("npcInteractionHistory", [])
	history.append({"version": 1, "decisionIndex": int(base.runClock.decisionIndex),
		"lifeId": base.runClock.lifeId, "phase": base.get("phase"),
		"cardId": base.get("currentCardId"), "npcId": npc_id,
		"action": action, "itemId": item_id, "reaction": reaction,
		"affectionDelta": delta})
	next.npcInteractionHistory = history
	return next


func _npc(npc_id: String) -> Dictionary:
	var source: Variant = _content.read_module(MODULE)
	if source is Dictionary:
		for raw in source.get("npcs", []):
			if raw is Dictionary and raw.get("id") == npc_id:
				return raw
	return {}


func _physical(state: Dictionary, npc_id: String) -> bool:
	var presence: Dictionary = state.get("worldContinuityState", {}).get(
		"npcs", {}).get(npc_id, {})
	return not presence.is_empty() and presence.get("lifeId") == int(
		state.get("lifeCount", 0)) and presence.get("lifecycle") == "ACTIVE" \
		and presence.get("manifestation") == "PHYSICAL"


func _roll(state: Dictionary, npc_id: String, action: String,
		count: int, stage: String, index: int) -> float:
	if index < roll_override_sequence.size():
		return float(roll_override_sequence[index])
	var key := "%s:%d:%d:%s:%s:%s" % [state.get("runClock", {}).get(
		"lifeId", ""), int(state.get("turn", 0)), count, npc_id, action, stage]
	return float(posmod(key.hash(), 1000000)) / 1000000.0


func _dialogue(npc: Dictionary, action: String, affection: int,
		emotion: String, mindset: String, roll: float) -> String:
	var matches := []
	var fallback := ""
	for raw in npc.get("dialogues", []):
		if not raw is Dictionary:
			continue
		if raw.get("scene") == "通用" and fallback.is_empty():
			fallback = String(raw.get("text", ""))
		if raw.get("scene") not in [action, "通用"] \
				or affection < int(raw.get("minAffection", -50)) \
				or affection > int(raw.get("maxAffection", 100)) \
				or raw.has("mindset") and raw.mindset != mindset \
				or raw.has("emotion") and raw.emotion != emotion:
			continue
		matches.append(String(raw.get("text", "")))
	return String(matches[mini(floori(roll * matches.size()), matches.size() - 1)]) \
		if not matches.is_empty() else fallback
