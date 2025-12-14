extends CharacterBody3D

var has_reached_target: bool = false
var target_position: Vector3 = Vector3.ZERO
var is_executing = false
var current_tween: Tween
var start_position: Vector3

# ФИЗИКА ДРОНА
var drone_physics: DronePhysics
var flight_behavior: Dictionary = {}
var is_crashed: bool = false
var crash_position: Vector3 = Vector3.ZERO

const GRID_SIZE = 32
const MOVE_SPEED = 1.0

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
	propellers = find_propellers_guaranteed()
	
	print("🚁 Дрон готов, масштаб: ", scale)
	print("🌀 Найдено пропеллеров: ", propellers.size())
	
	# Даже если пропеллеров нет, всё равно инициализируем физику
	init_drone_physics()
	
	# Если пропеллеров нет, показываем предупреждение
	if propellers.size() == 0:
		print("⚠️ ВНИМАНИЕ: Дрон без пропеллеров! Физика может работать некорректно.")
		
		show_imbalance_visualization()
		
	_ensure_collision()


func get_has_reached_target() -> bool:
	return has_reached_target

func set_target_position(pos: Vector3):
	target_position = pos
	print("🎯 Установлена цель: ", target_position)


func init_drone_physics():
	"""Инициализация системы физики дрона"""
	drone_physics = DronePhysics.new()
	add_child(drone_physics)

	# Собираем компоненты дрона
	var frame_node = find_component_by_type("frame")
	var board_node = find_component_by_type("board")
	var motor_nodes = find_all_components_by_type("motor")

	# ==== DEBUG: имена/пути моторов ====
	print("🧩 Motors найдено: ", motor_nodes.size())
	for m in motor_nodes:
		if m and is_instance_valid(m):
			var meta_slot_m = (m.get_meta("motor_slot") if m.has_meta("motor_slot") else "NONE")
			print("   motor node name=", m.name, " class=", m.get_class(), " path=", m.get_path(), " meta_slot=", meta_slot_m)

	# НАХОДИМ ПРОПЕЛЛЕРЫ ЧЕРЕЗ НАШУ ФУНКЦИЮ (если где-то выше она вызывается — ок; иначе можно раскомментить)
	# propellers = find_propellers_guaranteed()

	# ==== DEBUG: имена/пути пропеллеров из member массива ====
	print("🧩 Propellers (member) найдено: ", propellers.size())
	for p in propellers:
		if p and is_instance_valid(p):
			var meta_slot_p = (p.get_meta("motor_slot") if p.has_meta("motor_slot") else "NONE")
			print("   prop node name=", p.name, " class=", p.get_class(), " path=", p.get_path(), " meta_slot=", meta_slot_p, " groups=", p.get_groups())

	# Если пропеллеры не найдены — дополнительно сканим дерево по именам
	if propellers.size() == 0:
		print("🔎 Scan дерева на 'prop'/'motor' по именам:")
		var stack: Array = [self]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n == null or not is_instance_valid(n):
				continue

			for c in n.get_children():
				if c and is_instance_valid(c):
					stack.append(c)

			var nl := str(n.name).to_lower()
			if nl.find("motor") != -1 or nl.find("prop") != -1:
				var meta_slot = (n.get_meta("motor_slot") if n.has_meta("motor_slot") else "NONE")
				print("   node=", n.name, " class=", n.get_class(), " path=", n.get_path(), " meta_slot=", meta_slot, " groups=", n.get_groups())

	# Собираем пропеллеры для физики из member массива
	var propeller_nodes = []
	for propeller in propellers:
		if is_instance_valid(propeller):
			propeller_nodes.append(propeller)

	print("📊 Компоненты для физики:")
	print("   - Рам: ", 1 if frame_node else 0)
	print("   - Плат: ", 1 if board_node else 0)
	print("   - Моторов: ", motor_nodes.size())
	print("   - Пропеллеров: ", propeller_nodes.size())

	# Настраиваем физику
	if drone_physics:
		drone_physics.setup_from_components(
			frame_node,
			board_node,
			motor_nodes,
			propeller_nodes
		)

		flight_behavior = drone_physics.get_flight_behavior()

		if not flight_behavior["can_fly"]:
			print("⚠️ ВНИМАНИЕ: Дрон не может лететь!")
			print("   Причина: недостаточно моторов/пропеллеров")
			print("   Моторов: ", motor_nodes.size())
			print("   Пропеллеров: ", propeller_nodes.size())
			print("   Подъемная сила: ", drone_physics.lift_capacity)
			print("   Масса: ", drone_physics.total_mass)
		else:
			print("✅ Дрон готов к полету!")

