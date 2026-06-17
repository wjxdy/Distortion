# 警局内部 · 走廊。移动/动画由 Player.tscn(player.gd) 负责；本脚本只管门口提示与切场景。
# 三个交互点(按 x 区间)：最左=返回街道；审讯室门=进老人对话；终端室门=进终端室(占位)。
extends Control

const STREET := "res://scenes/world.tscn"
const INTERROGATION := "res://scenes/interrogation.tscn"
const TERMINAL := "res://scenes/terminal.tscn"

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var exit_area: Area2D = $ExitArea
@onready var interrogation_area: Area2D = $InterrogationArea
@onready var terminal_area: Area2D = $TerminalArea

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）
	prompt.visible = false
	_update_prompt()

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	# 只有人物的碰撞体(Player/Col)真正叠到触发区才算
	return area.overlaps_body(player)

func _update_prompt() -> void:
	if _at(exit_area):
		prompt.text = "↑ 返回  街道"
		prompt.visible = true
	elif _at(interrogation_area):
		prompt.text = "↑ 进入  审讯室"
		prompt.visible = true
	elif _at(terminal_area):
		prompt.text = "↑ 进入  终端室"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 130.0)

func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if not event.is_action_pressed("move_up"):
		return
	if _at(exit_area):
		Sfx.play_door()
		get_tree().change_scene_to_file(STREET)      # 出门回街道，直接切
	elif _at(interrogation_area):
		_enter_door(INTERROGATION)
	elif _at(terminal_area):
		_enter_door(TERMINAL)

func _enter_door(scene_path: String) -> void:
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
