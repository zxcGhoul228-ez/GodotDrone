extends CharacterBody3D

const GRID_SIZE = 32
const MOVE_SPEED = 1.0

var is_executing = false
var current_tween: Tween
var start_position: Vector3

# ПРОПЕЛЛЕРЫ - ТОЧНЫЙ ПОИСК ДЛЯ КВАДРОКОПТЕРА
var propellers: Array[MeshInstance3D] = []
var is_propellers_rotating: bool = false
var current_propeller_speed: float = 0.0
var target_propeller_speed: float = 0.0
var propeller_acceleration: float = 180.0
var propeller_deceleration: float = 360.0
var max_propeller_speed: float = 720.0

# Границы сетки
var boundary_min: Vector3
var boundary_max: Vector3

signal program_finished(success: bool)
signal drone_moved

func _ready():
	# Ждем полной инициализации позиции
	await get_tree().process_frame
	start_position = global_position
	
	# ДОБАВЛЯЕМ КОЛЛИЗИЮ ЕСЛИ ЕЁ НЕТ
	add_collision_shape()
	
	# ТОЧНЫЙ ПОИСК ПРОПЕЛЛЕРОВ ДЛЯ КВАДРОКОПТЕРА
	find_propellers_for_quadcopter()
	print("🚁 Дрон готов, стартовая позиция: ", vector3_to_str(start_position))
	print("🌀 Найдено пропеллеров: ", propellers.size())

# ФУНКЦИЯ ДОБАВЛЕНИЯ КОЛЛИЗИИ
func add_collision_shape():
	if has_collision():
		print("✅ Коллизия дрона уже существует")
		return
	
	print("🛡️ Добавляем коллизию дрону...")
	
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 1.5
	shape.height = 1.0
	
	collision.shape = shape
	collision.name = "DroneCollision"
	
	add_child(collision)
	
	if get_tree().edited_scene_root:
		collision.owner = get_tree().edited_scene_root
	
	print("✅ Коллизия добавлена")

# ПРОВЕРКА НАЛИЧИЯ КОЛЛИЗИИ
func has_collision() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false

# СПЕЦИАЛЬНЫЙ ПОИСК ДЛЯ КВАДРОКОПТЕРА (4 ПРОПЕЛЛЕРА)
func find_propellers_for_quadcopter():
	propellers.clear()
	await get_tree().create_timer(0.2).timeout
	
	print("🎯 Специальный поиск пропеллеров для квадрокоптера...")
	
	# Метод 1: Поиск по именам и структуре
	find_propellers_by_quadcopter_structure(self)
	
	# Метод 2: Если нашли не 4 пропеллера, используем альтернативный метод
	if propellers.size() != 4:
		print("⚠️ Найдено ", propellers.size(), " пропеллеров вместо 4, используем альтернативный поиск")
		find_propellers_alternative_quadcopter()
	
	# Метод 3: Если все еще не 4, ищем по характерным признакам
	if propellers.size() != 4:
		print("⚠️ Все еще не 4 пропеллера, используем точный поиск по характеристикам")
		find_propellers_by_exact_characteristics()
	
	print("✅ Финальный результат: ", propellers.size(), " пропеллеров")
	
	# Отладочная информация
	for i in range(propellers.size()):
		var prop = propellers[i]
		print("   Пропеллер ", i + 1, ": ", prop.name, " (расстояние: ", prop.global_position.distance_to(global_position), ")")

# ПОИСК ПО СТРУКТУРЕ КВАДРОКОПТЕРА
func find_propellers_by_quadcopter_structure(node: Node):
	for child in node.get_children():
		if child is Node3D:
			# Проверяем, является ли этот узел пропеллером квадрокоптера
			if is_quadcopter_propeller(child):
				var meshes = find_propeller_meshes(child)
				for mesh in meshes:
					if not propellers.has(mesh):
						propellers.append(mesh)
						print("✅ Найден пропеллер квадрокоптера: ", child.name, " -> ", mesh.name)
			
			# Рекурсивный поиск
			find_propellers_by_quadcopter_structure(child)

