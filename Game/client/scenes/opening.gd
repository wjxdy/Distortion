# 开场序幕（序·谜）逻辑：幻灯片做成节点切换式。
# 每张幻灯片是 Slides 下的一个节点(Slide0..N)，自带 Bg(背景图) + Shade(暗底) + Text(文案)，
# 全部可在编辑器里改图/改字/调位置。脚本只负责：切到下一张、打字机、Ken Burns 推镜、最后弹手机。
extends Control

const WORLD := "res://scenes/world.tscn"

var slides: Array = []     # Slides 下的各张幻灯片节点
var idx := -1
var phase := "slides"      # slides -> phone
var typing := false
var type_tween: Tween
var kb_tween: Tween

@onready var slides_root: Control = $Slides
@onready var hint: Label = $Hint

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）
	Game.reset()   # 开新游戏：清空线索/真相/对话历史
	for c in slides_root.get_children():
		slides.append(c)
		c.visible = false
	_advance()

func _advance() -> void:
	if phase != "slides":
		return
	if typing:
		_finish_typing()
		return
	idx += 1
	if idx >= slides.size():
		_go_world()   # 序幕放完 → 直接进主世界（手机改到 world 里点）
		return
	_show_slide(idx)

func _show_slide(i: int) -> void:
	for j in slides.size():
		slides[j].visible = (j == i)
	var slide: Control = slides[i]
	var bg: Control = slide.get_node("Bg")
	var text: Label = slide.get_node("Text")
	# 整张淡入
	slide.modulate = Color(1, 1, 1, 0.15)
	create_tween().tween_property(slide, "modulate:a", 1.0, 0.6)
	# Ken Burns：缓慢放大（绕背景中心）
	if kb_tween and kb_tween.is_valid():
		kb_tween.kill()
	bg.scale = Vector2(1.06, 1.06)
	kb_tween = create_tween()
	kb_tween.tween_property(bg, "scale", Vector2(1.16, 1.16), 9.0)
	# 打字机
	_type(text)

func _type(label: Label) -> void:
	label.visible_ratio = 0.0
	typing = true
	hint.modulate.a = 0.0
	var dur: float = clampf(label.text.length() * 0.045, 0.5, 3.0)
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	type_tween = create_tween()
	type_tween.tween_property(label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(_finish_typing)

func _finish_typing() -> void:
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	if idx >= 0 and idx < slides.size():
		(slides[idx].get_node("Text") as Label).visible_ratio = 1.0
	typing = false
	create_tween().tween_property(hint, "modulate:a", 0.3, 0.4)

func _go_world() -> void:
	Sfx.play_door()
	get_tree().change_scene_to_file(WORLD)

func _input(event: InputEvent) -> void:
	if phase != "slides":
		return
	var go := event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		Sfx.play_click()
		_advance()
