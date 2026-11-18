class_name WorldController
extends Node2D

# Главный контроллер игрового мира: чанковая оптимизация, Y-sorting, системы, погода и сохранения
var generator: WorldGenerator
var survival: SurvivalSystem
var inventory: InventorySystem
var crafting: CraftingSystem
var building_system: BuildingSystem
var time_weather: TimeWeatherSystem
var player: Player

@onready var ground_layer: Node2D = $GroundLayer
@onready var ysort_layer: Node2D = $YSortLayer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var rain_particles: CPUParticles2D = $RainLayer/RainParticles

var _tile_textures: Dictionary = {}
var _loaded_chunks: Dictionary = {} # Vector2i (chunk) -> GroundChunk
var _spawned_objects: Dictionary = {} # Vector2i (tile) -> WorldObject
var _buildings_by_tile: Dictionary = {} # String key "x,y,floor" -> BuildingObject
var _last_player_chunk: Vector2i = Vector2i(-999, -999)

var _env_check_timer: float = 0.0
var _autosave_timer: float = 0.0

func _ready() -> void:
	GameManager.current_world_node = self
	ysort_layer.y_sort_enabled = true

	# Инициализация систем
	survival = SurvivalSystem.new()
	add_child(survival)

	inventory = InventorySystem.new()
	add_child(inventory)

	crafting = CraftingSystem.new()
	crafting.setup(inventory, survival)
	add_child(crafting)

	time_weather = TimeWeatherSystem.new()
	add_child(time_weather)

	building_system = BuildingSystem.new()
	ysort_layer.add_child(building_system)

	# Предзагрузка текстур тайлов
	for t_type in WorldGenerator.TILE_TEXTURE_PATHS.keys():
		_tile_textures[t_type] = DataManager.get_texture(WorldGenerator.TILE_TEXTURE_PATHS[t_type])

	# Генерация мира по seed
	generator = WorldGenerator.new()
	generator.generate(GameManager.world_seed)

	# Создание персонажа
	player = Player.new()
	ysort_layer.add_child(player)
	player.setup(self)
	building_system.setup(self)
	time_weather.setup(canvas_modulate)

	# Загрузка сохранения или старт новой игры
	if GameManager.is_loading_save and not GameManager.pending_save_data.is_empty():
		_apply_save_data(GameManager.pending_save_data)
		GameManager.is_loading_save = false
		GameManager.pending_save_data = {}
	else:
		player.position = IsoMath.tile_center_world(generator.spawn_tile)
		inventory.give_starter_items()
		EventBus.notification_requested.emit("Выживите в разрушенном мире. Соберите дерево и камень!", Color(0.88, 0.92, 0.78))

	_update_active_chunks(true)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.settings_changed.connect(_on_settings_changed)
	_on_weather_changed(time_weather.current_weather)

func _process(delta: float) -> void:
	if player == null or survival.is_dead:
		return

	# Стриминг чанков только при смене чанка игроком (минимум CPU-нагрузки на Snapdragon 7 Gen 3)
	var p_tile := IsoMath.world_to_tile(player.position)
	var p_chunk := Vector2i(int(floor(float(p_tile.x) / WorldGenerator.CHUNK_SIZE)),
		int(floor(float(p_tile.y) / WorldGenerator.CHUNK_SIZE)))
	if p_chunk != _last_player_chunk:
		_last_player_chunk = p_chunk
		_update_active_chunks(false)

	# Периодическая проверка окружения (костры, навесы, верстаки, POI, тики построек) — 2 раза в сек
	_env_check_timer += delta
	if _env_check_timer >= 0.5:
		_tick_environment(_env_check_timer)
		_env_check_timer = 0.0

	# Автосохранение
	_autosave_timer += delta
	var interval := float(GameManager.settings.get("autosave_interval", 120))
	if interval > 0.0 and _autosave_timer >= interval:
		_autosave_timer = 0.0
		save_world(false)

