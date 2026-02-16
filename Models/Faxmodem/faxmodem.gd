extends Node3D

var t = 0
var next_blink =1
@export var lights : Array[LightDataFrequency] = []

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	t+=delta
	if t>next_blink:
		next_blink = t+randf()*2
		$GreenLight.visible = not $GreenLight.visible
