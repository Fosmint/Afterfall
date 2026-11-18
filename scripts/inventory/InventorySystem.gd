class_name InventorySystem
extends Node

# Инвентарь игрока: слоты, экипировка, быстрая панель и перенос в хранилище
var max_slots: int = 24
var slots: Array = [] # Array of Dictionary: { "id": String, "count": int, "durability": int }
var equipped_tool_id: String = ""
var equipped_tool_durability: int = 0
var quickbar_ids: Array[String] = ["berries", "clean_water", "bandage", "torch"]

func _ready() -> void:
	_ensure_slot_count()

func _ensure_slot_count() -> void:
	while slots.size() < max_slots:
		slots.append(null)

func give_starter_items() -> void:
	clear()
	add_item("canned_food", 2)
	add_item("clean_water", 2)
	add_item("bandage", 2)
	add_item("wood", 4)
	add_item("stone", 2)
	add_item("cloth", 2)

func clear() -> void:
	slots.clear()
	_ensure_slot_count()
	equipped_tool_id = ""
	equipped_tool_durability = 0
	EventBus.inventory_changed.emit()
	EventBus.equipment_changed.emit()

func add_item(item_id: String, amount: int = 1, durability: int = -1) -> int:
	var item_def := DataManager.get_item(item_id)
	if item_def.is_empty() or amount <= 0:
		return amount
	var max_stack: int = int(item_def.get("max_stack", 20))
	var remaining := amount

	# Сначала докладываем в существующие стопки
	if max_stack > 1:
		for i in range(slots.size()):
			if slots[i] != null and slots[i]["id"] == item_id:
				var space := max_stack - int(slots[i]["count"])
				if space > 0:
					var to_add := mini(space, remaining)
					slots[i]["count"] = int(slots[i]["count"]) + to_add
					remaining -= to_add
					if remaining <= 0:
						break

	# Затем в пустые слоты
	while remaining > 0:
		var empty_idx := _find_empty_slot()
		if empty_idx == -1:
			break
		var to_add := mini(max_stack, remaining)
		var entry := { "id": item_id, "count": to_add }
		if item_def.has("durability"):
			entry["durability"] = durability if durability > 0 else int(item_def["durability"])
		slots[empty_idx] = entry
		remaining -= to_add

	EventBus.inventory_changed.emit()
	return remaining # 0 если всё поместилось

func remove_item(item_id: String, amount: int = 1) -> bool:
	if get_item_count(item_id) < amount:
		return false
	var remaining := amount
	for i in range(slots.size() - 1, -1, -1):
		if slots[i] != null and slots[i]["id"] == item_id:
			var take := mini(int(slots[i]["count"]), remaining)
			slots[i]["count"] = int(slots[i]["count"]) - take
			remaining -= take
			if int(slots[i]["count"]) <= 0:
				slots[i] = null
			if remaining <= 0:
				break
	EventBus.inventory_changed.emit()
	return true

func remove_at_slot(slot_idx: int, amount: int = 1) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size() or slots[slot_idx] == null:
		return {}
	var entry: Dictionary = slots[slot_idx]
	var take := mini(int(entry["count"]), amount)
	var removed := { "id": entry["id"], "count": take }
	if entry.has("durability"):
		removed["durability"] = entry["durability"]
	entry["count"] = int(entry["count"]) - take
	if int(entry["count"]) <= 0:
		slots[slot_idx] = null
	EventBus.inventory_changed.emit()
	return removed

