extends Node3D

# ==================== КОНСТАНТЫ И ПЕРЕМЕННЫЕ ====================
const ROTATION_SPEED: float = 0.01
const ZOOM_SPEED: float = 0.1
const MIN_DISTANCE: float = 3.0
const MAX_DISTANCE: float = 20.0
const FRICTION: float = 0.92
const MIN_VERTICAL_ANGLE: float = 0.0
const MAX_VERTICAL_ANGLE: float = PI / 2.0 - 0.2
const PROP_SNAP_RADIUS := 3.0
const ASSEMBLY_AUTOSAVE_PATH := "user://assembly_autosave.json"


const BOUNDS_MIN: Vector3 = Vector3(-5, 0, -5)
const BOUNDS_MAX: Vector3 = Vector3(5, 3, 5)

var _components_center_local: Vector3 = Vector3.ZERO
var _components_center_valid: bool = false
# Камера
var camera_rotation: Vector2 = Vector2.ZERO
var camera_distance: float = 8.0
var is_rotating: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var rotation_velocity: Vector2 = Vector2.ZERO
var is_dragging_camera: bool = false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
const MAIN_MENU_SCENE_PATH := "res://app/main_menu/main_scene.tscn"
const CUSTOMIZATION_SCENE_PATH := "res://app/customization/DroneCustomizationScene.tscn"


# ==================== ПУТИ СЦЕН ====================
const CREATE_DRONE_SCENE_PATH := "res://app/assembly/create_dron.tscn"
const ARDUINO_SCENE_PATHS: Array[String] = [
	"res://app/arduino/DroneConnectionScene.tscn",
	"res://app/arduino/drone_connection_scene.tscn"
]

# ==================== ESC-МЕНЮ (ПАУЗА) ====================
var _pause_layer: CanvasLayer = null
var _pause_overlay: Control = null
var _pause_panel: Panel = null
var _pause_open: bool = false
var _pause_tween: Tween = null

# ==================== КНОПКА ПЕРЕХОДА В ARDUINO ====================
var _arduino_button: Button = null
var _customization_button: Button = null

# ==================== ЭКСПОРТ (ТИХИЙ РЕЖИМ) ====================
var _suppress_export_popup: bool = false

# UI (узлы берём из сцены, НЕ создаём дубликаты)
var open_close_button: Button = null
var list_panel: Panel = null
var component_list: ItemList = null

# Система сохранения
var save_slots: Array = [null, null, null]
var current_save_ui: Control = null
var _assembly_autosave_suspended: bool = false

# Служебное: данные для скрина превью слота (чтобы не получать "скрин меню в меню")
var _thumb_capture_state: Dictionary = {}

# Хранение компонентов
var drone_frame: Node3D = null
var drone_board: Node3D = null
var motors: Array[Node3D] = []
var propellers: Array[Node3D] = []

# Характеристики дрона
var drone_stats: Dictionary = {
	"total_mass": 0.0,
	"total_thrust": 0.0,
	"is_balanced": true,
	"missing_motors": 0,
	"missing_propellers": 0,
	"frame_present": false,
	"board_present": false
}

# Параметры компонентов
var component_stats: Dictionary = {
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

# Префабы компонентов
var frame_prefabs: Dictionary = {
	"Рама1": preload("res://app/assembly/components/frame1.tscn"),
	"Рама2": preload("res://app/assembly/components/frame2.tscn"),
	"Рама3": preload("res://app/assembly/components/frame3.tscn")
}
var board_prefabs: Dictionary = {
	"Плата1": preload("res://app/assembly/components/board1.tscn"),
	"Плата2": preload("res://app/assembly/components/board2.tscn"),
	"Плата3": preload("res://app/assembly/components/board3.tscn")
}
var motor_prefabs: Dictionary = {
	"Мотор1": preload("res://app/assembly/components/motor1.tscn"),
	"Мотор2": preload("res://app/assembly/components/motor2.tscn"),
	"Мотор3": preload("res://app/assembly/components/motor3.tscn")
}
var propeller_prefabs: Dictionary = {
	"Пропеллер1": preload("res://app/assembly/components/propeller1.tscn"),
	"Пропеллер2": preload("res://app/assembly/components/propeller2.tscn"),
	"Пропеллер3": preload("res://app/assembly/components/propeller3.tscn")
}

# Текущие выбранные типы компонентов
var current_frame_type: String = "Рама1"
var current_board_type: String = "Плата1"
var current_motor_type: String = "Мотор1"
var current_propeller_type: String = "Пропеллер1"

# Перетаскивание
var dragged_component: Node3D = null
var is_dragging_component: bool = false
var drag_offset: Vector3 = Vector3.ZERO
var original_component_position: Vector3 = Vector3.ZERO
var child_relative_positions: Dictionary = {}
var attachment_points: Array[Node3D] = []
var motor_propeller_map: Dictionary = {} # motor(Node3D) -> propeller(Node3D)

var green_material: StandardMaterial3D = StandardMaterial3D.new()
var red_material: StandardMaterial3D = StandardMaterial3D.new()

# Меню настроек (оставляем Variant, чтобы не было ошибок стат.типизации по методам open/is_open)
var settings_menu = null

# Кнопки выбора (создаются кодом, но строго 1 раз)
var frame_buttons: Array[Button] = []
var board_buttons: Array[Button] = []
var motor_buttons: Array[Button] = []
var propeller_buttons: Array[Button] = []

# ==================== ОСНОВНЫЕ ФУНКЦИИ ====================
func _ready() -> void:
	# Системы окружения
	load_settings_menu()
	add_room()
	setup_lighting()
	add_reflection_probe()

	# UI / ссылки из сцены (без дубликатов)
	init_ui_components()
	setup_hierarchy_panel()


	_remove_save_load_container_runtime()
	load_slots_info()
	# UI, который делается кодом (но с защитой от дублей)
	create_component_selectors_ui()
	# Мир
	create_grid()
	create_floor_line()

	# Камера / материалы / настройки
	camera_rotation = Vector2(0.52, -0.82)
	camera_distance = 9.8
	update_camera_position()
	add_to_group("drone_creator")
	create_attachment_materials()
	apply_global_settings()

	set_process_input(true)
	print("✅ create_dron.gd готов.")
	_ensure_pause_menu()
	_ensure_arduino_button()
	_ensure_customization_button()
	_apply_assembly_ui_theme()
	add_child(load("res://app/ui/beauty_visual.gd").new())
	call_deferred("_apply_current_customization_to_assembly")
	call_deferred("_restore_assembly_session")
func _process(delta: float) -> void:
	if _pause_open:
		return
	# Инерция камеры
	if (not is_dragging_camera) and (rotation_velocity.x != 0.0 or rotation_velocity.y != 0.0):
		camera_rotation.x += rotation_velocity.x
		camera_rotation.y += rotation_velocity.y
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		rotation_velocity *= FRICTION

		if abs(rotation_velocity.x) < 0.0001 and abs(rotation_velocity.y) < 0.0001:
			rotation_velocity = Vector2.ZERO

		update_camera_position()

# ==================== УПРАВЛЕНИЕ КАМЕРОЙ ====================
func update_camera_position() -> void:
	var target_position: Vector3 = Vector3.ZERO
	var components_3d: Node3D = $Components as Node3D
	if drone_frame != null and is_instance_valid(drone_frame):
		target_position = drone_frame.global_position + Vector3(0.0, 0.25, 0.0)
	elif components_3d != null:
		target_position = components_3d.to_global(get_components_center_local())
	var camera_position: Vector3 = Vector3(
		sin(camera_rotation.y) * cos(camera_rotation.x),
		sin(camera_rotation.x),
		cos(camera_rotation.y) * cos(camera_rotation.x)
	) * camera_distance

	camera.position = camera_position
	camera.look_at(target_position, Vector3.UP)

# ==================== ОБРАБОТКА ВВОДА ====================
func _input(event: InputEvent) -> void:
	# ==================== ESC -> ВЫЕЗЖАЮЩЕЕ МЕНЮ ====================
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Если открыты настройки — пусть SettingsScene сам обработает ESC
		if settings_menu != null and settings_menu.has_method("is_open") and bool(settings_menu.call("is_open")):
			return

		# Чтобы не "залипало" перетаскивание при открытии меню
		if (not _pause_open) and is_dragging_component:
			stop_component_dragging()

		_toggle_pause_menu(not _pause_open)
		get_viewport().set_input_as_handled()
		return

	# Если ESC-меню открыто — блокируем остальное управление
	if _pause_open:
		return

	# Если SettingsScene открыт — тоже блокируем остальное управление
	if settings_menu != null and settings_menu.has_method("is_open") and bool(settings_menu.call("is_open")):
		return

	# Вращение камеры ПКМ
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_rotating = true
			is_dragging_camera = true
			last_mouse_pos = event.position
			rotation_velocity = Vector2.ZERO
		else:
			is_rotating = false
			is_dragging_camera = false

	# Вращение камеры мышью
	if event is InputEventMouseMotion and is_rotating:
		var mouse_delta: Vector2 = event.position - last_mouse_pos
		rotation_velocity = Vector2(
			-mouse_delta.y * ROTATION_SPEED * 0.5,
			-mouse_delta.x * ROTATION_SPEED * 0.5
		)
		camera_rotation.x += -mouse_delta.y * ROTATION_SPEED
		camera_rotation.y += -mouse_delta.x * ROTATION_SPEED
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		last_mouse_pos = event.position
		update_camera_position()

	# Зум колесом
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = clamp(camera_distance - ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = clamp(camera_distance + ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()

	# Перетаскивание ЛКМ
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var comp: Node3D = get_component_under_mouse(event.position)
			if comp != null and is_component_draggable(comp):
				start_component_dragging(comp, event.position)
		else:
			if is_dragging_component:
				stop_component_dragging()

	# Движение при перетаскивании
	if event is InputEventMouseMotion and is_dragging_component and dragged_component != null:
		update_component_dragging(event.position)

# ==================== ПОИСК КОМПОНЕНТА ПОД МЫШЬЮ ====================
func get_component_under_mouse(mouse_position: Vector2) -> Node3D:
	var from: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_position)

	var all_components: Array = get_all_drone_components()
	var closest_component: Node3D = null
	var closest_distance: float = INF

	for c in all_components:
		var component: Node3D = c as Node3D
		if component == null or not is_instance_valid(component):
			continue

		var component_pos: Vector3 = component.global_position
		var to_comp: Vector3 = component_pos - from
		var projection: float = to_comp.dot(ray_dir)

		if projection > 0.0:
			var closest_point: Vector3 = from + ray_dir * projection
			var dist: float = closest_point.distance_to(component_pos)
			var component_radius: float = get_component_radius(component)

			if dist < component_radius and dist < closest_distance:
				closest_distance = dist
				closest_component = component

	return closest_component

func get_component_radius(component: Node3D) -> float:
	var component_type: String = get_component_type(component)
	match component_type:
		"frame":
			return 2.0
		"board":
			return 0.5
		"motor":
			return 0.3
		"propeller":
			return 0.4
		_:
			return 0.5

func get_all_drone_components() -> Array:
	var components: Array = []
	if drone_frame != null and is_instance_valid(drone_frame):
		components.append(drone_frame)
	if drone_board != null and is_instance_valid(drone_board):
		components.append(drone_board)

	for m in motors:
		var motor: Node3D = m as Node3D
		if motor != null and is_instance_valid(motor):
			components.append(motor)

	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop != null and is_instance_valid(prop):
			components.append(prop)

	return components

func is_component_draggable(component: Node3D) -> bool:
	if component == null or not is_instance_valid(component):
		return false
	return (component == drone_frame
		or component == drone_board
		or motors.has(component)
		or propellers.has(component))

# ==================== ПЕРЕТАСКИВАНИЕ ====================
func start_component_dragging(component: Node3D, mouse_position: Vector2) -> void:
	if component == null or not is_instance_valid(component):
		return

	is_rotating = false
	is_dragging_camera = false
	rotation_velocity = Vector2.ZERO
	dragged_component = component
	original_component_position = component.global_position
	is_dragging_component = true

	save_child_relative_positions(component)

	var component_type: String = get_component_type(component)
	show_attachment_points(component_type)

	var from: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_position)

	var drag_plane: Plane = Plane(Vector3.UP, component.global_position.y)
	var hit = drag_plane.intersects_ray(from, ray_dir)

	if hit is Vector3:
		var intersection: Vector3 = hit
		drag_offset = component.global_position - intersection
	else:
		drag_offset = Vector3.ZERO

func save_child_relative_positions(parent: Node3D) -> void:
	child_relative_positions.clear()

	var children: Array = get_direct_children(parent)
	for c in children:
		var child: Node3D = c as Node3D
		if child != null and is_instance_valid(child):
			var relative_pos: Vector3 = child.global_position - parent.global_position
			child_relative_positions[child] = relative_pos
			save_grandchildren_relative_positions(child, parent)

func save_grandchildren_relative_positions(child: Node3D, original_parent: Node3D) -> void:
	var grandchildren: Array = get_direct_children(child)
	for g in grandchildren:
		var grandchild: Node3D = g as Node3D
		if grandchild != null and is_instance_valid(grandchild):
			var relative_pos: Vector3 = grandchild.global_position - original_parent.global_position
			child_relative_positions[grandchild] = relative_pos

func get_direct_children(parent: Node3D) -> Array:
	var children: Array = []

	if parent == drone_frame:
		if drone_board != null and is_instance_valid(drone_board):
			children.append(drone_board)
		for m in motors:
			var motor: Node3D = m as Node3D
			if motor != null and is_instance_valid(motor):
				children.append(motor)

	elif motors.has(parent):
		if motor_propeller_map.has(parent):
			var mapped_propeller: Node3D = motor_propeller_map[parent] as Node3D
			if mapped_propeller != null and is_instance_valid(mapped_propeller) and mapped_propeller.get_parent() == parent:
				children.append(mapped_propeller)
				return children
		for child in parent.get_children():
			var prop: Node3D = child as Node3D
			if prop != null and is_instance_valid(prop) and is_propeller_attached_to_motor(prop, parent):
				children.append(prop)
				break

	return children

func is_propeller_attached_to_motor(propeller: Node3D, motor: Node3D) -> bool:
	if propeller == null or motor == null:
		return false
	if not is_instance_valid(propeller) or not is_instance_valid(motor):
		return false
	if propeller.get_parent() == motor:
		return true
	if motor_propeller_map.has(motor) and motor_propeller_map[motor] == propeller:
		return true
	if propeller.has_meta("motor_slot") and motor.has_meta("motor_slot"):
		return int(propeller.get_meta("motor_slot")) == int(motor.get_meta("motor_slot"))
	return false

func update_component_dragging(mouse_position: Vector2) -> void:
	if dragged_component == null or not is_instance_valid(dragged_component):
		stop_component_dragging()
		return

	var from: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_position)

	var drag_plane: Plane = Plane(Vector3.UP, original_component_position.y)
	var hit = drag_plane.intersects_ray(from, ray_dir)

	if hit is Vector3:
		var intersection: Vector3 = hit
		var new_position: Vector3 = intersection + drag_offset
		new_position.y = original_component_position.y
		new_position = clamp_position(new_position)

		var component_type: String = get_component_type(dragged_component)
		var previous_position: Vector3 = dragged_component.global_position

		match component_type:
			"board":
				var snapped_board: Vector3 = find_closest_board_attachment_point(new_position)
				dragged_component.global_position = snapped_board
			"motor":
				var snapped_motor: Vector3 = find_closest_motor_attachment_point(new_position)
				dragged_component.global_position = snapped_motor
			"propeller":
				var closest_motor: Node3D = find_closest_motor_for_propeller(new_position)
				if closest_motor != null:
					var target_pos: Vector3 = closest_motor.global_position + Vector3(0.0, 0.3, 0.0)
					dragged_component.global_position = target_pos
				else:
					dragged_component.global_position = new_position
			_:
				dragged_component.global_position = new_position

		var drag_delta: Vector3 = dragged_component.global_position - previous_position
		move_children_with_parent(drag_delta)

func move_children_with_parent(drag_delta: Vector3) -> void:
	for k in child_relative_positions.keys():
		var child: Node3D = k as Node3D
		if child == null or not is_instance_valid(child) or child == dragged_component:
			continue
		var parent_node: Node = child.get_parent()
		if parent_node is Node3D and (parent_node == dragged_component or child_relative_positions.has(parent_node)):
			continue
		if child != null and is_instance_valid(child):
			child.global_position += drag_delta

func stop_component_dragging() -> void:
	if dragged_component != null and is_instance_valid(dragged_component):
		var component_type: String = get_component_type(dragged_component)
		match component_type:
			"board":
				snap_board_to_frame(dragged_component)
			"motor":
				update_motor_propeller_connection(dragged_component)
			"propeller":
				snap_propeller_to_motor(dragged_component)

		_normalize_motor_propeller_links(true)
		hide_attachment_points()
		update_component_list()
		calculate_drone_stats()
		_apply_current_customization_to_assembly()
		_save_assembly_autosave()
		_tut_notify_after_drop(component_type)

	is_dragging_component = false
	dragged_component = null
	child_relative_positions.clear()

func _get_motor_slot_index(motor: Node3D) -> int:
	if motor == null or not is_instance_valid(motor):
		return -1
	if motor.has_meta("motor_slot"):
		return int(motor.get_meta("motor_slot"))
	var idx: int = motors.find(motor)
	return idx

