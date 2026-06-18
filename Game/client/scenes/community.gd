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
@onready var npc1: Sprite2D = $Npc1
@onready var npc2: Sprite2D = $Npc2

const CELL_W: int = 234
const CELL_H: int = 384
const IDLE_FRAMES: int = 5
var npc_frame: int = 0
var npc_timer: float = 0.0
var npc2_offset: int = 2   # NPC2 相位偏移，避免同步
var _doors_armed := false   # 反跳保护：先离开门区才允许踩门跳转

func _ready() -> void:
	Music.play_world_with_rain()
	prompt.visible = false
	npc_text.visible = false
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从街道/电梯回来时，落到对应入口锚点

func _process(delta: float) -> void:
	_animate_npcs(delta)
	if player.locked:
		return
	if not _doors_armed:
		if not _on_any_door():
			_doors_armed = true
	elif _check_doors():
		return
	_update_prompt()

func _on_any_door() -> bool:
	return _at(building_door) or _at(exit_area)

func _check_doors() -> bool:
	if _at(building_door):
		_go(ELEVATOR, ""); return true
	if _at(exit_area):
		_go(WORLD, "community"); return true
	return false

func _animate_npcs(delta: float) -> void:
	npc_timer += delta
	if npc_timer >= 1.0:   # 1 秒 1 帧，缓慢呼吸
		npc_timer = 0.0
		npc_frame = (npc_frame + 1) % IDLE_FRAMES
		npc1.region_rect = Rect2(npc_frame * CELL_W, 0, CELL_W, CELL_H)
		npc2.region_rect = Rect2(((npc_frame + npc2_offset) % IDLE_FRAMES) * CELL_W, 0, CELL_W, CELL_H)

func _at(area: Area2D) -> bool:
	return area.overlaps_body(player)

func _update_prompt() -> void:
	npc_text.visible = _at(npc_area)   # 走到楼①底下 → 听见邻居议论
	if _at(building_door):
		prompt.text = "▶ 老人的楼"
		prompt.visible = true
	elif _at(exit_area):
		prompt.text = "▶ 街道"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
