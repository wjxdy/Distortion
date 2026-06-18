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
@onready var task_dot: ColorRect = $Screen/Body/AppList/TaskBtn/Dot
@onready var mowang_btn: Button = $Screen/Body/AppList/MowangBtn
@onready var mowang_dot: ColorRect = $Screen/Body/AppList/MowangBtn/Dot
@onready var close_btn: Button = $Screen/Body/AppList/CloseBtn
@onready var display: Label = $Screen/Body/DisplayBg/Scroll/Display
@onready var scroll: ScrollContainer = $Screen/Body/DisplayBg/Scroll
@onready var toast: Label = $Toast

var _toast_tween: Tween

func _ready() -> void:
	screen.visible = false
	btn.pressed.connect(open)
	close_btn.pressed.connect(close)
	task_btn.pressed.connect(_show_task)
	mowang_btn.pressed.connect(_show_mowang)
	refresh_badge()

# 新莫忘提醒来了：响一声 + 刷红点 + 右上角弹一条小字(只勾人去看手机，详情在莫忘 app)。
func notify_hint() -> void:
	Sfx.play_notify()
	refresh_badge()
	_show_toast("💬 莫忘：我想到点东西——看看手机")

# 右上角小字提示：淡入→停留→淡出。纯文字带描边，不用气泡框。
func _show_toast(msg: String) -> void:
	toast.text = msg
	toast.visible = true
	toast.modulate.a = 0.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)

# 外部(场景)在触发新提醒后调用，刷新红点。📱 红点 = 任务或莫忘任一未读。
func refresh_badge() -> void:
	var task_un: bool = Game.state.task_unread
	var mw_un: bool = Game.state.mowang_unread
	phone_dot.visible = task_un or mw_un
	task_dot.visible = task_un
	mowang_dot.visible = mw_un

func open() -> void:
	Sfx.play_click()
	_show_task()          # 打开默认显示任务
	screen.visible = true
	opened.emit()

func close() -> void:
	Sfx.play_click()
	screen.visible = false
	closed.emit()

# 切到某 app：填内容并把滚动条拉回顶部(超长内容由 Scroll 提供纵向滚动)。
func _set_display(t: String) -> void:
	display.text = t
	scroll.set_deferred("scroll_vertical", 0)   # 等内容重排后回到顶部

func _show_task() -> void:
	_set_display(Content.BOSS_TASK)
	Game.state.read_task()   # 看过任务 → 红点清
	refresh_badge()

func _show_mowang() -> void:
	# 莫忘 app：展示已触发的提醒；看过即转已读、红点清。
	var log: Array = Game.state.mowang_log
	_set_display("\n\n".join(log) if not log.is_empty() else "（暂无提醒。莫忘会在关键时刻提示你。）")
	Game.state.read_mowang()
	refresh_badge()
