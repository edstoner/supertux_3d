extends KinematicBody

var speed = 2.0
var movevec
#var movedir = 1.0
var aplayer
var rotating = 0
var rng = RandomNumberGenerator.new()
var randnum
var planetup = Vector3(0,1,0)


# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)
	aplayer = get_node("godotbotanim/AnimationPlayer")
	rng.randomize()
	randnum = rng.randf_range(-0.1, 0.8)
	#print("RANDNUM: %s" % randnum)
	
	var space_state = get_world().direct_space_state
	var rayfrom = global_transform.origin
	var rayto = global_transform.origin+(global_transform.basis.y.normalized()*-3)
	var result = space_state.intersect_ray(rayfrom,rayto,[self],1)
	if result:
		planetup = result.normal
	else:
		print("ERROR NO PLANET FOR ROBOT")

func _physics_process(delta):
	if aplayer.current_animation != "Walk":
		aplayer.play("Walk")

	var space_state = get_world().direct_space_state
	var rayafrom = global_transform.origin
	var rayato = global_transform.origin+(global_transform.basis.y.normalized()*-3)
	var resulta = space_state.intersect_ray(rayafrom,rayato,[self],1)
	var grounddist = 0
	if resulta:
		grounddist = rayafrom.distance_to(resulta.position)
	else:
		print('ERROR: NO GROUND UNDER ROBOT')
	var raybfrom = global_transform.origin+global_transform.basis.z
	var raybto = raybfrom+(global_transform.basis.y.normalized()*-3)
	var resultb = space_state.intersect_ray(raybfrom,raybto,[self],1)
	var forwardgrounddist = 0
	if resultb:
		forwardgrounddist = raybfrom.distance_to(resultb.position)
	var groundaheadflat = true
	if abs(grounddist - forwardgrounddist) > 0.1:
		groundaheadflat = false
		#print("%s - %s" % [grounddist,forwardgrounddist])
	
	var obstacleahead = false
	var raycfrom = global_transform.origin
	var raycto = global_transform.origin+(global_transform.basis.z.normalized()*1)
	var resultc = space_state.intersect_ray(raycfrom,raycto,[self],2147483647,true,true)
	if resultc:
		obstacleahead = true
		#print("OBSTACLE AHEAD: %s" % get_parent().name)
	
	if not groundaheadflat or obstacleahead:
		# start/keep rotating
		#print("START ROTATING ROBOT")
		global_rotate(planetup,0.02)
		#global_rotate(Vector3(0,1,0),0.02)
		rotating += 0.02
	elif rotating > 0:
		# rotate for 40 degrees
		if rotating > 0.6+randnum:
			rotating = 0
			#print("STOP ROTATING")
		else:
			global_rotate(planetup,0.02)
			#global_rotate(Vector3(0,1,0),0.02)
			rotating += 0.02
	else:
		movevec = global_transform.basis.z*speed*delta
		global_translate(movevec)
	force_update_transform()


