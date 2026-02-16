extends Node3D

var path: Array = []
var current_index: int = 0
var speed: float = 2.0  # units per second
var target_coord: Vector2

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if path.size() == 0 or current_index >= path.size():
		return
	
	var current_pos = global_position
	var next_coord = path[current_index]
	var next_pos = Vector3(next_coord.x, 0, next_coord.y)
	
	var direction = (next_pos - current_pos).normalized()
	var distance = current_pos.distance_to(next_pos)
	
	if distance < 0.1:
		# Reached the next point
		current_index += 1
		if current_index >= path.size():
			# Reached destination
			_on_reached_destination()
			return
		else:
			next_coord = path[current_index]
			next_pos = Vector3(next_coord.x, 0, next_coord.y)
			direction = (next_pos - current_pos).normalized()
			distance = current_pos.distance_to(next_pos)
	
	var move_distance = speed * delta
	if move_distance > distance:
		move_distance = distance
	
	global_position += direction * move_distance

func set_path(new_path: Array) -> void:
	path = new_path
	current_index = 0
	if path.size() > 0:
		global_position = Vector3(path[0].x, 0, path[0].y)

func _on_reached_destination() -> void:
	# Notify the target module
	var nm = _find_network_manager()
	if nm:
		var mod = nm.get_module_at(target_coord)
		if mod and mod.has_method("on_packet_received"):
			mod.on_packet_received(self)
	queue_free()

func _find_network_manager():
	var nm = null
	if get_tree().root.has_node("Main/NetworkManager"):
		nm = get_tree().root.get_node("Main/NetworkManager")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("NetworkManager"):
			nm = cs.get_node("NetworkManager")
	return nm