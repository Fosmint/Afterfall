class_name Player
extends CharacterBody2D

# Игрок: изометрическое перемещение, 4-направленная анимация, плавная камера и сбор ресурсов
const BASE_SPEED: float = 132.0
const INTERACT_RADIUS: float = 68.0

var move_input: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2(0, 1)
var facing_key: String = "se"
var is_gathering: bool = false

var _sprite: Sprite2D
var _camera: Camera2D
var _player_light: PointLight2D
var _textures: Dictionary = {}
var _anim_timer: float = 0.0
var _anim_frame: int = 0
var _step_timer: float = 0.0

var _nearest_interactable: Node = null
var _gather_target: WorldObject = null
var _gather_elapsed: float = 0.0
var _gather_duration: float = 1.0
var _world_ctrl: Node = null

func _ready() -> void:
	_load_sprites()
	_sprite = Sprite2D.new()
	_sprite.texture = _textures.get("se_idle", null)
	_sprite.offset = Vector2(0, -18)
	add_child(_sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.45, 1.45)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.5
	_camera.make_current()
	add_child(_camera)

	_player_light = PointLight2D.new()
	_player_light.texture = DataManager.get_texture("res://assets/textures/ui/light_glow.png")
	_player_light.color = Color(1.0, 0.85, 0.58, 1.0)
	_player_light.energy = 0.95
	_player_light.visible = false
	_player_light.position = Vector2(0, -14)
	add_child(_player_light)

	EventBus.equipment_changed.connect(_update_player_light)
	EventBus.settings_changed.connect(func(_s): _update_player_light())

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	_update_player_light()

func _load_sprites() -> void:
	for d in ["se", "sw", "ne", "nw"]:
		for f in ["idle", "walk1", "walk2"]:
			var key := "%s_%s" % [d, f]
			_textures[key] = DataManager.get_texture("res://assets/sprites/player/player_%s.png" % key)

func set_joystick_input(vec: Vector2) -> void:
	move_input = vec

func adjust_camera_zoom(delta_zoom: float) -> void:
	var z := clampf(_camera.zoom.x + delta_zoom, 0.85, 2.35)
	_camera.zoom = Vector2(z, z)

func get_camera() -> Camera2D:
	return _camera

func _physics_process(delta: float) -> void:
	if _world_ctrl == null or _world_ctrl.survival.is_dead:
		return

	# Поддержка клавиатуры (удобно для отладки) + виртуальный джойстик на Android
	var input_vec := move_input
	if input_vec.length_squared() < 0.01:
		var kb := Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		)
		if kb.length_squared() > 0.01:
			input_vec = kb.normalized()

	# Если игрок начал двигаться во время добычи — отменяем добычу
	if is_gathering:
		if input_vec.length() > 0.25:
			_cancel_gathering()
		else:
			_process_gathering(delta)
			return

	var speed := BASE_SPEED
	if _world_ctrl.survival.energy < 15.0:
		speed *= 0.72

	velocity = input_vec * speed
	if velocity.length_squared() > 4.0:
		facing_dir = velocity.normalized()
		_update_facing_key(facing_dir)
		move_and_slide()
		_clamp_to_world_bounds()
		_animate_walk(delta)
		if _world_ctrl.building_system.active:
			_world_ctrl.building_system.update_preview_from_player()
	else:
		_anim_timer = 0.0
		_anim_frame = 0
		_sprite.texture = _textures.get("%s_idle" % facing_key, _sprite.texture)

	_update_nearest_interactable()

func _clamp_to_world_bounds() -> void:
	var g := IsoMath.world_to_grid(position)
	var clamped := Vector2(
		clampf(g.x, 2.0, float(WorldGenerator.MAP_SIZE - 3)),
		clampf(g.y, 2.0, float(WorldGenerator.MAP_SIZE - 3))
	)
	if clamped != g:
		position = IsoMath.grid_to_world(clamped)

func _update_facing_key(dir: Vector2) -> void:
	if dir.y >= 0.0:
		facing_key = "se" if dir.x >= 0.0 else "sw"
	else:
		facing_key = "ne" if dir.x >= 0.0 else "nw"

