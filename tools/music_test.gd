extends SceneTree
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var A = root.get_node("Audio")
	while not A._themes.has("night"):
		await process_frame
	print("themes rendered in ms: ", Time.get_ticks_msec() - t0)
	var out := OS.get_environment("OUT")
	A._themes["day"].save_to_wav(out + "/day_theme.wav")
	A._themes["night"].save_to_wav(out + "/night_theme.wav")
	for s in ["till","water","plant","harvest","forage","discover","levelup","coin","click","open","close","error","sleep"]:
		A._make_sfx(s)
	A._rain()
	print("sfx ok")
	quit()
