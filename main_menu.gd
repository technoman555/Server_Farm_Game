extends Node3D

func _ready() -> void:
	find_child("Button").pressed.connect(func():
		get_tree().change_scene_to_file("res://Main.tscn")
	)
	find_child("Button3").pressed.connect(func():
		get_tree().quit()
	)
