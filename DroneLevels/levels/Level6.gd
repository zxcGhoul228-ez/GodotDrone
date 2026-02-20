extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 6
	level_title = "УРОВЕНЬ"
	level_hint = "Продвинутый уровень: много движения и опасных окон."
	completion_text = "Отлично! Ты уверенно прошел уровень перед средней зоной."
	start_grid = Vector2i(-3, -2)
	start_height = 8
	target_grid = Vector2i(3, 2)
	target_height = 52
	moving_platforms_data = [
		{"from": Vector2i(-3, -2), "to": Vector2i(0, -2), "height": 8, "speed": 3.6, "color": Color(0.9, 0.3, 0.2)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, 0), "height": 24, "speed": 3.5, "color": Color(0.2, 0.7, 1.0)},
		{"from": Vector2i(0, 1), "to": Vector2i(2, 1), "height": 40, "speed": 3.3, "color": Color(0.2, 0.9, 0.5)},
		{"from": Vector2i(2, 1), "to": Vector2i(3, 2), "height": 52, "speed": 3.0, "color": Color(1.0, 0.8, 0.2)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-2, -1), "to": Vector2i(-2, 1), "height": 16, "speed": 2.3, "size": Vector3(6, 24, GRID_SIZE - 8), "color": Color(0.8, 0.1, 0.3)},
		{"from": Vector2i(0, 0), "to": Vector2i(2, 0), "height": 32, "speed": 2.1, "size": Vector3(GRID_SIZE - 8, 22, 6), "color": Color(0.9, 0.2, 0.6)},
		{"from": Vector2i(1, 1), "to": Vector2i(1, -1), "height": 40, "speed": 2.0, "size": Vector3(6, 24, GRID_SIZE - 8), "color": Color(0.95, 0.3, 0.7)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0, "size": Vector3(GRID_SIZE, 20, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 0, "size": Vector3(GRID_SIZE, 28, GRID_SIZE)},
		{"grid": Vector2i(0, 2), "height": 0, "size": Vector3(GRID_SIZE, 36, GRID_SIZE)},
		{"grid": Vector2i(1, -2), "height": 0, "size": Vector3(GRID_SIZE, 28, GRID_SIZE)},
		{"grid": Vector2i(2, 0), "height": 0, "size": Vector3(GRID_SIZE, 44, GRID_SIZE)}
	]
