# 警局档案室 / 证物室（色块占位，可走）。这里取走周明远家的钥匙(搜查授权)→ 进道具栏。
extends Control

const POLICE := "res://scenes/police.tscn"
const Content = preload("res://game/content.gd")

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var info: Label = $Info
@onready var key_obj: ColorRect = $KeyObj
@onready var key_area: Area2D = $KeyArea
@onready var exit_area: Area2D = $ExitArea
@onready var phone: CanvasLayer = $Phone

func _ready() -> void:
	prompt.visible = false
	info.visible = false
	key_obj.visible = not Game.state.has_item("home_key")   # 已取过就不再显示
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(key_area) and not Game.state.has_item("home_key"):
		prompt.text = "↑ 取走  钥匙"
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
	if _at(key_area) and not Game.state.has_item("home_key"):
		_take_key()
	elif _at(exit_area):
		Sfx.play_door()
		get_tree().change_scene_to_file(POLICE)

func _take_key() -> void:
	Sfx.play_click()
	Game.state.add_item("home_key")
	Inv.refresh()
	key_obj.visible = false
	info.text = "你取走了周明远家的钥匙（搜查授权已批）。现在可以去他家了。"
	info.visible = true
	# 莫忘提醒：钥匙到手 → 可以去小区
	if Game.state.fire_hint("got_key", str(Content.MOWANG_HINTS["got_key"])):
		phone.notify_hint()
