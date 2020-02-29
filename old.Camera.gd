extends Camera

var collision_exception = []
export var min_distance = 7.5
export var max_distance = 12.0
export var angle_v_adjust = 0.0
export var autoturn_ray_aperture = 30
export var autoturn_speed = 95
#var max_height = 3.0
#var min_height = 1.0
var count = 0

func _ready():
	# Find collision exceptions for ray
	var node = self
	while(node):
		if (node is RigidBody):
			collision_exception.append(node.get_rid())
			break
		else:
			node = node.get_parent()
	set_physics_process(true)
	# This detaches the camera transform from the parent spatial node
	set_as_toplevel(true)


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

func _physics_process(delta):
	count += 1
	var scene_root = get_tree().root.get_children()[0]
	#var targetnode = scene_root.get_node("tux")
	var targetnode = get_parent()
	var target = targetnode.global_transform.origin
	target += (targetnode.global_transform.basis.y * -.35)
	#var target = get_parent().get_global_transform().origin
	var pos = get_global_transform().origin
	var up = Vector3(0, 1, 0)

	# Rotate to same y/up as player
	#var up = targetnode.global_transform.basis.y
	#var pby = global_transform.basis.y
	#if pby.dot(up) == -1:
	#		#vectors are 180 degree difference
	#		pby += (global_transform.basis.x * .01)
	#		pby.normalized()
	#var lidir = pby.linear_interpolate(up,0.05).normalized()
	#global_transform.basis = align_up(global_transform.basis,lidir)


	var camvec = pos - target
	
	var manual_rotation = false
	# Manual Rotation
	if Input.is_action_pressed("cam_left"):
		manual_rotation = true
		camvec = Basis(up, deg2rad(delta*autoturn_speed)).xform(camvec)
		#camvec = Basis(global_transform.basis.y, deg2rad(delta*autoturn_speed)).xform(camvec)
	if Input.is_action_pressed("cam_right"):
		manual_rotation = true
		camvec = Basis(up, deg2rad(-delta*autoturn_speed)).xform(camvec)
		#camvec = Basis(global_transform.basis.y, deg2rad(-delta*autoturn_speed)).xform(camvec)
	if Input.is_action_pressed("cam_up"):
		manual_rotation = true
		camvec = Basis(targetnode.global_transform.basis.x, deg2rad(delta*autoturn_speed)).xform(camvec)
		#camvec = Basis(global_transform.basis.x, deg2rad(delta*autoturn_speed)).xform(camvec)
	if Input.is_action_pressed("cam_down"):
		manual_rotation = true
		camvec = Basis(targetnode.global_transform.basis.x, deg2rad(-delta*autoturn_speed)).xform(camvec)
		#camvec = Basis(global_transform.basis.x, deg2rad(-delta*autoturn_speed)).xform(camvec)
	# Check autoturn
	if !(manual_rotation):
		var joypadrsh = Input.get_joy_axis(0,2)
		if abs(joypadrsh) > 0.02:
			camvec = Basis(up, deg2rad(joypadrsh*delta*autoturn_speed)).xform(camvec)
			manual_rotation = true
		var joypadrsv = Input.get_joy_axis(0,3)
		if abs(joypadrsv) > 0.02:
			camvec = Basis(targetnode.global_transform.basis.x, deg2rad(joypadrsv*delta*autoturn_speed)).xform(camvec)
			manual_rotation = true
	
	if !(manual_rotation):
		# Check ranges
		if (camvec.length() < min_distance):
			camvec = camvec.normalized()*min_distance
		elif (camvec.length() > max_distance):
			camvec = camvec.normalized()*max_distance
	
		# Check upper and lower height
		#if (camvec.y > max_height):
		#	camvec.y = max_height
		#if (camvec.y < min_height):
		#	camvec.y = min_height
		
		#var ds = PhysicsServer.space_get_direct_state(get_world().get_space())
		var ds = get_world().direct_space_state

		var tarx = targetnode.global_transform.basis.x

		var col = ds.intersect_ray(target, target + camvec, collision_exception)
		var col_left = ds.intersect_ray(target, target + Basis(up, deg2rad(autoturn_ray_aperture)).xform(camvec), collision_exception)
		var col_right = ds.intersect_ray(target, target + Basis(up, deg2rad(-autoturn_ray_aperture)).xform(camvec), collision_exception)
		var col_up = ds.intersect_ray(target, target + Basis(tarx, deg2rad(autoturn_ray_aperture)).xform(camvec), collision_exception)
		if (!col.empty()):
			if (!col_left.empty() and col_right.empty()):
				# If only left ray is occluded, turn the camera around to the right
				camvec = Basis(up, deg2rad(-delta*autoturn_speed)).xform(camvec)
			elif (col_left.empty() and !col_right.empty()):
				# If only right ray is occluded, turn the camera around to the left
				camvec = Basis(up, deg2rad(delta*autoturn_speed)).xform(camvec)
			elif (col_up.empty()):
				camvec = Basis(tarx, deg2rad(delta*autoturn_speed)).xform(camvec)
				#print('%s:CAMROT-UP' % count)
			else:
				#If main ray was occluded, get camera closer, worst case scenario
				#camvec = col.position - target
				camvec = pos - target

	# Apply lookat
	if (camvec == Vector3()):
		print('CAMERA MESSED UP!')
		camvec = (pos - target).normalized()*0.0001
	pos = target + camvec
		
	look_at_from_position(pos, target, up)
		
	# Turn a little up or down
	var t = get_transform()
	t.basis = Basis(t.basis[0], deg2rad(angle_v_adjust))*t.basis
	set_transform(t)


