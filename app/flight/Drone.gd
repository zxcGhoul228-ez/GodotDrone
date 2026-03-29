extends CharacterBody3D

var has_reached_target: bool = false
var target_position: Vector3 = Vector3.ZERO
var is_executing = false
var current_tween: Tween
var crash_rotation_tween: Tween
var crash_fall_tween: Tween
var start_position: Vector3
var last_run_crashed: bool = false
var last_run_cancelled: bool = false

# ФИЗИКА ДРОНА
var drone_physics: DronePhysics
var flight_behavior: Dictionary = {}
var is_crashed: bool = false
var crash_position: Vector3 = Vector3.ZERO
var floor_height: float = 0.0
var movement_boundary_min: Vector3 = Vector3.ZERO
var movement_boundary_max: Vector3 = Vector3.ZERO
var has_movement_boundaries: bool = false

const GRID_SIZE = 32
const MOVE_SPEED = 1.0
const COLLISION_QUERY_LIMIT = 8
const MAX_WORLD_COLLISION_FOOTPRINT = 30.0
const MOVE_SETTLE_DISTANCE = 0.35
const MOVE_SETTLE_SPEED = 1.4
const MOVE_SETTLE_TIME = 0.22
const COMPONENT_SCRIPT_PATH = "res://app/assembly/component.gd"

# ПРОПЕЛЛЕРЫ
var propellers: Array[Node3D] = []
var is_propellers_rotating: bool = false
var current_propeller_speed: float = 0.0
var target_propeller_speed: float = 0.0
var propeller_acceleration: float = 720.0
var max_propeller_speed: float = 2160.0

signal program_finished(success: bool)
signal drone_moved

func _get_dynamic_step_duration(direction: int, steps: int = 1) -> float:
	var normalized_steps: int = maxi(steps, 1)
	if drone_physics != null and drone_physics.has_method("get_step_duration"):
		return maxf(float(drone_physics.call("get_step_duration", direction, normalized_steps)), 0.12)

	var is_vertical_move: bool = direction == 4 or direction == 5
	var base_duration: float = MOVE_SPEED * (0.78 if is_vertical_move else 0.92)
	return base_duration * float(normalized_steps)

func _ready():
	await get_tree().process_frame
	start_position = global_position
	
	# УВЕЛИЧИВАЕМ РАЗМЕР ДРОНА В 2 РАЗА
	scale = Vector3(6.0, 6.0, 6.0)
	print("🚁 Масштабирую дрон: ", scale)
	
	# ГАРАНТИРОВАННЫЙ ПОИСК ПРОПЕЛЛЕРОВ
	propellers = find_propellers_guaranteed()
	if propellers.is_empty():
		await get_tree().process_frame
		propellers = find_propellers_guaranteed()
	if propellers.is_empty():
		await get_tree().physics_frame
		propellers = find_propellers_guaranteed()
	_repair_missing_propellers_from_metadata()
	propellers = find_propellers_guaranteed()
	
	print("🚁 Дрон готов, масштаб: ", scale)
	print("🌀 Найдено пропеллеров: ", propellers.size())
	
	# Даже если пропеллеров нет, всё равно инициализируем физику
	_ensure_collision()
	_fit_collision_shape_to_grid()
	global_position = _clamp_above_floor(global_position)
	start_position = _clamp_above_floor(start_position)
	init_drone_physics()
	_reset_physics_motion_state()
	
	# Если пропеллеров нет, показываем предупреждение
	if propellers.size() == 0:
		print("⚠️ ВНИМАНИЕ: Дрон без пропеллеров! Физика может работать некорректно.")
		
		show_imbalance_visualization()
		


func _get_exported_drone_info() -> Dictionary:
	if has_meta("drone_info"):
		var info_variant: Variant = get_meta("drone_info")
		if typeof(info_variant) == TYPE_DICTIONARY:
			return info_variant as Dictionary
	return {}


func _repair_missing_propellers_from_metadata() -> void:
	var drone_info: Dictionary = _get_exported_drone_info()
	if drone_info.is_empty():
		return

	var propeller_entries_variant: Variant = drone_info.get("propellers", [])
	if typeof(propeller_entries_variant) != TYPE_ARRAY:
		return

	var propeller_entries: Array = propeller_entries_variant as Array
	if propeller_entries.is_empty():
		return

	var motors_by_slot: Dictionary = {}
	for motor_variant in _find_motors_by_tree_scan():
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		if motor.has_meta("motor_slot"):
			motors_by_slot[int(motor.get_meta("motor_slot"))] = motor

	if motors_by_slot.is_empty():
		return

	var existing_by_slot: Dictionary = {}
	for propeller_variant in propellers:
		var existing_propeller: Node3D = propeller_variant as Node3D
		if existing_propeller == null or not is_instance_valid(existing_propeller):
			continue
		if existing_propeller.has_meta("motor_slot"):
			existing_by_slot[int(existing_propeller.get_meta("motor_slot"))] = existing_propeller

	var repaired_any: bool = false
	for entry_variant in propeller_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var slot: int = int(entry.get("slot", -1))
		if slot < 0 or existing_by_slot.has(slot):
			continue

		var motor: Node3D = motors_by_slot.get(slot) as Node3D
		if motor == null or not is_instance_valid(motor):
			continue

		var propeller_type: String = str(entry.get("type", str(drone_info.get("propeller_type", "Пропеллер1"))))
		var repaired_propeller: Node3D = _create_repaired_propeller(propeller_type, slot)
		if repaired_propeller == null:
			continue

		motor.add_child(repaired_propeller)
		repaired_propeller.position = Vector3(0.0, 0.3, 0.0)
		repaired_propeller.rotation = Vector3.ZERO
		repaired_propeller.set_meta("is_drone_propeller", true)
		repaired_propeller.set_meta("motor_slot", slot)
		repaired_propeller.set_meta("attached_motor_slot", slot)
		if not repaired_propeller.is_in_group("drone_propellers"):
			repaired_propeller.add_to_group("drone_propellers")

		propellers.append(repaired_propeller)
		existing_by_slot[slot] = repaired_propeller
		repaired_any = true
		print("🔧 Восстановлен пропеллер из metadata: slot=", slot, " type=", propeller_type)

	if repaired_any:
		await get_tree().process_frame


