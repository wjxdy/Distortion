# 可复用手机 UI（色块占位，节点都在 phone.tscn 里，可在编辑器拖/DIY）。
# 在 world / interrogation 等场景里实例化即可：点 📱 打开，看上司任务。
# 分工：手机=上司任务；案件调查在「警局电脑终端」场景(terminal)，不在手机里。
# 脚本只管显隐 + 填任务文案。
extends CanvasLayer

const Content = preload("res://game/content.gd")

signal opened
signal closed

@onready var btn: Button = $PhoneBtn
@onready var screen: Control = $Screen
@onready var task_btn: Button = $Screen/Body/AppList/TaskBtn
@onready var close_btn: Button = $Screen/Body/AppList/CloseBtn
@onready var display: Label = $Screen/Body/DisplayBg/Display

func _ready() -> void:
	screen.visible = false
	btn.pressed.connect(open)
	close_btn.pressed.connect(close)
	task_btn.pressed.connect(_show_task)

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
