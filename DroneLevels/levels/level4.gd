extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 4
	level_title = "УРОВЕНЬ"
	level_hint = "Средняя сложность: узкий маршрут с динамическими воротами."
	completion_text = "Класс! Ты прошел плотный участок маршрута."
	start_grid = Vector2i(-3, -2)
	start_height = 8
	target_grid = Vector2i(3, 2)
	target_height = 40
	moving_platforms_data = [
		{"from": Vector2i(-3, -2), "to": Vector2i(-1, -2), "height": 8, "speed": 4.0, "color": Color(0.9, 0.35, 0.2)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, 0), "height": 24, "speed": 3.8, "color": Color(0.2, 0.7, 1.0)},
		{"from": Vector2i(1, 1), "to": Vector2i(3, 2), "height": 40, "speed": 3.5, "color": Color(0.2, 0.9, 0.5)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-1, 0), "to": Vector2i(-1, 2), "height": 24, "speed": 2.6, "size": Vector3(6, 24, GRID_SIZE - 8), "color": Color(0.95, 0.25, 0.65)},
		{"from": Vector2i(1, -1), "to": Vector2i(1, 1), "height": 32, "speed": 2.4, "size": Vector3(GRID_SIZE - 8, 22, 6), "color": Color(0.85, 0.15, 0.35)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0, "size": Vector3(GRID_SIZE, 22, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 0, "size": Vector3(GRID_SIZE, 28, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 0, "size": Vector3(GRID_SIZE, 32, GRID_SIZE)}
	]
