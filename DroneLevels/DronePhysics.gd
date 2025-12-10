class_name DronePhysics
extends Node

# Физические константы
const GRAVITY = 9.8
const AIR_DENSITY = 1.2
const PROP_EFFICIENCY = 0.8
const DRAG_COEFFICIENT = 0.3
const MAX_TILT_ANGLE = 30.0  # Максимальный угол крена в градусах
const TILT_RESPONSE = 2.0    # Коэффициент отклика на крен

# Ссылка на глобальные характеристики компонентов
var component_stats = {
	"frame": {
		"Рама1": {"mass": 1.0, "durability": 100},
		"Рама2": {"mass": 1.5, "durability": 150},
		"Рама3": {"mass": 2.0, "durability": 200}
	},
	"board": {
		"Плата1": {"mass": 0.3, "power": 1.0},
		"Плата2": {"mass": 0.5, "power": 1.5},
		"Плата3": {"mass": 0.7, "power": 2.0}
	},
	"motor": {
		"Мотор1": {"mass": 0.2, "thrust": 8.0, "power_consumption": 1.0},
		"Мотор2": {"mass": 0.3, "thrust": 12.0, "power_consumption": 1.5},
		"Мотор3": {"mass": 0.4, "thrust": 16.0, "power_consumption": 2.0}
	},
	"propeller": {
		"Пропеллер1": {"mass": 0.1, "efficiency": 0.9},
		"Пропеллер2": {"mass": 0.15, "efficiency": 0.7},
		"Пропеллер3": {"mass": 0.2, "efficiency": 0.8}
	}
}

# Компоненты дрона
var frame_mass: float = 0.0
var board_mass: float = 0.0
var motors: Array = []  # {position: Vector3, thrust: float, has_propeller: bool, motor_index: int, side: String}
var propellers: Array = []  # {position: Vector3, motor_index: int, efficiency: float}

# Физическое состояние
var velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var orientation: Quaternion = Quaternion.IDENTITY
var total_mass: float = 0.0
var center_of_mass: Vector3 = Vector3.ZERO
var is_airborne: bool = false
var last_position: Vector3 = Vector3.ZERO

# Расчетные параметры
var thrust_imbalance: Vector3 = Vector3.ZERO  # Вектор разбалансировки
var lift_capacity: float = 0.0  # Общая подъемная сила
var is_stable: bool = true
var missing_motors: Array = []  # Индексы отсутствующих моторов
var missing_sides: Dictionary = {  # Какие стороны ослаблены
	"front": false,
	"back": false,
	"left": false,
	"right": false
}

# Конфигурация квадрокоптера (стандартные позиции моторов)
const MOTOR_POSITIONS = [
	{"pos": Vector3(0.5, 0, 0.5), "side": "front_right"},   # Передний правый
	{"pos": Vector3(-0.5, 0, 0.5), "side": "front_left"},  # Передний левый
	{"pos": Vector3(0.5, 0, -0.5), "side": "back_right"},  # Задний правый
	{"pos": Vector3(-0.5, 0, -0.5), "side": "back_left"}   # Задний левый
]

