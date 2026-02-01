extends Node

## Wave Manager 腳本 - 管理遊戲波次和敵人生成

signal spawn_enemy(enemy_type: String)  # 發送敵人生成信號，包含敵人種類
signal wave_started(wave_number: int)  # 波次開始信號
signal wave_completed(wave_number: int)  # 波次完成信號

@export var spawn_distance: float = 600.0  # 生成距離（半徑）

# 波次資料結構
class WaveData:
	var wave_number: int
	var duration: float  # 波次持續時間（秒）
	var enemy_rules: Array  # 敵人生成規則陣列

	func _init(wave_num: int, dur: float, rules: Array):
		wave_number = wave_num
		duration = dur
		enemy_rules = rules

# 敵人生成規則結構
class EnemyRule:
	var enemy_type: String  # "normal", "tank"
	var spawn_interval: float  # 生成間隔（秒）
	var timer: float = 0.0  # 內部計時器

	func _init(type: String, interval: float):
		enemy_type = type
		spawn_interval = interval

# 波次定義
var waves: Array[WaveData] = []
var current_wave: int = 0
var wave_timer: float = 0.0
var game_timer: float = 0.0  # 總遊戲時間，用於無盡模式
var is_wave_active: bool = false
var endless_mode: bool = false

# 無盡模式參數
var endless_base_interval: float = 1.5  # 基礎生成間隔（從1.0增加到1.5）
var endless_speed_increase: float = 0.01  # 每秒速度增加量（從0.02減少到0.01）
var endless_min_interval: float = 0.5  # 最小生成間隔（從0.3增加到0.5）

func _ready() -> void:
	# 監聽難度改變信號，如果難度在運行時改變，重新設定波次
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		difficulty_manager.difficulty_changed.connect(_on_difficulty_changed)
	
	_setup_waves()
	
	# 檢查遊戲模式
	var game_mode_manager = get_node_or_null("/root/GameModeManager")
	if game_mode_manager and game_mode_manager.is_endless_mode():
		# 無盡模式：直接進入無盡模式
		_start_endless_mode()
	else:
		# 故事模式：開始波次
		_start_wave(1)

func _start_endless_mode() -> void:
	"""直接開始無盡模式"""
	current_wave = 4  # 設置為最後一波
	wave_timer = 0.0
	endless_mode = true
	is_wave_active = true
	
	print("🎯 直接進入無盡模式！")
	wave_started.emit(current_wave)

func _on_difficulty_changed(difficulty: int) -> void:
	"""難度改變時重新設定波次"""
	print("難度改變，重新設定波次: ", difficulty)
	waves.clear()
	_setup_waves()
	
	# 如果當前在遊戲中，重新開始第一波
	if current_wave > 0 and is_wave_active:
		_start_wave(1)

func _process(delta: float) -> void:
	if not is_wave_active:
		return

	game_timer += delta
	wave_timer += delta

	# 檢查波次是否結束
	if not endless_mode and wave_timer >= waves[current_wave - 1].duration:
		_complete_current_wave()
		return

	# 處理每個敵人規則的生成
	var current_wave_data = waves[current_wave - 1] if not endless_mode else null

	if endless_mode:
		# 無盡模式：所有敵人隨機混合，速度隨時間加快
		_handle_endless_mode(delta)
	else:
		# 普通波次模式
		for rule in current_wave_data.enemy_rules:
			rule.timer += delta
			if rule.timer >= rule.spawn_interval:
				rule.timer = 0.0
				spawn_enemy.emit(rule.enemy_type)

