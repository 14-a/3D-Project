@tool
class_name GatorSpriteTilemap
extends Resource

@export var grid_size: Vector2i = Vector2i.ONE
@export var cells: PackedInt32Array = PackedInt32Array([-1])

func resize_grid(requested_size: Vector2i) -> void:
	grid_size = requested_size.max(Vector2i.ONE)
	cells.resize(grid_size.x * grid_size.y)
	for cell_index: int in range(cells.size()):
		cells[cell_index] = -1

func set_cell(cell_position: Vector2i, tile_index: int) -> void:
	if cell_position.x < 0 or cell_position.y < 0 or cell_position.x >= grid_size.x or cell_position.y >= grid_size.y:
		return
	cells[cell_position.y * grid_size.x + cell_position.x] = tile_index

func get_cell(cell_position: Vector2i) -> int:
	if cell_position.x < 0 or cell_position.y < 0 or cell_position.x >= grid_size.x or cell_position.y >= grid_size.y:
		return -1
	return cells[cell_position.y * grid_size.x + cell_position.x]
