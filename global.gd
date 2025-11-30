# Global.gd
extends Node

# Игровые данные
var purchased_items = ["Рама1", "Плата1", "Мотор1", "Пропеллер1"]
var score = 100
static var drone_data = {}
var current_level: int = 1
var levels_unlocked: int = 1
var levels_data: Dictionary = {}
var currency = 100

# Система загрузки
var loading_screen: Control = null

# Временные пороги для звезд (в миллисекундах) для каждого уровня
# [3 звезды, 2 звезды, 1 звезда] - времена ДО которых нужно уложиться
var level_star_thresholds = {
	1: [30, 45, 60000],   # Уровень 1: до 30 сек - 3 звезды, до 45 сек - 2 звезды, до 60 сек - 1 звезда
	2: [45000, 60000, 90000],   # Уровень 2
	3: [60000, 90000, 120000],  # Уровень 3
	4: [75000, 105000, 150000], # Уровень 4
	5: [90000, 120000, 180000], # Уровень 5
	6: [120000, 150000, 210000],
	7: [150000, 180000, 240000],
	8: [180000, 210000, 270000],
	9: [210000, 240000, 300000],
	10: [240000, 270000, 330000],
	11: [270000, 300000, 360000],
	12: [300000, 330000, 390000],
	13: [330000, 360000, 420000],
	14: [360000, 390000, 450000],
	15: [390000, 420000, 480000]
}

# Награды за звезды (базовая валюта)
var star_rewards = {
	3: 100,  # За 3 звезды
	2: 60,   # За 2 звезды  
	1: 30    # За 1 звезду
}

# Бонус за первое прохождение уровня
var first_time_bonus = 50

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

func calculate_stars(level: int, actual_time_ms: int) -> int:
	if not level_star_thresholds.has(level):
		return 0
	
	var thresholds = level_star_thresholds[level]
	
	if actual_time_ms <= thresholds[0]:
		return 3
	elif actual_time_ms <= thresholds[1]:
		return 2
	elif actual_time_ms <= thresholds[2]:
		return 1
	else:
		return 0  # Время превысило все пороги - уровень пройден, но звезд нет

func calculate_level_reward(level: int, actual_time_ms: int, first_time: bool) -> Dictionary:
	var stars = calculate_stars(level, actual_time_ms)
	var base_reward = star_rewards.get(stars, 0)
	var total_reward = base_reward
	
	if first_time and stars > 0:
		total_reward += first_time_bonus
	
	return {
		"stars": stars,
		"reward": total_reward,
		"base_reward": base_reward,
		"bonus": first_time_bonus if first_time else 0
	}

func complete_level(level_number: int, time_ms: int):
	var level_key = str(level_number)
	if level_key in levels_data:
		var was_completed = levels_data[level_key]["completed"]
		var previous_stars = levels_data[level_key].get("stars", 0)
		var previous_best_time = levels_data[level_key].get("best_time", 0)
		
		# Рассчитываем звезды для этого прохождения
		var result = calculate_level_reward(level_number, time_ms, not was_completed)
		var stars = result["stars"]
		var reward = result["reward"]
		
		# Сохраняем лучшее время и звезды (только если результат улучшен)
		var is_improvement = false
		if stars > previous_stars or (stars == previous_stars and time_ms < previous_best_time):
			levels_data[level_key]["best_time"] = time_ms
			levels_data[level_key]["stars"] = stars
			is_improvement = true
		
		levels_data[level_key]["completed"] = true
		
		# Разблокируем следующий уровень
		if level_number < 15:
			var next_key = str(level_number + 1)
			levels_data[next_key]["unlocked"] = true
			if level_number + 1 > levels_unlocked:
				levels_unlocked = level_number + 1
		
		# Начисляем валюту только при первом прохождении или улучшении результата
		print("🎯 Условия начисления: был завершен=%s, улучшение=%s, звезды=%d, награда=%d" % [was_completed, is_improvement, stars, reward])
		if not was_completed or is_improvement:
			add_currency(reward)
			print("🎉 Уровень %d: %d звезд, награда: %d монет" % [level_number, stars, reward])
		else:
			print("ℹ️ Уровень уже был пройден без улучшения, валюта не начислена")
		
		save_levels_data()
		
		return result
	return {"stars": 0, "reward": 0, "base_reward": 0, "bonus": 0}

func add_currency(amount: int):
	currency += amount
	save_game()
	print("💰 Получено валюты: ", amount, ". Всего: ", currency)

func get_currency() -> int:
	return currency

func save_game():
	var config = ConfigFile.new()
	config.set_value("game", "score", score)
	config.set_value("game", "currency", currency)
	config.set_value("game", "purchased_items", purchased_items)
	config.save("user://game_save.cfg")

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

# Временная функция для тестирования порогов
func test_level_thresholds():
	print("=== ТЕСТИРОВАНИЕ ПОРОГОВ УРОВНЕЙ ===")
	for level in range(1, 16):
		if level_star_thresholds.has(level):
			var thresholds = level_star_thresholds[level]
			print("Уровень %d: 3★ - %s, 2★ - %s, 1★ - %s" % [
				level,
				format_test_time(thresholds[0]),
				format_test_time(thresholds[1]),
				format_test_time(thresholds[2])
			])

func format_test_time(ms: int) -> String:
	var seconds = ms / 1000.0
	return "%.1f сек" % seconds