func _resolve_component_slot(component: Node3D, fallback_slot: int = -1) -> int:
	if component == null or not is_instance_valid(component):
		return fallback_slot
	if component.has_meta("motor_slot"):
		return clampi(int(component.get_meta("motor_slot")), 0, 3)

	var parent_node: Node = component.get_parent()
	if parent_node is Node3D and (parent_node as Node3D).has_meta("motor_slot"):
		return clampi(int((parent_node as Node3D).get_meta("motor_slot")), 0, 3)

	var components_3d: Node3D = $Components as Node3D
	if components_3d != null:
		var local_position: Vector3 = components_3d.to_local(component.global_position)
		return clampi(_get_motor_slot_from_local_pos(local_position), 0, 3)

	return fallback_slot

func _is_propeller_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node3D):
		return false
	if node.has_meta("is_drone_propeller") and bool(node.get_meta("is_drone_propeller")):
		return true
	if node.is_in_group("drone_propellers"):
		return true
	if node.has_method("get_component_type"):
		var type_variant: Variant = node.call("get_component_type")
		if typeof(type_variant) == TYPE_STRING and String(type_variant) == "propeller":
			return true
	return str(node.name).to_lower().find("propeller") != -1

func _cleanup_component_arrays() -> void:
	var valid_motors: Array[Node3D] = []
	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor != null and is_instance_valid(motor):
			valid_motors.append(motor)
	motors.clear()
	motors.append_array(valid_motors)

	var known_propellers: Dictionary = {}
	var valid_propellers: Array[Node3D] = []
	for prop_variant in propellers:
		var propeller: Node3D = prop_variant as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue
		var instance_id: int = int(propeller.get_instance_id())
		if known_propellers.has(instance_id):
			continue
		known_propellers[instance_id] = true
		valid_propellers.append(propeller)

	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		for child in motor.get_children():
			var child_propeller: Node3D = child as Node3D
			if child_propeller == null or not is_instance_valid(child_propeller):
				continue
			if not _is_propeller_node(child_propeller):
				continue
			var child_id: int = int(child_propeller.get_instance_id())
			if known_propellers.has(child_id):
				continue
			known_propellers[child_id] = true
			valid_propellers.append(child_propeller)

	propellers.clear()
	propellers.append_array(valid_propellers)

	for key_variant in motor_propeller_map.keys():
		var mapped_motor: Node3D = key_variant as Node3D
		var mapped_propeller: Node3D = motor_propeller_map.get(mapped_motor) as Node3D
		if mapped_motor == null or not is_instance_valid(mapped_motor) or mapped_propeller == null or not is_instance_valid(mapped_propeller):
			motor_propeller_map.erase(mapped_motor)

func _refresh_motor_slots_from_positions() -> void:
	var components_root: Node3D = $Components as Node3D
	if components_root == null or motors.is_empty():
		return

	var slot_assignment: Dictionary = _assign_motor_slots_stable(components_root, motors)
	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var instance_id: int = int(motor.get_instance_id())
		if not slot_assignment.has(instance_id):
			continue
		var motor_slot: int = int(slot_assignment[instance_id])
		motor.set_meta("motor_slot", motor_slot)
		_apply_motor_slot_recursive(motor, motor_slot)

func _normalize_motor_propeller_links(force_snap_loose_propellers: bool = false) -> void:
	var components_root: Node3D = $Components as Node3D
	if components_root == null:
		return

	_cleanup_component_arrays()
	_refresh_motor_slots_from_positions()
	motor_propeller_map.clear()

	var motors_by_slot: Dictionary = {}
	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var motor_slot: int = _get_motor_slot_index(motor)
		if motor_slot >= 0:
			motors_by_slot[motor_slot] = motor

	var claimed_slots: Dictionary = {}
	for prop_variant in propellers:
		var propeller: Node3D = prop_variant as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue

		var target_slot: int = -1
		var parent_node: Node = propeller.get_parent()
		if parent_node is Node3D and motors.has(parent_node):
			target_slot = _get_motor_slot_index(parent_node as Node3D)
		elif propeller.has_meta("attached_motor_slot"):
			target_slot = int(propeller.get_meta("attached_motor_slot"))
		elif propeller.has_meta("motor_slot"):
			target_slot = int(propeller.get_meta("motor_slot"))
		elif force_snap_loose_propellers:
			var nearest_motor: Node3D = _find_nearest_motor(propeller, motors)
			if nearest_motor != null and is_instance_valid(nearest_motor):
				target_slot = _get_motor_slot_index(nearest_motor)

		if target_slot < 0 or not motors_by_slot.has(target_slot):
			if force_snap_loose_propellers and propeller.get_parent() != components_root:
				propeller.reparent(components_root, true)
			continue

		if claimed_slots.has(target_slot):
			if propeller.get_parent() != components_root:
				propeller.reparent(components_root, true)
			propeller.set_meta("attached_motor_slot", -1)
			continue

		var target_motor: Node3D = motors_by_slot[target_slot] as Node3D
		if target_motor == null or not is_instance_valid(target_motor):
			continue

		_attach_propeller_to_motor_clean(propeller, target_motor)
		propeller.set_meta("attached_motor_slot", target_slot)
		claimed_slots[target_slot] = propeller

func _attach_propeller_to_motor(propeller: Node3D, motor: Node3D) -> void:
	_attach_propeller_to_motor_clean(propeller, motor)
	return
	if propeller == null or not is_instance_valid(propeller):
		return
	if motor == null or not is_instance_valid(motor):
		return

	for key_variant in motor_propeller_map.keys():
		var mapped_motor: Node3D = key_variant as Node3D
		if mapped_motor == null or not is_instance_valid(mapped_motor):
			continue
		if motor_propeller_map[mapped_motor] != propeller:
			continue
		if mapped_motor != motor:
			motor_propeller_map.erase(mapped_motor)
		break

	if motor_propeller_map.has(motor):
		var current_propeller: Node3D = motor_propeller_map[motor] as Node3D
		if current_propeller != null and is_instance_valid(current_propeller) and current_propeller != propeller:
			current_propeller.reparent($Components, true)
			motor_propeller_map.erase(motor)

	# Проставляем слот (важно для физики в уровнях)
	var slot: int = _get_motor_slot_index(motor)
	if slot >= 0:
		propeller.set_meta("motor_slot", slot)
		_apply_motor_slot_recursive(propeller, slot)

	# Обязательные метки пропеллера
	propeller.set_meta("is_drone_propeller", true)
	if not propeller.is_in_group("drone_propellers"):
		propeller.add_to_group("drone_propellers")

	# Делаем пропеллер дочерним мотору, чтобы он гарантированно "жил" на своем моторе
	# и сохранял корректную привязку после экспорта.
		if propeller.get_parent() != motor:
			propeller.reparent(motor, true)
		motor_propeller_map[motor] = propeller

	# Позиционируем над мотором + небольшой оффсет для второго пропеллера на том же моторе
	var already: int = 0
	for c in motor.get_children():
		if c == propeller:
			continue
		if c is Node and c.has_meta("is_drone_propeller"):
			already += 1

	var lateral: float = 0.0
	if already % 2 == 0:
		lateral = 0.08
	else:
		lateral = -0.08

	var p3d: Node3D = propeller as Node3D
	p3d.position = Vector3(lateral, 0.3, 0.0)
	p3d.rotation = Vector3.ZERO

func _attach_propeller_to_motor_clean(propeller: Node3D, motor: Node3D) -> void:
	if propeller == null or not is_instance_valid(propeller):
		return
	if motor == null or not is_instance_valid(motor):
		return

	var components_root: Node3D = $Components as Node3D
	for key_variant in motor_propeller_map.keys():
		var mapped_motor: Node3D = key_variant as Node3D
		if mapped_motor == null or not is_instance_valid(mapped_motor):
			continue
		var mapped_propeller: Node3D = motor_propeller_map[mapped_motor] as Node3D
		if mapped_propeller == null or not is_instance_valid(mapped_propeller):
			motor_propeller_map.erase(mapped_motor)
			continue
		if mapped_propeller == propeller and mapped_motor != motor:
			motor_propeller_map.erase(mapped_motor)
		elif mapped_motor == motor and mapped_propeller != propeller and components_root != null:
			mapped_propeller.reparent(components_root, true)
			motor_propeller_map.erase(mapped_motor)

	if components_root != null:
		for child in motor.get_children():
			if child == propeller or not (child is Node3D):
				continue
			var other_propeller: Node3D = child as Node3D
			if other_propeller != null and is_instance_valid(other_propeller) and (other_propeller.has_meta("is_drone_propeller") or propellers.has(other_propeller)):
				other_propeller.reparent(components_root, true)

	var slot: int = _get_motor_slot_index(motor)
	if slot >= 0:
		propeller.set_meta("motor_slot", slot)
		_apply_motor_slot_recursive(propeller, slot)

	propeller.set_meta("is_drone_propeller", true)
	if not propeller.is_in_group("drone_propellers"):
		propeller.add_to_group("drone_propellers")

	if propeller.get_parent() != motor:
		propeller.reparent(motor, true)
	motor_propeller_map[motor] = propeller
	propeller.position = Vector3(0.0, 0.3, 0.0)
	propeller.rotation = Vector3.ZERO

func _find_mapped_motor_for_propeller(propeller: Node3D) -> Node3D:
	if propeller == null or not is_instance_valid(propeller):
		return null
	for key_variant in motor_propeller_map.keys():
		var mapped_motor: Node3D = key_variant as Node3D
		if mapped_motor == null or not is_instance_valid(mapped_motor):
			continue
		if motor_propeller_map[mapped_motor] == propeller:
			return mapped_motor
	var parent_node: Node = propeller.get_parent()
	if parent_node is Node3D and motors.has(parent_node):
		return parent_node as Node3D
	return null

func _update_motor_propeller_connection_clean(motor: Node3D) -> void:
	if motor == null or not is_instance_valid(motor):
		return
	if motor_propeller_map.has(motor):
		var mapped_propeller: Node3D = motor_propeller_map[motor] as Node3D
		if mapped_propeller != null and is_instance_valid(mapped_propeller):
			_attach_propeller_to_motor_clean(mapped_propeller, motor)
			return

	var closest_propeller: Node3D = null
	var closest_distance: float = INF
	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop == null or not is_instance_valid(prop):
			continue
		var d: float = prop.global_position.distance_to(motor.global_position)
		if d < PROP_SNAP_RADIUS and d < closest_distance:
			closest_distance = d
			closest_propeller = prop

	if closest_propeller != null:
		_attach_propeller_to_motor_clean(closest_propeller, motor)
	else:
		motor_propeller_map.erase(motor)

func _snap_propeller_to_motor_clean(propeller: Node3D) -> void:
	if propeller == null or not is_instance_valid(propeller):
		return

	var closest_motor: Node3D = null
	var closest_distance: float = INF
	for m in motors:
		var motor: Node3D = m as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var d: float = propeller.global_position.distance_to(motor.global_position)
		if d < closest_distance:
			closest_distance = d
			closest_motor = motor

	if closest_motor != null and closest_distance < PROP_SNAP_RADIUS:
		_attach_propeller_to_motor_clean(propeller, closest_motor)
		return

	var previous_motor: Node3D = _find_mapped_motor_for_propeller(propeller)
	if previous_motor != null and motor_propeller_map.has(previous_motor):
		motor_propeller_map.erase(previous_motor)
	var components_root: Node3D = $Components as Node3D
	if components_root != null and propeller.get_parent() != components_root:
		propeller.reparent(components_root, true)

func update_motor_propeller_connection(motor: Node3D) -> void:
	_update_motor_propeller_connection_clean(motor)
	return
	var old_propeller: Node3D = null
	if motor_propeller_map.has(motor):
		old_propeller = motor_propeller_map[motor] as Node3D

	var closest_propeller: Node3D = null
	var closest_distance: float = INF

	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop == null or not is_instance_valid(prop):
			continue
		if prop == dragged_component:
			continue

		var d: float = prop.global_position.distance_to(motor.global_position)
		if d < PROP_SNAP_RADIUS and d < closest_distance:
			closest_distance = d
			closest_propeller = prop

	if closest_propeller != null and closest_propeller != old_propeller:
		_attach_propeller_to_motor(closest_propeller, motor)

func snap_board_to_frame(board: Node3D) -> void:
	if drone_frame == null or not is_instance_valid(drone_frame):
		return

	var target_pos: Vector3 = drone_frame.global_position + Vector3(0, 0.3, 0.1)
	var current_pos: Vector3 = board.global_position

	if current_pos.distance_to(target_pos) < 1.0:
		board.global_position = target_pos
		board.rotation = drone_frame.rotation
		drone_board = board

func snap_propeller_to_motor(propeller: Node3D) -> void:
	_snap_propeller_to_motor_clean(propeller)
	return
	var closest_motor: Node3D = null
	var closest_distance: float = INF

	for m in motors:
		var motor: Node3D = m as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var d: float = propeller.global_position.distance_to(motor.global_position)
		if d < closest_distance:
			closest_distance = d
			closest_motor = motor

	if closest_motor != null and closest_distance < PROP_SNAP_RADIUS:
		# убрать старую связь (без удаления во время итерации)
		var key_to_erase: Node3D = null
		for k in motor_propeller_map.keys():
			var mot: Node3D = k as Node3D
			if mot != null and motor_propeller_map[mot] == propeller:
				key_to_erase = mot
				break
		if key_to_erase != null:
			motor_propeller_map.erase(key_to_erase)

			_attach_propeller_to_motor(propeller, closest_motor)

		# --- ВАЖНО ДЛЯ ФИЗИКИ: ставим slot на мотор и пропеллер ---
		var slot := -1

		# 1) если у мотора уже есть motor_slot — используем
		if closest_motor.has_meta("motor_slot"):
			slot = int(closest_motor.get_meta("motor_slot"))

		# 2) иначе считаем по позиции мотора в $Components
		if slot < 0:
			var local_motor_pos: Vector3 = ($Components as Node3D).to_local(closest_motor.global_position)
			slot = _get_motor_slot_from_local_pos(local_motor_pos)
			closest_motor.set_meta("motor_slot", slot)

		# 3) на пропеллер и всех его детей
		_apply_motor_slot_recursive(propeller, slot)

		# помечаем пропеллер как пропеллер (чтобы Drone.gd точно нашёл)
		propeller.set_meta("is_drone_propeller", true)
		if not propeller.is_in_group("drone_propellers"):
			propeller.add_to_group("drone_propellers")

		# позиционирование
		propeller.global_position = closest_motor.global_position + Vector3(0, 0.3, 0)
		propeller.rotation = closest_motor.rotation

func get_component_type(component: Node3D) -> String:
	if component == drone_frame:
		return "frame"
	if component == drone_board:
		return "board"
	if motors.has(component):
		return "motor"
	if propellers.has(component):
		return "propeller"
	return "unknown"

func get_component_name(component: Node3D) -> String:
	if component == drone_frame:
		return "Рама"
	if component == drone_board:
		return "Плата"
	if motors.has(component):
		var idx: int = motors.find(component)
		return "Двигатель " + str(idx + 1)
	if propellers.has(component):
		var idx2: int = propellers.find(component)
		return "Пропеллер " + str(idx2 + 1)
	return "Неизвестный компонент"

# ==================== ТОЧКИ КРЕПЛЕНИЯ ====================
func create_attachment_materials() -> void:
	green_material.albedo_color = Color(0, 1, 0, 0.7)
	green_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	red_material.albedo_color = Color(1, 0, 0, 0.7)
	red_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func show_attachment_points(component_type: String) -> void:
	hide_attachment_points()

	match component_type:
		"board":
			show_board_attachment_points()
		"motor":
			show_motor_attachment_points()
		"propeller":
			show_propeller_attachment_points()
		_:
			pass

func show_board_attachment_points() -> void:
	if drone_frame == null or not is_instance_valid(drone_frame):
		return

	var point: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	point.mesh = sphere

	add_child(point)

	var world_position: Vector3 = drone_frame.global_position + Vector3(0, 0.6, 0)
	point.global_position = world_position

	var point_free: bool = (drone_board == null or not is_instance_valid(drone_board) or drone_board == dragged_component)
	point.material_override = green_material if point_free else red_material

	attachment_points.append(point)

func show_motor_attachment_points() -> void:
	if drone_frame == null or not is_instance_valid(drone_frame):
		return

	var motor_points: Array = [
		Vector3(0, 0.28, 2.1),
		Vector3(0, 0.28, -2.1),
		Vector3(2.1, 0.28, 0),
		Vector3(-2.1, 0.28, 0)
	]

	for i in range(motor_points.size()):
		var point: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		point.mesh = sphere
		add_child(point)

		var wp: Vector3 = drone_frame.global_position + motor_points[i]
		point.global_position = wp

		var is_free: bool = true
		for m in motors:
			var motor: Node3D = m as Node3D
			if motor != null and is_instance_valid(motor) and motor != dragged_component:
				if motor.global_position.distance_to(wp) < 0.5:
					is_free = false
					break

		point.material_override = green_material if is_free else red_material
		attachment_points.append(point)

func show_propeller_attachment_points() -> void:
	for m in motors:
		var motor: Node3D = m as Node3D
		if motor == null or not is_instance_valid(motor):
			continue

		var point: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		point.mesh = sphere
		add_child(point)

		var wp: Vector3 = motor.global_position + Vector3(0, 0.3, 0)
		point.global_position = wp

		var motor_free: bool = true
		if motor_propeller_map.has(motor):
			var already: Node3D = motor_propeller_map[motor] as Node3D
			if already != null and is_instance_valid(already) and already != dragged_component:
				motor_free = false

		point.material_override = green_material if motor_free else red_material
		attachment_points.append(point)