func _create_repaired_propeller(propeller_type: String, slot: int) -> Node3D:
	var propeller_node := Node3D.new()
	propeller_node.name = "Propeller_%d" % slot

	var component_script: Script = load(COMPONENT_SCRIPT_PATH)
	if component_script != null:
		propeller_node.set_script(component_script)

	var variant: int = 1
	if propeller_type.ends_with("2"):
		variant = 2
	elif propeller_type.ends_with("3"):
		variant = 3

	propeller_node.set("component_type", "propeller")
	propeller_node.set("component_variant", variant)
	propeller_node.set("component_name", propeller_type)
	return propeller_node


func get_has_reached_target() -> bool:
	return has_reached_target

func get_is_crashed() -> bool:
	return is_crashed

func get_last_run_crashed() -> bool:
	return last_run_crashed

func get_last_run_cancelled() -> bool:
	return last_run_cancelled

func set_target_position(pos: Vector3):
	target_position = pos
	print("🎯 Установлена цель: ", target_position)


func _clear_local_crash_message() -> void:
	var local_canvas: CanvasLayer = get_node_or_null("CrashMessageCanvas") as CanvasLayer
	if local_canvas != null:
		local_canvas.queue_free()

	var parent_node: Node = get_parent()
	if parent_node != null:
		var scene_canvas: CanvasLayer = parent_node.get_node_or_null("CrashCanvas") as CanvasLayer
		if scene_canvas != null:
			scene_canvas.queue_free()

func _stop_runtime_tweens() -> void:
	if current_tween != null and is_instance_valid(current_tween):
		current_tween.kill()
	current_tween = null

	if crash_rotation_tween != null and is_instance_valid(crash_rotation_tween):
		crash_rotation_tween.kill()
	crash_rotation_tween = null

	if crash_fall_tween != null and is_instance_valid(crash_fall_tween):
		crash_fall_tween.kill()
	crash_fall_tween = null

func _prepare_for_new_attempt() -> void:
	_clear_local_crash_message()
	_stop_runtime_tweens()
	stop_propellers()
	is_crashed = false
	last_run_crashed = false
	last_run_cancelled = false
	has_reached_target = false
	crash_position = Vector3.ZERO
	rotation_degrees = Vector3.ZERO
	global_position = _clamp_above_floor(global_position)
	_reset_physics_motion_state()

func _reset_physics_motion_state() -> void:
	if drone_physics != null and drone_physics.has_method("reset_motion_state"):
		drone_physics.reset_motion_state(global_position)

func _update_visual_tilt(direction: int, delta: float) -> void:
	if drone_physics == null or not drone_physics.has_method("get_visual_tilt_degrees"):
		return

	var desired_tilt: Vector3 = drone_physics.get_visual_tilt_degrees(direction)
	var tilt_lerp: float = clampf(delta * 9.0, 0.0, 1.0)
	rotation_degrees.x = lerpf(rotation_degrees.x, desired_tilt.x, tilt_lerp)
	rotation_degrees.z = lerpf(rotation_degrees.z, desired_tilt.z, tilt_lerp)

func set_floor_height(value: float):
	floor_height = value
	start_position = _clamp_above_floor(start_position)
	if is_inside_tree():
		global_position = _clamp_above_floor(global_position)

func set_boundaries(min_value: Vector3, max_value: Vector3):
	movement_boundary_min = min_value
	movement_boundary_max = max_value
	has_movement_boundaries = true
	start_position = _clamp_above_floor(start_position)
	if is_inside_tree():
		global_position = _clamp_above_floor(global_position)

func _clamp_above_floor(position: Vector3) -> Vector3:
	var clamped_position: Vector3 = position
	if has_movement_boundaries:
		clamped_position.x = clampf(clamped_position.x, movement_boundary_min.x, movement_boundary_max.x)
		clamped_position.y = clampf(clamped_position.y, movement_boundary_min.y, movement_boundary_max.y)
		clamped_position.z = clampf(clamped_position.z, movement_boundary_min.z, movement_boundary_max.z)
	clamped_position.y = maxf(clamped_position.y, _get_safe_floor_center_y())
	if has_movement_boundaries:
		clamped_position.y = minf(clamped_position.y, movement_boundary_max.y)
	return clamped_position

func _get_safe_floor_center_y() -> float:
	var collision_shape: CollisionShape3D = _get_collision_shape_node()
	if collision_shape == null or collision_shape.shape == null:
		return floor_height

	if collision_shape.shape is BoxShape3D:
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		var bottom_local_y: float = collision_shape.position.y - box_shape.size.y * 0.5
		var scale_y: float = global_transform.basis.get_scale().y
		return floor_height - bottom_local_y * scale_y

	return floor_height

