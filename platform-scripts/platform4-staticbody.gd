extends StaticBody
var speed = 3.3
var xdir = -1
var moving = false
var movevec = Vector3(0,0,0)
var startz
var gravitywhenstill = true


func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)
	startz = global_transform.origin.z

func startmove():
	#print("MOVE PLATFORM")
	moving = true

func _physics_process(delta):
	if moving:
		movevec = Vector3(0,0,1)*speed*delta*xdir
		global_translate(movevec)
		force_update_transform()
		if global_transform.origin.z > startz:
			xdir = -1
		if global_transform.origin.z < -10:
			xdir = 1
