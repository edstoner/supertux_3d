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

extends KinematicBody

var tics = 0
var gametime = 0
var speed = 5.0
var jumpspeed = 5.0
var jumping = 0
var longjump = false
var sideflip = false
var slam = false
var slamground = 0
var jumpforce = 0
var jumpvec = Vector3(0,0,0)
var jumpbasis
var jumppresstime = 0
var fulljump = false
var forward = 0
var wallslide = false
var ledgehang = false
var sliding = false
var crashing = false
var planets = []
var lava = []
var planet
var planetnormal
var aplayer
var runpart
var jumppart
var bubblepart
var wakepart
var wallslidepart
var smokepart
var moveopposite = 0
var inwater = false
var runcol
var slidecol
var marblecount = 0
var mclabel
var gametimelabel

func _ready():
	set_physics_process(true)
	set_notify_local_transform(true)
	set_notify_transform(true)
	# attach to closet ground

	var scene_root = get_tree().root.get_children()[0]
	aplayer = scene_root.get_node("tux/tuxanim/AnimationPlayer")
	
	#planet = scene_root.get_node("planet/planet-mesh/planet-staticbody")
	#planets.append(planet)
	#planets.append(scene_root.get_node("moon/moon-mesh/moon-staticbody"))

	planets = get_tree().get_nodes_in_group('gravitybodies')
	lava = get_tree().get_nodes_in_group('lava')
	for pl in planets:
		print('PLANET:%s' % [pl.name])

	# ATTACH to curentplanet
	# NOTE: planet needs to be underneath tux in scene
	var rayfrom = global_transform.origin
	#var rayto = planet.global_transform.origin
	var rayto = rayfrom + Vector3(0,-10,0)
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(rayfrom,rayto,[self])
	if result:
		planet = result.collider
		global_transform.basis = align_up(global_transform.basis, result.normal.normalized())
		force_update_transform()
		orthonormalize()
		var raypos = result.position
		planetnormal = result.normal.normalized()
		global_transform.origin = raypos+(planetnormal*.5)
		force_update_transform()
		orthonormalize()
	else:
		print('ERROR-ERROR-ERROR')
	runpart = scene_root.get_node("tux/emitpoint/runparticles")
	jumppart = scene_root.get_node("tux/emitpoint/jumpparticles")
	bubblepart = scene_root.get_node("tux/emitpoint/bubbleparticles")
	wakepart = scene_root.get_node("tux/emitpoint/wakeparticles")
	wallslidepart = scene_root.get_node("tux/emitpoint/wallslideparticles")
	smokepart = scene_root.get_node("tux/emitpoint/smokeparticles")
	
	# connect water areas
	var waterareas = get_tree().get_nodes_in_group('waterareas')
	for waterarea in waterareas:
		waterarea.connect("body_entered",self,"_on_waterarea_body_entered")
		waterarea.connect("body_exited",self,"_on_waterarea_body_exited")
	
	# connect marble collisions
	var marbles = get_tree().get_nodes_in_group('marbles')
	for marblearea in marbles:
		marblearea.connect("body_entered",self,"_on_marblearea_body_entered",[marblearea])
	mclabel = scene_root.get_node("HUD/MarbleCount")
	gametimelabel = scene_root.get_node("HUD/GameTime")
	
	# collision shapes
	runcol = scene_root.get_node("tux/runcolshape")
	runcol.disabled = false
	slidecol = scene_root.get_node("tux/slidecolshape")
	slidecol.disabled = true


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
	
func align_up_noscale(node_basis, normal):
	var result = Basis()
	result.x = normal.cross(node_basis.z)
	result.y = normal
	result.z = node_basis.x.cross(normal)
	result.orthonormalized()
	return result

func align_forward(node_basis,fvec):
	var result = Basis()
	var origscale = node_basis.get_scale()
	#result.x = fvec.cross(node_basis.z)
	#result.y = fvec
	#result.z = node_basis.x.cross(fvec)

	result.y = fvec.cross(node_basis.x)
	result.z = fvec
	result.x = node_basis.y.cross(fvec)
		
	# check if y is flipped and flip them back
	if node_basis.y.angle_to(result.y) > 3:
		result.y = result.y * -1
		print('Y-FLIPPED')
	result = result.orthonormalized()
	result.x *= abs(origscale.x) #
	result.y *= abs(origscale.y) #
	result.z *= abs(origscale.z) #

	return result