func _get_collision_shape_node() -> CollisionShape3D:
	return find_child("CollisionShape3D", true, false) as CollisionShape3D

func _fit_collision_shape_to_grid() -> void:
	var collision_shape: CollisionShape3D = _get_collision_shape_node()
	if collision_shape == null or collision_shape.shape == null:
		return

	if collision_shape.shape is BoxShape3D:
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		var basis_scale: Vector3 = global_transform.basis.get_scale().abs()
		var scale_x: float = maxf(basis_scale.x, 0.001)
		var scale_z: float = maxf(basis_scale.z, 0.001)
		var max_local_x: float = MAX_WORLD_COLLISION_FOOTPRINT / scale_x
		var max_local_z: float = MAX_WORLD_COLLISION_FOOTPRINT / scale_z
		var new_size: Vector3 = box_shape.size
		var resized: bool = false

		if new_size.x > max_local_x:
			new_size.x = max_local_x
			resized = true
		if new_size.z > max_local_z:
			new_size.z = max_local_z
			resized = true

		if resized:
			box_shape.size = new_size
			print("📦 Ограничиваем коллизию дрона до размера клетки: ", box_shape.size)

func _find_hazard_at_position(test_position: Vector3) -> Node3D:
	if not is_inside_tree():
		return null

	var collision_shape: CollisionShape3D = _get_collision_shape_node()
	if collision_shape == null or collision_shape.shape == null:
		return null

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(global_transform.basis, test_position + global_transform.basis * collision_shape.position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var direct_space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var intersections: Array[Dictionary] = direct_space_state.intersect_shape(query, COLLISION_QUERY_LIMIT)
	for intersection_variant in intersections:
		if typeof(intersection_variant) != TYPE_DICTIONARY:
			continue
		var intersection: Dictionary = intersection_variant
		var collider_variant: Variant = intersection.get("collider", null)
		if collider_variant is Node:
			var collider_node: Node = collider_variant
			if collider_node == self:
				continue
			if collider_node.is_in_group("crash_hazard"):
				return collider_node as Node3D
	return null

func _crash_from_hazard(hazard_position: Vector3, hazard_name: String):
	if is_crashed:
		return
	is_crashed = true
	last_run_crashed = true
	crash_position = _clamp_above_floor(hazard_position)
	print("💥 Столкновение с препятствием: ", hazard_name)
	emit_crash_effect()

func _find_motors_by_tree_scan() -> Array:
	# Фоллбек-поиск моторов. Работает даже если у мотора нет get_component_type(),
	# но на нём проставлена meta "motor_slot" (create_dron.gd делает это при экспорте).
	var motors: Array = []
	for n in _walk_drone_tree():
		if not (n is Node3D):
			continue
		var parent = n.get_parent()
		var parent_has_slot = (parent != null and parent.has_meta("motor_slot"))
		if n.has_meta("motor_slot") and not parent_has_slot:
			# Важно: пропеллеры тоже имеют meta motor_slot, но они почти всегда внутри мотора,
			# поэтому по этому правилу сюда не попадают.
			motors.append(n)

	# Дедупликация по instance_id
	var uniq: Dictionary = {}
	var result: Array = []
	for m in motors:
		var id := (m as Node).get_instance_id()
		if not uniq.has(id):
			uniq[id] = true
			result.append(m)
	return result


func init_drone_physics():
	"""Инициализация системы физики дрона"""
	drone_physics = DronePhysics.new()
	add_child(drone_physics)

	# Собираем компоненты дрона
	var frame_node = find_component_by_type("frame")
	var board_node = find_component_by_type("board")
	var motor_nodes = find_all_components_by_type("motor")
	if motor_nodes.is_empty():
		motor_nodes = _find_motors_by_tree_scan()
	if propellers.size() == 0 and not motor_nodes.is_empty():
		_repair_missing_propellers_from_metadata()

	# ==== DEBUG: имена/пути моторов ====
	print("🧩 Motors найдено: ", motor_nodes.size())
	for m in motor_nodes:
		if m and is_instance_valid(m):
			var meta_slot_m = (m.get_meta("motor_slot") if m.has_meta("motor_slot") else "NONE")
			print("   motor node name=", m.name, " class=", m.get_class(), " path=", m.get_path(), " meta_slot=", meta_slot_m)

	# НАХОДИМ ПРОПЕЛЛЕРЫ ЧЕРЕЗ НАШУ ФУНКЦИЮ (если где-то выше она вызывается — ок; иначе можно раскомментить)
	if propellers.size() == 0:
		propellers = find_propellers_guaranteed()
	if propellers.size() == 0 and not motor_nodes.is_empty():
		_repair_missing_propellers_from_metadata()
		propellers = find_propellers_guaranteed()

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
	"""Находит компонент по типу в дереве дрона (поиск рекурсивный)"""
	for n in _walk_drone_tree():
		if n == self:
			continue
		if n.has_method("get_component_type") and n.get_component_type() == type:
			return n
	return null


func find_all_components_by_type(type: String) -> Array:
	"""Находит все компоненты по типу в дереве дрона (поиск рекурсивный)"""
	var result: Array = []
	for n in _walk_drone_tree():
		if n == self:
			continue
		if n.has_method("get_component_type") and n.get_component_type() == type:
			result.append(n)
	return result

func _walk_drone_tree() -> Array:
	var result: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		result.append(n)
		for c in n.get_children():
			stack.append(c)
	return result



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
func _get_propeller_dedupe_key(propeller: Node3D) -> String:
	if propeller == null:
		return "null"

	if propeller.has_meta("motor_slot"):
		return "slot:%d" % int(propeller.get_meta("motor_slot"))

	var inferred_slot: int = _infer_slot_from_propeller_name(propeller.name)
	if inferred_slot >= 0:
		return "slot:%d" % inferred_slot

	var pos: Vector3 = propeller.global_position
	return "pos:%.3f:%.3f:%.3f" % [pos.x, pos.y, pos.z]

func _normalize_propeller_root(candidate: Node) -> Node3D:
	var current: Node = candidate
	while current != null and current != self:
		if current is Node3D and not (current is MeshInstance3D):
			var lower_name := str(current.name).to_lower()
			if current.has_meta("is_drone_propeller") or current.is_in_group("drone_propellers") or lower_name.find("propeller") != -1:
				return current as Node3D
		current = current.get_parent()
	return null

func _register_propeller_candidate(candidate: Node, seen_propellers: Dictionary, found: Array, origin: String) -> void:
	var propeller_root: Node3D = _normalize_propeller_root(candidate)
	if propeller_root == null or not is_instance_valid(propeller_root):
		return

	var dedupe_key: String = _get_propeller_dedupe_key(propeller_root)
	if seen_propellers.has(dedupe_key):
		return

	if not propeller_root.has_meta("is_drone_propeller"):
		propeller_root.set_meta("is_drone_propeller", true)
	if not propeller_root.is_in_group("drone_propellers"):
		propeller_root.add_to_group("drone_propellers")

	var slot: int = -1
	if propeller_root.has_meta("motor_slot"):
		slot = int(propeller_root.get_meta("motor_slot"))
	elif candidate.has_meta("motor_slot"):
		slot = int(candidate.get_meta("motor_slot"))
	else:
		slot = _infer_slot_from_propeller_name(propeller_root.name)
	if slot >= 0 and not propeller_root.has_meta("motor_slot"):
		propeller_root.set_meta("motor_slot", slot)

	seen_propellers[dedupe_key] = true
	found.append(propeller_root)
	print("вњ… РќР°Р№РґРµРЅ ", origin, ": ", propeller_root.name, " РІ РїРѕР·РёС†РёРё ", propeller_root.global_position)

func find_propellers_guaranteed() -> Array:
	var found: Array = []
	var seen_propellers: Dictionary = {}
	print("🔍 Начинаем поиск пропеллеров...")

	# 1) Поиск по группе (быстрый)
	var group_propellers := get_tree().get_nodes_in_group("drone_propellers")
	for node in group_propellers:
		if node == null or not is_instance_valid(node):
			continue
		if not is_ancestor_of(node):
			continue
		_register_propeller_candidate(node, seen_propellers, found, "group")
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

		var node_key: String = _get_propeller_dedupe_key(node as Node3D)
		if not seen_propellers.has(node_key):
			seen_propellers[node_key] = true
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

		if n != self and not n.name.begins_with("@"):
			var node_name := str(n.name).to_lower()
			var looks_like_propeller: bool = node_name.find("propeller") != -1
			var marked_as_propeller: bool = n.has_meta("is_drone_propeller") and bool(n.get_meta("is_drone_propeller"))
			if looks_like_propeller or marked_as_propeller or n.is_in_group("drone_propellers"):
				_register_propeller_candidate(n, seen_propellers, found, "tree")
				continue

		if n.name.begins_with("@"):
			continue
		if not (n is Node3D):
			continue
		if n is MeshInstance3D:
			continue

		var nl := str(n.name).to_lower()
		if not nl.begins_with("propeller"):
			continue

		var dedupe_key: String = _get_propeller_dedupe_key(n as Node3D)
		if seen_propellers.has(dedupe_key):
			continue

		# ✅ Самофикс: помечаем, чтобы дальше всё стабильно работало
		if not n.has_meta("is_drone_propeller"):
			n.set_meta("is_drone_propeller", true)
		if not n.is_in_group("drone_propellers"):
			n.add_to_group("drone_propellers")

		var slot := _infer_slot_from_propeller_name(n.name)
		if slot >= 0 and not n.has_meta("motor_slot"):
			n.set_meta("motor_slot", slot)

		seen_propellers[dedupe_key] = true
		found.append(n)
		print("✅ Найден в дереве: ", n.name, " позиция ", (n as Node3D).global_position)

	# КЛЮЧЕВОЕ: записываем в member propellers
	if found.is_empty():
		for motor in _find_motors_by_tree_scan():
			if motor == null or not is_instance_valid(motor):
				continue
			for child in motor.get_children():
				_register_propeller_candidate(child, seen_propellers, found, "motor_child")

	found.sort_custom(func(a, b):
		var slot_a: int = int(a.get_meta("motor_slot")) if a.has_meta("motor_slot") else _infer_slot_from_propeller_name(a.name)
		var slot_b: int = int(b.get_meta("motor_slot")) if b.has_meta("motor_slot") else _infer_slot_from_propeller_name(b.name)
		if slot_a == slot_b:
			return str(a.name) < str(b.name)
		return slot_a < slot_b
	)

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
	# Propeller_0..7 (и выше, если появятся новые платформы)
	if s.begins_with("propeller_"):
		var parts := s.split("_")
		if parts.size() >= 2 and parts[parts.size() - 1].is_valid_int():
			var idx := int(parts[parts.size() - 1])
			if idx >= 0:
				return idx
	# Propeller0..7
	if s.length() > 0:
		var digit_suffix := ""
		for i in range(s.length() - 1, -1, -1):
			var ch := s.substr(i, 1)
			if ch.is_valid_int():
				digit_suffix = ch + digit_suffix
			else:
				break
		if not digit_suffix.is_empty() and s.find("propeller") != -1:
			var idx2 := int(digit_suffix)
			if idx2 >= 0:
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
	_prepare_for_new_attempt()
	
	print("========================================")
	print("🚀 ЗАПУСК ПРОГРАММЫ")
	print("   Команд: ", sequence.size())
	print("   Пропеллеров: ", propellers.size())
	print("   Цель: ", target_position)
	
	is_executing = true
	
	# ГАРАНТИРОВАННЫЙ ЗАПУСК ПРОПЕЛЛЕРОВ
	start_propellers()
	start_position = _clamp_above_floor(start_position)
	
	# Ждем раскрутки
	await get_tree().create_timer(0.3).timeout
	print("🌀 Пропеллеры раскручены")
	
	# Выполняем команды
	var success = await execute_actions_grid(sequence)
	
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
		
		var action: int = int(sequence[i])
		var command_name = get_direction_name(action)
		print("   ", i + 1, "/", sequence.size(), ": ", command_name)
		
		var move_success = await perform_movement_with_physics(action, 1)
		if not move_success:
			print("❌ Ошибка движения или падение")
			return false
	
	print("✅ Все команды выполнены успешно")
	return true

func perform_movement_with_physics(direction: int, steps: int = 1) -> bool:
	"""Выполняет движение с учетом физики дрона"""
	if is_crashed:
		print("❌ Дрон разбился! Невозможно двигаться")
		return false
	
	# Проверяем, что дрон все еще находится в дереве сцены
	if not is_inside_tree():
		print("❌ Дрон был удален из дерева сцены")
		return false
	
	var target_pos: Vector3 = global_position
	
	# Рассчитываем базовое направление
	match direction:
		0: target_pos.z -= GRID_SIZE  # Вперед
		1: target_pos.z += GRID_SIZE  # Назад
		2: target_pos.x -= GRID_SIZE  # Влево
		3: target_pos.x += GRID_SIZE  # Вправо
		4: target_pos.y += GRID_SIZE  # Вверх
		5: target_pos.y = max(target_pos.y - GRID_SIZE, 0)  # Вниз
	
	# Применяем физику к движению
	if steps > 1:
		var extra_distance: float = GRID_SIZE * float(steps - 1)
		match direction:
			0:
				target_pos.z -= extra_distance
			1:
				target_pos.z += extra_distance
			2:
				target_pos.x -= extra_distance
			3:
				target_pos.x += extra_distance
			4:
				target_pos.y += extra_distance
			5:
				target_pos.y = max(target_pos.y - extra_distance, 0.0)
	target_pos = _clamp_above_floor(target_pos)
	if drone_physics:
		# Проверяем, может ли дрон лететь
		if not drone_physics.can_take_off():
			print("⚠️ Дрон не может взлететь! Проверьте компоненты")
			is_crashed = true
			last_run_crashed = true
			crash_position = global_position
			emit_crash_effect()
			return false
		
		# Рассчитываем скорость (расстояние / время)
		var start_pos = global_position
		var move_duration: float = _get_dynamic_step_duration(direction, steps)
		var total_distance: float = start_pos.distance_to(target_pos)
		var move_speed: float = total_distance / maxf(move_duration, 0.001)
		
		# Симулируем движение с физикой
		var time_elapsed = 0.0
		var snap_to_grid: bool = false
		if drone_physics and drone_physics.has_method("is_grid_stable"):
			snap_to_grid = drone_physics.is_grid_stable()

		var movement_target_pos: Vector3 = target_pos
		if not snap_to_grid and drone_physics and drone_physics.has_method("predict_step_endpoint"):
			movement_target_pos = drone_physics.predict_step_endpoint(
				direction,
				start_pos,
				target_pos,
				move_duration,
				move_speed
			)
			movement_target_pos = _clamp_above_floor(movement_target_pos)

		var max_duration: float = move_duration + MOVE_SETTLE_TIME
		
		while time_elapsed < max_duration:
			# Проверяем, что дрон все еще активен
			if not is_inside_tree() or is_crashed:
				print("❌ Дрон был удален или разбился во время движения")
				return false
			
			var physics_delta: float = get_process_delta_time()
			var t = minf((time_elapsed + physics_delta) / move_duration, 1.0)
			var base_pos = start_pos.lerp(movement_target_pos, t)
			var hazard: Node3D = null
			
			# Применяем улучшенную физику с учетом направления И СКОРОСТИ
			var physics_pos = drone_physics.apply_movement_physics(
				direction,
				global_position,
				base_pos,
				physics_delta,
				move_speed  # Передаем рассчитанную скорость
			)
			
			# Проверяем, не упал ли дрон
			physics_pos = _clamp_above_floor(physics_pos)
			hazard = _find_hazard_at_position(physics_pos)
			if hazard != null:
				_crash_from_hazard(physics_pos, hazard.name)
				return false
			if drone_physics.check_crash_condition(physics_pos, _get_safe_floor_center_y(), physics_delta):
				print("💥 Дрон падает!")
				is_crashed = true
				last_run_crashed = true
				crash_position = physics_pos
				emit_crash_effect()
				return false
			
			# Безопасно обновляем позицию
			if is_inside_tree():
				global_position = physics_pos
				# ВИЗУАЛЬНЫЙ КРЕН (плавно, без рандома)
				_update_visual_tilt(direction, physics_delta)
				drone_moved.emit()
			else:
				return false
			
			var next_time_elapsed: float = time_elapsed + physics_delta
			if next_time_elapsed >= move_duration:
				var remaining_distance: float = global_position.distance_to(movement_target_pos)
				var motion_speed: float = drone_physics.velocity.length() if drone_physics != null else 0.0
				if remaining_distance <= MOVE_SETTLE_DISTANCE and motion_speed <= MOVE_SETTLE_SPEED:
					time_elapsed = next_time_elapsed
					break

			time_elapsed = next_time_elapsed
			if time_elapsed < max_duration:
				await get_tree().process_frame
		
		# Финальная позиция (только если дрон все еще в дереве)
		if is_inside_tree():
			var final_delta: float = get_process_delta_time()
			var final_target_pos: Vector3 = target_pos if snap_to_grid else movement_target_pos
			var final_pos = drone_physics.apply_movement_physics(
				direction,
				global_position,
				final_target_pos,
				final_delta,
				move_speed  # Передаем рассчитанную скорость
			)
			
			# Проверяем финальную позицию на падение
			final_pos = _clamp_above_floor(final_pos)
			var final_hazard: Node3D = _find_hazard_at_position(final_pos)
			if final_hazard != null:
				_crash_from_hazard(final_pos, final_hazard.name)
				return false
			if drone_physics.check_crash_condition(final_pos, _get_safe_floor_center_y(), final_delta):
				print("💥 Дрон падает в конце движения!")
				is_crashed = true
				last_run_crashed = true
				crash_position = final_pos
				emit_crash_effect()
				return false
			
			# Если дрон полностью собран и стабилен — доводим ровно до центра клетки
			if snap_to_grid:
				var target_hazard: Node3D = _find_hazard_at_position(target_pos)
				if target_hazard != null:
					_crash_from_hazard(target_pos, target_hazard.name)
					return false

				global_position = _clamp_above_floor(target_pos)
				_reset_physics_motion_state()
				rotation_degrees.x = 0.0
				rotation_degrees.z = 0.0
			else:
				global_position = _clamp_above_floor(final_pos)
				# Сохраняем инерцию и крен между клетками, чтобы движение не выглядело рваным
				_update_visual_tilt(direction, final_delta)
	else:
		# Без физики - обычное движение (с проверкой)
		if is_inside_tree():
			var direct_hazard: Node3D = _find_hazard_at_position(target_pos)
			if direct_hazard != null:
				_crash_from_hazard(target_pos, direct_hazard.name)
				return false
			target_pos = _clamp_above_floor(target_pos)
			var tween = create_tween()
			tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
			await tween.finished
		else:
			return false
	
	# Проверяем достижение цели (только если дрон активен)
	if is_inside_tree():
		check_target_proximity_precise()
		drone_moved.emit()
	
	return true

func execute_actions_grid(sequence: Array) -> bool:
	if sequence.is_empty():
		print("⚠️ Пустая программа")
		return false

	print("🎯 Выполнение команд по клеткам")
	for i in range(sequence.size()):
		if is_crashed:
			print("❌ Дрон разбился, прерываем программу")
			return false

		var action: int = int(sequence[i])
		print("   ", i + 1, "/", sequence.size(), ": ", get_direction_name(action))

		var move_success: bool = false
		if drone_physics != null:
			move_success = await perform_grid_step(action)
		else:
			move_success = await perform_grid_step_precise(action)
		if not move_success:
			print("❌ Ошибка движения или падение")
			return false

	print("✅ Все команды выполнены")
	return true

func perform_grid_step_precise(direction: int) -> bool:
	if is_crashed:
		return false

	if not is_inside_tree():
		return false

	var target_pos: Vector3 = global_position
	match direction:
		0:
			target_pos.z -= GRID_SIZE
		1:
			target_pos.z += GRID_SIZE
		2:
			target_pos.x -= GRID_SIZE
		3:
			target_pos.x += GRID_SIZE
		4:
			target_pos.y += GRID_SIZE
		5:
			target_pos.y = max(target_pos.y - GRID_SIZE, 0.0)

	target_pos = _clamp_above_floor(target_pos)
	var start_pos: Vector3 = global_position
	var is_vertical_move: bool = direction == 4 or direction == 5
	var move_duration: float = _get_dynamic_step_duration(direction, 1)
	var time_elapsed: float = 0.0

	if drone_physics != null:
		if not drone_physics.can_take_off():
			is_crashed = true
			last_run_crashed = true
			crash_position = global_position
			emit_crash_effect()
			return false

		var floor_center_y: float = _get_safe_floor_center_y()
		while time_elapsed < move_duration:
			if not is_inside_tree() or is_crashed:
				return false

			var physics_delta: float = get_process_delta_time()
			time_elapsed = minf(time_elapsed + physics_delta, move_duration)
			var progress: float = clampf(time_elapsed / maxf(move_duration, 0.001), 0.0, 1.0)
			var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
			var step_position: Vector3 = start_pos.lerp(target_pos, eased_progress)
			if not is_vertical_move:
				step_position.y += sin(progress * PI) * minf(GRID_SIZE * 0.11, 3.2)
			step_position = _clamp_above_floor(step_position)

			var hazard: Node3D = _find_hazard_at_position(step_position)
			if hazard != null:
				_crash_from_hazard(step_position, hazard.name)
				return false

			if drone_physics.check_crash_condition(step_position, floor_center_y, physics_delta):
				is_crashed = true
				last_run_crashed = true
				crash_position = step_position
				emit_crash_effect()
				return false

			global_position = step_position
			_update_visual_tilt(direction, physics_delta)
			drone_moved.emit()
			await get_tree().process_frame

		var final_position: Vector3 = _clamp_above_floor(target_pos)
		var final_hazard: Node3D = _find_hazard_at_position(final_position)
		if final_hazard != null:
			_crash_from_hazard(final_position, final_hazard.name)
			return false

		var final_delta: float = get_process_delta_time()
		if drone_physics.check_crash_condition(final_position, floor_center_y, final_delta):
			is_crashed = true
			last_run_crashed = true
			crash_position = final_position
			emit_crash_effect()
			return false

		global_position = final_position
		if drone_physics.has_method("settle_after_cell_move"):
			drone_physics.call("settle_after_cell_move", global_position)
		_update_visual_tilt(direction, final_delta)
	else:
		var direct_hazard: Node3D = _find_hazard_at_position(target_pos)
		if direct_hazard != null:
			_crash_from_hazard(target_pos, direct_hazard.name)
			return false

		var tween: Tween = create_tween()
		tween.tween_property(self, "global_position", target_pos, move_duration)
		await tween.finished

	if is_inside_tree():
		check_target_proximity_precise()
		drone_moved.emit()

	return true

func perform_grid_step(direction: int) -> bool:
	if is_crashed:
		print("❌ Дрон разбился, движение невозможно")
		return false

	if not is_inside_tree():
		print("❌ Дрон был удален из дерева сцены")
		return false

	var target_pos: Vector3 = global_position
	match direction:
		0:
			target_pos.z -= GRID_SIZE
		1:
			target_pos.z += GRID_SIZE
		2:
			target_pos.x -= GRID_SIZE
		3:
			target_pos.x += GRID_SIZE
		4:
			target_pos.y += GRID_SIZE
		5:
			target_pos.y = max(target_pos.y - GRID_SIZE, 0.0)

	target_pos = _clamp_above_floor(target_pos)

	if drone_physics:
		if not drone_physics.can_take_off():
			print("⚠️ Дрон не может взлететь, проверьте компоненты")
			is_crashed = true
			last_run_crashed = true
			crash_position = global_position
			emit_crash_effect()
			return false

		var start_pos: Vector3 = global_position
		var move_duration: float = _get_dynamic_step_duration(direction, 1)
		var move_speed: float = start_pos.distance_to(target_pos) / maxf(move_duration, 0.001)
		var time_elapsed: float = 0.0
		var max_duration: float = move_duration + MOVE_SETTLE_TIME
		var reached_target: bool = false

		while time_elapsed < max_duration:
			if not is_inside_tree() or is_crashed:
				print("❌ Дрон был удален или разбился во время движения")
				return false

			var physics_delta: float = get_process_delta_time()
			var progress: float = clampf(time_elapsed / maxf(move_duration, 0.001), 0.0, 1.0)
			var guide_pos: Vector3 = start_pos.lerp(target_pos, progress)
			guide_pos = guide_pos.lerp(target_pos, 0.55)

			var physics_pos: Vector3 = drone_physics.apply_movement_physics(
				direction,
				global_position,
				guide_pos,
				physics_delta,
				move_speed
			)

			physics_pos = _clamp_above_floor(physics_pos)
			var hazard: Node3D = _find_hazard_at_position(physics_pos)
			if hazard != null:
				_crash_from_hazard(physics_pos, hazard.name)
				return false
			if drone_physics.check_crash_condition(physics_pos, _get_safe_floor_center_y(), physics_delta):
				print("💥 Дрон теряет управление")
				is_crashed = true
				last_run_crashed = true
				crash_position = physics_pos
				emit_crash_effect()
				return false

			global_position = physics_pos
			_update_visual_tilt(direction, physics_delta)
			drone_moved.emit()

			if global_position.distance_to(target_pos) <= GRID_SIZE * 0.10:
				reached_target = true
				break

			time_elapsed += physics_delta
			await get_tree().process_frame

		var final_delta: float = get_process_delta_time()
		var final_pos: Vector3 = drone_physics.apply_movement_physics(
			direction,
			global_position,
			target_pos,
			final_delta,
			move_speed
		)

		final_pos = _clamp_above_floor(final_pos)
		var final_hazard: Node3D = _find_hazard_at_position(final_pos)
		if final_hazard != null:
			_crash_from_hazard(final_pos, final_hazard.name)
			return false
		if drone_physics.check_crash_condition(final_pos, _get_safe_floor_center_y(), final_delta):
			print("💥 Дрон теряет управление в конце шага")
			is_crashed = true
			last_run_crashed = true
			crash_position = final_pos
			emit_crash_effect()
			return false

		var snapped_pos: Vector3 = _clamp_above_floor(target_pos if reached_target else final_pos)
		var should_snap_to_target: bool = false
		if drone_physics != null and drone_physics.has_method("is_grid_stable"):
			should_snap_to_target = drone_physics.is_grid_stable()
		if should_snap_to_target and snapped_pos.distance_to(target_pos) <= GRID_SIZE * 0.25:
			global_position = _clamp_above_floor(target_pos)
		else:
			global_position = snapped_pos

		if drone_physics.has_method("settle_after_cell_move"):
			drone_physics.call("settle_after_cell_move", global_position)
		_update_visual_tilt(direction, final_delta)
	else:
		var direct_hazard: Node3D = _find_hazard_at_position(target_pos)
		if direct_hazard != null:
			_crash_from_hazard(target_pos, direct_hazard.name)
			return false

		var tween: Tween = create_tween()
		tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
		await tween.finished

	if is_inside_tree():
		check_target_proximity_precise()
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
	
	var target_pos: Vector3 = global_position
	
	# Рассчитываем базовое направление
	match direction:
		0: target_pos.z -= GRID_SIZE  # Вперед
		1: target_pos.z += GRID_SIZE  # Назад
		2: target_pos.x -= GRID_SIZE  # Влево
		3: target_pos.x += GRID_SIZE  # Вправо
		4: target_pos.y += GRID_SIZE  # Вверх
		5: target_pos.y = max(target_pos.y - GRID_SIZE, 0)  # Вниз (но не ниже земли)
	
	# Создаем твин для плавного движения
	target_pos = _clamp_above_floor(target_pos)
	var direct_hazard: Node3D = _find_hazard_at_position(target_pos)
	if direct_hazard != null:
		_crash_from_hazard(target_pos, direct_hazard.name)
		return false
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, MOVE_SPEED)
	tween.tween_callback(check_target_proximity_precise)
	await tween.finished
	
	# Проверяем достижение цели
	check_target_proximity_precise()
	
	drone_moved.emit()
	return true

