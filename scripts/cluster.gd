extends StaticBody3D

@export var size: Vector2 = Vector2(8, 3)
@export var offset: Vector3 = Vector3.ZERO
@export var processing_power: int = 1  # Can be upgraded

var packet_inventory: int = 0
var text_inventory: int = 0
var packets_processed: int = 0
var texts_processed: int = 0
var emails_sent: int = 0
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
	# Use the NetworkManager's shared grid helper
	var nm = _find_network_manager()
	if nm:
		var grid = nm.get_grid()
		if grid and grid.has_method("world_to_cell"):
			return grid.world_to_cell(global_position)
	return Vector2(int(round(global_position.x)), int(round(global_position.z)))

func _on_request_timer_timeout() -> void:
	_request_packet()
	_request_text()

func _request_packet() -> void:
	# Find a connected modem and ask it to send us a packet.
	var nm = _find_network_manager()
	if not nm:
		return

	# Collect all unique modem instances from the module_grid
	var modems_checked := {}
	for key in nm.module_grid.keys():
		var mod = nm.module_grid[key]
		if mod and mod.is_in_group("modem"):
			# Avoid checking the same modem instance multiple times
			# (modems occupy multiple cells)
			var mod_id = mod.get_instance_id()
			if modems_checked.has(mod_id):
				continue
			modems_checked[mod_id] = true

			# Check if this modem is connected to us via cables
			if nm.are_modules_connected(mod, self):
				# Ask the modem to send a packet to us
				mod.send_packet_to(self)
				print("[Cluster] Requested packet from modem: ", mod.name)
				return

	print("[Cluster] No connected modem found for packet request")

func _request_text() -> void:
	# Find a connected client and ask it to send us text.
	var nm = _find_network_manager()
	if not nm:
		return

	# Collect all unique client instances from the module_grid
	var clients_checked := {}
	for key in nm.module_grid.keys():
		var mod = nm.module_grid[key]
		if mod and mod.is_in_group("client"):
			# Avoid checking the same client instance multiple times
			# (clients occupy multiple cells)
			var mod_id = mod.get_instance_id()
			if clients_checked.has(mod_id):
				continue
			clients_checked[mod_id] = true

			# Check if this client is connected to us via cables
			if nm.are_modules_connected(mod, self):
				# Ask the client to send text to us
				mod.send_text_to(self)
				print("[Cluster] Requested text from client: ", mod.name)
				return

	print("[Cluster] No connected client found for text request")

func on_packet_received(packet) -> void:
	# Add to inventory and remove from scene
	packet_inventory += 1
	print("[Cluster] Received packet! Inventory: ", packet_inventory)
	if packet and is_instance_valid(packet):
		packet.queue_free()
	_try_combine()

func on_text_received(text) -> void:
	# Add to inventory and remove from scene
	text_inventory += 1
	print("[Cluster] Received text! Inventory: ", text_inventory)
	if text and is_instance_valid(text):
		text.queue_free()
	_try_combine()

func _try_combine() -> void:
	# If we have both a packet and a text in inventory, combine into email
	if packet_inventory > 0 and text_inventory > 0:
		packet_inventory -= 1
		text_inventory -= 1
		packets_processed += 1
		texts_processed += 1
		print("[Cluster] Combining packet and text into email! Processed: packets ", packets_processed, ", texts ", texts_processed)

		# Create email and send to connected internet
		_send_email()

func _send_email() -> void:
	var nm = _find_network_manager()
	if not nm:
		return

	# Find connected internet objects and send email to them
	var internets_sent = 0
	var internets_checked := {}
	for key in nm.module_grid.keys():
		var mod = nm.module_grid[key]
		if mod and mod.is_in_group("internet"):
			var mod_id = mod.get_instance_id()
			if internets_checked.has(mod_id):
				continue
			internets_checked[mod_id] = true

			# Check if this internet is connected to us via cables
			if nm.are_modules_connected(mod, self):
				# Send email to the internet
				var success = nm.send_email(self, mod)
				if success:
					emails_sent += 1
					internets_sent += 1
					print("[Cluster] Sent email to internet: ", mod.name, " (total sent: ", emails_sent, ")")
				else:
					print("[Cluster] Failed to send email to internet: ", mod.name, " — no cable path")

	if internets_sent == 0:
		print("[Cluster] No connected internet found for email sending")

func get_status() -> String:
	var nm = _find_network_manager()
	var adj_cables = 0
	var connected = false
	var current_score = 0
	if nm:
		adj_cables = nm.get_adjacent_cables_for_module(self).size()
		current_score = nm.get_score()
		# Check if connected to any modem
		var modems_checked := {}
		for key in nm.module_grid.keys():
			var mod = nm.module_grid[key]
			if mod and mod.is_in_group("modem"):
				var mod_id = mod.get_instance_id()
				if modems_checked.has(mod_id):
					continue
				modems_checked[mod_id] = true
				if nm.are_modules_connected(mod, self):
					connected = true
					break

	return "Cluster\nProcessing Power: %d\nCabled: %s (%d cables)\nConnected to Modem: %s\nPacket Inventory: %d\nText Inventory: %d\nPackets Processed: %d\nTexts Processed: %d\nEmails Sent: %d\nScore: %d" % [
		processing_power,
		"Yes" if adj_cables > 0 else "No",
		adj_cables,
		"Yes" if connected else "No",
		packet_inventory,
		text_inventory,
		packets_processed,
		texts_processed,
		emails_sent,
		current_score
	]

func _find_network_manager():
	if get_tree().root.has_node("Main/NetworkManager"):
		return get_tree().root.get_node("Main/NetworkManager")
	var cs = get_tree().get_current_scene()
	if cs and cs.has_node("NetworkManager"):
		return cs.get_node("NetworkManager")
	return null
