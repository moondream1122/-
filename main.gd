extends Node2D

## 主場景控制器 - 管理遊戲流程

# 預載敵人和粒子場景
@export var enemy_scene: PackedScene = preload("res://enemy.tscn")
@export var enemy_tank_scene: PackedScene = preload("res://enemy_tank.tscn")
@export var spark_scene: PackedScene = preload("res://spark.tscn")
@export var spawn_distance: float = 600.0  # 敵人生成距離中心的半徑
@export var tank_spawn_chance: float = 0.05  # 坦克生成機率 (5%)

@onready var projectiles: Node = $Projectiles
@onready var spawner: Node = $EnemySpawner
@onready var camera: Camera2D = $Camera2D
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var orbital_shield_label: Label = $CanvasLayer/OrbitalShieldLabel
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var final_score_label: Label = $CanvasLayer/GameOverScreen/GameOverPanel/FinalScoreLabel
@onready var restart_button: Button = $CanvasLayer/GameOverScreen/GameOverPanel/RestartButton
@onready var title_button: Button = $CanvasLayer/GameOverScreen/GameOverPanel/TitleButton
@onready var victory_screen: Control = $CanvasLayer/VictoryScreen
@onready var victory_level_label: Label = $CanvasLayer/VictoryScreen/VictoryPanel/VictoryLevelLabel
@onready var victory_score_label: Label = $CanvasLayer/VictoryScreen/VictoryPanel/VictoryScoreLabel
@onready var victory_restart_button: Button = $CanvasLayer/VictoryScreen/VictoryPanel/VictoryRestartButton
@onready var victory_title_button: Button = $CanvasLayer/VictoryScreen/VictoryPanel/VictoryTitleButton
@onready var core: Area2D = $Core
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var skill_ui: Control = $CanvasLayer/SkillUI
@onready var health_ui: Control = $CanvasLayer/HealthUI
@onready var upgrade_screen: CanvasLayer = preload("res://upgrade_screen.tscn").instantiate()
@onready var grayscale_rect: ColorRect = $HitStopFilter/GrayscaleRect

var game_over: bool = false
var shield_active: bool = false

# 天賦系統
var has_multi_ball: bool = false
var has_quantum_tunneling: bool = false
var has_voltage_chain: bool = false
var has_explosive_touch: bool = false

# 血量系統
var max_health: int = 3
var current_health: int = 3

# Hit Stop 系統
var hit_stop_active: bool = false

# 無敵時間系統
var invincibility_time: float = 0.0
var invincibility_duration: float = 1.5  # 無敵持續時間（秒）
var is_invincible: bool = false

# 受傷視覺效果
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var canvas_modulate: CanvasModulate = CanvasModulate.new()
var original_glow_intensity: float = 1.5
var original_tonemap_exposure: float = 1.0

func _on_skill_used(skill_name: String) -> void:
	"""技能使用時的 UI 更新"""
	_update_skill_ui(skill_name)

func _ready() -> void:
	# 從難度管理器獲取血量設定
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		max_health = difficulty_manager.get_player_health()
		current_health = max_health
		print("難度血量設定: %d" % max_health)
		print("當前難度: %s" % difficulty_manager.get_difficulty_name())
	
	# 初始化衛星盾等級顯示
	if orbital_shield_label:
		orbital_shield_label.text = "衛星盾: 0級"

	# Debug: 顯示畫面遮罩與濾鏡初始狀態
	print("[DEBUG] _ready: Engine.time_scale=", Engine.time_scale)
	if canvas_modulate:
		print("[DEBUG] _ready: canvas_modulate.color=", canvas_modulate.color)
	else:
		print("[DEBUG] _ready: canvas_modulate not set")
	if grayscale_rect:
		print("[DEBUG] _ready: grayscale_rect.visible=", grayscale_rect.visible)
	else:
		print("[DEBUG] _ready: grayscale_rect not set")
	
	# 清除衛星盾狀態（遊戲重啟時重置）
	if has_meta("orbital_shield_level"):
		remove_meta("orbital_shield_level")
	if has_meta("orbital_shields"):
		var shields = get_meta("orbital_shields")
		for shield in shields:
			if is_instance_valid(shield):
				shield.queue_free()
		remove_meta("orbital_shields")
	
	# 連接 Spawner 的信號
	spawner.spawn_enemy.connect(_on_spawn_enemy)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_completed.connect(_on_wave_completed)
	
	# 連接重新開始按鈕
	restart_button.pressed.connect(_on_restart_button_pressed)
	
	# 連接返回標題按鈕
	title_button.pressed.connect(_on_title_button_pressed)
	
	# 連接勝利畫面按鈕
	victory_restart_button.pressed.connect(_on_victory_restart_button_pressed)
	victory_title_button.pressed.connect(_on_victory_title_button_pressed)
	
	# 連接 Core 的進入信號
	core.body_entered.connect(_on_core_body_entered)
	
	# 連接 ScoreManager 的信號（如果已設置為 AutoLoad）
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.score_changed.connect(_on_score_changed)
	
	# 初始化 UI
	_update_score_display()
	_update_xp_display(0, 10)  # 初始化 XP 顯示
	
	# 連接技能管理器信號
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager:
		skill_manager.skill_used.connect(_on_skill_used)
		skill_manager.cooldown_updated.connect(_on_skill_cooldown_updated)
	
	# 連接技能按鈕
	$CanvasLayer/SkillUI/slow_motion_button.pressed.connect(_on_skill_button_pressed.bind("slow_motion"))
	$CanvasLayer/SkillUI/shield_button.pressed.connect(_on_skill_button_pressed.bind("shield"))
	$CanvasLayer/SkillUI/clear_screen_button.pressed.connect(_on_skill_button_pressed.bind("clear_screen"))
	
	# 連接 LevelManager 信號
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.xp_changed.connect(_on_xp_changed)
		level_manager.level_up.connect(_on_level_up)
		# 只在故事模式下連接勝利信號
		var game_mode_manager = get_node_or_null("/root/GameModeManager")
		if game_mode_manager and game_mode_manager.is_story_mode():
			level_manager.victory_achieved.connect(_on_victory_achieved)
	
	# 初始化護盾
	shield_sprite.visible = false
	
	# 初始化血量
	current_health = max_health
	_update_health_ui()
	
	# 保存原始環境設定
	if world_environment and world_environment.environment:
		original_glow_intensity = world_environment.environment.glow_intensity
		original_tonemap_exposure = world_environment.environment.tonemap_exposure
	
	# 添加全畫面閃爍效果節點
	add_child(canvas_modulate)
	canvas_modulate.color = Color(1, 1, 1, 1)  # 初始為正常顏色
	
	# 添加升級介面
	add_child(upgrade_screen)
	upgrade_screen.visible = false
	print("[DEBUG] _ready: upgrade_screen.visible=", upgrade_screen.visible)
	
	# 初始化勝利畫面
	victory_screen.visible = false

