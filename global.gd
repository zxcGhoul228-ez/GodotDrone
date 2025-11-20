# Global.gd
extends Node

# Игровые данные
var purchased_items = ["Рама1", "Плата1", "Мотор1", "Пропеллер1"]
var score = 100
static var drone_data = {}
var current_level: int = 1
var levels_unlocked: int = 1
var levels_data: Dictionary = {}

# Система загрузки
var loading_screen: Control = null

func _ready():
	print("=== GLOBAL INIT ===")
	load_levels_data()
	print("Уровней разблокировано: ", levels_unlocked)

# ФУНКЦИЯ ЗАГРУЗКИ ДЛЯ ИГРОВЫХ УРОВНЕЙ И СОЗДАНИЯ ДРОНА
func load_scene_with_loading(scene_path: String):
	print("🌐 Начинаем загрузку: ", scene_path)
	
	# Показываем экран загрузки
	var screen = show_loading_screen()
	
	# Ждем один кадр чтобы экран показался
	await get_tree().process_frame
	
	# Медленная имитация прогресса
	await slow_progress_simulation(scene_path, screen)

func slow_progress_simulation(scene_path: String, screen: Control):
	var progress = 0.0
	
	# Медленно проходим прогресс до 80%
	while progress < 0.8:
		progress += 0.04
		screen.set_progress(progress)
		await get_tree().create_timer(0.15).timeout
	
	# Переходим к быстрой загрузке
	screen.set_progress(0.9)
	screen.update_loading_text("Завершение...")
	
	# Короткая пауза перед загрузкой
	await get_tree().create_timer(0.5).timeout
	
	# Загружаем сцену
	_direct_scene_load(scene_path)

func show_loading_screen() -> Control:
	if not loading_screen:
		var loading_scene = preload("res://UI/LoadingScreen.tscn")
		loading_screen = loading_scene.instantiate()
		get_tree().root.add_child(loading_screen)
		loading_screen.start_loading()
	return loading_screen

func hide_loading_screen():
	if loading_screen:
		loading_screen.queue_free()
		loading_screen = null

func _direct_scene_load(scene_path: String):
	print("🔄 Прямая загрузка сцены...")
	
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		print("❌ Файл не найден: ", scene_path)
		get_tree().change_scene_to_file("res://DroneLevels/DroneScene.tscn")
	
	hide_loading_screen()

# Остальные функции без изменений...
func is_component_available(component_type: String, component_name: String) -> bool:
	if component_name.begins_with("Буст"):
		return true
	return component_name in purchased_items

func get_available_components(component_names: Array) -> Array:
	var available = []
	for name in component_names:
		if is_component_available("", name):
			available.append(name)
	return available

func initialize_levels_data():
	levels_data = {}
	for i in range(1, 16):
		levels_data[str(i)] = {
			"unlocked": i == 1,
			"completed": false,
			"best_steps": 0,
			"stars": 0
		}

func complete_level(level_number: int, steps: int, stars: int):
	var level_key = str(level_number)
	if level_key in levels_data:
		levels_data[level_key]["completed"] = true
		if steps < levels_data[level_key]["best_steps"] or levels_data[level_key]["best_steps"] == 0:
			levels_data[level_key]["best_steps"] = steps
		levels_data[level_key]["stars"] = stars
		
		if level_number < 15:
			var next_key = str(level_number + 1)
			levels_data[next_key]["unlocked"] = true
			if level_number + 1 > levels_unlocked:
				levels_unlocked = level_number + 1
		
		save_levels_data()

func save_levels_data():
	var file = FileAccess.open("user://levels_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(levels_data))
		file.close()

func load_levels_data():
	var file = FileAccess.open("user://levels_data.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			levels_data = json.data
			levels_unlocked = 1
			for level in range(1, 16):
				if str(level) in levels_data and levels_data[str(level)]["unlocked"]:
					levels_unlocked = level
				else:
					break
		else:
			initialize_levels_data()
	else:
		initialize_levels_data()

func is_level_unlocked(level_number: int) -> bool:
	return str(level_number) in levels_data and levels_data[str(level_number)]["unlocked"]

func get_level_data(level_number: int) -> Dictionary:
	var level_key = str(level_number)
	if level_key in levels_data:
		return levels_data[level_key].duplicate()
	return {}

func has_item(item_name: String) -> bool:
	return item_name in purchased_items

func get_purchased_items() -> Array:
	return purchased_items.duplicate()
