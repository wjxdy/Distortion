# 全局游戏状态单例（autoload 名 = Game）。
# 作用：让线索钥匙/真相/对话历史【跨场景保留】——比如在 world 的手机里查档案拿到钥匙，
# 切到 interrogation 审讯室后这把钥匙还在。各场景统一用 Game.state，不要再各自 new。
# 逻辑都在 GameState(已被单测覆盖)，这里只持有它的单一实例 + 提供新游戏重置。
extends Node

const GameState = preload("res://game/game_state.gd")

var state: GameState

# 场景切换导航：出发场景在切场景前设好"目标场景里的入口锚点名"，
# 目标场景 _ready 调 place_player 把玩家摆到对应 Marker2D 后清空。
# 为空（如开局从序幕进街道）则保持目标 .tscn 里的默认出生点。
var spawn_point: String = ""
var world_intro_from_opening := false

func _ready() -> void:
	reset()

# 开新游戏时调用（开场 opening 会调）：清空钥匙/真相/历史。
func reset() -> void:
	state = GameState.new()
	world_intro_from_opening = false

# 目标场景在 _ready 里调：按 spawn_point 找 Spawns/<名字> 的 Marker2D（可在编辑器拖），
# 把玩家移过去。没指定来源（如开局从序幕进街道）则回退到 Spawns/start 锚点。
# 出生点完全由锚点决定——Player 节点摆在编辑器哪儿都不影响。读完即清空，避免残留到下次。
func place_player(scene: Node, player: Node2D) -> void:
	var id := spawn_point
	spawn_point = ""
	if id == "":
		id = "start"   # 没来源 → 用开局默认锚点
	var marker := scene.get_node_or_null("Spawns/" + id) as Node2D
	if marker:
		player.position = marker.position
