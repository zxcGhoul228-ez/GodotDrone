class_name DronePhysics
extends Node

# Физические константы
const GRAVITY = 9.8
const AIR_DENSITY = 1.2
const PROP_EFFICIENCY = 0.8
const DRAG_COEFFICIENT = 0.3
const MAX_TILT_ANGLE = 30.0  # Максимальный угол крена в градусах
const TILT_RESPONSE = 2.0    # Коэффициент отклика на крен

# Плавность дрейфа/кренов (без рандома и без «телепортов»)
const DRIFT_SMOOTHING = 10.0 # Чем больше — тем быстрее дрейф выходит на целевую скорость

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

# motors: всегда 4 слота.
# has_propeller == «слот активен» (мотор есть И пропеллер есть)
var motors: Array = []  # {position: Vector3, thrust: float, has_propeller: bool, index: int, side: String, present: bool, propeller_present: bool}
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
var thrust_imbalance: Vector3 = Vector3.ZERO  # Вектор «слабой стороны» (куда заваливает/дрейфует)
var lift_capacity: float = 0.0  # Суммарная подъемная сила (в условных единицах)
var is_stable: bool = true
var missing_motors: Array = []  # Индексы отсутствующих/неактивных слотов
var missing_sides: Dictionary = {  # Какие стороны ослаблены
	"front": false,
	"back": false,
	"left": false,
	"right": false
}

# Внутреннее состояние для плавного дрейфа (чтобы не было «телепортов»)
var _drift_velocity_world: Vector3 = Vector3.ZERO

# Конфигурация квадрокоптера (стандартные позиции моторов в ЛОКАЛЬНЫХ координатах дрона)
# В Godot «вперед» обычно -Z, поэтому front имеет отрицательный Z.
const MOTOR_POSITIONS = [
	{"pos": Vector3(0.5, 0, -0.5), "side": "front_right"},   # Передний правый
	{"pos": Vector3(-0.5, 0, -0.5), "side": "front_left"},  # Передний левый
	{"pos": Vector3(0.5, 0, 0.5), "side": "back_right"},    # Задний правый
	{"pos": Vector3(-0.5, 0, 0.5), "side": "back_left"}     # Задний левый
]

func _get_drone_root() -> Node3D:
	var p = get_parent()
	return p as Node3D

func _slot_from_local_pos(local_pos: Vector3) -> int:
	# Классификация по четвертям X/Z (устойчива к любому порядку детей)
	var is_right = local_pos.x >= 0.0
	var is_front = local_pos.z <= 0.0
	if is_front and is_right:
		return 0
	if is_front and not is_right:
		return 1
	if not is_front and is_right:
		return 2
	return 3

func _closest_slot_by_local_pos(local_pos: Vector3) -> int:
	var best_i = 0
	var best_d = INF
	for i in range(MOTOR_POSITIONS.size()):
		var d = local_pos.distance_to(MOTOR_POSITIONS[i]["pos"])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func _local_dir_to_world_dir(local_dir: Vector3) -> Vector3:
	var root = _get_drone_root()
	if root:
		var b = root.global_transform.basis.orthonormalized()
		return (b * local_dir)
	return local_dir

func _extract_component_name(node: Node, category: String, default_name: String) -> String:
	# 1) meta
	var meta_key = "%s_type" % category
	if node and is_instance_valid(node) and node.has_meta(meta_key):
		return str(node.get_meta(meta_key))

	# 2) name contains known key
	if node and is_instance_valid(node):
		for key in component_stats[category].keys():
			if key in node.name:
				return key

	return default_name

func find_closest_motor(propeller_pos: Vector3, motor_nodes: Array) -> int:
	"""Находит индекс ближайшего слота мотора к пропеллеру.
	Важно: возвращает 0..3 (слот), а не индекс в motor_nodes.
	"""
	var root = _get_drone_root()
	if root:
		# Если есть моторы, сначала привяжемся к ближайшему реальному мотору
		var closest_motor: Node3D = null
		var closest_d = INF
		for motor in motor_nodes:
			if motor and is_instance_valid(motor) and motor is Node3D:
				var d = propeller_pos.distance_to((motor as Node3D).global_position)
				if d < closest_d:
					closest_d = d
					closest_motor = motor
		if closest_motor:
			var m_local = root.to_local(closest_motor.global_position)
			return _slot_from_local_pos(m_local)

		# Фоллбек: по позиции пропеллера
		var p_local = root.to_local(propeller_pos)
		return _slot_from_local_pos(p_local)

	# Если root не нашли (необычная иерархия) — старый фоллбек
	if motor_nodes.is_empty():
		return 0
	return 0

