# 道具栏（autoload 全局 HUD = Inv）。右上角一个"道具"按钮，点开才展开格子面板(默认收起)；
# 再点按钮收起。点具体道具看说明。全局单例 → 天然在每个场景都在。
# 静态结构在 inventory.tscn 里(可拖)：右上角按钮=ToggleBtn，展开的面板=Panel(里面 Bar 三格 + Desc)。
# 拿到新道具的地方调 Inv.refresh() 刷新。序幕里用 Inv.visible=false 隐藏整条。
extends CanvasLayer

const Content = preload("res://game/content.gd")

@onready var toggle_btn: Button = $ToggleBtn
@onready var panel: ColorRect = $Panel
@onready var slots: Array = [
	$Panel/Bar/Slot0, $Panel/Bar/Slot1, $Panel/Bar/Slot2
]
@onready var desc: Label = $Panel/Desc
@onready var phone_view: ColorRect = $PhoneView          # 老人手机阅读面板(看今天的莫忘对话)
@onready var pv_text: Label = $PhoneView/PVPanel/PVScroll/PVText
@onready var pv_scroll: ScrollContainer = $PhoneView/PVPanel/PVScroll
@onready var pv_close: Button = $PhoneView/PVPanel/PVClose

var _desc_tween: Tween
const _TERMINAL_DX := 184.0   # 终端场景里整条 HUD 左移量，给「关闭终端」让出最右
var _home := {}               # 记住默认(靠右)位置，离开终端时还原

func _ready() -> void:
	toggle_btn.pressed.connect(_toggle)
	for i in slots.size():
		(slots[i] as Button).pressed.connect(_on_slot.bind(i))
	pv_close.pressed.connect(_close_phone_view)
	panel.visible = false   # 默认收起，只露右上角按钮
	phone_view.visible = false
	desc.visible = false
	_home = {"bl": toggle_btn.offset_left, "br": toggle_btn.offset_right, "pl": panel.offset_left, "pr": panel.offset_right}
	refresh()

# 进终端场景时整条 HUD 左移让位(on=true)，离开还原(on=false)；默认靠右位置在 .tscn(可拖)。
func set_terminal_compact(on: bool) -> void:
	if _home.is_empty():
		return
	var dx: float = -_TERMINAL_DX if on else 0.0
	toggle_btn.offset_left = _home["bl"] + dx
	toggle_btn.offset_right = _home["br"] + dx
	panel.offset_left = _home["pl"] + dx
	panel.offset_right = _home["pr"] + dx

# 点右上角按钮：展开/收起道具面板。
func _toggle() -> void:
	Sfx.play_click()
	panel.visible = not panel.visible
	if not panel.visible:
		desc.visible = false   # 收起时一并清掉说明

# 道具变化后调用：把已拥有的道具填进格子，空格子置灰。
func refresh() -> void:
	var ids: Array = Game.state.items.keys()
	for i in slots.size():
		var b := slots[i] as Button
		if i < ids.size():
			b.set_meta("id", ids[i])
			b.text = str(Content.ITEMS[ids[i]]["label"])
			b.disabled = false
			b.modulate.a = 1.0
		else:
			b.set_meta("id", "")
			b.text = "·"
			b.disabled = true
			b.modulate.a = 0.4

func _on_slot(i: int) -> void:
	var id := str((slots[i] as Button).get_meta("id", ""))
	if id == "":
		return
	Sfx.play_click()
	if id == "oldman_phone":
		_open_phone_view()   # 老人手机 → 看今天的莫忘对话(不是简单说明)
		return
	_show_desc(str(Content.ITEMS[id]["label"]) + "：" + str(Content.ITEMS[id]["desc"]))

# 点开老人手机：看「今天」的莫忘对话；看完莫忘提醒去终端恢复完整历史。
func _open_phone_view() -> void:
	pv_text.text = "\n\n".join(Content.MOWANG_TODAY_LINES)
	pv_scroll.set_deferred("scroll_vertical", 0)
	phone_view.visible = true
	_notify_hint("unlock_log")

func _close_phone_view() -> void:
	Sfx.play_click()
	phone_view.visible = false

# 发莫忘提醒(去重)：记进莫忘日志+红点；当前场景若有手机实例则顺带响一声/弹小字。
func _notify_hint(id: String) -> void:
	if not Content.MOWANG_HINTS.has(id):
		return
	if Game.state.fire_hint(id, str(Content.MOWANG_HINTS[id])):
		var sc := get_tree().current_scene
		var ph := sc.get_node_or_null("Phone") if sc else null
		if ph and ph.has_method("notify_hint"):
			ph.notify_hint()

func _show_desc(t: String) -> void:
	desc.text = t
	desc.visible = true
	desc.modulate.a = 1.0
	if _desc_tween and _desc_tween.is_valid():
		_desc_tween.kill()
	_desc_tween = create_tween()
	_desc_tween.tween_interval(3.0)
	_desc_tween.tween_property(desc, "modulate:a", 0.0, 0.6)
	_desc_tween.tween_callback(func() -> void: desc.visible = false)
