# 主世界 · 街道。移动/动画由 Player.tscn(player.gd) 负责；本脚本只管门口提示与切场景。
# 门口交互：走到 PoliceDoor / CommunityDoor 标记附近按 ↑ 进入（标记可在编辑器拖到门上）。
extends Control

const POLICE := "res://scenes/police.tscn"

@onready var player: CharacterBody2D = $Player
@onready var police_door: Area2D = $PoliceDoor
@onready var community_door: Area2D = $CommunityDoor
@onready var prompt: Label = $Prompt
@onready var toast: Label = $Toast

var toast_tween: Tween

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）
	toast.modulate.a = 0.0
	prompt.visible = false
	_update_prompt()

func _process(_delta: float) -> void:
	if player.locked:
		return
	# 走到警局门口且按住 ↑/W → 进入
	if _near(police_door) and Input.is_action_pressed("move_up"):
		_enter_door(POLICE)
		return
	_update_prompt()

func _near(area: Area2D) -> bool:
	# 只有人物的碰撞体(Player/Col)真正叠到门触发区才算
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _near(police_door):
		prompt.text = "↑ 进入  警察局"
		prompt.visible = true
	elif _near(community_door):
		prompt.text = "↑ 进入  小区（暂未开放）"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 130.0)

func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if event.is_action_pressed("move_up") and _near(community_door) and not _near(police_door):
		Sfx.play_click()
		_show_toast("小区暂未开放，先去警察局。")

func _enter_door(scene_path: String) -> void:
	player.enter_door()
	Sfx.play_click()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)

func _show_toast(msg: String) -> void:
	toast.text = msg
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
