extends Node
class_name NetworkManager

# === DATA STORAGE ===
var cable_grid := {}   # Dictionary<String, Node>  key "x:z" => Cable node
var module_grid := {}  # Dictionary<String, Node>  key "x:z" => module node (modem, cluster, etc.)

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

# === SCORE / REWARD ===
var score: int = 0

func _coord_key(coord: Vector2) -> String:
	return str(int(coord.x)) + ":" + str(int(coord.y))

func _parse_coord_key(key: String) -> Vector2:
	var parts = key.split(":")
	return Vector2(parts[0].to_int(), parts[1].to_int())

# ─── Grid helper ───────────────────────────────────────────────
# Returns the single shared Grid node. All scripts should use this
# instead of hard-coding their own lookup.
func get_grid() -> Node:
	# Primary path: Main/Room/Grid
	if get_tree().root.has_node("Main/Room/Grid"):
		return get_tree().root.get_node("Main/Room/Grid")
	# Fallback: current scene / Room / Grid
	var cs = get_tree().get_current_scene()
	if cs:
		if cs.has_node("Room/Grid"):
			return cs.get_node("Room/Grid")
		if cs.has_node("Grid"):
			return cs.get_node("Grid")
	return null

# ─── Cable registration ───────────────────────────────────────
func register_cable(coord: Vector2, cable: Node) -> void:
	var key = _coord_key(coord)
	print("[NM] register_cable ", key)
	cable_grid[key] = cable
	_recompute_at_and_neighbors(coord)

func unregister_cable(coord: Vector2) -> void:
	var key = _coord_key(coord)
	print("[NM] unregister_cable ", key)
	cable_grid.erase(key)
	_recompute_neighbors(coord)

func get_cable_at(coord: Vector2) -> Node:
	return cable_grid.get(_coord_key(coord), null)

# ─── Module registration ──────────────────────────────────────
func register_module(coord: Vector2, module: Node) -> void:
	var key = _coord_key(coord)
	print("[NM] register_module ", key, " type:", module.name if module else "null")
	module_grid[key] = module

func unregister_module(coord: Vector2) -> void:
	module_grid.erase(_coord_key(coord))

func get_module_at(coord: Vector2) -> Node:
	return module_grid.get(_coord_key(coord), null)

# ─── Connection recomputation ─────────────────────────────────
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
			if neighbor_module.has_method("accepts_cable"):
				connected = neighbor_module.accepts_cable()
			else:
				connected = true
			if connected:
				module_count += 1
		if connected:
			mask |= DIR_BIT[d]
	if cable.has_method("set_connections"):
		cable.set_connections(mask)
	if cable.has_method("set_module_connections"):
		cable.set_module_connections(module_count)

# ─── Helpers: find cable cells adjacent to a module ───────────
# Returns all coords occupied by `module` in module_grid.
func get_module_coords(module: Node) -> Array:
	var coords := []
	for key in module_grid.keys():
		if module_grid[key] == module:
			coords.append(_parse_coord_key(key))
	return coords

# Returns cable coords that are directly adjacent to any cell of `module`.
func get_adjacent_cables_for_module(module: Node) -> Array:
	var cable_coords := []
	var mod_coords = get_module_coords(module)
	var mod_keys := {}
	for c in mod_coords:
		mod_keys[_coord_key(c)] = true
	for c in mod_coords:
		for d in DIRS:
			var nb = Vector2(c.x + d.x, c.y + d.y)
			var nb_key = _coord_key(nb)
			# Must be a cable, not another cell of the same module
			if mod_keys.has(nb_key):
				continue
			if get_cable_at(nb) != null:
				if not cable_coords.has(nb):
					cable_coords.append(nb)
	return cable_coords

