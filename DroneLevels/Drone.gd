# Drone.gd
extends CharacterBody3D

const GRID_SIZE = 32
const MOVE_SPEED = 1.0
var is_executing = false
var current_tween: Tween
signal drone_moved

func execute_sequence(sequence: Array):
	if is_executing:
		print("❌ Дрон уже выполняет команду!")
		return
	if sequence.is_empty():
		print("❌ Пустая последовательность!")
		return
	print("🚀 Запуск программы дрона")
	is_executing = true
	await execute_actions(sequence)
	is_executing = false
	print("✅ Программа завершена!")

func execute_actions(sequence: Array):
	for i in range(sequence.size()):
		var action = sequence[i]
		print("🎯 Выполняю команду ", i + 1, "/", sequence.size(), ": ", get_direction_name(action))
		await perform_grid_movement(action)

func get_direction_name(direction: int) -> String:
	match direction:
		0: return "Вперед"
		1: return "Назад" 
		2: return "Влево"
		3: return "Вправо"
		4: return "Вверх"
		5: return "Вниз"
		_: return "Неизвестно"

func perform_grid_movement(direction: int):
	var start_position = global_position
	var target_position = global_position
	
	match direction:
		0: target_position.z -= GRID_SIZE
		1: target_position.z += GRID_SIZE
		2: target_position.x -= GRID_SIZE
		3: target_position.x += GRID_SIZE
		4: target_position.y += GRID_SIZE
		5: target_position.y = max(target_position.y - GRID_SIZE, GRID_SIZE)
	
	print("📍 Двигаюсь из ", vector3_to_str(start_position), " в ", vector3_to_str(target_position))
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", target_position, MOVE_SPEED)
	await current_tween.finished
	drone_moved.emit()
	print("✅ Достигнута позиция: ", vector3_to_str(global_position))
	await get_tree().create_timer(0.2).timeout

func vector3_to_str(vec: Vector3) -> String:
	return "(%d, %d, %d)" % [vec.x, vec.y, vec.z]

func stop_execution():
	is_executing = false
	if current_tween:
		current_tween.kill()
	print("🛑 Выполнение программы остановлено")