# ХАРАКТЕРНЫЕ ПРИЗНАКИ ПРОПЕЛЛЕРА КВАДРОКОПТЕРА
func is_quadcopter_propeller(node: Node3D) -> bool:
	var node_name = node.name.to_lower()
	
	# Признак 1: Имя содержит propeller, rotor, blade или винт
	var has_propeller_name = (
		"propeller" in node_name or 
		"rotor" in node_name or 
		"blade" in node_name or
		"винт" in node_name or
		"пропеллер" in node_name
	)
	
	# Признак 2: Расположение на характерных позициях квадрокоптера
	var is_on_quadcopter_position = is_on_quadcopter_arm(node.global_position)
	
	# Признак 3: Расстояние от центра - пропеллеры на периферии
	var distance_from_center = node.global_position.distance_to(global_position)
	var is_on_periphery = distance_from_center > 5.0 and distance_from_center < 15.0
	
	# Признак 4: Высота - пропеллеры обычно выше центра
	var is_above_center = node.global_position.y > global_position.y + 0.5
	
	# Для квадрокоптера должны выполняться минимум 3 признака
	var score = 0
	if has_propeller_name: score += 2
	if is_on_quadcopter_position: score += 2
	if is_on_periphery: score += 1
	if is_above_center: score += 1
	
	return score >= 3

# ПРОВЕРКА РАСПОЛОЖЕНИЯ НА ЛУЧАХ КВАДРОКОПТЕРА
func is_on_quadcopter_arm(position: Vector3) -> bool:
	var local_pos = position - global_position
	local_pos.y = 0  # Игнорируем высоту
	
	var angle = atan2(local_pos.z, local_pos.x)
	var distance = local_pos.length()
	
	# Квадрокоптер имеет 4 луча под углами 45°, 135°, 225°, 315°
	var quadcopter_angles = [PI/4, 3*PI/4, 5*PI/4, 7*PI/4]
	
	for target_angle in quadcopter_angles:
		var angle_diff = abs(angle - target_angle)
		angle_diff = min(angle_diff, 2*PI - angle_diff)
		
		# Допуск ±15 градусов
		if angle_diff < PI/12 and distance > 6.0 and distance < 12.0:
			return true
	
	return false

