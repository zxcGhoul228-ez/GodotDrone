# Уровень 1: чистое знакомство с клеточным полетом без препятствий.
# Задача: просто довести дрон до цели и освоиться с шагом по сетке.
extends "res://app/flight/levels/LevelAdvanced.gd"

func _init():
	level_number = 1
	level_title = "Разминка"
	level_hint = "Пройдите к цели по открытому полю без препятствий."
	level_description = "Первый уровень полностью безопасен. Спокойно проведите дрон по клеткам и остановитесь на светящейся цели."
	completion_text = "Отличное начало. Базовое управление освоено."
	start_grid = Vector2i(-2, -2)
	start_height = 8.0
	target_grid = Vector2i(1, 1)
	target_height = 8.0
	moving_platforms_data = []
	moving_obstacles_data = []
	static_obstacles_data = []
