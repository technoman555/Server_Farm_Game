extends Node3D

@export var target: Node3D  # Drag Player here in Inspector
@export var height: float = 6.0
@export var distance: float = 5.0
@export var lerp_speed: float = 10.0

func _ready() -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")  # Add Player to "player" group

func _process(delta: float) -> void:
	var target_pos := target.global_position
	target_pos.y += height
	target_pos.z -= distance  # Slight back offset
	global_position = global_position.lerp(target_pos, lerp_speed * delta)
