extends CPUParticles2D

## 碰撞特效腳本 - 播放完畢後自動刪除

func _ready() -> void:
	# 連接粒子結束信號
	finished.connect(_on_finished)
	# 開始播放
	emitting = true

func _on_finished() -> void:
	# 粒子播放完畢後刪除自己
	queue_free()
