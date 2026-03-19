# Уровень 2: первый небольшой объезд вокруг статичных препятствий.
# Задача: обойти колонны и аккуратно выйти к цели на той же высоте.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 2
	level_title = "Объезд"
	level_hint = "Обойдите препятствия и дойдите до цели без набора высоты."
	level_description = "На поле появились первые колонны. Прямой путь перекрыт, поэтому нужно заранее выбрать безопасный объезд."
	completion_text = "Хорошо. Теперь ты видишь маршрут, а не только цель."
	start_grid = Vector2i(-2, -2)
	start_height = 8.0
	target_grid = Vector2i(2, 1)
	target_height = 8.0
	moving_platforms_data = []
	moving_obstacles_data = []
	static_obstacles_data = [
		{"grid": Vector2i(0, -2), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)}
	]
