extends KinematicBody

var speed = 2.0
var movevec
#var movedir = 1.0
var aplayer
var rotating = 0
var rng = RandomNumberGenerator.new()
var rotateang = 0
var movelen = 3.0
var movedist = 0
var planetnormal = Vector3(0,1,0)


# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)
	aplayer = get_node("godotbotanim/AnimationPlayer")
	rng.randomize()
	
	var space_state = get_world().direct_space_state
	var rayfrom = global_transform.origin
	var rayto = global_transform.origin+(global_transform.basis.y.normalized()*-3)
	var result = space_state.intersect_ray(rayfrom,rayto,[self],1)
	if result:
		planetnormal = result.normal
	else:
		print("ERROR NO PLANET FOR ROBOT")

func align_up(node_basis, normal):   
	var result = Basis()
	var origscale = node_basis.get_scale()
	result.x = normal.cross(node_basis.z)
	result.y = normal
	result.z = node_basis.x.cross(normal)
	
	# check if z or x is flipped and flip them back
	if node_basis.x.angle_to(result.x) > 3:
		#print('X-FLIPPED')
		result.x = result.x * -1
	if node_basis.z.angle_to(result.x) > 3:
		result.z = result.z * -1
		#print('Z-FLIPPED')
	result = result.orthonormalized()
	result.x *= abs(origscale.x) #
	result.y *= abs(origscale.y) #
	result.z *= abs(origscale.z) #

	return result

func aligntoground():
	# ALIGN TO GROUND
	var onground = false
	var grounddist = -1
	var rayfrom = global_transform.origin
	var rayto = global_transform.origin+(global_transform.basis.y.normalized()*-7)
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(rayfrom,rayto,[self],1)
	if result:
		var groundpos = result.position
		# NOTE: the below sometimes flips the z vector (makes it point in the opposite direction)
		var pby = global_transform.basis.y
		if pby.dot(planetnormal) == -1:
			#vectors are 180 degree difference
			pby += (global_transform.basis.x * .01)
			#pby.normalized()
		var lidir = pby.linear_interpolate(result.normal,0.4).normalized()
		global_transform.basis = align_up(global_transform.basis,lidir)
		force_update_transform()
		orthonormalize()
		planetnormal = result.normal.normalized()
		# CLAMP TO GROUND
		grounddist = global_transform.origin.distance_to(groundpos)
		global_transform.origin = groundpos+(planetnormal.normalized()*.75)
		force_update_transform()
		onground = true
	else:
		print('ERROR-NOPLANET')
	return [onground,grounddist]

func _physics_process(delta):
	if aplayer.current_animation != "Walk":
		aplayer.play("Walk",-1,1.5)

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
	
	if obstacleahead:
		# start/keep rotating
		#print("START ROTATING ROBOT")
		rotateang = rng.randf_range(-1.0, 1.0)
		global_rotate(planetnormal,0.02)
		rotating = 0.02
	elif rotating > 0:
		# rotate for 40 degrees
		if rotating >= rotateang:
			rotating = 0
			movelen = rng.randf_range(1.0,5.0)
			movedist = 0
			#print("STOP ROTATING")
		else:
			global_rotate(planetnormal,0.02)
			rotating += 0.02
	else:
		movevec = global_transform.basis.z*speed*delta
		var gravityvec = planetnormal * -1 * 3.0 * delta
		var _kcol = move_and_collide(movevec + gravityvec)
		aligntoground()
		movedist += movevec.length()
		if movedist >= movelen:
			rotateang = rng.randf_range(-1.0, 1.0)
			global_rotate(planetnormal,0.02)
			rotating = 0.02
	force_update_transform()


