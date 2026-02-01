extends CanvasLayer

## UpgradeScreen - 升級選擇介面

# 已選擇的天賦追蹤 (靜態變數，全局保持)
static var selected_upgrades_history = []

# 升級選項池
var upgrade_pool = {
	"巨人擋板": {
		"description": "擋板長度 x 1.5",
		"effect": "giant_paddle"
	},
	"衛星盾": {
		"description": "生成衛星小球自動防禦",
		"effect": "orbital_shield"
	},
	"生命恢復": {
		"description": "回復 1 點生命",
		"effect": "repair"
	},
	"量子穿透": {
		"description": "反彈攻擊有50%機率穿透敵人",
		"effect": "quantum_tunneling"
	},
	"連鎖閃電": {
		"description": "反彈敵人有30%機率向3個最近敵人發射閃電",
		"effect": "voltage_chain"
	},
	"爆炸接觸": {
		"description": "敵人撞到擋板時發生小範圍爆炸，推開周圍敵人",
		"effect": "explosive_touch"
	}
}

# 精英天賦池 (高等級解鎖)
var elite_upgrade_pool = {
	"影分身": {
		"description": "背後生成第二個擋板",
		"effect": "shadow_clone",
		"unlock_level": 5
	},
	"霓虹過載": {
		"description": "擋板變色，反彈力道翻倍",
		"effect": "neon_overload",
		"unlock_level": 7
	}
}

# 升級按鈕節點
@onready var upgrade_buttons = [
	$PanelContainer/HBoxContainer/UpgradeButton1,
	$PanelContainer/HBoxContainer/UpgradeButton2,
	$PanelContainer/HBoxContainer/UpgradeButton3
]

# 防止多重觸發（例如重複連接匿名函式時）
var selection_locked: bool = false

func _ready() -> void:
	# 確保在遊戲暫停時仍然可以處理輸入
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 按鈕信號在show_upgrade_screen()中連接，確保按鈕已準備好
	pass

func show_upgrade_screen() -> void:
	"""顯示升級介面"""
	visible = true
	print("[DEBUG] UpgradeScreen.show_upgrade_screen() called. visible=", visible)
	
	# 獲取當前等級
	var current_level = 1
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		current_level = level_manager.get_current_level()
	
	# 隨機選擇升級選項
	var selected_upgrades = _get_random_upgrades(current_level)
	
	# 設置按鈕索引並確保使用單一處理器（避免匿名 closure 重複連接）
	selection_locked = false
	for i in range(upgrade_buttons.size()):
		var button = upgrade_buttons[i]
		button.set_meta("upgrade_index", i)
		# 先嘗試斷開舊連線（如果存在）
		var callable_ref = Callable(self, "_on_upgrade_button_pressed")
		if button.pressed.is_connected(callable_ref):
			button.pressed.disconnect(callable_ref)
		# 使用 bind 傳入 index 參數，避免使用第三個 Array 參數導致類型錯誤
		button.pressed.connect(_on_upgrade_button_pressed.bind(i))
		print("[DEBUG] UpgradeScreen: button %d connected" % i)
	
	# 設置按鈕文字
	for i in range(selected_upgrades.size()):
		var upgrade_name = selected_upgrades[i]
		var upgrade_data = _get_upgrade_data(upgrade_name)
		upgrade_buttons[i].text = upgrade_name + "\n" + upgrade_data["description"]
		# 存儲效果 ID 和升級名稱
		upgrade_buttons[i].set_meta("effect", upgrade_data["effect"])
		upgrade_buttons[i].set_meta("upgrade_name", upgrade_name)
		
		# 根據天賦類型設定顏色：普通天賦藍色，精英天賦紫色
		if elite_upgrade_pool.has(upgrade_name):
			upgrade_buttons[i].add_theme_color_override("font_color", Color(0.8, 0.2, 1.0))  # 紫色
		else:
			upgrade_buttons[i].add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))  # 藍色

