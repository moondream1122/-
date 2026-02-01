extends Line2D

## Trail 拖尾效果腳本 - 使用 Line2D 實現（頭寬尾尖）

@export var max_points: int = 15  # 最大點數量
@export var trail_width: float = 16.0  # 拖尾寬度

var target: Node2D  # 跟隨的目標節點

func _ready() -> void:
	# 獲取父節點作為跟隨目標
	target = get_parent()
	
	# 設置 Line2D 屬性
	width = trail_width
	
	# 設置漸變色（末端透明）- 霓虹綠色
	var color_gradient = Gradient.new()
	color_gradient.set_offset(0, 0.0)
	color_gradient.set_offset(1, 1.0)
	color_gradient.set_color(0, Color(0.2, 1.0, 0.4, 0))  # 尾端透明霓虹綠
	color_gradient.set_color(1, Color(0.2, 1.0, 0.4, 0.8))  # 頭部霓虹綠
	self.gradient = color_gradient
	
	# 設置寬度曲線（頭寬尾尖）
	var width_curve_res = Curve.new()
	width_curve_res.add_point(Vector2(0, 0))    # 尾端很細
	width_curve_res.add_point(Vector2(0.3, 0.5))  # 中間漸寬
	width_curve_res.add_point(Vector2(1, 1))    # 頭部最寬
	self.width_curve = width_curve_res
	
	# 設置為全局坐標（不跟隨父節點旋轉）
	top_level = true

func _physics_process(_delta: float) -> void:
	if target == null:
		return
	
	# 將目標的全局位置加入到點列表開頭
	add_point(target.global_position, 0)
	
	# 如果點數超過最大值，移除最後一個點
	while get_point_count() > max_points:
		remove_point(get_point_count() - 1)
