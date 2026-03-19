# Уровень 11: тесные коридоры и мало безопасных клеток.
# Задача: точно выдерживать траекторию и не терять позицию перед финальным подъемом.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 11
	level_title = "Тесный коридор"
	level_hint = "Места стало меньше, а ошибки накапливаются быстрее."
	level_description = "Безопасных клеток уже немного. Нужно держать плотную траекторию и не отдать позицию после первого же маневра."
	completion_text = "Сильный результат. Узкие коридоры уже под контролем."
	start_grid = Vector2i(-5, -4)
	start_height = 8.0
	target_grid = Vector2i(5, 4)
	target_height = 104.0
	moving_platforms_data = [
		{"from": Vector2i(-2, -3), "to": Vector2i(0, -3), "height": 40.0, "speed": 2.5, "color": Color(0.88, 0.60, 0.34)},
		{"from": Vector2i(1, 0), "to": Vector2i(3, 0), "height": 72.0, "speed": 2.2, "color": Color(0.93, 0.72, 0.43)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-1, -2), "to": Vector2i(-1, 0), "height": 40.0, "speed": 1.8, "size": Vector3(6.0, 28.0, GRID_SIZE - 8.0), "color": Color(0.83, 0.36, 0.26)},
		{"from": Vector2i(1, -1), "to": Vector2i(3, -1), "height": 72.0, "speed": 1.7, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.74, 0.31, 0.23)},
		{"from": Vector2i(4, 1), "to": Vector2i(4, 3), "height": 104.0, "speed": 1.6, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.89, 0.44, 0.30)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-3, -3), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-2, -1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(0, 1), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(3, 3), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
