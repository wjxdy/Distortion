# 警局电脑终端：左侧案卷列表(静态按钮，在 terminal.tscn 里可拖) + 右侧详情显示。
# 点案卷 → 显示内容；带 grants_key 的案卷查完会经全局 Game 发线索钥匙(跨场景保留)，
# 回审讯室追问即可触发真相。现阶段不做门控、不做 AI 问询(后续再加)。
extends Control

const POLICE := "res://scenes/police.tscn"
const Content = preload("res://game/content.gd")

# 查到某案卷 → 莫忘弹一条提醒引导回去问老头(确定性双向提示)
const FILE_HINTS := {
	"wife": "ask_wife_death",
	"medical": "ask_no_accident",
	"address": "got_address",
}

@onready var display: Label = $DisplayBg/Display
@onready var back_btn: Button = $BackBtn
@onready var phone: CanvasLayer = $Phone
@onready var submit_phone_btn: Button = $FileList/SubmitPhoneBtn
@onready var log_view: Control = $LogView
@onready var log_label: Label = $LogView/Panel/Line
@onready var next_btn: Button = $LogView/Panel/NextBtn
@onready var log_close: Button = $LogView/Panel/CloseBtn

var log_idx := 0

func _ready() -> void:
	back_btn.pressed.connect(_back)
	# 各案卷按钮 -> 对应 TERMINAL_FILES 条目
	($FileList/CaseBtn as Button).pressed.connect(_show.bind("case"))
	($FileList/ZhouBtn as Button).pressed.connect(_show.bind("zhou"))
	($FileList/AddressBtn as Button).pressed.connect(_show.bind("address"))
	($FileList/WifeBtn as Button).pressed.connect(_show.bind("wife"))
	($FileList/MedicalBtn as Button).pressed.connect(_show.bind("medical"))
	# 接入老人手机解锁日志
	log_view.visible = false
	submit_phone_btn.pressed.connect(_submit_phone)
	next_btn.pressed.connect(_log_next)
	log_close.pressed.connect(_close_log)
	# 没拿到老人手机就别显示"接入手机"(也防止已解锁后重复解锁)
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

# 接入老人的手机 → 打开莫忘日志逐条翻(取证解锁)
func _submit_phone() -> void:
	if not Game.state.has_item("oldman_phone"):
		return
	Sfx.play_click()
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
	submit_phone_btn.visible = false
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