func _process(delta: float) -> void:
	"""處理無敵時間"""
	if is_invincible:
		invincibility_time -= delta
		if invincibility_time <= 0:
			is_invincible = false
			# 恢復正常外觀
			modulate = Color(1, 1, 1, 1)
			canvas_modulate.color = Color(1, 1, 1, 1)  # 恢復正常畫面顏色
			print("無敵時間結束")
		
		# 無敵期間全畫面閃爍效果
		else:
			var flash_speed = 12.0  # 閃爍速度
			var flash_intensity = sin(Time.get_ticks_msec() * 0.01 * flash_speed) * 0.4 + 0.6
			# 白色閃爍，帶點紅色調
			canvas_modulate.color = Color(1.0, flash_intensity, flash_intensity, 1.0)
	
	# 更新衛星盾位置
	_update_orbital_shields(delta)

	# 更新影分身（如果存在），讓其跟隨玩家
	var player = get_node_or_null("Player")
	if player:
		for child in get_children():
			if child.name == "ShadowPaddle":
				var shadow_angle = player.rotation + PI
				# 取得玩家的 paddle_distance（player.gd 有宣告該屬性）
				var pd = player.paddle_distance
				# 設置位置與旋轉
				child.global_position = player.global_position + Vector2(cos(shadow_angle), sin(shadow_angle)) * pd
				child.rotation = shadow_angle

func _on_spawn_enemy(enemy_type: String) -> void:
	"""處理敵人生成信號"""
	if not game_over:
		spawn_enemy(enemy_type)

func spawn_enemy(enemy_type: String) -> void:
	"""在圓周上隨機位置生成指定類型的敵人"""
	# 決定生成哪種敵人
	var enemy: CharacterBody2D
	
	match enemy_type:
		"normal":
			enemy = enemy_scene.instantiate()
			print("生成普通敵人")
		"tank":
			enemy = enemy_tank_scene.instantiate()
			print("★ 生成鐵甲巨獸！")
		_:
			# 默認生成普通敵人
			enemy = enemy_scene.instantiate()
			print("⚠ 未知敵人類型 '%s'，生成普通敵人" % enemy_type)
	
	# 計算隨機生成位置（在圓周上）
	var angle = randf() * TAU  # 隨機角度
	var spawn_position = Vector2(
		cos(angle) * spawn_distance,
		sin(angle) * spawn_distance
	)
	
	enemy.global_position = spawn_position
	
	# 連接敵人信號
	enemy.enemy_scored.connect(_on_enemy_scored)
	enemy.enemy_bounced.connect(_on_enemy_bounced)
	
	# 添加到 Projectiles 容器
	projectiles.add_child(enemy)

func _on_enemy_bounced(bounce_position: Vector2) -> void:
	"""處理敵人被反彈時的信號"""
	# 觸發相機震動
	camera.apply_shake(15.0, 0.2)
	
	# 生成粒子效果
	_spawn_spark_effect(bounce_position)

func _spawn_spark_effect(position: Vector2) -> void:
	"""在指定位置生成火花粒子效果"""
	var spark = spark_scene.instantiate()
	spark.global_position = position
	spark.emitting = true
	add_child(spark)
	
	# 0.8秒後自動刪除粒子節點
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(spark):
		spark.queue_free()

func show_combo_text(position: Vector2, combo: int, score: int) -> void:
	"""在指定位置顯示 Combo 文字"""
	var label = Label.new()
	label.text = "x%d! +%d" % [combo, score]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 設置樣式
	label.add_theme_font_size_override("font_size", 24 + combo * 4)
	
	# 根據連殺數改變顏色
	if combo >= 4:
		label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # 紅色
	elif combo >= 3:
		label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # 橙色
	elif combo >= 2:
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))  # 黃色
	else:
		label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))  # 青色
	
	label.global_position = position - Vector2(50, 20)
	label.z_index = 100
	add_child(label)
	
	# 動畫：向上飄動並淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 80, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.15).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 1.5秒後刪除
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(label):
		label.queue_free()

