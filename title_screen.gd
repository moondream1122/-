extends Control

## 標題畫面腳本

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var difficulty_label: Label = $CenterContainer/VBoxContainer/DifficultyContainer/DifficultyLabel
@onready var left_button: Button = $CenterContainer/VBoxContainer/DifficultyContainer/LeftButton
@onready var right_button: Button = $CenterContainer/VBoxContainer/DifficultyContainer/RightButton
@onready var mode_label: Label = $CenterContainer/VBoxContainer/ModeContainer/ModeLabel
@onready var mode_left_button: Button = $CenterContainer/VBoxContainer/ModeContainer/ModeLeftButton
@onready var mode_right_button: Button = $CenterContainer/VBoxContainer/ModeContainer/ModeRightButton

var difficulty_names = ["簡單", "普通", "困難", "瘋狂"]
var current_difficulty: int = 1  # 默認普通

var mode_names = ["故事模式", "無盡模式"]
var current_mode: int = 0  # 默認故事模式

func _ready() -> void:
	# 從 DifficultyManager 讀取當前難度
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		current_difficulty = difficulty_manager.current_difficulty
	
	# 連接按鈕信號
	play_button.pressed.connect(_on_play_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	mode_left_button.pressed.connect(_on_mode_left_button_pressed)
	mode_right_button.pressed.connect(_on_mode_right_button_pressed)
	
	# 初始化難度和模式顯示
	_update_difficulty_display()
	_update_mode_display()

func _on_play_button_pressed() -> void:
	# 設置難度
	var difficulty_manager = get_node_or_null("/root/DifficultyManager")
	if difficulty_manager:
		difficulty_manager.set_difficulty(current_difficulty)
	
	# 設置遊戲模式
	var game_mode_manager = get_node_or_null("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.set_game_mode(current_mode)
	
	# 切換到主遊戲場景
	get_tree().change_scene_to_file("res://main.tscn")

func _on_left_button_pressed() -> void:
	current_difficulty = max(0, current_difficulty - 1)
	_update_difficulty_display()

func _on_right_button_pressed() -> void:
	current_difficulty = min(3, current_difficulty + 1)
	_update_difficulty_display()

func _update_difficulty_display() -> void:
	difficulty_label.text = difficulty_names[current_difficulty]
	
	# 根據難度變換顏色
	match current_difficulty:
		0:  # 簡單
			difficulty_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		1:  # 普通
			difficulty_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.2))
		2:  # 困難
			difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		3:  # 瘋狂
			difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _on_mode_left_button_pressed() -> void:
	current_mode = max(0, current_mode - 1)
	_update_mode_display()

func _on_mode_right_button_pressed() -> void:
	current_mode = min(1, current_mode + 1)
	_update_mode_display()

func _update_mode_display() -> void:
	mode_label.text = mode_names[current_mode]
	
	# 根據模式變換顏色
	match current_mode:
		0:  # 故事模式
			mode_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		1:  # 無盡模式
			mode_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
