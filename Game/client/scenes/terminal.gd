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

func _ready() -> void:
	back_btn.pressed.connect(_back)
	# 各案卷按钮 -> 对应 TERMINAL_FILES 条目
	($FileList/CaseBtn as Button).pressed.connect(_show.bind("case"))
	($FileList/ZhouBtn as Button).pressed.connect(_show.bind("zhou"))
	($FileList/AddressBtn as Button).pressed.connect(_show.bind("address"))
	($FileList/WifeBtn as Button).pressed.connect(_show.bind("wife"))
	($FileList/MedicalBtn as Button).pressed.connect(_show.bind("medical"))

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

func _back() -> void:
	Sfx.play_door()
	get_tree().change_scene_to_file(POLICE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