func getnearest(playernode,plist):
	var space_state = get_world().direct_space_state
	var nearestdistance = 10000
	var nearnorm = Vector3(0,1,0)
	var nearplanet = plist[0]
	for xplanet in plist:
		var dplist = plist.duplicate(true)
		var i = dplist.find(xplanet)
		dplist.remove(i)
		dplist.append(playernode)
		# NOTE: the below doesn't take into account planets in between other planets
		var xresult = space_state.intersect_ray(playernode.global_transform.origin,xplanet.global_transform.origin,dplist,1)
		if xresult:
			if xresult.collider != xplanet:
				print("WRONGPLANET-shouldbe:%s, is:%s" % [xplanet.name,xresult.collider.name])
			var xdistance = playernode.global_transform.origin.distance_to(xresult.position)
			if xdistance < nearestdistance:
				nearestdistance = xdistance
				nearplanet = xresult.collider
				nearnorm = xresult.normal
	return [nearplanet,nearnorm,nearestdistance]

func aligntoground():
	# ALIGN TO GROUND
	var onground = false
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
			pby.normalized()
		var lidir = pby.linear_interpolate(result.normal,0.4).normalized()
		global_transform.basis = align_up(global_transform.basis,lidir)
		force_update_transform()
		orthonormalize()
		planetnormal = result.normal.normalized()
		if result.collider != planet:
			print("%s-Changed Planets RUNNING from %s to %s" % [tics,planet.name,result.collider.name])
			planet = result.collider
		# CLAMP TO GROUND
		if abs(global_transform.origin.distance_to(groundpos)) < 0.6:
			global_transform.origin = groundpos+(planetnormal*.5)
			force_update_transform()
			onground = true
	else:
		print('ERROR-NOPLANET')
	return onground

func secstotimestr(gametime):
	var minutes = int(gametime) / 60
	var seconds = int(gametime) % 60
	return "%02d:%02d" % [minutes,seconds]