func check_target_proximity_precise() -> void:
	if target_position == Vector3.ZERO:
		return

	var distance: float = global_position.distance_to(target_position)
	var proximity_threshold: float = GRID_SIZE * 0.35
	var reached_now: bool = distance <= proximity_threshold
	if reached_now and not has_reached_target:
		print("Target reached at distance ", distance)
	has_reached_target = reached_now

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
	last_run_crashed = true
	
	# Визуальный эффект падения
	if crash_rotation_tween != null and is_instance_valid(crash_rotation_tween):
		crash_rotation_tween.kill()
	crash_rotation_tween = create_tween()
	crash_rotation_tween.tween_property(self, "rotation_degrees", Vector3(randf_range(-45, 45), randf_range(0, 360), randf_range(-45, 45)), 0.5)
	
	# Эффект "падения" на место
	if crash_position.y > 0 and is_inside_tree():
		if crash_fall_tween != null and is_instance_valid(crash_fall_tween):
			crash_fall_tween.kill()
		crash_fall_tween = create_tween()
		crash_fall_tween.tween_property(self, "global_position:y", maxf(crash_position.y - 2.0, _get_safe_floor_center_y()), 0.3)
		crash_fall_tween.tween_property(self, "global_position:y", crash_position.y, 0.2)


# ОСТАНОВКА
func stop_execution():
	print("🛑 ПРИНУДИТЕЛЬНАЯ ОСТАНОВКА")
	is_executing = false
	last_run_cancelled = true
	is_crashed = false
	last_run_crashed = false
	has_reached_target = false
	crash_position = Vector3.ZERO
	stop_propellers()
	_clear_local_crash_message()
	_stop_runtime_tweens()
	_reset_physics_motion_state()
	program_finished.emit(false)

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
	has_reached_target = false
	last_run_cancelled = false
	crash_position = Vector3.ZERO
	_clear_local_crash_message()
	_stop_runtime_tweens()
	stop_propellers()
	
	# Возвращаем на старт
	start_position = _clamp_above_floor(start_position)
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", start_position, MOVE_SPEED * 1.5)
	current_tween.parallel().tween_property(self, "rotation_degrees", Vector3.ZERO, 0.5)
	await current_tween.finished
	current_tween = null
	global_position = start_position
	rotation_degrees = Vector3.ZERO
	_reset_physics_motion_state()
	
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
	has_reached_target = false
	last_run_crashed = false
	last_run_cancelled = false
	crash_position = Vector3.ZERO
	
	# Останавливаем пропеллеры
	stop_propellers()
	_clear_local_crash_message()
	_stop_runtime_tweens()
	
	# Возвращаемся на стартовую позицию
	start_position = _clamp_above_floor(start_position)
	current_tween = create_tween()
	current_tween.tween_property(self, "global_position", start_position, 1.0)
	current_tween.parallel().tween_property(self, "rotation_degrees", Vector3.ZERO, 0.5)
	await current_tween.finished
	current_tween = null
	global_position = start_position
	rotation_degrees = Vector3.ZERO
	_reset_physics_motion_state()
	
	
	print("✅ Дрон вернулся на старт и отцентрирован: ", global_position)

func set_start_position(new_start_position: Vector3):
	start_position = _clamp_above_floor(new_start_position)
	
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
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.has_method("show_crash_message"):
		parent_node.call_deferred("show_crash_message")
		return
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
	message_label.text = "💥 ДРОН РАЗБИЛСЯ!\n\nПричина: столкновение с препятствием или потеря устойчивости\nДрон будет возвращен на старт"
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
