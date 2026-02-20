extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 7
	level_title = "УРОВЕНЬ"
	level_hint = "Уровень средней сложности: платформы + базовые стены."
	completion_text = "Ты освоил базовую синхронизацию с платформами!"
	start_grid = Vector2i(-2, -2)
	start_height = 8
	target_grid = Vector2i(2, 2)
	target_height = 56
	required_collectibles = 2
	collectibles_data = [
		{"grid": Vector2i(-1, -1), "height": 16},
		{"grid": Vector2i(1, 1), "height": 32}
	]
	moving_platforms_data = [
		{"from": Vector2i(-2, -2), "to": Vector2i(1, -2), "height": 8, "speed": 3.8, "color": Color(0.9, 0.4, 0.2)},
		{"from": Vector2i(-1, 0), "to": Vector2i(2, 0), "height": 24, "speed": 4.0, "color": Color(0.2, 0.7, 0.9)},
		{"from": Vector2i(0, 1), "to": Vector2i(2, 2), "height": 40, "speed": 3.6, "color": Color(0.3, 0.9, 0.5)}
	]
	moving_obstacles_data = [

	]
	static_obstacles_data = [
		{"grid": Vector2i(-1, -1), "height": 0, "size": Vector3(GRID_SIZE, 18, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 0, "size": Vector3(GRID_SIZE, 26, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 0, "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"grid": Vector2i(1, 2), "height": 0, "size": Vector3(GRID_SIZE, 34, GRID_SIZE)}
	]
