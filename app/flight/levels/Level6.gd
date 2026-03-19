# Уровень 6: первая высокая цель и длинная диагональная трасса.
# Задача: подняться на второй этаж сетки и не влететь в движущуюся площадку.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 6
	level_title = "Высота"
	level_hint = "Поднимитесь выше и держите чистую диагональ к цели."
	level_description = "Финиш находится уже на втором уровне высоты. Подъем нужно соединить с аккуратным обходом движущегося элемента."
	completion_text = "Отлично. Высота и тайминг работают вместе."
	start_grid = Vector2i(-3, -2)
	start_height = 8.0
	target_grid = Vector2i(3, 2)
	target_height = 72.0
	moving_platforms_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(1, -1), "height": 40.0, "speed": 3.3, "color": Color(0.90, 0.60, 0.32)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(1, 0), "to": Vector2i(1, 2), "height": 40.0, "speed": 2.2, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.82, 0.34, 0.26)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-1, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 26.0, GRID_SIZE)},
		{"grid": Vector2i(0, 1), "height": 8.0, "size": Vector3(GRID_SIZE, 26.0, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 40.0, "size": Vector3(GRID_SIZE, 26.0, GRID_SIZE)}
	]