func _update_active_chunks(force: bool) -> void:
	var radius: int = int(GameManager.settings.get("chunk_view_radius", 2))
	var max_chunk := int(WorldGenerator.MAP_SIZE / WorldGenerator.CHUNK_SIZE) - 1
	var needed: Dictionary = {}

	for cy in range(maxi(0, _last_player_chunk.y - radius), mini(max_chunk, _last_player_chunk.y + radius) + 1):
		for cx in range(maxi(0, _last_player_chunk.x - radius), mini(max_chunk, _last_player_chunk.x + radius) + 1):
			var cc := Vector2i(cx, cy)
			needed[cc] = true
			if not _loaded_chunks.has(cc):
				_load_chunk(cc)

	# Выгружаем дальние чанки и объекты для экономии RAM и FPS
	var to_unload: Array[Vector2i] = []
	for cc in _loaded_chunks.keys():
		if not needed.has(cc):
			to_unload.append(cc)
	for cc in to_unload:
		_unload_chunk(cc)

	if force:
		_last_player_chunk = Vector2i(
			int(floor(float(IsoMath.world_to_tile(player.position).x) / WorldGenerator.CHUNK_SIZE)),
			int(floor(float(IsoMath.world_to_tile(player.position).y) / WorldGenerator.CHUNK_SIZE))
		)

func _load_chunk(cc: Vector2i) -> void:
	var chunk := GroundChunk.new()
	chunk.setup(cc, generator, _tile_textures)
	ground_layer.add_child(chunk)
	_loaded_chunks[cc] = chunk

	var sx := cc.x * WorldGenerator.CHUNK_SIZE
	var sy := cc.y * WorldGenerator.CHUNK_SIZE
	for y in range(sy, mini(sy + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)):
		for x in range(sx, mini(sx + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)):
			var tile := Vector2i(x, y)
			if generator.objects.has(tile) and not _spawned_objects.has(tile):
				var data: Dictionary = generator.objects[tile]
				var obj := WorldObject.new()
				obj.setup(tile, str(data["id"]), int(data["uses_left"]))
				ysort_layer.add_child(obj)
				_spawned_objects[tile] = obj

func _unload_chunk(cc: Vector2i) -> void:
	if _loaded_chunks.has(cc):
		_loaded_chunks[cc].queue_free()
		_loaded_chunks.erase(cc)
	var sx := cc.x * WorldGenerator.CHUNK_SIZE
	var sy := cc.y * WorldGenerator.CHUNK_SIZE
	for y in range(sy, mini(sy + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)):
		for x in range(sx, mini(sx + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)):
			var tile := Vector2i(x, y)
			if _spawned_objects.has(tile):
				_spawned_objects[tile].queue_free()
				_spawned_objects.erase(tile)

func on_world_object_harvested(obj: WorldObject, depleted: bool) -> void:
	var tile := obj.tile_pos
	if depleted:
		generator.objects.erase(tile)
		if _spawned_objects.has(tile):
			_spawned_objects.erase(tile)
		obj.queue_free()
	else:
		if generator.objects.has(tile):
			generator.objects[tile]["uses_left"] = obj.uses_left

func spawn_building(tile: Vector2i, building_id: String, saved_state: Dictionary = {}) -> BuildingObject:
	var b := BuildingObject.new()
	b.setup(tile, building_id, saved_state)
	ysort_layer.add_child(b)
	var key := _building_key(tile, bool(b.def.get("is_floor", false)))
	_buildings_by_tile[key] = b
	return b

func has_building_at(tile: Vector2i, is_floor: bool) -> bool:
	return _buildings_by_tile.has(_building_key(tile, is_floor))

func _building_key(tile: Vector2i, is_floor: bool) -> String:
	return "%d,%d,%s" % [tile.x, tile.y, "F" if is_floor else "B"]

