extends Node3D
@onready var grid: Node3D = $Grid
const dell_server = preload("res://early_server.tscn")
const cluster = preload("res://cluster.tscn")

var object
var isValid = false
var objectCells

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:  # just pressed (not held)
			
			# Case 1: No preview object yet → start placing one
			if object == null:
				var items = [dell_server,cluster]  # your preload or array of possible scenes
				var new_placement = items.pick_random().instantiate()
				add_child(new_placement)
				object = new_placement
				
				# Optional: Make it a "preview" (semi-transparent, follow mouse until placed)
				# new_placement.modulate.a = 0.6  # example for transparency
				
			# Case 2: We have a preview object → try to place it if valid
			elif isValid:
				_place_placement(objectCells)  # your placement function (finalize position, clear preview, etc.)
				
				# After successful placement, clear the preview reference
				object = null
				
				# Optional: reset isValid or other states
				isValid = false

func _process(delta: float) -> void:
	if not object: return
	var mouseGridPosition = _get_grid_position()
	if mouseGridPosition:
		object.global_position = mouseGridPosition
		_reset_highlight()
		objectCells = _get_object_cells()
		isValid = _check_and_highlight_cells(objectCells)
	
func _get_grid_position():
	var mousePositionDepth = 100
	var mousePosition := get_viewport().get_mouse_position()
	var currentCamera := get_viewport().get_camera_3d()
	var params := PhysicsRayQueryParameters3D.new()
	
	params.from = currentCamera.project_ray_origin(mousePosition)
	params.to = currentCamera.project_position(mousePosition, mousePositionDepth)
	params.collide_with_bodies = false
	params.collide_with_areas = true
	
	var worldspace := get_world_3d().direct_space_state
	var intersect := worldspace.intersect_ray(params)
	if not intersect: return
	if intersect.collider.get_parent().name == "Grid":
		return intersect.collider.global_position
	else:
		return
func _reset_highlight():
	for child in grid.get_children():
		child.change_color(grid.defaultColor)
func _get_object_cells():
	var cells = []
	for child in grid.get_children():
		if child.get_rect().intersects(object.get_rect()):
			cells.append(child)
	return cells
func _check_and_highlight_cells(objectCells: Array):
	var isValid = true
	var objectCellCount = (object.get_rect().size.x / grid.cellSize.x) * (object.get_rect().size.y / grid.cellSize.y)
	if objectCellCount != objectCells.size():
		isValid = false
	for cell in objectCells:
		if cell.full:
			isValid = false
			cell.change_color(Color.RED)
		else:
			cell.change_color(Color.GREEN)
	return isValid
func _place_placement(objectCells):
	object = null
	isValid = false
	
	for cell in objectCells:
		cell.full = true
	_reset_highlight()
	
	
	
	
