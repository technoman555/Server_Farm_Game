extends Node3D

@export var target: Node3D  # Drag Player here in Inspector
@export var height: float = 6.0
@export var distance: float = 5.0
@export var lerp_speed: float = 10.0
@export var min_distance: float = 1.0
@export var max_distance: float = 20.0
@export var zoom_step: float = 0.8
@export var orthographic_min_size: float = 2.0
@export var orthographic_max_size: float = 40.0
@export var rotation_speed: float = 90.0  # degrees per second

var rotation_angle: float = 0.0  # Current rotation around the player (in degrees)

func _ready() -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")  # Add Player to "player" group

func _process(delta: float) -> void:
	# Check Q/E keys for rotation
	if Input.is_key_pressed(KEY_Q):
		rotation_angle -= rotation_speed * delta
	if Input.is_key_pressed(KEY_E):
		rotation_angle += rotation_speed * delta
	
	var target_pos := target.global_position
	target_pos.y += height
	
	# Calculate offset based on rotation angle
	var angle_rad := deg_to_rad(rotation_angle)
	var offset := Vector3(
		sin(angle_rad) * distance,
		0.0,
		-cos(angle_rad) * distance
	)
	
	var desired_pos := target_pos + offset
	global_position = global_position.lerp(desired_pos, lerp_speed * delta)
	
	# Look at player
	look_at(target_pos, Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()

func _zoom_in() -> void:
	distance = max(min_distance, distance - zoom_step)
	var cam := $Camera3D if has_node("Camera3D") else null
	if cam and cam.projection == 1:
		cam.size = clamp(cam.size - zoom_step * 2.0, orthographic_min_size, orthographic_max_size)

func _zoom_out() -> void:
	distance = min(max_distance, distance + zoom_step)
	var cam := $Camera3D if has_node("Camera3D") else null
	if cam and cam.projection == 1:
		cam.size = clamp(cam.size + zoom_step * 2.0, orthographic_min_size, orthographic_max_size)
