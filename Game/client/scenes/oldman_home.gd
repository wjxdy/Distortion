# 老人房间（色块占位，可走）。两件关键证物：墙上合照、床头手机。
# 查合照 → 显示文案 + 发 photo 钥匙；查手机 → 打开「莫忘日志滑坡」逐条翻，翻完发 molog 钥匙
# + 莫忘提醒"回审讯做对峙"(第二层真相入口)。
extends Control

const CORRIDOR := "res://scenes/home_corridor.tscn"
const Content = preload("res://game/content.gd")

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var info: Label = $Info
@onready var phone: CanvasLayer = $Phone
@onready var photo_area: Area2D = $PhotoArea
@onready var phone_area: Area2D = $PhoneArea
@onready var exit_area: Area2D = $ExitArea
@onready var log_view: Control = $LogView
@onready var log_label: Label = $LogView/Panel/Line
@onready var next_btn: Button = $LogView/Panel/NextBtn
@onready var log_close: Button = $LogView/Panel/CloseBtn

var log_idx := 0

func _ready() -> void:
	prompt.visible = false
	info.visible = false
	log_view.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	next_btn.pressed.connect(_log_next)
	log_close.pressed.connect(_close_log)

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(photo_area):
		prompt.text = "↑ 查看  合照"
		prompt.visible = true
	elif _at(phone_area):
		prompt.text = "↑ 查看  老人的手机"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 离开"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if not event.is_action_pressed("move_up"):
		return
	if _at(photo_area):
		_examine("photo")
	elif _at(phone_area):
		_open_log()
	elif _at(exit_area):
		Sfx.play_door()
		get_tree().change_scene_to_file(CORRIDOR)

func _examine(id: String) -> void:
	Sfx.play_click()
	var e = Content.HOME_EVIDENCE[id]
	info.text = str(e["text"])
	info.visible = true
	var k := str(e.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)

# 查老人手机 → 拿到手机 + 打开莫忘日志滑坡
func _open_log() -> void:
	Sfx.play_click()
	Game.state.add_key("phone")
	log_idx = 0
	log_label.text = str(Content.MOWANG_LOG_LINES[0])
	next_btn.text = "下一条 ▼"
	next_btn.disabled = false
	log_view.visible = true
	player.locked = true

func _log_next() -> void:
	Sfx.play_click()
	if log_idx < Content.MOWANG_LOG_LINES.size() - 1:
		log_idx += 1
		log_label.text = str(Content.MOWANG_LOG_LINES[log_idx])
		if log_idx >= Content.MOWANG_LOG_LINES.size() - 1:
			next_btn.text = "（已看完）"
			next_btn.disabled = true
			_finish_log()

func _finish_log() -> void:
	Game.state.add_key("molog")   # 第二层真相钥匙
	if Game.state.fire_hint("confront_molog", str(Content.MOWANG_HINTS["confront_molog"])):
		phone.notify_hint()

func _close_log() -> void:
	Sfx.play_click()
	log_view.visible = false
	player.locked = false
