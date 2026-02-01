extends Node

## 技能管理器 - 管理玩家技能

signal skill_used(skill_name: String)
signal skill_ready(skill_name: String)
signal cooldown_updated(skill_name: String, remaining: float, total: float)

# 技能定義
var skills = {
	"slow_motion": {
		"name": "時間減緩",
		"key": KEY_1,
		"cooldown": 10.0,
		"duration": 3.0,
		"current_cooldown": 0.0,
		"ready": true
	},
	"shield": {
		"name": "護盾",
		"key": KEY_2,
		"cooldown": 15.0,
		"duration": 5.0,
		"current_cooldown": 0.0,
		"ready": true
	},
	"clear_screen": {
		"name": "清屏",
		"key": KEY_3,
		"cooldown": 20.0,
		"duration": 0.0,
		"current_cooldown": 0.0,
		"ready": true
	}
}

var slow_motion_active: bool = false
var shield_active: bool = false

func _ready() -> void:
	# 確保此節點在遊戲暫停時停止處理
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	# 更新所有技能的冷卻時間
	for skill_id in skills:
		var skill = skills[skill_id]
		if skill.current_cooldown > 0:
			skill.current_cooldown -= delta
			cooldown_updated.emit(skill_id, skill.current_cooldown, skill.cooldown)
			if skill.current_cooldown <= 0:
				skill.current_cooldown = 0
				skill.ready = true
				skill_ready.emit(skill_id)
				print("技能就緒: ", skill.name)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for skill_id in skills:
			if event.keycode == skills[skill_id].key:
				use_skill(skill_id)
				break

func use_skill(skill_id: String) -> bool:
	"""使用技能"""
	if not skills.has(skill_id):
		return false
	
	var skill = skills[skill_id]
	if not skill.ready:
		print("技能冷卻中: ", skill.name)
		return false
	
	# 標記技能進入冷卻
	skill.ready = false
	skill.current_cooldown = skill.cooldown
	
	# 執行技能效果
	match skill_id:
		"slow_motion":
			_activate_slow_motion(skill.duration)
		"shield":
			_activate_shield(skill.duration)
		"clear_screen":
			_activate_clear_screen()
	
	skill_used.emit(skill_id)
	print("使用技能: ", skill.name)
	return true

func _activate_slow_motion(duration: float) -> void:
	"""啟動時間減緩"""
	slow_motion_active = true
	Engine.time_scale = 0.3
	
	await get_tree().create_timer(duration * 0.3).timeout
	
	Engine.time_scale = 1.0
	slow_motion_active = false
	print("時間減緩結束")

func _activate_shield(duration: float) -> void:
	"""啟動護盾"""
	shield_active = true
	
	# 通知主場景啟動護盾
	var main = get_tree().current_scene
	if main and main.has_method("activate_shield"):
		main.activate_shield(duration)
	
	await get_tree().create_timer(duration).timeout
	
	shield_active = false
	print("護盾結束")

func _activate_clear_screen() -> void:
	"""清除所有敵人"""
	var enemies = get_tree().get_nodes_in_group("enemy")
	var score_manager = get_node_or_null("/root/ScoreManager")
	
	for enemy in enemies:
		# 每個敵人給予分數
		if score_manager:
			score_manager.add_score(50)
		enemy.queue_free()
	
	print("清屏！消滅 %d 個敵人" % enemies.size())

func is_skill_ready(skill_id: String) -> bool:
	"""檢查技能是否就緒"""
	if skills.has(skill_id):
		return skills[skill_id].ready
	return false

func get_cooldown_percent(skill_id: String) -> float:
	"""獲取技能冷卻百分比 (0.0 = 就緒, 1.0 = 剛使用)"""
	if skills.has(skill_id):
		var skill = skills[skill_id]
		if skill.cooldown > 0:
			return skill.current_cooldown / skill.cooldown
	return 0.0

func reset_all_skills() -> void:
	"""重置所有技能狀態"""
	for skill_id in skills:
		skills[skill_id].current_cooldown = 0.0
		skills[skill_id].ready = true
	
	slow_motion_active = false
	shield_active = false
	Engine.time_scale = 1.0
	print("所有技能已重置")
