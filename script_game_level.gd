# script_game_level.gd
extends Control

# Ссылки на контейнеры с уровнями
var level_containers = []
var back_button
var selected_level: int = 0

# Префаб кнопки уровня
var level_button_scene = preload("res://UI/LevelButton.tscn")

func _ready():
	print("=== LEVEL SELECTION INITIALIZATION ===")
	
	# Ждем инициализации Global
	await get_tree().process_frame
	
	# Находим все необходимые узлы
	find_all_nodes()
	
	# Создаем кнопки уровней
	create_level_buttons()
	
	# Принудительно вызываем обновление размера
	await get_tree().process_frame
	update_layout()

func find_all_nodes():
	# Находим ВСЕ контейнеры с уровнями автоматически
	find_level_containers()
	
	# Находим кнопку назад
	back_button = find_node_by_path("CenterContainer4/HBoxContainer/VBoxContainer/back_butt")
	if not back_button:
		back_button = find_child("back_butt", true, false)
	
	# Подключаем кнопку назад
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		print("✅ Кнопка назад найдена: ", back_button.name)
	else:
		print("❌ Кнопка назад не найдена!")
		create_fallback_back_button()
	
	print("Найдено контейнеров для уровней: ", level_containers.size())

func find_level_containers():
	# Ищем все контейнеры, которые могут содержать кнопки уровней
	var possible_containers = [
		"CenterContainer/VBoxContainer/HBoxContainer",
		"CenterContainer2/VBoxContainer/HBoxContainer", 
        "CenterContainer3/VBoxContainer/HBoxContainer"
	]
	
	for path in possible_containers:
		var container = find_node_by_path(path)
		if container and container not in level_containers:
			level_containers.append(container)
			print("✅ Найден контейнер: ", path)

func create_fallback_back_button():
	var fallback_button = Button.new()
	fallback_button.text = "Назад (временная)"
	fallback_button.size = Vector2(100, 50)
	fallback_button.position = Vector2(20, 20)
	fallback_button.pressed.connect(_on_back_button_pressed)
	add_child(fallback_button)
	back_button = fallback_button
	print("Создана временная кнопка назад")

func update_layout():
	# Принудительно обновляем размеры контейнеров
	for container in level_containers:
		if container:
			container.queue_sort()
			container.queue_redraw()

func find_node_by_path(path: String):
	var node = self
	var parts = path.split("/")
	
	for part in parts:
		node = node.get_node_or_null(part)
		if not node:
			return null
	
	return node

func create_level_buttons():
	# Очищаем существующие кнопки
	clear_existing_buttons()
	
	# Создаем кнопки для 15 уровней и распределяем по контейнерам
	for level in range(1, 16):
		var level_button = level_button_scene.instantiate()
		level_button.set_level_number(level)
		
		# Подключаем сигнал через метод который не удаляет кнопку сразу
		level_button.pressed.connect(_on_level_button_pressed.bind(level))
		
		# Передаем данные уровня
		if Global:
			var level_data = Global.get_level_data(level)
			if not level_data.is_empty():
				level_button.set_level_data(level_data)
				print("✅ Передали данные уровня ", level, " в кнопку: unlocked=", level_data["unlocked"])
		
		# Определяем в какой контейнер добавить (по порядку)
		var container_index = floor((level - 1) / 5.0)
		if container_index < level_containers.size():
			level_containers[container_index].add_child(level_button)
			print("Добавлен уровень ", level, " в контейнер ", container_index + 1)
		else:
			print("❌ Не удалось добавить уровень ", level, " - нет подходящего контейнера")
	
	# Обновляем внешний вид кнопок
	update_level_buttons()

func clear_existing_buttons():
	# Очищаем кнопки во всех контейнерах
	for container in level_containers:
		if container:
			for child in container.get_children():
				if child is Button or child.has_method("set_level_number"):
					child.queue_free()

func update_level_buttons():
	# Обновляем внешний вид всех кнопок уровней
	for container in level_containers:
		if container:
			for child in container.get_children():
				if child.has_method("update_appearance"):
					child.update_appearance()

func _on_level_button_pressed(level_number: int):
	print("🎯 === LEVEL SELECTION: КНОПКА УРОВНЯ ", level_number, " НАЖАТА ===")
	
	# Сохраняем выбранный уровень
	selected_level = level_number
	
	# Используем таймер для безопасной смены сцены
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(_load_selected_level)
	timer.one_shot = true
	timer.start(0.1)  # Короткая задержка

func _load_selected_level():
	print("🔄 Загружаем уровень ", selected_level)
	
	if Global:
		Global.current_level = selected_level
		print("✅ Уровень сохранен в Global: ", Global.current_level)
	
	var tree = get_tree()
	if tree == null:
		print("❌ get_tree() is null!")
		return
	
	var level_path = "res://DroneLevels/Levels/Level%d.tscn" % selected_level
	if FileAccess.file_exists(level_path):
		print("   Загружаем сцену: ", level_path)
		var error = tree.change_scene_to_file(level_path)
		if error != OK:
			print("❌ Ошибка загрузки сцены: ", error)
	else:
		# Если уровня нет, загружаем базовую сцену дрона
		print("❌ Сцена уровня не найдена: ", level_path)
		print("   Загружаем базовую сцену дрона...")
		var error = tree.change_scene_to_file("res://DroneLevels/DroneScene.tscn")
		if error != OK:
			print("❌ Ошибка загрузки базовой сцены: ", error)

func _on_back_button_pressed():
	print("Нажата кнопка назад")
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://main_scene.tscn")

func show_locked_message():
	print("Уровень заблокирован! Сначала завершите предыдущие уровни.")
