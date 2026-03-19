# Уровень 13: почти экспертный маршрут с длинной финальной связкой.
# Задача: без лишних движений провести дрон через серию плотных окон.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 13
	level_title = "Предфинал"
	level_hint = "Без точного плана и чистой последовательности этот маршрут не берется."
	level_description = "Окна стали узкими, а цена ошибки выросла. Любое лишнее движение съедает удобный ритм прохождения."
	completion_text = "Впечатляет. Предфинальный маршрут пройден."
	start_grid = Vector2i(-6, -4)
	start_height = 8.0
	target_grid = Vector2i(6, 5)
	target_height = 136.0
	moving_platforms_data = [
		{"from": Vector2i(-3, -3), "to": Vector2i(-1, -3), "height": 40.0, "speed": 2.3, "color": Color(0.90, 0.62, 0.35)},
		{"from": Vector2i(0, 0), "to": Vector2i(2, 0), "height": 72.0, "speed": 2.0, "color": Color(0.93, 0.72, 0.44)},
		{"from": Vector2i(3, 2), "to": Vector2i(4, 2), "height": 104.0, "speed": 1.8, "color": Color(0.95, 0.76, 0.46)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-2, -2), "to": Vector2i(-2, 0), "height": 40.0, "speed": 1.6, "size": Vector3(6.0, 28.0, GRID_SIZE - 8.0), "color": Color(0.84, 0.37, 0.27)},
		{"from": Vector2i(0, -1), "to": Vector2i(2, -1), "height": 72.0, "speed": 1.5, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.76, 0.31, 0.23)},
		{"from": Vector2i(2, 1), "to": Vector2i(2, 3), "height": 104.0, "speed": 1.4, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.89, 0.45, 0.31)},
		{"from": Vector2i(5, 3), "to": Vector2i(3, 3), "height": 136.0, "speed": 1.3, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.95, 0.55, 0.35)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-4, -3), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(0, 2), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 0), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(4, 2), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(5, 4), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