func _setup_waves() -> void:
	"""設定所有波次的資料（根據難度動態調整）"""
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	
	# 獲取難度設定
	var enemy_speed = 280.0  # 默認普通難度
	var tank_chance = 0.05
	
	if difficulty_manager:
		enemy_speed = difficulty_manager.get_enemy_speed()
		tank_chance = difficulty_manager.get_tank_spawn_chance()
	
	# 根據敵人速度計算波次難度倍率
	var difficulty_multiplier = enemy_speed / 280.0  # 普通難度為基準
	
	# Wave 1: 基礎訓練（根據難度調整持續時間和間隔）
	var wave1_duration = 15.0 / difficulty_multiplier  # 簡單難度時間更長
	var wave1_interval = 1.0 / difficulty_multiplier   # 簡單難度間隔更大
	var wave1_rules = [EnemyRule.new("normal", wave1_interval)]
	waves.append(WaveData.new(1, wave1_duration, wave1_rules))
	
	# Wave 2: 引入坦克威脅
	var wave2_duration = 20.0 / difficulty_multiplier
	var wave2_normal_interval = 1.5 / difficulty_multiplier
	var wave2_tank_interval = 5.0 / difficulty_multiplier
	var wave2_rules = [
		EnemyRule.new("normal", wave2_normal_interval),
		EnemyRule.new("tank", wave2_tank_interval)
	]
	waves.append(WaveData.new(2, wave2_duration, wave2_rules))
	
	# Wave 3: 衝刺敵人登場
	var wave3_duration = 20.0 / difficulty_multiplier
	var wave3_normal_interval = 1.5 / difficulty_multiplier
	var wave3_rules = [
		EnemyRule.new("normal", wave3_normal_interval)
	]
	waves.append(WaveData.new(3, wave3_duration, wave3_rules))
	
	# Wave 4: 無盡模式（難度已經在_process中調整）
	var wave4_rules = [
		EnemyRule.new("normal", 1.0),
		EnemyRule.new("tank", 3.0)
	]
	waves.append(WaveData.new(4, 0.0, wave4_rules))  # duration 0 表示無盡
	
	print("波次設定已根據難度調整 - 難度倍率: %.2f" % difficulty_multiplier)

func _start_wave(wave_number: int) -> void:
	"""開始指定波次"""
	current_wave = wave_number
	wave_timer = 0.0
	is_wave_active = true

	if wave_number >= waves.size():
		# 進入無盡模式
		endless_mode = true
		print("🎯 進入無盡模式！所有敵人隨機混合，速度不斷提升")
	else:
		endless_mode = false
		print("🌊 波次 %d 開始！持續 %.1f 秒" % [wave_number, waves[wave_number - 1].duration])

	wave_started.emit(wave_number)

func _complete_current_wave() -> void:
	"""完成當前波次"""
	is_wave_active = false
	wave_completed.emit(current_wave)

	if current_wave < waves.size():
		# 還有下一波，3秒後開始
		print("✅ 波次 %d 完成！3秒後開始下一波..." % current_wave)
		await get_tree().create_timer(3.0).timeout
		_start_wave(current_wave + 1)
	else:
		# 所有波次完成，進入無盡模式
		print("🏆 所有波次完成！進入無盡挑戰...")
		await get_tree().create_timer(3.0).timeout
		_start_wave(current_wave + 1)

func _handle_endless_mode(delta: float) -> void:
	"""處理無盡模式的敵人生成"""
	# 計算當前生成間隔（隨時間加快）
	var current_interval = max(endless_base_interval - (game_timer * endless_speed_increase), endless_min_interval)

	# 使用靜態變數來追蹤生成計時器
	if not has_meta("endless_timer"):
		set_meta("endless_timer", 0.0)

	var endless_timer = get_meta("endless_timer") + delta
	set_meta("endless_timer", endless_timer)

	if endless_timer >= current_interval:
		set_meta("endless_timer", 0.0)

		# 隨機選擇敵人種類（權重：normal 70%, tank 30%）
		var rand = randf()
		var enemy_type: String

		if rand < 0.7:
			enemy_type = "normal"
		else:
			enemy_type = "tank"

		spawn_enemy.emit(enemy_type)

		# 每100個敵人輸出一次難度資訊
		var enemy_count = get_meta("enemy_count") if has_meta("enemy_count") else 0
		enemy_count += 1
		set_meta("enemy_count", enemy_count)

		if enemy_count % 100 == 0:
			print("🔥 無盡模式進度：已生成 %d 個敵人，當前間隔 %.2f 秒" % [enemy_count, current_interval])

func get_current_wave() -> int:
	"""獲取當前波次編號"""
	return current_wave

func get_wave_progress() -> float:
	"""獲取當前波次的進度 (0.0 ~ 1.0)"""
	if endless_mode or not is_wave_active:
		return 1.0

	var current_wave_data = waves[current_wave - 1]
	return wave_timer / current_wave_data.duration

func get_game_time() -> float:
	"""獲取總遊戲時間"""
	return game_timer

func is_endless_mode() -> bool:
	"""檢查是否處於無盡模式"""
	return endless_mode

func stop() -> void:
	"""停止波次管理器"""
	is_wave_active = false
	print("波次管理器已停止")

func reset() -> void:
	"""重置波次管理器狀態"""
	current_wave = 0
	wave_timer = 0.0
	game_timer = 0.0
	is_wave_active = false
	endless_mode = false
	waves.clear()
	_setup_waves()
	print("[DEBUG] Spawner reset: game_timer =", game_timer, ", endless_mode =", endless_mode)
