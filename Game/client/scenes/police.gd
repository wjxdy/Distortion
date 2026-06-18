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

var _doors_armed := false   # 反跳保护：先离开出生门区才允许踩门跳转

func _ready() -> void:
	Music.play_police_ambience()
	prompt.visible = false
	# 看手机时锁住走动（与 world 一致）
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	Game.place_player(self, player)   # 从街道/审讯室/终端/档案室回来时，落到对应门口锚点
	_update_prompt()

func _process(_delta: float) -> void:
	if player.locked:
		return
	# 反跳保护：刚进场景可能站在门口锚点(在门区内)，先离开所有门区再允许踩门跳转
	if not _doors_armed:
		if not _on_any_door():
			_doors_armed = true
	elif _check_doors():
		return
	_update_prompt()

func _at(area: Area2D) -> bool:
	# 只有人物的碰撞体(Player/Col)真正叠到触发区才算
	return area.overlaps_body(player)

func _on_any_door() -> bool:
	return _at(exit_area) or _at(interrogation_area) or _at(terminal_area) or _at(archive_area)

# 脚踩到某个门区即跳转(无需按键)。返回 true 表示已触发。
func _check_doors() -> bool:
	if _at(exit_area):
		_go(STREET, "police"); return true
	if _at(interrogation_area):
		_go(INTERROGATION, ""); return true
	if _at(terminal_area):
		_go(TERMINAL, ""); return true
	if _at(archive_area):
		_go(ARCHIVE, "from_police"); return true
	return false

func _update_prompt() -> void:
	if _at(exit_area):
		prompt.text = "▶ 街道"
		prompt.visible = true
	elif _at(interrogation_area):
		prompt.text = "▶ 审讯室"
		prompt.visible = true
	elif _at(terminal_area):
		prompt.text = "▶ 终端室"
		prompt.visible = true
	elif _at(archive_area):
		prompt.text = "▶ 档案室"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 130.0)

# 踩门跳转：锁住玩家+播进门动画，0.45s 后切场景。
func _go(scene_path: String, entry: String) -> void:
	Game.spawn_point = entry
	player.enter_door()
	Sfx.play_door()
	await get_tree().create_timer(0.45).timeout
	get_tree().change_scene_to_file(scene_path)