func hide_attachment_points() -> void:
	for p in attachment_points:
		var point: Node3D = p as Node3D
		if point != null and is_instance_valid(point):
			point.queue_free()
	attachment_points.clear()

func find_closest_motor_attachment_point(position: Vector3) -> Vector3:
	if drone_frame == null or not is_instance_valid(drone_frame):
		return position

	var candidates: Array = [
		drone_frame.global_position + Vector3(0, 0.48, 2.1),
		drone_frame.global_position + Vector3(0, 0.48, -2.1),
		drone_frame.global_position + Vector3(2.1, 0.48, 0),
		drone_frame.global_position + Vector3(-2.1, 0.48, 0)
	]

	var best: Vector3 = position
	var best_dist: float = INF
	var found: bool = false

	for c in candidates:
		var pt: Vector3 = c
		var free_point: bool = true

		for m in motors:
			var motor: Node3D = m as Node3D
			if motor != null and is_instance_valid(motor) and motor != dragged_component:
				if motor.global_position.distance_to(pt) < 0.5:
					free_point = false
					break

		if free_point:
			var d: float = position.distance_to(pt)
			if d < best_dist:
				best_dist = d
				best = pt
				found = true

	if found and best_dist < 2.0:
		return best
	return position

func find_closest_board_attachment_point(position: Vector3) -> Vector3:
	if drone_frame == null or not is_instance_valid(drone_frame):
		return position

	var board_point: Vector3 = drone_frame.global_position + Vector3(0, 0.3, 0.1)
	var free_point: bool = (drone_board == null or not is_instance_valid(drone_board) or drone_board == dragged_component)

	if free_point:
		var d: float = position.distance_to(board_point)
		if d < 1.5:
			return board_point

	return position

func find_closest_motor_for_propeller(position: Vector3) -> Node3D:
	var best_motor: Node3D = null
	var best_dist: float = INF

	for m in motors:
		var motor: Node3D = m as Node3D
		if motor == null or not is_instance_valid(motor):
			continue

		var motor_free: bool = true
		if motor_propeller_map.has(motor):
			var already: Node3D = motor_propeller_map[motor] as Node3D
			if already != null and is_instance_valid(already) and already != dragged_component:
				motor_free = false

		if motor_free:
			var d: float = position.distance_to(motor.global_position)
			if d < best_dist:
				best_dist = d
				best_motor = motor

	if best_motor != null and best_dist < 2.0:
		return best_motor
	return null

# ==================== СИСТЕМА КОМПОНЕНТОВ ====================
func add_frame() -> void:
	if not Global.is_component_available("frame", current_frame_type):
		return
	if drone_frame != null and is_instance_valid(drone_frame):
		return

	var frame_prefab: PackedScene = frame_prefabs.get(current_frame_type, null)
	if frame_prefab == null:
		return

	var new_frame: Node3D = frame_prefab.instantiate() as Node3D
	$Components.add_child(new_frame)
	drone_frame = new_frame

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector3 = screen_to_world_position(mouse_pos)
	new_frame.position = world_pos
	_tag_component_for_customization(new_frame, "frame")

	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	start_component_dragging(drone_frame, mouse_pos)
	call_deferred("_tut_notify", "frame_spawned")

func add_board() -> void:
	if not Global.is_component_available("board", current_board_type):
		return
	if drone_frame == null or not is_instance_valid(drone_frame):
		return
	if drone_board != null and is_instance_valid(drone_board):
		return

	var board_prefab: PackedScene = board_prefabs.get(current_board_type, null)
	if board_prefab == null:
		return

	var new_board: Node3D = board_prefab.instantiate() as Node3D
	$Components.add_child(new_board)
	drone_board = new_board

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector3 = screen_to_world_position(mouse_pos)
	new_board.position = world_pos
	_tag_component_for_customization(new_board, "board")

	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	start_component_dragging(drone_board, mouse_pos)
	call_deferred("_tut_notify", "board_spawned")

func add_motor() -> void:
	if not Global.is_component_available("motor", current_motor_type):
		return
	if drone_frame == null or not is_instance_valid(drone_frame):
		return
	if motors.size() >= 4:
		return

	var motor_prefab: PackedScene = motor_prefabs.get(current_motor_type, null)
	if motor_prefab == null:
		return

	var new_motor: Node3D = motor_prefab.instantiate() as Node3D
	$Components.add_child(new_motor)

	# Запоминаем тип именно этого мотора (чтобы не ломать будущие расширения)
	new_motor.set_meta("component_type", current_motor_type)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector3 = screen_to_world_position(mouse_pos)
	new_motor.position = world_pos

	motors.append(new_motor)
	_update_cosmetic_tags()

	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	start_component_dragging(new_motor, mouse_pos)
	call_deferred("_tut_notify", "motor_spawned")

func add_propeller() -> void:
	if not Global.is_component_available("propeller", current_propeller_type):
		return
	if motors.size() <= 0:
		return
	if propellers.size() >= motors.size():
		return

	var prop_prefab: PackedScene = propeller_prefabs.get(current_propeller_type, null)
	if prop_prefab == null:
		return

	var new_prop: Node3D = prop_prefab.instantiate() as Node3D
	$Components.add_child(new_prop)

	new_prop.set_meta("component_type", current_propeller_type)
	new_prop.set_meta("is_drone_propeller", true)
	if not new_prop.is_in_group("drone_propellers"):
		new_prop.add_to_group("drone_propellers")

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector3 = screen_to_world_position(mouse_pos)
	new_prop.position = world_pos

	propellers.append(new_prop)
	_update_cosmetic_tags()

	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	start_component_dragging(new_prop, mouse_pos)
	call_deferred("_tut_notify", "propeller_spawned")

func delete_frame() -> void:
	if drone_frame != null and is_instance_valid(drone_frame):
		delete_board()
		while motors.size() > 0:
			delete_motor(0)
		drone_frame.queue_free()
	drone_frame = null
	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	_save_assembly_autosave()

func delete_board() -> void:
	if drone_board != null and is_instance_valid(drone_board):
		drone_board.queue_free()
	drone_board = null
	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	_save_assembly_autosave()

func delete_motor(index: int) -> void:
	if index < 0 or index >= motors.size():
		return

	var motor: Node3D = motors[index]
	if motor != null and is_instance_valid(motor):
		if motor_propeller_map.has(motor):
			var prop: Node3D = motor_propeller_map[motor] as Node3D
			if prop != null and is_instance_valid(prop):
				propellers.erase(prop)
				prop.queue_free()
			motor_propeller_map.erase(motor)

		motor.queue_free()

	motors.remove_at(index)
	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	_save_assembly_autosave()

func delete_propeller(index: int) -> void:
	if index < 0 or index >= propellers.size():
		return

	var prop: Node3D = propellers[index]
	if prop != null and is_instance_valid(prop):
		var key_to_erase: Node3D = null
		for k in motor_propeller_map.keys():
			var mot: Node3D = k as Node3D
			if mot != null and motor_propeller_map[mot] == prop:
				key_to_erase = mot
				break
		if key_to_erase != null:
			motor_propeller_map.erase(key_to_erase)

		prop.queue_free()

	propellers.remove_at(index)
	calculate_drone_stats()
	update_component_list()
	_apply_current_customization_to_assembly()
	_save_assembly_autosave()

func clear_drone() -> void:
	var components_root: Node3D = $Components as Node3D
	if components_root != null:
		for child in components_root.get_children():
			if child != null and is_instance_valid(child):
				child.free()
	drone_frame = null

	drone_board = null

	motors.clear()

	propellers.clear()

	motor_propeller_map.clear()
	_components_center_valid = false

	current_frame_type = "Рама1"
	current_board_type = "Плата1"
	current_motor_type = "Мотор1"
	current_propeller_type = "Пропеллер1"

	calculate_drone_stats()
	update_component_list()
	_save_assembly_autosave()

func screen_to_world_position(screen_pos: Vector2) -> Vector3:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)

	var drag_plane: Plane = Plane(Vector3.UP, 0.5)
	var hit = drag_plane.intersects_ray(from, ray_dir)
	if hit is Vector3:
		return hit
	return Vector3(0, 0.5, 0)

func clamp_position(position: Vector3) -> Vector3:
	var floor_limit_y: float = maxf(BOUNDS_MIN.y, 0.25)
	return Vector3(
		clamp(position.x, BOUNDS_MIN.x, BOUNDS_MAX.x),
		clamp(position.y, floor_limit_y, BOUNDS_MAX.y),
		clamp(position.z, BOUNDS_MIN.z, BOUNDS_MAX.z)
	)

# ==================== СТАТЫ ====================
func calculate_drone_stats() -> void:
	if not is_dragging_component:
		_normalize_motor_propeller_links()

	drone_stats["total_mass"] = 0.0
	drone_stats["total_thrust"] = 0.0
	drone_stats["missing_motors"] = 0
	drone_stats["missing_propellers"] = 0
	drone_stats["frame_present"] = drone_frame != null and is_instance_valid(drone_frame)
	drone_stats["board_present"] = drone_board != null and is_instance_valid(drone_board)

	if bool(drone_stats["frame_present"]):
		var frame_stat: Dictionary = component_stats["frame"][current_frame_type]
		drone_stats["total_mass"] = float(drone_stats["total_mass"]) + float(frame_stat["mass"])

	if bool(drone_stats["board_present"]):
		var board_stat: Dictionary = component_stats["board"][current_board_type]
		drone_stats["total_mass"] = float(drone_stats["total_mass"]) + float(board_stat["mass"])

	var motor_slots: Dictionary = {}
	for m in motors:
		var motor: Node3D = m as Node3D
		if motor != null and is_instance_valid(motor):
			var motor_type: String = current_motor_type
			if motor.has_meta("component_type"):
				motor_type = str(motor.get_meta("component_type"))

			var motor_stat: Dictionary = component_stats["motor"][motor_type]
			drone_stats["total_mass"] = float(drone_stats["total_mass"]) + float(motor_stat["mass"])
			drone_stats["total_thrust"] = float(drone_stats["total_thrust"]) + float(motor_stat["thrust"])
			var motor_slot: int = _resolve_component_slot(motor, motors.find(motor))
			if motor_slot >= 0:
				motor_slots[motor_slot] = true

	var propeller_slots: Dictionary = {}
	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop != null and is_instance_valid(prop):
			var prop_type: String = current_propeller_type
			if prop.has_meta("component_type"):
				prop_type = str(prop.get_meta("component_type"))

			var prop_stat: Dictionary = component_stats["propeller"][prop_type]
			drone_stats["total_mass"] = float(drone_stats["total_mass"]) + float(prop_stat["mass"])
			var prop_slot: int = _resolve_component_slot(prop, propellers.find(prop))
			if prop_slot >= 0 and _find_mapped_motor_for_propeller(prop) != null:
				propeller_slots[prop_slot] = true

	drone_stats["missing_motors"] = maxi(0, 4 - motor_slots.size())
	drone_stats["missing_propellers"] = maxi(0, 4 - propeller_slots.size())
	drone_stats["is_balanced"] = bool(drone_stats["frame_present"]) \
		and bool(drone_stats["board_present"]) \
		and motor_slots.size() == 4 \
		and propeller_slots.size() == 4

	update_stats_display()
	update_balance_warning()

func _refresh_assembly_stats_ui() -> void:
	var stats_panel: Panel = $UI.get_node_or_null("StatsPanel") as Panel
	if stats_panel == null:
		stats_panel = create_stats_panel()

	var mass: float = float(drone_stats.get("total_mass", 0.0))
	var thrust: float = float(drone_stats.get("total_thrust", 0.0))
	var ratio: float = thrust / maxf(mass, 0.1)
	var motors_ready: int = maxi(0, 4 - int(drone_stats.get("missing_motors", 0)))
	var propellers_ready: int = maxi(0, 4 - int(drone_stats.get("missing_propellers", 0)))
	var status_line: String = "Статус: готов к полету" if bool(drone_stats.get("is_balanced", false)) else "Статус: сборка не завершена"

	var lines: Array[String] = [
		"ХАРАКТЕРИСТИКИ ДРОНА",
		"Масса: %.1f кг" % mass,
		"Тяга: %.1f ед." % thrust,
		"Соотношение тяги: %.2f" % ratio,
		"Рама: %s" % ("есть" if bool(drone_stats.get("frame_present", false)) else "нет"),
		"Плата: %s" % ("есть" if bool(drone_stats.get("board_present", false)) else "нет"),
		"Моторы: %d/4" % motors_ready,
		"Пропеллеры: %d/4" % propellers_ready,
		status_line
	]

	var label: Label = stats_panel.get_node("Label") as Label
	if label != null:
		label.text = "\n".join(lines)

func _refresh_assembly_balance_ui() -> void:
	var warning_label: Label = $UI.get_node_or_null("BalanceWarning") as Label
	if warning_label == null:
		warning_label = Label.new()
		warning_label.name = "BalanceWarning"
		warning_label.position = Vector2(20, 100)
		warning_label.size = Vector2(360, 44)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_font_size_override("font_size", 16)
		$UI.add_child(warning_label)

	if bool(drone_stats.get("is_balanced", false)):
		warning_label.add_theme_color_override("font_color", Color(0.82, 0.71, 0.52))
		warning_label.text = "Сборка готова к полету"
		return

	var issues: Array[String] = []
	if not bool(drone_stats.get("frame_present", false)):
		issues.append("нет рамы")
	if not bool(drone_stats.get("board_present", false)):
		issues.append("нет платы")
	if int(drone_stats.get("missing_motors", 0)) > 0:
		issues.append("не хватает моторов: %d" % int(drone_stats.get("missing_motors", 0)))
	if int(drone_stats.get("missing_propellers", 0)) > 0:
		issues.append("не хватает пропеллеров: %d" % int(drone_stats.get("missing_propellers", 0)))

	warning_label.add_theme_color_override("font_color", Color(0.92, 0.45, 0.34))
	warning_label.text = "Сборка не готова: %s" % ", ".join(issues)

func update_stats_display() -> void:
	_refresh_assembly_stats_ui()
	return
	var stats_panel: Panel = $UI.get_node_or_null("StatsPanel") as Panel
	if stats_panel == null:
		stats_panel = create_stats_panel()

	var mass: float = float(drone_stats["total_mass"])
	var thrust: float = float(drone_stats["total_thrust"])
	var ratio: float = thrust / max(mass, 0.1)

	var stats_text: String = "ХАРАКТЕРИСТИКИ ДРОНА:\n"
	stats_text += "Масса: %.1f кг\n" % mass
	stats_text += "Тяга: %.1f ед.\n" % thrust
	stats_text += "Соотношение: %.2f\n" % ratio

	if not bool(drone_stats["is_balanced"]):
		stats_text += "⚠️ НЕСБАЛАНСИРОВАН!\n"
		stats_text += "Отсутствует моторов: %d\n" % int(drone_stats["missing_motors"])
		stats_text += "Дрон будет заваливаться в полете!"
	else:
		stats_text += "✅ Сбалансирован"

	stats_text = "ХАРАКТЕРИСТИКИ ДРОНА:\n"
	stats_text += "Масса: %.1f кг\n" % mass
	stats_text += "Тяга: %.1f ед.\n" % thrust
	stats_text += "Соотношение: %.2f\n" % ratio
	stats_text += "Рама: %s\n" % ("есть" if bool(drone_stats.get("frame_present", false)) else "нет")
	stats_text += "Плата: %s\n" % ("есть" if bool(drone_stats.get("board_present", false)) else "нет")
	stats_text += "Не хватает моторов: %d\n" % int(drone_stats.get("missing_motors", 0))
	stats_text += "Не хватает пропеллеров: %d" % int(drone_stats.get("missing_propellers", 0))

	var label: Label = stats_panel.get_node("Label") as Label
	if label != null:
		label.text = stats_text

func create_stats_panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "StatsPanel"
	panel.size = Vector2(356, 238)
	panel.position = Vector2(20, 150)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.08, 0.90)
	style.border_color = Color(0.76, 0.59, 0.39, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.name = "Label"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 16.0
	label.offset_top = 14.0
	label.offset_right = -16.0
	label.offset_bottom = -14.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))

	panel.add_child(label)
	$UI.add_child(panel)
	return panel

func update_balance_warning() -> void:
	_refresh_assembly_balance_ui()
	return
	var warning_label: Label = $UI.get_node_or_null("BalanceWarning") as Label
	if warning_label == null:
		warning_label = Label.new()
		warning_label.name = "BalanceWarning"
		warning_label.position = Vector2(20, 100)
		warning_label.add_theme_font_size_override("font_size", 16)
		$UI.add_child(warning_label)

	if not bool(drone_stats["is_balanced"]):
		warning_label.add_theme_color_override("font_color", Color.RED)
		warning_label.text = "⚠️ ДРОН НЕСБАЛАНСИРОВАН! Добавьте %d моторов" % int(drone_stats["missing_motors"])
	else:
		warning_label.add_theme_color_override("font_color", Color.GREEN)
		warning_label.text = "✅ Дрон сбалансирован"

