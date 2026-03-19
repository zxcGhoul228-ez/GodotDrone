# Уровень 10: середина кампании, где ошибочный порядок команд уже критичен.
# Задача: пройти длинную трассу с чередованием высоты и тайминга.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 10
	level_title = "Смена темпа"
	level_hint = "Высота, обход и тайминг теперь чередуются почти без пауз."
	level_description = "Маршрут стал заметно длиннее. Здесь важно не только пройти опасные клетки, но и удержать правильный ритм команд."
	completion_text = "Отлично. Полет уже ощущается собранным и взрослым."
	start_grid = Vector2i(-4, -3)
	start_height = 8.0
	target_grid = Vector2i(5, 3)
	target_height = 104.0
	moving_platforms_data = [
		{"from": Vector2i(-2, -2), "to": Vector2i(0, -2), "height": 40.0, "speed": 2.7, "color": Color(0.90, 0.61, 0.35)},
		{"from": Vector2i(1, 1), "to": Vector2i(3, 1), "height": 72.0, "speed": 2.4, "color": Color(0.94, 0.72, 0.44)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-1, -1), "to": Vector2i(-1, 1), "height": 40.0, "speed": 1.9, "size": Vector3(6.0, 26.0, GRID_SIZE - 8.0), "color": Color(0.82, 0.35, 0.26)},
		{"from": Vector2i(1, 0), "to": Vector2i(3, 0), "height": 72.0, "speed": 1.8, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.75, 0.31, 0.23)},
		{"from": Vector2i(4, 1), "to": Vector2i(4, 3), "height": 104.0, "speed": 1.7, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.90, 0.45, 0.31)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-2, -1), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(0, -1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(0, 2), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, 2), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(3, -1), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
