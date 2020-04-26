extends Control

var globals

func _ready():
	$Start_Menu/Button_Controls.connect("pressed", self, "button_controls_pressed")
	$Start_Menu/Button_Start.connect("pressed", self, "button_start_pressed")
	$Start_Menu/Button_Load.connect("pressed", self, "button_load_pressed")
	$Start_Menu/Button_Start.grab_focus()
	globals = get_node("/root/Globals")
	
func button_start_pressed():
	globals.load_new_scene("res://gatelevel.tscn")
	#get_tree().change_scene("res://gravitylevel1.tscn")

func button_controls_pressed():
	get_tree().change_scene("res://Controls.tscn")

func button_load_pressed():
	globals.load_gamedata()
	globals.load_new_scene("res://gatelevel.tscn")

func _process(delta):
	pass
