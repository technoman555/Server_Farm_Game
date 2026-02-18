extends Node3D

var path: Array = []          # Array of Vector2 cable coords to traverse
var current_index: int = 0
var speed: float = 3.0        # units per second
var target_module: Node = null # The destination module (cluster/server)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if path.size() == 0 or current_index >= path.size():
		return

	var current_pos = global_position
	var next_coord = path[current_index]
	var next_pos = Vector3(next_coord.x, 0.3, next_coord.y)  # Slightly above ground

	var direction = (next_pos - current_pos)
	var distance = direction.length()

	if distance < 0.1:
		# Reached the next waypoint
		current_index += 1
		if current_index >= path.size():
			# Reached the end of the cable path — deliver to target module
			_on_reached_destination()
			return
	else:
		var move_distance = speed * delta
		if move_distance > distance:
			move_distance = distance
		global_position += direction.normalized() * move_distance

func set_path(new_path: Array) -> void:
	path = new_path
	current_index = 0
	if path.size() > 0:
		# Start at the first cable position, slightly above ground
		global_position = Vector3(path[0].x, 0.3, path[0].y)

func _on_reached_destination() -> void:
	# Deliver to the target module
	if target_module and is_instance_valid(target_module) and target_module.has_method("on_text_received"):
		target_module.on_text_received(self)
	else:
		# No valid target — just clean up
		print("[Text] Reached destination but no valid target module")
		queue_free()