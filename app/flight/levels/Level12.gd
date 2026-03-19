# Уровень 12: перекрестные движения и высокий финиш.
# Задача: пройти через чередование горизонтальных и вертикальных угроз.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 12
	level_title = "Перекрестье"
	level_hint = "Опасности идут с разных сторон, поэтому маршрут нужно читать заранее."
	level_description = "Препятствия больше не работают по одному. Здесь нужно понимать, как несколько движений накладываются друг на друга."
	completion_text = "Отлично. Перекрестные тайминги пройдены."
	start_grid = Vector2i(-5, -4)
	start_height = 8.0
	target_grid = Vector2i(5, 5)
	target_height = 136.0
	moving_platforms_data = [
		{"from": Vector2i(-2, -2), "to": Vector2i(0, -2), "height": 40.0, "speed": 2.4, "color": Color(0.90, 0.62, 0.35)},
		{"from": Vector2i(1, 1), "to": Vector2i(3, 1), "height": 72.0, "speed": 2.1, "color": Color(0.94, 0.73, 0.44)},
		{"from": Vector2i(3, 3), "to": Vector2i(4, 3), "height": 104.0, "speed": 1.9, "color": Color(0.96, 0.76, 0.46)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-1, -1), "to": Vector2i(-1, 1), "height": 40.0, "speed": 1.7, "size": Vector3(6.0, 28.0, GRID_SIZE - 8.0), "color": Color(0.83, 0.36, 0.27)},
		{"from": Vector2i(1, 0), "to": Vector2i(3, 0), "height": 72.0, "speed": 1.6, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.75, 0.31, 0.23)},
		{"from": Vector2i(3, 2), "to": Vector2i(3, 4), "height": 104.0, "speed": 1.5, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.89, 0.45, 0.31)},
		{"from": Vector2i(4, 4), "to": Vector2i(2, 4), "height": 136.0, "speed": 1.4, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.94, 0.53, 0.34)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-3, -3), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-2, 0), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(0, 2), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 2), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(4, 2), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
