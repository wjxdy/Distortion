extends SceneTree
func _initialize() -> void:
	var ps := load("res://scenes/interrogation.tscn")
	var root = ps.instantiate()
	var ok := true
	for p in ["Evidence", "Evidence/VBox/Card_photo", "Evidence/VBox/Card_death", "Evidence/VBox/Card_farewell", "Evidence/VBox/Card_molog", "DirectorHttp", "EndSlide/VBox/TitleLabel", "EndSlide/VBox/EndButtons/BackToMenuBtn", "EndSlide/VBox/EndButtons/ViewAchieveBtn", "TitleHttp", "PhoneHttp"]:
		if root.get_node_or_null(p) == null:
			push_error("缺节点 " + p); ok = false
	if root.get_node_or_null("LeaveBtn") != null:
		push_error("LeaveBtn 应已删除"); ok = false
	print("interrogation 结构 " + ("OK" if ok else "FAIL"))
	root.free()
	quit(0 if ok else 1)
