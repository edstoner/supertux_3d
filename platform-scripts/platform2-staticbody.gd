extends StaticBody
var speed = 3.3
var xdir = -1
var movevec
var startz
var rotangle
var rotvec

func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)
	startz = global_transform.origin.z


func _physics_process(delta):
	#print('Global Trans:%s' % global_transform.origin)
	if global_transform.origin.z < startz:
		xdir = -1
	if global_transform.origin.z > 6:
		xdir = 1
	movevec = global_transform.basis.x*speed*delta*xdir
	global_translate(movevec)
	rotangle = delta*speed*0.15
	rotvec = global_transform.basis.x
	global_rotate(rotvec,rotangle)
	force_update_transform()

