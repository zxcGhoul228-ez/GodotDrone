extends CharacterBody3D

const GRID_SIZE = 32
const MOVE_SPEED = 1.0

var is_executing = false
var current_tween: Tween
var start_position: Vector3

# ПРОПЕЛЛЕРЫ
var propellers: Array[Node3D] = []
var is_propellers_rotating: bool = false
var current_propeller_speed: float = 0.0
var target_propeller_speed: float = 0.0
var propeller_acceleration: float = 720.0
var max_propeller_speed: float = 2160.0

signal program_finished(success: bool)
signal drone_moved

func _ready():
	await get_tree().process_frame
	start_position = global_position
	
	# УВЕЛИЧИВАЕМ РАЗМЕР ДРОНА В 2 РАЗА
	scale = Vector3(6.0, 6.0, 6.0)
	print("🚁 Масштабирую дрон: ", scale)
	
	# ГАРАНТИРОВАННЫЙ ПОИСК ПРОПЕЛЛЕРОВ
	find_propellers_guaranteed()
	
	print("🚁 Дрон готов, масштаб: ", scale)
	print("🌀 Найдено пропеллеров: ", propellers.size())

# ГАРАНТИРОВАННЫЙ ПОИСК ПРОПЕЛЛЕРОВ
func find_propellers_guaranteed():
	propellers.clear()
	
	# Способ 1: Поиск по группе
	var group_propellers = get_tree().get_nodes_in_group("drone_propellers")
	for node in group_propellers:
		if node is Node3D and is_instance_valid(node):
			if not propellers.has(node):
				propellers.append(node)
				print("✅ Найден по группе: ", node.name)
	
	# Способ 2: Поиск по метаданным
	if propellers.size() == 0:
		search_by_metadata(self)
	
	# Способ 3: Последний шанс - ищем все Node3D и MeshInstance3D
	if propellers.size() == 0:
		find_all_3d_nodes(self)
	
	print("🎯 Итог: ", propellers.size(), " пропеллеров")
	
	# Отладочная информация
	if propellers.size() == 0:
		print("⚠️ ВНИМАНИЕ: пропеллеры не найдены!")
		print_debug_tree(self, 0)

func search_by_metadata(node: Node):
	for child in node.get_children():
		if child is Node3D or child is MeshInstance3D:
			if child.has_meta("is_drone_propeller"):
				if child.get_meta("is_drone_propeller") == true:
					if not propellers.has(child):
						propellers.append(child)
						print("✅ Найден по метаданным: ", child.name)
		search_by_metadata(child)

func find_all_3d_nodes(node: Node):
	for child in node.get_children():
		if child is Node3D or child is MeshInstance3D:
			# Проверяем, похож ли на пропеллер по имени
			var child_name = str(child.name).to_lower()
			if "propeller" in child_name or "винт" in child_name or "пропеллер" in child_name:
				if not propellers.has(child):
					propellers.append(child)
					print("✅ Найден по имени: ", child.name)
		find_all_3d_nodes(child)

func print_debug_tree(node: Node, indent: int):
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + "└─ " + node.name + " (" + node.get_class() + ")")
	
	# Проверяем группы
	if node.has_method("get_groups"):
		var groups = node.get_groups()
		if groups.size() > 0:
			print(indent_str + "   Группы: ", groups)
	
	# Проверяем метаданные
	if node.has_meta("is_drone_propeller"):
		print(indent_str + "   Мета: is_drone_propeller = ", node.get_meta("is_drone_propeller"))
	
	# Рекурсивно для детей
	for child in node.get_children():
		print_debug_tree(child, indent + 1)

# ЗАПУСК ПРОПЕЛЛЕРОВ
func start_propellers():
	if is_propellers_rotating:
		return
	
	is_propellers_rotating = true
	target_propeller_speed = max_propeller_speed
	print("🌀 ЗАПУСК ПРОПЕЛЛЕРОВ")

# ОСТАНОВКА ПРОПЕЛЛЕРОВ
func stop_propellers():
	if not is_propellers_rotating:
		return
	
	is_propellers_rotating = false
	target_propeller_speed = 0.0
	print("🛑 ОСТАНОВКА ПРОПЕЛЛЕРОВ")

# ВРАЩЕНИЕ ПРОПЕЛЛЕРОВ
func _process(delta):
	# Плавное изменение скорости
	if current_propeller_speed < target_propeller_speed:
		current_propeller_speed += propeller_acceleration * delta
		current_propeller_speed = min(current_propeller_speed, target_propeller_speed)
	elif current_propeller_speed > target_propeller_speed:
		current_propeller_speed -= propeller_acceleration * 2 * delta
		current_propeller_speed = max(current_propeller_speed, 0.0)
	
	# Вращение пропеллеров
	if current_propeller_speed > 0.1:
		rotate_propellers(delta)

