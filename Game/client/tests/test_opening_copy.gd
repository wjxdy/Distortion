extends SceneTree

const Content = preload("res://game/content.gd")

const EXPECTED_SLIDES := [
	"人会忘。\n\n所以这座城市发明了\n不会忘的东西。",
	"AI 替人保存生日、病历、遗言、爱情。\n\n也替人保存悔恨。",
	"后来，人们不再问：\n\n“我记得对不对？”\n\n他们只问：\n\n“系统怎么说？”",
	"你曾经也相信系统。\n\n直到有一天，\n系统开始替人撒谎。",
	"现在，你只是个落魄警探。\n\n靠接一些没人愿意碰的案子，\n维持生活。",
	"不追逃犯。\n不找失物。\n不替人抓奸。\n\n你只查一种事：\n\n有人记住了\n不该存在的东西。",
	"任务会被推送到你的手机。\n\n地点。\n对象。\n报酬。\n\n还有一句话：\n\n去问清楚。"
]

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
	var opening_script := FileAccess.get_file_as_string("res://scenes/opening.gd")
	var world_script := FileAccess.get_file_as_string("res://scenes/world.gd")
	_check(not ("Sfx.play_click()" in opening_script), "开场切幻灯片不播放点击音")
	_check(not ("Sfx.play_notify()" in world_script), "主世界开场任务提示不播放通知音")

	var scene := load("res://scenes/opening.tscn")
	_check(scene != null, "opening.tscn 可加载")
	if scene:
		var root = scene.instantiate()
		_check(root.has_node("FadeOverlay"), "开场有淡黑转场层")
		var slides: Array = root.get_node("Slides").get_children()
		_check(slides.size() == EXPECTED_SLIDES.size(), "开场为 7 张幻灯片")
		for i in min(slides.size(), EXPECTED_SLIDES.size()):
			var slide: Node = slides[i]
			_check(slide.get_node("Bg") is ColorRect, "Slide%d 使用色块背景" % i)
			_check((slide.get_node("Text") as Label).text == EXPECTED_SLIDES[i], "Slide%d 文案正确" % i)
		root.free()

	var world_scene := load("res://scenes/world.tscn")
	_check(world_scene != null, "world.tscn 可加载")
	if world_scene:
		var world = world_scene.instantiate()
		_check(world.has_node("IntroFadeLayer/IntroFade"), "主世界有入场黑屏层")
		world.free()

	_check("【周队 · 新任务】" in Content.BOSS_TASK, "手机任务标题为周队新任务")
	_check("周明远" in Content.BOSS_TASK and "仁济医院" in Content.BOSS_TASK, "手机任务包含周明远案件")
	_check("为什么会记住一件没发生过的事" in Content.BOSS_TASK, "手机任务抛出核心谜题")

	print("\n开场文案测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
