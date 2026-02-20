extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 10
	level_title = "УРОВЕНЬ"
	level_hint = "Длинная трасса с частыми сменами высоты."
	completion_text = "Отличный контроль высоты и траектории!"
	start_grid = Vector2i(-4, -3)
	start_height = 8
	target_grid = Vector2i(4, 3)
	target_height = 96
	moving_platforms_data = [
		{"from": Vector2i(-4, -3), "to": Vector2i(-2, -2), "height": 16, "speed": 3.2, "color": Color(0.95, 0.35, 0.2)},
		{"from": Vector2i(-2, -1), "to": Vector2i(0, 0), "height": 32, "speed": 3.6, "color": Color(0.2, 0.75, 1.0)},
		{"from": Vector2i(0, 1), "to": Vector2i(2, 1), "height": 48, "speed": 3.4, "color": Color(0.2, 0.95, 0.5)},
		{"from": Vector2i(2, 2), "to": Vector2i(3, 3), "height": 64, "speed": 3.0, "color": Color(1.0, 0.82, 0.2)},
		{"from": Vector2i(3, 3), "to": Vector2i(4, 3), "height": 80, "speed": 2.8, "color": Color(0.85, 0.6, 1.0)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-3, -1), "to": Vector2i(-1, -1), "height": 24, "speed": 2.2, "size": Vector3(GRID_SIZE - 10, 20, 6), "color": Color(0.85, 0.15, 0.35)},
		{"from": Vector2i(-1, 1), "to": Vector2i(-1, 3), "height": 40, "speed": 2.0, "size": Vector3(6, 24, GRID_SIZE - 10), "color": Color(0.95, 0.3, 0.65)},
		{"from": Vector2i(2, 0), "to": Vector2i(2, 2), "height": 56, "speed": 1.9, "size": Vector3(GRID_SIZE - 8, 20, 6), "color": Color(0.95, 0.2, 0.45)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-3, -2), "height": 0, "size": Vector3(GRID_SIZE, 24, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 0, "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"grid": Vector2i(0, -2), "height": 0, "size": Vector3(GRID_SIZE, 36, GRID_SIZE)},
		{"grid": Vector2i(1, 2), "height": 0, "size": Vector3(GRID_SIZE, 42, GRID_SIZE)},
		{"grid": Vector2i(3, 1), "height": 0, "size": Vector3(GRID_SIZE, 48, GRID_SIZE)}
	]
