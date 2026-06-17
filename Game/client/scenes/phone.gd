# 可复用手机 UI（色块占位，节点都在 phone.tscn 里，可在编辑器拖/DIY）。
# 在 world / interrogation 等场景里实例化即可：点 📱 打开，看上司任务 / 莫忘 AI 助手提醒。
# 分工：手机=上司任务 + 莫忘提醒；案件调查在「警局电脑终端」场景(terminal)。
# 莫忘提醒由模型在对话中触发(后端 hint)，经 Game 去重；有新提醒时 📱 与莫忘 app 亮红点。
# 脚本只管显隐 + 填字 + 红点刷新。
extends CanvasLayer

const Content = preload("res://game/content.gd")

signal opened
signal closed

@onready var btn: Button = $PhoneBtn
@onready var phone_dot: ColorRect = $PhoneBtn/Dot
@onready var screen: Control = $Screen
@onready var task_btn: Button = $Screen/Body/AppList/TaskBtn
@onready var mowang_btn: Button = $Screen/Body/AppList/MowangBtn
@onready var mowang_dot: ColorRect = $Screen/Body/AppList/MowangBtn/Dot
@onready var close_btn: Button = $Screen/Body/AppList/CloseBtn
@onready var display: Label = $Screen/Body/DisplayBg/Display

func _ready() -> void:
	screen.visible = false
	btn.pressed.connect(open)
	close_btn.pressed.connect(close)
	task_btn.pressed.connect(_show_task)
	mowang_btn.pressed.connect(_show_mowang)
	refresh_badge()

# 外部(场景)在触发新提醒后调用，刷新红点。
func refresh_badge() -> void:
	var unread: bool = Game.state.mowang_unread
	phone_dot.visible = unread
	mowang_dot.visible = unread

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

func _show_mowang() -> void:
	# 莫忘 app：展示已触发的提醒；看过即转已读、红点清。
	var log: Array = Game.state.mowang_log
	display.text = "\n\n".join(log) if not log.is_empty() else "（暂无提醒。莫忘会在关键时刻提示你。）"
	Game.state.read_mowang()
	refresh_badge()
