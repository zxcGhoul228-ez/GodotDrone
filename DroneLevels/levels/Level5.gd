extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 5
	level_title = "УРОВЕНЬ"
	level_hint = "Сложный лабиринт из высот и препятствий."
	completion_text = "Отличная работа! Ты готов к продвинутым уровням."
	start_grid = Vector2i(-3, -3)
	start_height = 8
	target_grid = Vector2i(3, 2)
	target_height = 48
	moving_platforms_data = [
		{"from": Vector2i(-3, -3), "to": Vector2i(-1, -2), "height": 8, "speed": 3.8, "color": Color(0.9, 0.35, 0.2)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, 0), "height": 24, "speed": 3.6, "color": Color(0.2, 0.75, 1.0)},
		{"from": Vector2i(1, 1), "to": Vector2i(2, 2), "height": 40, "speed": 3.4, "color": Color(0.2, 0.9, 0.5)},
		{"from": Vector2i(2, 2), "to": Vector2i(3, 2), "height": 48, "speed": 3.2, "color": Color(1.0, 0.8, 0.2)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-2, -1), "to": Vector2i(0, -1), "height": 16, "speed": 2.5, "size": Vector3(GRID_SIZE - 8, 22, 6), "color": Color(0.85, 0.15, 0.35)},
		{"from": Vector2i(0, 0), "to": Vector2i(0, 2), "height": 32, "speed": 2.3, "size": Vector3(6, 24, GRID_SIZE - 8), "color": Color(0.95, 0.25, 0.65)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -2), "height": 0, "size": Vector3(GRID_SIZE, 24, GRID_SIZE)},
		{"grid": Vector2i(-1, 1), "height": 0, "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 0, "size": Vector3(GRID_SIZE, 36, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 0, "size": Vector3(GRID_SIZE, 40, GRID_SIZE)}
	]
