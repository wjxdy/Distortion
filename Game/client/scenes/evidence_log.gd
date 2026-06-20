# 证据列表(autoload 全局 HUD = Evidence)。右上角"📁 证据"按钮(道具栏左侧)，点开看已获得证据，
# 点条目读 proof 详情。获得证据的地方调 Evidence.note(key) 弹 toast+红点(去重)。
# 静态结构在 evidence_log.tscn(可拖)。序幕/结局用 Evidence.visible=false 隐藏整条。
extends CanvasLayer

const Content = preload("res://game/content.gd")

@onready var toggle_btn: Button = $ToggleBtn
@onready var dot: ColorRect = $ToggleBtn/Dot
@onready var panel: ColorRect = $Panel
@onready var entries: Array = [
	$Panel/List/Entry0, $Panel/List/Entry1, $Panel/List/Entry2, $Panel/List/Entry3
]
@onready var empty: Label = $Panel/Empty
@onready var detail: Label = $Panel/Detail
@onready var toast: Label = $Toast

var _toast_tween: Tween

func _ready() -> void:
	toggle_btn.pressed.connect(_toggle)
	for i in entries.size():
		(entries[i] as Button).pressed.connect(_on_entry.bind(i))
	panel.visible = false
	detail.visible = false
	dot.visible = false
	toast.visible = false
	refresh()

# 获得证据时调用(发完 key 后)：非证据 key 忽略；去重；弹 toast + 点红点。
func note(key: String) -> void:
	var card := Content.evidence_card_for_key(key)
	if card.is_empty():
		return
	if not Game.state.mark_evidence_seen(str(card["id"])):
		return
	_show_toast("已将【%s】添加到证据列表" % str(card["label"]))
	dot.visible = true
	refresh()

# 重建列表:每张卡按 has_key 显隐;无证据显示 Empty。
func refresh() -> void:
	var any := false
	for i in entries.size():
		var c: Dictionary = Content.EVIDENCE_CARDS[i]
		var held: bool = Game.state.has_key(str(c["key"]))
		(entries[i] as Button).visible = held
		(entries[i] as Button).text = str(c["label"])
		any = any or held
	empty.visible = not any

func _toggle() -> void:
	Sfx.play_click()
	panel.visible = not panel.visible
	if panel.visible:
		dot.visible = false   # 看了就清红点
		detail.visible = false
		refresh()

func _on_entry(i: int) -> void:
	Sfx.play_click()
	detail.text = str(Content.EVIDENCE_CARDS[i]["proof"])
	detail.visible = true

# 右上角淡入(0.3)停留(2.4)淡出(0.6) toast，仿 phone.gd。
func _show_toast(msg: String) -> void:
	toast.text = msg
	toast.visible = true
	toast.modulate.a = 0.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)