func _on_enemy_scored() -> void:
	"""處理敵人飛出畫面的信號"""
	# 使用 ScoreManager 增加分數
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(50)
	
	print("敵人飛出畫面！")
	
	# 觸發相機震動
	camera.apply_shake(12.0, 0.2)

func _update_score_display() -> void:
	"""更新分數顯示"""
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_label.text = "SCORE: %d" % score_manager.get_score()
	else:
		score_label.text = "SCORE: 0"

func _on_score_changed(new_score: int) -> void:
	"""監聯 ScoreManager 的分數改變信號"""
	score_label.text = "SCORE: %d" % new_score

func _on_wave_started(wave_number: int) -> void:
	"""處理波次開始"""
	print("🎯 波次 %d 開始！" % wave_number)
	
	# 可以添加波次開始的UI提示或其他效果
	show_wave_start_message(wave_number)

func _on_wave_completed(wave_number: int) -> void:
	"""處理波次完成"""
	print("✅ 波次 %d 完成！" % wave_number)
	
	# 可以添加波次完成的UI提示或其他效果
	show_wave_complete_message(wave_number)

func show_wave_start_message(wave_number: int) -> void:
	"""顯示波次開始訊息"""
	var label = Label.new()
	label.text = "WAVE %d" % wave_number
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	
	# 顯示在右下角
	label.position = Vector2(
		get_viewport_rect().size.x - 320,
		get_viewport_rect().size.y - 100
	)
	label.z_index = 500  # 提高z_index確保顯示在最上層
	
	# 添加到CanvasLayer而不是主節點
	$CanvasLayer.add_child(label)
	
	# 動畫效果 - 放大顯示然後淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(2.0)  # 延遲2秒後開始淡出
	
	await get_tree().create_timer(2.5).timeout  # 總顯示時間2.5秒
	if is_instance_valid(label):
		label.queue_free()

func show_wave_complete_message(wave_number: int) -> void:
	"""顯示波次完成訊息"""
	var label = Label.new()
	label.text = "WAVE %d CLEAR!" % wave_number
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	
	# 顯示在右下角
	label.position = Vector2(
		get_viewport_rect().size.x - 300,
		get_viewport_rect().size.y - 80
	)
	label.z_index = 500  # 提高z_index確保顯示在最上層
	
	# 添加到CanvasLayer而不是主節點
	$CanvasLayer.add_child(label)
	
	# 動畫效果 - 放大顯示然後淡出
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(2.0)  # 延遲2秒後開始淡出
	
	await get_tree().create_timer(2.5).timeout  # 總顯示時間2.5秒
	if is_instance_valid(label):
		label.queue_free()

func hit_stop(duration: float = 0.1, time_scale: float = 0.0) -> void:
	"""觸發 Hit Stop 效果（畫面凍結 + 黑白濾鏡）"""
	if hit_stop_active:
		return  # 防止重複觸發
	
	hit_stop_active = true
	Engine.time_scale = time_scale
	
	# 啟用黑白濾鏡
	if grayscale_rect:
		grayscale_rect.visible = true
	
	print("Hit Stop 開始！time_scale = ", time_scale)
	
	# 使用 SceneTreeTimer，設置 ignore_time_scale = true 確保不受時間縮放影響
	var timer = get_tree().create_timer(duration, true, false, true)
	await timer.timeout
	
	# 關閉黑白濾鏡
	if grayscale_rect:
		grayscale_rect.visible = false
	
	Engine.time_scale = 1.0
	hit_stop_active = false
	print("Hit Stop 結束！time_scale = 1.0")

func _on_game_over() -> void:
	"""遊戲結束"""
	if game_over:
		return  # 防止重複觸發
	
	game_over = true
	spawner.stop()
	
	var score_manager = get_node_or_null("/root/ScoreManager")
	var final_score = score_manager.get_score() if score_manager else 0
	final_score_label.text = "Final Score: %d" % final_score
	game_over_screen.visible = true
	
	# 暫停遊戲
	get_tree().paused = true
	
	print("遊戲結束！最終分數: ", final_score)

func _on_victory_achieved() -> void:
	"""勝利達成處理"""
	if game_over:
		return
	
	game_over = true
	
	# 停止敵人生成
	if spawner:
		spawner.is_wave_active = false
	
	# 獲取最終統計
	var score_manager = get_node_or_null("/root/ScoreManager")
	var level_manager = get_node_or_null("/root/LevelManager")
	
	var final_score = score_manager.get_score() if score_manager else 0
	var final_level = level_manager.get_current_level() if level_manager else 1
	
	# 更新勝利畫面
	victory_level_label.text = "最終等級: %d" % final_level
	victory_score_label.text = "最終分數: %d" % final_score
	
	# 顯示勝利畫面
	victory_screen.visible = true
	
	# 暫停遊戲
	get_tree().paused = true
	
	# 播放勝利音效（如果有的話）
	# play_victory_music()
	
	print("🎉 遊戲勝利！等級: %d, 分數: %d" % [final_level, final_score])

func _on_victory_restart_button_pressed() -> void:
	"""勝利畫面的重新開始按鈕"""
	# 重置所有遊戲狀態
	_reset_game_state()
	
	# 隱藏勝利畫面
	victory_screen.visible = false
	
	# 重新開始遊戲
	get_tree().reload_current_scene()

func _on_victory_title_button_pressed() -> void:
	"""勝利畫面的返回標題按鈕"""
	# 重置所有遊戲狀態
	_reset_game_state()
	
	# 返回標題畫面
	get_tree().change_scene_to_file("res://title_screen.tscn")