func setup_from_components(frame, board, motor_nodes: Array, propeller_nodes: Array):
	"""Инициализация физики на основе компонентов дрона"""
	var root = _get_drone_root()

	# Собираем массы
	var masses = []
	var positions = []

	# Рама
	if frame and is_instance_valid(frame):
		var frame_type = _extract_component_name(frame, "frame", "Рама1")
		frame_mass = component_stats["frame"][frame_type]["mass"]
		masses.append(frame_mass)
		positions.append(Vector3.ZERO)
		print("📊 Рама: ", frame_type, " масса: ", frame_mass)

	# Плата
	if board and is_instance_valid(board):
		var board_type = _extract_component_name(board, "board", "Плата1")
		board_mass = component_stats["board"][board_type]["mass"]
		masses.append(board_mass)
		positions.append(Vector3(0, 0.1, 0))
		print("📊 Плата: ", board_type, " масса: ", board_mass)

	# ===== МОТОРЫ: всегда 4 слота, даже если каких-то нод нет =====
	motors.clear()
	missing_motors.clear()
	missing_sides = {"front": false, "back": false, "left": false, "right": false}

	for i in range(MOTOR_POSITIONS.size()):
		motors.append({
			"position": MOTOR_POSITIONS[i]["pos"],
			"thrust": 0.0,
			"has_propeller": false,
			"index": i,
			"motor_type": "",
			"side": MOTOR_POSITIONS[i]["side"],
			"present": false,
			"propeller_present": false,
			"propeller_efficiency": 0.0
		})

	# Заполняем слоты тем, что реально есть в сцене
	var used_slots: Dictionary = {}
	for motor in motor_nodes:
		if not (motor and is_instance_valid(motor) and motor is Node3D):
			continue

		var motor_type = _extract_component_name(motor, "motor", "Мотор1")
		var motor_thrust = component_stats["motor"][motor_type]["thrust"]
		var motor_mass = component_stats["motor"][motor_type]["mass"]

		var local_pos = (root.to_local((motor as Node3D).global_position) if root else (motor as Node3D).position)
		# 1) по четвертям — устойчиво
		var slot = _slot_from_local_pos(local_pos)
		# 2) если вдруг два мотора попали в одну четверть, добираем ближайший свободный
		if used_slots.has(slot):
			slot = _closest_slot_by_local_pos(local_pos)
			if used_slots.has(slot):
				# последний фоллбек — первый свободный
				for k in range(MOTOR_POSITIONS.size()):
					if not used_slots.has(k):
						slot = k
						break

		used_slots[slot] = true

		motors[slot]["present"] = true
		motors[slot]["motor_type"] = motor_type
		motors[slot]["thrust"] = motor_thrust
		motors[slot]["position"] = local_pos

		masses.append(motor_mass)
		positions.append(local_pos)
		print("📊 Мотор слот ", slot, " (", motors[slot]["side"], "): ", motor_type, " тяга: ", motor_thrust)

		# ===== ПРОПЕЛЛЕРЫ =====
	propellers.clear()

	var assigned: Array = _assign_propellers_to_motor_slots_stable(propeller_nodes, root)

	for a in assigned:
		var prop: Node3D = a.get("node", null)
		if prop == null or not is_instance_valid(prop):
			continue

		var slot: int = int(a.get("slot", 0))
		slot = clampi(slot, 0, 3)

		var local_pos: Vector3 = a.get("local_pos", Vector3.ZERO)

		var propeller_type: String = _extract_component_name(prop, "propeller", "Пропеллер1")
		var propeller_efficiency: float = float(component_stats["propeller"][propeller_type]["efficiency"])
		var propeller_mass: float = float(component_stats["propeller"][propeller_type]["mass"])

		# сохраняем слот в meta (на будущее/для дебага)
		prop.set_meta("motor_slot", slot)

		var propeller_data: Dictionary = {
			"position": local_pos,
			"motor_index": slot,
			"efficiency": propeller_efficiency,
			"mass": propeller_mass,
			"propeller_type": propeller_type
		}
		propellers.append(propeller_data)

		motors[slot]["propeller_present"] = true

		var pc: int = int(motors[slot].get("propeller_count", 0)) + 1
		motors[slot]["propeller_count"] = pc

		var prev_eff: float = float(motors[slot].get("propeller_efficiency", 0.0))
		motors[slot]["propeller_efficiency"] = propeller_efficiency if pc == 1 else ((prev_eff * float(pc - 1)) + propeller_efficiency) / float(pc)

		motors[slot]["has_propeller"] = (bool(motors[slot].get("present", false)) and bool(motors[slot].get("propeller_present", false)))

		masses.append(propeller_mass)
		positions.append(local_pos)
		print("📊 Пропеллер на слот ", slot, ": ", propeller_type, " эффективность: ", propeller_efficiency)

	# Быстрый контроль распределения пропеллеров по слотам
	var pcnts: Array = [0, 0, 0, 0]
	for p in propellers:
		var si: int = int(p.get("motor_index", 0))
		if si >= 0 and si < 4:
			pcnts[si] += 1
	print("🧾 Пропеллеры по слотам: ", pcnts)

