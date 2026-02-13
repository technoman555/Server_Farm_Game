extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
var _pending_selection: Node3D = null


class CrosshairControl:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center = Vector2(16, 16)
		var len = 8
		var col = Color(1, 1, 1)
		draw_line(center + Vector2(-len, 0), center + Vector2(len, 0), col, 2)
		draw_line(center + Vector2(0, -len), center + Vector2(0, len), col, 2)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Add a simple HUD crosshair centered on screen
	var hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	var cross = CrosshairControl.new()
	# Position the 32x32 crosshair at the viewport center
	var vp_size = get_viewport().get_visible_rect().size
	cross.position = vp_size * 0.5 - Vector2(16, 16)
	hud_layer.add_child(cross)
	cross.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, -1.2, 1.2)  # Limit vertical look

	# Left click interaction: select/connect/disconnect
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000.0
		var space = get_world_3d().direct_space_state
		var params = PhysicsRayQueryParameters3D.new()
		params.from = from
		params.to = to
		params.exclude = [self]
		var result = space.intersect_ray(params)
		if not result:
			return
		var collider = result.get("collider")
		var node = _find_connectable_node(collider)
		if not node:
			return
		# If no pending selection, store it
		if _pending_selection == null:
			_pending_selection = node
			print("Selected: ", node.name)
			return
		# If same node clicked twice, deselect
		if _pending_selection == node:
			_pending_selection = null
			print("Deselected")
			return
		# Check for existing wire between the two (order-independent)
		for w in get_tree().get_nodes_in_group("wires"):
			if w is Wire3D:
				if (w.start_obj == _pending_selection and w.end_obj == node) or (w.start_obj == node and w.end_obj == _pending_selection):
					w.queue_free()
					print("Removed wire between ", _pending_selection.name, " and ", node.name)
					_pending_selection = null
					return
		# Create new wire
		var wire = Wire3D.new()
		var root = get_tree().get_current_scene()
		if root:
			root.add_child(wire)
			wire.set_ends(_pending_selection, node)
			print("Created wire between ", _pending_selection.name, " and ", node.name)
			_pending_selection = null


func _find_connectable_node(collider) -> Node3D:
	var n = collider
	while n:
		if n is Node3D:
			return n
		n = n.get_parent()
	return null

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():  # Space
		velocity.y = jump_velocity

	# Get input direction
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
