# 开场序幕（序·谜）逻辑：4 张背景 + 压暗 + 缓慢推镜(Ken Burns) + 居中打字机文字
# → 手机来电(派活) → 进审讯室。界面节点在 opening.tscn 里，可在编辑器直接调。
# 动态部分（背景切换、逐字打字、Ken Burns）留在这里。
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
var type_tween: Tween
var kb_tween: Tween

@onready var bg: TextureRect = $Clip/Bg
@onready var shade: ColorRect = $Shade
@onready var text_label: Label = $TextCenter/TextLabel
@onready var hint: Label = $Hint
@onready var phone: CenterContainer = $Phone
@onready var go_btn: Button = $Phone/Frame/Screen/VBox/GoBtn

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）：例如 Sfx.play_bgm("res://audio/opening_theme.ogg")
	go_btn.pressed.connect(_go_interrogation)
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
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(_finish_typing)

func _finish_typing() -> void:
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	text_label.visible_ratio = 1.0
	typing = false
	create_tween().tween_property(hint, "modulate:a", 0.3, 0.4)

func _show_phone() -> void:
	phase = "phone"
	text_label.hide()
	hint.hide()
	if kb_tween and kb_tween.is_valid():
		kb_tween.kill()
	bg.scale = Vector2(1.06, 1.06)
	shade.color = Color(0, 0, 0, 0.62)
	phone.visible = true

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
