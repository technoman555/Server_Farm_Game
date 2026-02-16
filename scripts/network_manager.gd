
extends Node
class_name NetworkManager

# === DATA STORAGE ===
var cable_grid := {}   # Dictionary<String, Node>  key => Cable node
var module_grid := {}  # Dictionary<String, Node>  key => module node

# Direction order: N, E, S, W (Vector2 offsets on X,Z as X,Y)
const DIRS := [
	Vector2(0, -1),
	Vector2(1, 0),
	Vector2(0, 1),
	Vector2(-1, 0)
]

const DIR_BIT := {
	Vector2(0, -1): 1,  # N
	Vector2(1, 0): 2,   # E
	Vector2(0, 1): 4,   # S
	Vector2(-1, 0): 8   # W
}

@onready var cables_parent = get_parent().get_node("Cables") if (get_parent() and get_parent().has_node("Cables")) else null
@onready var modules_parent = get_parent().get_node("Modules") if (get_parent() and get_parent().has_node("Modules")) else null

func _coord_key(coord: Vector2) -> String:
	return str(int(coord.x)) + ":" + str(int(coord.y))

func register_cable(coord: Vector2, cable: Node) -> void:
	var key = _coord_key(coord)
	print("[NetworkManager] register_cable at", key)
	cable_grid[key] = cable
	_recompute_at_and_neighbors(coord)

func unregister_cable(coord: Vector2) -> void:
	var key = _coord_key(coord)
	print("[NetworkManager] unregister_cable at", key)
	cable_grid.erase(key)
	_recompute_neighbors(coord)

func get_cable_at(coord: Vector2) -> Node:
	return cable_grid.get(_coord_key(coord), null)

func register_module(coord: Vector2, module: Node) -> void:
	var key = _coord_key(coord)
	print("[NetworkManager] register_module at", key, "type:", module.name if module else "null")
	module_grid[key] = module

func unregister_module(coord: Vector2) -> void:
	module_grid.erase(_coord_key(coord))

func get_module_at(coord: Vector2) -> Node:
	return module_grid.get(_coord_key(coord), null)

func _get_adjacent_coords(coord: Vector2) -> Array:
	var out := []
	for d in DIRS:
		out.append(Vector2(coord.x + d.x, coord.y + d.y))
	return out

func _recompute_at_and_neighbors(coord: Vector2) -> void:
	_recompute_connections_at(coord)
	for n in _get_adjacent_coords(coord):
		_recompute_connections_at(n)

func _recompute_neighbors(coord: Vector2) -> void:
	for n in _get_adjacent_coords(coord):
		_recompute_connections_at(n)

func _recompute_connections_at(coord: Vector2) -> void:
	var cable = get_cable_at(coord)
	if cable == null:
		return
	var mask := 0
	var module_count := 0
	for d in DIRS:
		var neighbor = Vector2(coord.x + d.x, coord.y + d.y)
		var neighbor_cable = get_cable_at(neighbor)
		var neighbor_module = get_module_at(neighbor)
		var connected = false
		if neighbor_cable:
			connected = true
		elif neighbor_module:
			# If the module exposes an "accepts_cable" method, respect it; otherwise assume connectable
			if neighbor_module.has_method("accepts_cable"):
				connected = neighbor_module.accepts_cable()
			else:
				connected = true
			if connected:
				module_count += 1
				print("Cable at", coord, "connected to module at", neighbor, "type:", neighbor_module.name if neighbor_module else "null")
		if connected:
			mask |= DIR_BIT[d]
	if cable.has_method("set_connections"):
		cable.set_connections(mask)
	if cable.has_method("set_module_connections"):
		cable.set_module_connections(module_count)
		if module_count > 0:
			print("Cable at", coord, "has", module_count, "module connections")
	if mask > 0:
		print("Cable at", coord, "connected to cables with mask", mask)

func find_path(start: Vector2, goal: Vector2, require_data: bool=true, require_power: bool=false) -> Array:
	var start_key = _coord_key(start)
	var goal_key = _coord_key(goal)
	if not cable_grid.has(start_key) or not cable_grid.has(goal_key):
		return []
	var visited := {}
	var q := []
	var parent := {}
	visited[start_key] = true
	q.append(start)
	while q.size() > 0:
		var cur = q.pop_front()
		if _coord_key(cur) == goal_key:
			var path := []
			var p = cur
			while _coord_key(p) != start_key:
				path.insert(0, p)
				p = parent[_coord_key(p)]
			path.insert(0, start)
			return path
		for d in DIRS:
			var nb = Vector2(cur.x + d.x, cur.y + d.y)
			var nb_key = _coord_key(nb)
			if visited.has(nb_key):
				continue
			var nb_cable = get_cable_at(nb)
			var nb_module = get_module_at(nb)
			if nb_cable == null and not (nb_module and nb_key == goal_key):
				continue
			if nb_cable:
				if require_data and not nb_cable.data_enabled:
					continue
				if require_power and not nb_cable.power_enabled:
					continue
			visited[nb_key] = true
			parent[nb_key] = cur
			q.append(nb)
	return []

func send_data(start: Vector2, goal: Vector2, payload) -> bool:
	var path = find_path(start, goal, true, false)
	if path.empty():
		print("[NetworkManager] no data path from", start, "to", goal)
		return false
	print("[NetworkManager] delivering payload along path:", path)
	var mod = get_module_at(goal)
	if mod and mod.has_method("on_data_received"):
		mod.on_data_received(payload)
	return true

func send_packet(start: Vector2, goal: Vector2) -> bool:
	var path = find_path(start, goal, true, false)
	if path.empty():
		print("[NetworkManager] no packet path from", start, "to", goal)
		return false
	print("[NetworkManager] sending packet along path:", path)
	# Instantiate packet
	var packet_scene = preload("res://Scene/packet.tscn")
	var packet = packet_scene.instantiate()
	packet.target_coord = goal
	packet.set_path(path)
	# Add to scene
	var parent = get_parent()
	if parent:
		parent.add_child(packet)
	return true

func has_power_at(coord: Vector2) -> bool:
	var c = get_cable_at(coord)
	if c == null:
		return false
	return c.power_enabled
