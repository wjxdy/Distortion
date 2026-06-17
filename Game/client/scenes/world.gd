# 主世界 · 宽幅滚动街道(2560 宽) HD-2D：相机跟随玩家横向滚动，远景/雾视差。
# 移动/动画由 Player.tscn 负责；本脚本管相机跟随、雾漂移、门口提示与切场景。
# 门口交互：人物碰撞体叠到 PoliceDoor / CommunityDoor 触发区(Area2D) + 按 W/↑ 进入。
extends Control

const POLICE := "res://scenes/police.tscn"
const LEVEL_WIDTH := 2560.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var police_door: Area2D = $PoliceDoor
@onready var community_door: Area2D = $CommunityDoor
@onready var prompt: Label = $Prompt
@onready var toast: Label = $UI/Toast
@onready var phone: CanvasLayer = $Phone   # 可复用手机 UI 实例(phone.tscn)

var toast_tween: Tween

func _ready() -> void:
	# BGM 挂载点（音乐由用户后期实现）
	toast.modulate.a = 0.0
	prompt.visible = false
	# 看手机时锁住走动（手机自身管显隐/填字，这里只联动锁人）
	phone.opened.connect(func() -> void: player.locked = true)
	phone.closed.connect(func() -> void: player.locked = false)
	_update_prompt()
	# 开局有未读任务 → 响一声通知音，提示玩家点手机看任务
	if Game.state.task_unread:
		Sfx.play_notify()

func _process(_delta: float) -> void:
	# 相机跟随玩家(水平)，夹在关卡两端不露边
	camera.position.x = clampf(player.position.x, 640.0, LEVEL_WIDTH - 640.0)
	camera.position.y = 360.0
	if player.locked:
		return
	# 走到警局门口且按住 W/↑ → 进入
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
		# 提示是世界空间 Control，跟随玩家头顶(随相机一起滚)
		prompt.position = Vector2(player.position.x - prompt.size.x * 0.5, player.position.y - 150.0)

func _input(event: InputEvent) -> void:
	if player.locked:
		return
	if event.is_action_pressed("move_up") and _near(community_door) and not _near(police_door):
		Sfx.play_click()
		_show_toast("小区暂未开放，先去警察局。")

func _enter_door(scene_path: String) -> void:
	player.enter_door()
	Sfx.play_door()
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
