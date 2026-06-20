# 警局内部 · 走廊。移动/动画由 Player.tscn(player.gd) 负责；本脚本只管门口提示与切场景。
# 四个交互点(从左到右)：返回街道 / 审讯室 / 电脑终端室 / 档案室。
extends Control

const STREET := "res://scenes/world.tscn"
const INTERROGATION := "res://scenes/interrogation.tscn"
const TERMINAL := "res://scenes/terminal.tscn"
const ARCHIVE := "res://scenes/archive.tscn"

@onready var player: CharacterBody2D = $Player
@onready var prompt: Label = $Prompt
@onready var exit_area: Area2D = $ExitArea
@onready var interrogation_area: Area2D = $InterrogationArea
@onready var terminal_area: Area2D = $TerminalArea
@onready var archive_area: Area2D = $ArchiveArea
@onready var phone: CanvasLayer = $Phone   # 走廊也能点开手机

func _ready() -> void:
	Music.play_police_ambience()
	prompt.visible = false
	# 看手机时锁住走动（与 world 一致）
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从街道/审讯室/终端/档案室回来时，落到对应门口锚点
	Game.show_controls_hint_once($Hint)
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
	elif _at(archive_area):
		prompt.text = "↑ 进入  档案室"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 130.0)

# 警局四个门(含返回街道)都在前方/墙上，统一按 ↑/W 进出。
func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if not event.is_action_pressed("move_up"):
		return
	if _at(exit_area):
		_go(STREET, "police")
	elif _at(interrogation_area):
		_go(INTERROGATION, "")
	elif _at(terminal_area):
		_go(TERMINAL, "")
	elif _at(archive_area):
		_go(ARCHIVE, "from_police")

# 进门：锁住玩家+播进门动画，0.45s 后切场景。
func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