func find_closest_motor(propeller_pos: Vector3, motor_nodes: Array) -> int:
	"""Находит индекс ближайшего мотора к пропеллеру"""
	if motor_nodes.is_empty():
		return 0
	
	var closest_index = 0
	var closest_distance = INF
	
	for i in range(motor_nodes.size()):
		var motor = motor_nodes[i]
		if motor and is_instance_valid(motor):
			var distance = propeller_pos.distance_to(motor.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_index = i
	
	return closest_index

func setup_from_components(frame, board, motor_nodes: Array, propeller_nodes: Array):
	"""Инициализация физики на основе компонентов дрона"""
	
	# Собираем массы
	var masses = []
	var positions = []
	
	# Рама
	if frame and is_instance_valid(frame):
		var frame_type = frame.get_meta("frame_type") if frame.has_meta("frame_type") else "Рама1"
		if frame.name.begins_with("frame") or "Рама" in frame.name:
			for key in component_stats["frame"].keys():
				if key in frame.name:
					frame_type = key
					break
		
		frame_mass = component_stats["frame"][frame_type]["mass"]
		masses.append(frame_mass)
		positions.append(Vector3.ZERO)
		print("📊 Рама: ", frame_type, " масса: ", frame_mass)
	
	# Плата
	if board and is_instance_valid(board):
		var board_type = board.get_meta("board_type") if board.has_meta("board_type") else "Плата1"
		if board.name.begins_with("board") or "Плата" in board.name:
			for key in component_stats["board"].keys():
				if key in board.name:
					board_type = key
					break
		
		board_mass = component_stats["board"][board_type]["mass"]
		masses.append(board_mass)
		positions.append(Vector3(0, 0.1, 0))
		print("📊 Плата: ", board_type, " масса: ", board_mass)
	
	# Моторы
	motors.clear()
	missing_motors.clear()
	missing_sides = {"front": false, "back": false, "left": false, "right": false}
	
	for i in range(motor_nodes.size()):
		var motor = motor_nodes[i]
		if motor and is_instance_valid(motor):
			var motor_type = motor.get_meta("motor_type") if motor.has_meta("motor_type") else "Мотор1"
			if motor.name.begins_with("motor") or "Мотор" in motor.name or "Двигатель" in motor.name:
				for key in component_stats["motor"].keys():
					if key in motor.name:
						motor_type = key
						break
			
			var motor_thrust = component_stats["motor"][motor_type]["thrust"]
			var motor_mass = component_stats["motor"][motor_type]["mass"]
			var motor_side = MOTOR_POSITIONS[i]["side"] if i < MOTOR_POSITIONS.size() else "unknown"
			
			var motor_data = {
				"position": MOTOR_POSITIONS[i]["pos"] if i < MOTOR_POSITIONS.size() else Vector3.ZERO,
				"thrust": motor_thrust,
				"has_propeller": false,
				"index": i,
				"motor_type": motor_type,
				"side": motor_side
			}
			motors.append(motor_data)
			
			masses.append(motor_mass)
			positions.append(motor_data.position)
			print("📊 Мотор ", i, " (", motor_side, "): ", motor_type, " тяга: ", motor_thrust)
	
	# Пропеллеры
	propellers.clear()
	for i in range(propeller_nodes.size()):
		var propeller = propeller_nodes[i]
		if propeller and is_instance_valid(propeller):
			var propeller_type = propeller.get_meta("propeller_type") if propeller.has_meta("propeller_type") else "Пропеллер1"
			if propeller.name.begins_with("propeller") or "Пропеллер" in propeller.name or "Винт" in propeller.name:
				for key in component_stats["propeller"].keys():
					if key in propeller.name:
						propeller_type = key
						break
			
			var closest_motor_index = find_closest_motor(propeller.global_position, motor_nodes)
			
			var propeller_efficiency = component_stats["propeller"][propeller_type]["efficiency"]
			var propeller_mass = component_stats["propeller"][propeller_type]["mass"]
			
			var propeller_data = {
				"position": MOTOR_POSITIONS[closest_motor_index]["pos"] if closest_motor_index < MOTOR_POSITIONS.size() else Vector3.ZERO,
				"motor_index": closest_motor_index,
				"efficiency": propeller_efficiency,
				"mass": propeller_mass,
				"propeller_type": propeller_type
			}
			propellers.append(propeller_data)
			
			if closest_motor_index < motors.size():
				motors[closest_motor_index]["has_propeller"] = true
				motors[closest_motor_index]["propeller_efficiency"] = propeller_efficiency
			
			masses.append(propeller_mass)
			positions.append(propeller_data.position)
			print("📊 Пропеллер ", i, " на мотор ", closest_motor_index, ": эффективность: ", propeller_efficiency)
	
	# Отмечаем отсутствующие моторы и определяем ослабленные стороны
	analyze_motor_configuration()
	
	# Рассчитываем общую массу и центр масс
	calculate_mass_properties(masses, positions)
	
	# Рассчитываем подъемную силу и баланс
	calculate_lift_and_balance()
	
	print("✅ Физика дрона инициализирована:")
	print("  Масса: ", total_mass)
	print("  Центр масс: ", center_of_mass)
	print("  Подъемная сила: ", lift_capacity)
	print("  Стабильность: ", is_stable)
	print("  Моторов/пропеллеров: ", motors.size(), "/", propellers.size())
	print("  Отсутствуют моторы: ", missing_motors)
	print("  Ослабленные стороны: ", missing_sides)

func analyze_motor_configuration():
	"""Анализирует конфигурацию моторов и определяет ослабленные стороны"""
	missing_motors.clear()
	missing_sides = {"front": false, "back": false, "left": false, "right": false}
	
	for i in range(motors.size()):
		if not motors[i]["has_propeller"]:
			missing_motors.append(i)
			var side = motors[i]["side"]
			
			# Определяем, какая сторона ослаблена
			if "front" in side:
				missing_sides["front"] = true
			if "back" in side:
				missing_sides["back"] = true
			if "left" in side:
				missing_sides["left"] = true
			if "right" in side:
				missing_sides["right"] = true
	
	print("🔍 Анализ конфигурации:")
	print("  Отсутствуют моторы на позициях: ", missing_motors)
	print("  Ослабленные стороны: ", missing_sides)

func get_direction_imbalance(direction: int) -> Vector3:
	"""Возвращает вектор разбалансировки для конкретного направления движения"""
	var imbalance = Vector3.ZERO
	
	match direction:
		0:  # Вперед
			if missing_sides["front"]:
				# Если отсутствуют передние моторы, дрон будет крениться вперед
				imbalance.z = -0.3
			if missing_sides["left"] and not missing_sides["right"]:
				imbalance.x = 0.2  # Крен вправо
			elif missing_sides["right"] and not missing_sides["left"]:
				imbalance.x = -0.2  # Крен влево
				
		1:  # Назад
			if missing_sides["back"]:
				imbalance.z = 0.3
			if missing_sides["left"] and not missing_sides["right"]:
				imbalance.x = 0.2
			elif missing_sides["right"] and not missing_sides["left"]:
				imbalance.x = -0.2
				
		2:  # Влево
			if missing_sides["left"]:
				imbalance.x = -0.3
			if missing_sides["front"] and not missing_sides["back"]:
				imbalance.z = -0.2
			elif missing_sides["back"] and not missing_sides["front"]:
				imbalance.z = 0.2
				
		3:  # Вправо
			if missing_sides["right"]:
				imbalance.x = 0.3
			if missing_sides["front"] and not missing_sides["back"]:
				imbalance.z = -0.2
			elif missing_sides["back"] and not missing_sides["front"]:
				imbalance.z = 0.2
	
	return imbalance

func calculate_tilt_effect(direction: int, current_pos: Vector3, target_pos: Vector3) -> Vector3:
	"""Рассчитывает эффект крена при движении в определенном направлении"""
	var direction_vector = (target_pos - current_pos).normalized()
	var tilt_effect = Vector3.ZERO
	
	# Базовый вектор крена из-за разбалансировки
	tilt_effect += thrust_imbalance * TILT_RESPONSE
	
	# Дополнительный крен из-за отсутствия моторов в направлении движения
	var direction_imbalance = get_direction_imbalance(direction)
	tilt_effect += direction_imbalance * 2.0
	
	# Ограничиваем максимальный крен
	var tilt_magnitude = tilt_effect.length()
	if tilt_magnitude > MAX_TILT_ANGLE / 90.0:  # Нормализуем к 0-1
		tilt_effect = tilt_effect.normalized() * (MAX_TILT_ANGLE / 90.0)
	
	return tilt_effect

func apply_movement_physics(direction: int, current_pos: Vector3, target_pos: Vector3, delta: float) -> Vector3:
	"""Применяет физику движения с учетом конфигурации дрона"""
	if not can_take_off():
		return current_pos + Vector3(0, -GRAVITY * delta, 0)
	
	# Базовое движение
	var movement = (target_pos - current_pos).normalized() * delta * 10.0
	
	# Эффект крена
	var tilt_effect = calculate_tilt_effect(direction, current_pos, target_pos)
	
	# Применяем крен к движению
	movement += tilt_effect * delta * 5.0
	
	# Учитываем стабильность
	var stability_factor = get_stability_factor()
	movement *= stability_factor
	
	# Добавляем случайные колебания при низкой стабильности
	if stability_factor < 0.7:
		var turbulence = Vector3(
			randf_range(-0.1, 0.1) * (1.0 - stability_factor),
			randf_range(-0.05, 0.05) * (1.0 - stability_factor),
			randf_range(-0.1, 0.1) * (1.0 - stability_factor)
		)
		movement += turbulence
	
	return current_pos + movement

func get_stability_factor() -> float:
	"""Возвращает коэффициент стабильности от 0 до 1"""
	var active_motors = get_active_motors_count()
	var max_motors = motors.size()
	
	if max_motors == 0:
		return 0.0
	
	var motor_factor = float(active_motors) / float(max_motors)
	var balance_factor = 1.0 - min(thrust_imbalance.length() * 2.0, 1.0)
	
	return (motor_factor * 0.6 + balance_factor * 0.4) * 0.8 + 0.2

# ВАЖНО: Добавляем функцию get_flight_behavior() обратно
func get_flight_behavior() -> Dictionary:
	"""Возвращает поведение дрона в зависимости от конфигурации"""
	var active_motors = get_active_motors_count()
	
	var behavior = {
		"can_fly": can_take_off(),
		"stability": get_stability_factor(),
		"drift_direction": Vector3.ZERO,
		"max_speed": 1.0,
		"energy_efficiency": 1.0
	}
	
	# Направление дрейфа
	if not is_stable and thrust_imbalance.length() > 0:
		behavior["drift_direction"] = thrust_imbalance.normalized()
	
	# Максимальная скорость зависит от эффективности
	behavior["max_speed"] = float(active_motors) / 4.0
	
	return behavior

func can_take_off() -> bool:
	"""Проверяет, может ли дрон взлететь"""
	var active_motors = get_active_motors_count()
	
	# Минимально 2 мотора для базовой стабильности
	if active_motors < 2:
		return false
	
	# Подъемная сила должна быть больше массы
	return lift_capacity > total_mass * 1.1

func get_active_motors_count() -> int:
	"""Считает активные моторы (с пропеллерами)"""
	var count = 0
	for motor in motors:
		if motor["has_propeller"]:
			count += 1
	return count

func calculate_mass_properties(masses: Array, positions: Array):
	"""Рассчитывает массу и центр масс"""
	total_mass = 0.0
	var weighted_sum = Vector3.ZERO
	
	for i in range(masses.size()):
		total_mass += masses[i]
		weighted_sum += positions[i] * masses[i]
	
	if total_mass > 0:
		center_of_mass = weighted_sum / total_mass
	else:
		center_of_mass = Vector3.ZERO

func calculate_lift_and_balance():
	"""Рассчитывает подъемную силу и баланс дрона"""
	lift_capacity = 0.0
	thrust_imbalance = Vector3.ZERO
	
	var thrust_center = Vector3.ZERO
	var total_thrust = 0.0
	
	for motor in motors:
		if motor["has_propeller"]:
			var thrust = motor["thrust"]
			var propeller_efficiency = motor.get("propeller_efficiency", 0.8)
			var effective_thrust = thrust * propeller_efficiency
			
			lift_capacity += effective_thrust
			total_thrust += effective_thrust
			thrust_center += motor["position"] * effective_thrust
	
	if total_thrust > 0:
		var thrust_center_position = thrust_center / total_thrust
		thrust_imbalance = (thrust_center_position - center_of_mass) * 2.0
	else:
		thrust_imbalance = Vector3.ZERO
	
	var active_motors = get_active_motors_count()
	is_stable = (
		active_motors >= 3 and
		thrust_imbalance.length() < 0.2
	)
	
	if propellers.size() < motors.size():
		lift_capacity *= float(propellers.size()) / float(motors.size())

# Старые функции для обратной совместимости
func apply_physics(delta: float, current_position: Vector3, target_position: Vector3) -> Vector3:
	"""Совместимость со старым кодом"""
	print("⚠️ Используется устаревшая функция apply_physics, используйте apply_movement_physics")
	return apply_movement_physics(0, current_position, target_position, delta)

func check_crash_condition(current_position: Vector3, ground_level: float = 0.0) -> bool:
	"""Проверяет, не упал ли дрон"""
	var behavior = get_flight_behavior()
	
	# Проверяем несколько условий:
	# 1. Дрон упал ниже уровня земли
	if current_position.y < ground_level - 1.0:  # Небольшой запас для эффекта
		print("💥 Дрон упал на землю!")
		return true
	
	# 2. Дрон слишком нестабилен и падает
	if behavior["stability"] < 0.15:  # Уменьшил порог с 0.2 до 0.15 для большей чувствительности
		print("💥 Дрон слишком нестабилен!")
		return true
	
	# 3. Нет моторов с пропеллерами
	var active_motors = get_active_motors_count()
	if active_motors == 0:
		print("💥 Нет активных моторов!")
		return true
	
	# 4. Дрон накренился слишком сильно (угол > 45 градусов)
	# Это можно реализовать, если отслеживать вращение дрона
	# Для простоты пока пропустим
	
	return false
