# 警局电脑终端室：玩家先进一个可走房间，走到综合终端机前按 ↑/W 打开查询界面。
# 查询界面沿用原来的案卷列表逻辑；关闭后回到房间，门口按 ↑/W 返回警局走廊。
extends Control

const POLICE := "res://scenes/police.tscn"
const Content = preload("res://game/content.gd")

# 查到某案卷 → 莫忘弹一条提醒引导回去问老头(确定性双向提示)
const FILE_HINTS := {
	"wife": "ask_wife_death",
	"medical": "ask_no_accident",
	"address": "got_address",
}

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var terminal_area: Area2D = $TerminalArea
@onready var exit_area: Area2D = $ExitArea
@onready var terminal_ui: Control = $TerminalUI
@onready var display: Label = $TerminalUI/DisplayBg/Display
@onready var back_btn: Button = $TerminalUI/BackBtn
@onready var phone: CanvasLayer = $Phone
@onready var submit_phone_btn: Button = $TerminalUI/FileList/SubmitPhoneBtn
@onready var log_view: Control = $TerminalUI/LogView
@onready var log_label: Label = $TerminalUI/LogView/Panel/Line
@onready var next_btn: Button = $TerminalUI/LogView/Panel/NextBtn
@onready var log_close: Button = $TerminalUI/LogView/Panel/CloseBtn

var log_idx := 0

func _ready() -> void:
	Music.play_police_ambience()
	prompt.visible = false
	terminal_ui.visible = false
	back_btn.pressed.connect(_close_terminal)
	# 各案卷按钮 -> 对应 TERMINAL_FILES 条目
	($TerminalUI/FileList/CaseBtn as Button).pressed.connect(_show.bind("case"))
	($TerminalUI/FileList/ZhouBtn as Button).pressed.connect(_show.bind("zhou"))
	($TerminalUI/FileList/AddressBtn as Button).pressed.connect(_show.bind("address"))
	($TerminalUI/FileList/WifeBtn as Button).pressed.connect(_show.bind("wife"))
	($TerminalUI/FileList/MedicalBtn as Button).pressed.connect(_show.bind("medical"))
	# 接入老人手机解锁日志
	log_view.visible = false
	submit_phone_btn.pressed.connect(_submit_phone)
	next_btn.pressed.connect(_log_next)
	log_close.pressed.connect(_close_log)
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = terminal_ui.visible)
	Game.place_player(self, player)
	# 没拿到老人手机就别显示"接入手机"(也防止已解锁后重复解锁)
	_refresh_terminal_actions()
	_update_prompt()

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(terminal_area):
		prompt.text = "↑ 使用  综合终端"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 返回  走廊"
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
	if _at(terminal_area):
		_open_terminal()
	elif _at(exit_area):
		_back()

func _open_terminal() -> void:
	Sfx.play_click()
	_refresh_terminal_actions()
	terminal_ui.visible = true
	player.locked = true
	prompt.visible = false

func _close_terminal() -> void:
	Sfx.play_click()
	log_view.visible = false
	terminal_ui.visible = false
	player.locked = false
	_update_prompt()

func _refresh_terminal_actions() -> void:
	submit_phone_btn.visible = Game.state.has_item("oldman_phone") and not Game.state.has_key("molog")

func _show(file_id: String) -> void:
	var f = Content.TERMINAL_FILES.get(file_id)
	if f == null:
		return
	Sfx.play_click()
	display.text = str(f["text"])
	var k := str(f.get("grants_key", ""))
	if k != "":
		Game.state.add_key(k)   # 发线索钥匙，跨场景保留
	# 双向提示：查到关键案卷 → 莫忘弹提醒引导回去问老头(去重，只一次)
	if FILE_HINTS.has(file_id):
		var hid: String = FILE_HINTS[file_id]
		if Content.MOWANG_HINTS.has(hid) and Game.state.fire_hint(hid, str(Content.MOWANG_HINTS[hid])):
			phone.notify_hint()

# 接入老人的手机 → 终端恢复全部历史日志 → 打开莫忘滑坡日志逐条翻(取证解锁)
func _submit_phone() -> void:
	if not Game.state.has_item("oldman_phone"):
		return
	Sfx.play_click()
	display.text = "接入成功。\n本地只剩今天的对话，正在从云端恢复……\n\n✅ 已恢复全部历史日志。"
	log_idx = 0
	log_label.text = str(Content.MOWANG_LOG_LINES[0])
	next_btn.text = "下一条 ▼"
	next_btn.disabled = false
	log_view.visible = true

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
	_refresh_terminal_actions()
	if Game.state.fire_hint("go_confront", str(Content.MOWANG_HINTS["go_confront"])):
		phone.notify_hint()

func _close_log() -> void:
	Sfx.play_click()
	log_view.visible = false

func _back() -> void:
	Game.spawn_point = "terminal"   # 回警局时落到终端室门口
	Sfx.play_door()
	get_tree().change_scene_to_file(POLICE)
# ESC 现在专用于打开设置；返回走廊用屏幕上的「← 返回走廊」按钮。