func get_item_count(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == item_id:
			total += int(s["count"])
	return total

func has_items(requirements: Dictionary) -> bool:
	for item_id in requirements.keys():
		if get_item_count(str(item_id)) < int(requirements[item_id]):
			return false
	return true

func consume_items(requirements: Dictionary) -> bool:
	if not has_items(requirements):
		return false
	for item_id in requirements.keys():
		remove_item(str(item_id), int(requirements[item_id]))
	return true

func use_slot(slot_idx: int, survival: SurvivalSystem) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size() or slots[slot_idx] == null:
		return false
	var entry: Dictionary = slots[slot_idx]
	var item_id: String = str(entry["id"])
	var item_def := DataManager.get_item(item_id)
	if item_def.is_empty():
		return false

	# Экипировка инструмента
	if bool(item_def.get("equippable", false)):
		var old_id := equipped_tool_id
		var old_dur := equipped_tool_durability
		equipped_tool_id = item_id
		equipped_tool_durability = int(entry.get("durability", int(item_def.get("durability", 100))))
		slots[slot_idx] = null
		if not old_id.is_empty():
			add_item(old_id, 1, old_dur)
		AudioManager.play_sfx("ui_click")
		EventBus.notification_requested.emit("Экипировано: %s" % item_def["name"], Color(0.85, 0.92, 0.78))
		EventBus.inventory_changed.emit()
		EventBus.equipment_changed.emit()
		return true

	# Улучшения (рюкзак, тёплая куртка)
	if item_def.has("upgrade_type"):
		var upg: String = str(item_def["upgrade_type"])
		if upg == "backpack":
			if max_slots >= 32:
				EventBus.notification_requested.emit("Рюкзак уже улучшен!", Color(0.9, 0.7, 0.4))
				return false
			max_slots = 32
			_ensure_slot_count()
			remove_at_slot(slot_idx, 1)
			AudioManager.play_sfx("level_up")
			EventBus.notification_requested.emit("Инвентарь расширен до 32 слотов!", Color(0.55, 0.92, 0.6))
			return true
		elif upg == "coat":
			if survival.has_warm_coat:
				EventBus.notification_requested.emit("Тёплая куртка уже надета!", Color(0.9, 0.7, 0.4))
				return false
			survival.has_warm_coat = true
			remove_at_slot(slot_idx, 1)
			AudioManager.play_sfx("level_up")
			EventBus.notification_requested.emit("Надета тёплая куртка (-50% потери тепла)!", Color(0.95, 0.82, 0.5))
			EventBus.stats_changed.emit(survival.get_stats_dict())
			return true

	# Наборы для строительства
	if item_def.has("place_building"):
		var b_id: String = str(item_def["place_building"])
		EventBus.build_mode_changed.emit(true, b_id)
		return true

	# Расходуемые предметы (еда, вода, медицина)
	if bool(item_def.get("usable", false)) and item_def.has("effects"):
		var effects: Dictionary = item_def["effects"]
		survival.apply_item_effects(effects)
		remove_at_slot(slot_idx, 1)
		if float(effects.get("thirst", 0)) > float(effects.get("hunger", 0)):
			AudioManager.play_sfx("drink")
		else:
			AudioManager.play_sfx("eat")
		EventBus.notification_requested.emit("Использовано: %s" % item_def["name"], Color(0.7, 0.92, 0.72))
		return true

	return false

func use_item_by_id(item_id: String, survival: SurvivalSystem) -> bool:
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["id"] == item_id:
			return use_slot(i, survival)
	return false

func get_tool_power_for(preferred_tool: String) -> float:
	if equipped_tool_id.is_empty():
		return 1.0
	var def := DataManager.get_item(equipped_tool_id)
	var t_type: String = str(def.get("tool_type", ""))
	if t_type == preferred_tool:
		return float(def.get("power", 1.5))
	if t_type == "universal":
		return float(def.get("power", 1.4))
	return 1.05

func damage_equipped_tool(amount: int = 1) -> void:
	if equipped_tool_id.is_empty():
		return
	equipped_tool_durability -= amount
	if equipped_tool_durability <= 0:
		var old_name := DataManager.get_item_name(equipped_tool_id)
		equipped_tool_id = ""
		equipped_tool_durability = 0
		EventBus.notification_requested.emit("Инструмент сломался: %s" % old_name, Color(0.95, 0.45, 0.4))
	EventBus.equipment_changed.emit()

func has_equipped_light() -> float:
	if equipped_tool_id.is_empty():
		return 0.0
	var def := DataManager.get_item(equipped_tool_id)
	if str(def.get("tool_type", "")) == "light":
		return float(def.get("light_radius", 1.6))
	return 0.0

func _find_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1

func to_save_dict() -> Dictionary:
	return {
		"max_slots": max_slots,
		"slots": slots.duplicate(true),
		"equipped_tool_id": equipped_tool_id,
		"equipped_tool_durability": equipped_tool_durability,
		"quickbar_ids": quickbar_ids.duplicate()
	}

func load_from_dict(data: Dictionary) -> void:
	max_slots = int(data.get("max_slots", 24))
	slots = []
	var saved_slots = data.get("slots", [])
	if typeof(saved_slots) == TYPE_ARRAY:
		for s in saved_slots:
			slots.append(s)
	_ensure_slot_count()
	equipped_tool_id = str(data.get("equipped_tool_id", ""))
	equipped_tool_durability = int(data.get("equipped_tool_durability", 0))
	EventBus.inventory_changed.emit()
	EventBus.equipment_changed.emit()