func _reset_game_state() -> void:
	"""重置所有遊戲狀態"""
	# 重置分數
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.reset_score()
	
	# 重置等級
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.reset_level()
	
	# 重置技能
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager:
		skill_manager.reset_all_skills()
	
	# 重置升級歷史記錄
	if upgrade_screen and upgrade_screen.has_method("reset_upgrade_history"):
		upgrade_screen.reset_upgrade_history()
	
	# 重置難度管理器
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		difficulty_manager.reset()
	
	# 重置遊戲模式管理器
	var game_mode_manager = get_node_or_null("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.reset()
	
	# 重置敵人生成器
	var spawner = get_node_or_null("EnemySpawner")
	if spawner and spawner.has_method("reset"):
		spawner.reset()
	
	# 重置玩家狀態
	var player = get_node_or_null("Player")
	if player and player.has_method("reset"):
		player.reset()
	
	# 重置天賦標誌
	has_multi_ball = false
	has_quantum_tunneling = false
	has_voltage_chain = false
	has_explosive_touch = false
	
	# 重置玩家生命值和無敵狀態
	current_health = max_health
	invincibility_time = 0.0
	
	# 清除場景中的所有敵人和 XP 寶石
	_clear_all_enemies_and_gems()
	
	# 清除軌道盾狀態（避免重啟後遺留等級與小球）
	if has_meta("orbital_shield_level"):
		remove_meta("orbital_shield_level")
	if has_meta("orbital_shields"):
		var shields = get_meta("orbital_shields")
		for shield in shields:
			if is_instance_valid(shield):
				shield.queue_free()
		remove_meta("orbital_shields")
	
	# 重新初始化衛星盾顯示
	if orbital_shield_label:
		orbital_shield_label.text = "衛星盾: 0級"
	
	# 恢復遊戲時間流
	get_tree().paused = false

	# 隱藏升級介面以防止重啟時殘留遮罩
	if is_instance_valid(upgrade_screen):
		upgrade_screen.visible = false

	# 恢復時間縮放與畫面遮罩狀態
	Engine.time_scale = 1.0
	if canvas_modulate:
		canvas_modulate.color = Color(1, 1, 1, 1)
	if grayscale_rect:
		grayscale_rect.visible = false
	
	# 恢復環境效果
	if world_environment and world_environment.environment:
		# 停止任何正在運行的環境tween
		var tree = get_tree()
		if tree:
			for tween in tree.get_processed_tweens():
				if tween and tween.is_valid():
					tween.kill()
		
		# 恢復原始環境設置
		world_environment.environment.glow_intensity = original_glow_intensity
		world_environment.environment.tonemap_exposure = original_tonemap_exposure

func _clear_all_enemies_and_gems() -> void:
	"""清除場景中的所有敵人和 XP 寶石"""
	# 清除敵人（包括友方球）
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	# 清除 XP 寶石
	var gems = get_tree().get_nodes_in_group("xp_gem")
	for gem in gems:
		if is_instance_valid(gem):
			gem.queue_free()

func _on_restart_button_pressed() -> void:
	"""重新開始遊戲"""
	# 使用通用的重置函數來重置所有狀態（包含軌道盾）
	_reset_game_state()

	# 重新載入場景
	get_tree().reload_current_scene()

func _on_title_button_pressed() -> void:
	"""返回標題畫面選擇難度"""
	# 使用通用的重置函數來重置所有狀態（包含軌道盾）
	_reset_game_state()

	# 返回標題畫面
	get_tree().change_scene_to_file("res://title_screen.tscn")

func _on_core_body_entered(body: Node2D) -> void:
	"""當敵人進入 Core 區域"""
	# 檢查是否是敵人（在 enemy 分組）
	if body.is_in_group("enemy"):
		# 如果護盾啟動，反彈敵人
		if shield_active:
			_deflect_enemy(body)
			return
		
		# 檢查是否處於無敵狀態
		if is_invincible:
			print("處於無敵狀態，忽略傷害")
			# 如果敵人還沒有被反彈過，才掉落 XP 寶石
			if not body.has_bounced and body.has_method("die"):
				body.die()
			
			# 仍然刪除敵人，但不扣血
			if body.has_method("play_explosion_sound"):
				body.play_explosion_sound()
				await get_tree().create_timer(0.1).timeout
			
			if is_instance_valid(body):
				body.queue_free()
			return
		
		# 造成傷害
		_take_damage(1)
		
		# 如果敵人還沒有被反彈過，才掉落 XP 寶石
		if not body.has_bounced and body.has_method("die"):
			body.die()
		
		# 播放爆炸音效並刪除敵人
		if body.has_method("play_explosion_sound"):
			body.play_explosion_sound()
			# 延遲刪除敵人，讓音效有時間播放
			await get_tree().create_timer(0.1).timeout
		
		# 檢查敵人是否仍然有效（可能在等待期間被刪除）
		if is_instance_valid(body):
			body.queue_free()

func _deflect_enemy(enemy: Node2D) -> void:
	"""護盾反彈敵人"""
	# 檢查敵人是否已經被反彈過
	if enemy.has_bounced:
		return
	
	if enemy.has_method("deflect_from_shield"):
		enemy.deflect_from_shield()
	else:
		# 基本反彈邏輯
		if enemy is CharacterBody2D:
			enemy.velocity = -enemy.velocity * 1.5
	
	# 觸發相機震動
	camera.apply_shake(20.0, 0.3)
	
	# 給予分數
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(100)
	
	# 檢查爆炸接觸天賦
	if has_explosive_touch:
		_create_explosion_at_position(enemy.global_position)
	
	# 檢查連鎖閃電天賦
	if has_voltage_chain and randf() < 0.3:  # 30% 機率
		_trigger_voltage_chain(enemy)

func _trigger_voltage_chain(source_enemy: Node2D) -> void:
	"""觸發連鎖閃電效果"""
	print("⚡ 觸發連鎖閃電！")
	
	# 找到所有敵人
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	# 移除源敵人（已經被反彈）
	var valid_enemies = []
	for enemy in enemies:
		if enemy != source_enemy and is_instance_valid(enemy):
			valid_enemies.append(enemy)
	
	# 按距離排序，選擇最近的3個
	valid_enemies.sort_custom(func(a, b): return a.global_position.distance_to(source_enemy.global_position) < b.global_position.distance_to(source_enemy.global_position))
	
	var chain_targets = []
	for i in range(min(3, valid_enemies.size())):
		chain_targets.append(valid_enemies[i])
	
	# 為每個目標創建閃電效果
	for target in chain_targets:
		_create_lightning_effect(source_enemy.global_position, target.global_position)
		# 延遲傷害
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(1)  # 造成1點傷害
			print("閃電擊中敵人！")

func _create_explosion_at_position(position: Vector2) -> void:
	"""在指定位置創建爆炸推開效果"""
	print("爆炸接觸！位置:", position)
	
	# 創建爆炸區域
	var explosion_area = Area2D.new()
	explosion_area.name = "ExplosionArea"
	explosion_area.global_position = position
	
	# 添加碰撞形狀 - 從小到大瞬間膨脹
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 10.0  # 初始小半徑
	collision_shape.shape = circle_shape
	explosion_area.add_child(collision_shape)
	
	# 設置為只檢測敵人
	explosion_area.collision_layer = 0
	explosion_area.collision_mask = 1  # 敵人層
	
	add_child(explosion_area)
	
	# 創建推開動畫
	var tween = create_tween()
	
	# 瞬間膨脹到最大半徑
	tween.tween_property(circle_shape, "radius", 80.0, 0.1)
	
	# 在膨脹期間推開敵人
	tween.parallel().tween_callback(func():
		_push_enemies_away(explosion_area, position, 80.0)
	)
	
	# 完成後清理
	tween.tween_callback(func():
		if is_instance_valid(explosion_area):
			explosion_area.queue_free()
	)

func _push_enemies_away(explosion_area: Area2D, center: Vector2, radius: float) -> void:
	"""推開爆炸範圍內的敵人"""
	var overlapping_bodies = explosion_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body.is_in_group("enemy") and body is CharacterBody2D:
			# 計算從中心到敵人的方向
			var direction = (body.global_position - center).normalized()
			
			# 根據距離計算推開力度（越近推得越遠）
			var distance = body.global_position.distance_to(center)
			var push_strength = (radius - distance) / radius  # 0-1 的力度
			
			if push_strength > 0:
				# 應用推開力
				var push_force = direction * push_strength * 400.0  # 推開力度
				body.velocity += push_force

func _create_lightning_effect(start_pos: Vector2, end_pos: Vector2) -> void:
	"""創建閃電視覺效果"""
	var lightning = Line2D.new()
	lightning.width = 3.0
	lightning.default_color = Color(0.2, 0.8, 1.0, 0.8)  # 亮藍色
	lightning.z_index = 10
	
	# 創建鋸齒狀閃電路徑
	var points = [start_pos]
	var segments = 8
	var direction = (end_pos - start_pos).normalized()
	var length = start_pos.distance_to(end_pos)
	
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = start_pos + direction * length * t
		# 添加隨機偏移
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = perpendicular * (randf() - 0.5) * 20.0
		points.append(base_pos + offset)
	
	points.append(end_pos)
	lightning.points = points
	
	# 添加到場景
	add_child(lightning)
	
	# 動畫效果：閃爍然後消失
	var tween = create_tween()
	tween.tween_property(lightning, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): lightning.queue_free())

