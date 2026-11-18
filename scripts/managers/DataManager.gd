extends Node

# Загрузка и кэширование JSON-баз данных и текстур
var items: Dictionary = {}
var recipes: Array = []
var buildings: Dictionary = {}
var world_objects: Dictionary = {}
var _texture_cache: Dictionary = {}

func _ready() -> void:
	_load_all_data()

func _load_all_data() -> void:
	var items_data := _read_json("res://data/items/items.json")
	items = items_data.get("items", {})
	var recipes_data := _read_json("res://data/recipes/recipes.json")
	recipes = recipes_data.get("recipes", [])
	var buildings_data := _read_json("res://data/buildings/buildings.json")
	buildings = buildings_data.get("buildings", {})
	var world_data := _read_json("res://data/world/loot_tables.json")
	world_objects = world_data.get("world_objects", {})

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataManager: файл не найден: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: ошибка чтения: " + path)
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataManager: некорректный JSON: " + path)
		return {}
	return parsed

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})

func get_item_name(item_id: String) -> String:
	var data: Dictionary = items.get(item_id, {})
	return str(data.get("name", item_id))

func get_building(building_id: String) -> Dictionary:
	return buildings.get(building_id, {})

func get_world_object(obj_id: String) -> Dictionary:
	return world_objects.get(obj_id, {})

func get_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_texture_cache[path] = tex
		return tex
	return null

func get_item_icon(item_id: String) -> Texture2D:
	var data := get_item(item_id)
	return get_texture(str(data.get("icon", "")))