func find_component_by_type(type: String):
	"""Находит компонент по типу в иерархии дрона"""
	for child in get_children():
		if child.has_method("get_component_type") and child.get_component_type() == type:
			return child
	return null

func find_all_components_by_type(type: String) -> Array:
	"""Находит все компоненты по типу"""
	var components = []
	for child in get_children():
		if child.has_method("get_component_type") and child.get_component_type() == type:
			components.append(child)
	return components


func count_active_motors() -> int:
	"""Считает активные моторы (с пропеллерами)"""
	if not drone_physics:
		return 0
	
	var count = 0
	for motor in drone_physics.motors:
		if motor["has_propeller"]:
			count += 1
	return count

# ГАРАНТИРОВАННЫЙ ПОИСК ПРОПЕЛЛЕРОВ
func find_propellers_guaranteed() -> Array:
	var found: Array = []
	print("🔍 Начинаем поиск пропеллеров...")

	# 1) Поиск по группе (быстрый)
	var group_propellers := get_tree().get_nodes_in_group("drone_propellers")
	for node in group_propellers:
		if node == null or not is_instance_valid(node):
			continue
		if not is_ancestor_of(node):
			continue
		if node.name.begins_with("@"):
			continue
		if not (node is Node3D):
			continue
		# Не берём MeshInstance3D как "пропеллер"
		if node is MeshInstance3D:
			continue

		# В группе должен быть КОРНЕВОЙ узел пропеллера
		var name_l := str(node.name).to_lower()
		if not name_l.begins_with("propeller"):
			continue

		if not found.has(node):
			found.append(node)
			print("✅ Найден по группе: ", node.name, " в позиции ", (node as Node3D).global_position)

	print("   Найдено по группе (после фильтра): ", found.size())

	# 2) ДОБОР ПО ДЕРЕВУ (ВСЕГДА!), чтобы подхватывать пропеллеры без группы/мет
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue

		for c in n.get_children():
			if c and is_instance_valid(c):
				stack.append(c)

		if n.name.begins_with("@"):
			continue
		if not (n is Node3D):
			continue
		if n is MeshInstance3D:
			continue

		var nl := str(n.name).to_lower()
		if not nl.begins_with("propeller"):
			continue

		if found.has(n):
			continue

		# ✅ Самофикс: помечаем, чтобы дальше всё стабильно работало
		if not n.has_meta("is_drone_propeller"):
			n.set_meta("is_drone_propeller", true)
		if not n.is_in_group("drone_propellers"):
			n.add_to_group("drone_propellers")

		var slot := _infer_slot_from_propeller_name(n.name)
		if slot >= 0 and not n.has_meta("motor_slot"):
			n.set_meta("motor_slot", slot)

		found.append(n)
		print("✅ Найден в дереве: ", n.name, " позиция ", (n as Node3D).global_position)

	# КЛЮЧЕВОЕ: записываем в member propellers
	propellers.clear()
	propellers.append_array(found)

	print("🎯 Итог: ", propellers.size(), " пропеллеров")
	for i in range(propellers.size()):
		var p := propellers[i] as Node3D
		if p:
			print("   ", i, ". ", p.name, " - позиция: ", p.global_position)

	return propellers


func _infer_slot_from_propeller_name(nm: String) -> int:
	var s := nm.to_lower()
	# Propeller_0..3
	if s.begins_with("propeller_"):
		var parts := s.split("_")
		if parts.size() >= 2 and parts[parts.size() - 1].is_valid_int():
			var idx := int(parts[parts.size() - 1])
			if idx >= 0 and idx <= 3:
				return idx
	# Propeller0..3
	if s.length() > 0:
		var last := s.substr(s.length() - 1, 1)
		if last.is_valid_int():
			var idx2 := int(last)
			if idx2 >= 0 and idx2 <= 3 and s.find("propeller") != -1:
				return idx2
	return -1

func search_all_meshes_for_propellers(node: Node):
	"""Ищет все меши, которые могут быть пропеллерами"""
	for child in node.get_children():
		if child is MeshInstance3D or child is Node3D:
			# Проверяем по имени
			var child_name = str(child.name).to_lower()
			if "propeller" in child_name or "винт" in child_name or "пропеллер" in child_name:
				if not propellers.has(child):
					propellers.append(child)
					print("✅ Найден по имени: ", child.name)
			
			# Проверяем по материалу или другим признакам
			if child is MeshInstance3D:
				if child.mesh:
					var mesh_name = str(child.mesh.resource_name).to_lower()
					if "propeller" in mesh_name:
						if not propellers.has(child):
							propellers.append(child)
							print("✅ Найден по мешу: ", child.name)
		
		# Рекурсивно ищем в детях
		search_all_meshes_for_propellers(child)
		