# ==================== ИЕРАРХИЯ / СПИСОК ====================
	if not bool(drone_stats["is_balanced"]):
		var issues: Array[String] = []
		if not bool(drone_stats.get("frame_present", false)):
			issues.append("рама")
		if not bool(drone_stats.get("board_present", false)):
			issues.append("плата")
		if int(drone_stats.get("missing_motors", 0)) > 0:
			issues.append("%d мотор." % int(drone_stats.get("missing_motors", 0)))
		if int(drone_stats.get("missing_propellers", 0)) > 0:
			issues.append("%d пропел." % int(drone_stats.get("missing_propellers", 0)))
		warning_label.add_theme_color_override("font_color", Color(0.92, 0.45, 0.34))
		warning_label.text = "Сборка не готова: %s" % ", ".join(issues)
	else:
		warning_label.add_theme_color_override("font_color", Color(0.82, 0.71, 0.52))
		warning_label.text = "Сборка готова к полету"

func _build_assembly_button_style(fill: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 10
	return style

func _build_assembly_panel_style(fill: Color, border: Color, radius: int = 18) -> StyleBoxFlat:
	var style := _build_assembly_button_style(fill, border, radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 16
	return style

func _apply_assembly_button_theme(button: Button, fill: Color, border: Color, font_size: int = 16) -> void:
	if button == null:
		return

	var normal: StyleBoxFlat = _build_assembly_button_style(fill, border)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.06)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.08)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = fill.darkened(0.16)
	disabled.border_color = border.darkened(0.12)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	button.add_theme_color_override("font_focus_color", Color(0.99, 0.95, 0.88))
	button.add_theme_color_override("font_hover_color", Color(0.99, 0.95, 0.88))
	button.add_theme_color_override("font_pressed_color", Color(0.97, 0.92, 0.85))
	button.add_theme_color_override("font_disabled_color", Color(0.73, 0.64, 0.56))
	button.add_theme_font_size_override("font_size", font_size)

func _apply_selector_option_theme(button: Button, is_selected: bool, is_unlocked: bool) -> void:
	if button == null:
		return

	if not is_unlocked:
		_apply_assembly_button_theme(button, Color(0.21, 0.16, 0.12, 0.92), Color(0.45, 0.34, 0.24, 0.68), 14)
		return

	if is_selected:
		_apply_assembly_button_theme(button, Color(0.49, 0.35, 0.22, 0.98), Color(0.92, 0.73, 0.47, 0.96), 14)
	else:
		_apply_assembly_button_theme(button, Color(0.26, 0.19, 0.13, 0.97), Color(0.72, 0.56, 0.36, 0.88), 14)

func _apply_assembly_ui_theme() -> void:
	if open_close_button != null:
		_apply_assembly_button_theme(open_close_button, Color(0.31, 0.22, 0.15, 0.97), Color(0.82, 0.63, 0.42, 0.95), 16)

	if list_panel != null:
		list_panel.add_theme_stylebox_override("panel", _build_assembly_panel_style(
			Color(0.15, 0.10, 0.07, 0.94),
			Color(0.74, 0.57, 0.38, 0.84)
		))

	var hierarchy_title := get_node_or_null("UI/Hierarchy/Title") as Label
	if hierarchy_title != null:
		hierarchy_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.83))

	if component_list != null:
		component_list.add_theme_stylebox_override("panel", _build_assembly_button_style(
			Color(0.20, 0.14, 0.10, 0.94),
			Color(0.62, 0.47, 0.31, 0.74),
			12
		))
		component_list.add_theme_color_override("font_color", Color(0.95, 0.90, 0.83))
		component_list.add_theme_color_override("font_selected_color", Color(0.99, 0.95, 0.88))
		component_list.add_theme_color_override("guide_color", Color(0.59, 0.45, 0.30, 0.45))

	var stats_panel := get_node_or_null("UI/StatsPanel") as Panel
	if stats_panel != null:
		stats_panel.add_theme_stylebox_override("panel", _build_assembly_panel_style(
			Color(0.14, 0.10, 0.07, 0.92),
			Color(0.71, 0.55, 0.37, 0.78)
		))

	var stats_label := get_node_or_null("UI/StatsPanel/Label") as Label
	if stats_label != null:
		stats_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.83))

	var warning_label := get_node_or_null("UI/BalanceWarning") as Label
	if warning_label != null:
		warning_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.67))

	var selectors := get_node_or_null("UI/ComponentSelectors") as VBoxContainer
	if selectors != null:
		selectors.add_theme_constant_override("separation", 10)

	_apply_assembly_button_theme(get_node_or_null("UI/ComponentSelectors/FrameSelector/FrameButton") as Button, Color(0.33, 0.23, 0.15, 0.97), Color(0.83, 0.64, 0.42, 0.95), 16)
	_apply_assembly_button_theme(get_node_or_null("UI/ComponentSelectors/BoardSelector/BoardButton") as Button, Color(0.31, 0.22, 0.15, 0.97), Color(0.79, 0.61, 0.40, 0.92), 16)
	_apply_assembly_button_theme(get_node_or_null("UI/ComponentSelectors/MotorSelector/MotorButton") as Button, Color(0.29, 0.20, 0.14, 0.97), Color(0.75, 0.58, 0.38, 0.90), 16)
	_apply_assembly_button_theme(get_node_or_null("UI/ComponentSelectors/PropellerSelector/PropellerButton") as Button, Color(0.28, 0.19, 0.13, 0.97), Color(0.72, 0.56, 0.36, 0.88), 16)

	if _arduino_button != null:
		_apply_assembly_button_theme(_arduino_button, Color(0.37, 0.25, 0.16, 0.98), Color(0.88, 0.68, 0.45, 0.95), 17)
	if _customization_button != null:
		_apply_assembly_button_theme(_customization_button, Color(0.34, 0.23, 0.15, 0.98), Color(0.84, 0.66, 0.43, 0.94), 17)

	var main_menu_btn := get_node_or_null("TopUiLayer/Overlay/btn_main_menu") as Button
	if main_menu_btn != null:
		_apply_assembly_button_theme(main_menu_btn, Color(0.28, 0.20, 0.14, 0.97), Color(0.76, 0.59, 0.39, 0.90), 15)

	if _pause_panel != null:
		_pause_panel.add_theme_stylebox_override("panel", _build_assembly_panel_style(
			Color(0.15, 0.10, 0.07, 0.96),
			Color(0.79, 0.60, 0.39, 0.90)
		))

func init_ui_components() -> void:
	open_close_button = get_node_or_null("UI/OpenClose") as Button
	list_panel = get_node_or_null("UI/Hierarchy") as Panel
	component_list = get_node_or_null("UI/Hierarchy/Complist") as ItemList

	if list_panel != null:
		list_panel.visible = false

	# OpenClose уже подключён в сцене, но на всякий — без дублей
	if open_close_button != null:
		var cb: Callable = Callable(self, "_on_open_close_pressed")
		if not open_close_button.is_connected("pressed", cb):
			open_close_button.pressed.connect(_on_open_close_pressed)

	if component_list != null:
		var cb2: Callable = Callable(self, "_on_component_list_item_clicked")
		if not component_list.is_connected("item_clicked", cb2):
			component_list.item_clicked.connect(_on_component_list_item_clicked)

	_apply_assembly_ui_theme()

func setup_hierarchy_panel() -> void:
	# НИЧЕГО НЕ СОЗДАЁМ — панель и список уже есть в твоей сцене
	list_panel = get_node_or_null("UI/Hierarchy") as Panel
	component_list = get_node_or_null("UI/Hierarchy/Complist") as ItemList

func _on_open_close_pressed() -> void:
	if list_panel == null:
		return

	list_panel.visible = not list_panel.visible

	if open_close_button != null:
		open_close_button.text = "📋 Скрыть список" if list_panel.visible else "📋 Показать список"

	if list_panel.visible:
		update_component_list()

func update_component_list() -> void:
	if component_list == null:
		return

	component_list.clear()

	if drone_frame != null and is_instance_valid(drone_frame):
		component_list.add_item("Рама: " + current_frame_type)
	if drone_board != null and is_instance_valid(drone_board):
		component_list.add_item("Плата: " + current_board_type)

	for i in range(motors.size()):
		var motor: Node3D = motors[i]
		if motor != null and is_instance_valid(motor):
			component_list.add_item("Двигатель " + str(i + 1) + ": " + current_motor_type)

	for i2 in range(propellers.size()):
		var prop: Node3D = propellers[i2]
		if prop != null and is_instance_valid(prop):
			component_list.add_item("Пропеллер " + str(i2 + 1) + ": " + current_propeller_type)

func _on_component_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		delete_component_by_index(index)

func delete_component_by_index(index: int) -> void:
	if component_list == null:
		return

	if index < 0 or index >= component_list.item_count:
		return

	var item_text: String = component_list.get_item_text(index)

	if item_text.begins_with("Рама:"):
		delete_frame()
	elif item_text.begins_with("Плата:"):
		delete_board()
	elif item_text.begins_with("Двигатель"):
		var motor_number: int = extract_number_from_text(item_text)
		if motor_number != -1:
			delete_motor(motor_number - 1)
	elif item_text.begins_with("Пропеллер"):
		var prop_number: int = extract_number_from_text(item_text)
		if prop_number != -1:
			delete_propeller(prop_number - 1)

func extract_number_from_text(text: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile("(\\d+)")
	var result: RegExMatch = regex.search(text)
	if result != null:
		return int(result.get_string(1))
	return -1

# ==================== ВЫБОР КОМПОНЕНТОВ (UI, создаётся 1 раз) ====================
func create_component_selectors_ui() -> void:
	if $UI.has_node("ComponentSelectors"):
		return

	var component_selectors: VBoxContainer = VBoxContainer.new()
	component_selectors.name = "ComponentSelectors"

	component_selectors.anchors_preset = Control.PRESET_BOTTOM_LEFT
	component_selectors.anchor_left = 0.0
	component_selectors.anchor_bottom = 1.0
	component_selectors.anchor_right = 0.0
	component_selectors.anchor_top = 1.0

	component_selectors.offset_left = 20
	component_selectors.offset_bottom = -20
	component_selectors.offset_right = 320
	component_selectors.offset_top = -700
	component_selectors.add_theme_constant_override("separation", 10)

	create_frame_section(component_selectors)
	create_board_section(component_selectors)
	create_motor_section(component_selectors)
	create_propeller_section(component_selectors)

	$UI.add_child(component_selectors)
	_apply_assembly_ui_theme()

func create_customization_section(parent: VBoxContainer) -> void:
	var customization_section := VBoxContainer.new()
	customization_section.name = "CustomizationSelector"
	customization_section.custom_minimum_size = Vector2(0, 58)
	customization_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var customization_button := Button.new()
	customization_button.name = "CustomizationButton"
	customization_button.text = "Кастомизация"
	customization_button.custom_minimum_size = Vector2(0, 44)
	customization_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	customization_button.add_theme_font_size_override("font_size", 16)
	customization_button.pressed.connect(_on_customization_pressed)
	_apply_assembly_button_theme(customization_button, Color(0.35, 0.24, 0.16, 0.98), Color(0.90, 0.70, 0.45, 0.96), 16)
	customization_section.add_child(customization_button)

	parent.add_child(customization_section)

func create_frame_section(parent: VBoxContainer) -> void:
	var frame_section: VBoxContainer = VBoxContainer.new()
	frame_section.name = "FrameSelector"
	frame_section.custom_minimum_size = Vector2(0, 50)
	frame_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var frame_button: Button = Button.new()
	frame_button.name = "FrameButton"
	frame_button.text = "Рамы"
	frame_button.custom_minimum_size = Vector2(0, 40)
	frame_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_button.add_theme_font_size_override("font_size", 16)
	frame_button.pressed.connect(_on_frame_menu_toggled)
	_apply_assembly_button_theme(frame_button, Color(0.33, 0.23, 0.15, 0.97), Color(0.83, 0.64, 0.42, 0.95), 16)

	var options: VBoxContainer = VBoxContainer.new()
	options.name = "FrameOptionsContainer"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.visible = false

	frame_section.add_child(frame_button)
	frame_section.add_child(options)
	parent.add_child(frame_section)

func create_board_section(parent: VBoxContainer) -> void:
	var sec: VBoxContainer = VBoxContainer.new()
	sec.name = "BoardSelector"
	sec.custom_minimum_size = Vector2(0, 50)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b: Button = Button.new()
	b.name = "BoardButton"
	b.text = "Платы"
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_board_menu_toggled)
	_apply_assembly_button_theme(b, Color(0.31, 0.22, 0.15, 0.97), Color(0.79, 0.61, 0.40, 0.92), 16)

	var options: VBoxContainer = VBoxContainer.new()
	options.name = "BoardOptionsContainer"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.visible = false

	sec.add_child(b)
	sec.add_child(options)
	parent.add_child(sec)

func create_motor_section(parent: VBoxContainer) -> void:
	var sec: VBoxContainer = VBoxContainer.new()
	sec.name = "MotorSelector"
	sec.custom_minimum_size = Vector2(0, 50)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b: Button = Button.new()
	b.name = "MotorButton"
	b.text = "Двигатели"
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_motor_menu_toggled)
	_apply_assembly_button_theme(b, Color(0.29, 0.20, 0.14, 0.97), Color(0.75, 0.58, 0.38, 0.90), 16)

	var options: VBoxContainer = VBoxContainer.new()
	options.name = "MotorOptionsContainer"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.visible = false

	sec.add_child(b)
	sec.add_child(options)
	parent.add_child(sec)

func create_propeller_section(parent: VBoxContainer) -> void:
	var sec: VBoxContainer = VBoxContainer.new()
	sec.name = "PropellerSelector"
	sec.custom_minimum_size = Vector2(0, 50)
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var b: Button = Button.new()
	b.name = "PropellerButton"
	b.text = "Пропеллеры"
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_propeller_menu_toggled)
	_apply_assembly_button_theme(b, Color(0.28, 0.19, 0.13, 0.97), Color(0.72, 0.56, 0.36, 0.88), 16)

	var options: VBoxContainer = VBoxContainer.new()
	options.name = "PropellerOptionsContainer"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.visible = false

	sec.add_child(b)
	sec.add_child(options)
	parent.add_child(sec)

func _on_frame_menu_toggled() -> void:
	_close_other_menus("frame")
	var options: VBoxContainer = $UI/ComponentSelectors/FrameSelector/FrameOptionsContainer
	options.visible = not options.visible
	if options.visible and options.get_child_count() == 0:
		create_frame_options()
	if options.visible:
		call_deferred("_tut_notify", "frame_menu_open")

func _on_board_menu_toggled() -> void:
	_close_other_menus("board")
	var options: VBoxContainer = $UI/ComponentSelectors/BoardSelector/BoardOptionsContainer
	options.visible = not options.visible
	if options.visible and options.get_child_count() == 0:
		create_board_options()
	if options.visible:
		call_deferred("_tut_notify", "board_menu_open")

func _on_motor_menu_toggled() -> void:
	_close_other_menus("motor")
	var options: VBoxContainer = $UI/ComponentSelectors/MotorSelector/MotorOptionsContainer
	options.visible = not options.visible
	if options.visible and options.get_child_count() == 0:
		create_motor_options()
	if options.visible:
		call_deferred("_tut_notify", "motor_menu_open")

func _on_propeller_menu_toggled() -> void:
	_close_other_menus("propeller")
	var options: VBoxContainer = $UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer
	options.visible = not options.visible
	if options.visible and options.get_child_count() == 0:
		create_propeller_options()
	if options.visible:
		call_deferred("_tut_notify", "propeller_menu_open")

func _close_other_menus(except_menu: String) -> void:
	var menus: Dictionary = {
		"frame": $UI/ComponentSelectors/FrameSelector/FrameOptionsContainer,
		"board": $UI/ComponentSelectors/BoardSelector/BoardOptionsContainer,
		"motor": $UI/ComponentSelectors/MotorSelector/MotorOptionsContainer,
		"propeller": $UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer
	}
	for k in menus.keys():
		if str(k) != except_menu:
			var node: Node = menus[k]
			if node != null:
				(node as CanvasItem).visible = false

func create_frame_options() -> void:
	var options: VBoxContainer = $UI/ComponentSelectors/FrameSelector/FrameOptionsContainer
	for child in options.get_children():
		child.queue_free()
	frame_buttons.clear()

	for frame_name in frame_prefabs.keys():
		var button: Button = Button.new()
		button.text = str(frame_name)
		button.custom_minimum_size = Vector2(0, 35)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)

		if Global.is_component_available("frame", button.text):
			button.disabled = false
			button.pressed.connect(_on_frame_selected.bind(button.text))
		else:
			button.disabled = true
			button.tooltip_text = "Не куплено в магазине"

		_apply_selector_option_theme(button, false, not button.disabled)
		options.add_child(button)
		frame_buttons.append(button)

	update_frame_selection()

func create_board_options() -> void:
	var options: VBoxContainer = $UI/ComponentSelectors/BoardSelector/BoardOptionsContainer
	for child in options.get_children():
		child.queue_free()
	board_buttons.clear()

	for board_name in board_prefabs.keys():
		var button: Button = Button.new()
		button.text = str(board_name)
		button.custom_minimum_size = Vector2(0, 35)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)

		if Global.is_component_available("board", button.text):
			button.disabled = false
			button.pressed.connect(_on_board_selected.bind(button.text))
		else:
			button.disabled = true
			button.tooltip_text = "Не куплено в магазине"

		_apply_selector_option_theme(button, false, not button.disabled)
		options.add_child(button)
		board_buttons.append(button)

	update_board_selection()

