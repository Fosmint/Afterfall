class_name BuildingObject
extends StaticBody2D

# Построенный игроком объект убежища (костёр, хранилище, кровать, верстак, сборщик воды, грядка и т.д.)
var tile_pos: Vector2i = Vector2i.ZERO
var building_id: String = ""
var def: Dictionary = {}

# Динамическое состояние постройки
var is_lit: bool = true
var storage_slots: Array = []
var water_stored: float = 0.0
var garden_planted: bool = false
var garden_growth: float = 0.0 # 0.0 .. 1.0

var _sprite: Sprite2D
var _light: PointLight2D
var _flicker_t: float = 0.0

func setup(tile: Vector2i, b_id: String, saved_state: Dictionary = {}) -> void:
	tile_pos = tile
	building_id = b_id
	def = DataManager.get_building(b_id)
	position = IsoMath.tile_center_world(tile)

	if bool(def.get("is_floor", false)):
		z_index = -5

	# Восстановление состояния
	is_lit = bool(saved_state.get("is_lit", true))
	water_stored = float(saved_state.get("water_stored", 0.0))
	garden_planted = bool(saved_state.get("garden_planted", false))
	garden_growth = float(saved_state.get("garden_growth", 0.0))

	if bool(def.get("is_storage", false)):
		var cap := int(def.get("storage_slots", 16))
		storage_slots.clear()
		var saved_slots = saved_state.get("storage_slots", [])
		for i in range(cap):
			if typeof(saved_slots) == TYPE_ARRAY and i < saved_slots.size():
				storage_slots.append(saved_slots[i])
			else:
				storage_slots.append(null)

	_sprite = Sprite2D.new()
	_refresh_sprite()
	add_child(_sprite)

	if bool(def.get("solid", true)):
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 15.0
		col.shape = shape
		add_child(col)

	if bool(def.get("provides_light", false)):
		_light = PointLight2D.new()
		_light.texture = DataManager.get_texture("res://assets/textures/ui/light_glow.png")
		var radius := float(def.get("light_radius", 2.4))
		_light.texture_scale = radius
		_light.color = Color(1.0, 0.72, 0.36, 1.0)
		_light.energy = 1.15 if is_lit else 0.0
		_light.position = Vector2(0, -14)
		_light.visible = bool(GameManager.settings.get("dynamic_lights", true)) and is_lit
		add_child(_light)

	if def.has("interact_verb"):
		add_to_group("interactables")
	add_to_group("buildings")

func _refresh_sprite() -> void:
	var path := str(def.get("sprite", ""))
	if not is_lit and def.has("sprite_unlit"):
		path = str(def["sprite_unlit"])
	var tex := DataManager.get_texture(path)
	_sprite.texture = tex
	if tex:
		var sz := tex.get_size()
		if bool(def.get("is_floor", false)):
			_sprite.offset = Vector2(0, 0)
		else:
			_sprite.offset = Vector2(0, -sz.y * 0.5 + 8.0)

func tick_building(dt: float, weather: String) -> void:
	# Мягкое мерцание огня
	if _light and is_lit and _light.visible:
		_flicker_t += dt * 5.0
		_light.energy = 1.08 + sin(_flicker_t) * 0.1

	# Сбор дождевой воды
	if bool(def.get("is_rain_collector", false)):
		var rate := 0.012
		if weather == "rain":
			rate = 0.09
		elif weather == "storm":
			rate = 0.14
		water_stored = minf(3.0, water_stored + rate * dt)

	# Рост овощей на грядке
	if bool(def.get("is_garden", false)) and garden_planted and garden_growth < 1.0:
		var grow_rate := 0.012 if (weather == "rain" or weather == "storm") else 0.007
		garden_growth = minf(1.0, garden_growth + grow_rate * dt)

func update_light_setting(enabled: bool) -> void:
	if _light:
		_light.visible = enabled and is_lit