func find_propellers_as_motor_children():
	"""Ищет пропеллеры как детей моторов"""
	# Сначала находим все моторы
	var motors_found = []
	for child in get_children():
		if child is Node3D:
			var child_name = str(child.name).to_lower()
			if "motor" in child_name or "мотор" in child_name or "двигатель" in child_name:
				motors_found.append(child)
	
	print("   Найдено моторов: ", motors_found.size())
	
	# Теперь ищем пропеллеры как детей моторов
	for motor in motors_found:
		for motor_child in motor.get_children():
			if motor_child is Node3D:
				var motor_child_name = str(motor_child.name).to_lower()
				if "propeller" in motor_child_name or "винт" in motor_child_name or "пропеллер" in motor_child_name:
					if not propellers.has(motor_child):
						propellers.append(motor_child)
						print("✅ Найден пропеллер как ребенок мотора: ", motor_child.name)
				
				# Также ищем MeshInstance3D среди детей
				if motor_child is MeshInstance3D:
					# Проверяем размер или форму
					if motor_child.mesh:
						var mesh_size = motor_child.mesh.get_aabb().size
						# Пропеллеры обычно плоские и широкие
						if mesh_size.x > 0.2 and mesh_size.y < 0.1 and mesh_size.z > 0.2:
							if not propellers.has(motor_child):
								propellers.append(motor_child)
								print("✅ Найден пропеллер по форме: ", motor_child.name)

func find_propellers_in_exported_structure():
	"""Ищет пропеллеры в структуре экспортированного дрона"""
	# В экспортированном дроне пропеллеры могут быть на том же уровне, что и моторы
	for child in get_children():
		if child is Node3D:
			# Пропеллеры часто имеют имена Propeller_0, Propeller_1 и т.д.
			if child.name.begins_with("Propeller_") or child.name.begins_with("propeller_"):
				if not propellers.has(child):
					propellers.append(child)
					print("✅ Найден по структуре: ", child.name)
			
			# Или могут быть в узле с именем Propeller
			if child.name == "Propeller" or child.name == "propeller":
				if not propellers.has(child):
					propellers.append(child)
					print("✅ Найден узел пропеллера: ", child.name)
				
				# Ищем меши внутри узла пропеллера
				for prop_child in child.get_children():
					if prop_child is MeshInstance3D:
						if not propellers.has(prop_child):
							propellers.append(prop_child)
							print("✅ Найден меш пропеллера: ", prop_child.name)

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
	
	# Сбрасываем флаг достижения цели
	has_reached_target = false
	
	print("========================================")
	print("🚀 ЗАПУСК ПРОГРАММЫ")
	print("   Команд: ", sequence.size())
	print("   Пропеллеров: ", propellers.size())
	print("   Цель: ", target_position)
	
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
	
	# ВАЖНО: Дрон НЕ возвращается на старт автоматически
	# Вместо этого сообщаем о результате программы
	print("✅ Программа завершена с результатом: ", success)
	
	# Проверяем, достиг ли дрон цели
	if not success:
		print("❌ Программа завершена неудачно, дрон остаётся на месте")
	else:
		print("✅ Программа выполнена успешно, дрон остаётся на месте")
	
	program_finished.emit(success)

# ВЫПОЛНЕНИЕ КОМАНД
func execute_actions(sequence: Array) -> bool:
	if sequence.is_empty():
		print("⚠️ Пустая программа")
		return false
	
	print("🎯 Выполнение команд (с физикой)")
	
	for i in range(sequence.size()):
		if is_crashed:
			print("❌ Дрон разбился, прерываем программу")
			return false
		
		var action = sequence[i]
		var command_name = get_direction_name(action)
		print("   ", i + 1, "/", sequence.size(), ": ", command_name)
		
		var move_success = await perform_movement_with_physics(action)
		if not move_success:
			print("❌ Ошибка движения или падение")
			await return_to_start()
			return false
		
		await get_tree().create_timer(0.1).timeout
	
	print("✅ Все команды выполнены успешно")
	return true

