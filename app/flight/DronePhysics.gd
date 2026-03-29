class_name DronePhysics
extends Node

# Физические константы
const GRAVITY = 9.8
const AIR_DENSITY = 1.2
const PROP_EFFICIENCY = 0.8
const DRAG_COEFFICIENT = 0.3
const MAX_TILT_ANGLE = 42.0  # Максимальный угол крена в градусах
const TILT_RESPONSE = 2.0    # Коэффициент отклика на крен

# Плавность дрейфа/кренов (без рандома и без «телепортов»)
const DRIFT_SMOOTHING = 10.0 # Чем больше — тем быстрее дрейф выходит на целевую скорость
const HORIZONTAL_ACCEL = 10.5
const HORIZONTAL_BRAKE = 13.0
const VERTICAL_ACCEL = 8.0
const VELOCITY_DAMPING = 7.5
const INPUT_TILT_ANGLE = 14.0
const DRIFT_TILT_ANGLE = 4.5
const VERTICAL_TILT_ANGLE = 5.5
const MAX_CONTROL_SPEED_FACTOR = 1.08
const MIN_STEP_SPEED_FACTOR = 0.22
const DRIFT_STRENGTH_SCALE = 0.42
const DRIFT_FRACTION_SCALE = 0.13
const MAX_DRIFT_FRACTION = 0.24
const VERTICAL_SINK_SCALE = 0.18
const LOW_STABILITY_SINK_THRESHOLD = 0.22
const LOW_STABILITY_SINK_SCALE = 0.12