func get_interact_label() -> String:
	if bool(def.get("is_rain_collector", false)):
		return "Набрать воду (%d/3)" % int(floor(water_stored))
	if bool(def.get("is_garden", false)):
		if not garden_planted:
			return "Посадить семена"
		if garden_growth >= 1.0:
			return "Собрать урожай"
		return "Растёт (%d%%)" % int(garden_growth * 100.0)
	return str(def.get("interact_verb", str(def.get("name", building_id))))

func interact(world_ctrl: Node) -> void:
	var inv: InventorySystem = world_ctrl.inventory
	var surv: SurvivalSystem = world_ctrl.survival
	var time_sys: TimeWeatherSystem = world_ctrl.time_weather

	if bool(def.get("is_storage", false)):
		AudioManager.play_sfx("ui_click")
		EventBus.storage_opened.emit(self)
		return

	if bool(def.get("is_bed", false)):
		surv.rest_on_bed()
		time_sys.advance_hours(6.0)
		AudioManager.play_sfx("level_up", 0.05)
		EventBus.notification_requested.emit("Вы отдохнули 6 часов. Энергия и здоровье восстановлены.", Color(0.68, 0.88, 0.96))
		world_ctrl.save_world(false)
		return

	if str(def.get("station_type", "")) == "workbench":
		AudioManager.play_sfx("ui_click")
		EventBus.open_crafting_station.emit("workbench")
		return

	if bool(def.get("is_rain_collector", false)):
		var bottles := int(floor(water_stored))
		if bottles <= 0:
			EventBus.notification_requested.emit("Воды ещё мало — подождите дождя.", Color(0.75, 0.85, 0.95))
			return
		var left := inv.add_item("clean_water", bottles)
		var taken := bottles - left
		if taken > 0:
			water_stored -= float(taken)
			AudioManager.play_sfx("drink")
			EventBus.notification_requested.emit("Набрано чистой воды: ×%d" % taken, Color(0.6, 0.88, 0.98))
		else:
			EventBus.notification_requested.emit("Инвентарь переполнен!", Color(0.95, 0.45, 0.4))
		return

	if bool(def.get("is_garden", false)):
		if not garden_planted:
			if inv.remove_item("seeds", 1):
				garden_planted = true
				garden_growth = 0.0
				AudioManager.play_sfx("pickup")
				EventBus.notification_requested.emit("Семена посажены! Урожай созреет со временем.", Color(0.65, 0.92, 0.6))
			else:
				EventBus.notification_requested.emit("Нужны семена (находятся в кустах и домах).", Color(0.92, 0.72, 0.45))
		elif garden_growth >= 1.0:
			inv.add_item("vegetables", randi_range(2, 3))
			inv.add_item("seeds", 1)
			garden_planted = false
			garden_growth = 0.0
			surv.add_skill_xp("survival", 18)
			AudioManager.play_sfx("pickup")
			EventBus.notification_requested.emit("Собран урожай свежих овощей!", Color(0.62, 0.95, 0.58))
		else:
			EventBus.notification_requested.emit("Урожай ещё растёт (%d%%)." % int(garden_growth * 100.0), Color(0.85, 0.9, 0.7))
		return

	if building_id == "campfire" or building_id == "furnace":
		if not is_lit:
			if inv.remove_item("wood", 1):
				is_lit = true
				_refresh_sprite()
				update_light_setting(bool(GameManager.settings.get("dynamic_lights", true)))
				AudioManager.play_sfx("build")
				EventBus.notification_requested.emit("Огонь разведён!", Color(1.0, 0.78, 0.4))
			else:
				EventBus.notification_requested.emit("Нужна древесина для розжига.", Color(0.95, 0.55, 0.4))
		else:
			EventBus.open_crafting_station.emit("campfire")
		return

	if building_id == "lantern_post":
		is_lit = not is_lit
		update_light_setting(bool(GameManager.settings.get("dynamic_lights", true)))
		AudioManager.play_sfx("ui_click")

func to_save_dict() -> Dictionary:
	return {
		"tile": [tile_pos.x, tile_pos.y],
		"id": building_id,
		"is_lit": is_lit,
		"storage_slots": storage_slots.duplicate(true),
		"water_stored": water_stored,
		"garden_planted": garden_planted,
		"garden_growth": garden_growth
	}