func create_motor_options() -> void:
	var options: VBoxContainer = $UI/ComponentSelectors/MotorSelector/MotorOptionsContainer
	for child in options.get_children():
		child.queue_free()
	motor_buttons.clear()

	for motor_name in motor_prefabs.keys():
		var button: Button = Button.new()
		button.text = str(motor_name)
		button.custom_minimum_size = Vector2(0, 35)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)

		if Global.is_component_available("motor", button.text):
			button.disabled = false
			button.pressed.connect(_on_motor_selected.bind(button.text))
		else:
			button.disabled = true
			button.tooltip_text = "Не куплено в магазине"

		_apply_selector_option_theme(button, false, not button.disabled)
		options.add_child(button)
		motor_buttons.append(button)

	update_motor_selection()

func create_propeller_options() -> void:
	var options: VBoxContainer = $UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer
	for child in options.get_children():
		child.queue_free()
	propeller_buttons.clear()

	for prop_name in propeller_prefabs.keys():
		var button: Button = Button.new()
		button.text = str(prop_name)
		button.custom_minimum_size = Vector2(0, 35)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)

		if Global.is_component_available("propeller", button.text):
			button.disabled = false
			button.pressed.connect(_on_propeller_selected.bind(button.text))
		else:
			button.disabled = true
			button.tooltip_text = "Не куплено в магазине"

		_apply_selector_option_theme(button, false, not button.disabled)
		options.add_child(button)
		propeller_buttons.append(button)

	update_propeller_selection()

func _on_frame_selected(frame_name: String) -> void:
	if Global.is_component_available("frame", frame_name):
		current_frame_type = frame_name
		update_frame_selection()
		$UI/ComponentSelectors/FrameSelector/FrameOptionsContainer.visible = false
		add_frame()

func _on_board_selected(board_name: String) -> void:
	if Global.is_component_available("board", board_name):
		current_board_type = board_name
		update_board_selection()
		$UI/ComponentSelectors/BoardSelector/BoardOptionsContainer.visible = false
		add_board()

func _on_motor_selected(motor_name: String) -> void:
	if Global.is_component_available("motor", motor_name):
		current_motor_type = motor_name
		update_motor_selection()
		$UI/ComponentSelectors/MotorSelector/MotorOptionsContainer.visible = false
		add_motor()

func _on_propeller_selected(propeller_name: String) -> void:
	if Global.is_component_available("propeller", propeller_name):
		current_propeller_type = propeller_name
		update_propeller_selection()
		$UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer.visible = false
		add_propeller()

func update_frame_selection() -> void:
	var b: Button = $UI/ComponentSelectors/FrameSelector/FrameButton
	b.text = "Рамы: " + current_frame_type
	for bt in frame_buttons:
		_apply_selector_option_theme(bt, bt.text == current_frame_type, not bt.disabled)

func update_board_selection() -> void:
	var b: Button = $UI/ComponentSelectors/BoardSelector/BoardButton
	b.text = "Платы: " + current_board_type
	for bt in board_buttons:
		_apply_selector_option_theme(bt, bt.text == current_board_type, not bt.disabled)

func update_motor_selection() -> void:
	var b: Button = $UI/ComponentSelectors/MotorSelector/MotorButton
	b.text = "Двигатели: " + current_motor_type
	for bt in motor_buttons:
		_apply_selector_option_theme(bt, bt.text == current_motor_type, not bt.disabled)

func update_propeller_selection() -> void:
	var b: Button = $UI/ComponentSelectors/PropellerSelector/PropellerButton
	b.text = "Пропеллеры: " + current_propeller_type
	for bt in propeller_buttons:
		_apply_selector_option_theme(bt, bt.text == current_propeller_type, not bt.disabled)

# ==================== СОХРАНЕНИЕ / ЗАГРУЗКА + СКРИНШОТЫ ====================
func add_save_load_buttons() -> void:
	if $UI.has_node("SaveLoadContainer"):
		load_slots_info()
		return

	var save_load_container: HBoxContainer = HBoxContainer.new()
	save_load_container.name = "SaveLoadContainer"
	save_load_container.position = Vector2(1920 / 2 - 150, 0)
	save_load_container.size = Vector2(300, 50)

	var save_button: Button = Button.new()
	save_button.text = "💾 Сохранить"
	save_button.custom_minimum_size = Vector2(90, 40)
	save_button.pressed.connect(show_save_menu)
	_apply_assembly_button_theme(save_button, Color(0.33, 0.23, 0.15, 0.97), Color(0.84, 0.65, 0.43, 0.95), 15)

	var load_button: Button = Button.new()
	load_button.text = "📂 Загрузить"
	load_button.custom_minimum_size = Vector2(90, 40)
	load_button.pressed.connect(show_load_menu)
	_apply_assembly_button_theme(load_button, Color(0.29, 0.20, 0.14, 0.97), Color(0.77, 0.59, 0.39, 0.92), 15)

	save_load_container.add_child(save_button)
	save_load_container.add_child(load_button)

	$UI.add_child(save_load_container)
	load_slots_info()

func show_save_menu() -> void:
	if current_save_ui != null and is_instance_valid(current_save_ui):
		current_save_ui.queue_free()
	current_save_ui = create_slot_menu(true, "СОХРАНЕНИЕ ДРОНА")
	$UI.add_child(current_save_ui)

func show_load_menu() -> void:
	if current_save_ui != null and is_instance_valid(current_save_ui):
		current_save_ui.queue_free()
	current_save_ui = create_slot_menu(false, "ЗАГРУЗКА ДРОНА")
	$UI.add_child(current_save_ui)

func _build_current_drone_data() -> Dictionary:
	_normalize_motor_propeller_links(true)
	var drone_data: Dictionary = {
		"frame": get_component_data(drone_frame),
		"board": get_component_data(drone_board) if (drone_board != null and is_instance_valid(drone_board)) else null,
		"motors": [],
		"propellers": []
	}

	for m in motors:
		var motor: Node3D = m as Node3D
		if motor != null and is_instance_valid(motor):
			drone_data["motors"].append(get_component_data(motor))

	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop != null and is_instance_valid(prop):
			drone_data["propellers"].append(get_component_data(prop))

	return drone_data

func _read_drone_data_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_string)
	if parse_result != OK:
		return {}

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	var drone_data: Dictionary = data
	return drone_data

func _save_assembly_autosave() -> void:
	if _assembly_autosave_suspended or is_dragging_component:
		return

	var file: FileAccess = FileAccess.open(ASSEMBLY_AUTOSAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(_build_current_drone_data()))
	file.close()

func _apply_loaded_drone_data(drone_data: Dictionary) -> void:
	_assembly_autosave_suspended = true
	create_drone_from_data(drone_data)
	_assembly_autosave_suspended = false
	_update_cosmetic_tags()
	_apply_current_customization_to_assembly()
	update_camera_position()

func _load_assembly_autosave() -> bool:
	var drone_data: Dictionary = _read_drone_data_file(ASSEMBLY_AUTOSAVE_PATH)
	if drone_data.is_empty():
		return false

	_apply_loaded_drone_data(drone_data)
	return true

func _restore_assembly_session() -> void:
	_load_assembly_autosave()

func _slot_json_path(slot_index: int) -> String:
	return "user://drone_slot_%d.json" % slot_index

func _slot_thumb_path(slot_index: int) -> String:
	return "user://drone_slot_%d.png" % slot_index

func _load_slot_thumbnail(slot_index: int) -> Texture2D:
	var path: String = _slot_thumb_path(slot_index)
	if not FileAccess.file_exists(path):
		return null

	var img: Image = Image.new()
	var err: int = img.load(path)
	if err != OK:
		return null

	var tex: ImageTexture = ImageTexture.new()
	tex.set_image(img)
	return tex

func _save_slot_thumbnail(slot_index: int) -> void:
	# Снимок превью слота: прячем UI и делаем capture ПОСЛЕ рендера кадра.
	# Иначе получится "скриншот меню поверх меню" (рекурсия), как у тебя на скрине.
	_thumb_capture_state.clear()

	var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	var hud_layer: CanvasLayer = get_node_or_null("EngineerHUD") as CanvasLayer
	var top_layer: CanvasLayer = get_node_or_null("TopUiLayer") as CanvasLayer

	_thumb_capture_state = {
		"slot_index": slot_index,
		"ui_layer": ui_layer,
		"hud_layer": hud_layer,
		"top_layer": top_layer,
		"ui_visible": (ui_layer.visible if ui_layer != null else true),
		"hud_visible": (hud_layer.visible if hud_layer != null else true),
		"top_visible": (top_layer.visible if top_layer != null else true)
	}

	if ui_layer != null:
		ui_layer.visible = false
	if hud_layer != null:
		hud_layer.visible = false
	if top_layer != null:
		top_layer.visible = false

	# Ждём, пока отрендерится кадр без UI, и только потом берём изображение.
	var cb: Callable = Callable(self, "_on_thumb_frame_post_draw")
	if RenderingServer.frame_post_draw.is_connected(cb):
		RenderingServer.frame_post_draw.disconnect(cb)
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)


func _on_thumb_frame_post_draw() -> void:
	if _thumb_capture_state.is_empty():
		return

	var slot_index: int = int(_thumb_capture_state.get("slot_index", -1))

	# Берём картинку уже после рендера кадра
	var img: Image = null
	var vp_tex: Texture2D = get_viewport().get_texture()
	if vp_tex != null:
		img = vp_tex.get_image()

	# Возвращаем видимость UI обратно (ВАЖНО: делаем это даже если img == null)
	var ui_layer: CanvasLayer = _thumb_capture_state.get("ui_layer") as CanvasLayer
	var hud_layer: CanvasLayer = _thumb_capture_state.get("hud_layer") as CanvasLayer
	var top_layer: CanvasLayer = _thumb_capture_state.get("top_layer") as CanvasLayer

	if ui_layer != null:
		ui_layer.visible = bool(_thumb_capture_state.get("ui_visible", true))
	if hud_layer != null:
		hud_layer.visible = bool(_thumb_capture_state.get("hud_visible", true))
	if top_layer != null:
		top_layer.visible = bool(_thumb_capture_state.get("top_visible", true))

	_thumb_capture_state.clear()

	if img == null or slot_index < 0:
		return


	var w: int = img.get_width()
	var h: int = img.get_height()
	var crop_width: int = mini(w, 820)
	var crop_height: int = mini(h, int(round(float(crop_width) * 0.68)))
	var x: int = maxi(0, int(round((w - crop_width) * 0.5)))
	var preferred_center_y: int = int(round(h * 0.44))
	var y: int = clampi(preferred_center_y - int(round(crop_height * 0.5)), 0, maxi(h - crop_height, 0))

	var region: Image = img.get_region(Rect2i(x, y, crop_width, crop_height))
	region.resize(320, 220, Image.INTERPOLATE_BILINEAR)
	region.save_png(_slot_thumb_path(slot_index))

func load_slots_info() -> void:
	for i in range(3):
		# По умолчанию слот считаем пустым
		save_slots[i] = null

		var file_path: String = _slot_json_path(i)
		if not FileAccess.file_exists(file_path):
			continue

		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue

		var json_string: String = file.get_as_text()
		file.close()

		# Если файл пустой — считаем слот пустым
		if json_string.strip_edges().is_empty():
			continue

		var json: JSON = JSON.new()
		var parse_result: int = json.parse(json_string)
		if parse_result != OK:
			continue

		var data_v: Variant = json.get_data()
		if typeof(data_v) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = data_v

		# frame может быть null -> берём Variant и проверяем тип
		var frame_type: String = "Неизвестно"
		var frame_v: Variant = d.get("frame")
		if typeof(frame_v) == TYPE_DICTIONARY:
			frame_type = str((frame_v as Dictionary).get("component_type", "Неизвестно"))

		# motors может быть null -> проверяем тип
		var motors_count: int = 0
		var motors_v: Variant = d.get("motors")
		if typeof(motors_v) == TYPE_ARRAY:
			motors_count = (motors_v as Array).size()

		# board может быть null
		var has_board: bool = false
		var board_v: Variant = d.get("board")
		has_board = (board_v != null and typeof(board_v) == TYPE_DICTIONARY)

		save_slots[i] = {
			"frame": frame_type,
			"motors_count": motors_count,
			"has_board": has_board
		}

func create_slot_menu(is_save_mode: bool, title: String) -> Panel:
	var menu_panel: Panel = Panel.new()
	menu_panel.name = "SlotMenu"
	menu_panel.size = Vector2(980, 540)

	var viewport_size: Vector2 = Vector2(get_viewport().size)
	menu_panel.position = (viewport_size - menu_panel.size) / 2.0
	menu_panel.z_index = 100

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.10, 0.07, 0.96)
	style.border_color = Color(0.80, 0.61, 0.39, 0.90)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 18
	menu_panel.add_theme_stylebox_override("panel", style)

	var container: VBoxContainer = VBoxContainer.new()
	container.size = menu_panel.size
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	title_label.custom_minimum_size = Vector2(0, 76)

	var slots_container: HBoxContainer = HBoxContainer.new()
	slots_container.custom_minimum_size = Vector2(910, 340)
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.add_theme_constant_override("separation", 22)

	for slot_index in range(3):
		var slot_button: Button = create_slot_button(slot_index, is_save_mode)
		slots_container.add_child(slot_button)

	var close_button: Button = Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size = Vector2(220, 56)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(menu_panel.queue_free)
	_apply_assembly_button_theme(close_button, Color(0.32, 0.22, 0.15, 0.97), Color(0.83, 0.64, 0.42, 0.95), 18)

	container.add_child(title_label)
	container.add_child(slots_container)
	container.add_child(close_button)

	menu_panel.add_child(container)
	return menu_panel

func create_slot_button(slot_index: int, is_save_mode: bool) -> Button:
	var slot_button: Button = Button.new()
	slot_button.name = "SlotButton_%d" % slot_index
	slot_button.custom_minimum_size = Vector2(280, 320)
	slot_button.add_theme_font_size_override("font_size", 15)

	var slot_data = save_slots[slot_index]
	var slot_text: String = "СЛОТ %d\n\n" % (slot_index + 1)

	if slot_data != null:
		slot_text += "✅ Сохранение:\n"
		slot_text += "Рама: %s\n" % str(slot_data["frame"])
		slot_text += "Двигатели: %d/4\n" % int(slot_data["motors_count"])
		slot_text += "Плата: %s\n" % ("✅" if bool(slot_data["has_board"]) else "❌")
		slot_text += "\n⚠️ Нажмите для ПЕРЕЗАПИСИ" if is_save_mode else "\n🎯 Нажмите для ЗАГРУЗКИ"
	else:
		slot_text += "📭 Пусто\n\n"
		slot_text += "💾 Нажмите для СОХРАНЕНИЯ" if is_save_mode else "❌ Нет сохранения"

	# Внутренний layout: превью + текст
	slot_button.text = ""

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_button.add_child(vbox)

	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(248, 176)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var thumb: Texture2D = _load_slot_thumbnail(slot_index)
	if thumb != null:
		tex_rect.texture = thumb

	var label: Label = Label.new()
	label.text = slot_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.84))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 16)

	vbox.add_child(tex_rect)
	vbox.add_child(label)

	var fill: Color = Color(0.24, 0.17, 0.12, 0.96)
	var border: Color = Color(0.67, 0.52, 0.35, 0.84)
	if slot_data != null and is_save_mode:
		fill = Color(0.43, 0.30, 0.18, 0.97)
		border = Color(0.88, 0.69, 0.45, 0.95)
	elif slot_data != null:
		fill = Color(0.33, 0.24, 0.16, 0.97)
		border = Color(0.77, 0.61, 0.40, 0.92)
	elif is_save_mode:
		fill = Color(0.28, 0.20, 0.14, 0.95)
		border = Color(0.70, 0.55, 0.36, 0.84)

	_apply_assembly_button_theme(slot_button, fill, border, 14)

	if is_save_mode or slot_data != null:
		slot_button.pressed.connect(_on_slot_button_pressed.bind(slot_index, is_save_mode))
	else:
		slot_button.disabled = true

	return slot_button

func _on_slot_button_pressed(slot_index: int, is_save_mode: bool) -> void:
	if is_save_mode:
		save_drone_to_slot(slot_index)
	else:
		load_drone_from_slot(slot_index)

	if current_save_ui != null and is_instance_valid(current_save_ui):
		current_save_ui.queue_free()

	show_slot_action_message(slot_index, is_save_mode)

func save_drone_to_slot(slot_index: int) -> void:
	var drone_data: Dictionary = _build_current_drone_data()

	var file: FileAccess = FileAccess.open(_slot_json_path(slot_index), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(drone_data))
		file.close()

	_save_slot_thumbnail(slot_index)

	save_slots[slot_index] = {
		"frame": current_frame_type,
		"motors_count": motors.size(),
		"has_board": drone_board != null
	}

	_tut_notify("saved")

func load_drone_from_slot(slot_index: int) -> void:
	var data: Dictionary = _read_drone_data_file(_slot_json_path(slot_index))
	if data.is_empty():
		return

	_apply_loaded_drone_data(data)

	_tut_notify("loaded")
