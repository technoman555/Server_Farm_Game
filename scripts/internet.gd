extends StaticBody3D

@export var size: Vector2 = Vector2(2, 2)
@export var offset: Vector3 = Vector3.ZERO

var emails_received: int = 0

func _ready() -> void:
	for child in get_children():
		child.position -= offset
	add_to_group("internet")

func get_rect():
	var objectPosition = Vector2(global_position.x - int(size.x / 2), global_position.z - int(size.y / 2))
	return Rect2(objectPosition, size)

func on_placed() -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("register_module"):
		var rect = get_rect()
		var occupied_coords = []
		for x in range(int(floor(rect.position.x)), int(ceil(rect.position.x + rect.size.x))):
			for z in range(int(floor(rect.position.y)), int(ceil(rect.position.y + rect.size.y))):
				var coord = Vector2(x, z)
				nm.register_module(coord, self)
				occupied_coords.append(coord)
		# Recompute connections for neighboring cables
		for coord in occupied_coords:
			if nm.has_method("_recompute_neighbors"):
				nm._recompute_neighbors(coord)

func on_removed() -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("unregister_module"):
		var rect = get_rect()
		for x in range(int(floor(rect.position.x)), int(ceil(rect.position.x + rect.size.x))):
			for z in range(int(floor(rect.position.y)), int(ceil(rect.position.y + rect.size.y))):
				var coord = Vector2(x, z)
				nm.unregister_module(coord)

func get_cell_coord() -> Vector2:
	# Use the NetworkManager's shared grid helper
	var nm = _find_network_manager()
	if nm:
		var grid = nm.get_grid()
		if grid and grid.has_method("world_to_cell"):
			return grid.world_to_cell(global_position)
	return Vector2(int(round(global_position.x)), int(round(global_position.z)))

func on_email_received(email) -> void:
	# Process the email and award points
	emails_received += 1
	print("[Internet] Received email! Total received: ", emails_received)

	# Award 2 points
	var nm = _find_network_manager()
	if nm:
		nm.add_reward(2)
		print("[Internet] Awarded 2 points! Total score: ", nm.get_score())

	# Clean up the email node
	if email and is_instance_valid(email):
		email.queue_free()

func get_status() -> String:
	var nm = _find_network_manager()
	var adj_cables = 0
	if nm:
		adj_cables = nm.get_adjacent_cables_for_module(self).size()
	var connected_str = "Yes" if adj_cables > 0 else "No"
	var current_score = nm.get_score() if nm else 0
	return "Internet\nOnline: %s\nCabled: %s (%d cables)\nEmails Received: %d\nScore: %d" % [
		"Yes" if is_inside_tree() else "No",
		connected_str,
		adj_cables,
		emails_received,
		current_score
	]

func _find_network_manager():
	if get_tree().root.has_node("Main/NetworkManager"):
		return get_tree().root.get_node("Main/NetworkManager")
	var cs = get_tree().get_current_scene()
	if cs and cs.has_node("NetworkManager"):
		return cs.get_node("NetworkManager")
	return null