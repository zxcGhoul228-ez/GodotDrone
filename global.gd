# global.gd
extends Node
var purchased_items = []
var score = 100
static var drone_data = {}
var current_level: int = 1
var levels_unlocked: int = 1
var levels_data: Dictionary = {}

func has_item(item_name):
	return item_name in purchased_items

func get_purchased_items():
	return purchased_items.duplicate() 

# global.gd

func _ready():
	print("=== GLOBAL.GD INIT ===")
	load_levels_data()
	
	print("Данные уровней загружены. Разблокировано уровней: ", levels_unlocked)

func initialize_levels_data():
	levels_data = {}
	for i in range(1, 16):
		levels_data[str(i)] = {  # Сохраняем как СТРОКИ
			"unlocked": i == 1,
			"completed": false, 
			"best_steps": 0, 
			"stars": 0
		}

func complete_level(level_number: int, steps: int, stars: int):
	var level_key = str(level_number)  # Конвертируем в строку
	if level_key in levels_data:
		levels_data[level_key]["completed"] = true
		if steps < levels_data[level_key]["best_steps"] or levels_data[level_key]["best_steps"] == 0:
			levels_data[level_key]["best_steps"] = steps
		if stars > levels_data[level_key]["stars"]:
			levels_data[level_key]["stars"] = stars
		
		if level_number < 15:
			levels_data[str(level_number + 1)]["unlocked"] = true
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
			# Обновляем levels_unlocked
			levels_unlocked = 1
			for level in range(1, 16):
				if str(level) in levels_data and levels_data[str(level)]["unlocked"]:
					levels_unlocked = level
				else:
					break
		else:
			initialize_levels_data()
		file.close()
	else:
		initialize_levels_data()

# Безопасные методы доступа - теперь работают со строками
func is_level_unlocked(level_number: int) -> bool:
	return str(level_number) in levels_data and levels_data[str(level_number)]["unlocked"]

func get_level_stars(level_number: int) -> int:
	var level_key = str(level_number)
	if level_key in levels_data:
		return levels_data[level_key]["stars"]
	return 0

func get_level_best_steps(level_number: int) -> int:
	var level_key = str(level_number)
	if level_key in levels_data:
		return levels_data[level_key]["best_steps"]
	return 0

# Новый метод для получения данных уровня
func get_level_data(level_number: int) -> Dictionary:
	var level_key = str(level_number)
	if level_key in levels_data:
		return levels_data[level_key].duplicate()  # Возвращаем копию
	return {}