func _take_damage(amount: int) -> void:
	"""受到傷害"""
	current_health -= amount
	_update_health_ui()
	
	# 設置無敵狀態
	is_invincible = true
	invincibility_time = invincibility_duration
	
	# 觸發強化視覺效果
	_trigger_damage_effects()
	
	print("受到傷害！剩餘血量: %d，進入無敵狀態 %.1f 秒" % [current_health, invincibility_duration])
	
	if current_health <= 0:
		_on_game_over()

func _trigger_damage_effects() -> void:
	"""觸發受傷時的強化視覺效果"""
	# 1. 強烈相機震動
	if camera:
		camera.apply_shake(50.0, 0.6)  # 更大的震動強度和持續時間
	
	# 2. 螢幕警報 - WorldEnvironment 特效
	if world_environment and world_environment.environment:
		# 保存當前值
		var current_glow = world_environment.environment.glow_intensity
		var current_exposure = world_environment.environment.tonemap_exposure
		
		# 瞬間拉高 Glow 和調低曝光 (製造紅色/高對比效果)
		world_environment.environment.glow_intensity = 5.0
		world_environment.environment.tonemap_exposure = 0.3  # 降低曝光，製造更暗更紅的效果
		
		# 0.1秒後恢復
		var env_tween = create_tween()
		env_tween.set_parallel(false)
		env_tween.tween_property(world_environment.environment, "glow_intensity", current_glow, 0.1)
		env_tween.tween_property(world_environment.environment, "tonemap_exposure", current_exposure, 0.1)

