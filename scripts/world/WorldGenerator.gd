class_name WorldGenerator
extends RefCounted

# Процедурный генератор изометрического мира 100x100 с биомами, дорогами и POI
const MAP_SIZE: int = 100
const CHUNK_SIZE: int = 10

# Типы тайлов местности
enum TileType {
	GRASS = 0,
	DIRT = 1,
	ASPHALT = 2,
	ROAD_DAMAGED = 3,
	ROCKY = 4,
	FOREST = 5
}

const TILE_TEXTURE_PATHS := {
	TileType.GRASS: "res://assets/sprites/tiles/grass.png",
	TileType.DIRT: "res://assets/sprites/tiles/dirt.png",
	TileType.ASPHALT: "res://assets/sprites/tiles/asphalt.png",
	TileType.ROAD_DAMAGED: "res://assets/sprites/tiles/road_damaged.png",
	TileType.ROCKY: "res://assets/sprites/tiles/rocky.png",
	TileType.FOREST: "res://assets/sprites/tiles/forest.png"
}

var seed_val: int = 12345
var tiles: PackedByteArray = PackedByteArray()
# Ключ: Vector2i -> Dictionary { "id": String, "uses_left": int, "poi": String }
var objects: Dictionary = {}
# Список интересных мест для системы открытий: Array[Dictionary]
var pois: Array = []
var spawn_tile: Vector2i = Vector2i(50, 50)

func generate(world_seed: int) -> void:
	seed_val = world_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var noise_biome := FastNoiseLite.new()
	noise_biome.seed = world_seed
	noise_biome.frequency = 0.032

	var noise_detail := FastNoiseLite.new()
	noise_detail.seed = world_seed + 7919
	noise_detail.frequency = 0.09

	tiles.resize(MAP_SIZE * MAP_SIZE)
	objects.clear()
	pois.clear()

	# 1. Базовая генерация рельефа и биомов
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			var b := noise_biome.get_noise_2d(float(x), float(y))
			var d := noise_detail.get_noise_2d(float(x), float(y))
			var t := TileType.GRASS
			if b > 0.24:
				t = TileType.FOREST
			elif b < -0.30:
				t = TileType.ROCKY
			elif d > 0.34:
				t = TileType.DIRT
			tiles[y * MAP_SIZE + x] = t

	# 2. Связная дорожная сеть (главное шоссе + поперечная улица + ответвления)
	var main_road_y: int = 46 + rng.randi_range(-3, 3)
	var cross_road_x: int = 54 + rng.randi_range(-3, 3)
	for x in range(4, MAP_SIZE - 4):
		for dy in range(-1, 2):
			var ry := clampi(main_road_y + dy, 2, MAP_SIZE - 3)
			var is_broken := rng.randf() < (0.35 if dy != 0 else 0.18)
			tiles[ry * MAP_SIZE + x] = TileType.ROAD_DAMAGED if is_broken else TileType.ASPHALT
	for y in range(4, MAP_SIZE - 4):
		for dx in range(-1, 2):
			var rx := clampi(cross_road_x + dx, 2, MAP_SIZE - 3)
			var is_broken := rng.randf() < (0.35 if dx != 0 else 0.2)
			tiles[y * MAP_SIZE + rx] = TileType.ROAD_DAMAGED if is_broken else TileType.ASPHALT

	# Точка спавна — расчищенная поляна рядом с перекрёстком
	spawn_tile = Vector2i(cross_road_x - 4, main_road_y + 4)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var p := spawn_tile + Vector2i(dx, dy)
			if is_valid_tile(p):
				tiles[p.y * MAP_SIZE + p.x] = TileType.GRASS if (abs(dx) + abs(dy) > 2) else TileType.DIRT

	# 3. Размещение ключевых локаций (POI) вдоль дорог и в окрестностях
	_place_poi("Заброшенный магазин", Vector2i(cross_road_x + 7, main_road_y - 6), "shop_ruin",
		["crate_wood", "trash_pile", "car_wreck_blue"], rng)
	_place_poi("Разрушенная АЗС", Vector2i(cross_road_x - 16, main_road_y - 5), "gas_station",
		["car_wreck_rust", "barrel_rust", "barrel_rust", "road_sign"], rng)
	_place_poi("Старый склад", Vector2i(cross_road_x + 15, main_road_y + 9), "warehouse_ruin",
		["container_metal", "crate_wood", "crate_wood", "barrel_rust"], rng)
	_place_poi("Заброшенный квартал", Vector2i(cross_road_x - 10, main_road_y + 18), "house_ruin",
		["house_ruin", "car_wreck_rust", "crate_wood", "trash_pile"], rng)
	_place_poi("Стоянка выживших", Vector2i(cross_road_x - 18, main_road_y - 18), "camp_tent",
		["crate_wood", "fallen_log", "bush_berry"], rng)
	_place_poi("Северные руины", Vector2i(cross_road_x + 8, main_road_y - 24), "house_ruin",
		["container_metal", "car_wreck_blue", "trash_pile"], rng)
	_place_poi("Восточный терминал", Vector2i(cross_road_x + 26, main_road_y - 4), "warehouse_ruin",
		["container_metal", "barrel_rust", "car_wreck_rust", "road_sign"], rng)

	# 4. Наполнение мира природными ресурсами, обломками и транспортом
	for y in range(2, MAP_SIZE - 2):
		for x in range(2, MAP_SIZE - 2):
			var pos := Vector2i(x, y)
			if pos.distance_to(spawn_tile) < 4.2:
				continue
			if objects.has(pos):
				continue
			var t := get_tile(pos)
			var r := rng.randf()
			match t:
				TileType.FOREST:
					if r < 0.20:
						_add_obj(pos, "tree_pine")
					elif r < 0.25:
						_add_obj(pos, "bush_berry")
					elif r < 0.28:
						_add_obj(pos, "fallen_log")
				TileType.GRASS:
					if r < 0.045:
						_add_obj(pos, "tree_pine")
					elif r < 0.065:
						_add_obj(pos, "tree_dead")
					elif r < 0.095:
						_add_obj(pos, "bush_berry")
					elif r < 0.115:
						_add_obj(pos, "bush_dry")
					elif r < 0.13:
						_add_obj(pos, "rock_large")
					elif r < 0.138:
						_add_obj(pos, "crate_wood")
					elif r < 0.144:
						_add_obj(pos, "trash_pile")
				TileType.DIRT:
					if r < 0.04:
						_add_obj(pos, "bush_dry")
					elif r < 0.07:
						_add_obj(pos, "rock_large")
					elif r < 0.085:
						_add_obj(pos, "barrel_rust")
					elif r < 0.095:
						_add_obj(pos, "trash_pile")
				TileType.ROCKY:
					if r < 0.15:
						_add_obj(pos, "rock_large")
					elif r < 0.18:
						_add_obj(pos, "tree_dead")
					elif r < 0.195:
						_add_obj(pos, "barrel_rust")
				TileType.ASPHALT, TileType.ROAD_DAMAGED:
					if r < 0.016:
						_add_obj(pos, "car_wreck_rust" if rng.randf() < 0.6 else "car_wreck_blue")
					elif r < 0.024:
						_add_obj(pos, "trash_pile")
					elif r < 0.03:
						_add_obj(pos, "road_sign")

	# Гарантируем стартовые ресурсы рядом со спавном для плавного начала игры
	_add_obj(spawn_tile + Vector2i(3, -1), "tree_pine")
	_add_obj(spawn_tile + Vector2i(-3, 2), "rock_large")
	_add_obj(spawn_tile + Vector2i(2, 3), "bush_berry")
	_add_obj(spawn_tile + Vector2i(-2, -3), "crate_wood")
	_add_obj(spawn_tile + Vector2i(4, 2), "car_wreck_rust")

