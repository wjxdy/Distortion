# 主世界 · 横版街道（魂斗罗式：只左右走，没有跳；走到门口按 ↑ 进入对应地点）
# 美术全部用纯色方块占位，后期替换为真图。
# 入口：警察局 → 直接进审讯室；小区 → 暂未开放（占位）。
# 节点结构在 world.tscn，脚本只管移动与进门判定。
extends Control

const POLICE := "res://scenes/police.tscn"

const SPEED := 340.0            # 角色左右移动速度（像素/秒）
const MIN_X := 90.0             # 玩家中心可走的最左
const MAX_X := 1190.0           # 玩家中心可走的最右

# 建筑门口触发区：玩家中心 x 落在区间 [x, y] 内即可按 ↑ 进入
const POLICE_DOOR := Vector2(240.0, 440.0)
const COMMUNITY_DOOR := Vector2(840.0, 1060.0)

@onready var player: ColorRect = $Player
@onready var prompt: Label = $Prompt
@onready var toast: Label = $Toast

var toast_tween: Tween

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）：例如 Sfx.play_bgm("res://audio/world_theme.ogg")
	toast.modulate.a = 0.0
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

func _at_police() -> bool:
	var c := _player_center()
	return c >= POLICE_DOOR.x and c <= POLICE_DOOR.y

func _at_community() -> bool:
	var c := _player_center()
	return c >= COMMUNITY_DOOR.x and c <= COMMUNITY_DOOR.y

func _update_prompt() -> void:
	if _at_police():
		prompt.text = "↑ 进入  警察局"
		prompt.visible = true
	elif _at_community():
		prompt.text = "↑ 进入  小区（暂未开放）"
		prompt.visible = true
	else:
		prompt.visible = false
	if prompt.visible:
		# 提示跟随玩家头顶
		prompt.position = Vector2(_player_center() - prompt.size.x * 0.5, player.position.y - 56.0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		if _at_police():
			Sfx.play_click()
			get_tree().change_scene_to_file(POLICE)
		elif _at_community():
			Sfx.play_click()
			_show_toast("小区暂未开放，先去警察局。")

func _show_toast(msg: String) -> void:
	toast.text = msg
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
