extends Node

## 分數管理腳本 - 全局單例，管理遊戲分數

signal score_changed(new_score: int)  # 分數改變信號

var score: int = 0

func _ready() -> void:
	# 初始化時發出信號
	score_changed.emit(score)

func add_score(amount: int) -> void:
	"""增加分數"""
	score += amount
	score_changed.emit(score)
	print("分數已更新: ", score)

func reset_score() -> void:
	"""重置分數為 0"""
	score = 0
	score_changed.emit(score)
	print("分數已重置")

func get_score() -> int:
	"""獲取當前分數"""
	return score