func perform_movement_with_physics(direction: int) -> bool:
	"""Выполняет движение с учетом физики дрона"""
	if is_crashed:
		print("❌ Дрон разбился! Невозможно двигаться")
		return false
	
	# Проверяем, что дрон все еще находится в дереве сцены
	if not is_inside_tree():
		print("❌ Дрон был удален из дерева сцены")
		return false
	
	var target_pos = global_position
	
	# Рассчитываем базовое направление
	match direction:
		0: target_pos.z -= GRID_SIZE  # Вперед
		1: target_pos.z += GRID_SIZE  # Назад
		2: target_pos.x -= GRID_SIZE  # Влево
		3: target_pos.x += GRID_SIZE  # Вправо
		4: target_pos.y += GRID_SIZE  # Вверх
		5: target_pos.y = max(target_pos.y - GRID_SIZE, 0)  # Вниз
	
	# Применяем физику к движению
	if drone_physics:
		# Проверяем, может ли дрон лететь
		if not drone_physics.can_take_off():
			print("⚠️ Дрон не может взлететь! Проверьте компоненты")
			is_crashed = true
			crash_position = global_position
			emit_crash_effect()
			return false
		
		# Рассчитываем скорость (расстояние / время)
		var move_speed = GRID_SIZE / MOVE_SPEED
		
		# Симулируем движение с физикой
		var time_elapsed = 0.0
		var move_duration = MOVE_SPEED
		var start_pos = global_position
		
		while time_elapsed < move_duration:
			# Проверяем, что дрон все еще активен
			if not is_inside_tree() or is_crashed:
				print("❌ Дрон был удален или разбился во время движения")
				return false
			
			var t = time_elapsed / move_duration
			var base_pos = start_pos.lerp(target_pos, t)
			
			# Применяем улучшенную физику с учетом направления И СКОРОСТИ
			var physics_pos = drone_physics.apply_movement_physics(
				direction,
				global_position,
				base_pos,
				get_process_delta_time(),
				move_speed  # Передаем рассчитанную скорость
			)
			
			# Проверяем, не упал ли дрон
			if drone_physics.check_crash_condition(physics_pos):
				print("💥 Дрон падает!")
				is_crashed = true
				crash_position = physics_pos
				emit_crash_effect()
				return false
			
			# Безопасно обновляем позицию
			if is_inside_tree():
				global_position = physics_pos
				# ВИЗУАЛЬНЫЙ КРЕН (плавно, без рандома)
				if drone_physics and drone_physics.has_method("get_visual_tilt_degrees"):
					var desired_tilt = drone_physics.get_visual_tilt_degrees(direction)
					var tilt_lerp = clamp(get_process_delta_time() * 8.0, 0.0, 1.0)
					rotation_degrees = rotation_degrees.lerp(desired_tilt, tilt_lerp)
				drone_moved.emit()
			else:
				return false
			
			time_elapsed += get_process_delta_time()
			await get_tree().process_frame
		
		# Финальная позиция (только если дрон все еще в дереве)
		if is_inside_tree():
			var final_pos = drone_physics.apply_movement_physics(
				direction,
				global_position,
				target_pos,
				get_process_delta_time(),
				move_speed  # Передаем рассчитанную скорость
			)
			
			# Проверяем финальную позицию на падение
			if drone_physics.check_crash_condition(final_pos):
				print("💥 Дрон падает в конце движения!")
				is_crashed = true
				crash_position = final_pos
				emit_crash_effect()
				return false
			
			# Если дрон полностью собран и стабилен — доводим ровно до центра клетки
			if drone_physics and drone_physics.has_method("get_translation_factor"):
				var t_factor = drone_physics.get_translation_factor()
				var s_factor = drone_physics.get_stability_factor()
				if t_factor >= 0.99 and s_factor >= 0.9:
					global_position = target_pos
				else:
					global_position = final_pos
			else:
				global_position = final_pos
			# Небольшой возврат крена к нулю в конце команды
			var reset_tween = create_tween()
			reset_tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 0.25)
	else:
		# Без физики - обычное движение (с проверкой)
		if is_inside_tree():
			var tween = create_tween()
			tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
			await tween.finished
		else:
			return false
	
	# Проверяем достижение цели (только если дрон активен)
	if is_inside_tree():
		check_target_proximity()
		drone_moved.emit()
	
	return true

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
	if is_crashed:
		print("❌ Дрон разбился! Невозможно двигаться")
		return false
	
	var target_pos = global_position
	
	# Рассчитываем базовое направление
	match direction:
		0: target_pos.z -= GRID_SIZE  # Вперед
		1: target_pos.z += GRID_SIZE  # Назад
		2: target_pos.x -= GRID_SIZE  # Влево
		3: target_pos.x += GRID_SIZE  # Вправо
		4: target_pos.y += GRID_SIZE  # Вверх
		5: target_pos.y = max(target_pos.y - GRID_SIZE, 0)  # Вниз (но не ниже земли)
	
	# Создаем твин для плавного движения
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
	tween.tween_callback(check_target_proximity)
	await tween.finished
	
	# Проверяем достижение цели
	check_target_proximity()
	
	drone_moved.emit()
	return true