func rotate_propellers(delta):
	var rotation_angle = deg_to_rad(current_propeller_speed * delta)
	
	for propeller in propellers:
		if is_instance_valid(propeller):
			propeller.rotate_y(rotation_angle)
	
	# Отладочный вывод
	if Engine.get_frames_drawn() % 120 == 0 and propellers.size() > 0 and current_propeller_speed > 100:
		print("🌀 Вращение: ", int(current_propeller_speed), "°/с")

# ВЫПОЛНЕНИЕ ПРОГРАММЫ - ИСПРАВЛЕННЫЙ КОД
func execute_sequence(sequence: Array):
	if is_executing:
		print("❌ Дрон уже выполняет программу!")
		return
	
	print("========================================")
	print("🚀 ЗАПУСК ПРОГРАММЫ")
	print("   Команд: ", sequence.size())
	print("   Пропеллеров: ", propellers.size())
	
	is_executing = true
	
	# ГАРАНТИРОВАННЫЙ ЗАПУСК ПРОПЕЛЛЕРОВ
	start_propellers()
	start_position = global_position
	
	# Ждем раскрутки
	await get_tree().create_timer(0.3).timeout
	print("🌀 Пропеллеры раскручены")
	
	# Выполняем команды
	var success = await execute_actions(sequence)
	
	# Останавливаем пропеллеры
	stop_propellers()
	
	# Ждем остановки
	await get_tree().create_timer(0.3).timeout
	
	is_executing = false
	
	# ВАЖНОЕ ИСПРАВЛЕНИЕ: ВОЗВРАЩАЕМ ДРОНА НА СТАРТ ПРИ НЕУДАЧЕ!
	if not success:
		print("❌ Программа завершена НЕУДАЧНО, возвращаю дрона на старт")
		await return_to_start()
	else:
		print("✅ Программа завершена УСПЕШНО, дрон остается на месте")
	
	print("✅ Программа завершена")
	program_finished.emit(success)

# ВЫПОЛНЕНИЕ КОМАНД
func execute_actions(sequence: Array) -> bool:
	if sequence.is_empty():
		print("⚠️ Пустая программа")
		return false
	
	print("🎯 Выполнение команд")
	
	for i in range(sequence.size()):
		var action = sequence[i]
		var command_name = get_direction_name(action)
		print("   ", i + 1, "/", sequence.size(), ": ", command_name)
		
		var move_success = await perform_movement(action)
		if not move_success:
			print("❌ Ошибка движения")
			return false
		
		await get_tree().create_timer(0.1).timeout
	
	print("📊 Программа выполнена, но цель не достигнута")
	return false  # ВРЕМЕННО: всегда возвращаем false, чтобы тестировать возврат

func get_direction_name(direction: int) -> String:
	match direction:
		0: return "ВПЕРЕД"
		1: return "НАЗАД"
		2: return "ВЛЕВО"
		3: return "ВПРАВО"
		4: return "ВВЕРХ"
		5: return "ВНИЗ"
		_: return "???"

func perform_movement(direction: int) -> bool:
	var target_pos = global_position
	
	match direction:
		0: target_pos.z -= GRID_SIZE
		1: target_pos.z += GRID_SIZE
		2: target_pos.x -= GRID_SIZE
		3: target_pos.x += GRID_SIZE
		4: target_pos.y += GRID_SIZE
		5: target_pos.y -= GRID_SIZE
	
	# Движение
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
	await tween.finished
	
	drone_moved.emit()
	return true

# ОСТАНОВКА
func stop_execution():
	print("🛑 ПРИНУДИТЕЛЬНАЯ ОСТАНОВКА")
	is_executing = false
	stop_propellers()
	
	if current_tween:
		current_tween.kill()
	
	# Принудительный возврат на старт при остановке
	print("↩️ Принудительный возврат на старт")
	await return_to_start()
	
	program_finished.emit(false)

# ВОЗВРАТ НА СТАРТ
func return_to_start():
	print("↩️ ВОЗВРАТ НА СТАРТ")
	
	# Отключаем коллизии дрона на время возврата
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)
	
	stop_propellers()
	
	# Создаем твин для возврата
	var tween = create_tween()
	tween.tween_property(self, "global_position", start_position, MOVE_SPEED * 2)
	await tween.finished
	
	# Включаем коллизии обратно
	set_collision_layer_value(1, true)
	set_collision_mask_value(2, true)
	
	drone_moved.emit()
	print("✅ Дрон вернулся на стартовую позицию")