func get_component_data(component: Node3D) -> Variant:
	if component == null or not is_instance_valid(component):
		return null

	var components_root: Node3D = $Components as Node3D
	var component_type: String = ""
	if component == drone_frame:
		component_type = current_frame_type
	elif component == drone_board:
		component_type = current_board_type
	elif motors.has(component):
		component_type = current_motor_type
		if component.has_meta("component_type"):
			component_type = str(component.get_meta("component_type"))
	elif propellers.has(component):
		component_type = current_propeller_type
		if component.has_meta("component_type"):
			component_type = str(component.get_meta("component_type"))

	var comp_name: String = component_type
	if component.has_method("get_component_name"):
		comp_name = str(component.call("get_component_name"))

	var stored_position: Vector3 = component.position
	if components_root != null:
		stored_position = components_root.to_local(component.global_position)

	var stored_slot: int = -1
	if motors.has(component):
		stored_slot = _resolve_component_slot(component, motors.find(component))
	elif propellers.has(component):
		stored_slot = _resolve_component_slot(component, propellers.find(component))

	var attached_motor_slot: int = -1
	if propellers.has(component):
		var mapped_motor: Node3D = _find_mapped_motor_for_propeller(component)
		if mapped_motor != null and is_instance_valid(mapped_motor):
			attached_motor_slot = _get_motor_slot_index(mapped_motor)
		elif component.get_parent() is Node3D and motors.has(component.get_parent()):
			attached_motor_slot = _get_motor_slot_index(component.get_parent() as Node3D)

	return {
		"component_type": component_type,
		"component_name": comp_name,
		"position": {"x": stored_position.x, "y": stored_position.y, "z": stored_position.z},
		"rotation": {"x": component.rotation.x, "y": component.rotation.y, "z": component.rotation.z},
		"slot": stored_slot,
		"attached_motor_slot": attached_motor_slot
	}

func create_drone_from_data(drone_data: Dictionary) -> void:
	clear_drone()

	if drone_data.has("frame") and drone_data["frame"] != null:
		add_frame_from_data(drone_data["frame"])
	if drone_data.has("board") and drone_data["board"] != null:
		add_board_from_data(drone_data["board"])
	if drone_data.has("motors"):
		for motor_data in drone_data["motors"]:
			add_motor_from_data(motor_data)
	if drone_data.has("propellers"):
		for prop_data in drone_data["propellers"]:
			add_propeller_from_data(prop_data)

	_restore_loaded_motor_propeller_links()
	_normalize_motor_propeller_links(true)
	calculate_drone_stats()
	update_component_list()
	_save_assembly_autosave()

func _find_motor_by_slot(slot: int) -> Node3D:
	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		if _get_motor_slot_index(motor) == slot:
			return motor
	return null

func _restore_loaded_motor_propeller_links() -> void:
	var components_root: Node3D = $Components as Node3D
	motor_propeller_map.clear()

	for motor_variant in motors:
		var motor: Node3D = motor_variant as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var motor_slot: int = _get_motor_slot_index(motor)
		if motor_slot < 0 and components_root != null:
			var motor_local: Vector3 = components_root.to_local(motor.global_position)
			motor_slot = _get_motor_slot_from_local_pos(motor_local)
			motor.set_meta("motor_slot", motor_slot)
			_apply_motor_slot_recursive(motor, motor_slot)

	for prop_variant in propellers:
		var propeller: Node3D = prop_variant as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue
		var target_slot: int = -1
		if propeller.has_meta("attached_motor_slot"):
			target_slot = int(propeller.get_meta("attached_motor_slot"))
		elif propeller.has_meta("motor_slot"):
			target_slot = int(propeller.get_meta("motor_slot"))
		if target_slot < 0:
			var nearest_motor: Node3D = _find_nearest_motor(propeller, motors)
			if nearest_motor != null and is_instance_valid(nearest_motor):
				target_slot = _get_motor_slot_index(nearest_motor)

		var target_motor: Node3D = _find_motor_by_slot(target_slot)
		if target_motor != null:
			_attach_propeller_to_motor_clean(propeller, target_motor)
		else:
			_snap_propeller_to_motor_clean(propeller)

func add_frame_from_data(frame_data: Dictionary) -> void:
	var frame_type: String = str(frame_data.get("component_type", "Рама1"))
	var prefab: PackedScene = frame_prefabs.get(frame_type, null)
	if prefab == null:
		return

	var new_frame: Node3D = prefab.instantiate() as Node3D
	$Components.add_child(new_frame)

	new_frame.position = Vector3(frame_data["position"]["x"], frame_data["position"]["y"], frame_data["position"]["z"])
	new_frame.rotation = Vector3(frame_data["rotation"]["x"], frame_data["rotation"]["y"], frame_data["rotation"]["z"])

	drone_frame = new_frame
	_tag_component_for_customization(new_frame, "frame")
	current_frame_type = frame_type
	update_frame_selection()
	_apply_current_customization_to_assembly()

func add_board_from_data(board_data: Dictionary) -> void:
	var board_type: String = str(board_data.get("component_type", "Плата1"))
	var prefab: PackedScene = board_prefabs.get(board_type, null)
	if prefab == null:
		return

	var new_board: Node3D = prefab.instantiate() as Node3D
	$Components.add_child(new_board)

	new_board.position = Vector3(board_data["position"]["x"], board_data["position"]["y"], board_data["position"]["z"])
	new_board.rotation = Vector3(board_data["rotation"]["x"], board_data["rotation"]["y"], board_data["rotation"]["z"])

	drone_board = new_board
	_tag_component_for_customization(new_board, "board")
	current_board_type = board_type
	update_board_selection()
	_apply_current_customization_to_assembly()

func add_motor_from_data(motor_data: Dictionary) -> void:
	var motor_type: String = str(motor_data.get("component_type", "Мотор1"))
	var prefab: PackedScene = motor_prefabs.get(motor_type, null)
	if prefab == null:
		return

	var new_motor: Node3D = prefab.instantiate() as Node3D
	$Components.add_child(new_motor)

	new_motor.position = Vector3(motor_data["position"]["x"], motor_data["position"]["y"], motor_data["position"]["z"])
	new_motor.rotation = Vector3(motor_data["rotation"]["x"], motor_data["rotation"]["y"], motor_data["rotation"]["z"])
	new_motor.set_meta("component_type", motor_type)
	if motor_data.has("slot"):
		var motor_slot: int = clampi(int(motor_data.get("slot", -1)), 0, 3)
		new_motor.set_meta("motor_slot", motor_slot)
		_apply_motor_slot_recursive(new_motor, motor_slot)

	motors.append(new_motor)
	_update_cosmetic_tags()

	if motors.size() == 1:
		current_motor_type = motor_type
		update_motor_selection()
	_apply_current_customization_to_assembly()

func add_propeller_from_data(prop_data: Dictionary) -> void:
	var prop_type: String = str(prop_data.get("component_type", "Пропеллер1"))
	var prefab: PackedScene = propeller_prefabs.get(prop_type, null)
	if prefab == null:
		return

	var new_prop: Node3D = prefab.instantiate() as Node3D
	$Components.add_child(new_prop)

	new_prop.position = Vector3(prop_data["position"]["x"], prop_data["position"]["y"], prop_data["position"]["z"])
	new_prop.rotation = Vector3(prop_data["rotation"]["x"], prop_data["rotation"]["y"], prop_data["rotation"]["z"])
	new_prop.set_meta("component_type", prop_type)
	new_prop.set_meta("is_drone_propeller", true)
	if not new_prop.is_in_group("drone_propellers"):
		new_prop.add_to_group("drone_propellers")
	if prop_data.has("slot"):
		var prop_slot: int = clampi(int(prop_data.get("slot", -1)), 0, 3)
		new_prop.set_meta("motor_slot", prop_slot)
		_apply_motor_slot_recursive(new_prop, prop_slot)
	if prop_data.has("attached_motor_slot"):
		new_prop.set_meta("attached_motor_slot", int(prop_data.get("attached_motor_slot", -1)))

	propellers.append(new_prop)
	_update_cosmetic_tags()

	if propellers.size() == 1:
		current_propeller_type = prop_type
		update_propeller_selection()
	_apply_current_customization_to_assembly()

func show_slot_action_message(slot_index: int, is_save_mode: bool) -> void:
	var accent: Color = Color(0.77, 0.61, 0.40, 0.92) if is_save_mode else Color(0.86, 0.70, 0.46, 0.92)
	var title: String = "Слот %d обновлен" % (slot_index + 1)
	var body: String = "Сборка %s в слот %d." % ["сохранена" if is_save_mode else "загружена", slot_index + 1]
	_show_assembly_notice(title, body, accent, 2.0)
	return
	var message_panel: Panel = Panel.new()
	message_panel.name = "SlotActionMessage"
	message_panel.size = Vector2(400, 150)

	var viewport_size: Vector2 = Vector2(get_viewport().size)
	message_panel.position = (viewport_size - message_panel.size) / 2.0
	message_panel.z_index = 101

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.7, 0.3, 0.9) if is_save_mode else Color(0.1, 0.5, 0.9, 0.9)
	style.border_color = Color(1, 1, 1, 0.8)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	message_panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "✅ %s В СЛОТЕ %d!" % ["СОХРАНЕНО" if is_save_mode else "ЗАГРУЖЕНО", slot_index + 1]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size = message_panel.size

	message_panel.add_child(label)
	$UI.add_child(message_panel)

	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(_queue_free_safe.bind(message_panel))

func _queue_free_safe(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()

func _show_assembly_notice(title: String, body: String, accent: Color, duration: float) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 102

	var panel := Panel.new()
	panel.size = Vector2(460, 196)
	panel.position = (Vector2(get_viewport().size) - panel.size) * 0.5
	panel.add_theme_stylebox_override("panel", _build_assembly_panel_style(
		Color(0.17, 0.12, 0.08, 0.95),
		accent,
		24
	))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	content.add_child(title_label)

	var separator := HSeparator.new()
	content.add_child(separator)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.73))
	content.add_child(body_label)

	canvas.add_child(panel)
	add_child(canvas)

	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(_queue_free_safe.bind(canvas))

func ensure_slots_marked_for_export() -> void:
	var components_3d: Node3D = $Components as Node3D
	if components_3d == null:
		return

	# Собираем валидные моторы
	var motor_nodes: Array = []
	for m in motors:
		var mot: Node3D = m as Node3D
		if mot != null and is_instance_valid(mot):
			motor_nodes.append(mot)

	# 1) Моторы: назначаем уникальные слоты по реальным позициям
	var motor_id_to_slot: Dictionary = _assign_motor_slots_stable(components_3d, motor_nodes)

	for mot_node in motor_nodes:
		var mot3d: Node3D = mot_node as Node3D
		if mot3d == null or not is_instance_valid(mot3d):
			continue
		var id: int = int(mot3d.get_instance_id()) # ✅ явный тип
		if motor_id_to_slot.has(id):
			mot3d.set_meta("motor_slot", int(motor_id_to_slot[id]))

	# 2) Пропеллеры: слот берём у мотора, к которому они привязаны (motor_propeller_map),
	# а если связи нет — ищем ближайший мотор
	for p in propellers:
		var prop: Node3D = p as Node3D
		if prop == null or not is_instance_valid(prop):
			continue

		var slot: int = -1

		# (a) связь из motor_propeller_map
		var owner_motor: Node3D = null
		for k in motor_propeller_map.keys():
			var motk: Node3D = k as Node3D
			if motk != null and is_instance_valid(motk) and motor_propeller_map[motk] == prop:
				owner_motor = motk
				break

		# (b) если связи нет — ближайший мотор
		if owner_motor == null:
			owner_motor = _find_nearest_motor(prop, motor_nodes)

		if owner_motor != null and owner_motor.has_meta("motor_slot"):
			slot = int(owner_motor.get_meta("motor_slot"))

		if slot >= 0:
			_apply_motor_slot_recursive(prop, slot)

		prop.set_meta("is_drone_propeller", true)
		if not prop.is_in_group("drone_propellers"):
			prop.add_to_group("drone_propellers")
# ==================== ЭКСПОРТ ДРОНА ====================
func _export_drone_on_scene_exit() -> void:
	if is_dragging_component:
		stop_component_dragging()
	else:
		_save_assembly_autosave()
	_suppress_export_popup = true
	export_drone_scene()
	_suppress_export_popup = false


func _on_customization_pressed() -> void:
	_export_drone_on_scene_exit()
	get_tree().change_scene_to_file(CUSTOMIZATION_SCENE_PATH)

func _tag_component_for_customization(component: Node3D, part_id: String) -> void:
	if component == null or not is_instance_valid(component):
		return
	component.set_meta("cosmetic_part_root", part_id)

func _update_cosmetic_tags() -> void:
	if drone_frame != null and is_instance_valid(drone_frame):
		_tag_component_for_customization(drone_frame, "frame")
	if drone_board != null and is_instance_valid(drone_board):
		_tag_component_for_customization(drone_board, "board")

	for motor_index in range(motors.size()):
		var motor: Node3D = motors[motor_index] as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var motor_slot: int = _resolve_component_slot(motor, motor_index)
		_tag_component_for_customization(motor, "motor_%d" % motor_slot)

	for prop_index in range(propellers.size()):
		var propeller: Node3D = propellers[prop_index] as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue
		var prop_slot: int = _resolve_component_slot(propeller, prop_index)
		_tag_component_for_customization(propeller, "propeller_%d" % prop_slot)

func _apply_current_customization_to_assembly() -> void:
	_update_cosmetic_tags()
	if Global == null:
		return
	var components_root: Node = get_node_or_null("Components")
	if components_root != null:
		Global.apply_customization_to_drone_root(components_root)

func export_drone_scene() -> bool:
	_components_center_valid = false
	if is_dragging_component:
		stop_component_dragging()
	_normalize_motor_propeller_links(true)
	calculate_drone_stats()
	ensure_propellers_marked()
	_update_cosmetic_tags()
	
	ensure_slots_marked_for_export()
	
	var physics_data: Dictionary = calculate_physics_data()
	physics_data["total_mass"] = float(drone_stats.get("total_mass", 0.0))
	physics_data["total_thrust"] = float(drone_stats.get("total_thrust", 0.0))
	physics_data["is_balanced"] = bool(drone_stats.get("is_balanced", false))

	var drone_root: CharacterBody3D = CharacterBody3D.new()
	drone_root.name = "ExportedDrone"

	var drone_script: Script = load("res://app/flight/Drone.gd")
	if drone_script != null:
		drone_root.set_script(drone_script)

	copy_components_to_drone(drone_root)
	if Global != null:
		Global.apply_customization_to_drone_root(drone_root)

	# ✅ Гарантируем коллизию (иначе в уровне будет 'нет коллизии')
	if drone_root.find_child("CollisionShape3D", true, false) == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 4.0, 8.0)
		cs.shape = box
		cs.position = Vector3(0.0, 2.0, 0.0)
		drone_root.add_child(cs)
		_set_owner_recursive(cs, drone_root)

	drone_root.set_meta("drone_physics", physics_data)

	var drone_info: Dictionary = {
		"frame_type": current_frame_type,
		"board_type": current_board_type,
		"motor_type": current_motor_type,
		"propeller_type": current_propeller_type,
		"frame_present": drone_frame != null and is_instance_valid(drone_frame),
		"board_present": drone_board != null and is_instance_valid(drone_board),
		"motor_count": motors.size(),
		"propeller_count": propellers.size(),
		"motor_slots": [],
		"propeller_slots": [],
		"recommended_motor_pins": Global.get_recommended_motor_pins(),
		"physics": physics_data,
		"is_balanced": bool(drone_stats.get("is_balanced", false)),
		"motors": [],
		"propellers": []
	}

	for motor in motors:
		if is_instance_valid(motor):
			var motor_node: Node3D = motor as Node3D
			var motor_slot: int = _resolve_component_slot(motor_node, drone_info["motors"].size())
			var motor_type: String = current_motor_type
			if motor_node != null and motor_node.has_meta("component_type"):
				motor_type = str(motor_node.get_meta("component_type"))
			drone_info["motors"].append({
				"position": motor.global_position,
				"rotation": motor.rotation,
				"type": motor_type,
				"slot": motor_slot,
				"slot_name": _slot_name_from_index(motor_slot),
				"recommended_pin": _recommended_pin_for_slot(motor_slot)
			})
			if motor_slot not in drone_info["motor_slots"]:
				drone_info["motor_slots"].append(motor_slot)

	for propeller in propellers:
		if is_instance_valid(propeller):
			var prop_node: Node3D = propeller as Node3D
			var prop_slot: int = _resolve_component_slot(prop_node, drone_info["propellers"].size())
			var prop_type: String = current_propeller_type
			if prop_node != null and prop_node.has_meta("component_type"):
				prop_type = str(prop_node.get_meta("component_type"))
			drone_info["propellers"].append({
				"position": propeller.global_position,
				"rotation": propeller.rotation,
				"type": prop_type,
				"slot": prop_slot,
				"slot_name": _slot_name_from_index(prop_slot)
			})
			if prop_slot not in drone_info["propeller_slots"]:
				drone_info["propeller_slots"].append(prop_slot)

	drone_info["motor_count"] = int((drone_info["motors"] as Array).size())
	drone_info["propeller_count"] = int((drone_info["propellers"] as Array).size())

	(drone_info["motor_slots"] as Array).sort()
	(drone_info["propeller_slots"] as Array).sort()

	drone_root.set_meta("drone_info", drone_info)
	Global.save_exported_drone_profile(drone_info)
	var current_wiring := Global.load_arduino_wiring()
	if not current_wiring.is_empty() and str(current_wiring.get("drone_signature", "")) != Global.get_drone_signature(drone_info):
		Global.clear_arduino_wiring()

	var packed_scene: PackedScene = PackedScene.new()
	print("🧱 EXPORT DEBUG: Components tree:")
	_debug_dump_tree($Components)
	print("🧱 EXPORT DEBUG: propellers array (size=", propellers.size(), "):")
	_debug_dump_list(propellers)
	var result: int = packed_scene.pack(drone_root)

	if result == OK:
		ResourceSaver.save(packed_scene, "user://exported_drone.tscn")
		ResourceSaver.save(packed_scene, "res://exported_drone.tscn")

		print("✅ Дрон экспортирован!")
		print("   - Тип ноды: ", drone_root.get_class())
		print("   - Моторов: ", motors.size())
		print("   - Пропеллеров: ", propellers.size())
		print("   - Детей: ", drone_root.get_child_count())

		if not _suppress_export_popup:
			show_export_success_message()
		_tut_notify("exported")
		return true

	print("❌ Ошибка при упаковке сцены дрона")
	return false

