extends Node3D
@onready var grid: Node3D = $Grid


var object
var isValid = false
var objectCells
var current_placement_item = null  # Stores the scene to place from UI selection

func set_placement_item(item_scene) -> void:
	"""Called by UI to set which item to place"""
	current_placement_item = item_scene
	# Clear any existing preview
	if object:
		object.queue_free()
		object = null
	isValid = false
	_reset_highlight()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Left click: place (existing behavior)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:  # just pressed (not held)
			
			# Case 1: No preview object yet → start placing one
			if object == null:
				if current_placement_item == null:
					return  # No item selected, do nothing
				
				var new_placement = current_placement_item.instantiate()
				add_child(new_placement)
				object = new_placement
				
			# Case 2: We have a preview object → try to place it if valid
			elif isValid:
				_place_placement(objectCells)  # your placement function (finalize position, clear preview, etc.)
		# Right click: remove cable under cursor when not placing
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Only remove when there's no active placement preview
			if object != null:
				return
			var mouseGridPosition = _get_grid_position()
			if not mouseGridPosition:
				return
			var coord = grid.world_to_cell(mouseGridPosition)
			var nm = null
			if get_tree().root.has_node("Main/NetworkManager"):
				nm = get_tree().root.get_node("Main/NetworkManager")
			else:
				var cs = get_tree().get_current_scene()
				if cs and cs.has_node("NetworkManager"):
					nm = cs.get_node("NetworkManager")
			if nm:
				var obj = nm.get_cable_at(coord)
				var is_cable = true
				if not obj:
					obj = nm.get_module_at(coord)
					is_cable = false
				if obj:
					# Inform network manager and free object node
					if obj.has_method("on_removed"):
						obj.on_removed()
					obj.queue_free()
					# Unregister
					if is_cable:
						nm.unregister_cable(coord)
					else:
						nm.unregister_module(coord)
					# Clear occupancy on the corresponding grid cell
					var cell = _get_cell_at_coord(coord)
					if cell:
						cell.full = false
					if nm.has_method("_recompute_neighbors"):
						nm._recompute_neighbors(coord)
					_reset_highlight()
			return

func _process(delta: float) -> void:
	if not object: return
	var mouseGridPosition = _get_grid_position()
	if not mouseGridPosition:
		return

	# Special-case: Cable previews snap to the center of a single grid cell
	if object is Cable:
		var coord = grid.world_to_cell(mouseGridPosition)
		var world_center = grid.cell_to_world(coord)
		object.global_position = world_center
		_reset_highlight()
		var cell = _get_cell_at_coord(coord)
		objectCells = []
		if cell:
			objectCells.append(cell)
			if cell.full:
				cell.change_color(Color.RED)
				isValid = false
			else:
				cell.change_color(Color.GREEN)
				isValid = true
		else:
			isValid = false
		return

	# Default placement flow for multi-cell objects
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
	# Only check grid cells if object has get_rect method
	if not object.has_method("get_rect"):
		return cells
	
	for child in grid.get_children():
		if child.get_rect().intersects(object.get_rect()):
			cells.append(child)
	return cells
func _check_and_highlight_cells(objectCells: Array):
	var isValid = true

	# If object doesn't have get_rect, caller should have handled validation
	if not object.has_method("get_rect"):
		return true
	
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
	# Finalize placement: notify object, then mark cells occupied
	if object and object.has_method("on_placed"):
		object.on_placed()

	# Clear the preview reference so the placed instance remains in the world
	object = null
	isValid = false

	for cell in objectCells:
		cell.full = true

	_reset_highlight()



func _get_cell_at_coord(coord: Vector2) -> Node:
	for child in grid.get_children():
		var c = grid.world_to_cell(child.global_position)
		if int(c.x) == int(coord.x) and int(c.y) == int(coord.y):
			return child
	return null
	
	
	
	
