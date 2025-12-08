extends Node3D

# ==================== КОНСТАНТЫ ====================
const GRID_SIZE = 32
const GRID_CELLS_COUNT = 32
const ROTATION_SPEED = 0.003
const ZOOM_SPEED = 3.0
const MIN_DISTANCE = 12.0
const MAX_DISTANCE = 400.0
const MIN_VERTICAL_ANGLE = -1.0
const MAX_VERTICAL_ANGLE = 1.5
const CAMERA_MOVE_SPEED = 500.0
const FRICTION = 0.92
const MAX_VELOCITY = 0.1
const MAX_TRAIL_LENGTH = 20
const TRAIL_FADE_TIME = 2.0
const MIN_CAMERA_HEIGHT = -15.0
const START_POINT_X = 0
const START_POINT_Z = 0
const START_POINT_Y = 0
const HIGHLIGHT_COLOR_WARNING = Color(1.0, 0.3, 0.3, 0.7)

# ==================== ПУТИ К КОМНАТАМ ====================
const ROOM_PATHS = [
	"res://room3d/source/room1.glb",
	"res://room3d/room2/source/chicken_gun_standoff_2_arena.glb", 
	"res://room3d/room3/source/Scene 1 - RealRoom.glb",
	"res://room3d/source/room4.glb",
	"res://room3d/source/room5.glb"
]

