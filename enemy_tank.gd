extends "res://enemy.gd"

## 鐵甲巨獸 (The Armored Hexagon) - 多血量坦克敵人

# 坦克專屬屬性
@export var max_hp: int = 3
var current_hp: int = 3

# 階段變化參數
@export var speed_increase_per_hit: float = 0.2  # 每次受傷速度增加 20%
@export var scale_decrease_per_hit: float = 0.2  # 每次受傷體型縮小 20%

# 顏色階段（藍 → 黃 → 紅）
var hp_colors: Array[Color] = [
	Color(1.0, 0.2, 0.2, 1.0),  # HP=1: 紅色（危險）
	Color(1.0, 0.8, 0.2, 1.0),  # HP=2: 黃色（受傷）
	Color(0.2, 0.8, 1.0, 1.0),  # HP=3: 藍色（滿血）
]

# 獲取六邊形節點
@onready var hexagon: Polygon2D = $Hexagon
@onready var shield_particles: CPUParticles2D = $ShieldParticles
@onready var metal_sound: AudioStreamPlayer2D = $MetalSound

var original_scale: Vector2
var base_speed: float

func _ready() -> void:
	super._ready()
	
	# 初始化坦克屬性
	current_hp = max_hp
	original_scale = scale
	base_speed = speed
	
	# 坦克移動較慢
	speed *= 0.5
	velocity = velocity.normalized() * speed
	
	# 更新外觀
	_update_visual_state()

func _handle_collision(collision: KinematicCollision2D) -> void:
	"""覆寫碰撞處理 - 坦克有多條命，且會反擊玩家"""
	var collider = collision.get_collider()
	
	# 檢查是否碰撞到 Paddle
	if collider and collider.name == "Paddle":
		# 如果在冷卻中，忽略此次碰撞
		if bounce_cooldown > 0:
			return
		
		# 設置冷卻時間
		bounce_cooldown = 0.2
		
		# 檢查是否為精準格擋
		var is_perfect_parry_now = false
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			player = get_node_or_null("/root/Main/Player")
		if player and player.has_method("is_parrying") and player.is_parrying():
			is_perfect_parry_now = true
		
		# 如果是精準格擋，設置標記
		if is_perfect_parry_now:
			is_perfect_parry = true
		
		# 被反彈後掉落 XP 寶石
		die()
		
		# 生成碰撞特效
		_spawn_impact_effect(collision.get_position())
		
		# 先正常反彈出去
		velocity = velocity.bounce(collision.get_normal())
		
		# 受傷！
		_take_tank_damage(collision.get_position())
		
		# 如果還活著，延遲後重新瞄準玩家攻擊！
		if current_hp > 0:
			_delayed_retarget()
		
		# 發送反彈信號
		enemy_bounced.emit(collision.get_position())
	else:
		# 碰到其他物體，直接反彈（也加冷卻）
		if bounce_cooldown > 0:
			return
		bounce_cooldown = 0.1
		velocity = velocity.bounce(collision.get_normal())

func _delayed_retarget() -> void:
	"""延遲一段時間後重新瞄準玩家"""
	# 先讓坦克飛出一段距離（等待 0.8 秒）
	await get_tree().create_timer(0.8).timeout
	
	# 確保坦克還存在
	if not is_instance_valid(self):
		return
	
	# 重新瞄準玩家
	_retarget_player()

func _retarget_player() -> void:
	"""重新瞄準玩家進行攻擊"""
	# 獲取玩家位置
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_node_or_null("/root/Main/Player")
	
	if player:
		# 計算朝向玩家擋板的方向
		var paddle = player.get_node_or_null("Paddle")
		var target_pos = paddle.global_position if paddle else player.global_position
		var direction = (target_pos - global_position).normalized()
		
		# 計算當前速度大小
		var current_speed = velocity.length()
		
		# 設置新的速度方向（朝向玩家）
		velocity = direction * current_speed
		
		# 坦克不是友方！它在反擊！
		is_friendly = false
		has_bounced = false  # 重置狀態，讓它可以再次被反彈
		
		print("⚠ 鐵甲巨獸反擊！瞄準玩家！")

func _take_tank_damage(hit_position: Vector2) -> void:
	"""坦克受傷處理"""
	current_hp -= 1
	
	# 播放金屬撞擊聲
	_play_metal_hit_sound()
	
	# 閃白效果
	_flash_white()
	
	# 相機震動（比普通敵人更強）
	var main = get_tree().current_scene
	if main and main.camera:
		main.camera.apply_shake(30.0, 0.35)
	
	# Hit Stop 效果
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.08, 0.05)
	
	# 給予分數
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(50)  # 每次打擊給分
	
	print("鐵甲巨獸受傷！剩餘 HP: %d" % current_hp)
	
	if current_hp <= 0:
		# 死亡！
		_tank_death(hit_position)
	else:
		# 階段變化
		_phase_change()

