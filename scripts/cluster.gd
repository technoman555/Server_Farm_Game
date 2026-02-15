extends StaticBody3D

@export var size: Vector2 = Vector2(8,3)
@export var offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	for child in get_children():
		child.position -= offset

func get_rect():
	var objectPosition = Vector2( global_position.x - int(size.x/2), global_position.z - int(size.y /2))
	return Rect2(objectPosition, size)

func on_placed() -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("register_module"):
		var coord = get_cell_coord()
		nm.register_module(coord, self)

func on_removed() -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("unregister_module"):
		var coord = get_cell_coord()
		nm.unregister_module(coord)

func get_cell_coord() -> Vector2:
	var grid = null
	if get_tree().root.has_node("Main/Grid"):
		grid = get_tree().root.get_node("Main/Grid")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("Grid"):
			grid = cs.get_node("Grid")
	if grid and grid.has_method("world_to_cell"):
		return grid.world_to_cell(global_position)
	return Vector2(int(round(global_position.x)), int(round(global_position.z)))

func _find_network_manager():
	var nm = null
	if get_tree().root.has_node("Main/NetworkManager"):
		nm = get_tree().root.get_node("Main/NetworkManager")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("NetworkManager"):
			nm = cs.get_node("NetworkManager")
	return nm
