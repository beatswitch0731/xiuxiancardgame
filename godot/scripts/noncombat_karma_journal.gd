extends RefCounted

# Presentation projection of KarmaSystem.getPlantedSeeds. Reads only the current
# run's planted seeds; it never advances their delay or schedules a payoff.
const TYPE_NAMES := {"karma": "善因", "grudge": "恶因",
	"bloodline": "血脉因果", "fate": "宿命因果"}


func entries(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for seed in state.get("karmaSeeds", []):
		if not seed is Dictionary:
			continue
		var raw_type: Variant = seed.get("seedType")
		var seed_type: String = raw_type if raw_type is String and not raw_type.is_empty() \
			else "karma"
		var origin_turn := int(seed.get("originTurn", 0))
		var name: String = TYPE_NAMES.get(seed_type, "善因")
		var fallback := "在第 %d 次决断种下的%s" % [origin_turn,
			TYPE_NAMES.get(seed_type, "因果")] if origin_turn > 0 else \
			"在入世之初种下的%s" % TYPE_NAMES.get(seed_type, "因果")
		var realm: Variant = seed.get("realm")
		var origin_card: Variant = seed.get("originCard")
		var description: Variant = seed.get("description")
		result.append({"id": String(seed.get("id", "")), "seedType": seed_type,
			"seedTypeName": name, "delay": maxi(0, int(seed.get("delay", 0))),
			"realm": realm if realm is String and not realm.is_empty() else "任意境界",
			"path": seed.get("path"), "priority": int(seed.get("priority", 0)),
			"originTurn": origin_turn,
			"originCard": origin_card if origin_card is String and not origin_card.is_empty() \
				else "未知来源",
			"description": description if description is String and not description.is_empty() \
				else fallback})
	return result
