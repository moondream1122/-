extends CharacterBody2D

## Enemy 節點 - 從畫面外飛向中心，碰到 Paddle 會反彈並飛出畫面

signal enemy_scored  # 敵人飛出畫面時發送的信號
signal enemy_bounced(bounce_position: Vector2)  # 敵人被反彈時發送的信號
signal enemy_hit_core  # 敵人撞擊核心時發送的信號

var speed: float = 400.0  # 移動速度（將從難度管理器獲取）
@export var screen_boundary: float = 800.0  # 畫面邊界（用於判斷是否飛出）

# 預載碰撞特效場景
var impact_effect_scene: PackedScene = preload("res://impact_effect.tscn")

@onready var bounce_sound: AudioStreamPlayer2D = $BounceSound
@onready var explosion_sound: AudioStreamPlayer2D = $ExplosionSound
@onready var parry_sound: AudioStreamPlayer2D = $ParrySound
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

var has_bounced: bool = false  # 是否已經反彈過
var is_perfect_parry: bool = false  # 是否為精準格擋的球
var is_friendly: bool = false  # 是否為友方（被反彈後變為友方）
var kill_combo: int = 0  # 友方球連殺計數
var bounce_cooldown: float = 0.0  # 反彈冷卻時間（防止多次反彈）

func _ready() -> void:
	# 從難度管理器獲取敵人速度
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		speed = difficulty_manager.get_enemy_speed()
	
	# 添加到 enemy 分組，方便 Core 識別
	add_to_group("enemy")
	
	# 設置碰撞層（敵人在第 1 層）
	collision_layer = 1
	collision_mask = 1
	
	# 初始化朝向中心的速度
	var direction = (Vector2.ZERO - global_position).normalized()
	velocity = direction * speed

func _physics_process(_delta: float) -> void:
	# 更新反彈冷卻時間
	if bounce_cooldown > 0:
		bounce_cooldown -= _delta
	
	# 金色球（精準格擋）具有穿透屬性，檢測並擊殺路徑上的敵人
	if is_perfect_parry and has_bounced:
		_check_piercing_hits()
	
	# 友方球檢測與敵方碰撞
	if is_friendly and not is_perfect_parry:
		_check_friendly_collision()
	
	# 移動並處理碰撞
	var collision = move_and_collide(velocity * _delta)
	
	if collision:
		_handle_collision(collision)
	
	# 如果已經反彈過，檢查是否飛出畫面
	if has_bounced and _is_out_of_bounds():
		_on_enemy_escaped()

func _check_piercing_hits() -> void:
	"""金色球穿透檢測：擊殺路徑上的其他敵人"""
	var enemies = get_tree().get_nodes_in_group("enemy")
	var kill_radius: float = 40.0  # 擊殺半徑
	
	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy):
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < kill_radius:
			# 擊殺敵人
			_kill_enemy(enemy)

func _check_friendly_collision() -> void:
	"""友方球檢測：與敵方碰撞時擊殺敵人並繼續飛行"""
	var enemies = get_tree().get_nodes_in_group("enemy")
	var collision_radius: float = 35.0  # 碰撞半徑
	
	for enemy in enemies:
		if enemy == self:
			continue
		if not is_instance_valid(enemy):
			continue
		# 只對非友方敵人生效
		if enemy.is_friendly:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < collision_radius:
			# 友方與敵方碰撞！
			_friendly_enemy_collision(enemy)
			# 不返回，繼續檢測其他敵人

func _friendly_enemy_collision(enemy: Node2D) -> void:
	"""處理友方與敵方的碰撞"""
	var collision_point = (global_position + enemy.global_position) / 2.0
	
	# 增加連殺計數
	kill_combo += 1
	
	# 計算指數級分數：100 * 2^(combo-1)
	var combo_score = 100 * int(pow(2, kill_combo - 1))
	
	# 播放爆炸音效
	if enemy.has_method("play_explosion_sound"):
		enemy.play_explosion_sound()
	
	# 加分
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(combo_score)
	
	# 生成爆炸特效
	var main = get_tree().current_scene
	if main and main.has_method("_spawn_spark_effect"):
		main._spawn_spark_effect(collision_point)
	
	# 顯示 Combo 文字
	if main and main.has_method("show_combo_text"):
		main.show_combo_text(collision_point, kill_combo, combo_score)
	
	# 相機震動（連殺越多震動越大）
	if main and main.camera:
		main.camera.apply_shake(10.0 + kill_combo * 5.0, 0.2)
	
	print("★ 友方球連殺 x%d！得分+%d" % [kill_combo, combo_score])
	
	# 只銷毀敵人，友方球繼續飛行
	enemy.queue_free()