func _tick_environment(dt: float) -> void:
	var near_fire := false
	var under_shelter := false
	var stations: Array[String] = []

	for b in _buildings_by_tile.values():
		if not is_instance_valid(b):
			continue
		var bo := b as BuildingObject
		bo.tick_building(dt, time_weather.current_weather)
		var dist := player.position.distance_to(bo.position)
		if dist < 135.0:
			var st := str(bo.def.get("station_type", ""))
			if not st.is_empty():
				if st == "campfire":
					if bo.is_lit:
						near_fire = true
						if not stations.has("campfire"):
							stations.append("campfire")
				elif not stations.has(st):
					stations.append(st)
			if bool(bo.def.get("provides_shelter", false)):
				under_shelter = true

	survival.is_near_fire = near_fire
	survival.is_under_shelter = under_shelter
	crafting.set_nearby_stations(stations)
	AudioManager.set_campfire_ambient(near_fire)

	# Проверка открытия новых локаций (POI)
	var p_tile := IsoMath.world_to_tile(player.position)
	for poi in generator.pois:
		if not bool(poi["discovered"]):
			var pt: Vector2i = poi["tile"]
			if p_tile.distance_to(pt) <= 6.5:
				poi["discovered"] = true
				var p_name := str(poi["name"])
				survival.add_skill_xp("survival", 35)
				AudioManager.play_sfx("level_up", 0.04)
				EventBus.poi_discovered.emit(p_name, 35)
				EventBus.notification_requested.emit("Открыта локация: %s (+35 опыта)" % p_name, Color(0.98, 0.85, 0.42))

func _on_weather_changed(weather: String) -> void:
	if rain_particles == null:
		return
	var allow := bool(GameManager.settings.get("particles_enabled", true))
	rain_particles.emitting = allow and (weather == "rain" or weather == "storm")
	rain_particles.amount = 140 if weather == "storm" else 75

func _on_settings_changed(settings: Dictionary) -> void:
	var lights := bool(settings.get("dynamic_lights", true))
	for b in _buildings_by_tile.values():
		if is_instance_valid(b):
			(b as BuildingObject).update_light_setting(lights)
	_on_weather_changed(time_weather.current_weather)
	_update_active_chunks(false)

func save_world(is_manual: bool = true) -> bool:
	var world_objs_state: Array = []
	for tile in generator.objects.keys():
		var d: Dictionary = generator.objects[tile]
		world_objs_state.append({
			"x": tile.x,
			"y": tile.y,
			"id": d["id"],
			"u": d["uses_left"]
		})

	var buildings_state: Array = []
	for b in _buildings_by_tile.values():
		if is_instance_valid(b):
			buildings_state.append((b as BuildingObject).to_save_dict())

	var discovered_pois: Array = []
	for poi in generator.pois:
		if bool(poi["discovered"]):
			discovered_pois.append(str(poi["name"]))

	var save_dict := {
		"world_seed": generator.seed_val,
		"player": {
			"x": player.position.x,
			"y": player.position.y,
			"facing": player.facing_key
		},
		"survival": survival.to_save_dict(),
		"inventory": inventory.to_save_dict(),
		"time": time_weather.to_save_dict(),
		"world_objects": world_objs_state,
		"buildings": buildings_state,
		"discovered_pois": discovered_pois
	}
	return SaveManager.save_game_data(save_dict, is_manual)

func _apply_save_data(data: Dictionary) -> void:
	var p_data: Dictionary = data.get("player", {})
	player.position = Vector2(float(p_data.get("x", 0.0)), float(p_data.get("y", 0.0)))
	player.facing_key = str(p_data.get("facing", "se"))

	survival.load_from_dict(data.get("survival", {}))
	inventory.load_from_dict(data.get("inventory", {}))
	time_weather.load_from_dict(data.get("time", {}))

	# Восстанавливаем оставшиеся объекты мира
	var saved_objs = data.get("world_objects", [])
	if typeof(saved_objs) == TYPE_ARRAY and not saved_objs.is_empty():
		generator.objects.clear()
		for o in saved_objs:
			var t := Vector2i(int(o["x"]), int(o["y"]))
			generator.objects[t] = {
				"id": str(o["id"]),
				"uses_left": int(o["u"]),
				"poi": ""
			}

	# Восстанавливаем постройки игрока
	var saved_buildings = data.get("buildings", [])
	if typeof(saved_buildings) == TYPE_ARRAY:
		for bd in saved_buildings:
			var arr: Array = bd.get("tile", [50, 50])
			spawn_building(Vector2i(int(arr[0]), int(arr[1])), str(bd["id"]), bd)

	# Восстанавливаем открытые POI
	var disc = data.get("discovered_pois", [])
	if typeof(disc) == TYPE_ARRAY:
		for poi in generator.pois:
			if disc.has(str(poi["name"])):
				poi["discovered"] = true

	EventBus.notification_requested.emit("Сохранение загружено.", Color(0.68, 0.9, 0.96))
