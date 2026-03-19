# Уровень 4: первая динамика и простое окно по таймингу.
# Задача: дождаться безопасного момента и пройти через движущуюся преграду.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 4
	level_title = "Тайминг"
	level_hint = "Подберите момент для прохода и не заденьте движущуюся преграду."
	level_description = "В центре появился медленный движущийся барьер. Маршрут по-прежнему короткий, но теперь важен правильный момент входа."
	completion_text = "Отлично. Первый тайминг выполнен чисто."
	start_grid = Vector2i(-3, -2)
	start_height = 8.0
	target_grid = Vector2i(2, 2)
	target_height = 40.0
	moving_platforms_data = []
	moving_obstacles_data = [
		{"from": Vector2i(0, -1), "to": Vector2i(0, 1), "height": 8.0, "speed": 2.9, "size": Vector3(6.0, 26.0, GRID_SIZE - 8.0), "color": Color(0.82, 0.39, 0.28)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-1, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(1, 1), "height": 8.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)}
	]
