extends SceneTree

const Content = preload("res://game/content.gd")

const EXPECTED_SLIDES := [
	"这年头，\n人连自己有没有忘事，\n都要先问一遍系统。\n\n挺方便的。\n\n也挺可笑的。",
	"生日、病历、遗言、聊天记录。\n\n连一句“我爱你”\n都能被备份、归档、标注时间。\n\n好像只要存得够久，\n人就真的不会失去什么。",
	"警局也一样。\n\n报案人说自己记得。\n档案说不是那样。\n终端弹出一行结论。\n\n于是所有人都松了口气：\n\n“系统有记录。”",
	"我是一名警探。\n\n听起来像是追查真相的人。\n\n实际大多数时候，\n我只是在给那些破事\n找一个能盖章的说法。",
	"走失、纠纷、报案、笔录。\n\n有人丢了东西。\n有人丢了人。\n也有人只是丢了\n自己还正常的证据。",
	"我以前还会认真听。\n\n后来发现，\n人来警局不一定是为了真相。\n\n更多时候，\n只是想听别人说一句：\n\n“你没记错。”",
	"周队今天大概又会派活过来。\n\n希望别又是那种\n说不清、查不完，\n还没人会感谢的破事。\n\n……不过，\n哪次不是呢？"
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
	_check("周明远" in Content.BOSS_TASK, "手机任务点名周明远")
	_check(("走丢" in Content.BOSS_TASK) or ("报案" in Content.BOSS_TASK) or ("找" in Content.BOSS_TASK), "手机任务=报案找妻子的钩子(不剧透死亡)")
	_check(not ("去世" in Content.BOSS_TASK) and not ("死亡" in Content.BOSS_TASK), "手机任务不剧透她已病逝")

	print("\n开场文案测试: %d 通过, %d 失败" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