# ─── Pathfinding ──────────────────────────────────────────────
# find_path now works between two modules (or between a cable and a module).
# It finds the shortest cable path between any cable adjacent to `start`
# and any cable adjacent to `goal`. If start/goal IS a cable coord, it
# uses that directly.
func find_path(start: Vector2, goal: Vector2, require_data: bool = true, require_power: bool = false) -> Array:
	# Determine start cable coords
	var start_cables := []
	if cable_grid.has(_coord_key(start)):
		start_cables.append(start)
	else:
		# start is a module coord — find adjacent cables
		var mod = get_module_at(start)
		if mod:
			start_cables = get_adjacent_cables_for_module(mod)

	# Determine goal cable coords
	var goal_cables := []
	if cable_grid.has(_coord_key(goal)):
		goal_cables.append(goal)
	else:
		var mod = get_module_at(goal)
		if mod:
			goal_cables = get_adjacent_cables_for_module(mod)

	if start_cables.is_empty() or goal_cables.is_empty():
		return []

	# BFS from all start cables simultaneously
	var goal_keys := {}
	for g in goal_cables:
		goal_keys[_coord_key(g)] = true

	var visited := {}
	var parent_map := {}
	var queue := []

	for sc in start_cables:
		var sk = _coord_key(sc)
		visited[sk] = true
		queue.append(sc)

	while queue.size() > 0:
		var cur = queue.pop_front()
		var cur_key = _coord_key(cur)

		if goal_keys.has(cur_key):
			# Reconstruct path
			var path := []
			var p = cur
			while visited.has(_coord_key(p)) and parent_map.has(_coord_key(p)):
				path.insert(0, p)
				p = parent_map[_coord_key(p)]
			path.insert(0, p)
			return path

		for d in DIRS:
			var nb = Vector2(cur.x + d.x, cur.y + d.y)
			var nb_key = _coord_key(nb)
			if visited.has(nb_key):
				continue
			var nb_cable = get_cable_at(nb)
			if nb_cable == null:
				continue
			if require_data and not nb_cable.data_enabled:
				continue
			if require_power and not nb_cable.power_enabled:
				continue
			visited[nb_key] = true
			parent_map[nb_key] = cur
			queue.append(nb)

	return []

# ─── Data / Packet sending ────────────────────────────────────
func send_data(start: Vector2, goal: Vector2, payload) -> bool:
	var path = find_path(start, goal, true, false)
	if path.is_empty():
		print("[NM] no data path from ", start, " to ", goal)
		return false
	print("[NM] delivering payload along path: ", path)
	var mod = get_module_at(goal)
	if mod and mod.has_method("on_data_received"):
		mod.on_data_received(payload)
	return true

func send_packet(from_module: Node, to_module: Node) -> bool:
	# Find cable-to-cable path between two modules
	var from_cables = get_adjacent_cables_for_module(from_module)
	var to_cables = get_adjacent_cables_for_module(to_module)

	if from_cables.is_empty():
		print("[NM] no cables adjacent to source module ", from_module.name)
		return false
	if to_cables.is_empty():
		print("[NM] no cables adjacent to target module ", to_module.name)
		return false

	# Try to find a path from any from_cable to any to_cable
	var best_path := []
	for fc in from_cables:
		for tc in to_cables:
			var path = find_path(fc, tc, true, false)
			if path.size() > 0:
				if best_path.is_empty() or path.size() < best_path.size():
					best_path = path
				break  # found a path from this start, move on
		if not best_path.is_empty():
			break

	if best_path.is_empty():
		print("[NM] no packet path between ", from_module.name, " and ", to_module.name)
		return false

	print("[NM] sending packet along path: ", best_path)

	# Instantiate packet
	var packet_scene = preload("res://Scene/packet.tscn")
	var packet = packet_scene.instantiate()
	# Add to scene under the NetworkManager's parent
	var scene_root = get_parent()
	if scene_root:
		scene_root.add_child(packet)
		packet.target_module = to_module
		packet.set_path(best_path)
	return true

# ─── Reward ────────────────────────────────────────────────────
func add_reward(amount: int) -> void:
	score += amount
	print("[NM] +", amount, " reward! Total score: ", score)

func get_score() -> int:
	return score

# ─── Power query ───────────────────────────────────────────────
func has_power_at(coord: Vector2) -> bool:
	var c = get_cable_at(coord)
	if c == null:
		return false
	return c.power_enabled

# ─── Connectivity query ───────────────────────────────────────
# Check if two modules are connected via cables.
func are_modules_connected(mod_a: Node, mod_b: Node) -> bool:
	var cables_a = get_adjacent_cables_for_module(mod_a)
	var cables_b = get_adjacent_cables_for_module(mod_b)
	if cables_a.is_empty() or cables_b.is_empty():
		return false
	for ca in cables_a:
		for cb in cables_b:
			var path = find_path(ca, cb, true, false)
			if path.size() > 0:
				return true
	return false
