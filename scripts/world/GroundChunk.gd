class_name GroundChunk
extends Node2D

# Отрисовка одного чанка земли 10x10 тайлов за минимальное число draw calls
var chunk_coord: Vector2i = Vector2i.ZERO
var _generator: WorldGenerator = null
var _tile_textures: Dictionary = {}

func setup(coord: Vector2i, generator: WorldGenerator, textures: Dictionary) -> void:
	chunk_coord = coord
	_generator = generator
	_tile_textures = textures
	z_index = -10
	queue_redraw()

func _draw() -> void:
	if _generator == null:
		return
	var start_x := chunk_coord.x * WorldGenerator.CHUNK_SIZE
	var start_y := chunk_coord.y * WorldGenerator.CHUNK_SIZE
	var end_x := mini(start_x + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)
	var end_y := mini(start_y + WorldGenerator.CHUNK_SIZE, WorldGenerator.MAP_SIZE)

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var t := _generator.get_tile(Vector2i(x, y))
			var tex: Texture2D = _tile_textures.get(t, null)
			if tex:
				var world_pos := IsoMath.grid_to_world(Vector2(x, y))
				# Смещение на половину ширины тайла (64/2 = 32), чтобы вершина ромба совпала с grid_to_world
				draw_texture(tex, Vector2(world_pos.x - 32.0, world_pos.y))
