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
			_check(root.has_node("TerminalUI/Chat"), "终端有聊天记录区 Chat")
			_check(root.has_node("TerminalUI/QueryInput"), "终端有查询输入框 QueryInput")
			_check(root.has_node("TerminalUI/QueryBtn"), "终端有查询按钮 QueryBtn")
			_check(root.has_node("TerminalUI/BackBtn"), "终端保留关闭按钮")
			_check(root.has_node("TerminalUI/FileList/SubmitPhoneBtn"), "终端保留接入手机按钮")
			_check(root.has_node("TerminalUI/LogView"), "终端保留莫忘日志面板")
			_check(not root.has_node("TerminalUI/FileList/CaseBtn"), "旧案卷按钮已移除")

		# --- 防"幽灵按键"(终端版)：关闭终端必须清掉打字时残留的方向键 ---
		# 复现：查询界面打开时 player.locked=true、焦点在输入框，按 ↑↓←→ 移光标→
		# move_* 被 Input 记成"按住"、释放被输入框吞掉；关终端不重载场景→
		# clear_movement_input(只在 _ready 跑)不触发→残留留着→解锁后玩家自动走。
		# 修复=_close_terminal 调 player.clear_movement_input() 清残留。
		get_root().add_child(root)
		await process_frame
		root._open_terminal()
		Input.action_press("move_right")
		_check(Input.is_action_pressed("move_right"), "终端打字残留方向键已注入(复现前置)")
		root._close_terminal()
		_check(not Input.is_action_pressed("move_right"), "关闭终端→清除残留方向键(防关掉后玩家自动走)")
		Input.action_release("move_right")   # 清理，避免污染后续
		root.queue_free()
		await process_frame
	print("\n终端室测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