# Отмечаем отсутствующие моторы/пропеллеры и определяем ослабленные стороны
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
	print("  Слотов моторов: ", motors.size(), ", активных: ", get_active_motors_count())
	print("  Неактивные слоты: ", missing_motors)
	print("  Ослабленные стороны: ", missing_sides)

func analyze_motor_configuration():
	"""Анализирует конфигурацию моторов и определяет ослабленные стороны
	Важно: учитывает отсутствие МОТОРА и/или ПРОПЕЛЛЕРА.
	"""
	missing_motors.clear()
	missing_sides = {"front": false, "back": false, "left": false, "right": false}

	for i in range(motors.size()):
		var slot_data = motors[i]
		var active = bool(slot_data.get("present", false)) and bool(slot_data.get("propeller_present", false))
		slot_data["has_propeller"] = active
		motors[i] = slot_data

		if not active:
			missing_motors.append(i)
			var side = str(slot_data.get("side", ""))
			if "front" in side:
				missing_sides["front"] = true
			if "back" in side:
				missing_sides["back"] = true
			if "left" in side:
				missing_sides["left"] = true
			if "right" in side:
				missing_sides["right"] = true

	print("🔍 Анализ конфигурации:")
	print("  Неактивные слоты: ", missing_motors)
	print("  Ослабленные стороны: ", missing_sides)

func get_direction_imbalance(direction: int) -> Vector3:
	"""Возвращает вектор разбалансировки для конкретного направления движения.
	Сделано МЯГЧЕ и без перекоса «всегда в одну сторону».
	"""
	# Базово — вектор слабой стороны (в локальном пространстве)
	var imbalance = thrust_imbalance

	# Мягкая добавка: если движемся «против» слабой стороны, чуть усилим эффект завала
	var move_axis = Vector3.ZERO
	match direction:
		0: move_axis = Vector3(0, 0, -1) # вперед
		1: move_axis = Vector3(0, 0, 1)  # назад
		2: move_axis = Vector3(-1, 0, 0) # влево
		3: move_axis = Vector3(1, 0, 0)  # вправо
		_: move_axis = Vector3.ZERO

	if move_axis != Vector3.ZERO and imbalance != Vector3.ZERO:
		var dot = clamp(move_axis.normalized().dot(imbalance.normalized()), -1.0, 1.0)
		# dot > 0 значит движемся «в сторону слабости», dot < 0 — «против»
		imbalance *= (1.0 + (-dot) * 0.25)

	return imbalance

func calculate_tilt_effect(direction: int, current_pos: Vector3, target_pos: Vector3) -> Vector3:
	"""Рассчитывает эффект крена/дрейфа при движении.
	Возвращает ВЕКТОР (в локальном XZ), который дальше превращается в дрейф.
	"""
	var tilt_effect = Vector3.ZERO

	# Базовый вектор крена из-за разбалансировки
	var base_imbalance = get_direction_imbalance(direction)
	tilt_effect += base_imbalance * TILT_RESPONSE

	# Ограничиваем (в «долях» клетки, а не в градусах) — чтобы не было «скачков»
	var max_len = 1.0
	if tilt_effect.length() > max_len:
		tilt_effect = tilt_effect.normalized() * max_len

	# Убираем Y — крен/дрейф считаем в плоскости
	tilt_effect.y = 0
	return tilt_effect


# Старая функция для обратной совместимости
func apply_movement_physics_old(direction: int, current_pos: Vector3, target_pos: Vector3, delta: float) -> Vector3:
	"""Совместимость со старым кодом"""
	print("⚠️ Используется устаревшая функция apply_movement_physics, используйте apply_movement_physics с параметром speed")
	return apply_movement_physics(direction, current_pos, target_pos, delta, 32.0)

