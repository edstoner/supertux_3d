extends StaticBody

var speed = 3.3
var rotangle
var rotvec
var planet

func _ready():
	planet = get_parent().get_parent().get_parent().get_node("smallplanet") # HACK!
	#print('BOULDER PARENT:%s' % planet)
	set_physics_process(true)
	set_notify_transform(true)
	set_as_toplevel(true)
	#print(self.name)
	if self.name == 'boulder3-staticbody' or self.name =='boulder4-staticbody':
		rotvec = planet.global_transform.basis.z
	else:
		rotvec = planet.global_transform.basis.y


func _physics_process(delta):
	rotangle = delta*speed*0.3
	var vectocenter = global_transform.origin - planet.global_transform.origin
	var rotvectocenter = vectocenter.rotated(rotvec,rotangle)
	var rotvec = rotvectocenter-vectocenter
	global_translate(rotvec)
	global_rotate(global_transform.basis.y,rotangle*2)
	#force_update_transform()
