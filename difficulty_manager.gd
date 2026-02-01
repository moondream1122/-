extends Node

## 難度管理器 - 全局單例，管理遊戲難度設定

signal difficulty_changed(difficulty: int)

enum Difficulty {
	EASY = 0,
	NORMAL = 1,
	HARD = 2,
	INSANE = 3
}

var current_difficulty: int = Difficulty.NORMAL

# 全局速度倍數（用於升級效果）
var global_speed_multiplier: float = 1.0

# 難度設定
var difficulty_settings = {
	Difficulty.EASY: {
		"name": "簡單",
		"enemy_speed": 200.0,
		"spawn_interval": 2.5,
		"min_spawn_interval": 1.2,
		"spawn_reduction": 0.03,
		"player_health": 5,
		"tank_spawn_chance": 0.02   # 2% 坦克
	},
	Difficulty.NORMAL: {
		"name": "普通",
		"enemy_speed": 280.0,
		"spawn_interval": 2.0,
		"min_spawn_interval": 0.8,
		"spawn_reduction": 0.05,
		"player_health": 5,
		"tank_spawn_chance": 0.05   # 5% 坦克
	},
	Difficulty.HARD: {
		"name": "困難",
		"enemy_speed": 380.0,
		"spawn_interval": 1.5,
		"min_spawn_interval": 0.5,
		"spawn_reduction": 0.08,
		"player_health": 5,
		"tank_spawn_chance": 0.08   # 8% 坦克
	},
	Difficulty.INSANE: {
		"name": "瘋狂",
		"enemy_speed": 500.0,
		"spawn_interval": 1.0,
		"min_spawn_interval": 0.3,
		"spawn_reduction": 0.12,
		"player_health": 5,
		"tank_spawn_chance": 0.12   # 12% 坦克
	}
}

func set_difficulty(difficulty: int) -> void:
	"""設置難度"""
	current_difficulty = difficulty
	difficulty_changed.emit(difficulty)
	print("難度設置為: ", get_difficulty_name())

func get_difficulty_name() -> String:
	"""獲取當前難度名稱"""
	return difficulty_settings[current_difficulty].name

func get_setting(key: String):
	"""獲取當前難度的設定值"""
	return difficulty_settings[current_difficulty][key]

func get_enemy_speed() -> float:
	return difficulty_settings[current_difficulty].enemy_speed * global_speed_multiplier

func set_global_speed_multiplier(multiplier: float) -> void:
	"""設置全局速度倍數（用於升級效果）"""
	global_speed_multiplier = multiplier
	print("全局速度倍數設置為: ", multiplier)

func get_spawn_interval() -> float:
	return difficulty_settings[current_difficulty].spawn_interval

func get_min_spawn_interval() -> float:
	return difficulty_settings[current_difficulty].min_spawn_interval

func get_spawn_reduction() -> float:
	return difficulty_settings[current_difficulty].spawn_reduction

func get_player_health() -> int:
	return difficulty_settings[current_difficulty].player_health

func get_tank_spawn_chance() -> float:
	return difficulty_settings[current_difficulty].tank_spawn_chance

func reset() -> void:
	"""重置難度管理器狀態"""
	global_speed_multiplier = 1.0
	current_difficulty = Difficulty.NORMAL  # 重置為普通難度
	print("[DEBUG] DifficultyManager reset: global_speed_multiplier =", global_speed_multiplier, ", current_difficulty =", current_difficulty)
