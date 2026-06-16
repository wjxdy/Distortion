# 开场序幕（序·谜）：4 张像素背景 + 压暗 + 缓慢推镜(Ken Burns) + 居中打字机文字
# → 加密终端来电(派活) → 进审讯室。
# 交互：点击 / 空格推进；文字未打完时点击 = 立即打完，再点 = 下一段。
extends Control

const INTERROGATION := "res://scenes/interrogation.tscn"

# 序·谜。每条：text 文案；img 背景路径（连续同图则不重载，推镜延续）。
var beats := [
	{"text": "有人说，真实曾经是一件很重的东西。", "img": "res://art/intro_city.png"},
	{"text": "后来，人们学会了把它——交给别人保管。", "img": "res://art/intro_city.png"},
	{"text": "在这座城市，没有人再问「那是不是真的」。\n人们只问：「它，是怎么说的。」", "img": "res://art/intro_crowd.png"},
	{"text": "记忆可以修改，往事可以重写。\n一个人是谁，取决于系统，允许他记得什么。", "img": "res://art/intro_crowd.png"},
	{"text": "而所谓真相，不过是——\n还没有被替换掉的谎言。", "img": "res://art/intro_distort.png"},
	{"text": "而你，是这座城里，极少数，还在追问的人。", "img": "res://art/intro_street.png"},
	{"text": "代号「你」。赏金侦探。\n专查那些——被人动过手脚的「记忆」。", "img": "res://art/intro_street.png"},
]

var phase := "slides"  # slides -> phone
var idx := -1
var cur_img := ""
var typing := false

var clip: Control
var bg: TextureRect
var shade: ColorRect
var text_label: Label
var hint: Label
var type_tween: Tween
var kb_tween: Tween
var blip_timer: Timer

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）：例如 Sfx.play_bgm("res://audio/opening_theme.ogg")

	# 背景层：外层裁剪，使推镜放大时不溢出画面
	clip = Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	add_child(clip)

	bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.pivot_offset = Vector2(640, 360)
	clip.add_child(bg)

	# 压暗层（~42%），保证文字可读
	shade = ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.42)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(840, 0)
	text_label.add_theme_font_size_override("font_size", 30)
	text_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	text_label.add_theme_constant_override("line_spacing", 12)
	center.add_child(text_label)

	hint = Label.new()
	hint.text = "▼ 点击 / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.0)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46
	hint.offset_bottom = -22
	add_child(hint)

	# 打字机的 blip 节拍器（仅打字期间运行）
	blip_timer = Timer.new()
	blip_timer.wait_time = 0.11
	blip_timer.timeout.connect(func() -> void: Sfx.play_blip())
	add_child(blip_timer)

	_advance()

func _advance() -> void:
	if phase != "slides":
		return
	if typing:
		_finish_typing()
		return
	idx += 1
	if idx >= beats.size():
		_show_phone()
		return
	var b = beats[idx]
	var img := str(b.get("img", ""))
	if img != cur_img:
		cur_img = img
		_set_bg(img)
	_type(str(b["text"]))

func _set_bg(path: String) -> void:
	bg.texture = load(path)
	# 淡入
	bg.modulate = Color(1, 1, 1, 0.15)
	create_tween().tween_property(bg, "modulate:a", 1.0, 0.7)
	# Ken Burns：缓慢放大（绕中心）
	if kb_tween and kb_tween.is_valid():
		kb_tween.kill()
	bg.scale = Vector2(1.06, 1.06)
	kb_tween = create_tween()
	kb_tween.tween_property(bg, "scale", Vector2(1.16, 1.16), 9.0)

func _type(full: String) -> void:
	text_label.text = full
	text_label.visible_ratio = 0.0
	typing = true
	hint.modulate.a = 0.0
	var dur: float = clampf(full.length() * 0.045, 0.5, 3.0)
	blip_timer.start()
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(_finish_typing)

func _finish_typing() -> void:
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	text_label.visible_ratio = 1.0
	blip_timer.stop()
	typing = false
	create_tween().tween_property(hint, "modulate:a", 0.3, 0.4)

func _show_phone() -> void:
	phase = "phone"
	text_label.hide()
	hint.hide()
	blip_timer.stop()
	if kb_tween and kb_tween.is_valid():
		kb_tween.kill()
	bg.scale = Vector2(1.06, 1.06)
	shade.color = Color(0, 0, 0, 0.62)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 手机外框（屏幕区叠任务文字）
	var frame := TextureRect.new()
	frame.texture = load("res://art/phone_frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	frame.custom_minimum_size = Vector2(430, 620)
	center.add_child(frame)

	# 屏幕内容区（避开边框）
	var screen := MarginContainer.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("margin_left", 40)
	screen.add_theme_constant_override("margin_right", 40)
	screen.add_theme_constant_override("margin_top", 70)
	screen.add_theme_constant_override("margin_bottom", 64)
	frame.add_child(screen)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	screen.add_child(v)

	var title := Label.new()
	title.text = "📱 加密终端"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	v.add_child(title)

	var sub := Label.new()
	sub.text = "— 1 条新任务 —"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.5)
	v.add_child(sub)

	var profile := _screen_label("〔档案〕代号「你」· 赏金侦探。\n专查 AI 越狱 / 劫持案件。")
	profile.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	v.add_child(profile)

	v.add_child(_screen_label("〔上司 · 加密〕\n周明远。本市，独居。行为异常，已触发数据预警。\n怀疑他自建的 AI，被人动了手脚。\n地点：第七区警察局。\n去，把他问清楚。"))

	var btn := Button.new()
	btn.text = "前往警察局 →"
	btn.pressed.connect(_go_interrogation)
	v.add_child(btn)

func _screen_label(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_constant_override("line_spacing", 4)
	return l

func _go_interrogation() -> void:
	Sfx.play_click()
	get_tree().change_scene_to_file(INTERROGATION)

func _input(event: InputEvent) -> void:
	if phase != "slides":
		return
	var go := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		Sfx.play_click()
		_advance()