func get_stability_factor() -> float:
	"""Возвращает коэффициент стабильности от 0 до 1"""
	var active_motors = get_active_motors_count()
	var motor_factor = float(active_motors) / 4.0
	var balance_factor = 1.0 - min(thrust_imbalance.length() * 2.0, 1.0)

	# Немного «поднимаем пол», чтобы поведение не было слишком резким
	return clamp((motor_factor * 0.65 + balance_factor * 0.35) * 0.85 + 0.15, 0.0, 1.0)

# ВАЖНО: функция оставлена
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

	# Направление дрейфа (в МИРОВЫХ координатах)
	if not is_stable and thrust_imbalance.length() > 0:
		behavior["drift_direction"] = get_drift_direction_world()

	# Максимальная скорость зависит от количества активных моторов
	behavior["max_speed"] = float(active_motors) / 4.0

	return behavior

func can_take_off() -> bool:
	"""Проверяет, может ли дрон взлететь"""
	var active_motors = get_active_motors_count()

	# Минимально 2 активных слота (мотор+проп) для хоть какого-то полета
	if active_motors < 2:
		return false

	# Подъемная сила должна быть больше массы (в этой игре — условная проверка)
	return lift_capacity > total_mass * 1.1

func get_active_motors_count() -> int:
	"""Считает активные моторы (слоты, где есть мотор И пропеллер)"""
	var count = 0
	for motor in motors:
		if bool(motor.get("has_propeller", false)):
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
		# active слот
		if bool(motor.get("has_propeller", false)):
			var thrust = float(motor.get("thrust", 0.0))
			var eff = float(motor.get("propeller_efficiency", PROP_EFFICIENCY))
			var effective_thrust = thrust * eff

			lift_capacity += effective_thrust
			total_thrust += effective_thrust
			thrust_center += Vector3(motor["position"].x, 0.0, motor["position"].z) * effective_thrust

	if total_thrust > 0:
		var thrust_center_position = thrust_center / total_thrust
		# Важно: thrust_imbalance теперь означает «слабая сторона» (куда заваливает)
		thrust_imbalance = Vector3(center_of_mass.x, 0.0, center_of_mass.z) - Vector3(thrust_center_position.x, 0.0, thrust_center_position.z)
	else:
		thrust_imbalance = Vector3.ZERO

	var active_motors = get_active_motors_count()
	is_stable = (
		active_motors >= 3 and
		thrust_imbalance.length() < 0.25
	)

func check_crash_condition(current_position: Vector3, ground_level: float = 0.0) -> bool:
	"""Проверяет, не упал ли дрон"""
	var behavior = get_flight_behavior()

	# 1. Дрон упал ниже уровня земли
	if current_position.y < ground_level - 1.0:
		print("💥 Дрон упал на землю!")
		return true

	# 2. Дрон слишком нестабилен
	if behavior["stability"] < 0.15:
		print("💥 Дрон слишком нестабилен!")
		return true

	# 3. Нет активных моторов
	var active_motors = get_active_motors_count()
	if active_motors == 0:
		print("💥 Нет активных моторов!")
		return true

	return false

func get_translation_factor() -> float:
	"""0..1: насколько «сильно» дрон способен двигаться (без зависимости от направления)"""
	var active = get_active_motors_count()
	var motor_factor = float(active) / 4.0
	var stability = get_stability_factor()
	# Основной смысл: меньше моторов -> меньше расстояние; нестабильность чуть снижает
	return clamp(motor_factor * (0.7 + 0.3 * stability), 0.0, 1.0)

func get_drift_direction_world() -> Vector3:
	"""Направление дрейфа в мировых координатах (куда уносит/заваливает)"""
	if thrust_imbalance == Vector3.ZERO:
		return Vector3.ZERO
	var dir_local = thrust_imbalance
	dir_local.y = 0
	var dir_world = _local_dir_to_world_dir(dir_local)
	dir_world.y = 0
	return dir_world.normalized() if dir_world.length() > 0.0001 else Vector3.ZERO

func get_visual_tilt_degrees(direction: int = -1) -> Vector3:
	"""Желаемый визуальный наклон дрона (в градусах). Можно использовать в Drone.gd."""
	var dir = get_drift_direction_world()
	if dir == Vector3.ZERO:
		return Vector3.ZERO

	var strength = clamp((1.0 - get_stability_factor()) * get_imbalance_multiplier(), 0.0, 1.0)
	var tilt = MAX_TILT_ANGLE * strength

	# pitch: наклон по Z, roll: по X
	var pitch = dir.z * tilt
	var roll = -dir.x * tilt
	return Vector3(pitch, 0.0, roll)

