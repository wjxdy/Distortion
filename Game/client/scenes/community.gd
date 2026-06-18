# 小区外景（色块占位，横版可走，套警局走廊套路）。两栋楼：楼①底下俩邻居议论老人；楼②=老人的楼。
# 移动/动画由 Player 负责；本脚本管门口提示 + NPC 旁白 + 切场景。后期换真图。
extends Control

const WORLD := "res://scenes/world.tscn"
const ELEVATOR := "res://scenes/elevator.tscn"

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var npc_text: Label = $NpcText
@onready var exit_area: Area2D = $ExitArea
@onready var npc_area: Area2D = $NpcArea
@onready var building_door: Area2D = $OldBuildingDoor
@onready var phone: CanvasLayer = $Phone

func _ready() -> void:
	Music.play_world_with_rain()
	prompt.visible = false
	npc_text.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从街道/电梯回来时，落到对应入口锚点

func _process(_delta: float) -> void:
	if player.locked:
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	npc_text.visible = _at(npc_area)   # 走到楼①底下 → 听见邻居议论
	if _at(building_door):
		prompt.text = "↑ 进入  老人的楼"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "↑ 返回  街道"
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
	if _at(building_door):
		Game.spawn_point = ""   # 电梯是纯 UI，无需锚点；清掉以防残留
		Sfx.play_door()
		get_tree().change_scene_to_file(ELEVATOR)
	elif _at(exit_area):
		Game.spawn_point = "community"   # 回街道时落到小区门口
		Sfx.play_door()
		get_tree().change_scene_to_file(WORLD)
