# Уровень 15: финальный маршрут кампании, максимально плотный, но честный.
# Задача: пройти самую длинную комбинацию высоты, объезда и тайминга без случайных решений.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 15
	level_title = "Финал"
	level_hint = "Самый сложный маршрут: длинный, высокий и с несколькими финальными окнами."
	level_description = "Финальный уровень требует полной концентрации. Здесь нужно точно пройти весь маршрут, сохранить высоту и не сорваться на последних окнах."
	completion_text = "Легендарно. Кампания пройдена."
	start_grid = Vector2i(-7, -5)
	start_height = 8.0
	target_grid = Vector2i(7, 6)
	target_height = 136.0
	moving_platforms_data = [
		{"from": Vector2i(-4, -4), "to": Vector2i(-2, -4), "height": 40.0, "speed": 2.0, "color": Color(0.90, 0.62, 0.35)},
		{"from": Vector2i(-1, -1), "to": Vector2i(1, -1), "height": 72.0, "speed": 1.8, "color": Color(0.93, 0.72, 0.44)},
		{"from": Vector2i(2, 2), "to": Vector2i(4, 2), "height": 104.0, "speed": 1.6, "color": Color(0.96, 0.76, 0.46)},
		{"from": Vector2i(5, 4), "to": Vector2i(6, 4), "height": 136.0, "speed": 1.4, "color": Color(0.98, 0.80, 0.48)}
	]
	moving_obstacles_data = [
		{"from": Vector2i(-3, -3), "to": Vector2i(-3, -1), "height": 40.0, "speed": 1.4, "size": Vector3(6.0, 28.0, GRID_SIZE - 8.0), "color": Color(0.84, 0.37, 0.27)},
		{"from": Vector2i(-1, -2), "to": Vector2i(1, -2), "height": 72.0, "speed": 1.3, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.76, 0.31, 0.23)},
		{"from": Vector2i(1, 0), "to": Vector2i(1, 2), "height": 104.0, "speed": 1.2, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.89, 0.45, 0.31)},
		{"from": Vector2i(3, 1), "to": Vector2i(5, 1), "height": 104.0, "speed": 1.1, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.95, 0.55, 0.35)},
		{"from": Vector2i(4, 3), "to": Vector2i(4, 5), "height": 136.0, "speed": 1.0, "size": Vector3(6.0, 24.0, GRID_SIZE - 8.0), "color": Color(0.97, 0.60, 0.38)},
		{"from": Vector2i(6, 5), "to": Vector2i(4, 5), "height": 136.0, "speed": 0.95, "size": Vector3(GRID_SIZE - 8.0, 24.0, 6.0), "color": Color(0.99, 0.63, 0.40)}
	]
	static_obstacles_data = [
		{"grid": Vector2i(-5, -4), "height": 0.0, "size": Vector3(GRID_SIZE, 24.0, GRID_SIZE)},
		{"grid": Vector2i(-4, -1), "height": 8.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(-2, 1), "height": 40.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(0, 0), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(2, -1), "height": 72.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(3, 3), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(5, 2), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)},
		{"grid": Vector2i(6, 4), "height": 104.0, "size": Vector3(GRID_SIZE, 28.0, GRID_SIZE)}
	]
