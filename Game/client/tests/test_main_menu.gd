extends SceneTree
func _initialize() -> void:
	var root = load("res://scenes/main_menu.tscn").instantiate()
	var ok := true
	for p in ["Buttons/StartBtn", "Buttons/AchieveBtn", "Buttons/QuitBtn"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	print("main_menu 结构 " + ("OK" if ok else "FAIL"))
	root.free(); quit(0 if ok else 1)
