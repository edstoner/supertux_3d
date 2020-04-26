extends StaticBody

var speed = 3.3
var moving = false
var moveonslam = true
var movevec = Vector3(0,0,0)
var movedir = 1

func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)

func startplatmove(hitloc):
	#print("START PLATFORM MOVING")
	if hitloc.y < 0 and global_transform.origin.y < 0:
		moving = true
		movevec = global_transform.basis.y
		movedir = 1
		#print("Moving Platform UP")
	if hitloc.y > 0 and global_transform.origin.y > 0:
		moving = true
		movevec = global_transform.basis.y
		movedir = -1
		#print("Moving Platform DOWN")

func _physics_process(delta):
	if movevec:
		global_translate(movevec*movedir*speed*delta)
		force_update_transform()
		if movedir == 1:
			if global_transform.origin.y >= 1:
				movevec = Vector3(0,0,0)
		else:
			if global_transform.origin.y <= -1:
				movevec = Vector3(0,0,0)