func _phase_change() -> void:
	"""階段變化：速度加快、體型縮小、顏色變紅"""
	# 速度增加
	var speed_multiplier = 1.0 + speed_increase_per_hit * (max_hp - current_hp)
	velocity = velocity.normalized() * base_speed * 0.5 * speed_multiplier
	
	# 體型縮小
	var scale_multiplier = 1.0 - scale_decrease_per_hit * (max_hp - current_hp)
	scale = original_scale * scale_multiplier
	
	# 更新視覺
	_update_visual_state()
	
	print("階段變化！速度倍率: %.1f, 體型倍率: %.1f" % [speed_multiplier, scale_multiplier])

func _update_visual_state() -> void:
	"""根據當前 HP 更新外觀"""
	var color_index = clamp(current_hp - 1, 0, hp_colors.size() - 1)
	var target_color = hp_colors[color_index]
	
	if hexagon:
		hexagon.color = target_color
	
	# 更新護盾粒子顏色
	if shield_particles:
		shield_particles.color = target_color
		shield_particles.color.a = 0.5

func _flash_white() -> void:
	"""閃白效果"""
	if hexagon:
		var original_color = hexagon.color
		hexagon.color = Color.WHITE
		
		# 創建 Tween 恢復顏色
		var tween = create_tween()
		tween.tween_property(hexagon, "color", original_color, 0.15)

func _play_metal_hit_sound() -> void:
	"""播放金屬撞擊聲"""
	if metal_sound:
		# 隨著 HP 降低，音高升高
		metal_sound.pitch_scale = 0.8 + (max_hp - current_hp) * 0.15
		metal_sound.play()
	else:
		# 如果沒有專用音效，使用反彈音效
		if bounce_sound:
			bounce_sound.pitch_scale = 0.6 + randf_range(-0.05, 0.05)
			bounce_sound.play()

func _tank_death(death_position: Vector2) -> void:
	"""坦克死亡 - 大爆炸！"""
	print("★ 鐵甲巨獸被擊敗！")
	
	# 額外分數獎勵
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(200)  # 擊敗獎勵
	
	# 掉落 XP 寶石
	die()
	
	# 強烈相機震動
	var main = get_tree().current_scene
	if main and main.camera:
		main.camera.apply_shake(50.0, 0.5)
	
	# 播放爆炸音效
	if explosion_sound:
		explosion_sound.pitch_scale = 0.7  # 低沉的爆炸聲
		explosion_sound.play()
	
	# 生成多個碰撞特效
	for i in range(5):
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		call_deferred("_spawn_death_effect", death_position + offset)
	
	# 延遲刪除（等音效播放）
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _spawn_death_effect(pos: Vector2) -> void:
	"""生成死亡特效"""
	if impact_effect_scene:
		var effect = impact_effect_scene.instantiate()
		effect.global_position = pos
		effect.color = Color(1.0, 0.5, 0.2, 1.0)  # 橙色爆炸
		effect.amount = 32  # 更多粒子
		get_tree().current_scene.add_child(effect)

# 覆寫友方碰撞處理
func _friendly_enemy_collision(enemy: Node2D) -> void:
	"""坦克撞擊敵人"""
	# 坦克不會因為撞到敵人而受傷
	# 但會擊殺被撞的敵人
	var collision_point = (global_position + enemy.global_position) / 2.0
	
	# 增加連殺計數
	kill_combo += 1
	
	# 計算連殺分數
	var combo_score = 100 * int(pow(2, kill_combo - 1))
	combo_score = min(combo_score, 3200)
	
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.add_score(combo_score)
	
	# 顯示 Combo 文字
	var main = get_tree().current_scene
	if main and main.has_method("show_combo_text"):
		main.show_combo_text(collision_point, kill_combo, combo_score)
	
	# 生成碰撞特效
	_spawn_impact_effect(collision_point)
	
	# 相機震動
	if main and main.camera:
		main.camera.apply_shake(15.0, 0.2)
	
	# 播放金屬撞擊聲
	_play_metal_hit_sound()
	
	print("★ 鐵甲巨獸碾壓敵人！Combo x%d" % kill_combo)
	
	# 刪除被撞的敵人
	enemy.queue_free()

func die() -> void:
	"""覆寫死亡方法 - 坦克敵人掉落 XP 寶石"""
	# 坦克敵人基礎掉落 2 個 XP 寶石，如果是完美格擋則額外+1個
	var base_gem_count = 2
	var extra_gem_count = 1 if is_perfect_parry else 0
	var total_gem_count = base_gem_count + extra_gem_count
	
	# 生成寶石
	for i in range(total_gem_count):
		var gem_scene = preload("res://experience_gem.tscn")
		var gem = gem_scene.instantiate()
		
		# 在敵人位置附近隨機散開
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		gem.global_position = global_position + offset
		get_tree().current_scene.add_child(gem)
	
	if is_perfect_parry:
		print("完美格擋坦克敵人！獲得 %d 個 XP 寶石" % total_gem_count)
