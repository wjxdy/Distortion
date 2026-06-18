# 老人楼电梯界面 — 按键图片 + 入场动画 + 点击反馈
extends Control

const COMMUNITY := "res://scenes/community.tscn"
const CORRIDOR := "res://scenes/home_corridor.tscn"
const OLD_FLOOR := 7

@onready var info: Label = $Info
@onready var back_btn: Button = $BackBtn
@onready var panel: ColorRect = $Panel
@onready var title: Label = $Title
@onready var floor_display: Label = $FloorDisplay
@onready var floors_vbox: VBoxContainer = $Floors
@onready var pressed_overlay: TextureRect = $PressedOverlay

# { floor_num -> { btn, label, normal } }
var _keys: Dictionary = {}
var _entrance_done := false

# ---- 初始化 ----------------------------------------------------------

func _ready() -> void:
	Music.stop()
	Music.stop_rain()

	back_btn.pressed.connect(_back)

	for f in [3, 5, 7, 9]:
		var btn := get_node("Floors/F%d" % f) as Button
		var label := btn.get_node("KeyLabel") as Label
		var normal_color := label.self_modulate
		_keys[f] = {"btn": btn, "label": label, "normal": normal_color}

		btn.pressed.connect(_pick.bind(f))
		btn.mouse_entered.connect(_on_hover.bind(f))
		btn.mouse_exited.connect(_on_unhover.bind(f))
		btn.button_down.connect(_on_press.bind(f))
		btn.button_up.connect(_on_release.bind(f))

	# 初始全隐藏，由入场动画逐步亮起
	info.text = ""
	title.modulate.a = 0.0
	_panel_set_alpha(0.0)

	_play_entrance()

func _panel_set_alpha(a: float) -> void:
	panel.modulate.a = a
	floor_display.modulate.a = a
	for c in floors_vbox.get_children():
		c.modulate.a = a

# ---- 入场动画 --------------------------------------------------------

func _play_entrance() -> void:
	var tw := create_tween().set_parallel(false)

	# 面板淡入
	tw.tween_property(panel, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)

	# 楼层显示滚动: 1 → 3 → 5 → 7
	tw.tween_callback(func():
		floor_display.modulate.a = 1.0
		floor_display.text = "1"; Sfx.play_blip()
	)
	tw.tween_interval(0.12)
	tw.tween_callback(func(): floor_display.text = "3"; Sfx.play_blip())
	tw.tween_interval(0.12)
	tw.tween_callback(func(): floor_display.text = "5"; Sfx.play_blip())
	tw.tween_interval(0.12)
	tw.tween_callback(func(): floor_display.text = "7"; Sfx.play_blip())

	# 按钮从下往上逐个亮起
	tw.tween_interval(0.08)
	for i in range(floors_vbox.get_child_count()):
		var btn := floors_vbox.get_child(floors_vbox.get_child_count() - 1 - i) as Button
		tw.tween_callback(func(): Sfx.play_blip())
		tw.tween_property(btn, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.06)

	# 标题淡入
	tw.tween_property(title, "modulate:a", 1.0, 0.35)

	# 入场完成
	tw.tween_callback(func(): _entrance_done = true)

# ---- 按钮悬停 / 按下效果 ---------------------------------------------

func _on_hover(f: int) -> void:
	if not _keys.has(f): return
	floor_display.text = str(f)
	var d: Dictionary = _keys[f]
	d.label.self_modulate = Color(1.0, 0.85, 0.4, 1)    # 暖金高亮

func _on_unhover(f: int) -> void:
	if not _keys.has(f): return
	floor_display.text = "7"
	var d: Dictionary = _keys[f]
	d.label.self_modulate = d.normal                     # 恢复本色

func _on_press(f: int) -> void:
	if not _keys.has(f): return
	var d: Dictionary = _keys[f]
	d.label.self_modulate = Color(1.0, 0.5, 0.1, 1)     # 按下橙红

func _on_release(f: int) -> void:
	if not _keys.has(f): return
	var d: Dictionary = _keys[f]
	d.label.self_modulate = Color(1.0, 0.85, 0.4, 1)    # 回到高亮

# ---- 选楼层 ----------------------------------------------------------

func _pick(floor_num: int) -> void:
	if not _entrance_done:
		return
	_entrance_done = false                # 防连点
	Sfx.play_click()

	_show_pressed_overlay()

	if floor_num == OLD_FLOOR:
		await get_tree().create_timer(1.1).timeout
		Game.spawn_point = "from_elevator"
		Sfx.play_door()
		get_tree().change_scene_to_file(CORRIDOR)
	else:
		await get_tree().create_timer(0.55).timeout
		info.text = "%d 层……不是他家。（他住 7 层）" % floor_num
		_entrance_done = true

# ---- 点击反馈遮罩 ----------------------------------------------------

func _show_pressed_overlay() -> void:
	pressed_overlay.visible = true
	pressed_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(pressed_overlay, "modulate:a", 0.85, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(pressed_overlay, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): pressed_overlay.visible = false)

# ---- 返回 ------------------------------------------------------------

func _back() -> void:
	if not _entrance_done:
		return
	Game.spawn_point = "from_elevator"
	Sfx.play_door()
	get_tree().change_scene_to_file(COMMUNITY)
# ESC 现在专用于打开设置；返回小区用屏幕上的「返回」按钮。