# Добавим параметр скорости в функцию
func apply_movement_physics(direction: int, current_pos: Vector3, target_pos: Vector3, delta: float, speed: float = 32.0) -> Vector3:
	"""Применяет физику движения с учетом конфигурации дрона и скорости.
	Цели:
	- без ускорения
	- без рандома
	- корректная сторона дрейфа при отсутствии мотора/пропеллера
	- расстояние за команду зависит ТОЛЬКО от количества активных моторов (и немного от стабильности)
	"""
	if not can_take_off():
		# Падает вниз (плавно)
		return current_pos + Vector3(0, -GRAVITY * delta, 0)

	# Базовое «догоняющее» движение к target_pos без разгона и без overshoot
	var translation_factor = get_translation_factor()
	var max_step = speed * translation_factor * delta
	var next_pos = current_pos.move_toward(target_pos, max_step)

	# Дрейф в сторону «слабой стороны» (плавно, без рандома)
	var stability = get_stability_factor()
	var drift_dir = get_drift_direction_world()
	if drift_dir != Vector3.ZERO:
		# Чем хуже стабильность/меньше моторов — тем заметнее дрейф
		var drift_fraction = clamp((1.0 - stability) * 0.35 * get_imbalance_multiplier(), 0.0, 0.6)
		var target_drift_vel = drift_dir * (speed * drift_fraction)
		var lerp_t = 1.0 - exp(-DRIFT_SMOOTHING * delta)
		_drift_velocity_world = _drift_velocity_world.lerp(target_drift_vel, lerp_t)
		next_pos += _drift_velocity_world * delta
	else:
		# Быстро затухаем к нулю
		var lerp_t2 = 1.0 - exp(-DRIFT_SMOOTHING * delta)
		_drift_velocity_world = _drift_velocity_world.lerp(Vector3.ZERO, lerp_t2)

	# Небольшая «просадка» по Y при очень низкой стабильности (но без рандома)
	if stability < 0.35:
		next_pos.y -= (0.35 - stability) * 0.25 * GRAVITY * delta

	return next_pos

func get_imbalance_multiplier() -> float:
	"""Возвращает множитель разбалансировки в зависимости от отсутствующих моторов"""
	var missing_count = 4 - get_active_motors_count()
	match missing_count:
		0:
			return 1.0
		1:
			return 1.4
		2:
			return 2.0
		3:
			return 2.6
		_:
			return 1.0
func _assign_propellers_to_motor_slots_stable(propeller_nodes: Array, root: Node3D) -> Array:
	# Возвращает Array из словарей:
	# { "node": Node3D, "slot": int, "local_pos": Vector3 }
	var props: Array = []
	for p in propeller_nodes:
		var n: Node3D = p as Node3D
		if n != null and is_instance_valid(n):
			props.append(n)

	var slots: Array = []
	for i in range(motors.size()):
		if bool(motors[i].get("present", false)):
			slots.append(i)

	var result: Array = []
	if props.is_empty() or slots.is_empty():
		for n2 in props:
			var lp2: Vector3 = (root.to_local(n2.global_position) if root else n2.position)
			result.append({"node": n2, "slot": 0, "local_pos": lp2})
		return result

	# локальные позиции пропеллеров
	var prop_pos: Array = []
	for n3 in props:
		var lp3: Vector3 = (root.to_local(n3.global_position) if root else n3.position)
		prop_pos.append(lp3)

	var p_count: int = props.size()
	var s_count: int = slots.size()

	# primary matching (минимальная сумма расстояний), чтобы не было [0,1,1,2] при 4/4
	var primary_map: Dictionary = {}
	if p_count >= s_count:
		# каждому слоту по одному пропеллеру (если пропов >= слотов)
		primary_map = _stable_match_slots_to_props(prop_pos, slots)
	else:
		# каждому пропеллеру уникальный слот (если пропов < слотов)
		primary_map = _stable_match_props_to_slots(prop_pos, slots)

	# отмечаем использованные пропеллеры
	var used_prop: Array = []
	used_prop.resize(p_count)
	for i in range(p_count):
		used_prop[i] = false

	# добавляем primary
	for k in primary_map.keys():
		var pi: int = int(k)
		var si: int = int(primary_map[k])
		if pi < 0 or pi >= p_count:
			continue
		used_prop[pi] = true
		result.append({
			"node": props[pi],
			"slot": si,
			"local_pos": prop_pos[pi]
		})

	# leftover: остальные пропеллеры -> ближайший слот
	for pi2 in range(p_count):
		if bool(used_prop[pi2]):
			continue
		var best_slot: int = _nearest_present_slot_for_local_pos(prop_pos[pi2], slots)
		result.append({
			"node": props[pi2],
			"slot": best_slot,
			"local_pos": prop_pos[pi2]
		})

	return result


