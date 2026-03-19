# Уровень 7: плотнее расставленные колонны и два окна по времени.
# Задача: сохранить высоту и проскочить через два независимых движения.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 7
	level_title = "Две фазы"
	level_hint = "Сохраните высоту и пройдите через два разных окна по таймингу."
	level_description = "С этого уровня маршрут уже нельзя пройти одним интуитивным броском. Нужно держать высоту и заранее думать о следующем окне."
	completion_text = "Сильный проход. Средняя сложность покорена."
	start_grid = Vector2i(-3, -3)
	start_height = 8.0
	target_grid = Vector2i(3, 2)
	target_height = 72.0
	moving_platforms_data = [
		{"from": Vector2i(-1, -2), "to": Vector2i(1, -2), "height": 40.0, "speed": 3.1, "color": Color(0.86, 0.58, 0.34)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(0, 1), "height": 40.0, "speed": 2.2, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.83, 0.38, 0.28)},
		{"from": Vector2i(2, -1), "to": Vector2i(2, 1), "height": 72.0, "speed": 2.0, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.76, 0.30, 0.22)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-1, 1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(1, 0), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