func _flash_damage() -> void:
	"""受傷閃紅效果"""
	var tween = create_tween()
	modulate = Color(1, 0.3, 0.3, 1)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

func _update_health_ui() -> void:
	"""更新血量 UI 顯示"""
	for i in range(max_health):
		var heart = health_ui.get_node_or_null("Heart" + str(i + 1))
		if heart:
			if i < current_health:
				heart.modulate = Color(1, 0.2, 0.3, 1)  # 紅色愛心
			else:
				heart.modulate = Color(0.3, 0.3, 0.3, 0.5)  # 灰色愛心


func activate_shield(duration: float) -> void:
	"""啟動護盾"""
	shield_active = true
	shield_sprite.visible = true
	
	# 護盾閃爍動畫
	var tween = create_tween().set_loops(int(duration * 2))
	tween.tween_property(shield_sprite, "modulate:a", 0.5, 0.25)
	tween.tween_property(shield_sprite, "modulate:a", 1.0, 0.25)
	
	await get_tree().create_timer(duration).timeout
	
	shield_active = false
	shield_sprite.visible = false
	tween.kill()
	print("護盾已結束")

func _on_skill_button_pressed(skill_name: String) -> void:
	"""處理技能按鈕點擊"""
	var skill_manager = get_node_or_null("/root/SkillManager")
	if skill_manager:
		skill_manager.use_skill(skill_name)

func _on_skill_cooldown_updated(skill_name: String, remaining: float, _total: float) -> void:
	"""更新技能冷卻 UI"""
	var skill_button = skill_ui.get_node_or_null(skill_name + "_button")
	if skill_button:
		if remaining > 0:
			skill_button.modulate = Color(0.5, 0.5, 0.5)
			skill_button.text = _get_skill_display_text(skill_name, remaining)
			skill_button.disabled = true
		else:
			skill_button.modulate = Color(1, 1, 1)
			skill_button.text = _get_skill_display_text(skill_name, 0)
			skill_button.disabled = false

func _update_skill_ui(skill_name: String) -> void:
	"""更新技能 UI 顯示"""
	var skill_button = skill_ui.get_node_or_null(skill_name + "_button")
	if skill_button:
		skill_button.modulate = Color(0.5, 0.5, 0.5)
		skill_button.disabled = true

func _get_skill_display_text(skill_name: String, cooldown: float) -> String:
	"""獲取技能顯示文字"""
	var cd_text = "" if cooldown <= 0 else " (%.1fs)" % cooldown
	match skill_name:
		"slow_motion":
			return "[1] 時間減緩" + cd_text
		"shield":
			return "[2] 護盾" + cd_text
		"clear_screen":
			return "[3] 清屏" + cd_text
	return ""

# LevelManager 相關函數
func _on_xp_changed(current: int, needed: int) -> void:
	"""XP 變化時更新 UI"""
	_update_xp_display(current, needed)

func _on_level_up(new_level: int) -> void:
	"""升級時的處理"""
	print("玩家升級到等級 %d！" % new_level)
	
	# 顯示升級畫面
	show_upgrade_screen()

func _update_xp_display(current_xp: int, xp_needed: int) -> void:
	"""更新 XP UI 顯示"""
	var xp_bar = $CanvasLayer/XPBar
	var xp_text = $CanvasLayer/XPText
	
	if xp_bar:
		var progress = float(current_xp) / float(xp_needed) * 100.0
		xp_bar.value = progress
	
	if xp_text:
		var level_manager = get_node_or_null("/root/LevelManager")
		var level = 1
		if level_manager:
			level = level_manager.get_current_level()
		xp_text.text = "LEVEL %d - XP: %d/%d" % [level, current_xp, xp_needed]

func show_upgrade_screen() -> void:
	"""顯示升級畫面"""
	upgrade_screen.show_upgrade_screen()
	
	# 暫停遊戲
	get_tree().paused = true

