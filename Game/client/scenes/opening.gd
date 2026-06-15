# 开场序章（B 版）：世界观幻灯片 → 渐亮入场 → 手机任务 → 进警局审讯。
# 占位视觉（纯色背景 + 文本），真正像素图 P4 再换。幻灯片：点击/空格翻页。
extends Control

const INTERROGATION := "res://scenes/interrogation.tscn"

# 世界观幻灯片。who 说话人标签（可空）；tint 背景色。最后一条是"渐亮入场"。
var beats := [
	{"who": "", "text": "今天……几号了？", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "我老伴……怎么还没回来？", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "「她出去了，很快回来。」", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "这是一个，凡事都问 AI 的时代。", "tint": Color(0.05, 0.06, 0.09)},
	{"who": "", "text": "人们不再自己思考。AI 说什么，便信什么。", "tint": Color(0.05, 0.06, 0.09)},
	{"who": "旧闻", "text": "天才科学家 周明远，创造首个 AI 大模型，人类就此迈入新纪元。", "tint": Color(0.10, 0.09, 0.06)},
	{"who": "", "text": "灯光渐亮。\n一个身影，走入街角的霓虹里。", "tint": Color(0.12, 0.13, 0.18)},
]

var phase := "slides"  # slides -> phone
var idx := -1
var bg: ColorRect
var text_label: Label
var hint: Label

func _ready() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(720, 0)
	text_label.add_theme_font_size_override("font_size", 28)
	center.add_child(text_label)

	hint = Label.new()
	hint.text = "▼ 点击 / 空格 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.35)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44
	hint.offset_bottom = -20
	add_child(hint)

	_advance()

func _advance() -> void:
	if phase != "slides":
		return
	idx += 1
	if idx >= beats.size():
		_show_phone()
		return
	var b = beats[idx]
	bg.color = b.get("tint", Color(0.05, 0.06, 0.09))
	var who = str(b.get("who", ""))
	text_label.text = (("【%s】\n\n" % who) if who != "" else "") + str(b["text"])

func _show_phone() -> void:
	phase = "phone"
	text_label.hide()
	hint.hide()
	bg.color = Color(0.04, 0.05, 0.08)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)

	var title := Label.new()
	title.text = "📱 加密终端 · 1 条新任务"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)

	var profile := _wrap_label("〔档案〕代号「你」。职业：赏金侦探，专查 AI Agent 越狱 / 劫持案件。")
	profile.modulate = Color(0.7, 0.85, 1.0)
	v.add_child(profile)

	var task := _wrap_label("〔上司·加密〕周明远——本市，独居，行为异常已触发数据预警。怀疑其自建的 AI 被人动过手脚。\n地点：第七区警察局。去，把他问清楚。")
	v.add_child(task)

	var btn := Button.new()
	btn.text = "前往警察局 →"
	btn.pressed.connect(_go_interrogation)
	v.add_child(btn)

func _wrap_label(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	return l

func _go_interrogation() -> void:
	get_tree().change_scene_to_file(INTERROGATION)

func _input(event: InputEvent) -> void:
	if phase != "slides":
		return
	var go := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		_advance()
