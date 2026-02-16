extends StaticBody3D

@export var size: Vector2 = Vector2(8,3)
@export var offset: Vector3 = Vector3.ZERO
@export var processing_power: int = 1  # Can be upgraded
@export var packet_queue: Array = []

var request_timer: Timer

func _ready() -> void:
	for child in get_children():
		child.position -= offset
	add_to_group("cluster")
	# Set up timer to request packets
	request_timer = Timer.new()
	request_timer.wait_time = 5.0  # Request every 5 seconds
	request_timer.autostart = true
	request_timer.connect("timeout", Callable(self, "_on_request_timer_timeout"))
	add_child(request_timer)

func get_rect():
	var objectPosition = Vector2( global_position.x - int(size.x/2), global_position.z - int(size.y /2))
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
	# After placement, try to request a packet from a connected modem
	_request_packet()

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

func _on_request_timer_timeout() -> void:
	_request_packet()

func _request_packet() -> void:
	# Find a connected modem and request a packet
	var nm = _find_network_manager()
	if not nm:
		return
	var my_coord = get_cell_coord()
	# Check all modems for a path
	for key in nm.module_grid.keys():
		var mod = nm.module_grid[key]
		if mod and mod.is_in_group("modem"):
			var parts = key.split(":")
			var modem_coord = Vector2(parts[0].to_int(), parts[1].to_int())
			if nm.find_path(modem_coord, my_coord, true, false).size() > 0:
				mod.send_packet_to(my_coord)
				break

func on_packet_received(packet) -> void:
	# Process the packet based on processing power
	print("Cluster processing packet with power:", processing_power)
	print("packets in qureue:", packet_queue.size())
	# For now, just print
	packet.queue_free()

func get_status() -> String:
	return "Cluster\nProcessing Power: %d\nOnline: Yes\nConnected: Yes" % processing_power + "\nPacket Queue: %d" % packet_queue.size()

func _find_network_manager():
	var nm = null
	if get_tree().root.has_node("Main/NetworkManager"):
		nm = get_tree().root.get_node("Main/NetworkManager")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("NetworkManager"):
			nm = cs.get_node("NetworkManager")
	return nm
