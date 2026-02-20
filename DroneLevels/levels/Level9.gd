extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 9
	level_title = "УРОВЕНЬ"
	level_hint = "Теперь нужно точно рассчитывать тайминги между воротами."
	completion_text = "Супер! Ты уверенно проходишь коридоры с таймингами."
	start_grid = Vector2i(-3, -3)
	start_height = 8
	target_grid = Vector2i(3, 3)
	target_height = 80
	mission_time_limit_sec = 85
	required_collectibles = 3
	collectibles_data = [
		{"grid": Vector2i(-2, -1), "height": 24},
		{"grid": Vector2i(0, 1), "height": 40},
		{"grid": Vector2i(2, 2), "height": 64}
	]
	moving_platforms_data = [
		{"from": Vector2i(-3, -3), "to": Vector2i(-1, -2), "height": 16, "speed": 3.4, "color": Color(0.9, 0.35, 0.2)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, 0), "height": 32, "speed": 3.8, "color": Color(0.25, 0.75, 1.0)},
		{"from": Vector2i(0, 1), "to": Vector2i(2, 2), "height": 48, "speed": 3.5, "color": Color(0.2, 0.9, 0.5)},
		{"from": Vector2i(1, 2), "to": Vector2i(3, 3), "height": 64, "speed": 3.2, "color": Color(1.0, 0.8, 0.2)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-2, -1), "to": Vector2i(-2, 1), "height": 24, "speed": 2.4, "size": Vector3(6, 24, GRID_SIZE - 6), "color": Color(0.9, 0.2, 0.5)},
		{"from": Vector2i(0, 0), "to": Vector2i(0, 2), "height": 40, "speed": 2.1, "size": Vector3(GRID_SIZE - 8, 24, 6), "color": Color(0.8, 0.1, 0.3)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -2), "height": 0, "size": Vector3(GRID_SIZE, 22, GRID_SIZE)},
		{"grid": Vector2i(-1, 1), "height": 0, "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 0, "size": Vector3(GRID_SIZE, 36, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 0, "size": Vector3(GRID_SIZE, 42, GRID_SIZE)}
	]
