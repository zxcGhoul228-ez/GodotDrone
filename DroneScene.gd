extends Node3D

const GRID_SIZE = 32
const GRID_CELLS_COUNT = 32

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var drone_container = $DroneContainer
@onready var block_ui = $UI/BlockProgramming
@onready var programming_button = $UI/Control/ProgrammingButton

# Таймер переменные
var timer_ui: CanvasLayer
var timer_label: Label
var timer: Timer
var start_time: int
var current_time_ms: int
var is_timer_running: bool = false
var best_time_ms: int = 0
var best_time_label: Label

# Основные переменные
var camera_rotation = Vector2(0, 0)
var camera_distance = 80.0
var ROTATION_SPEED = 0.003
var ZOOM_SPEED = 3.0
var MIN_DISTANCE = 12.0
var MAX_DISTANCE = 400.0
var MIN_VERTICAL_ANGLE = -1.0
var MAX_VERTICAL_ANGLE = 1.5
var CAMERA_MOVE_SPEED = 50.0
var camera_move_input = Vector3.ZERO
var current_drone: CharacterBody3D = null
var pause_menu = null
var settings_menu = null
var is_paused = false
var mouse_sensitivity: float = 1.0
var camera_fov: float = 75.0
var brightness: float = 1.0
var music_volume: float = 50.0
var sfx_volume: float = 50.0
var rotation_velocity = Vector2(0, 0)
const FRICTION = 0.92
const MAX_VELOCITY = 0.1
@onready var grid_highlight = $GridHighlight
var highlight_mesh: MeshInstance3D
var current_cell_position = Vector3.ZERO
var trail_meshes: Array[MeshInstance3D] = []
var max_trail_length = 20
var trail_fade_time = 2.0
var start_point_x: int = 0
var start_point_z: int = 0
var start_point_y: int = GRID_SIZE
var highlight_color: Color = Color(0, 1, 0, 0.6)
var trail_color: Color = Color(0, 1, 0, 0.3)

# Границы сетки
var grid_boundary_min: Vector3
var grid_boundary_max: Vector3

# Траектория и предпросмотр
var trajectory_markers: Array[MeshInstance3D] = []
var preview_color: Color = Color(0.2, 0.6, 1.0, 0.4)
var preview_material: StandardMaterial3D

func _ready():
	print("=== ИНИЦИАЛИЗАЦИЯ СЦЕНЫ ДРОНА ===")
	print("Размер сетки: ", GRID_SIZE, "x", GRID_SIZE)
	print("Количество клеток: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT)
	
	# Инициализация границ
	calculate_grid_boundaries()
	
	# Создаем материал для предпросмотра траектории
	create_preview_material()
	
	load_settings()
	create_drone()
	create_grid()
	create_grid_highlight()
	block_ui.hide()
	update_camera_position()
	connect_buttons()
	
	# Инициализируем таймер
	setup_timer()
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Сцена готова! Сетка: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT, " клеток")
	print("Границы сетки: от ", grid_boundary_min, " до ", grid_boundary_max)

# ================== ГРАНИЦЫ СЕТКИ ==================
func calculate_grid_boundaries():
	var half_size = (GRID_CELLS_COUNT * GRID_SIZE) / 2
	grid_boundary_min = Vector3(-half_size, 0, -half_size)
	grid_boundary_max = Vector3(half_size, GRID_SIZE * 10, half_size)

func is_position_within_bounds(position: Vector3) -> bool:
	return (position.x >= grid_boundary_min.x and position.x <= grid_boundary_max.x and
			position.z >= grid_boundary_min.z and position.z <= grid_boundary_max.z and
			position.y >= grid_boundary_min.y and position.y <= grid_boundary_max.y)

func clamp_position_to_bounds(position: Vector3) -> Vector3:
	return Vector3(
		clamp(position.x, grid_boundary_min.x, grid_boundary_max.x),
		clamp(position.y, grid_boundary_min.y, grid_boundary_max.y),
		clamp(position.z, grid_boundary_min.z, grid_boundary_max.z)
	)

# ================== ПРЕДПРОСМОТР ТРАЕКТОРИИ ==================
func create_preview_material():
	preview_material = StandardMaterial3D.new()
	preview_material.flags_unshaded = true
	preview_material.flags_transparent = true
	preview_material.albedo_color = preview_color

func update_trajectory_preview(sequence: Array):
	# Очищаем старые маркеры
	clear_trajectory_preview()
	
	if not current_drone or sequence.is_empty():
		return
	
	print("🔄 Обновляем предпросмотр траектории для ", sequence.size(), " команд")
	
	# Начинаем от текущей позиции дрона
	var current_pos = current_drone.global_position
	var visited_cells = {}
	
	# Создаем маркер для стартовой позиции
	create_trajectory_marker(current_pos, true)
	visited_cells[vector2_to_key(current_pos.x, current_pos.z)] = true
	
	# Проходим по всем командам и вычисляем позиции
	for i in range(sequence.size()):
		var direction = sequence[i]
		var next_pos = calculate_next_position(current_pos, direction)
		
		# Проверяем, была ли уже эта клетка
		var cell_key = vector2_to_key(next_pos.x, next_pos.z)
		var is_new_cell = not visited_cells.has(cell_key)
		
		# Создаем маркер для следующей позиции
		if is_new_cell:
			create_trajectory_marker(next_pos, false)
			visited_cells[cell_key] = true
		
		current_pos = next_pos
	
	print("✅ Предпросмотр обновлен: ", trajectory_markers.size(), " клеток подсвечено")

