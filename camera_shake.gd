extends Camera2D

## Camera Shake - 相機震動效果

signal hit  # 震動觸發信號

@export var shake_intensity: float = 10.0  # 震動強度
@export var shake_duration: float = 0.3  # 震動持續時間（秒）

var shake_timer: float = 0.0
var shake_amount: float = 0.0

func _ready() -> void:
	# 啟用相機
	enabled = true
	# 連接信號
	hit.connect(_on_hit)

func _process(delta: float) -> void:
	if shake_timer > 0:
		# 更新震動計時器
		shake_timer -= delta
		
		# 計算當前震動強度（隨時間衰減）
		shake_amount = shake_intensity * (shake_timer / shake_duration)
		
		# 應用隨機偏移
		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		# 震動結束，重置偏移
		offset = Vector2.ZERO

func _on_hit() -> void:
	"""觸發相機震動"""
	shake_timer = shake_duration

func apply_shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	"""應用相機震動（可選參數，使用預設值時留空）"""
	if intensity > 0:
		shake_intensity = intensity
	if duration > 0:
		shake_duration = duration
	shake_timer = shake_duration
