extends "res://tests/noncombat_choice_echo_flow.gd"

func _run() -> void:
	var flow = EchoFlow.new()
	var source: Variant = flow._content.read_module("echoes:echo_templates")
	if not source is Dictionary:
		return _fail("echo source unavailable")
	var count := 0
	for npc_id in source:
		var group: Variant = source[npc_id]
		if not group is Dictionary or not group.get("echoTemplates") is Array:
			continue
		for template in group.echoTemplates:
			if not template is Dictionary:
				return _fail("malformed echo template")
			for direction in ["left", "right"]:
				var state := _base()
				state["turn"] = 30
				state["runClock"]["decisionIndex"] = 30
				state["realm"] = "nascent"
				state["choiceEchoState"] = flow.marker(0)
				state["choiceEchoes"] = [{"id": "echo_test_%d" % count,
					"turn": 10, "realm": "qi", "cardId": "mentor_seed",
					"choice": "left", "choiceLabel": "原选择",
					"context": {"npcId": npc_id, "affection": 80,
						"location": "宗门", "cardType": "MENTOR_ARC"},
					"echoConditions": {"minTurnGap": 15, "minAffection": 0,
						"npcAlive": false, "location": null, "minRealm": null},
					"templateId": template.id, "genericIndex": 0,
					"triggered": false}]
				var pending: Dictionary = flow.take(state)
				if pending.get("phase") != "CHOICE_ECHO_PENDING":
					return _fail("template card not issued: " + String(template.id))
				var card: Dictionary = flow.card(pending)
				if card.get("description") != template.echoText \
						or card.get("choices", {}).get(direction) != template.echoChoices.get(direction):
					return _fail("template projection drift: " + String(template.id))
				var settled: Dictionary = flow.settle(pending, direction)
				if settled.get("phase") != "FLOW_PENDING" \
						or settled.get("runClock", {}).get("decisionIndex") != 31:
					return _fail("template settlement failed: %s/%s %s" % [
							template.id, direction, flow.last_error])
				if template.id == "bai_ren_last_lesson" and direction == "right" \
						and settled.get("modifiers", {}).get("combat_skill") != 1:
					return _fail("source combat_skill modifier was not applied")
				count += 1
	if count != 28:
		return _fail("expected 14 source templates, found %d choices" % count)
	print("NONCOMBAT_CHOICE_ECHO_TEMPLATES_PASS templates=14 choices=28")
	quit(0)