func get_components_center_local() -> Vector3:
	# Возвращает центр (AABB) всех Node3D внутри $Components в ЛОКАЛЬНЫХ координатах $Components.
	# Используется только для «центрирования» экспортируемой модели, чтобы оси в уровнях не «плыли».
	var components_3d: Node3D = $Components as Node3D
	if components_3d == null:
		return Vector3.ZERO

	var nodes: Array = []
	_collect_node3d_recursive(components_3d, nodes)

	var has_any := false
	var min_x := 0.0
	var min_y := 0.0
	var min_z := 0.0
	var max_x := 0.0
	var max_y := 0.0
	var max_z := 0.0

	for n in nodes:
		if n == components_3d:
			continue
		if not (n is Node3D):
			continue

		var p: Vector3 = components_3d.to_local((n as Node3D).global_position)

		if not has_any:
			has_any = true
			min_x = p.x
			min_y = p.y
			min_z = p.z
			max_x = p.x
			max_y = p.y
			max_z = p.z
		else:
			min_x = minf(min_x, p.x)
			min_y = minf(min_y, p.y)
			min_z = minf(min_z, p.z)
			max_x = maxf(max_x, p.x)
			max_y = maxf(max_y, p.y)
			max_z = maxf(max_z, p.z)

	if not has_any:
		return Vector3.ZERO

	return Vector3((min_x + max_x) * 0.5, (min_y + max_y) * 0.5, (min_z + max_z) * 0.5)


func _collect_node3d_recursive(root: Node, out: Array) -> void:
	if root == null:
		return
	out.append(root)
	for c in root.get_children():
		_collect_node3d_recursive(c, out)

func copy_components_to_drone(drone_root: CharacterBody3D) -> void:
	# ВАЖНО:
	# Раньше мы копировали только детей $Components. Если у $Components был сдвиг/поворот,
	# то при экспорте эти трансформации терялись, и в уровнях могли «поплыть» оси моторов/пропеллеров.
	# Это напрямую ломает расчёт центра тяги и визуально даёт «кривой» дрейф.
	# Теперь мы «запекаем» transform $Components в каждый скопированный узел + центрируем модель.
	var components_3d: Node3D = $Components as Node3D
	if components_3d == null:
		return

	# Центр экспорта должен быть СТАБИЛЬНЫМ.
	# Если центрировать по AABB всех деталей, то при недосборке (например 3 мотора)
	# ноль смещается и «слабая сторона» может перевернуться.
	# Поэтому якорим 0,0,0 на раму (pivot рамы).
	var center_local: Vector3 = Vector3.ZERO
	if drone_frame != null and is_instance_valid(drone_frame):
		center_local = components_3d.to_local(drone_frame.global_position)
	else:
		center_local = get_components_center_local() # фоллбек, если рамы нет

	# Базовый трансформ, который применим к каждому ребёнку, чтобы сохранить ориентацию $Components
	var base_t: Transform3D = components_3d.transform
	base_t.origin -= base_t.basis * center_local

	# 1) Копируем дерево компонентов
	for child in components_3d.get_children():
		var node: Node = child as Node
		if node == null or not is_instance_valid(node):
			continue

		var child_copy: Node = node.duplicate()
		drone_root.add_child(child_copy)

		# Запекаем transform $Components (поворот/смещение) в transform ребёнка
		if child_copy is Node3D and node is Node3D:
			(child_copy as Node3D).transform = base_t * (node as Node3D).transform

		_set_owner_recursive(child_copy, drone_root)
	# 2) Помечаем пропеллеры уже в скопированном дереве
	for i in range(propellers.size()):
		var propeller: Node3D = propellers[i] as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue

		var dc: Node = drone_root.find_child(propeller.name, true, false)
		if dc == null:
			continue

		# Метки
		dc.set_meta("is_drone_propeller", true)
		dc.set_meta("propeller_index", i)
		dc.set_meta("propeller_type", current_propeller_type)

		# ❗ ВАЖНО: motor_slot берём с ОРИГИНАЛА, а НЕ из имени Propeller_0/1/2/3
		var slot: int = -1
		if propeller.has_meta("motor_slot"):
			slot = int(propeller.get_meta("motor_slot"))

		# Фоллбек: если почему-то у оригинала нет слота — вычислим по ближайшему мотору
		if slot < 0:
			var best_d: float = INF
			var best_motor: Node3D = null
			for m in motors:
				var mot: Node3D = m as Node3D
				if mot == null or not is_instance_valid(mot):
					continue
				var d: float = propeller.global_position.distance_to(mot.global_position)
				if d < best_d:
					best_d = d
					best_motor = mot

			if best_motor != null:
				if best_motor.has_meta("motor_slot"):
					slot = int(best_motor.get_meta("motor_slot"))
				else:
					var local_motor_pos: Vector3 = components_3d.to_local(best_motor.global_position)
					slot = _get_motor_slot_from_local_pos(local_motor_pos)
					best_motor.set_meta("motor_slot", slot)

		if slot >= 0:
			_apply_motor_slot_recursive(dc, slot)

		# Группа только на корень пропеллера (детям убираем)
		if not dc.is_in_group("drone_propellers"):
			dc.add_to_group("drone_propellers")
		_remove_group_from_descendants(dc, "drone_propellers")



func show_export_success_message() -> void:
	var summary: String = "Рама: %s\nМоторов: %d\nПропеллеров: %d\nЭкспорт готов для запуска уровня." % [
		current_frame_type,
		motors.size(),
		propellers.size()
	]
	_show_assembly_notice("Дрон экспортирован", summary, Color(0.86, 0.69, 0.44, 0.94), 4.0)
	return
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100

	var panel: Panel = Panel.new()
	panel.size = Vector2(500, 300)

	var viewport_size: Vector2 = Vector2(get_viewport().size)
	panel.position = (viewport_size - panel.size) / 2.0

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0, 1, 0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "✅ ДРОН УСПЕШНО ЭКСПОРТИРОВАН!\n\n"
	label.text += "Компоненты:\n"
	label.text += "• Рама: %s\n" % current_frame_type
	label.text += "• Моторов: %d\n" % motors.size()
	label.text += "• Пропеллеров: %d\n\n" % propellers.size()
	label.text += "Теперь можно запускать на уровне!"

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size
	label.add_theme_font_size_override("font_size", 16)

	panel.add_child(label)
	canvas.add_child(panel)
	add_child(canvas)

	var timer: SceneTreeTimer = get_tree().create_timer(4.0)
	timer.timeout.connect(_queue_free_safe.bind(canvas))

func ensure_propellers_marked() -> void:
	for i in range(propellers.size()):
		var propeller: Node3D = propellers[i]
		if propeller == null or not is_instance_valid(propeller):
			continue

		if not propeller.name.begins_with("Propeller_"):
			propeller.name = "Propeller_" + str(i)

		propeller.set_meta("is_drone_propeller", true)
		propeller.set_meta("propeller_index", i)
		propeller.set_meta("propeller_type", current_propeller_type)

		# Проставляем слот пропеллера для физики (надежно, без угадываний в уровне)
		var slot: int = -1
		if propeller.has_meta("motor_slot"):
			slot = int(propeller.get_meta("motor_slot"))
		else:
			var parent_node: Node = propeller.get_parent()
			if parent_node is Node3D and motors.has(parent_node):
				slot = _get_motor_slot_index(parent_node as Node3D)
			elif drone_frame != null and is_instance_valid(drone_frame):
				var lp: Vector3 = drone_frame.to_local(propeller.global_position)
				slot = _get_motor_slot_from_local_pos(lp)

		if slot >= 0:
			propeller.set_meta("motor_slot", slot)
			_apply_motor_slot_recursive(propeller, slot)

		if not propeller.is_in_group("drone_propellers"):
			propeller.add_to_group("drone_propellers")

# ==================== ФИЗИКА ДЛЯ ЭКСПОРТА ====================
func calculate_physics_data() -> Dictionary:
	var total_mass: float = 0.0
	var center_of_mass: Vector3 = Vector3.ZERO
	var active_motors: int = 0
	var motor_positions: Array = []

	if drone_frame != null:
		total_mass += float(component_stats["frame"][current_frame_type]["mass"])
	if drone_board != null:
		total_mass += float(component_stats["board"][current_board_type]["mass"])

	for i in range(motors.size()):
		var motor: Node3D = motors[i]
		if motor == null or not is_instance_valid(motor):
			continue

		var motor_mass: float = float(component_stats["motor"][current_motor_type]["mass"])
		total_mass += motor_mass

		var motor_pos: Vector3 = Vector3.ZERO
		if i == 0:
			motor_pos = Vector3(0.5, 0, 0.5)
		elif i == 1:
			motor_pos = Vector3(-0.5, 0, 0.5)
		elif i == 2:
			motor_pos = Vector3(0.5, 0, -0.5)
		elif i == 3:
			motor_pos = Vector3(-0.5, 0, -0.5)

		var has_prop: bool = (i < propellers.size()) and (propellers[i] != null) and is_instance_valid(propellers[i])
		motor_positions.append({
			"position": motor_pos,
			"has_propeller": has_prop
		})

		if has_prop:
			active_motors += 1
			total_mass += float(component_stats["propeller"][current_propeller_type]["mass"])

	var stability: float = 1.0
	if motors.size() < 4:
		stability *= 0.7
	if propellers.size() < 4:
		stability *= 0.8
	if active_motors < 4:
		stability *= float(active_motors) / 4.0

	var imbalance: Vector3 = Vector3.ZERO
	if active_motors > 0:
		var thrust_center: Vector3 = Vector3.ZERO
		for md in motor_positions:
			var d: Dictionary = md
			if bool(d["has_propeller"]):
				thrust_center += d["position"]
		thrust_center /= float(active_motors)
		imbalance = thrust_center

	return {
		"total_mass": total_mass,
		"center_of_mass": center_of_mass,
		"active_motors": active_motors,
		"stability": stability,
		"imbalance": imbalance,
		"frame_type": current_frame_type,
		"motor_count": motors.size(),
		"propeller_count": propellers.size()
	}

# ==================== ОКРУЖЕНИЕ / ГРИД / КОМНАТА ====================
func create_grid() -> void:
	# защита от дублей
	if $Grid.get_child_count() > 0:
		return

	for x in range(-5, 6):
		for z in range(-5, 6):
			var grid_cube: MeshInstance3D = MeshInstance3D.new()
			var cube_mesh: BoxMesh = BoxMesh.new()
			cube_mesh.size = Vector3(0.9, 0.1, 0.9)

			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

			grid_cube.mesh = cube_mesh
			grid_cube.material_override = material
			grid_cube.position = Vector3(x, 0, z)
			$Grid.add_child(grid_cube)

func create_floor_line() -> void:
	if has_node("FloorLine"):
		return

	var line_mesh: MeshInstance3D = MeshInstance3D.new()
	line_mesh.name = "FloorLine"

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 0.8)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(Vector3(-6, 0.02, 0))
	immediate_mesh.surface_add_vertex(Vector3(6, 0.02, 0))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.02, -6))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.02, 6))
	immediate_mesh.surface_end()

	line_mesh.mesh = immediate_mesh
	add_child(line_mesh)

func add_room() -> void:
	if has_node("GarageRoom"):
		return

	var room_scene: PackedScene = load("res://content/environments/room3d/garage_to_create_drone/garage.glb")
	if room_scene == null:
		return

	var room: Node3D = room_scene.instantiate() as Node3D
	add_child(room)
	room.position = Vector3(10, 0, 0)
	room.scale = Vector3(6, 6, 6)
	room.name = "GarageRoom"

func setup_lighting() -> void:
	if has_node("LightsContainer"):
		return

	var lights_container: Node3D = Node3D.new()
	lights_container.name = "LightsContainer"
	add_child(lights_container)

	var main_light: DirectionalLight3D = DirectionalLight3D.new()
	main_light.name = "MainLight"
	lights_container.add_child(main_light)
	main_light.light_color = Color(1, 0.9, 0.8)
	main_light.light_energy = 1.14
	main_light.rotation_degrees = Vector3(-56, 26, 0)
	main_light.shadow_enabled = true
	main_light.shadow_bias = 0.06
	main_light.shadow_normal_bias = 0.7
	main_light.shadow_blur = 0.15

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "FillLight"
	lights_container.add_child(fill_light)
	fill_light.position = Vector3(0, 4, 0)
	fill_light.light_color = Color(0.62, 0.48, 0.34)
	fill_light.light_energy = 0.22
	fill_light.omni_range = 14
	fill_light.shadow_enabled = false

	var key_spot: SpotLight3D = SpotLight3D.new()
	key_spot.name = "DroneKeySpot"
	lights_container.add_child(key_spot)
	key_spot.position = Vector3(-6, 8, 7)
	key_spot.look_at(Vector3(0, 1.4, 0), Vector3.UP)
	key_spot.light_color = Color(1.0, 0.82, 0.54)
	key_spot.light_energy = 1.50
	key_spot.spot_range = 24
	key_spot.spot_angle = 34
	key_spot.shadow_enabled = true
	key_spot.shadow_blur = 0.18
	key_spot.shadow_bias = 0.05
	key_spot.shadow_normal_bias = 0.65

func add_reflection_probe() -> void:
	if has_node("MainReflectionProbe"):
		return

	var probe: ReflectionProbe = ReflectionProbe.new()
	probe.name = "MainReflectionProbe"
	add_child(probe)
	probe.position = Vector3(0, 2, 0)
	probe.size = Vector3(20, 10, 20)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS

