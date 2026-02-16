extends RigidBody3D

@onready var gp = global_transform
@onready var ms=[$ServerRack,$FaxModem]
@onready var ms_m={
	$ServerRack: $Rack,
	$FaxModem: $Rack2
}
@onready var c=$ServerRack:
	set(v):
		if c!=null:
			c.hide()
			ms_m[c].disabled = true
		c=v
		v.show()
		ms_m[v].disabled = false

var t=0
func _process(delta):
	t+=delta
	if t>5:
		t=0
		global_transform = gp
		linear_velocity = Vector3.ZERO
		c = ms.pick_random()
		rotate_y(randf()*6.283)