func _get_random_upgrades(current_level: int) -> Array:
	"""從池中隨機選擇不重複的升級"""
	var available_upgrades = []
	
	# 添加普通升級（排除已經選擇過的，生命恢復、衛星盾和巨人擋板除外）
	for upgrade_name in upgrade_pool.keys():
		if not selected_upgrades_history.has(upgrade_name) or upgrade_name in ["生命恢復", "衛星盾", "巨人擋板"]:
			available_upgrades.append(upgrade_name)
	
	# 添加已解鎖的精英升級（排除已經選擇過的，衛星盾除外）
	for elite_name in elite_upgrade_pool.keys():
		var elite_data = elite_upgrade_pool[elite_name]
		if current_level >= elite_data["unlock_level"] and (not selected_upgrades_history.has(elite_name) or elite_name == "衛星盾"):
			available_upgrades.append(elite_name)
	
	# 如果沒有足夠的升級，添加一些基本升級作為後備
	if available_upgrades.size() < 3:
		var fallback_upgrades = ["repair", "fast_spin"]  # 始終可用的基本升級
		for fallback in fallback_upgrades:
			if not available_upgrades.has(fallback) and not selected_upgrades_history.has(fallback):
				available_upgrades.append(fallback)
	
	# 隨機打亂並選擇3個
	available_upgrades.shuffle()
	return available_upgrades.slice(0, min(3, available_upgrades.size()))

func _get_upgrade_data(upgrade_name: String) -> Dictionary:
	"""獲取升級數據"""
	if upgrade_pool.has(upgrade_name):
		return upgrade_pool[upgrade_name]
	elif elite_upgrade_pool.has(upgrade_name):
		return elite_upgrade_pool[upgrade_name]
	
	# 返回默認數據
	return {"description": "未知升級", "effect": "unknown"}

func _on_upgrade_selected(button_index: int) -> void:
	"""升級選中時的處理"""
	# 防止重複處理同一次顯示的多次信號
	if selection_locked:
		return
	selection_locked = true

	var button = upgrade_buttons[button_index]
	var effect = button.get_meta("effect")
	var upgrade_name = button.get_meta("upgrade_name")
	print("[DEBUG] _on_upgrade_selected() index=%d name=%s" % [button_index, str(upgrade_name)])
	
	# 應用升級效果
	_apply_upgrade_effect(effect)
	
	# 添加到已選擇升級歷史記錄（生命恢復和衛星盾除外）
	if upgrade_name != "生命恢復" and upgrade_name != "衛星盾":
		selected_upgrades_history.append(upgrade_name)
	
	# 隱藏介面並恢復遊戲
	print("[DEBUG] UpgradeScreen._on_upgrade_selected() hiding screen. index=", button_index)
	visible = false
	get_tree().paused = false

func _on_upgrade_button_pressed(idx: int) -> void:
	"""安全的按鈕處理器，接收傳入的按鈕索引並轉發到 `_on_upgrade_selected`"""
	_on_upgrade_selected(idx)

func _apply_upgrade_effect(effect: String) -> void:
	"""應用升級效果"""
	var main = get_tree().current_scene
	if not main:
		return
	
	match effect:
		"giant_paddle":
			# 擋板長度 x 1.5
			if main.has_method("upgrade_paddle_size"):
				main.upgrade_paddle_size(1.5)
		"fast_spin":
			# 旋轉速度 + 30%
			if main.has_method("upgrade_spin_speed"):
				main.upgrade_spin_speed(1.3)
		"repair":
			# 回復 1 點生命
			if main.has_method("heal_player"):
				main.heal_player(1)
		"orbital_shield":
			# 衛星盾
			if main.has_method("orbital_shield"):
				main.orbital_shield()
		"shadow_clone":
			# 影分身
			if main.has_method("shadow_clone"):
				main.shadow_clone()
		"neon_overload":
			# 霓虹過載
			if main.has_method("neon_overload"):
				main.neon_overload()
		"quantum_tunneling":
			# 量子穿透
			if main.has_method("quantum_tunneling"):
				main.quantum_tunneling()
		"voltage_chain":
			# 連鎖閃電
			if main.has_method("voltage_chain"):
				main.voltage_chain()
		"explosive_touch":
			# 爆炸接觸
			if main.has_method("explosive_touch"):
				main.explosive_touch()
		_:
			print("未知升級效果: ", effect)

func reset_upgrade_history() -> void:
	"""重置升級歷史記錄"""
	selected_upgrades_history.clear()
	print("[DEBUG] Upgrade history reset")
