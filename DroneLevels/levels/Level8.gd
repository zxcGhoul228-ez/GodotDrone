extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 8
	level_title = "УРОВЕНЬ"
	level_hint = "Сложность растет: добавлены движущиеся ворота."
	completion_text = "Отлично! Ты справился с первыми динамическими ловушками!"
	start_grid = Vector2i(-3, -2)
	start_height = 8
	target_grid = Vector2i(3, 2)
	target_height = 72
	mission_time_limit_sec = 95
	required_collectibles = 2
	collectibles_data = [
		{"grid": Vector2i(-1, -1), "height": 24},
		{"grid": Vector2i(2, 1), "height": 48}
	]
	moving_platforms_data = [
		{"from": Vector2i(-3, -2), "to": Vector2i(0, -2), "height": 16, "speed": 3.5, "color": Color(0.9, 0.3, 0.2)},
		{"from": Vector2i(0, -1), "to": Vector2i(2, 1), "height": 32, "speed": 4.2, "color": Color(0.2, 0.7, 1.0)},
		{"from": Vector2i(-1, 1), "to": Vector2i(2, 2), "height": 48, "speed": 3.8, "color": Color(0.2, 0.9, 0.4)},
		{"from": Vector2i(2, 0), "to": Vector2i(3, 2), "height": 64, "speed": 3.0, "color": Color(0.9, 0.8, 0.2)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-1, 0), "to": Vector2i(-1, 0), "height": 16, "speed": 2.8, "size": Vector3(GRID_SIZE - 8, 24, 6), "color": Color(0.8, 0.1, 0.3)},
		{"from": Vector2i(1, 1), "to": Vector2i(1, -1), "height": 32, "speed": 2.2, "size": Vector3(6, 24, GRID_SIZE - 8), "color": Color(0.9, 0.2, 0.6)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0, "size": Vector3(GRID_SIZE, 20, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 0, "size": Vector3(GRID_SIZE, 28, GRID_SIZE)},
		{"grid": Vector2i(0, 2), "height": 0, "size": Vector3(GRID_SIZE, 36, GRID_SIZE)},
		{"grid": Vector2i(1, -2), "height": 0, "size": Vector3(GRID_SIZE, 28, GRID_SIZE)},
		{"grid": Vector2i(2, 0), "height": 0, "size": Vector3(GRID_SIZE, 44, GRID_SIZE)}
	]
