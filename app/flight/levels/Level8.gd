# Уровень 8: длиннее маршрут и больше вертикальных проверок.
# Задача: идти по ступеням высоты и не врезаться в поперечные барьеры.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 8
	level_title = "Ступени"
	level_hint = "Маршрут поднимается вверх по ступеням и требует точного позиционирования."
	level_description = "Здесь уже важно не только поймать момент, но и не сбиться по высоте: преграды стоят на разных этажах сетки."
	completion_text = "Отлично. Ты держишь и ритм, и вертикаль."
	start_grid = Vector2i(-4, -2)
	start_height = 8.0
	target_grid = Vector2i(4, 2)
	target_height = 72.0
	moving_platforms_data = [
		{"from": Vector2i(-1, 0), "to": Vector2i(1, 0), "height": 40.0, "speed": 2.8, "color": Color(0.91, 0.62, 0.34)},
		{"from": Vector2i(2, 1), "to": Vector2i(3, 1), "height": 72.0, "speed": 2.6, "color": Color(0.88, 0.70, 0.44)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(0, 1), "height": 40.0, "speed": 2.0, "size": Vector3(6.0, 26.0, GRID_SIZE - 8.0), "color": Color(0.84, 0.36, 0.27)},
		{"from": Vector2i(2, 0), "to": Vector2i(4, 0), "height": 72.0, "speed": 1.9, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.76, 0.31, 0.23)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(1, 1), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(3, 0), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
