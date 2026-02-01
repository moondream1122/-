extends Node

## GameModeManager - 管理遊戲模式

# 遊戲模式枚舉
enum GameMode {
	STORY = 0,    # 故事模式：有勝利條件
	ENDLESS = 1   # 無盡模式：無限持續
}

# 當前遊戲模式
var current_mode: int = GameMode.STORY

func set_game_mode(mode: int) -> void:
	"""設置遊戲模式"""
	current_mode = mode
	print("遊戲模式設置為: ", get_mode_name())

func get_current_mode() -> int:
	"""獲取當前遊戲模式"""
	return current_mode

func get_mode_name() -> String:
	"""獲取當前模式名稱"""
	match current_mode:
		GameMode.STORY:
			return "故事模式"
		GameMode.ENDLESS:
			return "無盡模式"
		_:
			return "未知模式"

func is_story_mode() -> bool:
	"""檢查是否為故事模式"""
	return current_mode == GameMode.STORY

func is_endless_mode() -> bool:
	"""檢查是否為無盡模式"""
	return current_mode == GameMode.ENDLESS

func reset() -> void:
	"""重置遊戲模式為默認（故事模式）"""
	current_mode = GameMode.STORY