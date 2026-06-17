# 可复用手机 UI（色块占位，节点都在 phone.tscn 里，可在编辑器拖/DIY）。
# 在 world / interrogation 等场景里实例化即可：点 📱 打开，左侧 app(任务/档案/关闭)，右侧显示区。
# 脚本只管显隐 + 按 app 填字 + 通过全局 Game 发线索钥匙(跨场景保留)。
extends CanvasLayer

const Content = preload("res://game/content.gd")

signal opened
signal closed

@onready var btn: Button = $PhoneBtn
@onready var screen: Control = $Screen
@onready var task_btn: Button = $Screen/Body/AppList/TaskBtn
@onready var archive_btn: Button = $Screen/Body/AppList/ArchiveBtn
@onready var close_btn: Button = $Screen/Body/AppList/CloseBtn
@onready var display: Label = $Screen/Body/DisplayBg/Display

func _ready() -> void:
	screen.visible = false
	btn.pressed.connect(open)
	close_btn.pressed.connect(close)
	task_btn.pressed.connect(_show_task)
	archive_btn.pressed.connect(_show_archive)

func open() -> void:
	Sfx.play_click()
	_show_task()          # 打开默认显示任务
	screen.visible = true
	opened.emit()

func close() -> void:
	Sfx.play_click()
	screen.visible = false
	closed.emit()

func _show_task() -> void:
	display.text = Content.BOSS_TASK

func _show_archive() -> void:
	# 查档案：显示档案文案 + 发线索钥匙(经全局 Game 跨场景保留)
	for a in Content.EXPLORE_ACTIONS:
		if a["id"] == "archive":
			Game.state.add_key(a["grants_key"])
			display.text = str(a["text"])
			return