func _place_poi(poi_name: String, center: Vector2i, main_obj: String, props: Array, rng: RandomNumberGenerator) -> void:
	center.x = clampi(center.x, 8, MAP_SIZE - 9)
	center.y = clampi(center.y, 8, MAP_SIZE - 9)
	pois.append({
		"name": poi_name,
		"tile": center,
		"discovered": false
	})
	# Расчищаем асфальтовую/земляную площадку под локацию
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var p := center + Vector2i(dx, dy)
			if is_valid_tile(p):
				tiles[p.y * MAP_SIZE + p.x] = TileType.ROAD_DAMAGED if rng.randf() < 0.5 else TileType.DIRT
				objects.erase(p)
	_add_obj(center, main_obj, poi_name)
	var offsets: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2),
		Vector2i(-2, -2), Vector2i(3, 0), Vector2i(0, 3)
	]
	for i in range(mini(props.size(), offsets.size())):
		var p: Vector2i = center + offsets[i]
		if is_valid_tile(p) and not objects.has(p):
			_add_obj(p, str(props[i]))

func _add_obj(tile: Vector2i, obj_id: String, poi_name: String = "") -> void:
	var def := DataManager.get_world_object(obj_id)
	var max_uses := int(def.get("max_uses", 1))
	objects[tile] = {
		"id": obj_id,
		"uses_left": max_uses,
		"poi": poi_name
	}

func is_valid_tile(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < MAP_SIZE and tile.y < MAP_SIZE

func get_tile(tile: Vector2i) -> int:
	if not is_valid_tile(tile):
		return TileType.ROCKY
	return int(tiles[tile.y * MAP_SIZE + tile.x])

func is_tile_blocked_by_world(tile: Vector2i) -> bool:
	if not is_valid_tile(tile):
		return true
	if objects.has(tile):
		var obj_data: Dictionary = objects[tile]
		var def := DataManager.get_world_object(str(obj_data["id"]))
		return bool(def.get("solid", true))
	return false
