extends Node3D
@onready var grid: Node3D = $Grid
@onready var status_panel: Panel = $StatusPanel
@onready var status_label: Label = $StatusPanel/StatusLabel

const CABLE = preload("res://Scene/cable.tscn")

var object
var isValid = false
var objectCells
var current_placement_item = null  # Stores the scene to place from UI selection

# Drag placement variables
var is_dragging = false
var drag_start_coord = Vector2()
var drag_end_coord = Vector2()

func set_placement_item(item_scene) -> void:
	"""Called by UI to set which item to place"""
	current_placement_item = item_scene
	# Clear any existing preview
	if object:
		object.queue_free()
		object = null
	isValid = false
	is_dragging = false
	_reset_highlight()
	
	# Create a preview object immediately so it follows the cursor
	if current_placement_item != null:
		var preview = current_placement_item.instantiate()
		add_child(preview)
		object = preview

func _input(event: InputEvent) -> void:
	# Check if mouse is over UI to prevent accidental placement
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var ui = get_tree().root.get_node_or_null("Main/UIPlacementPanel")
		if ui:
			if ui.panel_container.visible:
				var rect = ui.panel_container.get_global_rect()
				if rect.has_point(get_viewport().get_mouse_position()):
					return  # Don't process input if mouse is over the UI panel
			if ui.open_button.visible:
				var rect = ui.open_button.get_global_rect()
				if rect.has_point(get_viewport().get_mouse_position()):
					return  # Don't process input if mouse is over the open button

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			var ui = get_tree().root.get_node("Main/UIPlacementPanel")
			if ui and ui.has_method("_on_toggle_pressed"):
				ui._on_toggle_pressed()
			get_tree().root.set_input_as_handled()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouseGridPosition = _get_grid_position()
				if not mouseGridPosition:
					return
				var coord = grid.world_to_cell(mouseGridPosition)

				if current_placement_item == CABLE:
					# Start drag for cables
					is_dragging = true
					drag_start_coord = coord
					drag_end_coord = coord
					_reset_highlight()
				else:
					# For non-cable items: click to place the preview if valid
					if object != null and isValid:
						_place_placement(objectCells)
						# Create a new preview so the user can keep placing
						if current_placement_item != null:
							var new_preview = current_placement_item.instantiate()
							add_child(new_preview)
							object = new_preview
					elif object == null and current_placement_item != null:
						# Fallback: create preview if somehow missing
						var new_placement = current_placement_item.instantiate()
						add_child(new_placement)
						object = new_placement
			else:  # released
				if current_placement_item == CABLE and is_dragging:
					# Place cables along path
					var path = find_path_astar(drag_start_coord, drag_end_coord)
					if path.size() > 0:
						_place_cables_along_path(path)
					else:
						# If no path, try to place single cable at start if possible
						var cell = _get_cell_at_coord(drag_start_coord)
						if cell and not cell.full:
							var cable = CABLE.instantiate()
							add_child(cable)
							cable.global_position = grid.cell_to_world(drag_start_coord)
							if cable.has_method("on_placed"):
								cable.on_placed()
							cell.full = true
					is_dragging = false
					_reset_highlight()
		# Right click: cancel placement or remove object under cursor
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# If we have a placement preview, cancel the placement mode
			if current_placement_item != null:
				set_placement_item(null)
				# Also update the UI label
				var ui = get_tree().root.get_node_or_null("Main/UIPlacementPanel")
				if ui:
					ui.current_selection = ""
					ui.update_label()
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
					# Check if any module occupies this coord
					var world_pos = grid.cell_to_world(coord)
					var world_point = Vector2(world_pos.x, world_pos.z)
					for mc in nm.module_grid.keys():
						var mod = nm.module_grid[mc]
						if mod and mod.has_method("get_rect"):
							var rect = mod.get_rect()
							if rect.has_point(world_point):
								obj = mod
								break
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
						# For multi-cell modules, unregister all occupied coords
						if obj.has_method("get_rect"):
							var rect = obj.get_rect()
							for x in range(int(floor(rect.position.x)), int(ceil(rect.position.x + rect.size.x))):
								for z in range(int(floor(rect.position.y)), int(ceil(rect.position.y + rect.size.y))):
									var cell_coord = Vector2(x, z)
									nm.unregister_module(cell_coord)
						else:
							nm.unregister_module(obj.get_cell_coord())
					# Clear occupancy on the corresponding grid cells
					if is_cable:
						var cell = _get_cell_at_coord(coord)
						if cell:
							cell.full = false
					else:
						# For multi-cell objects, clear all occupied cells
						if obj.has_method("get_rect"):
							var rect = obj.get_rect()
							for cell in grid.get_children():
								var cell_world = grid.cell_to_world(grid.world_to_cell(cell.global_position))
								if rect.has_point(Vector2(cell_world.x, cell_world.z)):
									cell.full = false
					if nm.has_method("_recompute_neighbors"):
						nm._recompute_neighbors(coord)
					_reset_highlight()
			return

