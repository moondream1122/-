extends Node2D

## Player 節點 - 讓擋板始終朝向滑鼠位置

@export var paddle_distance: float = 75.0  # 擋板距離中心的距離
@export var parry_threshold: float = 0.1  # 旋轉閾值（弧度）- 桌面
@export var mobile_parry_threshold: float = 0.2  # 移動設備旋轉閾值（弧度）
@export var parry_window: int = 200  # 精準格擋窗口（毫秒）

var last_move_time: float = 0.0  # 上次移動的時間
var last_rotation: float = 0.0  # 上一幀的旋轉角度
var touch_position: Vector2 = Vector2.ZERO  # 觸摸位置
var is_mobile: bool = false  # 是否為移動設備

func _ready() -> void:
	add_to_group("player")
	
	# 檢測是否為移動設備
	var os_name = OS.get_name()
	is_mobile = os_name in ["Android", "iOS"] or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	
	# 在網頁環境中，額外檢查觸摸能力
	if OS.has_feature("web"):
		is_mobile = is_mobile or DisplayServer.is_touchscreen_available()
	
	if is_mobile:
		print("檢測到移動設備，啟用觸摸控制 (OS: ", os_name, ")")

func _process(_delta: float) -> void:
	var target_pos: Vector2
	
	if is_mobile:
		# 移動設備：使用觸摸位置
		if touch_position != Vector2.ZERO:
			target_pos = touch_position
		else:
			# 如果沒有觸摸，使用螢幕中心作為默認
			target_pos = get_viewport_rect().size / 2
	else:
		# 桌面設備：使用滑鼠位置
		target_pos = get_global_mouse_position()
	
	var current_rotation = (target_pos - global_position).angle()
	
	# 檢測旋轉角度變化（使用適合的閾值）
	var threshold = mobile_parry_threshold if is_mobile else parry_threshold
	var rotation_diff = abs(angle_difference(last_rotation, current_rotation))
	if rotation_diff > threshold:
		last_move_time = Time.get_ticks_msec()
	
	last_rotation = current_rotation
	look_at(target_pos)

func _input(event: InputEvent) -> void:
	if not is_mobile:
		return
		
	# 處理觸摸事件
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_position = event.position
		else:
			# 觸摸釋放時，重置到螢幕中心
			touch_position = get_viewport_rect().size / 2
			
	# 處理觸摸拖拽
	elif event is InputEventScreenDrag:
		touch_position = event.position

func is_parrying() -> bool:
	"""檢查是否在精準格擋窗口內"""
	return (Time.get_ticks_msec() - last_move_time) < parry_window

func reset() -> void:
	"""重置玩家狀態"""
	last_move_time = 0.0
	last_rotation = 0.0
