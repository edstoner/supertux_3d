# Copyright 2020 Ed Stoner
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends Camera

var collision_exception = []
export var min_distance = 6.5
export var max_distance = 9.0
var maxdist_fromvert = 4.5

# export var angle_v_adjust = 0.0
# export var autoturn_ray_aperture = 30
# export var autoturn_speed = 95
var camspeed = 7.0
#var max_height = 3.0
#var min_height = 1.0
var count = 0
var lastcamvec
var lasttarget

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
	# set lastcamvec for interpolation
	var targetnode = get_parent()
	lasttarget = targetnode.global_transform.origin
	lastcamvec = global_transform.origin - lasttarget


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
	#var scene_root = get_tree().root.get_children()[0]
	#var targetnode = scene_root.get_node("tux")
	var targetnode = get_parent()
	var target = targetnode.global_transform.origin
	if target.distance_to(lasttarget) > 0.3:
		#print('%s-TARGET-LERP' % [count])
		target = lasttarget.linear_interpolate(target,0.1)
	lasttarget = target
	var pos = global_transform.origin
	var dss = get_world().direct_space_state
	# var up = Vector3(0, 1, 0)

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
	var camveclen = camvec.length()
	
	var lcamvec = (camvec + (global_transform.basis.x*delta*camspeed)).normalized() * camveclen
	var rcamvec = (camvec + (global_transform.basis.x*-delta*camspeed)).normalized() * camveclen
	var ucamvec = (camvec + (global_transform.basis.y*delta*camspeed)).normalized() * camveclen
	var dcamvec = (camvec + (global_transform.basis.y*-delta*camspeed)).normalized() * camveclen
	
	var manual_rotation = false
	# Manual Rotation
	if Input.is_action_pressed("cam_left"):
		manual_rotation = true
		#camvec = Basis(up, deg2rad(delta*autoturn_speed)).xform(camvec)
		camvec = lcamvec
	if Input.is_action_pressed("cam_right"):
		manual_rotation = true
		#camvec = Basis(up, deg2rad(-delta*autoturn_speed)).xform(camvec)
		camvec = rcamvec
	if Input.is_action_pressed("cam_up"):
		manual_rotation = true
		#camvec = Basis(targetnode.global_transform.basis.x, deg2rad(delta*autoturn_speed)).xform(camvec)
		camvec = ucamvec
	if Input.is_action_pressed("cam_down"):
		manual_rotation = true
		#camvec = Basis(targetnode.global_transform.basis.x, deg2rad(-delta*autoturn_speed)).xform(camvec)
		camvec = dcamvec
		
	if Input.is_action_just_pressed("cam_align"):
		pos = target + (targetnode.global_transform.basis.y*4.5) + (targetnode.global_transform.basis.z * -5.5)
		look_at_from_position(pos, target, targetnode.global_transform.basis.y)
		return

	# JOYSTICK
	if !(manual_rotation):
		var joypadrsh = Input.get_joy_axis(0,2)
		if abs(joypadrsh) > 0.02:
			#camvec = Basis(up, deg2rad(joypadrsh*delta*autoturn_speed)).xform(camvec)
			camvec = (camvec + (global_transform.basis.x*joypadrsh*-delta*camspeed)).normalized() * camveclen
			manual_rotation = true
		var joypadrsv = Input.get_joy_axis(0,3)
		if abs(joypadrsv) > 0.02:
			#camvec = Basis(targetnode.global_transform.basis.x, deg2rad(joypadrsv*delta*autoturn_speed)).xform(camvec)
			camvec = (camvec + (global_transform.basis.y*joypadrsv*delta*camspeed)).normalized() * camveclen
			manual_rotation = true
	
	# AUTO-CAMERA
	if !(manual_rotation):
		# Check angle (by distance from camera pos to point same distance straight above player)
		#var camangle = rad2deg(camvec.angle_to(targetnode.global_transform.basis.y))
		var movetopoint = target + (targetnode.global_transform.basis.y * camvec.length())
		var distfromvert = pos.distance_to(movetopoint)
		if distfromvert > maxdist_fromvert:
			#var movevec = pos.direction_to(movetopoint) * (distfromvert - maxdist_fromvert)
			var movevec = pos.direction_to(movetopoint) * camspeed * delta
			var newpos = pos + movevec
			camvec = newpos - target
		# Check ranges
		if (camvec.length() < min_distance):
			#print('%s-MINDISTANCE' % [count])
			camvec = camvec.normalized()*min_distance
		elif (camvec.length() > max_distance):
			#print('%s-MAXDISTANCE' % [count])
			camvec = camvec.normalized()*max_distance


		var col = dss.intersect_ray(target, target + camvec, collision_exception)
		var col_left = dss.intersect_ray(target, target + lcamvec, collision_exception)
		var col_right = dss.intersect_ray(target, target + rcamvec, collision_exception)
		var col_up = dss.intersect_ray(target, target + ucamvec, collision_exception)
		#var col_left = ds.intersect_ray(target, target + Basis(up, deg2rad(autoturn_ray_aperture)).xform(camvec), collision_exception)
		#var col_right = ds.intersect_ray(target, target + Basis(up, deg2rad(-autoturn_ray_aperture)).xform(camvec), collision_exception)
		#var col_up = ds.intersect_ray(target, target + Basis(tarx, deg2rad(autoturn_ray_aperture)).xform(camvec), collision_exception)
		if (!col.empty()):
			if (!col_left.empty() and col_right.empty()):
				# If only left ray is occluded, turn the camera around to the right
				#camvec = Basis(up, deg2rad(-delta*autoturn_speed)).xform(camvec)
				camvec = rcamvec
			elif (col_left.empty() and !col_right.empty()):
				# If only right ray is occluded, turn the camera around to the left
				#camvec = Basis(up, deg2rad(delta*autoturn_speed)).xform(camvec)
				camvec = lcamvec
			elif (col_up.empty()):
				#camvec = Basis(tarx, deg2rad(delta*autoturn_speed)).xform(camvec)
				camvec = ucamvec
				#print('%s:CAMROT-UP' % count)
			else:
				#If main ray was occluded, get camera closer, worst case scenario
				#camvec = col.position - target
				#camvec = pos - target
				pass # DO NOTHING

	# ERROR Check
	if (camvec == Vector3()):
		print('CAMERA MESSED UP!')
		camvec = (pos - target).normalized()*0.0001
		
	# Apply lookat
	
	# Interpolate between camvecs
	#camvec = lastcamvec.linear_interpolate(camvec,0.2)
	lastcamvec = camvec
	pos = target + camvec

	var camcol = dss.intersect_ray(target, pos, collision_exception)
	if camcol and manual_rotation:
		# Don't let manual control move camera into things
		return
	#	pos = camcol.position
	#look_at_from_position(pos, target, up)
	look_at_from_position(pos, target, global_transform.basis.y)
		
	# Turn a little up or down
	#var t = get_transform()
	#t.basis = Basis(t.basis[0], deg2rad(angle_v_adjust))*t.basis
	#set_transform(t)


