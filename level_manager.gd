extends Node

## LevelManager - 管理玩家等級和經驗值系統

# 基本屬性
var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 10

# 信號
signal level_up(new_level: int)
signal xp_changed(current: int, needed: int)
signal victory_achieved  # 勝利達成信號

# 勝利條件
const VICTORY_LEVEL = 10

func _ready() -> void:
	print("LevelManager 初始化 - 等級: %d, XP: %d/%d" % [current_level, current_xp, xp_to_next_level])

func gain_xp(amount: int) -> void:
	"""獲得經驗值"""
	current_xp += amount
	print("獲得 XP: %d, 總計: %d/%d" % [amount, current_xp, xp_to_next_level])
	
	# 發送信號更新 UI
	xp_changed.emit(current_xp, xp_to_next_level)
	
	# 檢查是否升級
	while current_xp >= xp_to_next_level:
		_level_up()

func _level_up() -> void:
	"""升級處理"""
	current_level += 1
	current_xp = 0
	xp_to_next_level = round(xp_to_next_level * 1.5)
	
	print("🎉 升級到等級 %d！下級需要 XP: %d" % [current_level, xp_to_next_level])
	
	# 發送信號
	level_up.emit(current_level)
	
	# 只在故事模式下檢查勝利條件
	var game_mode_manager = get_node_or_null("/root/GameModeManager")
	if game_mode_manager and game_mode_manager.is_story_mode():
		# 檢查勝利條件
		if current_level >= VICTORY_LEVEL:
			print("🏆 恭喜！達到等級 %d，遊戲勝利！" % VICTORY_LEVEL)
			victory_achieved.emit()
			return
	
	# 發送信號讓主場景處理升級畫面顯示
	# 主場景會在接收到 level_up 信號後顯示升級畫面

func reset_level() -> void:
	"""重置等級和經驗值"""
	current_level = 1
	current_xp = 0
	xp_to_next_level = 10
	
	print("等級已重置 - 等級: %d, XP: %d/%d" % [current_level, current_xp, xp_to_next_level])
	
	# 發送信號更新UI
	xp_changed.emit(current_xp, xp_to_next_level)

# 獲取等級資訊
func get_current_level() -> int:
	return current_level

func get_current_xp() -> int:
	return current_xp

func get_xp_to_next_level() -> int:
	return xp_to_next_level

func get_xp_progress() -> float:
	"""獲取 XP 進度百分比 (0.0 - 1.0)"""
	if xp_to_next_level == 0:
		return 1.0
	return float(current_xp) / float(xp_to_next_level)
