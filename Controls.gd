extends Control

func _ready():
	$Button_Back.connect("pressed", self, "button_back_pressed")
	$Button_Back.grab_focus()

func button_back_pressed():
	get_tree().change_scene("res://Main_Menu.tscn")
