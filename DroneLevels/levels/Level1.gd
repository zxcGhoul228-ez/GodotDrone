extends "res://DroneLevels/levels/LevelAdvanced.gd"

func _init():
	level_number = 1
	level_title = "УРОВЕНЬ"
	level_hint = "Базовый уровень: доберись до цели по прямому маршруту."
	completion_text = "Отличное начало! Базовое управление освоено."
	start_grid = Vector2i(-2, -2)
	start_height = 8
	target_grid = Vector2i(1, 1)
	target_height = 8
	moving_platforms_data = [
		{"from": Vector2i(-1, -1), "to": Vector2i(0, -1), "height": 8, "speed": 5.0, "color": Color(0.3, 0.8, 1.0)}
	]
	moving_obstacles_data = [

	]
	static_obstacles_data = [
		{"grid": Vector2i(0, -2), "height": 0, "size": Vector3(GRID_SIZE, 14, GRID_SIZE)}
	]
