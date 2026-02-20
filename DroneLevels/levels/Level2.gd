extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 2
	level_title = "УРОВЕНЬ"
	level_hint = "Чуть сложнее: первый подъем и обход препятствий."
	completion_text = "Хорошо! Ты уверенно контролируешь траекторию."
	start_grid = Vector2i(-2, -2)
	start_height = 8
	target_grid = Vector2i(2, 1)
	target_height = 24
	moving_platforms_data = [
		{"from": Vector2i(-2, -1), "to": Vector2i(0, -1), "height": 8, "speed": 4.7, "color": Color(0.9, 0.45, 0.2)},
		{"from": Vector2i(0, 0), "to": Vector2i(1, 1), "height": 24, "speed": 4.5, "color": Color(0.25, 0.75, 1.0)}
	]
	moving_obstacles_data = [

	]
	static_obstacles_data = [
		{"grid": Vector2i(-1, 0), "height": 0, "size": Vector3(GRID_SIZE, 18, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 0, "size": Vector3(GRID_SIZE, 22, GRID_SIZE)}
	]