func calculate_next_position(current_pos: Vector3, direction: int) -> Vector3:
	var next_pos = current_pos
	
	match direction:
		0: next_pos.z -= GRID_SIZE  # Вперед
		1: next_pos.z += GRID_SIZE  # Назад
		2: next_pos.x -= GRID_SIZE  # Влево
		3: next_pos.x += GRID_SIZE  # Вправо
		4: next_pos.y += GRID_SIZE  # Вверх
		5: next_pos.y = max(next_pos.y - GRID_SIZE, grid_boundary_min.y)  # Вниз - ИСПРАВЛЕНО: boundary_min -> grid_boundary_min
	
	return next_pos

func create_trajectory_marker(position: Vector3, is_start: bool):
	var marker = MeshInstance3D.new()
	add_child(marker)
	marker.owner = get_tree().edited_scene_root
	
	# Позиционируем маркер чуть выше пола
	marker.global_position = Vector3(position.x, 0.08, position.z)
	
	# Создаем меш для маркера
	var box_mesh = BoxMesh.new()
	if is_start:
		box_mesh.size = Vector3(GRID_SIZE * 0.6, 0.15, GRID_SIZE * 0.6)  # Стартовая клетка меньше
	else:
		box_mesh.size = Vector3(GRID_SIZE * 0.8, 0.12, GRID_SIZE * 0.8)  # Обычные клетки
	
	marker.mesh = box_mesh
	
	# Настраиваем материал
	var marker_material = preview_material.duplicate()
	if is_start:
		marker_material.albedo_color = Color(0, 1, 0, 0.6)  # Зеленый для старта
	else:
		marker_material.albedo_color = preview_color
	
	marker.material_override = marker_material
	
	trajectory_markers.append(marker)

func clear_trajectory_preview():
	for marker in trajectory_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	trajectory_markers.clear()
	
	print("🧹 Предпросмотр траектории очищен")

func vector2_to_key(x: float, z: float) -> String:
	return "%.1f_%.1f" % [x, z]
# ================== ТАЙМЕР ==================
func setup_timer():
	timer = Timer.new()
	timer.wait_time = 0.01
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	create_timer_ui()
	load_best_time()
	
	print("✅ Таймер инициализирован")

func create_timer_ui():
	timer_ui = CanvasLayer.new()
	timer_ui.name = "TimerUI"
	timer_ui.layer = 10
	
	var panel = Panel.new()
	panel.size = Vector2(250, 90)
	panel.position = Vector2(20, 20)
	panel.add_theme_stylebox_override("panel", create_panel_style())
	
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "00:00.000"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.size = Vector2(panel.size.x, 45)
	
	best_time_label = Label.new()
	best_time_label.name = "BestTimeLabel"
	best_time_label.text = "Лучшее: --:--.---"
	best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_time_label.add_theme_font_size_override("font_size", 14)
	best_time_label.add_theme_color_override("font_color", Color.YELLOW)
	best_time_label.position = Vector2(0, 45)
	best_time_label.size = Vector2(panel.size.x, 30)
	
	panel.add_child(timer_label)
	panel.add_child(best_time_label)
	timer_ui.add_child(panel)
	add_child(timer_ui)
	
	update_best_time_display()

func create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(1, 1, 1, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func start_timer():
	if not timer:
		setup_timer()
	
	start_time = Time.get_ticks_msec()
	current_time_ms = 0
	is_timer_running = true
	timer.start()
	
	update_timer_display()
	print("⏱️ Таймер запущен")

func stop_timer() -> String:
	if timer and is_timer_running:
		is_timer_running = false
		timer.stop()
		
		var final_time = format_time_ms(current_time_ms)
		print("⏹️ Таймер остановлен. Итоговое время: ", final_time)
		return final_time
	return ""

func reset_timer():
	if timer:
		timer.stop()
	is_timer_running = false
	current_time_ms = 0
	update_timer_display()
	print("🔄 Таймер сброшен")

func _on_timer_timeout():
	if is_timer_running:
		current_time_ms = Time.get_ticks_msec() - start_time
		update_timer_display()

func update_timer_display():
	if timer_label:
		timer_label.text = format_time_ms(current_time_ms)

func format_time_ms(milliseconds: int) -> String:
	var total_seconds = milliseconds / 1000
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	var ms = milliseconds % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, ms]

func update_best_time_display():
	if best_time_label:
		if best_time_ms > 0:
			best_time_label.text = "Лучшее: " + format_time_ms(best_time_ms)
		else:
			best_time_label.text = "Лучшее: --:--.---"

func save_best_time():
	var config = ConfigFile.new()
	config.set_value("best_times", "level_%d" % Global.current_level, best_time_ms)
	config.save("user://best_times.cfg")
	print("💾 Лучшее время сохранено: ", format_time_ms(best_time_ms))

func load_best_time():
	var config = ConfigFile.new()
	var error = config.load("user://best_times.cfg")
	if error == OK:
		best_time_ms = config.get_value("best_times", "level_%d" % Global.current_level, 0)
		print("📁 Загружено лучшее время: ", format_time_ms(best_time_ms))
	else:
		best_time_ms = 0
		print("📁 Лучшее время не найдено")
	
	update_best_time_display()

func _on_program_finished(success: bool):
	print("🎯 Программа завершена, успех: ", success)
	
	var final_time = stop_timer()
	
	if success:
		print("🎉 Уровень пройден! Время: ", final_time)
		show_success_message(final_time)
		if best_time_ms == 0 or current_time_ms < best_time_ms:
			best_time_ms = current_time_ms
			save_best_time()
			update_best_time_display()
			print("🏆 Новый рекорд!")
	else:
		print("❌ Программа завершена, цель не достигнута. Время: ", final_time)

