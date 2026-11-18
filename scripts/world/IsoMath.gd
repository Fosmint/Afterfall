class_name IsoMath
extends RefCounted

# Константы стандартной 2:1 изометрической проекции (тайл 64x32)
const TILE_W: float = 64.0
const TILE_H: float = 32.0
const HALF_W: float = 32.0
const HALF_H: float = 16.0

static func grid_to_world(grid_pos: Vector2) -> Vector2:
	return Vector2(
		(grid_pos.x - grid_pos.y) * HALF_W,
		(grid_pos.x + grid_pos.y) * HALF_H
	)

static func world_to_grid(world_pos: Vector2) -> Vector2:
	var gx: float = (world_pos.x / HALF_W + world_pos.y / HALF_H) * 0.5
	var gy: float = (world_pos.y / HALF_H - world_pos.x / HALF_W) * 0.5
	return Vector2(gx, gy)

static func world_to_tile(world_pos: Vector2) -> Vector2i:
	var g := world_to_grid(world_pos)
	return Vector2i(int(floor(g.x)), int(floor(g.y)))

static func tile_center_world(tile: Vector2i) -> Vector2:
	return grid_to_world(Vector2(tile.x + 0.5, tile.y + 0.5))
