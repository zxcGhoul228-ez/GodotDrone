# Уровень 3: первое обязательное поднятие на один этаж сетки.
# Задача: перелететь над низкими колоннами и финишировать на высоте.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 3
	level_title = "Первый подъем"
	level_hint = "Поднимитесь на один уровень выше и пройдите над препятствиями."
	level_description = "Цель находится выше стартовой точки. Чтобы дойти до нее, поднимите дрон и пролетите над низкими колоннами."
	completion_text = "Отлично. Вертикальный маршрут больше не пугает."
	start_grid = Vector2i(-2, -2)
	start_height = 8.0
	target_grid = Vector2i(2, 1)
	target_height = 40.0
	moving_platforms_data = []
	moving_obstacles_data = []
	static_obstacles_data = [
		{"grid": Vector2i(0, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(1, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(1, 0), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
