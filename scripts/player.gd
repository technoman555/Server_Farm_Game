extends CharacterBody3D

@export var speed: float = 8.0
@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	direction.y = 0
	direction = direction.normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()