func _kill_enemy(enemy: Node2D) -> void:
	"""擊殺被穿透的敵人"""
	# 播放爆炸音效
	if enemy.has_method("play_explosion_sound"):
		enemy.play_explosion_sound()
	
	# 加分
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(100)
	
	# 生成粒子效果
	var main = get_tree().current_scene
	if main and main.has_method("_spawn_spark_effect"):
		main._spawn_spark_effect(enemy.global_position)
	
	# 相機震動
	if main and main.camera:
		main.camera.apply_shake(10.0, 0.15)
	
	print("★ 金色球穿透擊殺！")
	
	# 刪除敵人
	enemy.queue_free()

func _handle_collision(collision: KinematicCollision2D) -> void:
	"""處理碰撞事件"""
	var main = get_tree().current_scene
	var collider = collision.get_collider()
	
	# 獲取 Player 節點
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_node_or_null("/root/Main/Player")
	
	# 檢查是否碰撞到 Paddle 或 ShadowPaddle
	if collider and (collider.name == "Paddle" or collider.name == "ShadowPaddle"):
		# 如果是友方球，忽略與 Paddle 的碰撞
		if is_friendly:
			return
			
		# 如果在冷卻中，忽略此次碰撞
		if bounce_cooldown > 0:
			return
		
		# 如果已經反彈過，只做簡單的彈開處理（無冷卻）
		if has_bounced:
			velocity = velocity.bounce(collision.get_normal())
			return
		
		# 檢查量子穿透天賦
		if main and main.has_quantum_tunneling and randf() < 0.5:
			# 量子穿透：造成傷害但不反彈，繼續飛行
			print("量子穿透！")
			die()
			# 不設定has_bounced，不bounce，保持速度
			return
		
		# 使用反彈函數計算反彈後的速度
		velocity = velocity.bounce(collision.get_normal())
		has_bounced = true
		bounce_cooldown = 0.2  # 設置冷卻時間防止多次反彈
		
		# 檢查是否為精準格擋
		var is_perfect_parry_now = false
		if player and player.has_method("is_parrying") and player.is_parrying():
			is_perfect_parry_now = true
		
		# 被反彈後在原地留下 XP 寶石
		if is_perfect_parry_now:
			is_perfect_parry = true
		die()
		
		# 如果是精準格擋，應用額外效果
		if is_perfect_parry_now:
			print("★ 精準格擋觸發！")
			
			# 創建幽靈球（如果有分身球天賦）
			if main and main.has_method("create_ghost_ball"):
				main.create_ghost_ball(self)
			
			# 速度加倍
			velocity *= 2.0
			
			# 變成金色（更新著色器參數）
			var gold_color = Color(1.0, 0.85, 0.0, 1.0)
			modulate = gold_color
			if sprite:
				sprite.modulate = gold_color
				if sprite.material:
					sprite.material.set_shader_parameter("glow_color", gold_color)
					sprite.material.set_shader_parameter("glow_intensity", 3.5)
			
			# 播放精準格擋音效
			if parry_sound:
				parry_sound.pitch_scale = randf_range(1.0, 1.2)
				parry_sound.play()
			
			# 觸發 Hit Stop 效果
			if main and main.has_method("hit_stop"):
				main.hit_stop(0.1, 0.0)  # 完全凍結 0.1 秒
			else:
				print("警告：找不到 main 或 hit_stop 方法")
			
			# 額外加分（100 基礎 + 50 精準格擋獎勵）
			var score_manager = get_node_or_null("/root/ScoreManager")
			if score_manager:
				score_manager.add_score(150)
			
			print("★ 精準格擋！得分+150")
		else:
			# 普通防禦
			is_friendly = true  # 變為友方
			
			# 速度提升 1.5 倍
			velocity *= 1.5
			
			# 變成亮青色（更新著色器參數）
			var cyan_color = Color(0.0, 1.0, 1.0, 1.0)
			modulate = cyan_color
			if sprite:
				sprite.modulate = cyan_color
				if sprite.material:
					sprite.material.set_shader_parameter("glow_color", cyan_color)
					sprite.material.set_shader_parameter("glow_intensity", 2.5)
			
			_play_sound_with_random_pitch(bounce_sound)
			
			# 成功反彈時增加分數
			var score_manager = get_node_or_null("/root/ScoreManager")
			if score_manager:
				score_manager.add_score(100)
			
			print("反彈成功！得分+100")
		
		# 發送反彈信號，包含碰撞位置
		enemy_bounced.emit(collision.get_position())
	else:
		# 碰到其他物體，直接反彈
		velocity = velocity.bounce(collision.get_normal())

