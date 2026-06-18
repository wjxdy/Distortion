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
	_check(ProjectSettings.has_setting("autoload/Music"), "Music autoload 已注册")

	var script := load("res://autoload/music.gd")
	_check(script != null, "music.gd 存在")
	if script:
		var music = script.new()
		_check(music.has_method("play_world"), "Music 有 play_world()")
		_check(music.has_method("fade_to"), "Music 有 fade_to()")
		_check(music.has_method("start_rain"), "Music 有 start_rain()")
		_check(music.has_method("stop_rain"), "Music 有 stop_rain()")
		_check(ResourceLoader.exists(music.MAIN_WORLD), "主世界 BGM 资源存在")
		_check(ResourceLoader.exists("res://audio/ambience/rain_world.ogg"), "雨声资源存在")
		music.free()

	print("\n音乐测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