func check_target_proximity():
	if target_position != Vector3.ZERO:
		var distance = global_position.distance_to(target_position)
		var proximity_threshold = GRID_SIZE * 1.5  # ВОССТАНАВЛИВАЕМ ОРИГИНАЛЬНОЕ
		
		if distance < proximity_threshold:
			has_reached_target = true
			print("🎯 Достигнута цель! Расстояние: ", distance, " (порог: ", proximity_threshold, ")")
			# Дополнительно: принудительно перемещаем дрон к цели для визуального эффекта
			if distance > GRID_SIZE * 0.5:  # Если дрон близко, но не точно в цели
				var snap_tween = create_tween()
				snap_tween.tween_property(self, "global_position", target_position, 0.3)
		else:
			print("📏 Расстояние до цели: ", distance, " (порог: ", proximity_threshold, ")")

		
func emit_crash_effect():
	"""Эффект падения дрона"""
	# Проверяем, что дрон все еще в дереве
	if not is_inside_tree():
		print("❌ Дрон уже удален, не могу создать эффект падения")
		return
	
	print("💥💥💥 ДРОН РАЗБИЛСЯ!")
	
	# Останавливаем пропеллеры
	stop_propellers()
	
	# Показываем сообщение о разбитии
	show_crash_message()
	
	# Визуальный эффект падения
	var crash_tween = create_tween()
	crash_tween.tween_property(self, "rotation_degrees", Vector3(randf_range(-45, 45), randf_range(0, 360), randf_range(-45, 45)), 0.5)
	
	# Эффект "падения" на место
	if crash_position.y > 0 and is_inside_tree():
		var fall_tween = create_tween()
		fall_tween.tween_property(self, "global_position:y", crash_position.y - 2.0, 0.3)
		fall_tween.tween_property(self, "global_position:y", crash_position.y, 0.2)


# ОСТАНОВКА
func stop_execution():
	print("🛑 ПРИНУДИТЕЛЬНАЯ ОСТАНОВКА")
	is_executing = false
	stop_propellers()
	
	if current_tween:
		current_tween.kill()
	
	# Проверяем, что дрон все еще в дереве
	if is_inside_tree():
		# Принудительный возврат на старт при остановке
		print("↩️ Принудительный возврат на старт")
		await return_to_start()
		program_finished.emit(false)
	else:
		print("❌ Дрон уже удален")

# ВОЗВРАТ НА СТАРТ
func return_to_start():
	"""Возвращает дрон на старт после падения"""
	# Проверяем, что дрон все еще в дереве сцены
	if not is_inside_tree():
		print("❌ Дрон был удален, не могу вернуть на старт")
		return
	
	print("↩️ ВОЗВРАТ НА СТАРТ ИЗ-ЗА ПАДЕНИЯ")
	
	# Сбрасываем состояние падения
	is_crashed = false
	
	# Восстанавливаем ориентацию
	var reset_tween = create_tween()
	reset_tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 0.5)
	
	# Возвращаем на старт
	var return_tween = create_tween()
	return_tween.tween_property(self, "global_position", start_position, MOVE_SPEED * 1.5)
	await return_tween.finished
	
	if is_inside_tree():
		drone_moved.emit()
		print("✅ Дрон восстановлен и вернулся на старт")
	else:
		print("❌ Дрон был удален во время возврата на старт")

# ВИЗУАЛИЗАЦИЯ БАЛАНСА (опционально)
func show_balance_visualization():
	"""Показывает визуализацию центра масс и баланса"""
	if not drone_physics:
		return
	
	# Создаем маркер центра масс
	var com_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	com_marker.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	com_marker.material_override = material
	
	# Позиционируем относительно дрона
	com_marker.position = drone_physics.center_of_mass
	add_child(com_marker)
	
	# Показываем вектор разбалансировки
	if drone_physics.thrust_imbalance.length() > 0.1:
		var line = MeshInstance3D.new()
		var immediate_mesh = ImmediateMesh.new()
		var line_material = StandardMaterial3D.new()
		line_material.albedo_color = Color.YELLOW
		
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
		immediate_mesh.surface_add_vertex(drone_physics.center_of_mass)
		immediate_mesh.surface_add_vertex(drone_physics.center_of_mass + drone_physics.thrust_imbalance)
		immediate_mesh.surface_end()
		
		line.mesh = immediate_mesh
		add_child(line)