func _process(delta: float) -> void:
	# Check for hovered module
	var mouseGridPosition = _get_grid_position()
	if mouseGridPosition:
		var coord = grid.world_to_cell(mouseGridPosition)
		var world_pos = grid.cell_to_world(coord)
		var world_point = Vector2(world_pos.x, world_pos.z)
		var nm = null
		if get_tree().root.has_node("Main/NetworkManager"):
			nm = get_tree().root.get_node("Main/NetworkManager")
		else:
			var cs = get_tree().get_current_scene()
			if cs and cs.has_node("NetworkManager"):
				nm = cs.get_node("NetworkManager")
		if nm:
			for key in nm.module_grid.keys():
				var mod = nm.module_grid[key]
				if mod and not (mod is Cable) and mod.has_method("get_rect"):
					var rect = mod.get_rect()
					if rect.has_point(world_point):
						status_label.text = mod.get_status()
						status_panel.visible = true
						status_panel.position = get_viewport().get_mouse_position() + Vector2(10, 10)
						return
	status_panel.visible = false

	# Update drag end coord if dragging and highlight the A* path preview
	if is_dragging and mouseGridPosition:
		drag_end_coord = grid.world_to_cell(mouseGridPosition)
		_reset_highlight()
		var preview_path = find_path_astar(drag_start_coord, drag_end_coord)
		if preview_path.size() > 0:
			for coord in preview_path:
				var cell = _get_cell_at_coord(coord)
				if cell:
					cell.change_color(Color.GREEN)
		else:
			# No valid path - highlight start cell red
			var start_cell = _get_cell_at_coord(drag_start_coord)
			if start_cell:
				start_cell.change_color(Color.RED)

	if not object: return
	if not mouseGridPosition:
		return

	# Special-case: Cable previews snap to the center of a single grid cell
	if object is Cable:
		var coord = grid.world_to_cell(mouseGridPosition)
		var world_center = grid.cell_to_world(coord)
		object.global_position = world_center
		# Only highlight single cell when not dragging (drag highlighting is handled above)
		if not is_dragging:
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

func _place_cables_along_path(path: Array):
	# Place cables along the path
	for coord in path:
		var cell = _get_cell_at_coord(coord)
		if cell and not cell.full:
			var cable = CABLE.instantiate()
			add_child(cable)
			cable.global_position = grid.cell_to_world(coord)
			if cable.has_method("on_placed"):
				cable.on_placed()
			cell.full = true



func _get_cell_at_coord(coord: Vector2) -> Node:
	for child in grid.get_children():
		var c = grid.world_to_cell(child.global_position)
		if int(c.x) == int(coord.x) and int(c.y) == int(coord.y):
			return child
	return null

func _coord_key(coord: Vector2) -> String:
	return str(int(round(coord.x))) + ":" + str(int(round(coord.y)))

func find_path_astar(start_coord: Vector2, end_coord: Vector2) -> Array:
	# A* pathfinding for cable placement, avoiding occupied cells
	# Round coordinates to integers
	start_coord = Vector2(round(start_coord.x), round(start_coord.y))
	end_coord = Vector2(round(end_coord.x), round(end_coord.y))

	var astar = AStar2D.new()
	var cells = grid.get_children()
	if cells.size() == 0:
		return []
	var coord_to_id = {}
	var id_to_coord = {}
	var id_counter = 0

	# Find grid bounds
	var min_coord = Vector2(INF, INF)
	var max_coord = Vector2(-INF, -INF)
	for cell in cells:
		var coord = grid.world_to_cell(cell.global_position)
		min_coord = Vector2(min(min_coord.x, coord.x), min(min_coord.y, coord.y))
		max_coord = Vector2(max(max_coord.x, coord.x), max(max_coord.y, coord.y))

	# Check if start and end are within bounds
	if start_coord.x < min_coord.x or start_coord.x > max_coord.x or start_coord.y < min_coord.y or start_coord.y > max_coord.y:
		return []
	if end_coord.x < min_coord.x or end_coord.x > max_coord.x or end_coord.y < min_coord.y or end_coord.y > max_coord.y:
		return []

	# Add all cells as points
	for cell in cells:
		var coord = grid.world_to_cell(cell.global_position)
		var key = _coord_key(coord)
		var id = id_counter
		coord_to_id[key] = id
		id_to_coord[id] = coord
		astar.add_point(id, Vector2(coord.x, coord.y))
		if cell.full:
			astar.set_point_disabled(id, true)
		id_counter += 1

	# Connect neighbors (connect all adjacent cells; AStar2D handles disabled points during pathfinding)
	for cell in cells:
		var coord = grid.world_to_cell(cell.global_position)
		var key = _coord_key(coord)
		var id = coord_to_id.get(key, null)
		if id == null:
			continue
		for dir in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			var neighbor_coord = coord + dir
			var neighbor_key = _coord_key(neighbor_coord)
			var neighbor_id = coord_to_id.get(neighbor_key, null)
			if neighbor_id == null:
				continue
			if not astar.are_points_connected(id, neighbor_id):
				astar.connect_points(id, neighbor_id)

	var start_key = _coord_key(start_coord)
	var end_key = _coord_key(end_coord)
	if not coord_to_id.has(start_key) or not coord_to_id.has(end_key):
		return []

	var start_id = coord_to_id.get(start_key, null)
	var end_id = coord_to_id.get(end_key, null)
	if start_id == null or end_id == null:
		return []

	if astar.is_point_disabled(start_id) or astar.is_point_disabled(end_id):
		return []

	var path_ids = astar.get_id_path(start_id, end_id)
	var path_coords = []
	for id in path_ids:
		var coord = id_to_coord.get(id, null)
		if coord == null:
			continue
		path_coords.append(coord)
	return path_coords
	
	
	
	
