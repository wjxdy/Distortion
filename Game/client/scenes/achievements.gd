extends Control

const MENU := "res://scenes/main_menu.tscn"

@onready var count_label: Label = $CountLabel
@onready var list_label: Label = $Scroll/List
@onready var back_btn: Button = $BackBtn

func _ready() -> void:
	var titles := Titles.all_titles()
	count_label.text = "已获得 %d 个称号" % titles.size()
	list_label.text = "暂无称号，去玩一局吧。" if titles.is_empty() else "\n".join(PackedStringArray(titles))
	back_btn.pressed.connect(func() -> void: Sfx.play_click(); get_tree().change_scene_to_file(MENU))
	back_btn.grab_focus()
