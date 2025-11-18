extends CharacterBody3D

const GRID_SIZE = 32
const MOVE_SPEED = 1.0

var is_executing = false
var current_tween: Tween
var start_position: Vector3

# ПРОПЕЛЛЕРЫ - ТОЧЕЧНЫЙ ПОИСК
var propellers: Array[Node3D] = []
var is_propellers_rotating: bool = false
var propeller_rotation_speed: float = 360.0

# Границы сетки
var boundary_min: Vector3
var boundary_max: Vector3

signal program_finished(success: bool)
signal drone_moved

func _ready():
	# Ждем полной инициализации позиции
	await get_tree().process_frame
	start_position = global_position
	
	# ТОЧЕЧНЫЙ ПОИСК ПРОПЕЛЛЕРОВ
	find_propellers_precise()
	print("🚁 Дрон готов, стартовая позиция: ", vector3_to_str(start_position))
	print("🌀 Найдено пропеллеров: ", propellers.size())

# ТОЧЕЧНЫЙ ПОИСК ТОЛЬКО РЕАЛЬНЫХ ПРОПЕЛЛЕРОВ
func find_propellers_precise():
	propellers.clear()
	
	# Даем время на полную инициализацию сцены
	await get_tree().create_timer(0.2).timeout
	
	print("🎯 Точечный поиск пропеллеров...")
	
	# Метод 1: Поиск по именам мешей (самый надежный)
	find_propellers_by_mesh_name(self)
	
	# Метод 2: Поиск по именам узлов (резервный)
	if propellers.is_empty():
		find_propellers_by_node_name(self)
	
	# Метод 3: Поиск по структуре (очень осторожный)
	if propellers.is_empty():
		find_propellers_by_careful_structure()
	
	print("✅ Финальный результат: ", propellers.size(), " пропеллеров")

# ПОИСК ПО ИМЕНАМ МЕШЕЙ - САМЫЙ ТОЧНЫЙ
func find_propellers_by_mesh_name(node: Node):
	for child in node.get_children():
		if child is Node3D:
			# Проверяем всех детей этого узла на наличие мешей пропеллеров
			check_node_for_propeller_meshes(child)
			
			# Рекурсивно проверяем детей
			find_propellers_by_mesh_name(child)

func check_node_for_propeller_meshes(node: Node3D):
	var has_propeller_mesh = false
	
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance = child as MeshInstance3D
			if mesh_instance.mesh:
				var mesh_name = mesh_instance.mesh.resource_name.to_lower()
				
				# ТОЛЬКО если имя меша содержит "propeller"
				if "propeller" in mesh_name:
					has_propeller_mesh = true
					break
	
	# Если у узла есть меш пропеллера, добавляем сам узел
	if has_propeller_mesh:
		if not propellers.has(node):
			propellers.append(node)
			print("✅ Найден пропеллер по мешу: ", node.name)

# ПОИСК ПО ИМЕНАМ УЗЛОВ - РЕЗЕРВНЫЙ
func find_propellers_by_node_name(node: Node):
	for child in node.get_children():
		if child is Node3D:
			var node_name = child.name.to_lower()
			
			# Ищем узлы с именами содержащими propeller
			if "propeller" in node_name:
				if not propellers.has(child):
					propellers.append(child)
					print("✅ Найден пропеллер по имени узла: ", child.name)
			
			# Рекурсивно проверяем детей
			find_propellers_by_node_name(child)

# ОСТОРОЖНЫЙ ПОИСК ПО СТРУКТУРЕ
func find_propellers_by_careful_structure():
	print("🔍 Осторожный поиск по структуре...")
	
	# Собираем только Node3D с мешами
	var nodes_with_meshes = []
	find_nodes_with_meshes(self, nodes_with_meshes)
	
	# Фильтруем по характерным признакам пропеллеров
	for node in nodes_with_meshes:
		if is_likely_propeller(node):
			if not propellers.has(node):
				propellers.append(node)
				print("✅ Найден вероятный пропеллер: ", node.name)

func find_nodes_with_meshes(node: Node, collection: Array):
	for child in node.get_children():
		if child is Node3D:
			# Проверяем, есть ли у этого Node3D меши
			if has_mesh_children(child):
				collection.append(child)
			find_nodes_with_meshes(child, collection)

func has_mesh_children(node: Node3D) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			return true
	return false

func is_likely_propeller(node: Node3D) -> bool:
	# Пропеллеры обычно маленькие
	if node.scale.length() > 2.0:
		return false
	
	# Пропеллеры обычно расположены на некотором расстоянии от центра
	var distance_from_center = node.global_position.distance_to(global_position)
	if distance_from_center < 0.5 or distance_from_center > 10.0:
		return false
	
	# Пропеллеры обычно имеют вращательную симметрию
	# (это сложно проверить, поэтому пропускаем)
	
	return true

# ЗАПУСК ПРОПЕЛЛЕРОВ
func start_propellers():
	if is_propellers_rotating:
		return
	
	is_propellers_rotating = true
	propeller_rotation_speed = 360.0
	print("🌀 Запуск вращения ", propellers.size(), " пропеллеров")

# ОСТАНОВКА ПРОПЕЛЛЕРОВ
func stop_propellers():
	if not is_propellers_rotating:
		return
	
	is_propellers_rotating = false
	propeller_rotation_speed = 0.0
	print("🛑 Остановка вращения пропеллеров")

# ВРАЩЕНИЕ ПРОПЕЛЛЕРОВ
func _process(delta):
	if is_propellers_rotating:
		for propeller in propellers:
			if is_instance_valid(propeller):
				propeller.rotate_y(deg_to_rad(propeller_rotation_speed * delta))

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
	
	# ЗАПУСКАЕМ ПРОПЕЛЛЕРЫ
	start_propellers()
	start_position = global_position
	
	var success = await execute_actions(sequence)
	is_executing = false
	
	# ОСТАНАВЛИВАЕМ ПРОПЕЛЛЕРЫ
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