func _nearest_present_slot_for_local_pos(p_local: Vector3, slots: Array) -> int:
	var best_slot: int = int(slots[0])
	var best_d: float = 1.0e30

	for s in slots:
		var si: int = int(s)
		var mp: Vector3 = motors[si].get("position", Vector3.ZERO)
		var d: float = p_local.distance_squared_to(mp)
		if d < best_d:
			best_d = d
			best_slot = si

	return best_slot


func _stable_match_slots_to_props(prop_pos: Array, slots: Array) -> Dictionary:
	# Мапа: prop_index -> slot_index, где покрыты ВСЕ slots (каждому слоту по 1 пропу)
	var p_count: int = prop_pos.size()

	var used: Array = []
	used.resize(p_count)
	for i in range(p_count):
		used[i] = false

	var best: Dictionary = {"cost": 1.0e30, "map": {}}
	var cur_map: Dictionary = {}
	_stable_match_slots_to_props_rec(prop_pos, slots, 0, used, cur_map, 0.0, best)

	var out: Dictionary = {}
	var m: Variant = best.get("map")
	if typeof(m) == TYPE_DICTIONARY:
		out = m as Dictionary
	return out


func _stable_match_slots_to_props_rec(prop_pos: Array, slots: Array, slot_i: int, used: Array, cur_map: Dictionary, cur_cost: float, best: Dictionary) -> void:
	var best_cost: float = float(best.get("cost", 1.0e30))
	if cur_cost >= best_cost:
		return

	if slot_i >= slots.size():
		best["cost"] = cur_cost
		best["map"] = cur_map.duplicate(true)
		return

	var slot: int = int(slots[slot_i])
	var motor_p: Vector3 = motors[slot].get("position", Vector3.ZERO)

	for pi in range(prop_pos.size()):
		if bool(used[pi]):
			continue
		var d: float = (prop_pos[pi] as Vector3).distance_squared_to(motor_p)

		used[pi] = true
		cur_map[pi] = slot
		_stable_match_slots_to_props_rec(prop_pos, slots, slot_i + 1, used, cur_map, cur_cost + d, best)
		cur_map.erase(pi)
		used[pi] = false


func _stable_match_props_to_slots(prop_pos: Array, slots: Array) -> Dictionary:
	# Мапа: prop_index -> slot_index, где у каждого пропа уникальный слот
	var s_count: int = slots.size()

	var used_slots: Array = []
	used_slots.resize(s_count)
	for i in range(s_count):
		used_slots[i] = false

	var best: Dictionary = {"cost": 1.0e30, "map": {}}
	var cur_map: Dictionary = {}
	_stable_match_props_to_slots_rec(prop_pos, slots, 0, used_slots, cur_map, 0.0, best)

	var out: Dictionary = {}
	var m: Variant = best.get("map")
	if typeof(m) == TYPE_DICTIONARY:
		out = m as Dictionary
	return out


func _stable_match_props_to_slots_rec(prop_pos: Array, slots: Array, prop_i: int, used_slots: Array, cur_map: Dictionary, cur_cost: float, best: Dictionary) -> void:
	var best_cost: float = float(best.get("cost", 1.0e30))
	if cur_cost >= best_cost:
		return

	if prop_i >= prop_pos.size():
		best["cost"] = cur_cost
		best["map"] = cur_map.duplicate(true)
		return

	var p_local: Vector3 = prop_pos[prop_i] as Vector3

	for si_idx in range(slots.size()):
		if bool(used_slots[si_idx]):
			continue
		var slot: int = int(slots[si_idx])
		var motor_p: Vector3 = motors[slot].get("position", Vector3.ZERO)
		var d: float = p_local.distance_squared_to(motor_p)

		used_slots[si_idx] = true
		cur_map[prop_i] = slot
		_stable_match_props_to_slots_rec(prop_pos, slots, prop_i + 1, used_slots, cur_map, cur_cost + d, best)
		cur_map.erase(prop_i)
		used_slots[si_idx] = false
