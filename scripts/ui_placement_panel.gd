extends CanvasLayer

@onready var toggle_button = $PanelContainer/VBoxContainer/HBoxContainer/ToggleButton
@onready var panel_container = $PanelContainer
@onready var open_button = $OpenButton
@onready var content_container = $PanelContainer/VBoxContainer/ContentContainer
@onready var cluster_button = $PanelContainer/VBoxContainer/ContentContainer/ClusterButton
@onready var server_button = $PanelContainer/VBoxContainer/ContentContainer/ServerButton
@onready var cable_button = $PanelContainer/VBoxContainer/ContentContainer/CableButton
@onready var cancel_button = $PanelContainer/VBoxContainer/ContentContainer/CancelButton
@onready var selected_label = $PanelContainer/VBoxContainer/ContentContainer/SelectedLabel

var room: Node3D
var current_selection: String = ""
var is_visible: bool = true

const TEST_OBJECT = preload("res://Scene/early_server.tscn")
const SERVER = preload("res://Scene/server.tscn")
const CLUSTER = preload("res://Scene/cluster.tscn")
const CABLE = preload("res://Scene/cable.tscn")

func _ready() -> void:
	room = get_tree().root.get_node("Main/Room")
	
	cluster_button.pressed.connect(_on_cluster_pressed)
	server_button.pressed.connect(_on_server_pressed)
	cable_button.pressed.connect(_on_cable_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	toggle_button.pressed.connect(_on_toggle_pressed)
	open_button.pressed.connect(_on_open_pressed)
	
	update_label()

func _on_toggle_pressed() -> void:
	is_visible = not is_visible
	panel_container.visible = is_visible
	open_button.visible = not is_visible

func _on_open_pressed() -> void:
	is_visible = true
	panel_container.visible = is_visible
	open_button.visible = false



func _on_cluster_pressed() -> void:
	current_selection = "cluster"
	update_label()
	if room and room.has_method("set_placement_item"):
		room.set_placement_item(CLUSTER)

func _on_server_pressed() -> void:
	current_selection = "server"
	update_label()
	if room and room.has_method("set_placement_item"):
		room.set_placement_item(SERVER)

func _on_cable_pressed() -> void:
	current_selection = "cable"
	update_label()
	if room and room.has_method("set_placement_item"):
		room.set_placement_item(CABLE)

func _on_cancel_pressed() -> void:
	current_selection = ""
	update_label()
	if room and room.has_method("set_placement_item"):
		room.set_placement_item(null)

func update_label() -> void:
	if current_selection == "":
		selected_label.text = "None Selected"
	else:
		selected_label.text = "Selected: " + current_selection.to_upper()
