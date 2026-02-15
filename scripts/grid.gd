@tool
extends Node3D

@export var gridWidth := 5:
	set(value):
		gridWidth = value
		_remove_grid()
		_generate_grid()
@export var gridHeight := 5:
	set(value):
		gridHeight = value
		_remove_grid()
		_generate_grid()
@export var cellSize: Vector2 = Vector2(1,1):
	set(value):
		cellSize = value
		_remove_grid()
		_generate_grid()
@export var defaultColor: Color = Color.GRAY

const GRID_CELL = preload("res://grid_cell.tscn")

func _remove_grid():
	for node in get_children():
		node.queue_free()

func _generate_grid():
	_remove_grid()  # optional but good to call first if regenerating

	for height in range(gridHeight):
		for width in range(gridWidth):
			var gridCell = GRID_CELL.instantiate()
			# Set local position directly (recommended)
			gridCell.position = Vector3(width * cellSize.x, 0, height * cellSize.y)
			add_child(gridCell)  # now it's in the tree

func world_to_cell(world_pos: Vector3) -> Vector2:
	# Convert a world position to grid cell coordinates (X,Z mapped to Vector2.x, Vector2.y)
	var local = to_local(world_pos)
	var cx = int(round(local.x / cellSize.x))
	var cy = int(round(local.z / cellSize.y))
	return Vector2(cx, cy)

func cell_to_world(cell: Vector2) -> Vector3:
	# Convert grid cell coordinates back to a world position (center of the cell)
	var wx = cell.x * cellSize.x
	var wz = cell.y * cellSize.y
	var local_pos = Vector3(wx, 0, wz)
	return to_global(local_pos)
