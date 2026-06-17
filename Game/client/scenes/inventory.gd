# 道具栏（autoload 全局 HUD = Inv）。底部常驻几个格子，显示已拿到的道具；点格子看说明。
# 全局单例 → 天然在每个场景都在，不用各场景实例化。色块占位，inventory.tscn 里可拖。
# 拿到新道具的地方调 Inv.refresh() 刷新。
extends CanvasLayer

const Content = preload("res://game/content.gd")

@onready var slots: Array = [
	$Bar/Slot0, $Bar/Slot1, $Bar/Slot2
]
@onready var desc: Label = $Desc

var _desc_tween: Tween

func _ready() -> void:
	for i in slots.size():
		(slots[i] as Button).pressed.connect(_on_slot.bind(i))
	desc.visible = false
	refresh()

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
	_show_desc(str(Content.ITEMS[id]["label"]) + "：" + str(Content.ITEMS[id]["desc"]))

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
