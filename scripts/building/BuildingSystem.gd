class_name BuildingSystem
extends Node2D

# Режим строительства с полупрозрачным изометрическим предпросмотром и проверкой места
var active: bool = false
var selected_building_id: String = ""
var target_tile: Vector2i = Vector2i.ZERO
var can_place_here: bool = false

var _world_ctrl: Node = null
var _ghost_sprite: Sprite2D

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.visible = false
	_ghost_sprite.z_index = 20
	add_child(_ghost_sprite)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)

func _on_build_mode_changed(is_active: bool, building_id: String) -> void:
	active = is_active
	selected_building_id = building_id
	if not active or selected_building_id.is_empty():
		_ghost_sprite.visible = false
		return
	var def := DataManager.get_building(selected_building_id)
	var tex := DataManager.get_texture(str(def.get("sprite", "")))
	_ghost_sprite.texture = tex
	if tex:
		var sz := tex.get_size()
		_ghost_sprite.offset = Vector2.ZERO if bool(def.get("is_floor", false)) else Vector2(0, -sz.y * 0.5 + 8.0)
	_ghost_sprite.visible = true
	update_preview_from_player()

func cancel_build_mode() -> void:
	if active:
		EventBus.build_mode_changed.emit(false, "")

func update_preview_from_player() -> void:
	if not active or _world_ctrl == null or _world_ctrl.player == null:
		return
	var player_pos: Vector2 = _world_ctrl.player.position
	var facing: Vector2 = _world_ctrl.player.facing_dir
	var ahead_world: Vector2 = player_pos + facing * 42.0
	set_target_tile(IsoMath.world_to_tile(ahead_world))

func set_target_world_pos(world_pos: Vector2) -> void:
	if not active:
		return
	set_target_tile(IsoMath.world_to_tile(world_pos))

func set_target_tile(tile: Vector2i) -> void:
	target_tile = tile
	_ghost_sprite.position = IsoMath.tile_center_world(tile)
	can_place_here = check_placement_valid(tile, selected_building_id)
	_ghost_sprite.modulate = Color(0.45, 0.98, 0.52, 0.65) if can_place_here else Color(0.98, 0.35, 0.35, 0.65)

func check_placement_valid(tile: Vector2i, building_id: String) -> bool:
	if _world_ctrl == null:
		return false
	var gen: WorldGenerator = _world_ctrl.generator
	if not gen.is_valid_tile(tile):
		return false
	# Запрещаем строить на занятой объектами мира клетке
	if gen.objects.has(tile):
		return false
	var def := DataManager.get_building(building_id)
	var is_floor := bool(def.get("is_floor", false))
	# Проверяем пересечение с существующими постройками (поверх пола можно ставить мебель/стены)
	if _world_ctrl.has_building_at(tile, is_floor):
		return false
	# Нельзя ставить твёрдую постройку прямо на игрока
	if bool(def.get("solid", true)) and _world_ctrl.player != null:
		var p_tile := IsoMath.world_to_tile(_world_ctrl.player.position)
		if p_tile == tile:
			return false
	# Грядку нельзя ставить на асфальт или камень
	if bool(def.get("is_garden", false)):
		var t := gen.get_tile(tile)
		if t == WorldGenerator.TileType.ASPHALT or t == WorldGenerator.TileType.ROCKY:
			return false
	return true

func confirm_placement() -> bool:
	if not active or selected_building_id.is_empty():
		return false
	if not check_placement_valid(target_tile, selected_building_id):
		EventBus.notification_requested.emit("Здесь нельзя построить!", Color(0.95, 0.45, 0.4))
		return false
	var def := DataManager.get_building(selected_building_id)
	var cost: Dictionary = def.get("cost", {})
	var inv: InventorySystem = _world_ctrl.inventory

	# Проверяем готовый набор (например, campfire_kit или wooden_crate) или сырьё
	var kit_used := false
	if selected_building_id == "campfire" and inv.remove_item("campfire_kit", 1):
		kit_used = true
	elif selected_building_id == "storage_chest" and inv.remove_item("wooden_crate", 1):
		kit_used = true

	if not kit_used:
		if not inv.consume_items(cost):
			EventBus.notification_requested.emit("Недостаточно ресурсов для постройки!", Color(0.95, 0.45, 0.4))
			return false

	_world_ctrl.spawn_building(target_tile, selected_building_id)
	_world_ctrl.survival.add_skill_xp("building", int(def.get("xp", 18)))
	AudioManager.play_sfx("build")
	GameManager.vibrate_short(26)
	EventBus.notification_requested.emit("Построено: %s" % str(def.get("name", selected_building_id)), Color(0.65, 0.95, 0.65))
	cancel_build_mode()
	return true