func _physics_process(delta):
	tics += 1
	gametime += delta
	gametimelabel.text = secstotimestr(gametime)

	var rotate = 0
	var jumppress = false
	var crouchpress = false
	var downpress = false
	var spinpress = false
	var slidepress = false
	
	if Input.is_action_just_pressed("ui_select"):
		jumppress = true
	if Input.is_action_just_pressed("spin"):
		spinpress = true
	if Input.is_action_pressed("crouch"):
		crouchpress = true
	if Input.is_action_pressed("ui_down"):
		downpress = true
	if Input.is_action_pressed("ui_up"):
		if (not crouchpress) and (not wallslide) and (not downpress) and (not ledgehang) and (not sliding) and (not crashing):
			if (jumping == 0) or ((gametime - jumping) > 0.8):
				if forward < 1.0:
					forward += 0.1
	if Input.is_action_pressed("slide-dive"):
		slidepress = true
	if Input.is_action_pressed("ui_left"):
		rotate = 1
	if Input.is_action_pressed("ui_right"):
		rotate = -1

	var inslidedive = false
	if jumping > 0:
		if aplayer.current_animation == "BellySlide":
			inslidedive = true

	if jumping > 0:
		if Input.is_action_pressed("ui_select"):
			jumppresstime += delta
		else:
			jumppresstime = 0
	else:
		jumppresstime = 0

	# JOYSTICK CONTROL
	#var scene_root = get_tree().root.get_children()[0]
	if moveopposite > 0:
		if gametime - moveopposite > 0.3:
			moveopposite = 0
		else:
			downpress = true

	var joydir = Vector3(0,0,0)
	var camera = get_node("Camera")
	var joypadleftstickhorz = Input.get_joy_axis(0,0)
	var joypadleftstickvert = Input.get_joy_axis(0,1)
	var cambasisproj = align_forward(camera.global_transform.basis,global_transform.basis.y)
	if ((abs(joypadleftstickhorz) > 0.02) or (abs(joypadleftstickvert) > 0.02)):
		joydir += cambasisproj.x*joypadleftstickhorz
		joydir += -1*(cambasisproj.y*joypadleftstickvert)
		joydir.normalized()
		if (not crouchpress) and (not wallslide) and (not downpress) and (not ledgehang) and (not sliding) and (not crashing):
			if (jumping == 0) or ((gametime - jumping) > 0.8):
				forward = joydir.length()
		var pbz = global_transform.basis.z
		if (moveopposite == 0) and (pbz.dot(joydir) < -0.6):
			moveopposite = gametime
			#print('MOVEOPPOSITE')
		if pbz.dot(joydir) == -1:
			# vectors are 180 degrees apart and linear interpolate gives error
			pbz += global_transform.basis.x * 0.01
			pbz.normalized()
		var lidir = pbz.linear_interpolate(joydir,0.3).normalized()
		if sliding or longjump:
			lidir = pbz.linear_interpolate(joydir,0.02).normalized()
		# ROTATE
		if (not wallslide) and (not ledgehang) and (not crashing) and (not sideflip) and (not inslidedive):
			global_transform.basis = align_forward(global_transform.basis,lidir)

	var space_state = get_world().direct_space_state

	#ROTATE
	if rotate and (not wallslide) and (not sideflip) and (not ledgehang) and (not crashing) and (not inslidedive):
		if sliding or longjump:
			global_rotate(global_transform.basis.y,rotate*delta*speed*0.2)
		else:
			global_rotate(global_transform.basis.y,rotate*delta*speed)

	if wallslide:
		if not $slidesound.playing:
			$slidesound.play()
		var canjump = false
		if aplayer.get_current_animation_position() > 0.2:
			wallslidepart.emitting = true
			canjump = true
		var gravityvec = planetnormal * -1 * 5.0 * delta
		var fmovevec = global_transform.basis.z.normalized() * forward * delta
		var kcol = move_and_collide(gravityvec + fmovevec)
		if kcol:
			if rad2deg(kcol.normal.angle_to(global_transform.basis.y)) < 40:
				wallslide = false
				$slidesound.stop()
				wallslidepart.emitting = false
			elif jumppress and canjump:
				wallslidepart.emitting = false
				global_rotate(global_transform.basis.y,3.14) # turn around
				force_update_transform()
				global_transform.origin += (global_transform.basis.z * 0.1) # move away from wall a little
				force_update_transform()
				orthonormalize()
				wallslide = false
				$slidesound.stop()
				aplayer.play('Walljump')
				$jumpsound.play()
				forward = 1
				jumpforce = 3.5
				jumping = gametime
				jumpvec = planetnormal 
				jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
				return
	elif ledgehang:
		var ldgmove = Input.get_joy_axis(0,0)
		if abs(ldgmove) > 0.02:
			rotate = ldgmove * -1
		if aplayer.current_animation == 'WallClimbUp':
			if aplayer.current_animation_position > 0.94:
				global_transform.origin += global_transform.basis.z * 0.5
				global_transform.origin += global_transform.basis.y * 1.0
				force_update_transform()
				ledgehang = false
				aplayer.play("Stand")
		elif jumppress:
			if Input.is_action_pressed("ui_up") or (rad2deg(joydir.angle_to(global_transform.basis.z)) < 15.0):
				aplayer.play("WallClimbUp")
			else:
				ledgehang = false
				print('LEDGE FALL')
				jumping = gametime
				jumpvec = planetnormal 
				jumpvec = jumpvec.normalized()
				jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
				runpart.emitting = false
				if $walksound.playing:
					$walksound.stop()
					#print('STOP-WALKSOUND1')
				wakepart.emitting = false
				jumpforce = 0
		elif rotate != 0:
			var ldgdownfrom = global_transform.origin + global_transform.basis.y*1.0 + global_transform.basis.z*0.5 + (global_transform.basis.x*.3*rotate)
			var ldgdownto = ldgdownfrom + global_transform.basis.y*-1.1
			var ldgdownrc = space_state.intersect_ray(ldgdownfrom,ldgdownto,[self])
			var ldgmovevec = (global_transform.basis.x * rotate) + (global_transform.basis.z * .01)
			if ldgdownrc:
				var _ldgcol = move_and_collide(ldgmovevec * delta)
				# align height with ledge height (ldgdownrc.position)
				ldgdownfrom = global_transform.origin + global_transform.basis.y*1.0 + global_transform.basis.z*0.5
				ldgdownto = ldgdownfrom + global_transform.basis.y*-1.1
				ldgdownrc = space_state.intersect_ray(ldgdownfrom,ldgdownto,[self])
				global_transform.origin = ldgdownrc.position + global_transform.basis.z*-0.5 + global_transform.basis.y*-0.5
				force_update_transform()
				if rotate == 1:
					aplayer.play('WallClimb.l')
				else:
					aplayer.play('WallClimb.r')
		else:
			aplayer.play('WallHang',0.3)
	elif slam:
		if aplayer.get_current_animation_position() > 0.5:
			var gravityvec = planetnormal * -1 * 12.0
			if slamground == 0:
				var kcol = move_and_collide(gravityvec * delta)
				if kcol:
					if kcol.collider in lava:
						print('IN LAVA') #NOTE: should really make the below a function
						slam = false
						aplayer.play('FireRun')
						$quacksound.play()
						jumpforce = 3.4
						forward = 1.0
						fulljump = true
						jumping = gametime
						jumpvec = planetnormal 
						jumpvec = jumpvec.normalized()
						jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
						smokepart.emitting = true
						return
					if rad2deg(kcol.normal.angle_to(global_transform.basis.y)) < 40:
					#if kcol.collider in planets:
						slamground = delta
						global_transform.basis = align_up(global_transform.basis, kcol.normal)
						force_update_transform()
						orthonormalize()
						#print('%s-COLLAND' % tics)
			else:
				if slamground < 0.03:
					# NOTE: This is a bit of a hack and assumes delta > 0 and < 0.03
					#       other option is to use another global variable to keep track
					#       of weather the particle system and sound have been played
					# only have to do this because the area signal doesn't fire right
					# when the player hits the ground, but one cycle after
					if inwater:
						bubblepart.restart()
						bubblepart.emitting = true
						$splashsound.play()
					else:
						jumppart.restart()
						jumppart.emitting = true
						$slamsound.play()
				slamground += delta
				if slamground > 0.5:
					slam = false
		else:
			#if Input.is_action_just_pressed("slide-dive"):
			if slidepress:
				#print('SLIDE-DIVE')
				aplayer.play('BellySlide')
				$launchsound.play()
				slam=false
				jumping = gametime
				jumpvec = planetnormal 
				jumpvec = jumpvec.normalized()
				jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
				jumpforce = 0.4
				forward = 2.0
				slidecol.disabled = false
				runcol.disabled = true
	elif jumping > 0:
		if $walksound.playing:
			$walksound.stop()
			#print('STOP-WALKSOUND2')
		# SLAM
		if crouchpress and (not longjump) and (not crashing) and (gametime-jumping > 0.5) and (aplayer.current_animation != 'BackFlip') and (aplayer.current_animation != 'BellySlide'):
			#print('SLAM!!-%s-%s' % [jumping,jumping>0])
			#print(aplayer.current_animation)
			jumping = 0
			longjump = false
			sideflip = false
			aplayer.play('Slam')
			slam = true
			slamground = 0
			return
		# FULL-JUMP
		if (not fulljump) and (not longjump) and (not crashing) and (gametime-jumping > 0.1) and (aplayer.current_animation != 'BackFlip') and (aplayer.current_animation != 'BellySlide'):
			if jumppresstime > 0.1:
				jumpforce += 1.2
				fulljump = true
		#var nearest = getnearest(self,planet,planets,tics)
		var nearest = getnearest(self,planets)
		var nearestplanet = nearest[0]
		#var nearestnorm = nearest[1]
		var nearestdistance = nearest[2]
		if nearestplanet != planet:
			print("%s-Changed Planets from %s to %s" % [tics,planet.name,nearestplanet.name])
		planet = nearestplanet
		planetnormal = nearest[1].normalized()

		#ALIGN TO PLANET
		var pby = global_transform.basis.y
		if pby.dot(planetnormal) == -1:
			#vectors are 180 degree difference
			pby += (global_transform.basis.x * .01)
			pby.normalized()
		var lidir = pby.linear_interpolate(planetnormal,0.15).normalized()
		global_transform.basis = align_up(global_transform.basis,lidir)

		# FRICTION
		if forward > 0:
			forward -= 0.01
		if forward < 0:
			forward += 0.01
		#CLAMP FORWARD
		if forward < 0.02 and forward > -0.02:
			forward = 0
		if jumpforce > 0:
			jumpforce -= (delta * 4.0)
			if jumpforce < 0:
				if abs(jumpforce) > 0.2:
					print('NEGATIVE JUMPFORCE:%s' % jumpforce)
				jumpforce = 0

		#MOVE
		var gravityvec = planetnormal * -1 * 5.0
		var jvec = jumpvec * jumpforce * jumpspeed
		if gametime - jumping > 0.8:
			jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
		else:
			jumpbasis = align_up(jumpbasis,global_transform.basis.y)
		var jfvec = jumpbasis.z.normalized() * forward * 5.0
		#var jrvec = global_transform.basis.z.normalized() * 1.3
		var kcol = move_and_collide((jvec + jfvec + gravityvec) * delta)
		force_update_transform()
		orthonormalize()
		
		# HANDLE COLLISIONS
		if kcol:
			var colnormangle = rad2deg(kcol.normal.angle_to(global_transform.basis.y))
			if colnormangle < 40: # ground
				if kcol.collider in lava:
					print('IN LAVA')
					aplayer.play('FireRun')
					$quacksound.play()
					jumpforce = 3.4
					forward = 1.0
					fulljump = true
					jumping = gametime
					jumpvec = planetnormal 
					jumpvec = jumpvec.normalized()
					jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
					runpart.emitting = false
					if $walksound.playing:
						$walksound.stop()
					wakepart.emitting = false
					smokepart.emitting = true
					return
				else:
					smokepart.emitting = false
				jumping = 0
				if crouchpress and (longjump or (aplayer.current_animation == 'BellySlide')):
					sliding = true
					slidecol.disabled = false
					runcol.disabled = true
					aplayer.play('BellySlide')
					aplayer.seek(0.2,true)
					forward = 2.2
				else:
					slidecol.disabled = true
					runcol.disabled = false
				longjump = false
				sideflip = false
				#global_transform.basis = align_up(global_transform.basis, kcol.normal)
				force_update_transform()
				orthonormalize()
				#print('%s-COLLAND' % tics)
				if crashing:
					pass
				elif inwater:
					bubblepart.restart()
					bubblepart.emitting = true
					$splashsound.play()
				else:
					jumppart.restart()
					jumppart.emitting = true
					$landsound.play()
			elif colnormangle < 120: # wall
				if crashing:
					return
				elif aplayer.current_animation == 'BellySlide':
					crashing = true
					aplayer.play('Crash')
					$crashsound.play()
					forward = 0
					jumpforce = 0
					return
				elif nearestdistance > 2.0:  # no wallslide if close to ground
					# rotate to align with wall, NOTE: below sometimes flips tux upside down
					var upbeforealign = global_transform.basis.y
					global_transform.basis = align_forward(global_transform.basis, -1*kcol.normal)
					force_update_transform()
					if upbeforealign.dot(global_transform.basis.y) < -0.8:
						print('Flipped upside down!!!')
					jumping = 0
					longjump = false
					sideflip = false
					var ldgdownfrom = global_transform.origin + global_transform.basis.y*1.0 + global_transform.basis.z*0.5
					var ldgdownto = ldgdownfrom + global_transform.basis.y*-1.1
					var ldgdownrc = space_state.intersect_ray(ldgdownfrom,ldgdownto,[self])
					var ldgfwdfrom = global_transform.origin + global_transform.basis.y*0.489
					var ldgfwdto = ldgfwdfrom + global_transform.basis.z*0.82
					var ldgfwdrc = space_state.intersect_ray(ldgfwdfrom,ldgfwdto,[self])
					var nearledge = false
					#print('LDGFWDRC:%s' % [ldgfwdrc])
					#print('LDGDOWNRC:%s' % [ldgdownrc])
					if not ldgfwdrc and ldgdownrc:
						nearledge = true
					#print('LDGFWDRAY:%s' % [ldgfwdray.is_colliding()])
					#print('LDGDOWNRAY:%s' % [ldgdownray.is_colliding()])
					#if ldgdownray.is_colliding() and (not ldgfwdray.is_colliding()):
					#	nearledge = true
					if nearledge:
						#print('LEDGE HANG')
						#print(ldgdownrc.collider.name)
						ledgehang = true
						forward = 0
						# align height with ledge height (ldgdownrc.position)
						global_transform.origin = ldgdownrc.position + global_transform.basis.z*-0.5 + global_transform.basis.y*-0.5
						force_update_transform()
						aplayer.play('WallHang')
					else:
						wallslide = true
						forward = 0.5
						aplayer.play('WallSlide')
						return
	else:   # ON FLOOR/GROUND
		if jumppress and (not sliding):
			if crouchpress:
				if forward > 0.1:
					longjump = true
					forward = 2.0
					jumpforce = 3.0
					aplayer.play('LongJump')
					$longjumpsound.play()
				else:
					aplayer.play('BackFlip')
					$backflipsound.play()
					jumpforce = 4.0
					forward = 0
			elif downpress or moveopposite:
				if forward > 0.1:
					sideflip = true
					jumpforce = 4.0
					forward = 1.0
					aplayer.play('SideFlip')
					$backflipsound.play()
					global_rotate(global_transform.basis.y,3.14) # turn around
					force_update_transform()
					orthonormalize()
				else:
					return
			else:
				aplayer.play('Jump')
				$jumpsound.play()
				jumpforce = 2.2
				fulljump = false
			#print('JUMP-%s' % gametime)
			jumping = gametime
			jumpvec = planetnormal 
			jumpvec = jumpvec.normalized()
			jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
			runpart.emitting = false
			if $walksound.playing:
				$walksound.stop()
				#print('STOP-WALKSOUND3')
			wakepart.emitting = false
		else:
			if forward != 0:
				if inwater:
					if not crashing:
						wakepart.emitting = true
						if not $watersound.playing:
							$watersound.play()
				else:
					if not crashing:
						runpart.emitting = true
						if not sliding:
							if not $walksound.playing:
								$walksound.play()
								#print('START-WALKSOUND')
						else:
							if $walksound.playing:
								$walksound.stop()
								#print('STOP-WALKSOUND4')
				if sliding:
					if not $slidesound.playing:
						$slidesound.play()
					if aplayer.current_animation == 'BellyPush':
						pass
					elif Input.is_action_just_pressed("slide-dive"):
						aplayer.play('BellyPush')
						forward = 2.0
					elif aplayer.current_animation != 'BellySlide':
						aplayer.play('BellySlide')
						aplayer.seek(0.2,true)
				elif crouchpress:
					if slidepress:
						sliding = true
						slidecol.disabled = false
						runcol.disabled = true
						aplayer.play('BellySlide')
						aplayer.seek(0.2,true)
						forward = 2.0
						return
					else:
						aplayer.play('Crouch')
						aplayer.seek(0.3,true)
						wakepart.emitting = false
						runpart.emitting = false
						#if $walksound.playing:
						#	$walksound.stop()
						#	print('STOP-WALKSOUND5')
				elif downpress:
					aplayer.play('KickStop')
					wakepart.emitting = false
					runpart.emitting = false
					#if $walksound.playing:
					#	$walksound.stop()
					#	print('STOP-WALKSOUND6')
				elif spinpress:
					aplayer.play('Spin')
					$spinsound.play()
				else:
					if aplayer.current_animation == 'Spin':
						if aplayer.current_animation_position > 1.0:
							aplayer.play('Walk',-1,abs(forward*2.5))
					else:
						aplayer.play('Walk',-1,abs(forward*2.5))

				# MOVE
				var gravityvec = planetnormal * -1 * 3.0 * delta
				var fmovevec = global_transform.basis.z.normalized() * forward * delta * speed
				var kcol = move_and_collide(fmovevec + gravityvec)
				var nofloorcollide = false
				if kcol:
					if kcol.collider in planets:
						#print('%s-colwithPLANET-%s-%s' % [tics,fmovevec,kcol.get_remainder()])
						global_transform.basis = align_up(global_transform.basis, kcol.normal.normalized())
						#global_translate(fmovevec)
						global_translate(kcol.get_remainder())
					else:
						if sliding:
							var kcolnormangle = rad2deg(kcol.normal.angle_to(global_transform.basis.y))
							if kcolnormangle > 55 and kcolnormangle < 120:
								print('CRASH:%s' % kcolnormangle)
								sliding = false
								crashing = true
								runpart.emitting = false
								if $walksound.playing:
									$walksound.stop()
									#print('STOP-WALKSOUND7')
								wakepart.emitting = false
								aplayer.play('Crash')
								if $slidesound.playing:
									$slidesound.stop()
								$crashsound.play()
								forward = 0
								return
						else:
							pass
							#print('OBJCOLLIDER:%s' % kcol.collider)
				else:
					nofloorcollide = true
				force_update_transform()
				orthonormalize()
				# FRICTION
				if forward > 0:
					if crouchpress or downpress:
						forward -= 0.05
					else:
						forward -= 0.02
				if forward < 0:
					if crouchpress or downpress:
						forward += 0.05
					else:
						forward += 0.02
				#CLAMP FORWARD
				if forward < 0.05 and forward > -0.05:
					forward = 0
				# ALIGN TO GROUND
				var onground = false
				var rayfrom = global_transform.origin
				var rayto = global_transform.origin+(global_transform.basis.y.normalized()*-9)
				var result = space_state.intersect_ray(rayfrom,rayto,[self],1)
				if result:
					var groundpos = result.position
					# NOTE: the below sometimes flips the z vector (makes it point in the opposite direction)
					var pby = global_transform.basis.y
					if pby.dot(planetnormal) == -1:
						#vectors are 180 degree difference
						pby += (global_transform.basis.x * .01)
						pby.normalized()
					var lidir = pby.linear_interpolate(result.normal,0.4).normalized()
					global_transform.basis = align_up(global_transform.basis,lidir)
					force_update_transform()
					orthonormalize()
					planetnormal = result.normal.normalized()
					if result.collider != planet:
						print("%s-Changed Planets RUNNING from %s to %s" % [tics,planet.name,result.collider.name])
						planet = result.collider
					# CLAMP TO GROUND
					if abs(global_transform.origin.distance_to(groundpos)) < 0.6:
						global_transform.origin = groundpos+(planetnormal*.5)
						force_update_transform()
						onground = true
				else:
					print('ERROR-NOPLANET')
				# CHECK IF MOVED OFF PLATFORM
				if nofloorcollide and not onground:
					var onplatform = false
					var pcrayto = global_transform.origin+(global_transform.basis.y.normalized()*-4)
					var pcast = space_state.intersect_ray(global_transform.origin,pcrayto,[self])
					if pcast:
						if abs(global_transform.origin.distance_to(pcast.position)) < 0.6:
							onplatform = true
					if not onplatform:
						print('NOGROUNDCOLLIDE')
						jumping = gametime
						jumpvec = planetnormal 
						jumpvec = jumpvec.normalized()
						jumpbasis = Basis(global_transform.basis.x,global_transform.basis.y,global_transform.basis.z)
						runpart.emitting = false
						if $walksound.playing:
							$walksound.stop()
							#print('STOP-WALKSOUND8')
						wakepart.emitting = false
						jumpforce = 0
			else: #STANDING STILL
				#var gravityvec = planetnormal * -1 * 3.0 * delta
				#var _kcol = move_and_collide(gravityvec)
				#aligntoground()
				if crashing:
					if aplayer.current_animation == 'Crash':
						if aplayer.current_animation_position > 0.6:
							if not $flappingsound.playing:
								$flappingsound.play()
						if aplayer.current_animation_position > 1.0:
							aplayer.play('Landing')
					elif aplayer.current_animation != 'Landing':
						crashing = false
						slidecol.disabled = true
						runcol.disabled = false
					return
				if sliding:
					sliding = false
					slidecol.disabled = true
					runcol.disabled = false
					if $slidesound.playing:
						$slidesound.stop()
				if crouchpress:
					if slidepress:
						sliding = true
						slidecol.disabled = false
						runcol.disabled = true
						aplayer.play('BellySlide')
						aplayer.seek(0.2,true)
						forward = 3.0
						return
					else:
						aplayer.play('Crouch')
						aplayer.seek(0.3,true)
				else:
					aplayer.play('Stand')
					if $walksound.playing:
						$walksound.stop()
						#print('STOP-WALKSOUND9')
				runpart.emitting = false
				if $walksound.playing:
					$walksound.stop()
					#print('STOP-WALKSOUND10')
				wakepart.emitting = false
				if $watersound.playing:
					$watersound.stop()


func _on_waterarea_body_entered(body):
	#print('ENTERWATER: %s' % body.name)
	if body.name == 'tux':
		inwater = true
		runpart.emitting = false
		if $walksound.playing:
			$walksound.stop()
	
func _on_waterarea_body_exited(body):
	#print('LEAVEWATER: %s' % body.name)
	if body.name == 'tux':
		inwater = false
		#splashpart.emitting = false
		wakepart.emitting = false
		if $watersound.playing:
			$watersound.stop()
		if jumping == 0:
			runpart.emitting = true
			if not $walksound.playing:
				$walksound.play()
				
func _on_marblearea_body_entered(body,area):
	if body.name == 'tux':
		$collectsound.play()
		marblecount += 1
		mclabel.text = str(marblecount)
		area.queue_free()