func _is_out_of_bounds() -> bool:
	"""檢查敵人是否飛出畫面"""
	return (abs(global_position.x) > screen_boundary or 
			abs(global_position.y) > screen_boundary)

func _on_enemy_escaped() -> void:
	"""敵人飛出畫面，增加分數並刪除自己"""
	print("敵人飛出畫面！")
	
	# 播放反彈音效
	_play_sound_with_random_pitch(bounce_sound)
	
	# 發送信號
	enemy_scored.emit()
	
	# 延遲刪除，讓音效有時間播放
	await get_tree().create_timer(0.1).timeout
	queue_free()

func play_explosion_sound() -> void:
	"""播放爆炸音效（被外部調用，例如撞擊核心時）"""
	_play_sound_with_random_pitch(explosion_sound)
	# 發送信號
	enemy_hit_core.emit()

func deflect_from_shield() -> void:
	"""被護盾反彈時調用"""
	# 計算從中心向外的方向
	var direction = global_position.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(randf() * TAU)
	
	# 設置反彈速度（加速 1.5 倍）
	velocity = direction * speed * 1.5
	has_bounced = true
	
	# 播放反彈音效
	_play_sound_with_random_pitch(bounce_sound)
	
	# 發送反彈信號
	enemy_bounced.emit(global_position)
	
	print("被護盾反彈！")

func _play_sound_with_random_pitch(audio_player: AudioStreamPlayer2D) -> void:
	"""播放音效，並隨機調整音高"""
	if audio_player:
		# 隨機音高 0.9 ~ 1.1
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

func _spawn_impact_effect(effect_position: Vector2) -> void:
	"""在指定位置生成碰撞特效"""
	var impact = impact_effect_scene.instantiate()
	impact.global_position = effect_position
	
	# 根據球的狀態設置特效顏色
	if is_perfect_parry:
		# 金色特效
		impact.color = Color(1.0, 0.9, 0.3, 1.0)
	elif is_friendly:
		# 青色特效
		impact.color = Color(0.3, 1.0, 0.9, 1.0)
	else:
		# 預設亮白黃色
		impact.color = Color(1.0, 1.0, 0.8, 1.0)
	
	# 添加到場景
	get_tree().current_scene.add_child(impact)

func die() -> void:
	"""敵人死亡，掉落 XP 寶石"""
	# 計算寶石數量：普通敵人1個，如果是完美格擋則額外+1個
	var gem_count = 1
	if is_perfect_parry:
		gem_count += 1  # 完美格擋額外獲得1個寶石
	
	# 生成寶石
	for i in range(gem_count):
		var gem_scene = preload("res://experience_gem.tscn")
		var gem = gem_scene.instantiate()
		
		# 如果有多個寶石，在敵人位置附近隨機散開
		if gem_count > 1:
			var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
			gem.global_position = global_position + offset
		else:
			gem.global_position = global_position
			
		get_tree().current_scene.add_child(gem)
	
	if is_perfect_parry:
		print("完美格擋！獲得 %d 個 XP 寶石" % gem_count)

func take_damage(amount: int) -> void:
	"""受到傷害"""
	print("敵人受到 %d 點傷害！" % amount)
	# 直接死亡（簡單實現）
	die()
	# 延遲刪除
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		queue_free()
