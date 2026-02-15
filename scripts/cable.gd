extends Node3D
class_name Cable

# Cable occupies a single grid cell and auto-connects to neighbors.
# Connections bitmask: N=1, E=2, S=4, W=8
@export var data_enabled: bool = true
@export var power_enabled: bool = true
var connections: int = 0

func _ready() -> void:
	pass

func set_connections(mask: int) -> void:
	if connections == mask:
		return
	connections = mask
	_apply_visual_variant()

func _apply_visual_variant() -> void:
	# Toggle child segment visibility based on connections bitmask.
	# Bit mapping: N=1, E=2, S=4, W=8
	var seg_n = get_node_or_null("Seg_N")
	var seg_e = get_node_or_null("Seg_E")
	var seg_s = get_node_or_null("Seg_S")
	var seg_w = get_node_or_null("Seg_W")
	var center = get_node_or_null("Center")

	if seg_n:
		seg_n.visible = (connections & 1) != 0
	if seg_e:
		seg_e.visible = (connections & 2) != 0
	if seg_s:
		seg_s.visible = (connections & 4) != 0
	if seg_w:
		seg_w.visible = (connections & 8) != 0
	if center:
		# show center if any connection exists, otherwise keep visible so cable is visible
		center.visible = true

	# Optionally color segments if power/data disabled
	var tint = Color(0.5, 0.5, 0.9)
	if not data_enabled:
		tint = Color(0.5, 0.5, 0.9)
	if not power_enabled:
		tint = Color(0.9, 0.6, 0.6)
	for name in ["Seg_N", "Seg_E", "Seg_S", "Seg_W", "Center"]:
		var n = get_node_or_null(name)
		if n and n is MeshInstance3D:
			# Assign a simple material override to tint the mesh instance
			var mat = StandardMaterial3D.new()
			mat.albedo_color = tint
			n.material_override = mat

func get_cell_coord() -> Vector2:
	# Convert this cable's global position to grid cell coordinates.
	var grid = null
	if get_tree().root.has_node("Main/Grid"):
		grid = get_tree().root.get_node("Main/Grid")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("Grid"):
			grid = cs.get_node("Grid")
	if grid and grid.has_method("world_to_cell"):
		return grid.world_to_cell(global_position)
	# Fallback: round X,Z to integers
	return Vector2(int(round(global_position.x)), int(round(global_position.z)))

func on_placed() -> void:
	# Called after the cable is instantiated and added to scene.
	var nm = _find_network_manager()
	if nm and nm.has_method("register_cable"):
		nm.register_cable(get_cell_coord(), self)

func on_removed() -> void:
	var nm = _find_network_manager()
	if nm and nm.has_method("unregister_cable"):
		nm.unregister_cable(get_cell_coord())

func _find_network_manager():
	# Prefer stable path under Main, fall back to current scene lookup
	var nm = null
	if get_tree().root.has_node("Main/NetworkManager"):
		nm = get_tree().root.get_node("Main/NetworkManager")
	else:
		var cs = get_tree().get_current_scene()
		if cs and cs.has_node("NetworkManager"):
			nm = cs.get_node("NetworkManager")
	return nm
