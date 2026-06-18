# 全局音效单例（autoload 名 Sfx）。任何场景调用 Sfx.play_click() 等即可。
extends Node

var blip: AudioStream
var click: AudioStream       # 点击图标/手机/按钮
var reveal: AudioStream      # 真相浮现
var door: AudioStream        # 进入场景/开门
var notify: AudioStream      # 手机弹消息(任务/莫忘提醒)
var typing: AudioStream      # 老头对话打字机(循环；打字时播，打完停)

var _typing_player: AudioStreamPlayer  # 打字机专用持久 player，便于 start/stop
var _typing_fade: Tween                # 起停淡入淡出，避免硬起硬停的爆音"嘣"
const TYPING_VOL_DB := 0.0
const TYPING_FADE := 0.06

func _ready() -> void:
	blip = load("res://audio/blip.wav")
	click = load("res://audio/click.wav")
	reveal = load("res://audio/reveal.wav")
	door = load("res://audio/open_door.wav")
	notify = load("res://audio/notify.wav")
	typing = load("res://audio/typing.mp3")
	if typing is AudioStreamMP3:
		typing.loop = true   # 循环以覆盖较长文本；打完手动 stop
	_typing_player = AudioStreamPlayer.new()
	_typing_player.stream = typing
	add_child(_typing_player)

func _play(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_blip() -> void:
	_play(blip)

func play_click() -> void:
	_play(click)

func play_reveal() -> void:
	_play(reveal)

func play_door() -> void:
	_play(door)

func play_notify() -> void:
	_play(notify)

# 打字机音效：开始打字时调（已在播则不重复），打字结束时调 stop。
# 起播淡入、停时淡出（~60ms），避免在波形高点硬起硬停产生的小爆音"嘣"。
func start_typing() -> void:
	if not _typing_player:
		return
	if _typing_fade and _typing_fade.is_valid():
		_typing_fade.kill()
	if _typing_player.playing:
		_typing_player.volume_db = TYPING_VOL_DB
		return
	_typing_player.volume_db = -40.0
	_typing_player.play()
	_typing_fade = create_tween()
	_typing_fade.tween_property(_typing_player, "volume_db", TYPING_VOL_DB, TYPING_FADE)

func stop_typing() -> void:
	if not _typing_player or not _typing_player.playing:
		return
	if _typing_fade and _typing_fade.is_valid():
		_typing_fade.kill()
	_typing_fade = create_tween()
	_typing_fade.tween_property(_typing_player, "volume_db", -40.0, TYPING_FADE)
	_typing_fade.tween_callback(_typing_player.stop)