# ==================== НАСТРОЙКИ ====================
func load_settings_menu() -> void:
	if settings_menu != null and is_instance_valid(settings_menu):
		return

	var settings_scene: PackedScene = preload("res://app/ui/SettingsScene.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

	# сигналы (если существуют)
	if settings_menu.has_signal("settings_saved"):
		settings_menu.connect("settings_saved", Callable(self, "_on_settings_saved"))
	if settings_menu.has_signal("settings_cancelled"):
		settings_menu.connect("settings_cancelled", Callable(self, "_on_settings_cancelled"))
	if settings_menu.has_signal("settings_closed"):
		settings_menu.connect("settings_closed", Callable(self, "_on_settings_closed"))

func apply_global_settings() -> void:
	if not Global:
		return

	camera.fov = Global.camera_fov

	var env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env != null and env.environment != null:
		Global.apply_environment_graphics(env.environment)

	var lights_container := get_node_or_null("LightsContainer")
	if lights_container != null:
		for directional_variant in lights_container.find_children("*", "DirectionalLight3D", true, false):
			if directional_variant is DirectionalLight3D:
				Global.apply_directional_light_graphics(directional_variant)
		for omni_variant in lights_container.find_children("*", "OmniLight3D", true, false):
			if omni_variant is OmniLight3D:
				Global.apply_omni_light_graphics(omni_variant)

func _on_settings_saved() -> void:
	apply_global_settings()

func _on_settings_cancelled() -> void:
	apply_global_settings()

func _on_settings_closed() -> void:
	pass

func _slot_name_from_index(slot: int) -> String:
	match slot:
		0:
			return "Front right"
		1:
			return "Front left"
		2:
			return "Back right"
		3:
			return "Back left"
		_:
			return "Slot %d" % slot

func _recommended_pin_for_slot(slot: int) -> String:
	var pins := Global.get_recommended_motor_pins()
	if slot >= 0 and slot < pins.size():
		return pins[slot]
	return "D?"

func _get_motor_slot_from_local_pos(local_pos: Vector3) -> int:
	# 0 = front_right, 1 = front_left, 2 = back_right, 3 = back_left
	# Вперёд обычно -Z, назад +Z; право +X, лево -X

	var components_3d: Node3D = $Components as Node3D
	var center: Vector3 = _get_components_visual_center_local(components_3d)

	# Сдвигаем координаты в систему, где (0,0,0) = центр модели
	var p: Vector3 = local_pos - center

	var eps := 0.0001
	var x := p.x
	var z := p.z
	if abs(x) < eps: x = 0.0
	if abs(z) < eps: z = 0.0

	var is_front := (z <= 0.0)
	var is_right := (x >= 0.0)

	if is_front and is_right:
		return 0
	if is_front and not is_right:
		return 1
	if not is_front and is_right:
		return 2
	return 3
 
func _remove_group_recursive(n: Node, group_name: String, skip_self: bool = false) -> void:
	if not skip_self:
		if n.is_in_group(group_name):
			n.remove_from_group(group_name)
	for c in n.get_children():
		_remove_group_recursive(c, group_name, false)

func _set_owner_recursive(n: Node, owner_node: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	n.owner = owner_node
	for c in n.get_children():
		_set_owner_recursive(c, owner_node)

func _remove_group_from_descendants(root: Node, group_name: String) -> void:
	for c in root.get_children():
		if c != null and is_instance_valid(c):
			if c.is_in_group(group_name):
				c.remove_from_group(group_name)
			_remove_group_from_descendants(c, group_name)

func _apply_motor_slot_recursive(node: Node, slot: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_meta("motor_slot", slot)
	for c in node.get_children():
		_apply_motor_slot_recursive(c, slot)

func _create_main_menu_button_top() -> void:
	# Верхний слой, чтобы кнопку ничего не перекрывало
	var top_layer := get_node_or_null("TopUiLayer") as CanvasLayer
	if top_layer == null:
		top_layer = CanvasLayer.new()
		top_layer.name = "TopUiLayer"
		top_layer.layer = 200 # выше обычной UI
		add_child(top_layer)

	# Контейнер на весь экран (сам не блокирует мышь)
	var overlay := top_layer.get_node_or_null("Overlay") as Control
	if overlay == null:
		overlay = Control.new()
		overlay.name = "Overlay"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_layer.add_child(overlay)

	# Не создаём вторую кнопку
	if overlay.get_node_or_null("btn_main_menu") != null:
		return

	var btn := Button.new()
	btn.name = "btn_main_menu"
	btn.text = "В главное меню"
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# btn.z_index = 100  # можно не ставить
	btn.set_as_top_level(true) # чтобы не зависеть от родительских трансформов

	# Снизу слева
	btn.anchor_left = 0.0
	btn.anchor_right = 0.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 16.0
	btn.offset_right = 220.0
	btn.offset_top = -56.0
	btn.offset_bottom = -16.0

	overlay.add_child(btn)
	_apply_assembly_button_theme(btn, Color(0.28, 0.20, 0.14, 0.97), Color(0.76, 0.59, 0.39, 0.90), 15)
	btn.pressed.connect(_on_main_menu_button_pressed)


func _on_main_menu_button_pressed() -> void:
	_export_drone_on_scene_exit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _debug_dump_tree(root: Node, depth: int = 0) -> void:
	if root == null or not is_instance_valid(root):
		return

	var indent := ""
	for i in range(depth):
		indent += "  "

	var meta_slot = (root.get_meta("motor_slot") if root.has_meta("motor_slot") else "NONE")
	var is_prop = (root.get_meta("is_drone_propeller") if root.has_meta("is_drone_propeller") else "NONE")
	print(indent, "- ", root.name, " class=", root.get_class(), " groups=", root.get_groups(), " motor_slot=", meta_slot, " is_drone_propeller=", is_prop)

	for c in root.get_children():
		if c != null and is_instance_valid(c):
			_debug_dump_tree(c, depth + 1)


func _debug_dump_list(arr: Array) -> void:
	for n in arr:
		if n == null or not is_instance_valid(n):
			continue
		var meta_slot = (n.get_meta("motor_slot") if n.has_meta("motor_slot") else "NONE")
		var is_prop = (n.get_meta("is_drone_propeller") if n.has_meta("is_drone_propeller") else "NONE")
		print("  * ", n.name, " class=", n.get_class(), " path=", n.get_path(), " groups=", n.get_groups(), " motor_slot=", meta_slot, " is_drone_propeller=", is_prop)

func _get_components_visual_center_local(components_3d: Node3D) -> Vector3:
	if _components_center_valid:
		return _components_center_local

	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	var stack: Array = [components_3d]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null or not is_instance_valid(n):
			continue

		for c in n.get_children():
			if c != null and is_instance_valid(c):
				stack.append(c)

		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var aabb: AABB = mi.get_aabb()

			# Переводим 8 углов AABB меша в локальные координаты $Components
			var to_comp: Transform3D = components_3d.global_transform.affine_inverse() * mi.global_transform
			for i in range(8):
				var corner := aabb.position
				if (i & 1) != 0: corner.x += aabb.size.x
				if (i & 2) != 0: corner.y += aabb.size.y
				if (i & 4) != 0: corner.z += aabb.size.z

				var p: Vector3 = to_comp * corner
				min_v = Vector3(minf(min_v.x, p.x), minf(min_v.y, p.y), minf(min_v.z, p.z))
				max_v = Vector3(maxf(max_v.x, p.x), maxf(max_v.y, p.y), maxf(max_v.z, p.z))

	# Если мешей нет — центр нулевой
	if min_v.x == INF:
		_components_center_local = Vector3.ZERO
	else:
		_components_center_local = (min_v + max_v) * 0.5

	_components_center_valid = true
	return _components_center_local

func _find_nearest_motor(prop: Node3D, motor_nodes: Array) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for mot in motor_nodes:
		var m: Node3D = mot as Node3D
		if m == null or not is_instance_valid(m):
			continue
		var d: float = prop.global_position.distance_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


func _assign_motor_slots_stable(components_3d: Node3D, motor_nodes: Array) -> Dictionary:
	# Возвращает: { motor_instance_id(int) : slot(int 0..3) }
	var locals: Dictionary = {} # int -> Vector3
	var xs: Array = []
	var zs: Array = []

	for mot in motor_nodes:
		var m: Node3D = mot as Node3D
		if m == null or not is_instance_valid(m):
			continue
		var id: int = int(m.get_instance_id())
		var lp: Vector3 = components_3d.to_local(m.global_position)
		locals[id] = lp
		xs.append(lp.x)
		zs.append(lp.z)

	if locals.size() == 0:
		return {}

	# экстенты
	var min_x: float = float(xs[0])
	var max_x: float = float(xs[0])
	for x in xs:
		min_x = minf(min_x, float(x))
		max_x = maxf(max_x, float(x))

	var min_z: float = float(zs[0])
	var max_z: float = float(zs[0])
	for z in zs:
		min_z = minf(min_z, float(z))
		max_z = maxf(max_z, float(z))

	# 0 = front_right, 1 = front_left, 2 = back_right, 3 = back_left
	var targets := {
		0: Vector3(max_x, 0.0, min_z),
		1: Vector3(min_x, 0.0, min_z),
		2: Vector3(max_x, 0.0, max_z),
		3: Vector3(min_x, 0.0, max_z)
	}

	var ids: Array = locals.keys() # keys будут Variant, ниже приводим к int
	var n: int = ids.size()

	var slots_all := [0, 1, 2, 3]
	var best_cost: float = INF
	var best_assign: Dictionary = {}

	# перебор всех перестановок слотов длины n
	_perm_slots(ids, locals, targets, 0, [], slots_all, best_assign, best_cost)

	return best_assign


func _solve_slot_assignment(ids: Array, locals: Dictionary, targets: Dictionary, idx: int, used: Array, current: Dictionary, cost: float, best_assign: Dictionary, best_cost: float) -> void:
	# ids: массив instance_id моторов
	if idx >= ids.size():
		if cost < best_cost:
			# обновляем best_assign/best_cost
			best_assign.clear()
			for k in current.keys():
				best_assign[k] = current[k]
			# трюк: best_cost передать наружу нельзя по значению,
			# поэтому храним его в best_assign meta ключом
			best_assign["__best_cost"] = cost
		return

	# Текущий лучший cost (если уже записан)
	var bc := INF
	if best_assign.has("__best_cost"):
		bc = float(best_assign["__best_cost"])

	# Отсечение
	if cost >= bc:
		return

	var id = ids[idx]
	var lp: Vector3 = locals[id]

	for slot in range(4):
		if used[slot]:
			continue

		var t: Vector3 = targets[slot]
		# Стоимость — расстояние в XZ (квадрат, без sqrt)
		var dx := lp.x - t.x
		
func _perm_slots(ids: Array, locals: Dictionary, targets: Dictionary, idx: int, chosen: Array, available: Array, best_assign: Dictionary, best_cost: float) -> void:
	if idx >= ids.size():
		# оценка стоимости
		var cost: float = 0.0
		for i in range(ids.size()):
			var id: int = int(ids[i])
			var slot: int = int(chosen[i])
			var lp: Vector3 = locals[id]
			var t: Vector3 = targets[slot]
			var dx: float = lp.x - t.x
			var dz: float = lp.z - t.z
			cost += dx * dx + dz * dz

		var current_best: float = best_cost
		if best_assign.has("__cost"):
			current_best = float(best_assign["__cost"])

		if cost < current_best:
			best_assign.clear()
			for i in range(ids.size()):
				best_assign[int(ids[i])] = int(chosen[i])
			best_assign["__cost"] = cost
		return

	# отсечение по текущему best
	var current_best2: float = best_cost
	if best_assign.has("__cost"):
		current_best2 = float(best_assign["__cost"])

	# выбираем следующий слот
	for j in range(available.size()):
		var slot_pick: int = int(available[j])

		var next_chosen := chosen.duplicate()
		next_chosen.append(slot_pick)

		var next_avail := available.duplicate()
		next_avail.remove_at(j)

		_perm_slots(ids, locals, targets, idx + 1, next_chosen, next_avail, best_assign, best_cost)

# ==================== UI: УБРАТЬ КНОПКИ СЦЕНЫ (SAVE/LOAD/EXPORT) ====================
func _remove_save_load_container_runtime() -> void:
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return
	var c := ui.get_node_or_null("SaveLoadContainer")
	if c != null and is_instance_valid(c):
		c.queue_free()

# ==================== ARDUINO: ПЕРЕХОД В СЦЕНУ ====================
func _get_arduino_scene_path() -> String:
	for p in ARDUINO_SCENE_PATHS:
		if ResourceLoader.exists(p):
			return p
	return ARDUINO_SCENE_PATHS[0]

func _ensure_arduino_button() -> void:
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return

	var btn := ui.get_node_or_null("ArduinoButton") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "ArduinoButton"
		btn.text = "🔌 Arduino"
		btn.custom_minimum_size = Vector2(200, 45)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		# Сверху справа
		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 0.0
		btn.anchor_bottom = 0.0
		btn.offset_left = -220.0
		btn.offset_right = -20.0
		btn.offset_top = 15.0
		btn.offset_bottom = 60.0

		ui.add_child(btn)

	_arduino_button = btn
	_apply_assembly_button_theme(_arduino_button, Color(0.37, 0.25, 0.16, 0.98), Color(0.88, 0.68, 0.45, 0.95), 17)
	var cb := Callable(self, "_on_arduino_button_pressed")
	if not _arduino_button.is_connected("pressed", cb):
		_arduino_button.pressed.connect(_on_arduino_button_pressed)

func _ensure_customization_button() -> void:
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return

	var btn := ui.get_node_or_null("CustomizationButton") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "CustomizationButton"
		btn.text = "Кастомизация"
		btn.custom_minimum_size = Vector2(200, 45)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		btn.anchor_left = 1.0
		btn.anchor_right = 1.0
		btn.anchor_top = 0.0
		btn.anchor_bottom = 0.0
		btn.offset_left = -220.0
		btn.offset_right = -20.0
		btn.offset_top = 70.0
		btn.offset_bottom = 115.0

		ui.add_child(btn)

	_customization_button = btn
	_apply_assembly_button_theme(_customization_button, Color(0.34, 0.23, 0.15, 0.98), Color(0.84, 0.66, 0.43, 0.94), 17)
	var cb := Callable(self, "_on_customization_pressed")
	if not _customization_button.is_connected("pressed", cb):
		_customization_button.pressed.connect(_on_customization_pressed)

func _on_arduino_button_pressed() -> void:
	if _pause_open:
		_toggle_pause_menu(false)

	_export_drone_on_scene_exit()

	get_tree().change_scene_to_file(_get_arduino_scene_path())


# ===================================================================
# ==================== ESC-МЕНЮ: СОЗДАНИЕ/АНИМАЦИЯ ===================
# ===================================================================

func _ensure_pause_menu() -> void:
	if _pause_layer != null and is_instance_valid(_pause_layer):
		return

	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseMenuLayer"
	_pause_layer.layer = 500
	add_child(_pause_layer)

	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(_pause_overlay)

	# Клик по затемнению -> закрыть
	_pause_overlay.gui_input.connect(_on_pause_overlay_gui_input)

	# Затемнение
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dim)

	# Панель меню (по центру)
	_pause_panel = Panel.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.size = Vector2(420, 420)
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -_pause_panel.size.x * 0.5
	_pause_panel.offset_top = -_pause_panel.size.y * 0.5
	_pause_panel.offset_right = _pause_panel.size.x * 0.5
	_pause_panel.offset_bottom = _pause_panel.size.y * 0.5
	_pause_panel.pivot_offset = _pause_panel.size * 0.5
	_pause_panel.scale = Vector2(0.92, 0.92)
	_pause_panel.modulate.a = 0.0
	_pause_overlay.add_child(_pause_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.10, 0.07, 0.96)
	style.border_color = Color(0.79, 0.60, 0.39, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	_pause_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_top = 18
	vbox.offset_right = -18
	vbox.offset_bottom = -18
	vbox.add_theme_constant_override("separation", 8)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "МЕНЮ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "ESC — закрыть меню"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.90, 0.82, 0.72, 0.88)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# --- быстрые действия ---
	vbox.add_child(_pm_btn("▶ Продолжить", Callable(self, "_on_pause_resume_pressed")))
	vbox.add_child(_pm_btn("🔌 Arduino (схема)", Callable(self, "_on_pause_arduino_pressed")))
	vbox.add_child(_pm_btn("💾 Сохранить (слоты)", Callable(self, "_on_pause_save_pressed")))
	vbox.add_child(_pm_btn("📂 Загрузить", Callable(self, "_on_pause_load_pressed")))
	vbox.add_child(_pm_btn("⚙ Настройки", Callable(self, "_on_pause_settings_pressed")))
	vbox.add_child(_pm_btn("🏠 В главное меню", Callable(self, "_on_pause_main_menu_pressed")))
	vbox.add_child(_pm_btn("⛔ Выйти из игры", Callable(self, "_on_pause_quit_pressed")))

func _pm_btn(text_: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text_
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	_apply_assembly_button_theme(b, Color(0.30, 0.21, 0.14, 0.97), Color(0.78, 0.60, 0.39, 0.90), 16)
	b.pressed.connect(cb)
	return b

func _toggle_pause_menu(open: bool) -> void:
	_ensure_pause_menu()
	_pause_open = open
	_pause_overlay.visible = true

	if _pause_tween != null and is_instance_valid(_pause_tween):
		_pause_tween.kill()

	if open:
		_pause_panel.scale = Vector2(0.92, 0.92)
		_pause_panel.modulate.a = 0.0

	_pause_tween = create_tween()
	_pause_tween.set_trans(Tween.TRANS_QUAD)
	_pause_tween.set_ease(Tween.EASE_OUT)

	if open:
		_pause_tween.tween_property(_pause_panel, "modulate:a", 1.0, 0.12)
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2(1, 1), 0.14)
	else:
		_pause_tween.tween_property(_pause_panel, "modulate:a", 0.0, 0.10)
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2(0.92, 0.92), 0.10)
		_pause_tween.tween_callback(Callable(self, "_pause_hide_overlay"))

func _pause_hide_overlay() -> void:
	if (not _pause_open) and _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false

func _close_pause_menu_immediate() -> void:
	# Мгновенно закрывает оверлей (нужно, чтобы он не перекрывал другие окна, например меню слотов)
	_pause_open = false
	if _pause_tween != null and is_instance_valid(_pause_tween):
		_pause_tween.kill()
	if _pause_panel != null and is_instance_valid(_pause_panel):
		_pause_panel.modulate.a = 0.0
		_pause_panel.scale = Vector2(0.92, 0.92)
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false


func _on_pause_overlay_gui_input(event: InputEvent) -> void:
	# клик по фону закрывает меню
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_pause_menu(false)

# ===================================================================
# ==================== ESC-МЕНЮ: ОБРАБОТЧИКИ КНОПОК ==================
# ===================================================================

func _on_pause_resume_pressed() -> void:
	_toggle_pause_menu(false)

func _on_pause_arduino_pressed() -> void:
	_close_pause_menu_immediate()
	_on_arduino_button_pressed()

func _on_pause_save_pressed() -> void:
	_close_pause_menu_immediate()
	show_save_menu()

func _on_pause_load_pressed() -> void:
	_close_pause_menu_immediate()
	show_load_menu()

func _on_pause_settings_pressed() -> void:
	_toggle_pause_menu(false)
	if settings_menu != null and settings_menu.has_method("open"):
		settings_menu.call("open")

func _on_pause_main_menu_pressed() -> void:
	_toggle_pause_menu(false)
	_export_drone_on_scene_exit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_pause_quit_pressed() -> void:
	_export_drone_on_scene_exit()
	get_tree().quit()


# ==================== TUTORIAL HOOKS ====================
func _get_tut() -> Node:
	var t := get_node_or_null("/root/tut")
	return t

func _is_tutorial_active() -> bool:
	var t := _get_tut()
	if t == null:
		return false
	return bool(t.get("active"))

func _tut_notify(event_name: String, data: Variant = null) -> void:
	var t := _get_tut()
	if t == null:
		return
	if t.has_method("notify"):
		t.notify(event_name, data)

func _tut_notify_after_drop(component_type: String) -> void:
	match component_type:
		"frame":
			_tut_notify("frame_added")
		"board":
			_tut_notify("board_added")
		"motor":
			_tut_notify("motors_count", motors.size())
		"propeller":
			_tut_notify("propellers_count", propellers.size())
		_:
			pass
