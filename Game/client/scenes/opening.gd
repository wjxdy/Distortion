# 开场序章：冷开钩子 + 世界观幻灯片 + 老人旧闻，播完切到审讯室。
# 占位视觉（纯色背景），真正像素图 P4 再换。点击 / 空格 翻页。
extends Control

const INTERROGATION := "res://scenes/interrogation.tscn"

# 每个 beat：text 正文；who 说话人标签（可空）；tint 背景色。
var beats := [
	{"who": "", "text": "今天……几号了？", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "我老伴……怎么还没回来？", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "「她出去了，很快回来。」", "tint": Color(0.02, 0.02, 0.03)},
	{"who": "", "text": "这是一个，凡事都问 AI 的时代。", "tint": Color(0.05, 0.06, 0.09)},
	{"who": "", "text": "人们不再自己思考。AI 说什么，便信什么。", "tint": Color(0.05, 0.06, 0.09)},
	{"who": "旧闻", "text": "天才科学家 周明远，创造首个 AI 大模型，人类就此迈入新纪元。", "tint": Color(0.10, 0.09, 0.06)},
	{"who": "", "text": "可这世上，总得有人还在怀疑。\n——而我，就是干这行的。", "tint": Color(0.05, 0.06, 0.09)},
]

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
	idx += 1
	if idx >= beats.size():
		get_tree().change_scene_to_file(INTERROGATION)
		return
	var b = beats[idx]
	bg.color = b.get("tint", Color(0.05, 0.06, 0.09))
	var who = str(b.get("who", ""))
	text_label.text = (("【%s】\n\n" % who) if who != "" else "") + str(b["text"])

func _input(event: InputEvent) -> void:
	var go := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		_advance()
