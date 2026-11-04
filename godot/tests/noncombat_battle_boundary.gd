extends SceneTree

const Registry = preload("res://scripts/runtime_data_registry.gd")
const ContentRepository = preload("res://scripts/noncombat_content_repository.gd")
const Domain = preload("res://scripts/noncombat_domain.gd")
const Store = preload("res://scripts/noncombat_opening_store.gd")
const BattlePlanResolver = preload("res://scripts/battle_plan_resolver.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gateway_script = load("res://scripts/noncombat_battle_gateway.gd")
	if gateway_script == null:
		_fail("source encounter offer and battle contract gateway are absent")
		return
	var registry = Registry.new()
	var gateway = gateway_script.new(registry)
	var plan_resolver = BattlePlanResolver.new(registry)
	var offers := 0
	for path_id in ["sword", "spell", "body", "pill"]:
		for direction in ["left", "right"]:
			var save_path := "user://tests/battle_boundary_%s_%s_%d.json" % [
				path_id, direction, Time.get_ticks_usec()]
			var game = Domain.new(registry, Store.new(save_path), "slot_2")
			if not game.start(path_id) or not game.choose("right", game.issue_choice_token()) \
					or not game.choose("left", game.issue_choice_token()) \
					or not game.choose(direction, game.issue_choice_token()):
				_fail("source opening could not reach encounter offer")
				return
			var before: Dictionary = game.state.duplicate(true)
			var offer: Dictionary = gateway.offer_from_state(game.state)
			var authored_image: String = registry.read_json(
				"data/combat/encounter_presentations.json").get("presentations", {}).get(
					String(game.state["currentCardId"]).trim_prefix("encounter_card_"), {}).get(
						"sceneImage", "")
			if offer.get("encounterId") != String(game.state["currentCardId"]).trim_prefix("encounter_card_") \
					or offer.get("sourceCardId") != game.state["currentCardId"] \
					or offer.get("path") != path_id or offer.get("originCardId") != "q_start_" + path_id \
					or offer.get("originDirection") != direction \
					or String(offer.get("title", "")).is_empty() \
					or String(offer.get("enemyName", "")).is_empty() \
					or not String(offer.get("challengeText", "")).contains(String(offer.get("enemyName", ""))) \
					or String(offer.get("warningTitle", "")).is_empty() \
					or registry.texture_for(String(offer.get("originSceneImage", ""))) == null \
					or game.state != before:
				_fail("encounter offer lost source identity or mutated the run: %s/%s" % [path_id, direction])
				return
			if offer.get("sceneImage") != authored_image \
					or registry.texture_for(authored_image) == null:
				_fail("encounter offer did not project/import its authored scene image: %s/%s" % [
					path_id, direction])
				return
			if path_id == "sword" and direction == "left":
				var mutable_registry = Registry.new()
				var forged_catalog: Dictionary = mutable_registry.read_json(
					"data/combat/encounters.json")
				for encounter in forged_catalog.get("encounters", []):
					if encounter is Dictionary and encounter.get("id") == offer["encounterId"]:
						encounter["title"] = "伪造的教学遭遇"
						break
				var forged_gateway = gateway_script.new(mutable_registry)
				if forged_gateway.offer_from_state(game.state).get("title") != offer["title"]:
					_fail("mutable unverified JSON cache changed the authored encounter offer")
					return
				var forged_manifest: Dictionary = mutable_registry.read_json("source_manifest.json")
				for row in forged_manifest.get("data", []):
					if row is Dictionary and row.get("path") == "data/combat/encounters.json":
						row["sha256"] = "0".repeat(64)
						break
				if forged_gateway.source_content_hash() != gateway.source_content_hash():
					_fail("mutable unverified manifest changed the source-content fingerprint")
					return
				var bad_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
					"res://content/source_manifest.json"))
				for row in bad_manifest.get("data", []):
					if row is Dictionary and row.get("path") == "data/combat/encounters.json":
						row["sha256"] = "0".repeat(64)
						break
				var bad_manifest_path := "user://gateway_bad_manifest_%d.json" % Time.get_ticks_usec()
				var bad_file := FileAccess.open(bad_manifest_path, FileAccess.WRITE)
				if bad_file == null:
					_fail("cannot create source-drift fixture for the encounter gateway")
					return
				bad_file.store_string(JSON.stringify(bad_manifest))
				bad_file.close()
				var bad_gateway = gateway_script.new(registry, ContentRepository.new(bad_manifest_path))
				if not bad_gateway.offer_from_state(game.state).is_empty() \
						or not bad_gateway.source_content_hash().is_empty():
					_fail("gateway accepted encounter data with an invalid source SHA")
					return
				DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_manifest_path))
				for source_path in ["data/config/paths.json", "data/cards/qi.json",
						"data/combat/encounter_director.json"]:
					var drifted_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
						"res://content/source_manifest.json"))
					for row in drifted_manifest.get("data", []):
						if row is Dictionary and row.get("path") == source_path:
							row["sha256"] = "0".repeat(64)
							break
					var drift_path := "user://gateway_bad_source_%d.json" % Time.get_ticks_usec()
					var drift_file := FileAccess.open(drift_path, FileAccess.WRITE)
					if drift_file == null:
						_fail("cannot create source-drift fixture for " + source_path)
						return
					drift_file.store_string(JSON.stringify(drifted_manifest))
					drift_file.close()
					var drift_gateway = gateway_script.new(registry, ContentRepository.new(drift_path))
					if not drift_gateway.offer_from_state(game.state).is_empty() \
							or not drift_gateway.source_content_hash().is_empty():
						_fail("gateway accepted an offer with invalid source SHA: " + source_path)
						return
					DirAccess.remove_absolute(ProjectSettings.globalize_path(drift_path))
			if not gateway.build_request(game.state).is_empty():
				_fail("unselected encounter offer produced a battle request")
				return
			for field in ["currentCardId", "path", "realm"]:
				var invalid_offer: Dictionary = game.state.duplicate(true)
				invalid_offer[field] = "invalid"
				if not gateway.offer_from_state(invalid_offer).is_empty():
					_fail("foreign encounter offer passed source field " + field)
					return
			var missing_origin: Dictionary = game.state.duplicate(true)
			missing_origin["choiceHistory"].clear()
			if not gateway.offer_from_state(missing_origin).is_empty():
				_fail("encounter offer bypassed its committed origin choice")
				return
			var restored = Domain.new(registry, Store.new(save_path), "slot_2")
			if not restored.restore() or gateway.offer_from_state(restored.state) != offer:
				_fail("encounter offer changed after save reload")
				return
			var pending: Dictionary = game.state.duplicate(true)
			pending["phase"] = "BATTLE_PENDING"
			var life_id := String(pending["runClock"]["lifeId"])
			var base_index := int(pending["runClock"]["decisionIndex"])
			var decision_index := base_index + 1
			var card_id := String(offer["sourceCardId"])
			var owner := "enc:%s:%d:%s:1" % [life_id, base_index, card_id]
			var warning_direction := "right" if direction == "right" else "left"
			var warning_token := "warning:%s:%s" % [owner, warning_direction]
			var before_stones := int(pending["resources"]["spiritStone"])
			var before_health := int(pending["attributes"]["health"])
			var prep_cost := 10 if warning_direction == "right" else 0
			var after_stones := before_stones - prep_cost
			var after_health := mini(int(pending["maxHealth"]),
				before_health + (1 if warning_direction == "right" else 0))
			if after_stones < 0:
				_fail("test route cannot afford source warning preparation")
				return
			pending["resources"]["spiritStone"] = after_stones
			pending["attributes"]["health"] = after_health
			pending["decisionCheckpoint"] = {"version": 1, "cardId": card_id,
				"sourceCardId": card_id, "decisionIndex": base_index,
				"warningChoiceDirection": warning_direction}
			pending["runClock"]["preparationReceipts"] = {
				warning_token: {"sourceCardId": card_id,
					"direction": warning_direction, "baseDecisionIndex": base_index,
					"applied": true, "beforeSpiritStone": before_stones,
					"afterSpiritStone": after_stones,
					"beforeHealth": before_health,
					"afterHealth": after_health}}
			var starter_deck: Array = registry.read_json(
				"data/combat/deck_progression.json").get("paths", {}).get(
					path_id, {}).get("starterDeck", []).duplicate(true)
			pending["deck"] = starter_deck.duplicate(true)
			pending["starterDeckPath"] = path_id
			var opening_block := int(registry.read_json("data/config/paths.json").get(
				"paths", {}).get(path_id, {}).get("bonuses", {}).get("combatOpeningBlock", 0))
			pending["battleLoadout"] = {"deck": starter_deck.duplicate(true),
				"equipment": {}, "treasures": [], "skills": {}, "companions": [],
				"lineage": {}, "modifiers": {},
				"pathOpening": {"combatOpeningBlock": opening_block}}
			var source_hash: String = gateway.source_content_hash()
			var source_encounter: Dictionary = {}
			var source_catalog: Dictionary = registry.read_json("data/combat/encounters.json")
			for entry in source_catalog.get("encounters", []):
				if entry is Dictionary and entry.get("id") == offer["encounterId"]:
					source_encounter = entry
					break
			var visual: Dictionary = registry.read_json(
				"data/combat/encounter_presentations.json").get("presentations", {}).get(
					offer["encounterId"], {})
			var tier := int(source_encounter.get("enemy", {}).get("tier", 1))
			var tier_loss := int(source_catalog.get("defeatHealthLossByTier", {}).get(str(tier), tier))
			var frozen_choice := {
				"encounterId": offer["encounterId"], "triggerCombat": true,
				"encounterKind": source_encounter.get("encounterKind", "ordinary"),
				"enemy": source_encounter.get("enemy", {}).duplicate(true),
				"battlefield": visual.get("battlefield", null),
				"combatPresentation": visual.duplicate(true),
				"victoryEffects": source_encounter.get("victoryEffects", {}).duplicate(true),
				"combatRewards": source_encounter.get("victoryEffects", {}).duplicate(true),
				"combatOutcomeLinks": source_encounter.get("outcomeLinks", {}).duplicate(true),
				"combatOutcomePresentation": source_encounter.get("combatOutcomePresentation", {}).duplicate(true),
				"defeatHealthLoss": int(source_encounter.get("defeatHealthLoss", tier_loss)),
			}
			pending["pendingBattle"] = {
				"sourceCardId": card_id, "direction": direction, "encounterId": offer["encounterId"],
				"encounterInstanceId": owner, "baseDecisionIndex": base_index,
				"nextDecisionIndex": decision_index,
				"warningChoiceDirection": warning_direction,
				"warningCheckpointToken": warning_token,
				"pendingResolution": {"sourceCardId": card_id,
					"direction": "left",
					"sourceCard": {"id": card_id, "type": "COMBAT"},
					"choice": frozen_choice,
					"combatCard": {"id": card_id, "encounterId": offer["encounterId"]}},
				"returnPolicy": "source_flow", "warningConfirmed": true,
				"sourceContentHash": source_hash}
			var request: Dictionary = gateway.build_request(pending)
			if request.get("contractVersion") != 2 \
					or request.get("encounterInstanceId") != owner \
					or request.get("slotId") != "slot_2" \
					or request.get("decisionIndex") != decision_index \
					or request.get("warningChoiceDirection") != warning_direction \
					or request.get("playerSnapshot", {}).get("battleLoadout", {}).get("deck") != starter_deck \
					or request.get("presentationId") != offer.get("presentationId") \
					or String(request.get("sourceContentHash", "")).length() != 64:
				_fail("committed challenge did not make a stable source request path=%s origin=%s warning=%s request=%s" % [
					path_id, direction, warning_direction, JSON.stringify(request).left(200)])
				return
			var frozen_request: Dictionary = request.duplicate(true)
			var battle_plan: Dictionary = plan_resolver.inspect_request(request)
			if battle_plan.is_empty() \
					or battle_plan.get("encounterInstanceId") != owner \
					or battle_plan.get("battlefieldId") != offer.get("battlefieldId") \
					or battle_plan.get("deck") != starter_deck \
					or battle_plan.get("path") != path_id \
					or request != frozen_request:
				_fail("real source request could not become a read-only battle plan: " \
						+ plan_resolver.last_error)
				return
			var premature_choice: Dictionary = pending.duplicate(true)
			premature_choice["choiceHistory"].append({"cardId": card_id,
				"direction": "left", "decisionIndex": decision_index})
			if not gateway.build_request(premature_choice).is_empty():
				_fail("battle request accepted source choice settled before outcome")
				return
			var premature_receipt: Dictionary = pending.duplicate(true)
			premature_receipt["runClock"]["receipts"]["decision:%s:choice:%s:%d" % [
				life_id, card_id, decision_index]] = {"kind": "choice"}
			if not gateway.build_request(premature_receipt).is_empty():
				_fail("battle request accepted premature source decision receipt")
				return
			var unconfirmed: Dictionary = pending.duplicate(true)
			unconfirmed["pendingBattle"]["warningConfirmed"] = false
			if not gateway.build_request(unconfirmed).is_empty():
				_fail("battle request bypassed the warning confirmation")
				return
			var altered_warning: Dictionary = pending.duplicate(true)
			altered_warning["pendingBattle"]["warningChoiceDirection"] = (
				"left" if warning_direction == "right" else "right")
			if not gateway.build_request(altered_warning).is_empty():
				_fail("battle request accepted a changed preparation branch")
				return
			var no_checkpoint: Dictionary = pending.duplicate(true)
			no_checkpoint["decisionCheckpoint"] = null
			if not gateway.build_request(no_checkpoint).is_empty():
				_fail("battle request bypassed the persisted warning checkpoint")
				return
			var advanced_clock: Dictionary = pending.duplicate(true)
			advanced_clock["runClock"]["decisionIndex"] = decision_index
			advanced_clock["turn"] = decision_index
			if not gateway.build_request(advanced_clock).is_empty():
				_fail("battle request accepted a source decision already clocked")
				return
			var no_warning_receipt: Dictionary = pending.duplicate(true)
			no_warning_receipt["runClock"]["preparationReceipts"].clear()
			if not gateway.build_request(no_warning_receipt).is_empty():
				_fail("battle request bypassed durable warning preparation")
				return
			var unpaid_preparation: Dictionary = pending.duplicate(true)
			unpaid_preparation["resources"]["spiritStone"] = before_stones + (
				1 if warning_direction == "right" else 1)
			if not gateway.build_request(unpaid_preparation).is_empty():
				_fail("battle request accepted preparation without matching state cost")
				return
			var unhealed_preparation: Dictionary = pending.duplicate(true)
			unhealed_preparation["attributes"]["health"] = after_health - 1
			if not gateway.build_request(unhealed_preparation).is_empty():
				_fail("battle request accepted preparation with changed healing")
				return
			var no_deck: Dictionary = pending.duplicate(true)
			no_deck["battleLoadout"]["deck"].clear()
			if not gateway.build_request(no_deck).is_empty():
				_fail("battle request silently invented a combat deck")
				return
			var wrong_path_deck: Dictionary = pending.duplicate(true)
			wrong_path_deck["battleLoadout"]["deck"] = ["sword_probe"]
			wrong_path_deck["deck"] = ["sword_probe"]
			if not gateway.build_request(wrong_path_deck).is_empty():
				_fail("battle request accepted a non-source opening deck")
				return
			var no_equipment_authority: Dictionary = pending.duplicate(true)
			no_equipment_authority["battleLoadout"].erase("equipment")
			if not gateway.build_request(no_equipment_authority).is_empty():
				_fail("battle request accepted incomplete loadout authority")
				return
			var no_path_opening: Dictionary = pending.duplicate(true)
			no_path_opening["battleLoadout"]["pathOpening"]["combatOpeningBlock"] = 0 if opening_block == 1 else 1
			if not gateway.build_request(no_path_opening).is_empty():
				_fail("battle request lost source path opening block")
				return
			var truncated_resolution: Dictionary = pending.duplicate(true)
			truncated_resolution["pendingBattle"]["pendingResolution"].erase("choice")
			if not gateway.build_request(truncated_resolution).is_empty():
				_fail("battle request omitted the source combat choice")
				return
			var forged_effects: Dictionary = pending.duplicate(true)
			forged_effects["pendingBattle"]["pendingResolution"]["choice"]["victoryEffects"] = {"cultivation": 999}
			if not gateway.build_request(forged_effects).is_empty():
				_fail("battle request accepted forged source rewards")
				return
			var forged_reward_alias: Dictionary = pending.duplicate(true)
			forged_reward_alias["pendingBattle"]["pendingResolution"]["choice"]["combatRewards"] = {"cultivation": 999}
			if not gateway.build_request(forged_reward_alias).is_empty():
				_fail("battle request accepted forged combat reward alias")
				return
			var forged_template: Dictionary = pending.duplicate(true)
			forged_template["pendingBattle"]["pendingResolution"]["choice"]["enemy"]["templateId"] = "foreign"
			if not gateway.build_request(forged_template).is_empty():
				_fail("battle request accepted a substituted enemy template")
				return
			if path_id in ["body", "pill"]:
				var forged_intents: Dictionary = pending.duplicate(true)
				forged_intents["pendingBattle"]["pendingResolution"]["choice"]["enemy"]["randomIntents"] = true
				if not gateway.build_request(forged_intents).is_empty():
					_fail("battle request accepted changed enemy intent behavior")
					return
			var result := {"contractVersion": 2, "encounterInstanceId": owner,
				"sourceCardId": card_id, "encounterId": offer["encounterId"],
				"sourceContentHash": request["sourceContentHash"],
				"outcome": "victory", "combatReceipt": "combat:" + owner,
				"postBattleState": {"encounterInstanceId": owner, "terminal": true,
					"combatPhase": "VICTORY", "turn": 3}}
			var checked: Dictionary = gateway.validate_result(pending, result)
			if not checked.get("ok", false) or pending["phase"] != "BATTLE_PENDING" \
					or not pending.has("pendingBattle"):
				_fail("valid battle result was rejected or pre-validation mutated state")
				return
			for field in ["encounterInstanceId", "sourceCardId", "encounterId"]:
				var foreign := result.duplicate(true)
				foreign[field] = "foreign"
				if gateway.validate_result(pending, foreign).get("ok", false):
					_fail("foreign result passed ownership field " + field)
					return
			var old_content := result.duplicate(true)
			old_content["sourceContentHash"] = "outdated"
			if gateway.validate_result(pending, old_content).get("ok", false):
				_fail("source content mismatch passed the contract")
				return
			var invalid_outcome := result.duplicate(true)
			invalid_outcome["outcome"] = "unknown"
			if gateway.validate_result(pending, invalid_outcome).get("ok", false):
				_fail("unknown battle outcome passed the contract")
				return
			var empty_state := result.duplicate(true)
			empty_state["postBattleState"] = {}
			if gateway.validate_result(pending, empty_state).get("ok", false):
				_fail("empty battle snapshot passed terminal validation")
				return
			var loose_receipt := result.duplicate(true)
			loose_receipt["combatReceipt"] = "x"
			if gateway.validate_result(pending, loose_receipt).get("ok", false):
				_fail("unowned combat receipt passed validation")
				return
			var no_flee: Dictionary = pending.duplicate(true)
			no_flee["pendingBattle"]["fleeAllowed"] = false
			var fleeing := result.duplicate(true)
			fleeing["outcome"] = "flee"
			if gateway.validate_result(no_flee, fleeing).get("ok", false):
				_fail("forbidden flee passed the contract")
				return
			var stale_pending: Dictionary = pending.duplicate(true)
			stale_pending["pendingBattle"]["sourceContentHash"] = "outdated"
			if not gateway.build_request(stale_pending).is_empty():
				_fail("pending battle with changed source content was accepted")
				return
			var duplicated: Dictionary = pending.duplicate(true)
			duplicated["runClock"]["receipts"]["battle:%s" % owner] = {"outcome": "victory"}
			if gateway.validate_result(duplicated, result).get("ok", false):
				_fail("already settled result passed duplicate guard")
				return
			offers += 1
	print("NONCOMBAT_BATTLE_BOUNDARY_PASS offers=%d pending_contract=8 foreign_rejected=true" % offers)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
