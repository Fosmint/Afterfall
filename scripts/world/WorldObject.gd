class_name WorldObject
extends StaticBody2D

# Интерактивный объект окружающего мира (дерево, камень, авто, ящик, руины)
var tile_pos: Vector2i = Vector2i.ZERO
var object_id: String = ""
var uses_left: int = 1
var def: Dictionary = {}

var _sprite: Sprite2D
var _collision: CollisionShape2D

func setup(tile: Vector2i, obj_id: String, remaining_uses: int) -> void:
	tile_pos = tile
	object_id = obj_id
	uses_left = remaining_uses
	def = DataManager.get_world_object(obj_id)

	position = IsoMath.tile_center_world(tile)
	y_sort_enabled = false

	_sprite = Sprite2D.new()
	var tex := DataManager.get_texture(str(def.get("sprite", "")))
	_sprite.texture = tex
	if tex:
		# Якорь внизу по центру — для точного Y-sorting в изометрии
		var sz := tex.get_size()
		_sprite.offset = Vector2(0, -sz.y * 0.5 + 8.0)
	add_child(_sprite)

	if bool(def.get("solid", true)):
		_collision = CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 16.0 if str(def.get("type", "")) != "building_poi" else 28.0
		_collision.shape = shape
		add_child(_collision)

	add_to_group("interactables")

func get_interact_label() -> String:
	var verb := str(def.get("interact_verb", "Взаимодействовать"))
	var obj_name := str(def.get("name", object_id))
	return "%s (%s)" % [verb, obj_name]

func get_gather_time(tool_power: float, skill_mult: float) -> float:
	var base := float(def.get("gather_time", 1.2))
	return clampf(base / maxf(0.5, tool_power * skill_mult), 0.35, 3.0)

func get_preferred_tool() -> String:
	return str(def.get("preferred_tool", "none"))

func harvest(inventory: InventorySystem, survival: SurvivalSystem) -> Dictionary:
	var gained: Dictionary = {}
	var drops: Array = def.get("drops", [])
	var bonus_chance := survival.get_bonus_drop_chance()
	for d in drops:
		if randf() <= float(d.get("chance", 1.0)):
			var item_id := str(d["item"])
			var qty := randi_range(int(d.get("min", 1)), int(d.get("max", 1)))
			if randf() < bonus_chance:
				qty += 1
			var leftover := inventory.add_item(item_id, qty)
			var added := qty - leftover
			if added > 0:
				gained[item_id] = int(gained.get(item_id, 0)) + added

	uses_left -= 1
	var sfx := str(def.get("sound", "pickup"))
	AudioManager.play_sfx(sfx)
	GameManager.vibrate_short(18)
	survival.consume_energy(2.5)
	survival.add_skill_xp("gathering", 12)
	inventory.damage_equipped_tool(1)

	# Лёгкая отдача спрайта при добыче
	if _sprite:
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", Vector2(1.08, 0.92), 0.07)
		tw.tween_property(_sprite, "scale", Vector2.ONE, 0.09)

	return {
		"gained": gained,
		"depleted": uses_left <= 0
	}
