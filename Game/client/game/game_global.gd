# 全局游戏状态单例（autoload 名 = Game）。
# 作用：让线索钥匙/真相/对话历史【跨场景保留】——比如在 world 的手机里查档案拿到钥匙，
# 切到 interrogation 审讯室后这把钥匙还在。各场景统一用 Game.state，不要再各自 new。
# 逻辑都在 GameState(已被单测覆盖)，这里只持有它的单一实例 + 提供新游戏重置。
extends Node

const GameState = preload("res://game/game_state.gd")

var state: GameState

func _ready() -> void:
	reset()

# 开新游戏时调用（开场 opening 会调）：清空钥匙/真相/历史。
func reset() -> void:
	state = GameState.new()
