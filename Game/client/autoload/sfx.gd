# 全局音效单例（autoload 名 Sfx）。任何场景调用 Sfx.play_blip() 等即可。
extends Node

var blip: AudioStream
var click: AudioStream
var reveal: AudioStream

func _ready() -> void:
	blip = load("res://audio/blip.wav")
	click = load("res://audio/click.wav")
	reveal = load("res://audio/reveal.wav")

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
