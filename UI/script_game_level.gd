extends Control

var level_containers = []
var back_button
var selected_level: int = 0
var level_button_scene = preload("res://UI/LevelButton.tscn")

func _ready():
	print("=== LEVEL SELECTION ===")
	await get_tree().process_frame
	find_nodes()
	create_level_buttons()
	update_layout()

func find_nodes():
	# Ищем контейнеры уровней
	var container_paths = [
		"CenterContainer/VBoxContainer/HBoxContainer",
		"CenterContainer2/VBoxContainer/HBoxContainer", 
		"CenterContainer3/VBoxContainer/HBoxContainer"
	]
	
	for path in container_paths:
		var container = get_node_or_null(path)
		if container:
			level_containers.append(container)
			print("✅ Контейнер: ", path)
	
	# ИСПРАВЛЕН ПУТЬ К КНОПКЕ НАЗАД
	back_button = get_node_or_null("HBoxContainer/VBoxContainer/back_butt")
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("✅ Кнопка назад найдена в сцене")
	else:
		print("❌ Кнопка назад не найдена по пути: HBoxContainer/VBoxContainer/back_butt")
		# Попробуем найти кнопку другим способом
		find_back_button_alternative()

func find_back_button_alternative():
	# Пробуем найти кнопку по имени
	back_button = find_child("back_butt", true, false)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("✅ Кнопка назад найдена альтернативным способом")
	else:
		print("❌ Кнопка назад не найдена вообще! Создаем временную")
		create_fallback_back_button()

func create_fallback_back_button():
	back_button = Button.new()
	back_button.text = "НАЗАД"
	back_button.custom_minimum_size = Vector2(100, 50)
	back_button.position = Vector2(20, 20)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)
	print("✅ Создана временная кнопка назад")

func create_level_buttons():
	for container in level_containers:
		for child in container.get_children():
			if child is Button or child.has_method("set_level_number"):
				child.queue_free()
	
	for level in range(1, 16):
		var button = level_button_scene.instantiate()
		button.set_level_number(level)
		button.pressed.connect(_on_level_pressed.bind(level))
		
		if Global:
			var level_data = Global.get_level_data(level)
			button.set_level_data(level_data)
		
		var container_index = floor((level - 1) / 5.0)
		if container_index < level_containers.size():
			level_containers[container_index].add_child(button)

func update_layout():
	for container in level_containers:
		if container:
			container.queue_redraw()

func _on_level_pressed(level_number: int):
	print("🎯 Выбран уровень: ", level_number)
	selected_level = level_number
	
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_load_level)
	timer.one_shot = true
	timer.start(0.1)

func _load_level():
	if Global:
		Global.current_level = selected_level
	
	var level_path = "res://DroneLevels/Levels/Level%d.tscn" % selected_level
	if not FileAccess.file_exists(level_path):
		level_path = "res://DroneLevels/DroneScene.tscn"
	
	# Для игровых уровней используем экран загрузки
	Global.load_scene_with_loading(level_path)

func _on_back_pressed():
	# Возврат в главное меню БЕЗ экрана загрузки
	print("🔙 Назад в меню")
	get_tree().change_scene_to_file("res://main_scene.tscn")
