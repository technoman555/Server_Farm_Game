extends StaticBody3D

@export var size: Vector2 = Vector2(2, 2)
@export var offset: Vector3 = Vector3.ZERO
var packets_sent: int = 0

func _ready() -> void:
	for child in get_children():
		child.position -= offset
	add_to_group("modem")

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

# Method to send a packet to a requesting server
func send_packet_to(target_coord: Vector2) -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("send_packet"):
		var start_coord = get_cell_coord()
		# Find an adjacent cable to send from
		var dirs = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
		for d in dirs:
			var nb = start_coord + d
			if nm.get_cable_at(nb):
				start_coord = nb
				break
		nm.send_packet(start_coord, target_coord)
		packets_sent += 1
		print("Modem at", get_cell_coord(), "sent packet to", target_coord,)

func get_status() -> String:
	if not is_inside_tree():
		return "Modem\nOnline: No\nConnected: No"
	else: return "Modem\nOnline: Yes\nConnected: " + (str(get_cell_coord()) if get_cell_coord() else "Unknown" ) + "\nPackets Sent: " + str(packets_sent)