# ==================== КОНФИГУРАЦИЯ КОМНАТ ПО УРОВНЯМ ====================
var level_room_configs = {
	1: [0, Vector3(700, 700, 700), Vector3(-600, -200, -200)],
	2: [1, Vector3(20000, 20000, 20000), Vector3(0, -40, 500)],
	3: [2, Vector3(1000, 1000, 1000), Vector3(-2000, -80, 2000)],
	4: [3, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	5: [4, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	6: [0, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	7: [1, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	8: [2, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	9: [3, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	10: [4, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	11: [0, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	12: [1, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	13: [2, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	14: [3, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)],
	15: [4, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)]
}

# ==================== ССЫЛКИ НА НОДЫ ====================
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var drone_container = $DroneContainer
@onready var block_ui = $UI/BlockProgramming
@onready var programming_button = $UI/Control/ProgrammingButton
@onready var grid_highlight = $GridHighlight

# ==================== ПЕРЕМЕННЫЕ ТАЙМЕРА ====================
var timer_ui: CanvasLayer
var timer_label: Label
var timer: Timer
var start_time: int
var current_time_ms: int
var is_timer_running: bool = false
var best_time_ms: int = 0
var best_time_label: Label

# ==================== ОСНОВНЫЕ ПЕРЕМЕННЫЕ ====================
var camera_rotation = Vector2(0, 0)
var camera_distance = 200.0
var camera_move_input = Vector3.ZERO
var current_drone: CharacterBody3D = null
var rotation_velocity = Vector2(0, 0)
var highlight_mesh: MeshInstance3D
var current_cell_position = Vector3.ZERO
var trail_meshes: Array[MeshInstance3D] = []
var grid_boundary_min: Vector3
var grid_boundary_max: Vector3

# ==================== ПЕРЕМЕННЫЕ ВИЗУАЛЬНЫХ ЭФФЕКТОВ ====================
var trajectory_markers: Array[MeshInstance3D] = []
var preview_color: Color = Color(0.2, 0.6, 1.0, 0.4)
var preview_material: StandardMaterial3D

# ==================== ПЕРЕМЕННЫЕ ОСВЕЩЕНИЯ ====================
var lights_container: Node3D
var fill_light: OmniLight3D
var accent_lights: Node3D
var reflection_probe: ReflectionProbe

# ==================== МЕНЮ ПАУЗЫ И НАСТРОЕК ====================
var pause_menu = null
var settings_menu_instance: CanvasLayer = null
var is_paused = false
var is_settings_visible = false
var original_settings = {}

# ==================== ФУНКЦИИ ИНИЦИАЛИЗАЦИИ ====================
func _ready():
	print("=== ИНИЦИАЛИЗАЦИЯ СЦЕНЫ ДРОНА ===")
	
	# Базовые настройки
	create_wooden_floor()
	load_room_for_level(Global.current_level)
	setup_additional_lighting()
	add_reflection_probe()
	
	# Камера
	camera.far = 100000.0
	
	# Границы и сетка
	calculate_grid_boundaries()
	create_preview_material()
	
	# Загрузка настроек и создание объектов
	load_settings()
	create_drone()
	create_grid()
	create_table()
	create_grid_highlight()
	
	# UI и кнопки
	block_ui.hide()
	update_camera_position()
	connect_buttons()
	
	# Таймер
	setup_timer()
	
	# Игровые настройки
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Сцена готова! Сетка: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT, " клеток")
	print("Границы сетки: от ", grid_boundary_min, " до ", grid_boundary_max)

# ==================== СИСТЕМА КОМНАТ ====================
func load_room_for_level(level: int):
	print("🔄 Загружаем комнату для уровня: ", level)
	
	var config = level_room_configs.get(level, [0, Vector3(2000, 2000, 2000), Vector3(3200, -1000, -16)])
	var room_index = clamp(config[0], 0, ROOM_PATHS.size() - 1)
	var room_scale = config[1]
	var room_position = config[2]
	var room_path = ROOM_PATHS[room_index]
	
	var room_scene = load(room_path)
	if room_scene:
		var room_instance = room_scene.instantiate()
		room_instance.scale = room_scale
		room_instance.position = room_position
		add_child(room_instance)
		print("✅ Загружена комната: ", room_path)
	else:
		print("❌ Не удалось загрузить комнату: ", room_path)

# ==================== СИСТЕМА ГРАНИЦ ====================
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

# ==================== СИСТЕМА ПРЕДПРОСМОТРА ТРАЕКТОРИИ ====================
func update_trajectory_preview(sequence: Array):
	clear_trajectory_preview()
	if not current_drone or sequence.is_empty():
		return
	
	print("🔄 Обновляем предпросмотр траектории для ", sequence.size(), " команд")
	var current_pos = current_drone.global_position
	var visited_cells = {}
	
	create_trajectory_marker(current_pos, true)
	visited_cells[vector2_to_key(current_pos.x, current_pos.z)] = true
	
	for i in range(sequence.size()):
		var direction = sequence[i]
		var next_pos = calculate_next_position(current_pos, direction)
		var cell_key = vector2_to_key(next_pos.x, next_pos.z)
		var is_new_cell = not visited_cells.has(cell_key)
		
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

func clear_trajectory_preview():
	for marker in trajectory_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	trajectory_markers.clear()
	print("🧹 Предпросмотр траектории очищен")

func vector2_to_key(x: float, z: float) -> String:
	return "%.1f_%.1f" % [x, z]

# ==================== СИСТЕМА ТАЙМЕРА ====================
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

# ==================== СИСТЕМА РЕЗУЛЬТАТОВ ====================
func _on_program_finished(success: bool):
	print("🎯 Программа завершена, успех: ", success)
	var final_time = stop_timer()
	
	if success:
		print("🎉 Уровень пройден! Время: ", final_time)
		print("📊 Текущий уровень: ", Global.current_level)
		print("⏱️ Текущее время (мс): ", current_time_ms)
		
		# Получаем результат завершения уровня
		var result = Global.complete_level(Global.current_level, current_time_ms)
		print("📈 Результат от Global.complete_level: ", result)
		
		# Проверяем, что результат содержит нужные данные
		if result.has("stars") and result.has("reward"):
			print("✅ Данные результата корректны, показываем сообщение")
			print("   Звезды: ", result["stars"])
			print("   Награда: ", result["reward"])
			print("   Базовая награда: ", result.get("base_reward", 0))
			print("   Бонус: ", result.get("bonus", 0))
			
			show_success_message(final_time, current_time_ms, result)
		else:
			print("❌ Ошибка: результат не содержит ожидаемых данных!")
			print("   result: ", result)
			
			# Создаем заглушку для теста
			var test_result = {
				"stars": 3,
				"reward": 100,
				"base_reward": 100,
				"bonus": 0
			}
			print("🔄 Используем тестовые данные: ", test_result)
			show_success_message(final_time, current_time_ms, test_result)
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
	
	# Главный контейнер для центрирования всей панели
	var main_center_container = CenterContainer.new()
	main_center_container.name = "MainCenterContainer"
	main_center_container.size = get_viewport().get_visible_rect().size
	main_center_container.anchor_left = 0.5
	main_center_container.anchor_right = 0.5
	main_center_container.anchor_top = 0.5
	main_center_container.anchor_bottom = 0.5
	main_center_container.offset_left = -350  # Половина ширины панели
	main_center_container.offset_right = 350
	main_center_container.offset_top = -275  # Половина высоты панели
	main_center_container.offset_bottom = 275
	
	var panel = Panel.new()
	panel.name = "SuccessPanel"
	panel.size = Vector2(700, 550)
	
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
	
	# Внутренний контейнер для содержимого панели
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.size = panel.size
	content_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_theme_constant_override("separation", 20)
	
	# Заголовок
	var title_container = CenterContainer.new()
	title_container.custom_minimum_size = Vector2(650, 50)
	
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = get_success_title(result["stars"])
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", get_star_color(result["stars"]))
	
	title_container.add_child(title_label)
	content_container.add_child(title_container)
	
	# Звезды
	var stars_container = CenterContainer.new()
	stars_container.custom_minimum_size = Vector2(650, 100)
	
	var stars_inner_container = HBoxContainer.new()
	stars_inner_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_inner_container.add_theme_constant_override("separation", 20)
	
	var stars_earned = result["stars"]
	
	for i in range(3):
		var star_frame = CenterContainer.new()
		star_frame.custom_minimum_size = Vector2(80, 80)
		var star_label = Label.new()
		star_label.add_theme_font_size_override("font_size", 64)
		
		if i < stars_earned:
			star_label.text = "★"
			star_label.add_theme_color_override("font_color", Color.GOLD)
			star_label.scale = Vector2(1.2, 1.2)
		else:
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", Color.DARK_GRAY)
			star_label.scale = Vector2(1.2, 1.2)
		
		star_frame.add_child(star_label)
		stars_inner_container.add_child(star_frame)
	
	stars_container.add_child(stars_inner_container)
	content_container.add_child(stars_container)
	
	# Время
	var time_container = CenterContainer.new()
	time_container.custom_minimum_size = Vector2(650, 50)
	
	var time_inner_container = HBoxContainer.new()
	time_inner_container.alignment = BoxContainer.ALIGNMENT_CENTER
	time_inner_container.add_theme_constant_override("separation", 10)
	
	var time_icon = Label.new()
	time_icon.text = "⏱️"
	time_icon.add_theme_font_size_override("font_size", 24)
	
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "Время: " + final_time
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	
	time_inner_container.add_child(time_icon)
	time_inner_container.add_child(time_label)
	time_container.add_child(time_inner_container)
	content_container.add_child(time_container)
	
	# Награда
	var reward_container = CenterContainer.new()
	reward_container.custom_minimum_size = Vector2(650, 50)
	
	var reward_inner_container = HBoxContainer.new()
	reward_inner_container.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_inner_container.add_theme_constant_override("separation", 10)
	
	var reward_icon = Label.new()
	reward_icon.text = "💰"
	reward_icon.add_theme_font_size_override("font_size", 24)
	
	var reward_label = Label.new()
	reward_label.name = "RewardLabel"
	
	# Формируем текст награды
	var reward_text = ""
	var base_reward = result.get("base_reward", 0)
	var bonus = result.get("bonus", 0)
	var total_reward = result.get("reward", 0)
	
	if stars_earned > 0:
		if bonus > 0:
			reward_text = "+" + str(total_reward) + " очков (" + str(base_reward) + " за звезды + " + str(bonus) + " бонус за первое прохождение)"
		else:
			reward_text = "+" + str(total_reward) + " очков"
	else:
		reward_text = "0 очков (необходимо получить хотя бы 1 звезду)"
	
	reward_label.text = reward_text
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 24)
	
	if stars_earned > 0:
		reward_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		reward_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	reward_inner_container.add_child(reward_icon)
	reward_inner_container.add_child(reward_label)
	reward_container.add_child(reward_inner_container)
	content_container.add_child(reward_container)
	
	# Пороги времени для звезд
	var thresholds_container = CenterContainer.new()
	thresholds_container.custom_minimum_size = Vector2(650, 40)
	
	var thresholds_label = Label.new()
	thresholds_label.name = "ThresholdsLabel"
	
	var thresholds = Global.level_star_thresholds.get(Global.current_level, [0, 0, 0])
	thresholds_label.text = "Время для звезд: 3★ - %s, 2★ - %s, 1★ - %s" % [
		format_time_ms(thresholds[0]),
		format_time_ms(thresholds[1]), 
		format_time_ms(thresholds[2])
	]
	thresholds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thresholds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thresholds_label.add_theme_font_size_override("font_size", 16)
	thresholds_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	
	thresholds_container.add_child(thresholds_label)
	content_container.add_child(thresholds_container)
	
	# Кнопка продолжения
	var button_container = CenterContainer.new()
	button_container.custom_minimum_size = Vector2(650, 60)
	
	var continue_button = Button.new()
	continue_button.text = "Продолжить"
	continue_button.custom_minimum_size = Vector2(200, 50)
	continue_button.add_theme_font_size_override("font_size", 20)
	continue_button.pressed.connect(_on_continue_pressed.bind(canvas))
	
	button_container.add_child(continue_button)
	content_container.add_child(button_container)
	
	# Добавляем контент в панель
	panel.add_child(content_container)
	
	# Добавляем панель в главный контейнер центрирования
	main_center_container.add_child(panel)
	
	# Собираем всю иерархию
	overlay.add_child(main_center_container)
	canvas.add_child(overlay)
	add_child(canvas)
	
	print("✅ Финальный экран создан. Звезды: ", stars_earned, ", Награда: ", total_reward, ", Бонус: ", bonus)
	
	# Запускаем анимацию звезд после создания интерфейса
	if stars_earned > 0:
		if bonus > 0:
			reward_text = "+" + str(total_reward) + " очков (" + str(base_reward) + " за звезды + " + str(bonus) + " бонус за первое прохождение)"
		else:
			reward_text = "+" + str(total_reward) + " очков"
	else:
		reward_text = "0 очков (необходимо получить хотя бы 1 звезду)"

func animate_stars(stars_container: HBoxContainer, stars_earned: int):
	for i in range(stars_earned):
		if i < stars_container.get_child_count():
			var star_frame = stars_container.get_child(i) as CenterContainer
			if star_frame and star_frame.get_child_count() > 0:
				var star_label = star_frame.get_child(0) as Label
				if star_label:
					# Ждем задержку перед анимацией каждой звезды
					await get_tree().create_timer(i * 0.2).timeout
					
					# Анимация звезды
					var tween = create_tween()
					tween.tween_property(star_label, "scale", Vector2(1.5, 1.5), 0.5)
					tween.tween_property(star_label, "scale", Vector2(1.2, 1.2), 0.3)
func get_success_title(stars: int) -> String:
	match stars:
		3: return "🎉 ИДЕАЛЬНО! 3 ЗВЕЗДЫ! 🎉"
		2: return "✨ ОТЛИЧНО! 2 ЗВЕЗДЫ! ✨"
		1: return "👍 ХОРОШО! 1 ЗВЕЗДА! 👍"
		_: return "УРОВЕНЬ ПРОЙДЕН"

func get_star_color(stars: int) -> Color:
	match stars:
		3: return Color.GOLD
		2: return Color.SILVER
		1: return Color.ORANGE
		_: return Color.GREEN

func _on_continue_pressed(canvas: CanvasLayer):
	if canvas and is_instance_valid(canvas):
		canvas.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	return_to_selection()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://UI/game_level.tscn")

# ==================== СИСТЕМА ДРОНА ====================
func create_drone():
	print("🔧 Создаем дрон...")
	for child in drone_container.get_children():
		child.queue_free()
	
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
	var aligned_x = round((START_POINT_X + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	@warning_ignore("integer_division")
	var aligned_z = round((START_POINT_Z + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	return Vector3(aligned_x, START_POINT_Y, aligned_z)

func set_drone_height(height: float):
	print("🔄 Устанавливаем высоту дрона: ", height)
	if current_drone:
		var new_pos = current_drone.global_position
		new_pos.y = height
		current_drone.global_position = new_pos
		print("✅ Высота дрона установлена: ", new_pos)

func get_drone_height() -> float:
	return START_POINT_Y

func adjust_drone_height(relative_change: float):
	var new_height = START_POINT_Y + relative_change
	set_drone_height(new_height)

func setup_drone(drone_node: CharacterBody3D):
	print("🔧 Настраиваем дрон...")
	var start_pos = calculate_start_position()
	if not is_position_within_bounds(start_pos):
		start_pos = clamp_position_to_bounds(start_pos)
		print("⚠️ Стартовая позиция скорректирована: ", start_pos)
	
	drone_node.global_position = start_pos
	drone_node.scale = Vector3(6, 6, 6)
	
	var target_pos = Vector3(GRID_SIZE * 2, 0, GRID_SIZE * 2)
	if drone_node.has_method("set_target_position"):
		drone_node.set_target_position(target_pos)
		print("🎯 Установлена целевая позиция для дрона: ", target_pos)
	
	add_collision_if_needed(drone_node)
	drone_node.collision_layer = 1
	drone_node.collision_mask = 1
	
	if drone_node.has_signal("drone_moved"):
		drone_node.drone_moved.connect(on_drone_moved)
	if drone_node.has_signal("program_finished"):
		drone_node.program_finished.connect(_on_program_finished)
		print("✅ Сигнал program_finished подключен")
	
	if drone_node.has_method("set_boundaries"):
		drone_node.set_boundaries(grid_boundary_min, grid_boundary_max)
		print("✅ Границы установлены для дрона")
	
	print("✅ Дрон настроен: ", drone_node.name)

func add_collision_if_needed(drone_node: CharacterBody3D):
	if drone_node.get_node_or_null("CollisionShape3D") == null:
		print("➕ Добавляем коллизию дрону...")
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(6, 1.5, 6)
		collision.shape = shape
		collision.position = Vector3(0, 0.75, 0)
		drone_node.add_child(collision)
		collision.owner = get_tree().edited_scene_root
		print("✅ Добавлена коллизия дрону")

func create_default_drone():
	print("🔧 Создаем дрон по умолчанию...")
	current_drone = create_default_character_drone()

func create_default_character_drone() -> CharacterBody3D:
	var drone_node = CharacterBody3D.new()
	drone_node.name = "DefaultDrone"
	
	var drone_script = load("res://DroneLevels/Drone.gd")
	if drone_script:
		drone_node.set_script(drone_script)
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4, 1, 4)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.2, 0.2)
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

# ==================== СИСТЕМА СЕТКИ И ВИЗУАЛЬНЫХ ЭФФЕКТОВ ====================
func create_grid():
	var grid = $Grid
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.albedo_color = Color(0.3, 0.3, 0.3)
	for child in grid.get_children():
		child.queue_free()
	
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

func update_grid_highlight():
	if not current_drone or not grid_highlight:
		return
	
	var drone_pos = current_drone.global_position
	if is_position_within_bounds(drone_pos):
		grid_highlight.global_position = Vector3(drone_pos.x, 0.15, drone_pos.z)
		grid_highlight.visible = true
		highlight_mesh.material_override.albedo_color = Global.highlight_color
		highlight_mesh.material_override.emission = Global.highlight_color * 0.6
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
	var floor_node = $Floor
	if floor_node:
		var mesh_instance = floor_node.get_node("MeshInstance3D")
		if mesh_instance:
			var floor_material = StandardMaterial3D.new()
			floor_material.albedo_color = Color(0.35, 0.25, 0.15)
			floor_material.metallic = 0.1
			floor_material.roughness = 0.7
			
			var wood_texture = load("res://room3d/textures/wood.jpg")
			if wood_texture:
				floor_material.albedo_texture = wood_texture
				floor_material.uv1_scale = Vector3(16, 16, 16)
			
			mesh_instance.material_override = floor_material
			print("✅ Деревянный пол создан")

func start_trail_fade(trail_mesh: MeshInstance3D):
	var trail_index = trail_meshes.find(trail_mesh)
	var tween = create_tween()
	tween.tween_property(trail_mesh, "scale", Vector3(0.5, 0.5, 0.5), TRAIL_FADE_TIME * 0.7)
	tween.parallel().tween_property(trail_mesh.material_override, "albedo_color:a", 0.0, TRAIL_FADE_TIME)
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

# ==================== СИСТЕМА УПРАВЛЕНИЯ КАМЕРОЙ ====================
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_settings_visible and settings_menu_instance:
			print("📋 Нажата ESC в меню настроек - отменяем изменения")
			settings_menu_instance._on_cancel_pressed()
			get_viewport().set_input_as_handled()
			return
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
			-mouse_delta.y * ROTATION_SPEED * Global.mouse_sensitivity * 0.5,
			-mouse_delta.x * ROTATION_SPEED * Global.mouse_sensitivity * 0.5
		)
		rotation_velocity.x = clamp(rotation_velocity.x, -MAX_VELOCITY, MAX_VELOCITY)
		rotation_velocity.y = clamp(rotation_velocity.y, -MAX_VELOCITY, MAX_VELOCITY)
		camera_rotation.x += -mouse_delta.y * ROTATION_SPEED * Global.mouse_sensitivity
		camera_rotation.y += -mouse_delta.x * ROTATION_SPEED * Global.mouse_sensitivity
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

# ==================== СИСТЕМА UI И КНОПОК ====================
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
	
	if block_ui and block_ui.has_signal("trajectory_updated"):
		block_ui.trajectory_updated.connect(update_trajectory_preview)
		print("✅ Сигнал trajectory_updated подключен")
	
	print("✅ Все кнопки подключены")

func _on_programming_button_pressed():
	toggle_programming()

func _on_start_button_pressed():
	print("🟢 Запускаем программу дрона")
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
		clear_trajectory_preview()
		print("❌ Закрываем панель программирования")
	else:
		block_ui.show()
		programming_button.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if block_ui.has_method("get_program_sequence"):
			var sequence = block_ui.get_program_sequence()
			update_trajectory_preview(sequence)
		print("🧩 Открываем панель программирования")

# ==================== МЕНЮ ПАУЗЫ ====================
func create_pause_menu():
	pause_menu = ColorRect.new()
	pause_menu.color = Color(0, 0, 0, 0.7)
	pause_menu.size = get_viewport().size
	pause_menu.visible = false
	
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size = Vector2(400, 350)
	
	var viewport_size = Vector2(get_viewport().size)
	container.position = (viewport_size - container.size) / 2
	
	var title = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	
	var resume_btn = Button.new()
	resume_btn.text = "Продолжить"
	resume_btn.custom_minimum_size = Vector2(300, 50)
	resume_btn.pressed.connect(toggle_pause_menu)
	
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
	
	container.add_child(title)
	container.add_child(resume_btn)
	container.add_child(settings_btn)
	container.add_child(main_menu_btn)
	container.add_child(quit_btn)
	
	pause_menu.add_child(container)
	add_child(pause_menu)

# ==================== ОТДЕЛЬНАЯ СЦЕНА НАСТРОЕК ====================
# ==================== ОТДЕЛЬНАЯ СЦЕНА НАСТРОЕК ====================
func open_settings():
	print("🔄 Открываем настройки...")
	
	# Если меню настроек уже открыто, ничего не делаем
	if is_settings_visible and settings_menu_instance:
		print("⚠️ Меню настроек уже открыто")
		return
	
	# Загружаем сцену настроек если еще не загружена
	if settings_menu_instance == null:
		print("📥 Загружаем сцену настроек...")
		var settings_scene = load("res://UI/SettingsScene.tscn")
		if settings_scene:
			settings_menu_instance = settings_scene.instantiate()
			add_child(settings_menu_instance)
			
			# Подключаем сигналы от сцены настроек
			settings_menu_instance.settings_saved.connect(_on_settings_saved)
			settings_menu_instance.settings_cancelled.connect(_on_settings_cancelled)
			settings_menu_instance.settings_closed.connect(_on_settings_closed)
			print("✅ Сцена настроек загружена и добавлена")
		else:
			print("❌ Не удалось загрузить сцену настроек")
			return
	
	# Открываем меню настроек
	if settings_menu_instance.has_method("open"):
		settings_menu_instance.open()
		is_settings_visible = true
		
		# Ставим игру на паузу, если она еще не на паузе
		if not is_paused:
			toggle_pause_menu_silent()  # Специальная функция для бесшумной паузы
		
		# Скрываем меню паузы если оно открыто
		if pause_menu and pause_menu.visible:
			pause_menu.visible = false
			print("📋 Скрыли меню паузы")
		
		print("⚙️ Меню настроек открыто, игра на паузе")
	else:
		print("❌ Сцена настроек не имеет метода open()")

func close_settings():
	print("🔄 Закрываем настройки...")
	
	if settings_menu_instance and settings_menu_instance.has_method("close"):
		settings_menu_instance.close()
	
	is_settings_visible = false
	
	# Если игра была на паузе до открытия настроек, показываем меню паузы
	if is_paused and pause_menu:
		pause_menu.visible = true
		print("📋 Показали меню паузы")
	else:
		# Если игра не на паузе, снимаем паузу (на всякий случай)
		if is_paused:
			toggle_pause_menu_silent()
	
	print("✅ Меню настроек закрыто")

# ==================== УПРАВЛЕНИЕ ПАУЗОЙ (новые функции) ====================
func toggle_pause_menu_silent():
	"""Переключает паузу без показа/скрытия меню паузы"""
	is_paused = !is_paused
	
	if is_paused and is_timer_running:
		timer.paused = true
		print("⏸️ Таймер на паузе (бесшумно)")
	elif not is_paused and is_timer_running:
		timer.paused = false
		print("▶️ Таймер возобновлен (бесшумно)")
	
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("⏸️ Игра на паузе (бесшумно)")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("▶️ Игра продолжается (бесшумно)")
	
	get_tree().paused = is_paused

func toggle_pause_menu():
	print("🔄 Нажата кнопка ESC, текущая пауза:", is_paused)
	
	# Если открыты настройки - закрываем их
	if is_settings_visible and settings_menu_instance:
		print("📋 Закрываем настройки вместо паузы")
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

func _on_settings_saved():
	print("✅ Настройки сохранены (сигнал получен)")
	# Применяем настройки к текущей сцене
	apply_settings()
	
	# Закрываем меню настроек и автоматически снимаем паузу
	close_settings()
	if is_paused:
		toggle_pause_menu()
	print("🎮 Игра продолжается после сохранения настроек")

func _on_settings_cancelled():
	print("↩️ Изменения настроек отменены (сигнал получен)")
	# Закрываем меню настроек и показываем меню паузы
	close_settings()
	print("📋 Возвращаемся в меню паузы")

func _on_settings_closed():
	print("📋 Меню настроек закрыто (сигнал получен)")
	is_settings_visible = false
	# Если игра на паузе и меню паузы не видно, показываем его
	if is_paused and pause_menu and not pause_menu.visible:
		pause_menu.visible = true
		print("📋 Показали меню паузы после закрытия настроек")

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_scene.tscn")

func quit_game():
	get_tree().quit()

# ==================== СИСТЕМА НАСТРОЕК ====================
func save_settings():
	# Теперь сохраняется через Global.gd
	Global.save_global_settings()

func load_settings():
	Global.load_global_settings()
	apply_settings()

func apply_settings():
	# Применяем настройки из Global.gd
	camera.fov = Global.camera_fov
	camera.far = 100090.0
	
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = Global.brightness
	
	if highlight_mesh and highlight_mesh.material_override:
		highlight_mesh.material_override.albedo_color = Global.highlight_color
	
	Global.apply_global_settings()

# ==================== СИСТЕМА ОСВЕЩЕНИЯ ====================
func setup_additional_lighting():
	lights_container = Node3D.new()
	lights_container.name = "AdditionalLights"
	add_child(lights_container)
	setup_fill_light()
	setup_accent_lights()
	print("✅ Дополнительное освещение настроено")

func setup_fill_light():
	fill_light = OmniLight3D.new()
	fill_light.name = "FillLight"
	lights_container.add_child(fill_light)
	fill_light.position = Vector3(0, 30, 0)
	fill_light.light_color = Color(0.8, 0.85, 1)
	fill_light.light_energy = 0.4
	fill_light.omni_range = 60
	fill_light.shadow_enabled = false

func setup_accent_lights():
	accent_lights = Node3D.new()
	accent_lights.name = "AccentLights"
	lights_container.add_child(accent_lights)
	
	var half_size = (GRID_CELLS_COUNT * GRID_SIZE) / 2
	var table_width = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_depth = GRID_CELLS_COUNT * GRID_SIZE + 100
	
	var corner_positions = [
		Vector3(-table_width/2 + 50, 15, -table_depth/2 + 50),
		Vector3(table_width/2 - 50, 15, -table_depth/2 + 50),
		Vector3(-table_width/2 + 50, 15, table_depth/2 - 50),
		Vector3(table_width/2 - 50, 15, table_depth/2 - 50)
	]
	
	for i in range(corner_positions.size()):
		var spot_light = SpotLight3D.new()
		spot_light.name = "AccentLight_%d" % i
		accent_lights.add_child(spot_light)
		spot_light.position = corner_positions[i]
		spot_light.look_at(Vector3(0, 0, 0), Vector3.UP)
		spot_light.light_color = Color(0.9, 0.8, 1)
		spot_light.light_energy = 0.6
		spot_light.spot_range = 30
		spot_light.spot_angle = 45
		spot_light.shadow_enabled = false

func add_reflection_probe():
	reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "GameTableReflectionProbe"
	add_child(reflection_probe)
	reflection_probe.position = Vector3(0, 20, 0)
	reflection_probe.size = Vector3(100, 40, 100)
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	print("✅ Reflection probe добавлен для стола")

# ==================== СИСТЕМА СТОЛА ====================
func create_table():
	print("🔧 Создаем красивый игровой стол...")
	var table_node = MeshInstance3D.new()
	table_node.name = "GameTable"
	
	var table_width = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_depth = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_height = 15
	
	var table_mesh = BoxMesh.new()
	table_mesh.size = Vector3(table_width, table_height, table_depth)
	table_node.mesh = table_mesh
	table_node.position = Vector3(0, -table_height/2 - 2, 0)
	
	var table_material = StandardMaterial3D.new()
	table_material.albedo_color = Color(0.3, 0.2, 0.1)
	table_material.roughness = 0.7
	table_material.metallic = 0.1
	
	var wood_texture = load("res://room3d/textures/wood.jpg")
	if wood_texture:
		table_material.albedo_texture = wood_texture
		table_material.uv1_scale = Vector3(4, 4, 4)
		table_material.roughness_texture = wood_texture
		table_material.metallic_texture = wood_texture
	
	table_node.material_override = table_material
	add_child(table_node)
	table_node.owner = get_tree().edited_scene_root
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

# ==================== СИСТЕМА ПОДСВЕТКИ КЛЕТОК ====================
func create_grid_highlight():
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.85, 0.1, GRID_SIZE * 0.85)
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.mesh = box_mesh
	
	var highlight_material = StandardMaterial3D.new()
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Global.highlight_color
	highlight_material.emission_enabled = true
	highlight_material.emission = Global.highlight_color * 0.8
	highlight_material.emission_energy = 0.5
	highlight_material.metallic = 0.3
	highlight_material.roughness = 0.2
	
	highlight_mesh.material_override = highlight_material
	grid_highlight.add_child(highlight_mesh)
	highlight_mesh.owner = get_tree().edited_scene_root
	grid_highlight.visible = false
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(highlight_mesh.material_override, "emission", 
						Global.highlight_color * 1.2, 1.0)
	tween.tween_property(highlight_mesh.material_override, "emission", 
						Global.highlight_color * 0.8, 1.0)

func create_trail_marker(position: Vector3):
	if not is_position_within_bounds(position):
		return
	
	var trail_mesh = MeshInstance3D.new()
	add_child(trail_mesh)
	trail_mesh.owner = get_tree().edited_scene_root
	trail_mesh.global_position = Vector3(position.x, 0.08, position.z)
	
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = GRID_SIZE * 0.35
	cylinder_mesh.bottom_radius = GRID_SIZE * 0.35
	cylinder_mesh.height = 0.06
	trail_mesh.mesh = cylinder_mesh
	
	var trail_material = StandardMaterial3D.new()
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.albedo_color = Global.trail_color
	trail_material.emission_enabled = true
	trail_material.emission = Global.trail_color * 0.3
	trail_mesh.material_override = trail_material
	
	trail_meshes.append(trail_mesh)
	
	if trail_meshes.size() > MAX_TRAIL_LENGTH:
		var oldest_trail = trail_meshes.pop_front()
		if is_instance_valid(oldest_trail):
			oldest_trail.queue_free()
	
	start_trail_fade(trail_mesh)

func create_preview_material():
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	preview_material.emission_enabled = true
	preview_material.emission = Color(0.3, 0.7, 1.0, 0.3)

func create_trajectory_marker(position: Vector3, is_start: bool):
	var marker = MeshInstance3D.new()
	add_child(marker)
	marker.owner = get_tree().edited_scene_root
	marker.global_position = Vector3(position.x, 0.08, position.z)
	
	var cylinder_mesh = CylinderMesh.new()
	if is_start:
		cylinder_mesh.top_radius = GRID_SIZE * 0.4
		cylinder_mesh.bottom_radius = GRID_SIZE * 0.4
		cylinder_mesh.height = 0.12
	else:
		cylinder_mesh.top_radius = GRID_SIZE * 0.35
		cylinder_mesh.bottom_radius = GRID_SIZE * 0.35
		cylinder_mesh.height = 0.1
	
	marker.mesh = cylinder_mesh
	
	var marker_material = preview_material.duplicate()
	if is_start:
		marker_material.albedo_color = Color(0.2, 1.0, 0.3, 0.7)
		marker_material.emission = Color(0.2, 1.0, 0.3, 0.4)
	else:
		marker_material.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	
	marker.material_override = marker_material
	trajectory_markers.append(marker)

# ==================== СИСТЕМА КАМЕРЫ ====================
func update_camera_position():
	var camera_position = Vector3(
		sin(camera_rotation.y) * cos(camera_rotation.x),
		sin(camera_rotation.x),
		cos(camera_rotation.y) * cos(camera_rotation.x)
	) * camera_distance
	camera.position = camera_position
	camera.look_at(camera_pivot.global_position, Vector3.UP)
	
	var time = Time.get_ticks_msec() / 1000.0
	camera.h_offset = sin(time * 0.5) * 0.01
	camera.v_offset = cos(time * 0.3) * 0.01
