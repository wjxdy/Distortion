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
	_check(ResourceLoader.exists("res://art/phone_logo.png"), "手机入口 logo PNG 资源存在")
	var scene := load("res://scenes/phone.tscn") as PackedScene
	_check(scene != null, "phone.tscn 可加载")
	if scene:
		var root := scene.instantiate()
		var btn := root.get_node_or_null("PhoneBtn") as Button
		_check(btn != null, "手机入口按钮存在")
		if btn:
			_check(btn.icon != null, "手机入口按钮使用 PNG icon")
			_check(btn.text == "", "手机入口按钮不再显示 emoji 文本")
		root.free()
	print("\n手机 logo 测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
