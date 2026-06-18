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
	var scene := load("res://scenes/terminal.tscn") as PackedScene
	_check(scene != null, "terminal.tscn 可加载")
	if scene:
		var root := scene.instantiate()
		_check(root.has_node("Player"), "终端室有可走玩家")
		_check(root.has_node("TerminalArea"), "终端室有终端机交互区")
		_check(root.has_node("ExitArea"), "终端室有返回走廊交互区")
		_check(root.has_node("Bg") and root.get_node("Bg") is Sprite2D, "终端室背景是独立 Sprite2D")
		_check(root.has_node("TerminalMachine") and root.get_node("TerminalMachine") is Sprite2D, "终端机是独立 Sprite2D")
		_check(root.has_node("TerminalUI"), "终端查询界面被包成 TerminalUI")
		if root.has_node("TerminalUI"):
			_check(not root.get_node("TerminalUI").visible, "TerminalUI 默认隐藏")
		root.free()
	print("\n终端室测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
