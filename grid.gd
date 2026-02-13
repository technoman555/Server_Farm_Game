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
			
# Alternative if you really need global (usually not needed here):
# add_child(gridCell)
# gridCell.global_position = global_position + Vector3(width * cellSize.x, 0, height * cellSize.y))
