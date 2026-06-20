extends SceneTree

var _pass := 0
var _fail := 0

func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ok  ", name)
	else:
		_fail += 1
		printerr("  FAIL ", name)

func _initialize() -> void:
	var scene := load("res://scenes/evidence_log.tscn") as PackedScene
	_check(scene != null, "evidence_log.tscn 可加载")
	if scene:
		var root := scene.instantiate()
		_check(root.has_node("ToggleBtn"), "有证据按钮 ToggleBtn")
		_check(root.has_node("ToggleBtn/Dot"), "证据按钮有红点 Dot")
		_check(root.has_node("Panel"), "有列表面板 Panel")
		_check(not root.get_node("Panel").visible, "Panel 默认隐藏")
		_check(root.has_node("Panel/List/Entry0"), "有证据条目 Entry0")
		_check(root.has_node("Panel/List/Entry1"), "有证据条目 Entry1")
		_check(root.has_node("Panel/List/Entry2"), "有证据条目 Entry2")
		_check(root.has_node("Panel/List/Entry3"), "有证据条目 Entry3")
		_check(root.has_node("Panel/Empty"), "有空状态标签 Empty")
		_check(root.has_node("Panel/Detail"), "有详情标签 Detail")
		_check(root.has_node("Toast"), "有 toast 标签")
		root.free()
	print("\n证据HUD测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
