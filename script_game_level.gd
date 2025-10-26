extends Control

func _ready():
	$HBoxContainer/VBoxContainer/back_butt.pressed.connect(_back_pressed)
	$CenterContainer2/VBoxContainer/HBoxContainer/Level1.pressed.connect(_on_level_button_pressed.bind(1))

func _back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")

func _on_level_button_pressed(level_number: int):
	# Сохраняем номер уровня в глобальную переменную или синглтон
	Global.current_level = level_number
	# Переходим в сцену с дроном
	get_tree().change_scene_to_file("DroneLevels/DroneScene.tscn")
