extends Control

var globals
var loadtime = 0
var loader
var count = 0

# FOR THREAD LOADING
var thread = null
var res

func _ready():
	globals = get_node("/root/Globals")
	thread = Thread.new()
	thread.start(self, "_thread_load", globals.nextscene)

func _thread_load(path):
	#print(str('LOADING SCENE: ' + path))
	var ril = ResourceLoader.load_interactive(path)
	var total = ril.get_stage_count()
	# Call deferred to configure max load steps
#	progress.call_deferred("set_max", total)
#
	res = null
	
	while true: #iterate until we have a resource
		# Update progress bar, use call deferred, which routes to main thread
#		progress.call_deferred("set_value", ril.get_stage())
		# Simulate a delay
		OS.delay_msec(50.0)
		# Poll (does a load step)
		var err = ril.poll()
		#print('%s-POLL' % count)
		if err == ERR_FILE_EOF:
			# Loading done, fetch resource
			res = ril.get_resource()
			#print("Loading Done")
			call_deferred("thread_done", res)
			break
		elif err != OK:
			# Not OK, there was an error
			print("There was an error loading")
			break

func thread_done(resource):
	# Always wait for threads to finish, this is required on Windows
	thread.wait_to_finish()
	#print("Thread Finished")

	get_tree().change_scene_to(resource)
	# THE BELOW DOESN'T WORK
	#var nextscene = resource.instance()
	#var root = get_tree().get_root()
	#var curscene = root.get_child(root.get_child_count() - 1)
	#root.remove_child(curscene)
	#curscene.call_deferred("free")
	#root.add_child(nextscene)

func _old_ready():
	globals = get_node("/root/Globals")
	loader = ResourceLoader.load_interactive(globals.nextscene)
	if loader == null: # check for errors
		print('ERROR OF SOME KIND!')
		return
	set_process(true)

func update_progress(count):
	print("%s - Progress Loading" % count)

func _old_process(delta):
	#loadtime += delta
	#if loadtime > 3.0:
	#	get_tree().change_scene(globals.nextscene)
	count += 1

	var t = OS.get_ticks_msec()
	var time_max = 3
	while OS.get_ticks_msec() < t + time_max: # use "time_max" to control for how long we block this thread
		# poll your loader
		var err = loader.poll()
		if err == ERR_FILE_EOF: # Finished loading.
			print('FINISHED LOADING')
			var resource = loader.get_resource()
			loader = null
			get_tree().change_scene_to(resource)
			break
		elif err == OK:
			update_progress(count)
		else: # error during loading
			print('ERROR DURING LOADING')
			loader = null
			break

func _process(delta):
	count += 1


