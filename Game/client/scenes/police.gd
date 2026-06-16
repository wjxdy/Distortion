# 警局内部 · 横版走廊（复用街道同款移动：←→ 走，门口/出口按 ↑）
# 三个交互点：最左=返回街道；审讯室门=进老人对话；终端室门=进终端室(占位)。
# 美术全用纯色方块占位，后期替换。
extends Control

const STREET := "res://scenes/world.tscn"
const INTERROGATION := "res://scenes/interrogation.tscn"
const TERMINAL := "res://scenes/terminal.tscn"

const SPEED := 340.0
const MIN_X := 90.0
const MAX_X := 1190.0

# 交互触发区：玩家中心 x 落在区间 [x, y] 内按 ↑ 触发
const EXIT_ZONE := Vector2(70.0, 200.0)            # 返回街道
const INTERROGATION_DOOR := Vector2(260.0, 460.0)  # 审讯室门
const TERMINAL_DOOR := Vector2(800.0, 1000.0)      # 终端室门

@onready var player: ColorRect = $Player
@onready var prompt: Label = $Prompt

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）
	prompt.visible = false
	_update_prompt()

func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		var c := _player_center() + dir * SPEED * delta
		c = clampf(c, MIN_X, MAX_X)
		player.position.x = c - player.size.x * 0.5
	_update_prompt()

func _player_center() -> float:
	return player.position.x + player.size.x * 0.5

func _in(zone: Vector2) -> bool:
	var c := _player_center()
	return c >= zone.x and c <= zone.y

func _update_prompt() -> void:
	if _in(EXIT_ZONE):
		prompt.text = "↑ 返回  街道"
		prompt.visible = true
	elif _in(INTERROGATION_DOOR):
		prompt.text = "↑ 进入  审讯室"
		prompt.visible = true
	elif _in(TERMINAL_DOOR):
		prompt.text = "↑ 进入  终端室"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		prompt.position = Vector2(_player_center() - prompt.size.x * 0.5, player.position.y - 56.0)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_up"):
		return
	if _in(EXIT_ZONE):
		Sfx.play_click()
		get_tree().change_scene_to_file(STREET)
	elif _in(INTERROGATION_DOOR):
		Sfx.play_click()
		get_tree().change_scene_to_file(INTERROGATION)
	elif _in(TERMINAL_DOOR):
		Sfx.play_click()
		get_tree().change_scene_to_file(TERMINAL)
