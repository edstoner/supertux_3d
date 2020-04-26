extends StaticBody

var started = false
var speed = 0.5
var startpos
var moving = false
var movevec = Vector3(0,0,0)

func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	#set_as_toplevel(true)
	startpos = global_transform.origin

func turnscrew(hitloc):
	if not started:
		if hitloc.y > global_transform.origin.y:
			started = true
			#print("TURN SCREW")
			movevec = Vector3(0,-1,0)
			moving = true

func _physics_process(delta):
	if moving:
		global_translate(movevec*speed*delta)
		global_rotate(Vector3(0,1,0),-0.1)
		force_update_transform()
		if global_transform.origin.distance_to(startpos) > .6:
			moving = false
			get_parent().startmove()
