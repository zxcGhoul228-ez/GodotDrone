extends Control

@export var audio_player: AudioStreamPlayer
@export var score_label: Label  # Перетащите ноду в инспекторе

func _ready():
	# Подключаем сигналы кнопок
	$HBoxContainer/VBoxContainer/GameButt.pressed.connect(_on_start_pressed)
	$HBoxContainer/VBoxContainer/InvButt.pressed.connect(_on_CreateDron_pressed)
	$HBoxContainer/VBoxContainer/ShopButt.pressed.connect(_on_shop_pressed)
	
	if score_label:
		update_score_display()
	else:
		print("Перетащите Label в инспектор!")
	
	# Воспроизводим музыку
	audio_player.play()

func update_score_display():
	score_label.text = "Счет: " + str(Global.score)

func _on_button_pressed():
	Global.score += 10
	update_score_display()

func _on_start_pressed():
	# Загрузка игровой сцены БЕЗ экрана загрузки
	print("🎮 Переход к выбору уровней")
	get_tree().change_scene_to_file("res://UI/game_level.tscn")

func _on_shop_pressed():
	# Загрузка сцены магазина БЕЗ экрана загрузки
	print("🛒 Переход в магазин")
	get_tree().change_scene_to_file("res://shop/shop.tscn")

func _on_CreateDron_pressed():
	# Загрузка сцены создания дрона С экраном загрузки
	print("🔧 Переход к созданию дрона")
	Global.load_scene_with_loading("res://create_drone/create_dron.tscn")

func _on_exit_pressed():
	get_tree().quit()
