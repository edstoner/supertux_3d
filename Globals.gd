extends Node


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var gametime = 0
var marblecount = 0
var marbles = {}
var nextscene

var POPUP = preload("res://Pause.tscn")
var canvas_layer = null
var popup = null
var SAVEFILE = "user://game.data"


# Called when the node enters the scene tree for the first time.
func _ready():
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

func load_new_scene(new_scene_path):
	nextscene = new_scene_path
	get_tree().change_scene("res://Loading.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if popup == null:
			var inmainloading = false
			var nodelist = get_tree().get_root().get_children()
			for n in nodelist:
				if n.name == 'Main_Menu':
					inmainloading = true
				if n.name == 'Loading':
					inmainloading = true
			if not inmainloading:
				popup = POPUP.instance()
				#popup.get_node("Button_quit").connect("pressed", self, "popup_quit")
				#popup.connect("popup_hide", self, "popup_closed")
				popup.get_node("Resume").connect("pressed", self, "popup_closed")
				popup.get_node("Quit").connect("pressed", self, "popup_quit")
				popup.get_node("Save").connect("pressed", self, "popup_save")
				
				canvas_layer.add_child(popup)
				#popup.popup_centered()
				popup.get_node("Resume").grab_focus()

				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
				get_tree().paused = true

func popup_closed():
	get_tree().paused = false
	if popup != null:
		popup.queue_free()
		popup = null
		
func popup_quit():
	get_tree().quit()
	
func popup_save():
	var f = File.new()
	f.open(SAVEFILE, File.WRITE)
	var gamedata = {"Marblecount":marblecount,"Gametime":gametime,"Marbles":marbles}
	f.store_var(gamedata)
	f.close()

func load_gamedata():
	var f = File.new()
	if f.file_exists(SAVEFILE):
		f.open(SAVEFILE, File.READ)
		var gamedata = f.get_var()
		f.close()
		marblecount = gamedata["Marblecount"]
		gametime = gamedata["Gametime"]
		marbles = gamedata["Marbles"]
