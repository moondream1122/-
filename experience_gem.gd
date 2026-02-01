extends Node2D

## XP 寶石 - 敵人死亡時掉落的經驗值寶石

@export var initial_speed: float = 100.0  # 初始噴出速度
@export var magnet_speed: float = 300.0   # 磁吸速度
@export var magnet_delay: float = 0.5     # 磁吸延遲時間

signal collected  # 收集時發送信號

var is_collected: bool = false
var velocity: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0
var player: Node2D = null

func _ready() -> void:
	# 添加到 xp_gem 組
	add_to_group("xp_gem")
	
	# 隨機初始方向噴出
	var angle = randf() * TAU
	velocity = Vector2(cos(angle), sin(angle)) * initial_speed
	
	# 查找 Player
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_node_or_null("/root/Main/Player")

func _physics_process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	
	# 旋轉動畫
	rotation += delta * 2.0
	
	if time_elapsed < magnet_delay:
		# 向外飄散階段
		position += velocity * delta
		# 逐漸減速
		velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
	else:
		# 磁吸階段
		if player:
			var direction = (player.global_position - global_position).normalized()
			position += direction * magnet_speed * delta
			
			# 檢查是否接近目標
			var distance = global_position.distance_to(player.global_position)
			if distance < 10.0:
				_collect()

func _collect() -> void:
	"""收集寶石"""
	if is_collected:
		return
	
	is_collected = true
	
	# 給予玩家經驗值
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("gain_xp"):
		level_manager.gain_xp(1)  # 每個寶石給 1 XP
	
	collected.emit()
	queue_free()