func show_success_message(final_time: String):
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "SuccessCanvas"
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = get_viewport().size
	overlay.name = "Overlay"
	
	var panel = Panel.new()
	panel.name = "SuccessPanel"
	panel.size = Vector2(600, 300)
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	panel_style.border_color = Color.GREEN
	panel_style.border_width_left = 4
	panel_style.border_width_top = 4
	panel_style.border_width_right = 4
	panel_style.border_width_bottom = 4
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size = panel.size
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🎉 УРОВЕНЬ ПРОЙДЕН! 🎉"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color.GREEN)
	title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "Ваше время: " + final_time
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.add_theme_color_override("font_color", Color.GOLD)
	time_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var best_time_text = ""
	if best_time_ms > 0 and current_time_ms <= best_time_ms:
		best_time_text = "🏆 НОВЫЙ РЕКОРД! 🏆"
	else:
		best_time_text = "Лучшее время: " + format_time_ms(best_time_ms)
	
	var best_time_label = Label.new()
	best_time_label.name = "BestTimeLabel"
	best_time_label.text = best_time_text
	best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_time_label.add_theme_font_size_override("font_size", 20)
	best_time_label.add_theme_color_override("font_color", Color.YELLOW)
	best_time_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var return_label = Label.new()
	return_label.name = "ReturnLabel"
	return_label.text = "Автоматический возврат через 5 секунд..."
	return_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return_label.add_theme_font_size_override("font_size", 18)
	return_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	return_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	vbox.add_child(title_label)
	vbox.add_child(time_label)
	vbox.add_child(best_time_label)
	vbox.add_child(return_label)
	
	vbox.add_theme_constant_override("separation", 20)
	
	panel.add_child(vbox)
	overlay.add_child(panel)
	canvas.add_child(overlay)
	add_child(canvas)
	
	print("✅ Финальный экран создан: ", final_time)
	
	await get_tree().create_timer(5.0).timeout
	
	if canvas and is_instance_valid(canvas):
		canvas.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return_to_selection()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://UI/game_level.tscn")

# ================== СИСТЕМА ДРОНА ==================
func create_drone():
	print("🔧 Создаем дрон...")
	
	# Очищаем контейнер
	for child in drone_container.get_children():
		child.queue_free()
	
	# Пытаемся загрузить существующий дрон
	var drone_paths = [
		"res://exported_drone.tscn",
		"user://exported_drone.tscn", 
		"res://DroneLevels/Drone.tscn"
	]
	
	var drone_loaded = false
	for path in drone_paths:
		if ResourceLoader.exists(path):
			print("✅ Найден дрон: ", path)
			drone_loaded = load_drone_from_path(path)
			if drone_loaded:
				break
	
	if not drone_loaded:
		print("❌ Дрон не найден, создаем дрон по умолчанию")
		create_default_drone()
	
	print("✅ Дрон создан и готов")

func load_drone_from_path(path: String) -> bool:
	var drone_scene = load(path)
	if drone_scene:
		var drone_instance = drone_scene.instantiate()
		drone_container.add_child(drone_instance)
		
		if drone_instance is CharacterBody3D:
			current_drone = drone_instance
			setup_drone(current_drone)
			return true
		else:
			# Если это не CharacterBody3D, ищем внутри
			var drone_body = find_drone_root(drone_instance)
			if drone_body:
				current_drone = create_drone_from_parts(drone_body)
				setup_drone(current_drone)
				drone_instance.queue_free()
				return true
		
		print("❌ Не удалось создать дрон из: ", path)
		drone_instance.queue_free()
	
	return false

func find_drone_root(root_node: Node) -> Node3D:
	if root_node is CharacterBody3D:
		return root_node
	for child in root_node.get_children():
		if child is CharacterBody3D:
			return child
	var drone_candidates = []
	for child in root_node.get_children():
		if child is Node3D:
			if has_drone_components(child):
				drone_candidates.append(child)
	if drone_candidates.size() > 0:
		return drone_candidates[0]
	if root_node is Node3D:
		return root_node
	return null

func has_drone_components(node: Node3D) -> bool:
	var mesh_count = 0
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	return mesh_count > 0

func create_drone_from_parts(drone_node: Node3D) -> CharacterBody3D:
	print("🔧 Создаем дрон из частей...")
	var new_drone = CharacterBody3D.new()
	new_drone.name = "Drone"
	
	# Загружаем скрипт дрона
	var drone_script = load("res://DroneLevels/Drone.gd")
	if drone_script:
		new_drone.set_script(drone_script)
		print("✅ Добавлен скрипт Drone.gd")
	
	drone_container.add_child(new_drone)
	new_drone.owner = get_tree().edited_scene_root
	
	if drone_node is Node3D:
		print("📦 Копируем компоненты дрона...")
		var children_to_copy = []
		for child in drone_node.get_children():
			children_to_copy.append(child)
		for child in children_to_copy:
			if child is Node3D:
				var relative_transform = child.transform
				var child_name = child.name
				drone_node.remove_child(child)
				new_drone.add_child(child)
				child.owner = get_tree().edited_scene_root
				child.transform = relative_transform
				child.name = child_name
	
	# Устанавливаем позицию с проверкой границ
	var start_pos = calculate_start_position()
	if not is_position_within_bounds(start_pos):
		start_pos = clamp_position_to_bounds(start_pos)
		print("⚠️ Стартовая позиция скорректирована: ", start_pos)
	
	new_drone.global_position = start_pos
	
	if drone_node.get_parent() and drone_node.get_parent() != drone_container:
		drone_node.queue_free()
	
	print("✅ Дрон создан из частей")
	return new_drone

