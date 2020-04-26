extends StaticBody

var speed = 3.3
var movevec
var rotangle
var rotvec
var nogroundclamp = true

func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)


func _physics_process(delta):
	movevec = global_transform.basis.z*speed*delta
	rotangle = delta*speed*0.15
	rotvec = global_transform.basis.y
	#global_transform.origin += global_transform.basis.z*speed*delta
	global_translate(movevec)
	global_rotate(rotvec,rotangle)
	force_update_transform()
