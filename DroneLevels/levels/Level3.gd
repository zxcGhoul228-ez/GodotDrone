extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 3
	level_title = "УРОВЕНЬ"
	level_hint = "Появляются тайминги: комбинируй движение и высоту."
	completion_text = "Отлично! Ты справился с первыми таймингами."
	start_grid = Vector2i(-3, -2)
	start_height = 8
	target_grid = Vector2i(2, 2)
	target_height = 32
	moving_platforms_data = [
		{"from": Vector2i(-3, -2), "to": Vector2i(-1, -1), "height": 8, "speed": 4.2, "color": Color(0.9, 0.4, 0.2)},
		{"from": Vector2i(-1, 0), "to": Vector2i(1, 0), "height": 24, "speed": 4.0, "color": Color(0.2, 0.7, 1.0)},
		{"from": Vector2i(1, 1), "to": Vector2i(2, 2), "height": 32, "speed": 3.8, "color": Color(0.3, 0.9, 0.5)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(0, 1), "height": 16, "speed": 3.0, "size": Vector3(6, 20, GRID_SIZE - 8), "color": Color(0.9, 0.2, 0.5)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0, "size": Vector3(GRID_SIZE, 20, GRID_SIZE)},
		{"grid": Vector2i(0, 1), "height": 0, "size": Vector3(GRID_SIZE, 24, GRID_SIZE)}
	]