# ПОИСК МЕШЕЙ ПРОПЕЛЛЕРОВ В УЗЛЕ
func find_propeller_meshes(node: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	
	for child in node.get_children():
		if child is MeshInstance3D:
			# Проверяем, что это именно пропеллер (а не двигатель или рама)
			if is_propeller_mesh(child):
				meshes.append(child)
	
	return meshes

# ПРИЗНАКИ МЕША ПРОПЕЛЛЕРА
func is_propeller_mesh(mesh: MeshInstance3D) -> bool:
	# Пропеллеры обычно:
	# - Имеют тонкую плоскую форму
	# - Расположены выше других деталей
	# - Имеют характерную форму лопастей
	
	# Проверяем масштаб - пропеллеры обычно плоские (маленький scale.y)
	var is_flat = mesh.scale.y < 0.5
	
	# Проверяем положение - пропеллеры обычно выше других деталей двигателя
	var is_high = mesh.global_position.y > global_position.y + 1.0
	
	# Проверяем имя меша
	var mesh_name = ""
	if mesh.mesh:
		mesh_name = mesh.mesh.resource_name.to_lower()
	var has_propeller_mesh_name = (
		"propeller" in mesh_name or 
		"blade" in mesh_name or
		"винт" in mesh_name
	)
	
	return (is_flat and is_high) or has_propeller_mesh_name

# АЛЬТЕРНАТИВНЫЙ ПОИСК ДЛЯ КВАДРОКОПТЕРА
func find_propellers_alternative_quadcopter():
	print("🔍 Альтернативный поиск для квадрокоптера...")
	
	# Ищем все меши в сцене
	var all_meshes: Array[MeshInstance3D] = []
	find_all_mesh_instances(self, all_meshes)
	
	# Фильтруем по характерным признакам пропеллеров квадрокоптера
	var candidate_propellers: Array[MeshInstance3D] = []
	
	for mesh in all_meshes:
		if is_quadcopter_propeller_mesh(mesh):
			candidate_propellers.append(mesh)
	
	# Если нашли 4 кандидата - отлично!
	if candidate_propellers.size() == 4:
		propellers = candidate_propellers
		print("✅ Найдено 4 пропеллера альтернативным методом")
	else:
		# Иначе берем 4 самых подходящих
		candidate_propellers.sort_custom(sort_propellers_by_suitability)
		propellers = candidate_propellers.slice(0, min(4, candidate_propellers.size()))
		print("✅ Выбрано ", propellers.size(), " наиболее подходящих пропеллеров")

# ХАРАКТЕРНЫЕ ПРИЗНАКИ МЕША ПРОПЕЛЛЕРА КВАДРОКОПТЕРА
func is_quadcopter_propeller_mesh(mesh: MeshInstance3D) -> bool:
	var distance = mesh.global_position.distance_to(global_position)
	var is_on_periphery = distance > 6.0 and distance < 12.0
	
	var is_flat = mesh.scale.y < 0.3  # Очень плоский
	var is_high = mesh.global_position.y > global_position.y + 1.5  # Высоко расположен
	
	var is_on_arm = is_on_quadcopter_arm(mesh.global_position)
	
	return is_on_periphery and is_flat and is_high and is_on_arm

# СОРТИРОВКА ПРОПЕЛЛЕРОВ ПО ПОДХОДЯЩЕСТИ
func sort_propellers_by_suitability(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	# Более подходящие пропеллеры: более плоские, выше, на правильных позициях
	var score_a = calculate_propeller_score(a)
	var score_b = calculate_propeller_score(b)
	return score_a > score_b

func calculate_propeller_score(mesh: MeshInstance3D) -> float:
	var score = 0.0
	
	# Плоскость (чем более плоский, тем лучше)
	score += (1.0 - min(mesh.scale.y, 1.0)) * 10
	
	# Высота (чем выше, тем лучше)
	score += max(0, mesh.global_position.y - global_position.y) * 5
	
	# Положение на луче (чем ближе к идеальной позиции, тем лучше)
	if is_on_quadcopter_arm(mesh.global_position):
		score += 20
	
	# Расстояние (оптимальное расстояние 8-10 единиц)
	var distance = mesh.global_position.distance_to(global_position)
	var distance_score = 1.0 - abs(distance - 9.0) / 9.0  # 9.0 - идеальное расстояние
	score += distance_score * 10
	
	return score

# ТОЧНЫЙ ПОИСК ПО ХАРАКТЕРИСТИКАМ
func find_propellers_by_exact_characteristics():
	print("🎯 Точный поиск по характеристикам...")
	
	# Создаем список всех мешей
	var all_meshes: Array[MeshInstance3D] = []
	find_all_mesh_instances(self, all_meshes)
	
	# Ищем 4 меша, которые наиболее соответствуют пропеллерам квадрокоптера
	var best_propellers: Array[MeshInstance3D] = []
	
	for mesh in all_meshes:
		var score = calculate_propeller_score(mesh)
		
		# Если счет высокий, добавляем в кандидаты
		if score > 15.0:
			best_propellers.append(mesh)
	
	# Сортируем по убыванию счета
	best_propellers.sort_custom(sort_propellers_by_suitability)
	
	# Берем только 4 лучших
	propellers = best_propellers.slice(0, min(4, best_propellers.size()))
	
	print("✅ Найдено ", propellers.size(), " пропеллеров точным поиском")

# ПОИСК ВСЕХ MESHINSTANCE3D В СЦЕНЕ
func find_all_mesh_instances(node: Node, collection: Array[MeshInstance3D]):
	for child in node.get_children():
		if child is MeshInstance3D:
			collection.append(child)
		find_all_mesh_instances(child, collection)

# ЗАПУСК ПРОПЕЛЛЕРОВ С ПЛАВНЫМ РАЗГОНОМ
func start_propellers():
	if is_propellers_rotating:
		return
	
	is_propellers_rotating = true
	target_propeller_speed = max_propeller_speed
	print("🌀 Запуск вращения ", propellers.size(), " пропеллеров")

# ОСТАНОВКА ПРОПЕЛЛЕРОВ С ПЛАВНЫМ ЗАМЕДЛЕНИЕМ
func stop_propellers():
	if not is_propellers_rotating:
		return
	
	is_propellers_rotating = false
	target_propeller_speed = 0.0
	print("🛑 Остановка вращения пропеллеров")

# ВРАЩЕНИЕ ПРОПЕЛЛЕРОВ С ПЛАВНЫМ ИЗМЕНЕНИЕМ СКОРОСТИ
func _process(delta):
	# Плавное изменение скорости пропеллеров
	if current_propeller_speed < target_propeller_speed:
		# Разгон
		current_propeller_speed += propeller_acceleration * delta
		current_propeller_speed = min(current_propeller_speed, target_propeller_speed)
	elif current_propeller_speed > target_propeller_speed:
		# Замедление
		current_propeller_speed -= propeller_deceleration * delta
		current_propeller_speed = max(current_propeller_speed, target_propeller_speed)
	
	# Вращаем пропеллеры с текущей скоростью
	if current_propeller_speed > 0:
		for propeller in propellers:
			if is_instance_valid(propeller):
				propeller.rotate_y(deg_to_rad(current_propeller_speed * delta))

# ОСТАЛЬНЫЕ ФУНКЦИИ БЕЗ ИЗМЕНЕНИЙ
func set_boundaries(min_bound: Vector3, max_bound: Vector3):
	boundary_min = min_bound
	boundary_max = max_bound

func can_move_to(position: Vector3) -> bool:
	return (position.x >= boundary_min.x and position.x <= boundary_max.x and
			position.z >= boundary_min.z and position.z <= boundary_max.z and
			position.y >= boundary_min.y and position.y <= boundary_max.y)

func return_to_start():
	print("🔄 Возвращаю дрона на стартовую позицию...")
	
	if current_tween:
		current_tween.kill()
	
	is_executing = false
	stop_propellers()
	
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", start_position, MOVE_SPEED * 1.5)
	await current_tween.finished
	
	print("✅ Дрон вернулся на стартовую позицию")
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
	
	# ЗАПУСКАЕМ ПРОПЕЛЛЕРЫ С ПЛАВНЫМ РАЗГОНОМ
	start_propellers()
	start_position = global_position
	
	var success = await execute_actions(sequence)
	is_executing = false
	
	# ОСТАНАВЛИВАЕМ ПРОПЕЛЛЕРЫ С ПЛАВНЫМ ЗАМЕДЛЕНИЕМ
	stop_propellers()
	
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
	
	await get_tree().create_timer(0.5).timeout
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
	
	match direction:
		0: target_position.z -= GRID_SIZE
		1: target_position.z += GRID_SIZE
		2: target_position.x -= GRID_SIZE
		3: target_position.x += GRID_SIZE
		4: target_position.y += GRID_SIZE
		5: target_position.y = max(target_position.y - GRID_SIZE, boundary_min.y)
	
	if not can_move_to(target_position):
		print("❌ Движение невозможно: позиция за пределами сетки")
		return false
	
	print("📍 Двигаюсь из ", vector3_to_str(start_pos), " в ", vector3_to_str(target_position))
	
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", target_position, MOVE_SPEED)
	await current_tween.finished
	
	drone_moved.emit()
	print("✅ Достигнута позиция: ", vector3_to_str(global_position))
	
	await get_tree().create_timer(0.1).timeout
	return true

func vector3_to_str(vec: Vector3) -> String:
	return "(%d, %d, %d)" % [vec.x, vec.y, vec.z]

func stop_execution():
	print("🛑 Выполнение программы остановлено")
	is_executing = false
	stop_propellers()
	
	if current_tween:
		current_tween.kill()
	
	await return_to_start()
	program_finished.emit(false)
