# Уровень 9: первая по-настоящему длинная трасса с несколькими таймингами.
# Задача: спланировать путь заранее и сохранить контроль на длинной дистанции.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 9
	level_title = "Длинный коридор"
	level_hint = "Маршрут длинный: ошибаться в середине уже дорого."
	level_description = "Дрон должен пройти длинную серию клеток, не потеряв темп между несколькими движущимися угрозами."
	completion_text = "Серьезный прогресс. Длинные маршруты тебе уже по силам."
	start_grid = Vector2i(-4, -3)
	start_height = 8.0
	target_grid = Vector2i(4, 3)
	target_height = 104.0
	moving_platforms_data = [
		{"from": Vector2i(-1, -2), "to": Vector2i(1, -2), "height": 40.0, "speed": 2.8, "color": Color(0.88, 0.60, 0.34)},
		{"from": Vector2i(2, 1), "to": Vector2i(3, 1), "height": 72.0, "speed": 2.4, "color": Color(0.93, 0.72, 0.44)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(0, 2), "height": 40.0, "speed": 1.9, "size": Vector3(6.0, 26.0, GRID_SIZE - 8.0), "color": Color(0.84, 0.37, 0.27)},
		{"from": Vector2i(2, -1), "to": Vector2i(4, -1), "height": 72.0, "speed": 1.8, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.76, 0.31, 0.23)},
		{"from": Vector2i(3, 1), "to": Vector2i(3, 3), "height": 104.0, "speed": 1.7, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.90, 0.44, 0.30)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -2), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-1, 0), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(1, 1), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 2), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(4, 1), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
