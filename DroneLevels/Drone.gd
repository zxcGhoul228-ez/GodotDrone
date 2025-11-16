extends CharacterBody3D

const GRID_SIZE = 32
const MOVE_SPEED = 1.0

var is_executing = false
var current_tween: Tween
var start_position: Vector3

# Границы сетки
var boundary_min: Vector3
var boundary_max: Vector3

signal program_finished(success: bool)
signal drone_moved

func _ready():
	# Ждем полной инициализации позиции
	await get_tree().process_frame
	# Сохраняем ТЕКУЩУЮ позицию как стартовую (уже отцентрованную)
	start_position = global_position
	print("🚁 Дрон готов, стартовая позиция: ", vector3_to_str(start_position))

# Функция для установки границ из DroneScene
func set_boundaries(min_bound: Vector3, max_bound: Vector3):
	boundary_min = min_bound
	boundary_max = max_bound
	print("🚁 Границы дрона установлены: от ", vector3_to_str(boundary_min), " до ", vector3_to_str(boundary_max))

# Проверка возможности движения в указанную позицию
func can_move_to(position: Vector3) -> bool:
	return (position.x >= boundary_min.x and position.x <= boundary_max.x and
			position.z >= boundary_min.z and position.z <= boundary_max.z and
			position.y >= boundary_min.y and position.y <= boundary_max.y)

func return_to_start():
	print("🔄 Возвращаю дрона на стартовую позицию...")
	
	# Останавливаем текущее движение
	if current_tween:
		current_tween.kill()
	
	is_executing = false
	
	# Плавно возвращаем на сохраненную стартовую позицию
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", start_position, MOVE_SPEED * 1.5)
	await current_tween.finished
	
	print("✅ Дрон вернулся на стартовую позицию: ", vector3_to_str(global_position))
	drone_moved.emit()

func execute_sequence(sequence: Array):
	if is_executing:
		print("❌ Дрон уже выполняет команду!")
		return
	if sequence.is_empty():
		print("❌ Пустая последовательность!")
		program_finished.emit(false)
		return
		
	print("🚀 Запуск программы дрона из ", sequence.size(), " команд")
	is_executing = true
	
	# Сохраняем текущую позицию как стартовую для этой попытки
	start_position = global_position
	print("📍 Стартовая позиция для этой попытки: ", vector3_to_str(start_position))
	
	# ВОССТАНАВЛИВАЕМ старую логику выполнения
	var success = await execute_actions(sequence)
	is_executing = false
	
	if not success:
		print("❌ Программа завершена неудачно, возвращаю дрона на старт")
		await return_to_start()
	else:
		print("✅ Программа завершена успешно!")
	
	program_finished.emit(success)

func execute_actions(sequence: Array) -> bool:
	for i in range(sequence.size()):
		var action = sequence[i]
		print("🎯 Выполняю команду ", i + 1, "/", sequence.size(), ": ", get_direction_name(action))
		
		var move_success = await perform_grid_movement(action)
		if not move_success:
			print("❌ Движение невозможно - достигнут предел сетки!")
			return false
	
	# Даем время на обработку коллизий после последнего движения
	await get_tree().create_timer(0.5).timeout
	
	# В Level1 успех определяется через коллизию с целью
	# Здесь просто возвращаем false, а настоящий успех определится в _on_target_body_entered
	return false

func get_direction_name(direction: int) -> String:
	match direction:
		0: return "Вперед"
		1: return "Назад" 
		2: return "Влево"
		3: return "Вправо"
		4: return "Вверх"
		5: return "Вниз"
		_: return "Неизвестно"

func perform_grid_movement(direction: int) -> bool:
	var start_pos = global_position
	var target_position = global_position
	
	# Двигаемся на целую клетку GRID_SIZE, сохраняя центрирование
	match direction:
		0: target_position.z -= GRID_SIZE  # Вперед
		1: target_position.z += GRID_SIZE  # Назад
		2: target_position.x -= GRID_SIZE  # Влево
		3: target_position.x += GRID_SIZE  # Вправо
		4: target_position.y += GRID_SIZE  # Вверх
		5: target_position.y = max(target_position.y - GRID_SIZE, boundary_min.y)  # Вниз (не ниже минимальной границы)
	
	# Проверяем, можно ли двигаться в целевую позицию
	if not can_move_to(target_position):
		print("❌ Движение невозможно: позиция ", vector3_to_str(target_position), " за пределами сетки")
		return false
	
	print("📍 Двигаюсь из ", vector3_to_str(start_pos), " в ", vector3_to_str(target_position))
	
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", target_position, MOVE_SPEED)
	await current_tween.finished
	
	drone_moved.emit()
	print("✅ Достигнута позиция: ", vector3_to_str(global_position))
	
	# Короткая пауза между движениями
	await get_tree().create_timer(0.1).timeout
	return true

func vector3_to_str(vec: Vector3) -> String:
	return "(%d, %d, %d)" % [vec.x, vec.y, vec.z]

func stop_execution():
	print("🛑 Выполнение программы остановлено")
	is_executing = false
	
	if current_tween:
		current_tween.kill()
	
	# При остановке возвращаем на старт
	await return_to_start()
	
	program_finished.emit(false)