func reset_to_start():
	print("🔁 Принудительный возврат на старт")
	is_executing = false
	is_crashed = false
	
	# Останавливаем пропеллеры
	stop_propellers()
	
	# Возвращаемся на стартовую позицию
	var return_tween = create_tween()
	return_tween.tween_property(self, "global_position", start_position, 1.0)
	return_tween.parallel().tween_property(self, "rotation_degrees", Vector3.ZERO, 0.5)
	await return_tween.finished
	
	
	print("✅ Дрон вернулся на старт и отцентрирован: ", global_position)
	
func set_target_reached(reached: bool):
	has_reached_target = reached
	if reached:
		print("🎯 Дрон: цель достигнута!")


func show_imbalance_visualization():
	"""Показывает визуализацию разбалансировки дрона"""
	if not drone_physics:
		return
	
	# Создаем стрелки, показывающие направление крена
	for i in range(4):
		var arrow = MeshInstance3D.new()
		var arrow_mesh = CylinderMesh.new()
		arrow_mesh.top_radius = 0.05
		arrow_mesh.bottom_radius = 0.05
		arrow_mesh.height = 0.5
		arrow.mesh = arrow_mesh
		
		var material = StandardMaterial3D.new()
		
		# Цвет стрелки в зависимости от стороны
		match i:
			0:  # Передняя
				material.albedo_color = Color.GREEN
				arrow.position = Vector3(0, 0.3, 0.5)
			1:  # Задняя
				material.albedo_color = Color.BLUE
				arrow.position = Vector3(0, 0.3, -0.5)
			2:  # Левая
				material.albedo_color = Color.YELLOW
				arrow.position = Vector3(-0.5, 0.3, 0)
			3:  # Правая
				material.albedo_color = Color.RED
				arrow.position = Vector3(0.5, 0.3, 0)
		
		arrow.material_override = material
		add_child(arrow)
		
		# Анимация стрелки в зависимости от разбалансировки
		var imbalance = drone_physics.get_direction_imbalance(i)
		if imbalance.length() > 0.1:
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(arrow, "rotation_degrees:x", 20.0, 0.5)
			tween.tween_property(arrow, "rotation_degrees:x", 0.0, 0.5)


func show_crash_message():
	"""Показывает сообщение о разбитии дрона"""
	# Проверяем, что дрон все еще в дереве
	if not is_inside_tree():
		return
	
	print("📢 Показываем сообщение о разбитии дрона")
	
	# Создаем CanvasLayer для сообщения
	var crash_canvas = CanvasLayer.new()
	crash_canvas.layer = 20
	crash_canvas.name = "CrashMessageCanvas"
	
	# Полупрозрачный фон
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.size = get_viewport().size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Панель сообщения
	var message_panel = Panel.new()
	message_panel.size = Vector2(400, 200)
	
	# Центрируем панель
	var viewport_size = Vector2(get_viewport().get_visible_rect().size)
	message_panel.position = (viewport_size - message_panel.size) / 2
	
	# Стиль панели
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0, 0, 0.9)
	panel_style.border_color = Color.RED
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	message_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Текст сообщения
	var message_label = Label.new()
	message_label.text = "💥 ДРОН РАЗБИЛСЯ!\n\nПричина: дисбаланс или отсутствие двигателей\nДрон будет возвращен на старт"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.size = message_panel.size
	
	message_panel.add_child(message_label)
	overlay.add_child(message_panel)
	crash_canvas.add_child(overlay)
	
	# Добавляем канвас к родителю дрона
	if get_parent():
		get_parent().add_child(crash_canvas)
	else:
		add_child(crash_canvas)
	
	# Автоматическое скрытие через 3 секунды
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(crash_canvas):
		crash_canvas.queue_free()

func _ensure_collision() -> void:
	if find_child("CollisionShape3D", true, false) != null:
		return

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"

	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 4.0, 8.0) # подгони под свою клетку/размер дрона
	cs.shape = shape
	cs.position = Vector3(0.0, 2.0, 0.0)

	add_child(cs)
