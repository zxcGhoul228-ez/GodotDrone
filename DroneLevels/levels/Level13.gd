extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 13
	level_title = "УРОВЕНЬ"
	level_hint = "Почти эксперт: много угроз, мало безопасных окон."
	completion_text = "Впечатляюще! Экспертная трасса пройдена."
	start_grid = Vector2i(-5, -4)
	start_height = 8
	target_grid = Vector2i(5, 4)
	target_height = 120
	moving_platforms_data = [
		{"from": Vector2i(-5, -4), "to": Vector2i(-3, -3), "height": 16, "speed": 2.8, "color": Color(0.95, 0.3, 0.2)},
		{"from": Vector2i(-3, -2), "to": Vector2i(-1, -1), "height": 32, "speed": 3.0, "color": Color(0.2, 0.72, 1.0)},
		{"from": Vector2i(-1, 0), "to": Vector2i(1, 1), "height": 48, "speed": 2.8, "color": Color(0.2, 0.9, 0.5)},
		{"from": Vector2i(1, 2), "to": Vector2i(3, 3), "height": 64, "speed": 2.6, "color": Color(1.0, 0.8, 0.2)},
		{"from": Vector2i(3, 3), "to": Vector2i(4, 4), "height": 80, "speed": 2.4, "color": Color(0.75, 0.55, 1.0)},
		{"from": Vector2i(4, 4), "to": Vector2i(5, 4), "height": 96, "speed": 2.2, "color": Color(0.58, 0.98, 0.85)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-4, -3), "to": Vector2i(-2, -3), "height": 24, "speed": 1.8, "size": Vector3(GRID_SIZE - 10, 24, 6), "color": Color(0.92, 0.1, 0.42)},
		{"from": Vector2i(-2, -1), "to": Vector2i(-2, 1), "height": 40, "speed": 1.7, "size": Vector3(6, 28, GRID_SIZE - 10), "color": Color(0.98, 0.3, 0.68)},
		{"from": Vector2i(0, 0), "to": Vector2i(2, 0), "height": 56, "speed": 1.6, "size": Vector3(GRID_SIZE - 10, 24, 6), "color": Color(0.96, 0.18, 0.52)},
		{"from": Vector2i(1, 2), "to": Vector2i(1, 4), "height": 72, "speed": 1.5, "size": Vector3(6, 30, GRID_SIZE - 10), "color": Color(1.0, 0.28, 0.75)},
		{"from": Vector2i(3, 2), "to": Vector2i(1, 2), "height": 88, "speed": 1.4, "size": Vector3(GRID_SIZE - 10, 24, 6), "color": Color(0.95, 0.2, 0.6)},
		{"from": Vector2i(4, 3), "to": Vector2i(4, 1), "height": 104, "speed": 1.3, "size": Vector3(6, 30, GRID_SIZE - 10), "color": Color(1.0, 0.35, 0.8)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-4, -3), "height": 0, "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"grid": Vector2i(-3, 0), "height": 0, "size": Vector3(GRID_SIZE, 38, GRID_SIZE)},
		{"grid": Vector2i(-2, 2), "height": 0, "size": Vector3(GRID_SIZE, 44, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 0, "size": Vector3(GRID_SIZE, 48, GRID_SIZE)},
		{"grid": Vector2i(1, 2), "height": 0, "size": Vector3(GRID_SIZE, 52, GRID_SIZE)},
		{"grid": Vector2i(2, -2), "height": 0, "size": Vector3(GRID_SIZE, 56, GRID_SIZE)},
		{"grid": Vector2i(3, 1), "height": 0, "size": Vector3(GRID_SIZE, 60, GRID_SIZE)},
		{"grid": Vector2i(4, -1), "height": 0, "size": Vector3(GRID_SIZE, 64, GRID_SIZE)}
	]
