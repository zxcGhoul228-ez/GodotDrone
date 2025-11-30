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
var camera_distance = 200.0
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
var start_point_y: int = 0  # ИЗМЕНЕНО: было GRID_SIZE, теперь 0 - старт с земли
var highlight_color: Color = Color(0, 1, 0, 0.6)
var trail_color: Color = Color(0, 1, 0, 0.3)
var MIN_CAMERA_HEIGHT = -15.0  # Минимальная высота камеры (чуть выше стола)
# Границы сетки
var grid_boundary_min: Vector3
var grid_boundary_max: Vector3

# Траектория и предпросмотр
var trajectory_markers: Array[MeshInstance3D] = []
var preview_color: Color = Color(0.2, 0.6, 1.0, 0.4)
var preview_material: StandardMaterial3D

func _ready():
	create_wooden_floor()
	var room_scene = load("res://room3d/source/Untitled1.glb")
	# Корректировка масштаба
	camera.far = 100000.0  # Вместо стандартных 100
	var room_instance = room_scene.instantiate()
	room_instance.scale = Vector3(2000, 2000, 2000)  # Пример
	add_child(room_instance)
	print("=== ИНИЦИАЛИЗАЦИЯ СЦЕНЫ ДРОНА ===")
	print("Размер сетки: ", GRID_SIZE, "x", GRID_SIZE)
	print("Количество клеток: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT)
	room_instance.position = Vector3(3200, -1000, -16)  # Центровка
	# Инициализация границ
	calculate_grid_boundaries()
	
	# Создаем материал для предпросмотра траектории
	create_preview_material()
	
	load_settings()
	create_drone()
	create_grid()
	create_table()  # ДОБАВЬТЕ ЭТУ СТРОКУ
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
		5: next_pos.y = max(next_pos.y - GRID_SIZE, grid_boundary_min.y)  # Вниз
	
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
		
		# Сохраняем результат и получаем награду
		var result = Global.complete_level(Global.current_level, current_time_ms)
		
		# Показываем сообщение с результатом
		show_success_message(final_time, current_time_ms, result)
		
		# Обновляем лучшее время если нужно
		if best_time_ms == 0 or current_time_ms < best_time_ms:
			best_time_ms = current_time_ms
			save_best_time()
			update_best_time_display()
			print("🏆 Новый рекорд!")
	else:
		print("❌ Программа завершена, цель не достигнута. Время: ", final_time)

func show_success_message(final_time: String, time_ms: int, result: Dictionary):
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "SuccessCanvas"
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = get_viewport().size
	overlay.name = "Overlay"
	
	var panel = Panel.new()
	panel.name = "SuccessPanel"
	panel.size = Vector2(700, 500)
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	panel_style.border_color = get_star_color(result["stars"])
	panel_style.border_width_left = 6
	panel_style.border_width_top = 6
	panel_style.border_width_right = 6
	panel_style.border_width_bottom = 6
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size = panel.size
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Заголовок с анимацией
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = get_success_title(result["stars"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", get_star_color(result["stars"]))
	
	# Контейнер для звезд
	var stars_container = HBoxContainer.new()
	stars_container.name = "StarsContainer"
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 20)
	
	# Создаем звезды
	var stars_earned = result["stars"]
	for i in range(3):
		var star_frame = CenterContainer.new()
		star_frame.custom_minimum_size = Vector2(80, 80)
		
		var star_label = Label.new()
		if i < stars_earned:
			star_label.text = "★"
			star_label.add_theme_color_override("font_color", Color.GOLD)
			# Анимация для полученных звезд
			var tween = create_tween()
			tween.tween_property(star_label, "scale", Vector2(1.5, 1.5), 0.5)
			tween.tween_property(star_label, "scale", Vector2(1.2, 1.2), 0.3)
		else:
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", Color.DARK_GRAY)
		
		star_label.add_theme_font_size_override("font_size", 64)
		star_frame.add_child(star_label)
		stars_container.add_child(star_frame)
	
	# Время прохождения
	var time_container = HBoxContainer.new()
	time_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var time_icon = Label.new()
	time_icon.text = "⏱️"
	time_icon.add_theme_font_size_override("font_size", 24)
	
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = final_time
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	
	time_container.add_child(time_icon)
	time_container.add_child(time_label)
	
	# Награда
	var reward_container = HBoxContainer.new()
	reward_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var reward_icon = Label.new()
	reward_icon.text = "💰"
	reward_icon.add_theme_font_size_override("font_size", 24)
	
	var reward_label = Label.new()
	reward_label.name = "RewardLabel"
	var reward_text = "+" + str(result["reward"]) + " монет"
	if result["bonus"] > 0:
		reward_text += " (бонус за первое прохождение!)"
	reward_label.text = reward_text
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 24)
	reward_label.add_theme_color_override("font_color", Color.GOLD)
	
	reward_container.add_child(reward_icon)
	reward_container.add_child(reward_label)
	
	# Информация о порогах
	var thresholds = Global.level_star_thresholds.get(Global.current_level, [0, 0, 0])
	var thresholds_label = Label.new()
	thresholds_label.name = "ThresholdsLabel"
	thresholds_label.text = "Время для звезд: 3★ - %s, 2★ - %s, 1★ - %s" % [
		format_time_ms(thresholds[0]),
		format_time_ms(thresholds[1]), 
		format_time_ms(thresholds[2])
	]
	thresholds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thresholds_label.add_theme_font_size_override("font_size", 16)
	thresholds_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	
	# Кнопка продолжения
	var continue_button = Button.new()
	continue_button.text = "Продолжить"
	continue_button.custom_minimum_size = Vector2(200, 50)
	continue_button.pressed.connect(_on_continue_pressed.bind(canvas))
	
	# Добавляем все элементы
	vbox.add_child(title_label)
	vbox.add_child(stars_container)
	vbox.add_child(time_container)
	vbox.add_child(reward_container)
	vbox.add_child(thresholds_label)
	vbox.add_child(continue_button)
	
	vbox.add_theme_constant_override("separation", 20)
	
	panel.add_child(vbox)
	overlay.add_child(panel)
	canvas.add_child(overlay)
	add_child(canvas)
	
	print("✅ Финальный экран создан. Звезды: ", stars_earned, ", Награда: ", result["reward"])

func get_success_title(stars: int) -> String:
	match stars:
		3:
			return "🎉 ИДЕАЛЬНО! 3 ЗВЕЗДЫ! 🎉"
		2:
			return "✨ ОТЛИЧНО! 2 ЗВЕЗДЫ! ✨"
		1:
			return "👍 ХОРОШО! 1 ЗВЕЗДА! 👍"
		_:
			return "✅ УРОВЕНЬ ПРОЙДЕН!"

func get_star_color(stars: int) -> Color:
	match stars:
		3:
			return Color.GOLD
		2:
			return Color.SILVER
		1:
			return Color.ORANGE
		_:
			return Color.GREEN

func _on_continue_pressed(canvas: CanvasLayer):
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
	return Vector3(aligned_x, start_point_y, aligned_z)  # ИСПОЛЬЗУЕМ start_point_y (теперь 0)
# ================== УПРАВЛЕНИЕ ВЫСОТОЙ ДРОНА ==================
func set_drone_height(height: float):
	print("🔄 Устанавливаем высоту дрона: ", height)
	start_point_y = height
	
	if current_drone:
		var new_pos = current_drone.global_position
		new_pos.y = height
		current_drone.global_position = new_pos
		print("✅ Высота дрона установлена: ", new_pos)
	
	# Сохраняем настройки
	save_settings()

func get_drone_height() -> float:
	return start_point_y

# Функция для внешнего управления высотой (например из Level1)
func adjust_drone_height(relative_change: float):
	var new_height = start_point_y + relative_change
	set_drone_height(new_height)
func setup_drone(drone_node: CharacterBody3D):
	print("🔧 Настраиваем дрон...")
	
	# Устанавливаем стартовую позицию
	var start_pos = calculate_start_position()
	if not is_position_within_bounds(start_pos):
		start_pos = clamp_position_to_bounds(start_pos)
		print("⚠️ Стартовая позиция скорректирована: ", start_pos)
	
	drone_node.global_position = start_pos
	drone_node.scale = Vector3(3, 3, 3)
	
	# Устанавливаем целевую позицию (например, противоположный угол)
	var target_pos = Vector3(GRID_SIZE * 2, 0, GRID_SIZE * 2)
	if drone_node.has_method("set_target_position"):
		drone_node.set_target_position(target_pos)
		print("🎯 Установлена целевая позиция для дрона: ", target_pos)
	
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

# Замени функцию create_table():
func create_table():
	print("🔧 Создаем красивый игровой стол...")
	
	var table_node = MeshInstance3D.new()
	table_node.name = "GameTable"
	
	# Размеры стола
	var table_width = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_depth = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_height = 15
	
	var table_mesh = BoxMesh.new()
	table_mesh.size = Vector3(table_width, table_height, table_depth)
	table_node.mesh = table_mesh
	
	table_node.position = Vector3(0, -table_height/2 - 2, 0)
	
	# Создаем красивый материал для стола
	var table_material = StandardMaterial3D.new()
	table_material.albedo_color = Color(0.3, 0.2, 0.1)
	table_material.roughness = 0.7
	table_material.metallic = 0.1
	
	# Пробуем загрузить деревянную текстуру
	var wood_texture = load("res://room3d/textures/wood.jpg")
	if wood_texture:
		table_material.albedo_texture = wood_texture
		table_material.uv1_scale = Vector3(4, 4, 4)
		table_material.roughness_texture = wood_texture
		table_material.metallic_texture = wood_texture
	
	table_node.material_override = table_material
	
	add_child(table_node)
	table_node.owner = get_tree().edited_scene_root
	
	# Создаем стильные ножки
	create_modern_table_legs(table_width, table_depth, table_height)
	
	print("✅ Красивый стол создан")

func create_modern_table_legs(table_width: float, table_depth: float, table_height: float):
	var leg_height = 80
	var leg_thickness = 12
	
	var leg_material = StandardMaterial3D.new()
	leg_material.albedo_color = Color(0.15, 0.15, 0.15)
	leg_material.roughness = 0.8
	leg_material.metallic = 0.3
	
	var leg_positions = [
		Vector3(-table_width/2 + leg_thickness, -table_height/2 - leg_height/2, -table_depth/2 + leg_thickness),
		Vector3(table_width/2 - leg_thickness, -table_height/2 - leg_height/2, -table_depth/2 + leg_thickness),
		Vector3(-table_width/2 + leg_thickness, -table_height/2 - leg_height/2, table_depth/2 - leg_thickness),
		Vector3(table_width/2 - leg_thickness, -table_height/2 - leg_height/2, table_depth/2 - leg_thickness)
	]
	
	for i in range(4):
		var leg = MeshInstance3D.new()
		leg.name = "ModernTableLeg_" + str(i)
		
		var leg_mesh = CylinderMesh.new()
		leg_mesh.top_radius = leg_thickness / 2
		leg_mesh.bottom_radius = leg_thickness / 2
		leg_mesh.height = leg_height
		leg.mesh = leg_mesh
		leg.material_override = leg_material
		
		leg.position = leg_positions[i]
		
		add_child(leg)
		leg.owner = get_tree().edited_scene_root

func create_table_legs_long(table_width: float, table_depth: float, table_height: float):
	var leg_size = Vector3(40, 4000, 40)
	var leg_material = StandardMaterial3D.new()
	leg_material.albedo_color = Color(0.3, 0.15, 0.05)
	leg_material.roughness = 0.9
	
	var leg_positions = [
		Vector3(-table_width/2 + leg_size.x, -table_height/2 - leg_size.y/2, -table_depth/2 + leg_size.z),
		Vector3(table_width/2 - leg_size.x, -table_height/2 - leg_size.y/2, -table_depth/2 + leg_size.z),
		Vector3(-table_width/2 + leg_size.x, -table_height/2 - leg_size.y/2, table_depth/2 - leg_size.z),
		Vector3(table_width/2 - leg_size.x, -table_height/2 - leg_size.y/2, table_depth/2 - leg_size.z)
	]
	
	for i in range(4):
		var leg = MeshInstance3D.new()
		leg.name = "TableLeg_Long_" + str(i)
		
		var leg_mesh = BoxMesh.new()
		leg_mesh.size = leg_size
		leg.mesh = leg_mesh
		leg.material_override = leg_material
		
		leg.position = leg_positions[i]
		
		add_child(leg)
		leg.owner = get_tree().edited_scene_root
	
	print("✅ Длинные ножки созданы: высота = ", leg_size.y)
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


func create_highlight_shader() -> Shader:
	var shader_code = """
	shader_type spatial;
	render_mode unshaded, blend_add;
	
	uniform vec4 highlight_color;
	uniform float pulse_speed;
	
	void fragment() {
		float time = TIME * pulse_speed;
		float pulse = (sin(time) + 1.0) * 0.5;
		float alpha = highlight_color.a * (0.7 + 0.3 * pulse);
		
		// Плавное затухание к краям
		vec2 uv = UV - 0.5;
		float edge_fade = 1.0 - smoothstep(0.3, 0.5, length(uv));
		
		ALBEDO = highlight_color.rgb;
		ALPHA = alpha * edge_fade;
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	return shader

# Обнови позицию подсветки в update_grid_highlight():


# В # В DroneScene.gd замени функцию create_grid_highlight():
func create_grid_highlight():
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.9, 0.1, GRID_SIZE * 0.9)
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.mesh = box_mesh
	
	# Создаем красивый материал для подсветки
	var highlight_material = StandardMaterial3D.new()
	highlight_material.flags_transparent = true
	highlight_material.albedo_color = HIGHLIGHT_COLOR_NORMAL
	highlight_material.emission_enabled = true
	highlight_material.emission = HIGHLIGHT_COLOR_NORMAL * 0.6
	highlight_material.metallic = 0.2
	highlight_material.roughness = 0.1
	
	highlight_mesh.material_override = highlight_material
	grid_highlight.add_child(highlight_mesh)
	highlight_mesh.owner = get_tree().edited_scene_root
	grid_highlight.visible = false
	
	# Плавная анимация пульсации
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(highlight_mesh.material_override, "albedo_color:a", 0.7, 1.5)
	tween.tween_property(highlight_mesh.material_override, "emission", HIGHLIGHT_COLOR_NORMAL * 0.8, 0.75)
	tween.tween_property(highlight_mesh.material_override, "albedo_color:a", 0.3, 1.5)
	tween.tween_property(highlight_mesh.material_override, "emission", HIGHLIGHT_COLOR_NORMAL * 0.3, 0.75)

# Обнови константы цветов:
const HIGHLIGHT_COLOR_NORMAL = Color(0.2, 0.6, 1.0, 0.5)
const HIGHLIGHT_COLOR_WARNING = Color(1.0, 0.2, 0.2, 0.6)
const TRAIL_COLOR = Color(0.2, 0.5, 0.9, 0.4)

# В update_grid_highlight() обнови позицию:
func update_grid_highlight():
	if not current_drone or not grid_highlight:
		return
	
	var drone_pos = current_drone.global_position
	
	if is_position_within_bounds(drone_pos):
		grid_highlight.global_position = Vector3(drone_pos.x, 0.15, drone_pos.z)
		grid_highlight.visible = true
		highlight_mesh.material_override.albedo_color = HIGHLIGHT_COLOR_NORMAL
		highlight_mesh.material_override.emission = HIGHLIGHT_COLOR_NORMAL * 0.6
	else:
		grid_highlight.global_position = Vector3(drone_pos.x, 0.15, drone_pos.z)
		grid_highlight.visible = true
		highlight_mesh.material_override.albedo_color = HIGHLIGHT_COLOR_WARNING
		highlight_mesh.material_override.emission = HIGHLIGHT_COLOR_WARNING * 0.8
	
	var new_cell_position = Vector3(drone_pos.x, 0, drone_pos.z)
	if new_cell_position != current_cell_position and current_cell_position != Vector3.ZERO:
		create_trail_marker(current_cell_position)
	current_cell_position = new_cell_position
func create_wooden_floor():
	var floor_node = $Floor  # или путь к вашему узлу Floor
	
	if floor_node:
		var mesh_instance = floor_node.get_node("MeshInstance3D")
		if mesh_instance:
			# Создаем красивый деревянный материал
			var floor_material = StandardMaterial3D.new()
			floor_material.albedo_color = Color(0.35, 0.25, 0.15)
			floor_material.metallic = 0.1
			floor_material.roughness = 0.7
			
			# Пробуем загрузить деревянную текстуру
			var wood_texture = load("res://room3d/textures/wood.jpg")
			if wood_texture:
				floor_material.albedo_texture = wood_texture
				# Настраиваем масштаб текстуры для хорошего размера
				floor_material.uv1_scale = Vector3(16, 16, 16)
			
			
			mesh_instance.material_override = floor_material
			print("✅ Деревянный пол создан")
# Улучшенная функция создания следов:
func create_trail_marker(position: Vector3):
	if not is_position_within_bounds(position):
		return
	
	var trail_mesh = MeshInstance3D.new()
	add_child(trail_mesh)
	trail_mesh.owner = get_tree().edited_scene_root
	trail_mesh.global_position = Vector3(position.x, 0.08, position.z)
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.7, 0.08, GRID_SIZE * 0.7)
	trail_mesh.mesh = box_mesh
	
	var trail_material = StandardMaterial3D.new()
	trail_material.flags_unshaded = true
	trail_material.flags_transparent = true
	trail_material.albedo_color = TRAIL_COLOR
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
	
	# Настройки стартовой высоты Y - ИЗМЕНЕНО: теперь минимум 0
	var start_y_container = HBoxContainer.new()
	var start_y_label = Label.new()
	start_y_label.text = "Стартовая высота Y:"
	start_y_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_y_slider = HSlider.new()
	start_y_slider.min_value = 0  # ИЗМЕНЕНО: было GRID_SIZE
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
		start_point_y = config.get_value("start_position", "y", 0)  # ИЗМЕНЕНО: было GRID_SIZE, теперь 0
		highlight_color = config.get_value("colors", "highlight_color", Color(0, 1, 0, 0.6))
		trail_color = config.get_value("colors", "trail_color", Color(0, 1, 0, 0.3))
		apply_settings()
		print("Настройки загружены")
	else:
		print("Файл настроек не найден, используются настройки по умолчанию")

func apply_settings():
	camera.fov = camera_fov
	camera.far = 100090.0  # Добавьте эту строку
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = brightness
	if highlight_mesh and highlight_mesh.material_override:
		highlight_mesh.material_override.albedo_color = highlight_color