# 升級效果函數
func upgrade_paddle_size(multiplier: float) -> void:
	"""升級擋板大小"""
	var player = $Player
	if player:
		player.paddle_distance *= multiplier
		
		# 同時調整碰撞形狀大小
		var paddle = player.get_node("Paddle")
		if paddle:
			var collision_shape = paddle.get_node("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				# 將碰撞形狀的大小乘以倍數
				collision_shape.shape.size *= multiplier
				
				# 同時調整 ColorRect 大小（而不是縮放）
				var paddle_sprite = paddle.get_node("PaddleSprite")
				if paddle_sprite and paddle_sprite is ColorRect:
					# 調整 ColorRect 的 offset 來匹配新的碰撞形狀大小
					var new_size = collision_shape.shape.size
					paddle_sprite.offset_left = -new_size.x / 2
					paddle_sprite.offset_top = -new_size.y / 2
					paddle_sprite.offset_right = new_size.x / 2
					paddle_sprite.offset_bottom = new_size.y / 2
		
		print("擋板大小升級: x%.1f" % multiplier)

func upgrade_spin_speed(multiplier: float) -> void:
	"""升級旋轉速度"""
	var player = $Player
	if player:
		player.parry_threshold *= (1.0 / multiplier)  # 降低閾值使旋轉更容易檢測
		print("旋轉速度升級: +%.0f%%" % ((multiplier - 1.0) * 100))

func heal_player(amount: int) -> void:
	"""治療玩家"""
	current_health = min(current_health + amount, max_health)
	_update_health_ui()
	print("治療: +%d HP" % amount)

func orbital_shield() -> void:
	"""啟用衛星盾 - 每次升級增加一個小球"""
	print("[DEBUG] orbital_shield() called")
	
	# 獲取當前衛星盾等級，如果不存在則為0
	var shield_level = 0
	if has_meta("orbital_shield_level"):
		shield_level = get_meta("orbital_shield_level")
		print("[DEBUG] Found existing shield level: %d" % shield_level)
	
	# 增加等級
	shield_level += 1
	set_meta("orbital_shield_level", shield_level)
	
	print("[DEBUG] orbital_shield() called. New level: %d" % shield_level)
	
	# 更新UI顯示
	if orbital_shield_label:
		orbital_shield_label.text = "衛星盾: %d級" % shield_level
	
	# 只創建一個新的小球（而不是重新創建所有小球）
	_create_orbital_shield_ball(shield_level - 1, shield_level)

func multi_ball() -> void:
	"""啟用分身球天賦"""
	has_multi_ball = true
	print("分身球天賦啟用！")

func quantum_tunneling() -> void:
	"""啟用量子穿透天賦"""
	has_quantum_tunneling = true
	print("量子穿透天賦啟用！")

func voltage_chain() -> void:
	"""啟用連鎖閃電天賦"""
	has_voltage_chain = true
	print("連鎖閃電天賦啟用！")

func explosive_touch() -> void:
	"""啟用爆炸接觸天賦"""
	has_explosive_touch = true
	print("爆炸接觸天賦啟用！")

func create_ghost_ball(original_ball: Node2D) -> void:
	"""創建幽靈球 - 精準格擋時的額外球"""
	if not has_multi_ball:
		return
	
	# 複製原本的球
	var ghost_ball = original_ball.duplicate()
	ghost_ball.name = "GhostBall"
	
	# 設定為友方（不會傷害玩家）
	ghost_ball.is_friendly = true
	ghost_ball.has_bounced = false
	
	# 設定壽命 3 秒
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.connect("timeout", Callable(self, "_on_ghost_ball_timeout").bind(ghost_ball))
	ghost_ball.add_child(timer)
	timer.start()
	
	# 設定碰撞層 - 只與敵人碰撞
	ghost_ball.collision_layer = 2  # 假設敵人是層2
	ghost_ball.collision_mask = 2   # 只檢測敵人
	
	# 設定視覺效果 - 半透明
	if ghost_ball.has_node("Sprite2D"):
		var sprite = ghost_ball.get_node("Sprite2D")
		sprite.modulate.a = 0.5
	
	# 設定速度 - 稍微不同方向
	var original_velocity = original_ball.velocity
	var angle_offset = randf_range(-PI/6, PI/6)  # 隨機偏移角度
	var new_direction = original_velocity.normalized().rotated(angle_offset)
	ghost_ball.velocity = new_direction * original_velocity.length() * 0.8  # 稍慢
	
	# 添加到場景
	projectiles.add_child(ghost_ball)
	
	print("幽靈球創建！")

func _on_ghost_ball_timeout(ghost_ball: Node2D) -> void:
	"""幽靈球壽命結束"""
	if is_instance_valid(ghost_ball):
		ghost_ball.queue_free()
		print("幽靈球消失")

func _create_orbital_shield_ball(index: int, total_balls: int) -> void:
	"""創建單個衛星盾小球"""
	print("[DEBUG] Creating orbital shield ball %d/%d" % [index + 1, total_balls])
	
	# 創建衛星盾節點
	var shield = Area2D.new()
	shield.name = "OrbitalShield_%d" % index
	
	# 設置碰撞層（衛星盾在第 2 層）
	shield.collision_layer = 2
	shield.collision_mask = 1  # 檢測第 1 層（敵人）
	shield.monitoring = true  # 啟用區域監測
	
	# 添加碰撞形狀 - 增大碰撞區域
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 50.0  # 增大衛星盾半徑從25.0到50.0
	collision_shape.shape = circle_shape
	shield.add_child(collision_shape)
	
	# 添加視覺效果 - 創建更好的視覺效果
	var sprite = Sprite2D.new()
	var texture = load("res://icon.svg")
	sprite.texture = texture
	sprite.scale = Vector2(0.3, 0.3)  # 增大視覺尺寸從0.1到0.3
	
	# 添加霓虹發光效果
	var material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform vec4 glow_color : source_color = vec4(0.2, 1.0, 0.4, 1.0);
	uniform float glow_intensity : hint_range(0.0, 5.0) = 3.0;
	uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;
	
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
		
		vec4 final_color = tex;
		final_color.rgb = glow_color.rgb * glow_intensity * pulse;
		final_color.a = tex.a;
		
		COLOR = final_color;
	}
	"""
	material.shader = shader
	material.set_shader_parameter("glow_color", Color(0.5, 0.0, 1.0, 1.0))  # 紫色霓虹
	material.set_shader_parameter("glow_intensity", 3.0)
	material.set_shader_parameter("pulse_speed", 4.0)
	
	sprite.material = material
	shield.add_child(sprite)
	
	# 設置衛星盾位置和旋轉邏輯
	# 根據小球索引計算初始角度
	var initial_angle = (2 * PI * index) / total_balls
	shield.position = Vector2(cos(initial_angle) * 100, sin(initial_angle) * 100)
	add_child(shield)
	
	# 連接碰撞信號 - 使用body_entered因為敵人是CharacterBody2D
	shield.connect("body_entered", Callable(self, "_on_orbital_shield_hit"))
	
	# 創建圍繞玩家旋轉的動畫
	var orbital_distance = 100.0  # 軌道距離
	
	# 使用自定義腳本或在 _process 中處理旋轉
	shield.set_meta("orbital_distance", orbital_distance)
	shield.set_meta("ball_index", index)
	shield.set_meta("total_balls", total_balls)
	
	# 添加到衛星盾列表以便在 _process 中更新
	if not has_meta("orbital_shields"):
		set_meta("orbital_shields", [])
	get_meta("orbital_shields").append(shield)

func _update_orbital_shields(delta: float) -> void:
	"""更新衛星盾的位置，使其圍繞玩家旋轉並保持相對間距"""
	if not has_meta("orbital_shields"):
		return
	
	var shields = get_meta("orbital_shields")
	if shields.is_empty():
		return
	
	# 獲取或創建共享的旋轉角度
	var base_angle = 0.0
	if has_meta("orbital_base_angle"):
		base_angle = get_meta("orbital_base_angle")
	
	# 更新基礎角度（所有小球共享的旋轉）
	var orbital_speed = 2.0  # 旋轉速度（弧度/秒）
	base_angle += orbital_speed * delta
	set_meta("orbital_base_angle", base_angle)
	
	# 更新每個小球的位置
	for shield in shields:
		if is_instance_valid(shield):
			var orbital_distance = shield.get_meta("orbital_distance", 100.0)
			var ball_index = shield.get_meta("ball_index", 0)
			var total_balls = shield.get_meta("total_balls", 1)
			
			# 計算每個小球的固定角度偏移
			var angle_offset = (2 * PI * ball_index) / total_balls
			
			# 最終角度 = 共享基礎角度 + 固定偏移
			var final_angle = base_angle + angle_offset
			
			# 計算位置
			var new_x = cos(final_angle) * orbital_distance
			var new_y = sin(final_angle) * orbital_distance
			shield.position = Vector2(new_x, new_y)

func _on_orbital_shield_hit(body: Node2D) -> void:
	"""衛星盾碰撞到敵人時的處理"""
	# 檢查是否是敵人
	if body.is_in_group("enemy"):
		# 給予分數
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.add_score(50)
		
		# 播放音效（如果敵人有）
		if body.has_method("play_explosion_sound"):
			body.play_explosion_sound()
		
		# 觸發相機震動
		if camera:
			camera.apply_shake(15.0, 0.2)
		
		# 生成粒子效果
		_spawn_spark_effect(body.global_position)
		
		# 讓敵人正常死亡（會掉落 XP 寶石）
		if body.has_method("die"):
			body.die()
		else:
			# 如果沒有 die 方法，直接刪除
			if is_instance_valid(body):
				body.queue_free()
		
		print("衛星盾擊殺敵人！")

func shadow_clone() -> void:
	"""啟用影分身"""
	print("影分身啟用")

	var player = $Player
	if not player:
		print("錯誤：找不到 Player 節點，無法創建影分身")
		return

	var paddle = player.get_node_or_null("Paddle")
	if not paddle:
		print("錯誤：Player 中找不到 Paddle，無法創建影分身")
		return

	# 嘗試深複製玩家的 Paddle（包含子節點）
	var clone_body = paddle.duplicate(true)
	if not clone_body:
		print("錯誤：複製 Paddle 失敗")
		return

	clone_body.name = "ShadowPaddle"

	# 對複製出來的節點及其子節點，將所有畫布項目設為半透明
	for node in clone_body.get_children():
		if node is CanvasItem:
			var m = node.modulate
			m.a = 0.5
			node.modulate = m
		# 再遞歸處理孫節點
		for sub in node.get_children():
			if sub is CanvasItem:
				var sm = sub.modulate
				sm.a = 0.5
				sub.modulate = sm

	# 複製碰撞層與遮罩
	if paddle.has_method("get_collision_layer") or paddle.has_meta("collision_layer"):
		# 直接嘗試複製屬性（大多數 Body2D 有這些屬性）
		clone_body.collision_layer = paddle.collision_layer
		clone_body.collision_mask = paddle.collision_mask

	# 設置影分身位置（與玩家相反的角度）
	var shadow_angle = player.rotation + PI
	clone_body.position = Vector2(cos(shadow_angle), sin(shadow_angle)) * player.paddle_distance
	clone_body.rotation = shadow_angle

	add_child(clone_body)

	print("影分身創建完成，位置: ", clone_body.position, " 角度: ", shadow_angle)

func neon_overload() -> void:
	"""啟用霓虹過載"""
	print("霓虹過載啟用")
	
	# 增加所有現有敵人的速度
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy.has_method("set_speed_multiplier"):
			enemy.set_speed_multiplier(2.0)
		else:
			enemy.speed *= 2.0  # 直接修改速度
	
	# 設置全局速度倍數標誌（影響新生成的敵人）
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager and difficulty_manager.has_method("set_global_speed_multiplier"):
		difficulty_manager.set_global_speed_multiplier(2.0)
	
	# 啟動彩虹色動畫
	var player = $Player
	if player:
		var rainbow_tween = create_tween()
		rainbow_tween.set_loops()
		
		# 彩虹色循環
		var colors = [
			Color(1, 0, 0),  # 紅
			Color(1, 0.5, 0),  # 橙
			Color(1, 1, 0),  # 黃
			Color(0, 1, 0),  # 綠
			Color(0, 0, 1),  # 藍
			Color(0.3, 0, 0.5),  # 靛
			Color(0.5, 0, 1)  # 紫
		]
		
		for i in range(colors.size()):
			rainbow_tween.tween_property(player, "modulate", colors[i], 0.5)
		
		print("霓虹過載效果啟用：雙倍敵人速度和彩虹色")