# Ссылка на глобальные характеристики компонентов
var component_stats = {
	"frame": {
		"Рама1": {"mass": 1.0, "durability": 100},
		"Рама2": {"mass": 1.5, "durability": 150},
		"Рама3": {"mass": 2.0, "durability": 200},
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
var platform_type: String = DronePlatformConfig.PLATFORM_QUAD
var motor_slot_configs: Array[Dictionary] = []

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
var _unstable_time: float = 0.0  # Накопитель нестабильности (только для мягкой деградации поведения)
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
var _command_velocity_world: Vector3 = Vector3.ZERO

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

func _get_horizontal_axes(root: Node3D) -> Dictionary:
	# Берём только горизонтальную проекцию осей дрона (yaw), чтобы визуальный наклон (pitch/roll)
	# и вложенные повороты компонентов не «перекручивали» оси дрейфа.
	var b := root.global_transform.basis
	var right := b.x
	right.y = 0.0
	if right.length() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var back := b.z
	back.y = 0.0
	if back.length() < 0.0001:
		back = Vector3.BACK
	else:
		back = back.normalized()
	return {"right": right, "back": back}

func _global_to_flat_local(global_pos: Vector3, root: Node3D) -> Vector3:
	# Координаты относительно дрона в «плоской» системе:
	# X = вправо, Z = назад (как в Transform3D), а «вперёд» = -Z.
	var axes: Dictionary = _get_horizontal_axes(root)
	var right_axis: Vector3 = axes.get("right", Vector3.RIGHT)
	var back_axis: Vector3 = axes.get("back", Vector3.BACK)
	var offset: Vector3 = global_pos - root.global_position
	var x: float = right_axis.dot(offset)
	var z: float = back_axis.dot(offset)
	return Vector3(x, offset.y, z)

func _flat_local_dir_to_world_dir(local_dir: Vector3, root: Node3D) -> Vector3:
	var axes: Dictionary = _get_horizontal_axes(root)
	var right_axis: Vector3 = axes.get("right", Vector3.RIGHT)
	var back_axis: Vector3 = axes.get("back", Vector3.BACK)
	return right_axis * local_dir.x + Vector3.UP * local_dir.y + back_axis * local_dir.z

func _get_platform_slot_configs() -> Array[Dictionary]:
	if not motor_slot_configs.is_empty():
		return motor_slot_configs
	return DronePlatformConfig.get_motor_slots(platform_type)

func _get_required_motor_count() -> int:
	var slot_count: int = _get_platform_slot_configs().size()
	if slot_count > 0:
		return slot_count
	return MOTOR_POSITIONS.size()

func _get_min_takeoff_motor_count() -> int:
	return clampi(DronePlatformConfig.get_min_takeoff_motors(platform_type), 1, maxi(_get_required_motor_count(), 1))

func _get_platform_speed_multiplier() -> float:
	return maxf(DronePlatformConfig.get_speed_multiplier(platform_type), 0.1)

func _get_baseline_effective_thrust_per_slot() -> float:
	return 8.0 * 0.9

func _get_total_effective_thrust() -> float:
	var total_effective_thrust: float = 0.0
	for motor in motors:
		if not bool(motor.get("has_propeller", false)):
			continue
		var thrust: float = float(motor.get("thrust", 0.0))
		var efficiency: float = maxf(float(motor.get("propeller_efficiency", PROP_EFFICIENCY)), 0.01)
		total_effective_thrust += thrust * efficiency
	return total_effective_thrust

func _get_effective_power_factor() -> float:
	var required_motors: int = maxi(_get_required_motor_count(), 1)
	var baseline_total: float = float(required_motors) * _get_baseline_effective_thrust_per_slot()
	return clampf(_get_total_effective_thrust() / maxf(baseline_total, 0.001), 0.0, 2.0)

func get_speed_multiplier() -> float:
	var power_factor: float = _get_effective_power_factor()
	var stability: float = get_stability_factor()
	var power_speed: float = clampf(0.28 + power_factor * 0.72, MIN_STEP_SPEED_FACTOR, 1.40)
	var stability_speed: float = clampf(0.72 + stability * 0.28, 0.52, 1.0)
	return _get_platform_speed_multiplier() * power_speed * stability_speed

func get_step_duration(direction: int = 0, steps: int = 1) -> float:
	var is_vertical_move: bool = direction == 4 or direction == 5
	var base_duration: float = 0.78 if is_vertical_move else 0.92
	var speed_factor: float = maxf(get_speed_multiplier(), MIN_STEP_SPEED_FACTOR)
	return (base_duration / speed_factor) * float(maxi(steps, 1))

func is_grid_stable() -> bool:
	var required_motors: int = maxi(_get_required_motor_count(), 1)
	if get_active_motors_count() < required_motors:
		return false
	if not can_take_off():
		return false
	return get_stability_factor() >= 0.96 and thrust_imbalance.length() <= _get_reference_radius() * 0.04

func _get_reference_radius() -> float:
	var slots: Array[Dictionary] = _get_platform_slot_configs()
	if slots.is_empty():
		return 1.0

	var total_radius: float = 0.0
	for slot_variant in slots:
		var slot_data: Dictionary = slot_variant as Dictionary
		var pos: Vector3 = slot_data.get("position", Vector3.ZERO)
		total_radius += Vector2(pos.x, pos.z).length()
	return maxf(total_radius / float(slots.size()), 0.001)

func _get_slot_side_name(local_pos: Vector3) -> String:
	var front_threshold: float = 0.12
	var side_parts: Array[String] = []

	if local_pos.z < -front_threshold:
		side_parts.append("front")
	elif local_pos.z > front_threshold:
		side_parts.append("back")

	if local_pos.x < -front_threshold:
		side_parts.append("left")
	elif local_pos.x > front_threshold:
		side_parts.append("right")

	if side_parts.is_empty():
		if absf(local_pos.x) >= absf(local_pos.z):
			side_parts.append("right" if local_pos.x >= 0.0 else "left")
		else:
			side_parts.append("back" if local_pos.z >= 0.0 else "front")

	return "_".join(side_parts)

func _slot_from_local_pos(local_pos: Vector3) -> int:
	return _closest_slot_by_local_pos(local_pos)

func _closest_slot_by_local_pos(local_pos: Vector3) -> int:
	var best_i = 0
	var best_d = INF
	var slot_configs: Array[Dictionary] = _get_platform_slot_configs()
	if slot_configs.is_empty():
		for i in range(MOTOR_POSITIONS.size()):
			var fallback_pos: Vector3 = MOTOR_POSITIONS[i]["pos"]
			var fallback_distance: float = local_pos.distance_to(fallback_pos)
			if fallback_distance < best_d:
				best_d = fallback_distance
				best_i = i
		return best_i

	for i in range(slot_configs.size()):
		var slot_data: Dictionary = slot_configs[i] as Dictionary
		var slot_pos: Vector3 = slot_data.get("position", Vector3.ZERO)
		var d = local_pos.distance_to(slot_pos)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i

func _get_slot_distance(local_pos: Vector3, slot_index: int) -> float:
	var slot_configs: Array[Dictionary] = _get_platform_slot_configs()
	if slot_index < 0 or slot_index >= slot_configs.size():
		return INF
	var slot_data: Dictionary = slot_configs[slot_index] as Dictionary
	var slot_pos: Vector3 = slot_data.get("position", Vector3.ZERO)
	return local_pos.distance_to(slot_pos)

func _resolve_slot_from_position(local_pos: Vector3, preferred_slot: int = -1) -> int:
	var slot_configs: Array[Dictionary] = _get_platform_slot_configs()
	if slot_configs.is_empty():
		if preferred_slot >= 0:
			return clampi(preferred_slot, 0, maxi(MOTOR_POSITIONS.size() - 1, 0))
		return 0

	var nearest_slot: int = _slot_from_local_pos(local_pos)
	if preferred_slot < 0 or preferred_slot >= slot_configs.size():
		return nearest_slot
	if preferred_slot == nearest_slot:
		return preferred_slot

	var preferred_distance: float = _get_slot_distance(local_pos, preferred_slot)
	var nearest_distance: float = _get_slot_distance(local_pos, nearest_slot)
	var mismatch_margin: float = maxf(_get_reference_radius() * 0.18, 0.35)
	if preferred_distance > nearest_distance + mismatch_margin:
		return nearest_slot
	return preferred_slot

func _local_dir_to_world_dir(local_dir: Vector3) -> Vector3:
	var root := _get_drone_root()
	if root:
		return _flat_local_dir_to_world_dir(local_dir, root)
	return local_dir

func _world_dir_to_flat_local_dir(world_dir: Vector3, root: Node3D) -> Vector3:
	var axes: Dictionary = _get_horizontal_axes(root)
	var right_axis: Vector3 = axes.get("right", Vector3.RIGHT)
	var back_axis: Vector3 = axes.get("back", Vector3.BACK)
	return Vector3(
		right_axis.dot(world_dir),
		0.0,
		back_axis.dot(world_dir)
	)

func _get_command_local_direction(direction: int) -> Vector3:
	match direction:
		0:
			return Vector3(0.0, 0.0, -1.0)
		1:
			return Vector3(0.0, 0.0, 1.0)
		2:
			return Vector3(-1.0, 0.0, 0.0)
		3:
			return Vector3(1.0, 0.0, 0.0)
		4:
			return Vector3(0.0, 1.0, 0.0)
		5:
			return Vector3(0.0, -1.0, 0.0)
		_:
			return Vector3.ZERO

func reset_motion_state(start_world_position: Vector3 = Vector3.ZERO) -> void:
	velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	orientation = Quaternion.IDENTITY
	is_airborne = false
	last_position = start_world_position
	_unstable_time = 0.0
	_drift_velocity_world = Vector3.ZERO
	_command_velocity_world = Vector3.ZERO

func settle_after_cell_move(final_world_position: Vector3) -> void:
	# Сохраняем ощущение инерции между шагами, но гасим свободный дрейф,
	# чтобы движение оставалось привязанным к сетке.
	last_position = final_world_position
	is_airborne = final_world_position.y > 0.25
	velocity.x *= 0.34
	velocity.z *= 0.34
	velocity.y *= 0.18
	_drift_velocity_world *= 0.22
	_command_velocity_world *= 0.18


func _extract_component_name(node: Node, category: String, default_name: String) -> String:
	var known_components: Dictionary = component_stats.get(category, {})
	if known_components.is_empty():
		return default_name

	# 1) meta
	var meta_key = "%s_type" % category
	if node and is_instance_valid(node) and node.has_meta(meta_key):
		var meta_name: String = str(node.get_meta(meta_key))
		if known_components.has(meta_name):
			return meta_name

	# 1.5) runtime metadata from assembly/export
	if node and is_instance_valid(node) and node.has_meta("component_type"):
		var component_type_meta: String = str(node.get_meta("component_type"))
		if known_components.has(component_type_meta):
			return component_type_meta

	# 2) exported property on assembly component
	if node and is_instance_valid(node):
		var component_name_variant: Variant = node.get("component_name")
		if typeof(component_name_variant) == TYPE_STRING:
			var component_name: String = str(component_name_variant)
			if known_components.has(component_name):
				return component_name

		var component_type_variant: Variant = node.get("component_type")
		if typeof(component_type_variant) == TYPE_STRING:
			var component_type_name: String = str(component_type_variant)
			if known_components.has(component_type_name):
				return component_type_name

	# 3) name contains known key
	if node and is_instance_valid(node):
		for key in known_components.keys():
			if key in node.name:
				return key

	return default_name

func _resolve_platform_type(frame, motor_nodes: Array) -> String:
	var root := _get_drone_root()
	if root != null and root.has_meta("drone_info"):
		var info_variant: Variant = root.get_meta("drone_info")
		if typeof(info_variant) == TYPE_DICTIONARY:
			var info: Dictionary = info_variant as Dictionary
			var from_metadata: String = str(info.get("platform_type", ""))
			if not from_metadata.is_empty():
				return DronePlatformConfig.normalize_platform_type(from_metadata)

	if frame != null and is_instance_valid(frame):
		if frame.has_method("get_drone_platform_type"):
			return DronePlatformConfig.normalize_platform_type(str(frame.call("get_drone_platform_type")))
		var frame_platform: Variant = frame.get("drone_platform_type")
		if typeof(frame_platform) == TYPE_STRING and not str(frame_platform).is_empty():
			return DronePlatformConfig.normalize_platform_type(str(frame_platform))

	return DronePlatformConfig.infer_platform_from_motor_count(motor_nodes.size())

func _get_frame_mass(frame_type: String) -> float:
	if component_stats["frame"].has(frame_type):
		return float(component_stats["frame"][frame_type]["mass"])
	match platform_type:
		DronePlatformConfig.PLATFORM_HEXA:
			return 1.8
		DronePlatformConfig.PLATFORM_OCTO:
			return 2.4
		_:
			return 1.0

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
			var m_local = _global_to_flat_local(closest_motor.global_position, root)
			return _slot_from_local_pos(m_local)

		# Фоллбек: по позиции пропеллера
		var p_local = _global_to_flat_local(propeller_pos, root)
		return _slot_from_local_pos(p_local)

	# Если root не нашли (необычная иерархия) — старый фоллбек
	if motor_nodes.is_empty():
		return 0
	return 0

func setup_from_components(frame, board, motor_nodes: Array, propeller_nodes: Array):
	"""Инициализация физики на основе компонентов дрона"""
	var root = _get_drone_root()
	platform_type = _resolve_platform_type(frame, motor_nodes)
	motor_slot_configs = DronePlatformConfig.get_motor_slots(platform_type)
	if motor_slot_configs.is_empty():
		for slot_data in MOTOR_POSITIONS:
			motor_slot_configs.append({
				"position": slot_data["pos"],
				"label": slot_data["side"]
			})

	# Собираем массы
	var masses = []
	var positions = []

	# Рама
	if frame and is_instance_valid(frame):
		var frame_type = _extract_component_name(frame, "frame", "Рама1")
		frame_mass = _get_frame_mass(frame_type)
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

	# ===== МОТОРЫ: подготавливаем все слоты платформы, даже если каких-то нод нет =====
	motors.clear()
	missing_motors.clear()
	missing_sides = {"front": false, "back": false, "left": false, "right": false}

	for i in range(motor_slot_configs.size()):
		var slot_config: Dictionary = motor_slot_configs[i] as Dictionary
		var slot_pos: Vector3 = slot_config.get("position", Vector3.ZERO)
		motors.append({
			"position": slot_pos,
			"thrust": 0.0,
			"has_propeller": false,
			"index": i,
			"motor_type": "",
			"side": _get_slot_side_name(slot_pos),
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

		var local_pos = (_global_to_flat_local((motor as Node3D).global_position, root) if root else (motor as Node3D).position)
		var preferred_slot: int = -1
		if (motor as Node3D).has_meta("motor_slot"):
			preferred_slot = int((motor as Node3D).get_meta("motor_slot"))
		var slot: int = _resolve_slot_from_position(local_pos, preferred_slot)
		if used_slots.has(slot):
			var nearest_slot: int = _closest_slot_by_local_pos(local_pos)
			if not used_slots.has(nearest_slot):
				slot = nearest_slot
			else:
				for k in range(motor_slot_configs.size()):
					if not used_slots.has(k):
						slot = k
						break
		used_slots[slot] = true
		var canonical_slot_pos: Vector3 = motor_slot_configs[slot].get("position", local_pos)
		(motor as Node3D).set_meta("motor_slot", slot)
		motors[slot]["present"] = true
		motors[slot]["motor_type"] = motor_type
		motors[slot]["thrust"] = motor_thrust
		motors[slot]["position"] = canonical_slot_pos
		motors[slot]["actual_position"] = local_pos

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

		var matched_slot: int = int(a.get("slot", 0))
		var preferred_slot: int = -1
		if prop.has_meta("attached_motor_slot"):
			preferred_slot = int(prop.get_meta("attached_motor_slot"))
		elif prop.has_meta("motor_slot"):
			preferred_slot = int(prop.get_meta("motor_slot"))
		var local_pos: Vector3 = a.get("local_pos", Vector3.ZERO)
		var slot: int = _resolve_slot_from_position(local_pos, preferred_slot)
		if slot < 0 or slot >= motor_slot_configs.size() or not bool(motors[slot].get("present", false)):
			slot = clampi(matched_slot, 0, maxi(motor_slot_configs.size() - 1, 0))
		var propeller_type: String = _extract_component_name(prop, "propeller", str(component_stats["propeller"].keys()[0]))
		var propeller_efficiency: float = float(component_stats["propeller"][propeller_type]["efficiency"])
		var propeller_mass: float = float(component_stats["propeller"][propeller_type]["mass"])
		prop.set_meta("motor_slot", slot)
		prop.set_meta("attached_motor_slot", slot)

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
	var pcnts: Array = []
	pcnts.resize(motor_slot_configs.size())
	for i in range(pcnts.size()):
		pcnts[i] = 0
	for p in propellers:
		var si: int = int(p.get("motor_index", 0))
		if si >= 0 and si < pcnts.size():
			pcnts[si] += 1
	print("🧾 Пропеллеры по слотам: ", pcnts)

# Отмечаем отсутствующие моторы/пропеллеры и определяем ослабленные стороны
	analyze_motor_configuration()

	# Рассчитываем общую массу и центр масс
	calculate_mass_properties(masses, positions)

	# Рассчитываем подъемную силу и баланс
	calculate_lift_and_balance()
	reset_motion_state(root.global_position if root != null else Vector3.ZERO)

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
	var total_side_weight := {"front": 0.0, "back": 0.0, "left": 0.0, "right": 0.0}
	var active_side_weight := {"front": 0.0, "back": 0.0, "left": 0.0, "right": 0.0}

	for i in range(motors.size()):
		var slot_data: Dictionary = motors[i]
		var active: bool = bool(slot_data.get("present", false)) and bool(slot_data.get("propeller_present", false))
		var slot_pos: Vector3 = slot_data.get("position", Vector3.ZERO)
		var front_weight: float = maxf(-slot_pos.z, 0.0)
		var back_weight: float = maxf(slot_pos.z, 0.0)
		var left_weight: float = maxf(-slot_pos.x, 0.0)
		var right_weight: float = maxf(slot_pos.x, 0.0)

		total_side_weight["front"] += front_weight
		total_side_weight["back"] += back_weight
		total_side_weight["left"] += left_weight
		total_side_weight["right"] += right_weight
		if active:
			active_side_weight["front"] += front_weight
			active_side_weight["back"] += back_weight
			active_side_weight["left"] += left_weight
			active_side_weight["right"] += right_weight

		slot_data["has_propeller"] = active
		motors[i] = slot_data

		if not active:
			missing_motors.append(i)

	for side_name in ["front", "back", "left", "right"]:
		var side_total: float = float(total_side_weight.get(side_name, 0.0))
		if side_total <= 0.001:
			continue
		var side_active: float = float(active_side_weight.get(side_name, 0.0))
		missing_sides[side_name] = side_active <= side_total * 0.45

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
	var active_motors: int = get_active_motors_count()
	if active_motors <= 0:
		return 0.0

	var required_motors: int = maxi(_get_required_motor_count(), 1)
	var motor_factor: float = float(active_motors) / float(required_motors)
	var imbalance: float = thrust_imbalance.length() / _get_reference_radius()
	var balance_factor: float = 1.0 - clampf(imbalance * 1.45, 0.0, 0.8)

	var stability: float = motor_factor * (0.30 + 0.70 * balance_factor)
	return clampf(stability, 0.0, 1.0)

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
	behavior["max_speed"] = get_speed_multiplier()

	return behavior

func can_take_off() -> bool:
	var active_motors_count := get_active_motors_count()
	var required_motors: int = maxi(_get_required_motor_count(), 1)
	var min_takeoff_motors: int = _get_min_takeoff_motor_count()
	var active_fraction: float = float(active_motors_count) / float(required_motors)
	if active_motors_count < min_takeoff_motors:
		return false
	if total_mass <= 0.001:
		return true
	var lift_ratio := lift_capacity / total_mass
	var full_build_ratio: float = 0.88
	var partial_build_ratio: float = lerpf(0.34, 0.58, clampf(active_fraction, 0.0, 1.0))
	var min_ratio: float = full_build_ratio if active_motors_count >= required_motors else partial_build_ratio
	return lift_ratio >= min_ratio
func get_active_motors_count() -> int:
	"""Counts active motor slots with both motor and propeller."""
	var count = 0
	for motor in motors:
		if bool(motor.get("has_propeller", false)):
			count += 1
	return count
func _get_missing_fraction() -> float:
	var required_motors: int = maxi(_get_required_motor_count(), 1)
	return clampf(float(required_motors - get_active_motors_count()) / float(required_motors), 0.0, 1.0)
func _get_normalized_imbalance() -> float:
	return clampf(thrust_imbalance.length() / _get_reference_radius(), 0.0, 1.0)
func _get_platform_imbalance_sensitivity() -> float:
	match platform_type:
		DronePlatformConfig.PLATFORM_QUAD:
			return 1.15
		DronePlatformConfig.PLATFORM_HEXA:
			return 0.88
		DronePlatformConfig.PLATFORM_OCTO:
			return 0.78
		_:
			return 1.0

func _get_platform_visual_tilt_limit() -> float:
	match platform_type:
		DronePlatformConfig.PLATFORM_QUAD:
			return 55.0
		DronePlatformConfig.PLATFORM_HEXA:
			return 42.0
		DronePlatformConfig.PLATFORM_OCTO:
			return 38.0
		_:
			return 42.0
func _get_visual_imbalance_strength() -> float:
	var base_strength: float = _get_missing_fraction() * 1.35 + _get_normalized_imbalance() * 1.25
	return clampf(base_strength * _get_platform_imbalance_sensitivity(), 0.0, 1.0)
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

	var thrust_center := Vector3.ZERO
	var total_thrust := 0.0

	for motor in motors:
		# active слот (мотор есть И пропеллер есть)
		if bool(motor.get("has_propeller", false)):
			var thrust := float(motor.get("thrust", 0.0))
			var eff := float(motor.get("propeller_efficiency", PROP_EFFICIENCY))
			var effective_thrust := thrust * eff

			lift_capacity += effective_thrust
			total_thrust += effective_thrust
			# Центр тяги считаем только по активным моторам, в XZ-плоскости
			thrust_center += Vector3(float(motor["position"].x), 0.0, float(motor["position"].z)) * effective_thrust

	if total_thrust > 0.0:
		var thrust_center_position := thrust_center / total_thrust

		# ВАЖНО:
		# Раньше мы считали через center_of_mass, и из-за смещения масс (например, когда мотор отсутствует и масса тоже пропадает)
		# направление могло «переворачиваться». Для поведения «дрейфует к стороне, где НЕТ тяги» используем геометрический центр (0,0,0).
		# Если справа нет мотора -> центр тяги смещается влево -> слабая сторона = -thrust_center_position (вправо).
		thrust_imbalance = -Vector3(thrust_center_position.x, 0.0, thrust_center_position.z)
	else:
		thrust_imbalance = Vector3.ZERO

	var active_motors := get_active_motors_count()
	var imbalance_limit: float = _get_reference_radius() * 0.05
	is_stable = (active_motors == _get_required_motor_count() and thrust_imbalance.length() < imbalance_limit)

func check_crash_condition(current_position: Vector3, ground_level: float = 0.0, delta: float = 0.0) -> bool:
	"""Проверяет, не упал ли дрон.
	Важно: нестабильность сама по себе больше не считается отдельным крэшем.
	Дрон падает только при реальном падении на землю или полном отсутствии активных моторов."""
	var behavior = get_flight_behavior()

	# 1. Дрон упал ниже уровня земли
	if current_position.y < ground_level - 1.0:
		print("💥 Дрон упал на землю!")
		return true

	# 2. Нестабильность больше не считается отдельным крэшем.
	# Мы лишь накапливаем время, чтобы движение/дрифт могли реагировать на долгую раскачку,
	# но сам дрон не «умирает» только из-за того, что его заносит.
	var stab := float(behavior.get("stability", 0.0))
	var airborne := current_position.y > ground_level + 0.25
	if airborne and delta > 0.0 and stab < 0.15:
		_unstable_time += delta
	else:
		_unstable_time = 0.0

	# 3. Нет активных моторов
	var active_motors = get_active_motors_count()
	if active_motors == 0:
		print("💥 Нет активных моторов!")
		return true

	return false

func get_translation_factor() -> float:
	"""0..1: насколько «сильно» дрон способен двигаться (без зависимости от направления)"""
	# Основной смысл: меньше моторов -> меньше расстояние; нестабильность чуть снижает
	var relative_speed: float = get_speed_multiplier() / maxf(_get_platform_speed_multiplier(), 0.001)
	return clampf(relative_speed, 0.18, MAX_CONTROL_SPEED_FACTOR)

func get_drift_direction_world() -> Vector3:
	"""Направление дрейфа в мировых координатах (куда уносит/заваливает).
	Важно: переводим локальный XZ в мир без влияния roll/pitch (только "горизонт"),
	иначе при визуальном крене направление может «плыть».
	"""
	if thrust_imbalance == Vector3.ZERO:
		return Vector3.ZERO

	var dir_local := thrust_imbalance
	dir_local.y = 0.0
	if dir_local.length() < 0.0001:
		return Vector3.ZERO

	var root := _get_drone_root()
	if root:
		# Берем горизонтальные оси из текущего basis, но проецируем в XZ-плоскость
		var right := root.global_transform.basis.x
		right.y = 0.0
		var back := root.global_transform.basis.z
		back.y = 0.0

		if right.length() < 0.0001 or back.length() < 0.0001:
			return dir_local.normalized()

		right = right.normalized()
		back = back.normalized()

		# local (x,z) -> world (right, back)
		var dir_world := right * dir_local.x + back * dir_local.z
		dir_world.y = 0.0
		return dir_world.normalized() if dir_world.length() > 0.0001 else Vector3.ZERO

	return dir_local.normalized()

func get_visual_tilt_degrees(direction: int = -1) -> Vector3:
	"""Returns target visual tilt in degrees."""
	var root: Node3D = _get_drone_root()
	var command_local_dir: Vector3 = _get_command_local_direction(direction)
	var horizontal_command: Vector3 = Vector3(command_local_dir.x, 0.0, command_local_dir.z)
	var motion_world: Vector3 = velocity + _drift_velocity_world + _command_velocity_world * 0.25
	motion_world.y = 0.0
	if root != null and motion_world.length() > 0.001:
		var motion_local: Vector3 = _world_dir_to_flat_local_dir(motion_world.normalized(), root)
		horizontal_command = motion_local if horizontal_command == Vector3.ZERO else horizontal_command.lerp(motion_local, 0.65)
	var drift_world: Vector3 = get_drift_direction_world()
	var drift_local: Vector3 = Vector3.ZERO
	if root != null and drift_world.length() > 0.001:
		drift_local = _world_dir_to_flat_local_dir(drift_world.normalized(), root)
	var imbalance_local: Vector3 = thrust_imbalance
	imbalance_local.y = 0.0
	if imbalance_local.length() > 0.001:
		imbalance_local = imbalance_local.normalized()
	var translation_factor: float = get_translation_factor()
	var stability: float = get_stability_factor()
	var input_strength: float = clampf(0.35 + translation_factor * 0.65, 0.0, 1.0)
	var drift_strength: float = clampf((1.0 - stability) * DRIFT_STRENGTH_SCALE * get_imbalance_multiplier(), 0.0, 0.45)
	var command_strength: float = clampf(horizontal_command.length(), 0.0, 1.0)
	var motion_strength: float = clampf(motion_world.length() / 28.0, 0.0, 1.0)
	var imbalance_motion_strength: float = maxf(command_strength, motion_strength)
	var visual_tilt_limit: float = _get_platform_visual_tilt_limit()
	var imbalance_tilt_angle: float = lerpf(8.0, visual_tilt_limit, imbalance_motion_strength)
	imbalance_tilt_angle += command_strength * 8.0
	var imbalance_strength: float = _get_visual_imbalance_strength()
	var pitch: float = horizontal_command.z * INPUT_TILT_ANGLE * input_strength
	pitch += drift_local.z * DRIFT_TILT_ANGLE * drift_strength
	pitch += imbalance_local.z * imbalance_tilt_angle * imbalance_strength
	if direction == 4:
		pitch -= VERTICAL_TILT_ANGLE * input_strength
	elif direction == 5:
		pitch += VERTICAL_TILT_ANGLE * input_strength
	var roll: float = -(horizontal_command.x * INPUT_TILT_ANGLE * input_strength + drift_local.x * DRIFT_TILT_ANGLE * drift_strength)
	roll -= imbalance_local.x * imbalance_tilt_angle * imbalance_strength
	return Vector3(
		clampf(pitch, -visual_tilt_limit, visual_tilt_limit),
		0.0,
		clampf(roll, -visual_tilt_limit, visual_tilt_limit)
	)
func apply_movement_physics(direction: int, current_pos: Vector3, target_pos: Vector3, delta: float, speed: float = 32.0) -> Vector3:
	var safe_delta: float = maxf(delta, 0.0001)

	# Если взлететь нельзя — плавно теряем высоту и гасим горизонтальную скорость.
	if not can_take_off():
		var fall_target: Vector3 = Vector3.ZERO
		fall_target.y = -float(GRAVITY) * 0.55
		var fall_lerp: float = 1.0 - exp(-VERTICAL_ACCEL * safe_delta)
		velocity = velocity.lerp(fall_target, fall_lerp)
		_drift_velocity_world = _drift_velocity_world.lerp(Vector3.ZERO, 1.0 - exp(-DRIFT_SMOOTHING * safe_delta))
		_command_velocity_world = Vector3.ZERO
		var falling_position: Vector3 = current_pos + velocity * safe_delta
		last_position = falling_position
		is_airborne = true
		return falling_position

	var translation_factor: float = get_translation_factor()
	var stability: float = get_stability_factor()
	var to_target: Vector3 = target_pos - current_pos
	var desired_velocity: Vector3 = Vector3.ZERO

	if to_target.length() > 0.001:
		var desired_direction: Vector3 = to_target.normalized()
		var distance_factor: float = clampf(to_target.length() / maxf(speed * 1.6, 0.001), 0.72, 1.0)
		var control_speed: float = speed * clampf(translation_factor * (0.78 + 0.22 * stability), 0.18, MAX_CONTROL_SPEED_FACTOR)
		desired_velocity = desired_direction * control_speed * distance_factor

	_command_velocity_world = desired_velocity

	var horizontal_target: Vector3 = Vector3(desired_velocity.x, 0.0, desired_velocity.z)
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_response: float = lerpf(HORIZONTAL_ACCEL * 0.68, HORIZONTAL_ACCEL, stability)
	var horizontal_brake: float = lerpf(HORIZONTAL_BRAKE * 0.75, HORIZONTAL_BRAKE, stability)
	var horizontal_gain: float = horizontal_response if horizontal_target.length() > 0.01 else horizontal_brake
	var horizontal_lerp: float = 1.0 - exp(-horizontal_gain * safe_delta)
	horizontal_velocity = horizontal_velocity.lerp(horizontal_target, horizontal_lerp)

	var vertical_lerp: float = 1.0 - exp(-VERTICAL_ACCEL * safe_delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = lerpf(velocity.y, desired_velocity.y, vertical_lerp)

	if desired_velocity.length() < 0.001:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-VELOCITY_DAMPING * safe_delta))

	var controlled_displacement: Vector3 = velocity * safe_delta
	if to_target.length() > 0.0 and controlled_displacement.length() > to_target.length():
		controlled_displacement = to_target

	# Дрейф в сторону слабой тяги делаем мягче и инерционнее.
	var drift_dir: Vector3 = get_drift_direction_world()
	if drift_dir != Vector3.ZERO:
		var imbalance_mul: float = get_imbalance_multiplier()
		var instability_time_factor: float = clampf(_unstable_time * 0.35, 0.0, 0.18)
		var drift_fraction: float = clampf((1.0 - stability) * DRIFT_FRACTION_SCALE * imbalance_mul + instability_time_factor, 0.0, MAX_DRIFT_FRACTION)
		var target_drift_vel: Vector3 = drift_dir * (speed * drift_fraction)
		var drift_lerp: float = 1.0 - exp(-DRIFT_SMOOTHING * safe_delta)
		_drift_velocity_world = _drift_velocity_world.lerp(target_drift_vel, drift_lerp)
	else:
		_drift_velocity_world = _drift_velocity_world.lerp(Vector3.ZERO, 1.0 - exp(-DRIFT_SMOOTHING * safe_delta))

	var next_pos: Vector3 = current_pos + controlled_displacement + _drift_velocity_world * safe_delta

	# Просадка по Y при неполной сборке оставляем, но делаем более предсказуемой.
	var power_deficit: float = 1.0 - clampf(_get_effective_power_factor(), 0.0, 1.0)
	if power_deficit > 0.001:
		var sink_strength: float = clampf(power_deficit * (0.45 + 0.55 * (1.0 - stability)), 0.0, 1.0)
		var sink_speed: float = float(GRAVITY) * VERTICAL_SINK_SCALE * sink_strength
		next_pos.y -= sink_speed * safe_delta
		velocity.y -= sink_speed * 0.35 * safe_delta

	if stability < LOW_STABILITY_SINK_THRESHOLD:
		next_pos.y -= (LOW_STABILITY_SINK_THRESHOLD - stability) * LOW_STABILITY_SINK_SCALE * float(GRAVITY) * safe_delta

	last_position = next_pos
	is_airborne = next_pos.y > 0.25
	return next_pos

func get_imbalance_multiplier() -> float:
	"""Returns a softened physical imbalance multiplier."""
	var sensitivity: float = _get_platform_imbalance_sensitivity()
	return 1.0 + (_get_missing_fraction() * 0.85 + _get_normalized_imbalance() * 0.35) * sensitivity
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
			var lp2: Vector3 = (_global_to_flat_local(n2.global_position, root) if root else n2.position)
			result.append({"node": n2, "slot": 0, "local_pos": lp2})
		return result

	# локальные позиции пропеллеров
	var prop_pos: Array = []
	for n3 in props:
		var lp3: Vector3 = (_global_to_flat_local(n3.global_position, root) if root else n3.position)
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
