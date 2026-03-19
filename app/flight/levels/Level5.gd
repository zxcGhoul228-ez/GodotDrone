# Уровень 5: связка из объезда и одного динамического окна.
# Задача: сначала уйти в сторону от колонн, затем пройти между движением и статикой.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 5
	level_title = "Связка"
	level_hint = "Сначала выберите маршрут, потом поймайте момент для прохода."
	level_description = "Маршрут стал длиннее: одна ошибка в позиционировании быстро заводит дрон в тупик между колоннами и движением."
	completion_text = "Хорошо. Ты уже уверенно читаешь поле."
	start_grid = Vector2i(-3, -2)
	start_height = 8.0
	target_grid = Vector2i(3, 2)
	target_height = 40.0
	moving_platforms_data = []
	moving_obstacles_data = [
		{"from": Vector2i(0, 0), "to": Vector2i(2, 0), "height": 8.0, "speed": 2.5, "size": Vector3(GRID_SIZE - 8.0, 22.0, 6.0), "color": Color(0.86, 0.42, 0.30)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-1, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(1, 1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)}
	]
