# 全局音效单例（autoload 名 Sfx）。任何场景调用 Sfx.play_click() 等即可。
extends Node

var blip: AudioStream
var click: AudioStream       # 点击图标/手机/按钮
var reveal: AudioStream      # 真相浮现
var door: AudioStream        # 进入场景/开门
var notify: AudioStream      # 手机弹消息(任务/莫忘提醒)
var typing: AudioStream      # 老头对话打字机(循环；打字时播，打完停)

var _typing_player: AudioStreamPlayer  # 打字机专用持久 player，便于 start/stop

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
func start_typing() -> void:
	if _typing_player and not _typing_player.playing:
		_typing_player.play()

func stop_typing() -> void:
	if _typing_player:
		_typing_player.stop()
