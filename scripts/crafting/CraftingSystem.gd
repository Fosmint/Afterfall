class_name CraftingSystem
extends Node

# Система крафта с проверкой ресурсов и ближайших производственных станций
var inventory: InventorySystem
var survival: SurvivalSystem
var nearby_stations: Array[String] = []

func setup(inv: InventorySystem, surv: SurvivalSystem) -> void:
	inventory = inv
	survival = surv

func set_nearby_stations(stations: Array[String]) -> void:
	nearby_stations = stations

func is_station_available(station_type: String) -> bool:
	if station_type == "none" or station_type.is_empty():
		return true
	return nearby_stations.has(station_type)

func can_craft(recipe: Dictionary) -> bool:
	if inventory == null:
		return false
	var station: String = str(recipe.get("station", "none"))
	if not is_station_available(station):
		return false
	var ingredients: Dictionary = recipe.get("ingredients", {})
	return inventory.has_items(ingredients)

func craft(recipe_id: String) -> bool:
	var recipe := _find_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if not can_craft(recipe):
		var station: String = str(recipe.get("station", "none"))
		if not is_station_available(station):
			var st_name := "костёр" if station == "campfire" else "рабочий стол"
			EventBus.notification_requested.emit("Нужен %s поблизости!" % st_name, Color(0.95, 0.55, 0.35))
		else:
			EventBus.notification_requested.emit("Недостаточно материалов!", Color(0.95, 0.5, 0.4))
		return false

	var ingredients: Dictionary = recipe.get("ingredients", {})
	var result_id: String = str(recipe.get("result", ""))
	var amount: int = int(recipe.get("amount", 1))

	if not inventory.consume_items(ingredients):
		return false
	var leftover := inventory.add_item(result_id, amount)
	if leftover > 0:
		# Возвращаем материалы, если инвентарь переполнен
		for k in ingredients.keys():
			inventory.add_item(str(k), int(ingredients[k]))
		EventBus.notification_requested.emit("Инвентарь переполнен!", Color(0.95, 0.45, 0.4))
		return false

	if survival:
		survival.add_skill_xp("crafting", int(recipe.get("xp", 12)))
	AudioManager.play_sfx("craft")
	GameManager.vibrate_short(20)
	var item_name := DataManager.get_item_name(result_id)
	EventBus.notification_requested.emit("Создано: %s ×%d" % [item_name, amount], Color(0.62, 0.92, 0.65))
	return true

func _find_recipe(recipe_id: String) -> Dictionary:
	for r in DataManager.recipes:
		if str(r.get("id", "")) == recipe_id:
			return r
	return {}
