# 主角（可复用）：四向物理移动 + 动画 + 随机待机。被各场景实例化。
# 可走区域由场景里的 Walls(StaticBody2D + 碰撞形状) 决定，撞墙贴滑、可绕障碍 —— 在编辑器里拖墙体即可。
# 动画(detective_frames.tres)：左右走/向下走 → walk_right(向左翻转)；向上走 → walk_up；
#   站立 idle，久站随机插入 adjust_glasses / smoke。
# 进门由场景脚本调 enter_door()：锁住移动 + 播 walk_up；场景随后切场景。
extends CharacterBody2D

const FOOTSTEP_STREAM := preload("res://audio/footstep06.wav")

@export var speed := 300.0
@export var footstep_interval := 0.64
@export var footstep_volume_db := -16.0

var locked := false                 # 进门动画期间锁移动
var idle_gap := 0.0
var footstep_time := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer

# 防"幽灵按键"：上个场景(如审讯室打字用方向键/WASD)某移动键的释放事件，
# 可能在同步 change_scene 的瞬间丢失，残留成"按住"留在全局 Input 单例里，
# 导致新场景一加载就 get_vector 读到它→玩家没碰键盘也自动走。进场景时清掉残留。
static func clear_movement_input() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

func _ready() -> void:
	clear_movement_input()
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle")
	idle_gap = randf_range(4.0, 8.0)
	footstep_player.stream = FOOTSTEP_STREAM
	footstep_player.volume_db = footstep_volume_db

func _physics_process(delta: float) -> void:
	if locked:
		velocity = Vector2.ZERO
		move_and_slide()
		footstep_time = 0.0
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = v * speed
	move_and_slide()
	if v != Vector2.ZERO:
		_move_anim(v)
		_update_footsteps(delta)
		idle_gap = randf_range(4.0, 8.0)
	else:
		footstep_time = 0.0
		_idle_behavior(delta)

func _move_anim(v: Vector2) -> void:
	if absf(v.x) > 0.01:                      # 有水平分量 → 侧面走，向左翻转
		sprite.flip_h = v.x < 0.0
		if sprite.animation != "walk_right":
			sprite.play("walk_right")
	elif v.y < 0.0:                           # 纯向上 → 背面走
		if sprite.animation != "walk_up":
			sprite.play("walk_up")
	else:                                     # 纯向下 → 用侧面走动作
		sprite.flip_h = false
		if sprite.animation != "walk_right":
			sprite.play("walk_right")

func _idle_behavior(delta: float) -> void:
	if sprite.animation == "walk_right" or sprite.animation == "walk_up":
		sprite.play("idle")
		idle_gap = randf_range(4.0, 8.0)
		return
	if sprite.animation == "idle":
		idle_gap -= delta
		if idle_gap <= 0.0:
			sprite.play(["adjust_glasses", "smoke"].pick_random())

func _on_anim_finished() -> void:
	if sprite.animation == "adjust_glasses" or sprite.animation == "smoke":
		sprite.play("idle")
		idle_gap = randf_range(4.0, 8.0)

func _update_footsteps(delta: float) -> void:
	footstep_time -= delta
	if footstep_time > 0.0:
		return
	footstep_time = footstep_interval
	footstep_player.pitch_scale = randf_range(0.92, 1.08)
	footstep_player.volume_db = footstep_volume_db + randf_range(-2.0, 1.0)
	footstep_player.play()

# 场景调用：进门/出门 —— 锁住移动并播放朝 dir 走的动作("up"上 / "left"左 / "right"右)。
# 左/右出口用侧面走(walk_right + 翻转)，避免"按左键却向上走"的反直觉。
func enter_door(dir: String = "up") -> void:
	locked = true
	footstep_time = 0.0
	match dir:
		"left":
			sprite.flip_h = true
			sprite.play("walk_right")
		"right":
			sprite.flip_h = false
			sprite.play("walk_right")
		_:
			sprite.play("walk_up")