func _animate_walk(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= 0.16:
		_anim_timer = 0.0
		_anim_frame = 1 if _anim_frame != 1 else 2
		_sprite.texture = _textures.get("%s_walk%d" % [facing_key, _anim_frame], _sprite.texture)

	_step_timer += delta
	if _step_timer >= 0.34:
		_step_timer = 0.0
		var tile := IsoMath.world_to_tile(position)
		var t_type := _world_ctrl.generator.get_tile(tile)
		if t_type == WorldGenerator.TileType.ASPHALT or t_type == WorldGenerator.TileType.ROAD_DAMAGED:
			AudioManager.play_sfx("step_asphalt", 0.12)
		else:
			AudioManager.play_sfx("step_grass", 0.12)

func _update_nearest_interactable() -> void:
	var best: Node = null
	var best_dist := INTERACT_RADIUS
	for node in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(node) or not node.visible:
			continue
		var d := position.distance_to(node.position)
		if d < best_dist:
			best_dist = d
			best = node

	if best != _nearest_interactable:
		_nearest_interactable = best
		if best != null and best.has_method("get_interact_label"):
			EventBus.interactable_changed.emit(best, best.get_interact_label())
		else:
			EventBus.interactable_changed.emit(null, "")

func trigger_interact() -> void:
	if _world_ctrl == null or is_gathering:
		return
	if _world_ctrl.building_system.active:
		_world_ctrl.building_system.confirm_placement()
		return
	if _nearest_interactable == null or not is_instance_valid(_nearest_interactable):
		return

	if _nearest_interactable is BuildingObject:
		(_nearest_interactable as BuildingObject).interact(_world_ctrl)
		# Обновляем подпись кнопки после взаимодействия
		EventBus.interactable_changed.emit(_nearest_interactable, _nearest_interactable.get_interact_label())
	elif _nearest_interactable is WorldObject:
		var obj := _nearest_interactable as WorldObject
		var tool_pow := _world_ctrl.inventory.get_tool_power_for(obj.get_preferred_tool())
		var skill_mult := _world_ctrl.survival.get_gathering_speed_multiplier()
		_gather_target = obj
		_gather_duration = obj.get_gather_time(tool_pow, skill_mult)
		_gather_elapsed = 0.0
		is_gathering = true
		EventBus.gather_progress.emit(true, 0.0, obj.get_interact_label())

func _process_gathering(delta: float) -> void:
	if _gather_target == null or not is_instance_valid(_gather_target):
		_cancel_gathering()
		return
	_gather_elapsed += delta
	var ratio := clampf(_gather_elapsed / _gather_duration, 0.0, 1.0)
	EventBus.gather_progress.emit(true, ratio, _gather_target.get_interact_label())
	if _gather_elapsed >= _gather_duration:
		var res := _gather_target.harvest(_world_ctrl.inventory, _world_ctrl.survival)
		var gained: Dictionary = res["gained"]
		if not gained.is_empty():
			var parts: PackedStringArray = []
			for k in gained.keys():
				parts.append("%s ×%d" % [DataManager.get_item_name(str(k)), int(gained[k])])
			EventBus.notification_requested.emit("+ " + ", ".join(parts), Color(0.68, 0.95, 0.65))
		else:
			EventBus.notification_requested.emit("Ничего полезного не найдено или инвентарь полон.", Color(0.88, 0.78, 0.52))
		_world_ctrl.on_world_object_harvested(_gather_target, bool(res["depleted"]))
		_cancel_gathering()

func _cancel_gathering() -> void:
	is_gathering = false
	_gather_target = null
	_gather_elapsed = 0.0
	EventBus.gather_progress.emit(false, 0.0, "")

func _update_player_light() -> void:
	if _world_ctrl == null or _player_light == null:
		return
	var rad := _world_ctrl.inventory.has_equipped_light()
	var lights_on := bool(GameManager.settings.get("dynamic_lights", true))
	_player_light.visible = lights_on and rad > 0.0
	if rad > 0.0:
		_player_light.texture_scale = rad
