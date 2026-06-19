extends SceneTree
func _initialize() -> void:
	var root = load("res://scenes/achievements.tscn").instantiate()
	var ok := true
	for p in ["CountLabel", "Scroll/List", "BackBtn"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	print("achievements 结构 " + ("OK" if ok else "FAIL"))
	root.free(); quit(0 if ok else 1)
