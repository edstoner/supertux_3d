extends KinematicBody


var speed = 3.3

func _ready():
	set_physics_process(true)
	set_notify_local_transform(true)
	set_notify_transform(true)


func _physics_process(delta):
	#move_and_collide(global_transform.basis.z*speed*delta)
	if Input.is_action_pressed("cometstop"):
		pass
	else:
		global_transform.origin += global_transform.basis.z*speed*delta
		global_rotate(global_transform.basis.y,delta*speed*0.15)
		force_update_transform()

