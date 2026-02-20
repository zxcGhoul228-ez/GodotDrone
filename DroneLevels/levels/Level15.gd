extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 15
	level_title = "УРОВЕНЬ"
	level_hint = "Финал: захват и доставка груза в условиях предельной сложности."
	completion_text = "Легенда! Финальная доставка выполнена."
	start_grid = Vector2i(-6, -5)
	start_height = 8
	target_grid = Vector2i(6, 5)
	target_height = 136
	mission_time_limit_sec = 65
	requires_cargo_delivery = true
	cargo_start_grid = Vector2i(-1, -1)
	cargo_start_height = 56
	cargo_drop_grid = Vector2i(6, 5)
	cargo_drop_height = 120
	moving_platforms_data = [
		{"from": Vector2i(-6, -5), "to": Vector2i(-4, -4), "height": 16, "speed": 2.4, "color": Color(0.95, 0.25, 0.2)},
		{"from": Vector2i(-4, -3), "to": Vector2i(-2, -2), "height": 32, "speed": 2.6, "color": Color(0.2, 0.7, 1.0)},
		{"from": Vector2i(-2, -1), "to": Vector2i(0, 0), "height": 48, "speed": 2.4, "color": Color(0.2, 0.9, 0.5)},
		{"from": Vector2i(0, 1), "to": Vector2i(2, 2), "height": 64, "speed": 2.2, "color": Color(1.0, 0.8, 0.2)},
		{"from": Vector2i(2, 3), "to": Vector2i(4, 4), "height": 80, "speed": 2.0, "color": Color(0.75, 0.55, 1.0)},
		{"from": Vector2i(4, 4), "to": Vector2i(5, 5), "height": 96, "speed": 1.8, "color": Color(0.58, 0.98, 0.85)},
		{"from": Vector2i(5, 5), "to": Vector2i(6, 5), "height": 112, "speed": 1.6, "color": Color(1.0, 0.55, 0.85)},
		{"from": Vector2i(6, 5), "to": Vector2i(6, 4), "height": 128, "speed": 1.4, "color": Color(1.0, 0.7, 0.45)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-5, -4), "to": Vector2i(-3, -4), "height": 24, "speed": 1.4, "size": Vector3(GRID_SIZE - 10, 28, 6), "color": Color(0.92, 0.1, 0.42)},
		{"from": Vector2i(-3, -2), "to": Vector2i(-3, 0), "height": 40, "speed": 1.3, "size": Vector3(6, 32, GRID_SIZE - 10), "color": Color(0.98, 0.3, 0.68)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, -1), "height": 56, "speed": 1.2, "size": Vector3(GRID_SIZE - 10, 28, 6), "color": Color(0.96, 0.18, 0.52)},
		{"from": Vector2i(1, 1), "to": Vector2i(1, 3), "height": 72, "speed": 1.1, "size": Vector3(6, 34, GRID_SIZE - 10), "color": Color(1.0, 0.28, 0.75)},
		{"from": Vector2i(3, 1), "to": Vector2i(1, 1), "height": 88, "speed": 1.0, "size": Vector3(GRID_SIZE - 10, 28, 6), "color": Color(0.95, 0.2, 0.6)},
		{"from": Vector2i(4, 2), "to": Vector2i(4, 0), "height": 104, "speed": 0.95, "size": Vector3(6, 34, GRID_SIZE - 10), "color": Color(1.0, 0.35, 0.8)},
		{"from": Vector2i(5, 3), "to": Vector2i(3, 3), "height": 120, "speed": 0.9, "size": Vector3(GRID_SIZE - 10, 28, 6), "color": Color(1.0, 0.45, 0.85)},
		{"from": Vector2i(6, 4), "to": Vector2i(4, 4), "height": 132, "speed": 0.85, "size": Vector3(GRID_SIZE - 10, 28, 6), "color": Color(1.0, 0.5, 0.9)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-5, -4), "height": 0, "size": Vector3(GRID_SIZE, 34, GRID_SIZE)},
		{"grid": Vector2i(-4, -1), "height": 0, "size": Vector3(GRID_SIZE, 42, GRID_SIZE)},
		{"grid": Vector2i(-3, 1), "height": 0, "size": Vector3(GRID_SIZE, 48, GRID_SIZE)},
		{"grid": Vector2i(-2, 3), "height": 0, "size": Vector3(GRID_SIZE, 54, GRID_SIZE)},
		{"grid": Vector2i(0, -2), "height": 0, "size": Vector3(GRID_SIZE, 58, GRID_SIZE)},
		{"grid": Vector2i(1, 1), "height": 0, "size": Vector3(GRID_SIZE, 62, GRID_SIZE)},
		{"grid": Vector2i(2, -1), "height": 0, "size": Vector3(GRID_SIZE, 66, GRID_SIZE)},
		{"grid": Vector2i(3, 2), "height": 0, "size": Vector3(GRID_SIZE, 70, GRID_SIZE)},
		{"grid": Vector2i(4, 0), "height": 0, "size": Vector3(GRID_SIZE, 74, GRID_SIZE)},
		{"grid": Vector2i(5, 2), "height": 0, "size": Vector3(GRID_SIZE, 78, GRID_SIZE)}
	]
