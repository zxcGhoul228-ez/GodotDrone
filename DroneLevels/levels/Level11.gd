extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 11
	level_title = "УРОВЕНЬ"
	level_hint = "Сложный уровень доставки: захвати груз и пронеси через узкие окна."
	completion_text = "Класс! Контейнер доставлен в сложной зоне."
	start_grid = Vector2i(-4, -4)
	start_height = 8
	target_grid = Vector2i(4, 4)
	target_height = 104
	mission_time_limit_sec = 90
	requires_cargo_delivery = true
	cargo_start_grid = Vector2i(-3, -2)
	cargo_start_height = 24
	cargo_drop_grid = Vector2i(4, 4)
	cargo_drop_height = 80
	moving_platforms_data = [
		{"from": Vector2i(-4, -4), "to": Vector2i(-2, -3), "height": 16, "speed": 3.0, "color": Color(0.9, 0.32, 0.2)},
		{"from": Vector2i(-2, -2), "to": Vector2i(0, -1), "height": 32, "speed": 3.3, "color": Color(0.25, 0.75, 1.0)},
		{"from": Vector2i(0, 0), "to": Vector2i(2, 1), "height": 48, "speed": 3.1, "color": Color(0.2, 0.9, 0.55)},
		{"from": Vector2i(2, 2), "to": Vector2i(3, 3), "height": 64, "speed": 2.9, "color": Color(1.0, 0.8, 0.2)},
		{"from": Vector2i(3, 3), "to": Vector2i(4, 4), "height": 80, "speed": 2.6, "color": Color(0.75, 0.55, 1.0)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-3, -2), "to": Vector2i(-1, -2), "height": 24, "speed": 2.0, "size": Vector3(GRID_SIZE - 10, 22, 6), "color": Color(0.9, 0.1, 0.4)},
		{"from": Vector2i(-1, 0), "to": Vector2i(-1, 2), "height": 40, "speed": 1.9, "size": Vector3(6, 26, GRID_SIZE - 10), "color": Color(0.95, 0.25, 0.65)},
		{"from": Vector2i(1, 1), "to": Vector2i(3, 1), "height": 56, "speed": 1.8, "size": Vector3(GRID_SIZE - 10, 22, 6), "color": Color(0.95, 0.2, 0.5)},
		{"from": Vector2i(2, 3), "to": Vector2i(2, 1), "height": 72, "speed": 1.7, "size": Vector3(6, 28, GRID_SIZE - 10), "color": Color(1.0, 0.3, 0.7)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-3, -3), "height": 0, "size": Vector3(GRID_SIZE, 26, GRID_SIZE)},
		{"grid": Vector2i(-2, 0), "height": 0, "size": Vector3(GRID_SIZE, 34, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 0, "size": Vector3(GRID_SIZE, 38, GRID_SIZE)},
		{"grid": Vector2i(1, 2), "height": 0, "size": Vector3(GRID_SIZE, 46, GRID_SIZE)},
		{"grid": Vector2i(2, -2), "height": 0, "size": Vector3(GRID_SIZE, 42, GRID_SIZE)},
		{"grid": Vector2i(3, 2), "height": 0, "size": Vector3(GRID_SIZE, 50, GRID_SIZE)}
	]
