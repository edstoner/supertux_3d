extends MeshInstance


var scalenum = 1
var scalev = 0.0001


# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	scalenum += scalev
	set_scale(Vector3(scalenum,scalenum,scalenum))
	if scalenum > 1.05:
		scalev = scalev * -1
	if scalenum < 1.0:
		scalev = scalev * -1