func calculate_start_position() -> Vector3:
	@warning_ignore("integer_division")
	var aligned_x = round((start_point_x + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	@warning_ignore("integer_division")
	var aligned_z = round((start_point_z + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	return Vector3(aligned_x, start_point_y, aligned_z)

func setup_drone(drone_node: CharacterBody3D):
	print("🔧 Настраиваем дрон...")
	
	# Устанавливаем позицию с проверкой границ
	var start_pos = calculate_start_position()
	if not is_position_within_bounds(start_pos):
		start_pos = clamp_position_to_bounds(start_pos)
		print("⚠️ Стартовая позиция скорректирована: ", start_pos)
	
	drone_node.global_position = start_pos
	drone_node.scale = Vector3(3, 3, 3)
	
	# Добавляем коллизию если нужно
	add_collision_if_needed(drone_node)
	
	drone_node.collision_layer = 1
	drone_node.collision_mask = 1
	
	# Подключаем сигналы
	if drone_node.has_signal("drone_moved"):
		drone_node.drone_moved.connect(on_drone_moved)
	if drone_node.has_signal("program_finished"):
		drone_node.program_finished.connect(_on_program_finished)
		print("✅ Сигнал program_finished подключен")
	
	# Устанавливаем границы
	if drone_node.has_method("set_boundaries"):
		drone_node.set_boundaries(grid_boundary_min, grid_boundary_max)
		print("✅ Границы установлены для дрона")
	
	# Проверяем коллизию
	var collision_node = drone_node.get_node_or_null("CollisionShape3D")
	if collision_node:
		print("🚁 Коллизия дрона: ", collision_node.global_position)
	else:
		print("⚠️ Коллизия дрона не найдена, добавляем...")
		add_collision_if_needed(drone_node)
	
	print("✅ Дрон настроен: ", drone_node.name)

func add_collision_if_needed(drone_node: CharacterBody3D):
	if drone_node.get_node_or_null("CollisionShape3D") == null:
		print("➕ Добавляем коллизию дрону...")
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(6, 1.5, 6)  # Стандартный размер для дрона
		collision.shape = shape
		collision.position = Vector3(0, 0.75, 0)  # Центрируем по высоте
		drone_node.add_child(collision)
		collision.owner = get_tree().edited_scene_root
		print("✅ Добавлена коллизия дрону")

func create_default_drone():
	print("🔧 Создаем дрон по умолчанию...")
	current_drone = create_default_character_drone()

func create_default_character_drone() -> CharacterBody3D:
	var drone_node = CharacterBody3D.new()
	drone_node.name = "DefaultDrone"
	
	# Добавляем скрипт
	var drone_script = load("res://DroneLevels/Drone.gd")
	if drone_script:
		drone_node.set_script(drone_script)
	
	# Добавляем визуальную часть
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4, 1, 4)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.2, 0.2)  # Красный цвет для видимости
	mesh_instance.material_override = material
	
	drone_node.add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root
	
	drone_container.add_child(drone_node)
	drone_node.owner = get_tree().edited_scene_root
	
	setup_drone(drone_node)
	print("✅ Дрон по умолчанию создан")
	return drone_node

func get_drone() -> CharacterBody3D:
	return current_drone

# ================== СЕТКА И ВИЗУАЛЬНЫЕ ЭФФЕКТЫ ==================
func create_grid():
	var grid = $Grid
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.albedo_color = Color(0.3, 0.3, 0.3)
	for child in grid.get_children():
		child.queue_free()
	
	# Создаем сетку 32x32 клеток
	var half_cells = GRID_CELLS_COUNT / 2
	for i in range(-half_cells, half_cells + 1):
		create_grid_line(
			Vector3(i * GRID_SIZE, 0, -half_cells * GRID_SIZE),
			Vector3(i * GRID_SIZE, 0, half_cells * GRID_SIZE),
			material, 0.3
		)
		create_grid_line(
			Vector3(-half_cells * GRID_SIZE, 0, i * GRID_SIZE),
			Vector3(half_cells * GRID_SIZE, 0, i * GRID_SIZE),
			material, 0.3
		)
	
	print("✅ Сетка создана: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT, " клеток")

func create_grid_line(from: Vector3, to: Vector3, material: Material, thickness: float):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()
	mesh_instance.mesh = immediate_mesh
	$Grid.add_child(mesh_instance)
	mesh_instance.owner = get_tree().edited_scene_root

func create_grid_highlight():
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.9, 0.2, GRID_SIZE * 0.9)
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.mesh = box_mesh
	highlight_mesh.position = Vector3.ZERO
	var highlight_material = StandardMaterial3D.new()
	highlight_material.flags_unshaded = true
	highlight_material.flags_transparent = true
	highlight_material.albedo_color = highlight_color
	highlight_mesh.material_override = highlight_material
	grid_highlight.add_child(highlight_mesh)
	highlight_mesh.owner = get_tree().edited_scene_root
	grid_highlight.position = Vector3.ZERO
	grid_highlight.visible = false

func update_grid_highlight():
	if not current_drone or not grid_highlight:
		return
	var drone_pos = current_drone.global_position
	
	# Проверяем, находится ли дрон в пределах сетки
	if is_position_within_bounds(drone_pos):
		grid_highlight.global_position = Vector3(drone_pos.x, 0.1, drone_pos.z)
		grid_highlight.visible = true
		highlight_mesh.material_override.albedo_color = highlight_color
	else:
		# Подсветка красным, если дрон за пределами
		grid_highlight.global_position = Vector3(drone_pos.x, 0.1, drone_pos.z)
		grid_highlight.visible = true
		highlight_mesh.material_override.albedo_color = Color(1, 0, 0, 0.6)
	
	var new_cell_position = Vector3(drone_pos.x, 0, drone_pos.z)
	if new_cell_position != current_cell_position and current_cell_position != Vector3.ZERO:
		create_trail_marker(current_cell_position)
	current_cell_position = new_cell_position

func create_trail_marker(position: Vector3):
	# Создаем след только если позиция в пределах сетки
	if not is_position_within_bounds(position):
		return
	
	var trail_mesh = MeshInstance3D.new()
	add_child(trail_mesh)
	trail_mesh.owner = get_tree().edited_scene_root
	trail_mesh.global_position = Vector3(position.x, 0.05, position.z)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.8, 0.1, GRID_SIZE * 0.8)
	trail_mesh.mesh = box_mesh
	var trail_material = StandardMaterial3D.new()
	trail_material.flags_unshaded = true
	trail_material.flags_transparent = true
	trail_material.albedo_color = trail_color
	trail_mesh.material_override = trail_material
	trail_meshes.append(trail_mesh)
	if trail_meshes.size() > max_trail_length:
		var oldest_trail = trail_meshes.pop_front()
		if is_instance_valid(oldest_trail):
			oldest_trail.queue_free()
	start_trail_fade(trail_mesh)

func start_trail_fade(trail_mesh: MeshInstance3D):
	var trail_index = trail_meshes.find(trail_mesh)
	var tween = create_tween()
	tween.tween_property(trail_mesh, "scale", Vector3(0.5, 0.5, 0.5), trail_fade_time * 0.7)
	tween.parallel().tween_property(trail_mesh.material_override, "albedo_color:a", 0.0, trail_fade_time)
	tween.tween_callback(_on_trail_fade_finished.bind(trail_index))

func _on_trail_fade_finished(trail_index: int):
	if trail_index >= 0 and trail_index < trail_meshes.size():
		var trail_mesh = trail_meshes[trail_index]
		if is_instance_valid(trail_mesh):
			trail_mesh.queue_free()
		trail_meshes.remove_at(trail_index)

func remove_trail_mesh(trail_mesh_ref):
	var trail_mesh = trail_mesh_ref as MeshInstance3D
	if trail_mesh and is_instance_valid(trail_mesh) and trail_mesh in trail_meshes:
		trail_meshes.erase(trail_mesh)
		trail_mesh.queue_free()

func clear_all_trails():
	for trail in trail_meshes:
		if is_instance_valid(trail):
			trail.queue_free()
	trail_meshes.clear()

func on_drone_moved():
	update_grid_highlight()

# ================== УПРАВЛЕНИЕ КАМЕРОЙ ==================
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_programming()
		get_viewport().set_input_as_handled()
		return
	
	if is_paused or block_ui.visible:
		return
	
	if event is InputEventMouseMotion:
		var mouse_delta = event.relative
		
		rotation_velocity = Vector2(
			-mouse_delta.y * ROTATION_SPEED * mouse_sensitivity * 0.5,
			-mouse_delta.x * ROTATION_SPEED * mouse_sensitivity * 0.5
		)
		
		rotation_velocity.x = clamp(rotation_velocity.x, -MAX_VELOCITY, MAX_VELOCITY)
		rotation_velocity.y = clamp(rotation_velocity.y, -MAX_VELOCITY, MAX_VELOCITY)
		
		camera_rotation.x += -mouse_delta.y * ROTATION_SPEED * mouse_sensitivity
		camera_rotation.y += -mouse_delta.x * ROTATION_SPEED * mouse_sensitivity
		
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		
		update_camera_position()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clamp(camera_distance - ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clamp(camera_distance + ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()
	
	if event is InputEventKey:
		var pressed = event.pressed
		match event.keycode:
			KEY_S: camera_move_input.z = -1.0 if pressed else 0.0
			KEY_W: camera_move_input.z = 1.0 if pressed else 0.0
			KEY_A: camera_move_input.x = -1.0 if pressed else 0.0
			KEY_D: camera_move_input.x = 1.0 if pressed else 0.0
			KEY_SPACE: camera_move_input.y = 1.0 if pressed else 0.0
			KEY_CTRL: camera_move_input.y = -1.0 if pressed else 0.0

func _process(delta):
	if camera_move_input != Vector3.ZERO:
		var move_direction = camera_move_input.normalized()
		var camera_forward = -camera.global_transform.basis.z
		var camera_right = camera.global_transform.basis.x
		var camera_up = camera.global_transform.basis.y
		var world_direction = Vector3.ZERO
		world_direction += camera_forward * move_direction.z
		world_direction += camera_right * move_direction.x
		world_direction += camera_up * move_direction.y
		camera_pivot.global_position += world_direction * CAMERA_MOVE_SPEED * delta
	
	if rotation_velocity.x != 0 or rotation_velocity.y != 0:
		camera_rotation.x += rotation_velocity.x
		camera_rotation.y += rotation_velocity.y
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		rotation_velocity *= FRICTION
		if abs(rotation_velocity.x) < 0.0001 and abs(rotation_velocity.y) < 0.0001:
			rotation_velocity = Vector2(0, 0)
		update_camera_position()
	
	if current_drone and grid_highlight:
		update_grid_highlight()

func update_camera_position():
	var camera_position = Vector3(
		sin(camera_rotation.y) * cos(camera_rotation.x),
		sin(camera_rotation.x),
		cos(camera_rotation.y) * cos(camera_rotation.x)
	) * camera_distance
	camera.position = camera_position
	camera.look_at(camera_pivot.global_position, Vector3.UP)

# ================== UI И КНОПКИ ==================
func connect_buttons():
	var programming_btn = $UI/Control/ProgrammingButton
	var start_btn = $UI/BlockProgramming/StartButton
	var clear_btn = $UI/BlockProgramming/ClearButton
	var close_btn = $UI/BlockProgramming/CloseButton
	
	if programming_btn:
		programming_btn.pressed.connect(_on_programming_button_pressed)
	if start_btn:
		start_btn.pressed.connect(_on_start_button_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_button_pressed)
	if close_btn:
		close_btn.pressed.connect(_on_close_button_pressed)
	
	# ПОДКЛЮЧАЕМ СИГНАЛ ДЛЯ ПРЕДПРОСМОТРА ТРАЕКТОРИИ
	if block_ui and block_ui.has_signal("trajectory_updated"):
		block_ui.trajectory_updated.connect(update_trajectory_preview)
		print("✅ Сигнал trajectory_updated подключен")
	
	print("✅ Все кнопки подключены")

func _on_programming_button_pressed():
	toggle_programming()

func _on_start_button_pressed():
	print("🟢 Запускаем программу дрона")
	
	# Очищаем предпросмотр перед запуском
	clear_trajectory_preview()
	
	var drone = get_drone()
	if drone and drone.has_method("execute_sequence"):
		var sequence = block_ui.get_program_sequence()
		print("Полученная последовательность: ", sequence)
		if sequence.size() > 0:
			print("✅ Запускаем программу из ", sequence.size(), " команд")
			start_timer()
			drone.execute_sequence(sequence)
		else:
			print("❌ Программа пуста! Добавьте блоки команд.")
	else:
		print("❌ Дрон не найден или не имеет метода execute_sequence")

func _on_clear_button_pressed():
	print("🗑️ Очищаем программу")
	
	# Очищаем предпросмотр при очистке программы
	clear_trajectory_preview()
	
	if block_ui and block_ui.has_method("_on_clear_button_pressed"):
		block_ui._on_clear_button_pressed()
	elif block_ui and block_ui.has_method("clear_program"):
		block_ui.clear_program()
	else:
		print("❌ BlockProgramming UI не найден или не имеет метода очистки")

func _on_close_button_pressed():
	toggle_programming()

func toggle_programming():
	if block_ui.visible:
		block_ui.hide()
		programming_button.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# Очищаем предпросмотр при закрытии панели
		clear_trajectory_preview()
		
		print("❌ Закрываем панель программирования")
	else:
		block_ui.show()
		programming_button.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# Обновляем предпросмотр при открытии панели
		if block_ui.has_method("get_program_sequence"):
			var sequence = block_ui.get_program_sequence()
			update_trajectory_preview(sequence)
		
		print("🧩 Открываем панель программирования")

# ================== МЕНЮ ПАУЗЫ И НАСТРОЕК ==================
func toggle_pause_menu():
	print("🔄 Нажата кнопка ESC, текущая пауза:", is_paused)
	
	if settings_menu and settings_menu.visible:
		print("📋 Закрываем настройки")
		close_settings()
		return
	
	if block_ui.visible:
		print("🧩 Закрываем программирование вместо паузы")
		toggle_programming()
		return
	
	if pause_menu == null:
		print("🆕 Создаем меню паузы впервые")
		create_pause_menu()
	
	is_paused = !is_paused
	print("🎯 Новое состояние паузы:", is_paused)
	
	if is_paused and is_timer_running:
		timer.paused = true
		print("⏸️ Таймер на паузе")
	elif not is_paused and is_timer_running:
		timer.paused = false
		print("▶️ Таймер возобновлен")
	
	pause_menu.visible = is_paused
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("⏸️ Меню паузы ОТКРЫТО - мышь видима")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("▶️ Меню паузы ЗАКРЫТО - мышь захвачена")
	
	get_tree().paused = is_paused

func create_pause_menu():
	pause_menu = ColorRect.new()
	pause_menu.color = Color(0, 0, 0, 0.7)
	pause_menu.size = get_viewport().size
	pause_menu.visible = false
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size = Vector2(400, 300)
	
	var viewport_size = Vector2(get_viewport().size)
	container.position = (viewport_size - container.size) / 2
	
	var title = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	
	var settings_btn = Button.new()
	settings_btn.text = "Настройки"
	settings_btn.custom_minimum_size = Vector2(300, 50)
	settings_btn.pressed.connect(open_settings)
	
	var main_menu_btn = Button.new()
	main_menu_btn.text = "Главное меню"
	main_menu_btn.custom_minimum_size = Vector2(300, 50)
	main_menu_btn.pressed.connect(go_to_main_menu)
	
	var quit_btn = Button.new()
	quit_btn.text = "Выйти из игры"
	quit_btn.custom_minimum_size = Vector2(300, 50)
	quit_btn.pressed.connect(quit_game)
	
	var resume_btn = Button.new()
	resume_btn.text = "Продолжить"
	resume_btn.custom_minimum_size = Vector2(300, 50)
	resume_btn.pressed.connect(toggle_pause_menu)
	
	container.add_child(title)
	container.add_child(resume_btn)
	container.add_child(settings_btn)
	container.add_child(main_menu_btn)
	container.add_child(quit_btn)
	
	pause_menu.add_child(container)
	add_child(pause_menu)

func open_settings():
	if settings_menu == null:
		create_settings_menu()
	pause_menu.visible = false
	settings_menu.visible = true

func close_settings():
	if settings_menu:
		settings_menu.visible = false
		pause_menu.visible = true
		save_settings()

func create_settings_menu():
	settings_menu = ColorRect.new()
	settings_menu.color = Color(0, 0, 0, 0.8)
	settings_menu.size = get_viewport().size
	settings_menu.visible = false
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size = Vector2(500, 700)
	
	var viewport_size = Vector2(get_viewport().size)
	container.position = (viewport_size - container.size) / 2
	
	var title = Label.new()
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	
	# Настройки чувствительности мыши
	var mouse_sens_container = HBoxContainer.new()
	var mouse_sens_label = Label.new()
	mouse_sens_label.text = "Чувствительность мыши:"
	mouse_sens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mouse_sens_slider = HSlider.new()
	mouse_sens_slider.min_value = 0.1
	mouse_sens_slider.max_value = 2.0
	mouse_sens_slider.value = mouse_sensitivity
	mouse_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	var mouse_sens_value = Label.new()
	mouse_sens_value.text = str(mouse_sensitivity)
	mouse_sens_value.custom_minimum_size = Vector2(40, 0)
	mouse_sens_container.add_child(mouse_sens_label)
	mouse_sens_container.add_child(mouse_sens_slider)
	mouse_sens_container.add_child(mouse_sens_value)
	
	# Настройки FOV
	var fov_container = HBoxContainer.new()
	var fov_label = Label.new()
	fov_label.text = "Поле зрения (FOV):"
	fov_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fov_slider = HSlider.new()
	fov_slider.min_value = 60
	fov_slider.max_value = 120
	fov_slider.value = camera_fov
	fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_slider.value_changed.connect(_on_fov_changed)
	var fov_value = Label.new()
	fov_value.text = str(int(camera_fov))
	fov_value.custom_minimum_size = Vector2(40, 0)
	fov_container.add_child(fov_label)
	fov_container.add_child(fov_slider)
	fov_container.add_child(fov_value)
	
	# Настройки яркости
	var brightness_container = HBoxContainer.new()
	var brightness_label = Label.new()
	brightness_label.text = "Яркость:"
	brightness_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.5
	brightness_slider.max_value = 2.0
	brightness_slider.value = brightness
	brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brightness_slider.value_changed.connect(_on_brightness_changed)
	var brightness_value = Label.new()
	brightness_value.text = str(brightness)
	brightness_value.custom_minimum_size = Vector2(40, 0)
	brightness_container.add_child(brightness_label)
	brightness_container.add_child(brightness_slider)
	brightness_container.add_child(brightness_value)
	
	# Настройки громкости музыки
	var music_volume_container = HBoxContainer.new()
	var music_volume_label = Label.new()
	music_volume_label.text = "Громкость музыки:"
	music_volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var music_volume_slider = HSlider.new()
	music_volume_slider.min_value = 0
	music_volume_slider.max_value = 100
	music_volume_slider.value = music_volume
	music_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	var music_volume_value = Label.new()
	music_volume_value.text = str(int(music_volume))
	music_volume_value.custom_minimum_size = Vector2(40, 0)
	music_volume_container.add_child(music_volume_label)
	music_volume_container.add_child(music_volume_slider)
	music_volume_container.add_child(music_volume_value)
	
	# Настройки громкости звуков
	var sfx_volume_container = HBoxContainer.new()
	var sfx_volume_label = Label.new()
	sfx_volume_label.text = "Громкость звуков:"
	sfx_volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_volume_slider = HSlider.new()
	sfx_volume_slider.min_value = 0
	sfx_volume_slider.max_value = 100
	sfx_volume_slider.value = sfx_volume
	sfx_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	var sfx_volume_value = Label.new()
	sfx_volume_value.text = str(int(sfx_volume))
	sfx_volume_value.custom_minimum_size = Vector2(40, 0)
	sfx_volume_container.add_child(sfx_volume_label)
	sfx_volume_container.add_child(sfx_volume_slider)
	sfx_volume_container.add_child(sfx_volume_value)
	
	# Разделитель для стартовой позиции
	var start_point_separator = HSeparator.new()
	start_point_separator.custom_minimum_size = Vector2(400, 5)
	
	var start_point_label = Label.new()
	start_point_label.text = "=== СТАРТОВАЯ ТОЧКА ДРОНА ==="
	start_point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_point_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# Настройки стартовой позиции X
	var start_x_container = HBoxContainer.new()
	var start_x_label = Label.new()
	start_x_label.text = "Стартовая позиция X:"
	start_x_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_x_slider = HSlider.new()
	start_x_slider.min_value = -GRID_CELLS_COUNT/2 * GRID_SIZE
	start_x_slider.max_value = GRID_CELLS_COUNT/2 * GRID_SIZE
	start_x_slider.step = GRID_SIZE
	start_x_slider.value = start_point_x
	start_x_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_x_slider.value_changed.connect(_on_start_x_changed)
	var start_x_value = Label.new()
	start_x_value.text = str(start_point_x)
	start_x_value.custom_minimum_size = Vector2(60, 0)
	start_x_container.add_child(start_x_label)
	start_x_container.add_child(start_x_slider)
	start_x_container.add_child(start_x_value)
	
	# Настройки стартовой позиции Z
	var start_z_container = HBoxContainer.new()
	var start_z_label = Label.new()
	start_z_label.text = "Стартовая позиция Z:"
	start_z_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_z_slider = HSlider.new()
	start_z_slider.min_value = -GRID_CELLS_COUNT/2 * GRID_SIZE
	start_z_slider.max_value = GRID_CELLS_COUNT/2 * GRID_SIZE
	start_z_slider.step = GRID_SIZE
	start_z_slider.value = start_point_z
	start_z_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_z_slider.value_changed.connect(_on_start_z_changed)
	var start_z_value = Label.new()
	start_z_value.text = str(start_point_z)
	start_z_value.custom_minimum_size = Vector2(60, 0)
	start_z_container.add_child(start_z_label)
	start_z_container.add_child(start_z_slider)
	start_z_container.add_child(start_z_value)
	
	# Настройки стартовой высоты Y
	var start_y_container = HBoxContainer.new()
	var start_y_label = Label.new()
	start_y_label.text = "Стартовая высота Y:"
	start_y_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_y_slider = HSlider.new()
	start_y_slider.min_value = GRID_SIZE
	start_y_slider.max_value = 3 * GRID_SIZE
	start_y_slider.step = GRID_SIZE
	start_y_slider.value = start_point_y
	start_y_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_y_slider.value_changed.connect(_on_start_y_changed)
	var start_y_value = Label.new()
	start_y_value.text = str(start_point_y)
	start_y_value.custom_minimum_size = Vector2(60, 0)
	start_y_container.add_child(start_y_label)
	start_y_container.add_child(start_y_slider)
	start_y_container.add_child(start_y_value)
	
	# Кнопка применения стартовой позиции
	var apply_start_btn = Button.new()
	apply_start_btn.text = "Применить стартовую позицию"
	apply_start_btn.custom_minimum_size = Vector2(300, 40)
	apply_start_btn.pressed.connect(_on_apply_start_position)
	
	# Кнопка назад
	var back_btn = Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(300, 50)
	back_btn.pressed.connect(close_settings)
	
	# Добавляем все элементы в контейнер
	container.add_child(title)
	container.add_child(mouse_sens_container)
	container.add_child(fov_container)
	container.add_child(brightness_container)
	container.add_child(music_volume_container)
	container.add_child(sfx_volume_container)
	container.add_child(start_point_separator)
	container.add_child(start_point_label)
	container.add_child(start_x_container)
	container.add_child(start_z_container)
	container.add_child(start_y_container)
	container.add_child(apply_start_btn)
	container.add_child(back_btn)
	
	settings_menu.add_child(container)
	add_child(settings_menu)

func _on_mouse_sens_changed(value: float):
	mouse_sensitivity = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var mouse_sens_container = container.get_child(1)
		var value_label = mouse_sens_container.get_child(2)
		value_label.text = str(round(value * 100) / 100)

func _on_fov_changed(value: float):
	camera_fov = value
	camera.fov = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var fov_container = container.get_child(2)
		var value_label = fov_container.get_child(2)
		value_label.text = str(int(value))

func _on_brightness_changed(value: float):
	brightness = value
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var brightness_container = container.get_child(3)
		var value_label = brightness_container.get_child(2)
		value_label.text = str(round(value * 100) / 100)

func _on_music_volume_changed(value: float):
	music_volume = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var music_container = container.get_child(4)
		var value_label = music_container.get_child(2)
		value_label.text = str(int(value))

func _on_sfx_volume_changed(value: float):
	sfx_volume = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var sfx_container = container.get_child(5)
		var value_label = sfx_container.get_child(2)
		value_label.text = str(int(value))

func _on_start_x_changed(value: float):
	start_point_x = int(value)
	if settings_menu:
		var container = settings_menu.get_child(0)
		var start_x_container = container.get_child(8)
		var value_label = start_x_container.get_child(2)
		value_label.text = str(start_point_x)

func _on_start_z_changed(value: float):
	start_point_z = int(value)
	if settings_menu:
		var container = settings_menu.get_child(0)
		var start_z_container = container.get_child(9)
		var value_label = start_z_container.get_child(2)
		value_label.text = str(start_point_z)

func _on_start_y_changed(value: float):
	start_point_y = int(value)
	if settings_menu:
		var container = settings_menu.get_child(0)
		var start_y_container = container.get_child(10)
		var value_label = start_y_container.get_child(2)
		value_label.text = str(start_point_y)

func _on_apply_start_position():
	print("🎯 Применяем новую стартовую позицию: ", start_point_x, ", ", start_point_y, ", ", start_point_z)
	if current_drone:
		var start_pos = calculate_start_position()
		if not is_position_within_bounds(start_pos):
			start_pos = clamp_position_to_bounds(start_pos)
			print("⚠️ Стартовая позиция скорректирована: ", start_pos)
		
		current_drone.global_position = start_pos
		on_drone_moved()
	save_settings()

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_scene.tscn")

func quit_game():
	get_tree().quit()

# ================== НАСТРОЙКИ ==================
func save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "camera_fov", camera_fov)
	config.set_value("settings", "brightness", brightness)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("start_position", "x", start_point_x)
	config.set_value("start_position", "z", start_point_z)
	config.set_value("start_position", "y", start_point_y)
	config.set_value("colors", "highlight_color", highlight_color)
	config.set_value("colors", "trail_color", trail_color)
	var error = config.save("user://settings.cfg")
	if error == OK:
		print("Настройки сохранены")
	else:
		print("Ошибка сохранения настроек")

func load_settings():
	var config = ConfigFile.new()
	var error = config.load("user://settings.cfg")
	if error == OK:
		mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", 1.0)
		camera_fov = config.get_value("settings", "camera_fov", 75.0)
		brightness = config.get_value("settings", "brightness", 1.0)
		music_volume = config.get_value("settings", "music_volume", 50.0)
		sfx_volume = config.get_value("settings", "sfx_volume", 50.0)
		start_point_x = config.get_value("start_position", "x", 0)
		start_point_z = config.get_value("start_position", "z", 0)
		start_point_y = config.get_value("start_position", "y", GRID_SIZE)
		highlight_color = config.get_value("colors", "highlight_color", Color(0, 1, 0, 0.6))
		trail_color = config.get_value("colors", "trail_color", Color(0, 1, 0, 0.3))
		apply_settings()
		print("Настройки загружены")
	else:
		print("Файл настроек не найден, используются настройки по умолчанию")

func apply_settings():
	camera.fov = camera_fov
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = brightness
	if highlight_mesh and highlight_mesh.material_override:
		highlight_mesh.material_override.albedo_color = highlight_color
