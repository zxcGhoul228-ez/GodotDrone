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
const MIN_CAMERA_HEIGHT = 18.0
const TABLE_PLAY_PADDING = 56.0
const CAMERA_WORLD_MIN_OFFSET = 22.0
const START_POINT_X = 0
const START_POINT_Z = 0
const START_POINT_Y = 0.0 # спавн на уровне пола (y=0)
const HIGHLIGHT_COLOR_WARNING = Color(1.0, 0.3, 0.3, 0.7)
const LEVEL_ONE_HINT_TEXT = "Для первого уровня хватит простого маршрута: 3 вправо, 3 назад, 1 вниз."

# ==================== ПУТИ К КОМНАТАМ ====================
const ROOM_PATHS = [
	"res://content/environments/room3d/source/room1.glb",
	"res://content/environments/room3d/room2/source/chicken_gun_standoff_2_arena.glb",
	"res://content/environments/room3d/room3/source/Scene 1 - RealRoom.glb"
]

# ==================== КОНФИГУРАЦИЯ КОМНАТ ПО УРОВНЯМ ====================
const LOCATION_ROOM_PROFILES = [
	{
		"room_index": 0,
		"scale": Vector3(700, 700, 700),
		"position": Vector3(-600, -200, -200),
		"background_color": Color(0.23, 0.19, 0.15),
		"background_energy": 0.90,
		"ambient_color": Color(0.58, 0.48, 0.40),
		"ambient_energy": 0.88,
		"adjustment_brightness": 1.08,
		"adjustment_contrast": 1.08,
		"adjustment_saturation": 0.92,
		"glow_strength": 0.04,
		"glow_threshold": 1.56,
		"sun_color": Color(0.92, 0.77, 0.58),
		"sun_energy": 0.98,
		"sun_rotation": Vector3(-28.0, 36.0, 0.0),
		"fill_color": Color(0.48, 0.35, 0.24),
		"fill_energy": 0.24,
		"fill_range": 60.0,
		"accent_color": Color(0.94, 0.74, 0.52),
		"accent_energy": 0.22,
		"accent_range": 34.0,
		"accent_height": 16.0,
		"table_color": Color(0.25, 0.18, 0.12),
		"table_emission": Color(0.02, 0.015, 0.01),
		"table_roughness": 0.88,
		"leg_color": Color(0.09, 0.08, 0.07),
		"floor_color": Color(0.17, 0.12, 0.09),
		"floor_roughness": 0.92,
		"room_tint": Color(0.88, 0.84, 0.80)
	},
	{
		"room_index": 1,
		"scale": Vector3(20000, 20000, 20000),
		"position": Vector3(0, -40, 500),
		"background_color": Color(0.22, 0.17, 0.13),
		"background_energy": 0.92,
		"ambient_color": Color(0.58, 0.46, 0.37),
		"ambient_energy": 0.90,
		"adjustment_brightness": 1.08,
		"adjustment_contrast": 1.10,
		"adjustment_saturation": 0.94,
		"glow_strength": 0.04,
		"glow_threshold": 1.54,
		"sun_color": Color(0.96, 0.76, 0.53),
		"sun_energy": 1.00,
		"sun_rotation": Vector3(-33.0, 72.0, 0.0),
		"fill_color": Color(0.50, 0.34, 0.22),
		"fill_energy": 0.25,
		"fill_range": 64.0,
		"accent_color": Color(0.91, 0.68, 0.44),
		"accent_energy": 0.24,
		"accent_range": 36.0,
		"accent_height": 18.0,
		"table_color": Color(0.24, 0.17, 0.11),
		"table_emission": Color(0.02, 0.015, 0.01),
		"table_roughness": 0.90,
		"leg_color": Color(0.10, 0.08, 0.07),
		"floor_color": Color(0.16, 0.11, 0.08),
		"floor_roughness": 0.94,
		"room_tint": Color(0.86, 0.82, 0.78)
	},
	{
		"room_index": 2,
		"scale": Vector3(1000, 1000, 1000),
		"position": Vector3(-2000, -80, 2000),
		"background_color": Color(0.21, 0.18, 0.16),
		"background_energy": 0.88,
		"ambient_color": Color(0.54, 0.47, 0.41),
		"ambient_energy": 0.86,
		"adjustment_brightness": 1.06,
		"adjustment_contrast": 1.08,
		"adjustment_saturation": 0.90,
		"glow_strength": 0.035,
		"glow_threshold": 1.60,
		"sun_color": Color(0.88, 0.77, 0.66),
		"sun_energy": 0.94,
		"sun_rotation": Vector3(-24.0, -28.0, 0.0),
		"fill_color": Color(0.40, 0.34, 0.30),
		"fill_energy": 0.22,
		"fill_range": 56.0,
		"accent_color": Color(0.83, 0.69, 0.56),
		"accent_energy": 0.20,
		"accent_range": 30.0,
		"accent_height": 15.0,
		"table_color": Color(0.22, 0.16, 0.12),
		"table_emission": Color(0.018, 0.014, 0.01),
		"table_roughness": 0.92,
		"leg_color": Color(0.09, 0.08, 0.07),
		"floor_color": Color(0.15, 0.12, 0.10),
		"floor_roughness": 0.96,
		"room_tint": Color(0.84, 0.81, 0.78)
	}
]

# ==================== ССЫЛКИ НА НОДЫ ====================
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var drone_container: Node3D = $DroneContainer
@onready var block_ui: Panel = $UI/BlockProgramming
@onready var programming_button: Button = $UI/Control/ProgrammingButton
@onready var grid_highlight: Node3D = $GridHighlight

# ==================== ПЕРЕМЕННЫЕ ТАЙМЕРА ====================
var timer_ui: Control
var timer_label: Label
var timer: Timer
var start_time: int
var current_time_ms: int
var is_timer_running: bool = false
var best_time_ms: int = 0
var best_time_label: Label

# ==================== ОСНОВНЫЕ ПЕРЕМЕННЫЕ ====================
var camera_rotation = Vector2(0.58, -0.82)
var camera_distance = 182.0
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
var current_room_instance: Node3D = null
var current_location_profile: Dictionary = {}
var current_location_index: int = 0
var floor_material_instance: StandardMaterial3D = null
var table_material_instance: StandardMaterial3D = null
var table_leg_material_instance: StandardMaterial3D = null
var table_node_instance: MeshInstance3D = null

# ==================== МЕНЮ ПАУЗЫ И НАСТРОЕК ====================
var pause_menu = null
var pause_panel_root: VBoxContainer = null
var pause_panel_ref: Panel = null
var pause_margin_ref: MarginContainer = null
var pause_stats_summary_label: Label = null
var pause_stats_top_label: Label = null
var settings_menu_instance = null
var is_paused = false
var is_settings_visible = false
var original_settings = {}
var _result_window_open: bool = false

# ==================== ФУНКЦИИ ИНИЦИАЛИЗАЦИИ ====================
func _ready():
	print("📄 DroneScene script: ", get_script().resource_path)
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
	_apply_location_visual_profile()
	apply_settings()
	create_grid_highlight()
	
	# UI и кнопки
	block_ui.hide()
	update_camera_position()
	_apply_programming_ui_theme()
	connect_buttons()
	
	# Таймер
	setup_timer()
	
	# Игровые настройки
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Сцена готова! Сетка: ", GRID_CELLS_COUNT, "x", GRID_CELLS_COUNT, " клеток")
	print("Границы сетки: от ", grid_boundary_min, " до ", grid_boundary_max)

# ==================== СИСТЕМА КОМНАТ ====================
	_tutorial_setup_level()

func load_room_for_level(level: int):
	if current_room_instance != null and is_instance_valid(current_room_instance):
		current_room_instance.queue_free()
		current_room_instance = null
	print("🔄 Загружаем комнату для уровня: ", level)
	
	current_location_index = posmod(level - 1, LOCATION_ROOM_PROFILES.size())
	var profile_variant: Variant = LOCATION_ROOM_PROFILES[current_location_index]
	if typeof(profile_variant) == TYPE_DICTIONARY:
		var location_profile: Dictionary = profile_variant
		current_location_profile = location_profile.duplicate(true)
	else:
		current_room_instance = null
		current_location_profile = {}

	var room_index: int = clampi(int(current_location_profile.get("room_index", 0)), 0, ROOM_PATHS.size() - 1)
	var room_scale: Vector3 = current_location_profile.get("scale", Vector3.ONE)
	var room_position: Vector3 = current_location_profile.get("position", Vector3.ZERO)
	var room_path: String = ROOM_PATHS[room_index]
	
	var room_scene: PackedScene = load(room_path)
	if room_scene != null:
		var room_instance: Node = room_scene.instantiate()
		if room_instance is Node3D:
			current_room_instance = room_instance as Node3D
			current_room_instance.name = "LevelLocation"
			current_room_instance.scale = room_scale
			current_room_instance.position = room_position
			add_child(current_room_instance)
		print("✅ Загружена комната: ", room_path)
	else:
		print("❌ Не удалось загрузить комнату: ", room_path)

# ==================== СИСТЕМА ГРАНИЦ ====================
func _apply_location_visual_profile():
	if current_location_profile.is_empty():
		return

	var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment: Environment = world_environment.environment
		environment.background_color = current_location_profile.get("background_color", environment.background_color)
		environment.background_energy_multiplier = float(current_location_profile.get("background_energy", environment.background_energy_multiplier))
		environment.ambient_light_color = current_location_profile.get("ambient_color", environment.ambient_light_color)
		environment.ambient_light_energy = float(current_location_profile.get("ambient_energy", environment.ambient_light_energy))
		environment.fog_enabled = false
		environment.glow_strength = float(current_location_profile.get("glow_strength", environment.glow_strength))
		environment.glow_hdr_threshold = float(current_location_profile.get("glow_threshold", environment.glow_hdr_threshold))
		environment.adjustment_enabled = true
		environment.adjustment_brightness = float(current_location_profile.get("adjustment_brightness", environment.adjustment_brightness))
		environment.adjustment_contrast = float(current_location_profile.get("adjustment_contrast", environment.adjustment_contrast))
		environment.adjustment_saturation = float(current_location_profile.get("adjustment_saturation", environment.adjustment_saturation))

	var sun_light: DirectionalLight3D = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun_light != null:
		sun_light.light_color = current_location_profile.get("sun_color", sun_light.light_color)
		sun_light.light_energy = float(current_location_profile.get("sun_energy", sun_light.light_energy))
		var sun_rotation: Vector3 = current_location_profile.get("sun_rotation", sun_light.rotation_degrees)
		sun_light.rotation_degrees = sun_rotation

	if fill_light != null:
		fill_light.light_color = current_location_profile.get("fill_color", fill_light.light_color)
		fill_light.light_energy = float(current_location_profile.get("fill_energy", fill_light.light_energy))
		fill_light.omni_range = float(current_location_profile.get("fill_range", fill_light.omni_range))

	if accent_lights != null:
		var accent_color: Color = current_location_profile.get("accent_color", Color(0.90, 0.75, 0.50))
		var accent_energy: float = float(current_location_profile.get("accent_energy", 0.3))
		var accent_range: float = float(current_location_profile.get("accent_range", 38.0))
		var accent_height: float = float(current_location_profile.get("accent_height", 16.0))
		for accent_node in accent_lights.get_children():
			var accent_light: SpotLight3D = accent_node as SpotLight3D
			if accent_light == null:
				continue
			accent_light.light_color = accent_color
			accent_light.light_energy = accent_energy
			accent_light.spot_range = accent_range
			accent_light.position.y = accent_height
			accent_light.look_at(Vector3(0, 0, 0), Vector3.UP)

	if table_material_instance != null:
		table_material_instance.albedo_color = current_location_profile.get("table_color", table_material_instance.albedo_color)
		table_material_instance.emission_enabled = true
		table_material_instance.emission = current_location_profile.get("table_emission", Color(0.18, 0.11, 0.06))
		table_material_instance.roughness = float(current_location_profile.get("table_roughness", table_material_instance.roughness))

	if table_leg_material_instance != null:
		table_leg_material_instance.albedo_color = current_location_profile.get("leg_color", table_leg_material_instance.albedo_color)

	if floor_material_instance != null:
		floor_material_instance.albedo_color = current_location_profile.get("floor_color", floor_material_instance.albedo_color)
		floor_material_instance.roughness = float(current_location_profile.get("floor_roughness", floor_material_instance.roughness))

	_apply_room_material_focus(current_location_profile.get("room_tint", Color(0.32, 0.27, 0.23)))

func _apply_room_material_focus(tint: Color) -> void:
	if current_room_instance == null or not is_instance_valid(current_room_instance):
		return

	var tint_strength: float = 0.30
	var brighten_amount: float = 0.06

	for child in current_room_instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance == null:
			continue

		if mesh_instance.material_override is BaseMaterial3D:
			var override_material: BaseMaterial3D = (mesh_instance.material_override as BaseMaterial3D).duplicate()
			var override_base: Color = override_material.albedo_color
			var override_tinted: Color = override_base.lerp(override_base * tint, tint_strength).lightened(brighten_amount)
			override_material.albedo_color = override_tinted
			override_material.emission_enabled = false
			override_material.roughness = maxf(override_material.roughness, 0.72)
			mesh_instance.material_override = override_material
			continue

		if mesh_instance.mesh == null:
			continue

		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			if source_material is BaseMaterial3D:
				var focused_material: BaseMaterial3D = (source_material as BaseMaterial3D).duplicate()
				var focused_base: Color = focused_material.albedo_color
				var focused_tinted: Color = focused_base.lerp(focused_base * tint, tint_strength).lightened(brighten_amount)
				focused_material.albedo_color = focused_tinted
				focused_material.emission_enabled = false
				focused_material.roughness = maxf(focused_material.roughness, 0.72)
				mesh_instance.set_surface_override_material(surface_index, focused_material)

func calculate_grid_boundaries():
	var table_width: float = GRID_CELLS_COUNT * GRID_SIZE + 100.0
	var table_depth: float = GRID_CELLS_COUNT * GRID_SIZE + 100.0
	var half_width: float = table_width * 0.5 - TABLE_PLAY_PADDING
	var half_depth: float = table_depth * 0.5 - TABLE_PLAY_PADDING
	grid_boundary_min = Vector3(-half_width, 0.0, -half_depth)
	grid_boundary_max = Vector3(half_width, GRID_SIZE * 10, half_depth)

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
	var ui_root: CanvasLayer = $UI as CanvasLayer
	var panel: Panel = $UI/TimerUI as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "TimerUI"
		panel.position = Vector2(24, 22)
		ui_root.add_child(panel)

	timer_ui = panel
	panel.position = Vector2(24, 22)
	panel.size = Vector2(286, 108)
	panel.visible = true
	panel.add_theme_stylebox_override("panel", create_panel_style())

	timer_label = panel.get_node_or_null("TimerLabel") as Label
	if timer_label == null:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		panel.add_child(timer_label)
	timer_label.text = "00:00.000"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	timer_label.position = Vector2(16, 14)
	timer_label.size = Vector2(panel.size.x - 32.0, 44.0)

	best_time_label = panel.get_node_or_null("BestTimeLabel") as Label
	if best_time_label == null:
		best_time_label = Label.new()
		best_time_label.name = "BestTimeLabel"
		panel.add_child(best_time_label)
	best_time_label.text = "Лучшее: --:--.---"
	best_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_time_label.text = "Лучшее: --:--.---"
	best_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	best_time_label.add_theme_font_size_override("font_size", 17)
	best_time_label.add_theme_color_override("font_color", Color(0.89, 0.73, 0.49))
	best_time_label.position = Vector2(16, 58)
	best_time_label.size = Vector2(panel.size.x - 32.0, 28.0)

	var caption: Label = panel.get_node_or_null("TimerCaption") as Label
	if caption == null:
		caption = Label.new()
		caption.name = "TimerCaption"
		panel.add_child(caption)
	caption.text = "Полетное время"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text = "Полетное время"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.85, 0.77, 0.69, 0.92))
	caption.position = Vector2(16, 84)
	caption.size = Vector2(panel.size.x - 32.0, 16.0)

	update_best_time_display()
func create_panel_style() -> StyleBoxFlat:
	var style_modern: StyleBoxFlat = StyleBoxFlat.new()
	style_modern.bg_color = Color(0.17, 0.11, 0.08, 0.94)
	style_modern.border_color = Color(0.80, 0.62, 0.40, 0.84)
	style_modern.border_width_left = 2
	style_modern.border_width_top = 2
	style_modern.border_width_right = 2
	style_modern.border_width_bottom = 2
	style_modern.corner_radius_top_left = 18
	style_modern.corner_radius_top_right = 18
	style_modern.corner_radius_bottom_right = 18
	style_modern.corner_radius_bottom_left = 18
	style_modern.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style_modern.shadow_size = 12
	return style_modern

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
	if _result_window_open:
		return
	print("Программа завершена, успех: ", success)
	var final_time: String = stop_timer()
	var final_time_ms: int = current_time_ms
	var target_reached: bool = false
	var is_crashed_now: bool = false
	var was_cancelled: bool = false

	if current_drone != null and current_drone.has_method("get_has_reached_target"):
		target_reached = bool(current_drone.call("get_has_reached_target"))
	if current_drone != null and current_drone.has_method("get_last_run_crashed"):
		is_crashed_now = bool(current_drone.call("get_last_run_crashed"))
	elif current_drone != null and current_drone.has_method("get_is_crashed"):
		is_crashed_now = bool(current_drone.call("get_is_crashed"))
	if current_drone != null and current_drone.has_method("get_last_run_cancelled"):
		was_cancelled = bool(current_drone.call("get_last_run_cancelled"))

	if was_cancelled:
		print("ℹ️ Выполнение было отменено пользователем")
		reset_timer()
		return

	if is_crashed_now:
		print("💥 Полет завершился повреждением дрона")
		Global.record_level_attempt(Global.current_level, final_time_ms, false)
		_refresh_pause_stats()
		show_failure_message(final_time, final_time_ms, "Дрон получил повреждения во время маршрута. Проверьте сборку и траекторию перед новой попыткой.")
		return

	if success and target_reached:
		print("🎉 Цель достигнута, завершаем уровень")
		var completion_result: Dictionary = Global.complete_level(Global.current_level, final_time_ms)
		if completion_result.is_empty() or not completion_result.has("stars") or not completion_result.has("reward"):
			completion_result = {"stars": 0, "reward": 0, "base_reward": 0, "bonus": 0}
		Global.record_level_attempt(Global.current_level, final_time_ms, true)
		_refresh_pause_stats()
		show_success_message(final_time, final_time_ms, completion_result)
		return

	print("❌ Маршрут не привел дрон к цели")
	Global.record_level_attempt(Global.current_level, final_time_ms, false)
	_refresh_pause_stats()
	show_failure_message(final_time, final_time_ms, "Маршрут выполнен, но цель не достигнута. Пересоберите программу и попробуйте снова.")

func show_crash_message():
	show_failure_message(format_time_ms(current_time_ms), current_time_ms, "Дрон получил повреждения во время полета. Проверьте маршрут и попробуйте снова.")

func show_failure_message(final_time: String, time_ms: int, summary: String):
	_clear_success_canvas()
	_close_failure_canvas(get_node_or_null("CrashCanvas") as CanvasLayer)
	_result_window_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var canvas := CanvasLayer.new()
	canvas.layer = 119
	canvas.name = "CrashCanvas"

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.07, 0.05, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760, 470)
	var panel_style := create_panel_style()
	panel_style.border_color = Color(0.86, 0.58, 0.42, 0.96)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Маршрут не выполнен"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Дрон не дошел до цели. Попробуйте еще раз."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.90, 0.80, 0.70))
	layout.add_child(subtitle)

	var summary_label := Label.new()
	summary_label.text = summary
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 20)
	summary_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
	layout.add_child(summary_label)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 14)
	layout.add_child(stats_row)
	stats_row.add_child(_build_success_stat_card("Время", final_time if not final_time.is_empty() else format_time_ms(time_ms), Color(0.86, 0.64, 0.44)))
	stats_row.add_child(_build_success_stat_card("Цель", "Не достигнута", Color(0.79, 0.46, 0.35)))
	stats_row.add_child(_build_success_stat_card("Попытка", str(int(Global.get_level_statistics(Global.current_level).get("attempt_count", 0))), Color(0.67, 0.54, 0.37)))

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	layout.add_child(button_row)

	button_row.add_child(_build_success_button("Главное меню", Color(0.28, 0.19, 0.13, 0.98), Color(0.72, 0.56, 0.37, 0.90), Callable(self, "_on_failure_menu_pressed").bind(canvas)))
	button_row.add_child(_build_success_button("Начать заново", Color(0.41, 0.27, 0.17, 0.98), Color(0.88, 0.69, 0.45, 0.94), Callable(self, "_on_failure_retry_pressed").bind(canvas)))

	add_child(canvas)

func _on_failure_menu_pressed(canvas: CanvasLayer):
	_close_failure_canvas(canvas)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://app/main_menu/main_scene.tscn")

func _on_failure_retry_pressed(canvas: CanvasLayer):
	_close_failure_canvas(canvas)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(_get_current_level_scene_path())

func _get_current_level_scene_path() -> String:
	var current_scene_path: String = ""
	if get_tree() != null and get_tree().current_scene != null:
		current_scene_path = str(get_tree().current_scene.scene_file_path)
	if current_scene_path.is_empty():
		current_scene_path = "res://app/flight/levels/Level%d.tscn" % Global.current_level
	return current_scene_path

func _close_failure_canvas(canvas: CanvasLayer):
	if canvas != null and is_instance_valid(canvas):
		canvas.queue_free()
	_result_window_open = false

func _close_crash_canvas(canvas: CanvasLayer):
	_close_failure_canvas(canvas)

func show_success_message(final_time: String, time_ms: int, result: Dictionary):
	_clear_success_canvas()
	_result_window_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if best_time_ms <= 0 or time_ms < best_time_ms:
		best_time_ms = time_ms
		save_best_time()
		update_best_time_display()

	var stars: int = int(result.get("stars", 0))
	var reward: int = int(result.get("reward", 0))

	var canvas := CanvasLayer.new()
	canvas.layer = 120
	canvas.name = "SuccessCanvas"

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.07, 0.05, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(760, 500)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.10, 0.07, 0.96)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.84, 0.66, 0.43, 0.96)
	panel_style.corner_radius_top_left = 22
	panel_style.corner_radius_top_right = 22
	panel_style.corner_radius_bottom_left = 22
	panel_style.corner_radius_bottom_right = 22
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title := Label.new()
	title.text = get_success_title(stars)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Уровень %d успешно завершен" % Global.current_level
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.79, 0.68))
	layout.add_child(subtitle)

	var stars_label := Label.new()
	stars_label.text = _build_success_stars_line(stars)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.add_theme_font_size_override("font_size", 30)
	stars_label.add_theme_color_override("font_color", get_star_color(stars))
	layout.add_child(stars_label)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 18)
	layout.add_child(stats)
	stats.add_child(_build_success_stat_card("Время", final_time, Color(0.84, 0.66, 0.43, 0.94)))
	stats.add_child(_build_success_stat_card("Звезды", "%d / 3" % stars, Color(0.93, 0.77, 0.47, 0.94)))
	stats.add_child(_build_success_stat_card("Монеты", "+%d" % reward, Color(0.78, 0.60, 0.39, 0.94)))

	var summary := Label.new()
	summary.text = _build_success_summary_text(result)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
	layout.add_child(summary)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	buttons.add_child(_build_success_button("Главное меню", Color(0.29, 0.20, 0.14, 0.98), Color(0.74, 0.58, 0.39, 0.92), Callable(self, "_on_success_menu_pressed").bind(canvas)))
	var next_button: Button = _build_success_button("Следующий уровень", Color(0.41, 0.28, 0.17, 0.98), Color(0.88, 0.70, 0.45, 0.95), Callable(self, "_on_success_next_pressed").bind(canvas))
	next_button.disabled = Global.current_level >= 15
	buttons.add_child(next_button)
	buttons.add_child(_build_success_button("Пройти снова", Color(0.23, 0.17, 0.12, 0.98), Color(0.68, 0.52, 0.35, 0.90), Callable(self, "_on_success_retry_pressed").bind(canvas)))

	add_child(canvas)

func animate_stars(stars_container: HBoxContainer, stars_earned: int):
	for i in range(stars_earned):
		if i < stars_container.get_child_count():
			var star_frame = stars_container.get_child(i) as CenterContainer
			if star_frame and star_frame.get_child_count() > 0:
				var star_label = star_frame.get_child(0) as Label
				if star_label:
					# Ждем задержку перед анимацией каждой звезды
					if not await _wait_for_tree_timer(i * 0.2):
						return
					
					# Анимация звезды
					var tween = create_tween()
					tween.tween_property(star_label, "scale", Vector2(1.5, 1.5), 0.5)
					tween.tween_property(star_label, "scale", Vector2(1.2, 1.2), 0.3)

func _wait_for_tree_timer(duration: float) -> bool:
	if duration <= 0.0:
		return get_tree() != null and is_inside_tree()
	if get_tree() == null or not is_inside_tree():
		return false
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	if timer == null:
		return false
	await timer.timeout
	return get_tree() != null and is_inside_tree()

func _clear_success_canvas():
	var existing: CanvasLayer = get_node_or_null("SuccessCanvas") as CanvasLayer
	if existing != null:
		existing.queue_free()
	_result_window_open = false

func _build_success_stars_line(stars: int) -> String:
	var parts: Array[String] = []
	for index in range(3):
		parts.append("★" if index < stars else "☆")
	return " ".join(parts)

func _build_success_summary_text(result: Dictionary) -> String:
	var stars: int = int(result.get("stars", 0))
	var reward: int = int(result.get("reward", 0))
	var bonus: int = int(result.get("bonus", 0))
	if bonus > 0:
		return "Маршрут закрыт чисто. Получено %d монет, включая бонус за первое прохождение." % reward
	if stars >= 3:
		return "Отличный заход: маршрут пройден быстро и аккуратно."
	if stars == 2:
		return "Хороший результат. Можно улучшить время и добрать еще одну звезду."
	if stars == 1:
		return "Уровень пройден, но по времени еще есть запас."
	return "Маршрут завершен. Попробуйте пройти его быстрее, чтобы получить звезды."

func _build_success_stat_card(title: String, value: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.21, 0.15, 0.10, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.77, 0.67))
	layout.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 24)
	value_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.87))
	layout.add_child(value_label)
	return card

func _build_success_button(text: String, fill: Color, border: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(204, 58)
	_style_drone_ui_button(button, fill, border, 18)
	button.pressed.connect(callback)
	return button

func _on_success_menu_pressed(canvas: CanvasLayer):
	_close_success_canvas(canvas)
	return_to_selection()

func _on_success_retry_pressed(canvas: CanvasLayer):
	_close_success_canvas(canvas)
	var current_scene_path: String = ""
	if get_tree() != null and get_tree().current_scene != null:
		current_scene_path = str(get_tree().current_scene.scene_file_path)
	if current_scene_path.is_empty():
		current_scene_path = "res://app/flight/levels/Level%d.tscn" % Global.current_level
	Global.load_scene_with_loading(current_scene_path)

func _on_success_next_pressed(canvas: CanvasLayer):
	_close_success_canvas(canvas)
	var next_level: int = mini(Global.current_level + 1, 15)
	Global.current_level = next_level
	Global.load_scene_with_loading("res://app/flight/levels/Level%d.tscn" % next_level)

func _close_success_canvas(canvas: CanvasLayer):
	if canvas != null and is_instance_valid(canvas):
		canvas.queue_free()
	_result_window_open = false

func get_success_title(stars: int) -> String:
	match stars:
		3: return "Идеально! 3 звезды!"
		2: return "Отлично! 2 звезды!"
		1: return "Хорошо! 1 звезда!"
		_: return "Уровень пройден"

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
	if _is_tutorial_active():
		get_tree().change_scene_to_file("res://app/main_menu/main_scene.tscn")
		return
	get_tree().change_scene_to_file("res://app/ui/game_level.tscn")

# ==================== СИСТЕМА ДРОНА ====================
func create_drone():
	print("🔧 Создаем дрон...")
	for child in drone_container.get_children():
		child.queue_free()
	
	var drone_paths = [
		"res://exported_drone.tscn",
		"user://exported_drone.tscn", 
		"res://app/flight/Drone.tscn"
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
		print("📂 Загружаем дрон из: ", path)
		var drone_instance = drone_scene.instantiate()
		if Global != null:
			Global.apply_customization_to_drone_root(drone_instance)
		
		print("   Тип загруженного объекта: ", drone_instance.get_class())
		print("   Детей у объекта: ", drone_instance.get_child_count())
		
		# Проверяем метаданные
		if drone_instance.has_meta("drone_info"):
			var info = drone_instance.get_meta("drone_info")
			print("   Метаданные дрона: ", info)
		
		drone_container.add_child(drone_instance)
		
		# ПРОВЕРЯЕМ, ЧТО ЭТО CharacterBody3D
		if drone_instance is CharacterBody3D:
			print("✅ Дрон загружен как CharacterBody3D")
			current_drone = drone_instance
			setup_drone(current_drone)
			return true
		else:
			print("❌ Загруженный объект не CharacterBody3D, а: ", drone_instance.get_class())
			
			# Пытаемся найти CharacterBody3D в детях
			var found_drone = find_drone_in_children(drone_instance)
			if found_drone and found_drone is CharacterBody3D:
				print("✅ Нашли CharacterBody3D в детях")
				current_drone = found_drone
				setup_drone(current_drone)
				return true
			else:
				print("❌ Не удалось найти CharacterBody3D")
				drone_instance.queue_free()
				return false
	
	return false

func find_drone_in_children(node: Node) -> CharacterBody3D:
	"""Рекурсивно ищет CharacterBody3D в детях"""
	for child in node.get_children():
		if child is CharacterBody3D:
			return child
		var found = find_drone_in_children(child)
		if found:
			return found
	return null

func create_drone_from_parts(drone_node: Node3D) -> CharacterBody3D:
	print("🔧 Создаем CharacterBody3D из компонентов...")
	
	var new_drone = CharacterBody3D.new()
	new_drone.name = "ConstructedDrone"
	
	var drone_script = load("res://app/flight/Drone.gd")
	if drone_script:
		new_drone.set_script(drone_script)
	
	# Копируем все компоненты
	for child in drone_node.get_children():
		if child is Node3D:
			var child_copy = child.duplicate()
			new_drone.add_child(child_copy)
			child_copy.owner = new_drone
	if Global != null:
		Global.apply_customization_to_drone_root(new_drone)
	
	drone_container.add_child(new_drone)
	new_drone.owner = get_tree().edited_scene_root
	
	# Устанавливаем начальную позицию
	var start_pos = calculate_start_position()
	new_drone.global_position = start_pos
	
	print("✅ CharacterBody3D создан из компонентов")
	return new_drone
	
func count_nodes_by_name(root: Node, name_part: String) -> int:
	var count = 0
	for child in root.get_children():
		if name_part in child.name:
			count += 1
		count += count_nodes_by_name(child, name_part)
	return count

func create_character_body_from_node(drone_node: Node3D) -> CharacterBody3D:
	"""Создает CharacterBody3D из Node3D с компонентами"""
	print("🔧 Создаем CharacterBody3D из компонентов...")
	
	var new_drone = CharacterBody3D.new()
	new_drone.name = "LoadedDrone"
	
	var drone_script = load("res://app/flight/Drone.gd")
	if drone_script:
		new_drone.set_script(drone_script)
	
	# Копируем все меши из исходного узла
	copy_meshes_to_drone(drone_node, new_drone)
	if Global != null:
		Global.apply_customization_to_drone_root(new_drone)
	
	drone_container.add_child(new_drone)
	new_drone.owner = get_tree().edited_scene_root
	
	# Устанавливаем начальную позицию
	var start_pos = calculate_start_position()
	new_drone.global_position = start_pos
	
	print("✅ CharacterBody3D создан из компонентов")
	return new_drone

func copy_meshes_to_drone(source: Node, target: CharacterBody3D):
	"""Копирует все меши из source в target"""
	for child in source.get_children():
		if child is MeshInstance3D or child is Node3D:
			var child_copy = child.duplicate()
			target.add_child(child_copy)
			child_copy.owner = target
			
			# Копируем имя для идентификации
			if "Motor" in child.name:
				print("🔧 Скопирован мотор: ", child.name)
			elif "Propeller" in child.name:
				print("🌀 Скопирован пропеллер: ", child.name)
		
		# Рекурсивно копируем детей
		copy_meshes_to_drone(child, target)

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

func _get_spawn_floor_y(drone_node: CharacterBody3D) -> float:
	# Пол в этой сцене = нижняя граница сетки
	var floor_y: float = grid_boundary_min.y

	var cs: CollisionShape3D = drone_node.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if cs != null and cs.shape != null and cs.shape is BoxShape3D:
		var box: BoxShape3D = cs.shape
		# Нижняя точка коллизии в ЛОКАЛЬНЫХ координатах дрона
		var bottom_local_y: float = cs.position.y - box.size.y * 0.5
		# Учитываем масштаб (у тебя дрон scale = Vector3(6,6,6) в Drone.gd)
		var scale_y: float = drone_node.global_transform.basis.get_scale().y
		var bottom_world_offset: float = bottom_local_y * scale_y
		# Ставим дрон так, чтобы низ коллизии касался пола
		return floor_y - bottom_world_offset

	return floor_y


func setup_drone(drone_node: CharacterBody3D):
	print("🔧 Настраиваем дрон...")
	
	# ВЫРАВНИВАЕМ ПО СЕТКЕ ПРИ ЗАГРУЗКЕ
	var start_pos = calculate_start_position()
	
	# Принудительное выравнивание по сетке
	@warning_ignore("integer_division")
	var aligned_x = floor((start_pos.x + GRID_SIZE / 2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE / 2
	@warning_ignore("integer_division")
	var aligned_z = floor((start_pos.z + GRID_SIZE / 2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE / 2
	
	start_pos = Vector3(aligned_x, start_pos.y, aligned_z)
	# Страховка: ставим дрон так, чтобы его нижняя точка была на полу
	start_pos.y = max(start_pos.y, _get_spawn_floor_y(drone_node))
	if not is_position_within_bounds(start_pos):
		start_pos = clamp_position_to_bounds(start_pos)
		print("⚠️ Стартовая позиция скорректирована: ", start_pos)
	
	drone_node.global_position = start_pos
	drone_node.scale = Vector3(6, 6, 6)
	if drone_node.has_method("set_start_position"):
		drone_node.call("set_start_position", start_pos)
	if Global != null:
		Global.apply_customization_to_drone_root(drone_node)
	current_cell_position = _get_cell_position_from_world_position(start_pos)
	
	# Сбрасываем вращение, чтобы дрон был ровно
	drone_node.rotation_degrees = Vector3.ZERO
	
	# Установите целевую позицию для текущего уровня
	var target_pos = get_target_for_level(Global.current_level)
	if drone_node.has_method("set_target_position"):
		drone_node.set_target_position(target_pos)
		print("🎯 Установлена целевая позиция для дрона: ", target_pos)
	
	add_collision_if_needed(drone_node)
	drone_node.collision_layer = 1
	drone_node.collision_mask = 3
	if drone_node.has_method("set_floor_height"):
		drone_node.set_floor_height(grid_boundary_min.y)
	
	if drone_node.has_signal("drone_moved"):
		drone_node.drone_moved.connect(on_drone_moved)
	if drone_node.has_signal("program_finished"):
		drone_node.program_finished.connect(_on_program_finished)
		print("✅ Сигнал program_finished подключен")
	
	if drone_node.has_method("set_boundaries"):
		drone_node.set_boundaries(grid_boundary_min, grid_boundary_max)
		print("✅ Границы установлены для дрона")
	
	# DEBUG: РµСЃР»Рё РґСЂРѕРЅ "телепортируется вниз", СЌС‚РѕС‚ С‚СЂРµРєРµСЂ РїРѕРєР°Р¶РµС‚, РљРћР“Р”Рђ СЌС‚Рѕ СЃР»СѓС‡Р°РµС‚СЃСЏ
	if camera_pivot != null:
		camera_pivot.global_position = drone_node.global_position
		update_camera_position()
	_spawn_debug_track(drone_node, drone_node.global_position.y)
	print("🚁 Дрон установлен на позицию: ", drone_node.global_position)
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
	
	var drone_script = load("res://app/flight/Drone.gd")
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
	if current_drone != null and is_instance_valid(current_drone):
		return current_drone

	if drone_container != null:
		current_drone = find_drone_in_children(drone_container)
	return current_drone

# ==================== СИСТЕМА СЕТКИ И ВИЗУАЛЬНЫХ ЭФФЕКТОВ ====================
func create_grid():
	var grid = $Grid
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grid_color: Color = Color(0.58, 0.45, 0.28, 0.62)
	if not current_location_profile.is_empty():
		var accent_color: Color = current_location_profile.get("accent_color", grid_color)
		var floor_color: Color = current_location_profile.get("floor_color", grid_color)
		grid_color = floor_color.lerp(accent_color, 0.48).lightened(0.04)
		grid_color.a = 0.62
	material.albedo_color = grid_color
	material.emission_enabled = true
	material.emission = Color(grid_color.r, grid_color.g, grid_color.b, 1.0) * 0.07
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
	# Проверяем, что дрон и подсветка существуют
	if not current_drone or not grid_highlight:
		return
	
	# Получаем точную позицию дрона
	var drone_pos = current_drone.global_position
	
	# Устанавливаем подсветку ПРЯМО ПОД ДРОНОМ
	grid_highlight.global_position = Vector3(drone_pos.x, 0.15, drone_pos.z)
	grid_highlight.visible = true
	
	# Выбираем цвет в зависимости от позиции
	if is_position_within_bounds(drone_pos):
		highlight_mesh.material_override.albedo_color = Global.highlight_color.darkened(0.12)
		highlight_mesh.material_override.emission = Global.highlight_color * 0.10
	else:
		highlight_mesh.material_override.albedo_color = HIGHLIGHT_COLOR_WARNING.darkened(0.18)
		highlight_mesh.material_override.emission = HIGHLIGHT_COLOR_WARNING * 0.12
	
	# Для создания трейла все еще используем округление до центра клетки
	var new_cell_position = _get_cell_position_from_world_position(drone_pos)
	
	# Создаем трейл только при переходе в новую клетку
	if new_cell_position != current_cell_position and current_cell_position != Vector3.ZERO:
		create_trail_marker(current_cell_position)
		if Global != null:
			Global.record_cells_flown(1)
	
	current_cell_position = new_cell_position

func create_wooden_floor():
	var floor_node = $Floor
	if floor_node:
		var mesh_instance = floor_node.get_node("MeshInstance3D")
		if mesh_instance:
			var floor_material = StandardMaterial3D.new()
			floor_material.albedo_color = Color(0.14, 0.09, 0.06)
			floor_material.metallic = 0.1
			floor_material.roughness = 0.88
			
			var wood_texture = load("res://content/environments/room3d/textures/wood.jpg")
			if wood_texture:
				floor_material.albedo_texture = wood_texture
				floor_material.uv1_scale = Vector3(16, 16, 16)
			
			floor_material_instance = floor_material
			mesh_instance.material_override = floor_material_instance
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

func _get_cell_position_from_world_position(world_position: Vector3) -> Vector3:
	var half_grid: float = GRID_SIZE * 0.5
	var cell_x: float = floor(world_position.x / GRID_SIZE) * GRID_SIZE + half_grid
	var cell_z: float = floor(world_position.z / GRID_SIZE) * GRID_SIZE + half_grid
	return Vector3(cell_x, 0.0, cell_z)

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
		_clamp_camera_pivot_to_bounds()
		update_camera_position()
	
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
func _apply_programming_ui_theme():
	if block_ui != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.15, 0.10, 0.07, 0.96)
		panel_style.border_color = Color(0.76, 0.58, 0.38, 0.86)
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 18
		panel_style.corner_radius_top_right = 18
		panel_style.corner_radius_bottom_left = 18
		panel_style.corner_radius_bottom_right = 18
		panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
		panel_style.shadow_size = 16
		block_ui.add_theme_stylebox_override("panel", panel_style)

	_style_drone_ui_button(programming_button, Color(0.34, 0.24, 0.16, 0.98), Color(0.84, 0.65, 0.43, 0.95), 18)
	_style_drone_ui_button($UI/BlockProgramming/StartButton as Button, Color(0.46, 0.31, 0.18, 0.98), Color(0.91, 0.73, 0.46, 0.95), 16)
	_style_drone_ui_button($UI/BlockProgramming/ClearButton as Button, Color(0.39, 0.22, 0.16, 0.98), Color(0.82, 0.50, 0.36, 0.94), 16)
	_style_drone_ui_button($UI/BlockProgramming/CloseButton as Button, Color(0.29, 0.20, 0.14, 0.98), Color(0.74, 0.58, 0.38, 0.92), 16)

func _style_drone_ui_button(button: Button, fill: Color, border: Color, font_size: int = 16):
	if button == null:
		return

	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 14.0
	normal.content_margin_top = 8.0
	normal.content_margin_right = 14.0
	normal.content_margin_bottom = 8.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.08)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.08)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	button.add_theme_font_size_override("font_size", font_size)

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
		var tut := get_node_or_null("/root/tut")
		if tut != null:
			tut.notify("programming_open")
		print("🧩 Открываем панель программирования")

# ==================== МЕНЮ ПАУЗЫ ====================
func create_pause_menu():
	pause_menu = Control.new()
	pause_menu.name = "PauseOverlay"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.05, 0.03, 0.68)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	pause_panel_ref = Panel.new()
	pause_panel_ref.custom_minimum_size = Vector2(620, 640)
	pause_panel_ref.add_theme_stylebox_override("panel", create_panel_style())
	center.add_child(pause_panel_ref)

	pause_margin_ref = MarginContainer.new()
	pause_margin_ref.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_margin_ref.add_theme_constant_override("margin_left", 24)
	pause_margin_ref.add_theme_constant_override("margin_top", 22)
	pause_margin_ref.add_theme_constant_override("margin_right", 24)
	pause_margin_ref.add_theme_constant_override("margin_bottom", 22)
	pause_panel_ref.add_child(pause_margin_ref)

	pause_panel_root = VBoxContainer.new()
	pause_panel_root.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_panel_root.add_theme_constant_override("separation", 14)
	pause_panel_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_margin_ref.add_child(pause_panel_root)

	var title: Label = Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
	pause_panel_root.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Полет приостановлен. Можно вернуться, перенастроить сцену или выйти."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.86, 0.78, 0.69))
	subtitle.custom_minimum_size = Vector2(0, 72)
	pause_panel_root.add_child(subtitle)

	var stats_card := PanelContainer.new()
	stats_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.custom_minimum_size = Vector2(0, 180)
	var stats_style := create_panel_style()
	stats_style.bg_color = Color(0.20, 0.14, 0.10, 0.94)
	stats_style.border_color = Color(0.72, 0.56, 0.37, 0.76)
	stats_card.add_theme_stylebox_override("panel", stats_style)
	pause_panel_root.add_child(stats_card)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 18)
	stats_margin.add_theme_constant_override("margin_top", 16)
	stats_margin.add_theme_constant_override("margin_right", 18)
	stats_margin.add_theme_constant_override("margin_bottom", 16)
	stats_card.add_child(stats_margin)

	var stats_layout := VBoxContainer.new()
	stats_layout.add_theme_constant_override("separation", 10)
	stats_margin.add_child(stats_layout)

	var stats_title := Label.new()
	stats_title.text = "Статистика уровня"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	stats_layout.add_child(stats_title)

	pause_stats_summary_label = Label.new()
	pause_stats_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pause_stats_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_stats_summary_label.add_theme_font_size_override("font_size", 19)
	pause_stats_summary_label.add_theme_color_override("font_color", Color(0.90, 0.83, 0.75))
	stats_layout.add_child(pause_stats_summary_label)

	pause_stats_top_label = Label.new()
	pause_stats_top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pause_stats_top_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_stats_top_label.add_theme_font_size_override("font_size", 18)
	pause_stats_top_label.add_theme_color_override("font_color", Color(0.83, 0.74, 0.64))
	stats_layout.add_child(pause_stats_top_label)

	var resume_btn: Button = Button.new()
	resume_btn.text = "Продолжить"
	resume_btn.custom_minimum_size = Vector2(360, 56)
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drone_ui_button(resume_btn, Color(0.46, 0.31, 0.18, 0.98), Color(0.91, 0.73, 0.46, 0.95), 18)
	resume_btn.pressed.connect(toggle_pause_menu)
	pause_panel_root.add_child(resume_btn)

	var settings_btn: Button = Button.new()
	settings_btn.text = "Настройки"
	settings_btn.custom_minimum_size = Vector2(360, 56)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drone_ui_button(settings_btn, Color(0.34, 0.24, 0.16, 0.98), Color(0.82, 0.64, 0.42, 0.92), 18)
	settings_btn.pressed.connect(open_settings)
	pause_panel_root.add_child(settings_btn)

	var restart_btn: Button = Button.new()
	restart_btn.text = "Пройти снова"
	restart_btn.custom_minimum_size = Vector2(360, 56)
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drone_ui_button(restart_btn, Color(0.27, 0.19, 0.13, 0.98), Color(0.71, 0.55, 0.37, 0.88), 18)
	restart_btn.pressed.connect(func():
		toggle_pause_menu()
		Global.load_scene_with_loading("res://app/flight/levels/Level%d.tscn" % Global.current_level)
	)
	pause_panel_root.add_child(restart_btn)

	var main_menu_btn: Button = Button.new()
	main_menu_btn.text = "Главное меню"
	main_menu_btn.custom_minimum_size = Vector2(360, 56)
	main_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drone_ui_button(main_menu_btn, Color(0.27, 0.19, 0.13, 0.98), Color(0.71, 0.55, 0.37, 0.88), 18)
	main_menu_btn.pressed.connect(go_to_main_menu)
	pause_panel_root.add_child(main_menu_btn)

	var quit_btn: Button = Button.new()
	quit_btn.text = "Выйти из игры"
	quit_btn.custom_minimum_size = Vector2(360, 56)
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_drone_ui_button(quit_btn, Color(0.38, 0.20, 0.16, 0.98), Color(0.84, 0.49, 0.36, 0.92), 18)
	quit_btn.pressed.connect(quit_game)
	pause_panel_root.add_child(quit_btn)

	add_child(pause_menu)
	_refresh_pause_stats()
	call_deferred("_fit_pause_menu_panel", pause_panel_ref, pause_panel_root, pause_margin_ref)

func _fit_pause_menu_panel(panel: Panel, container: VBoxContainer, margin: MarginContainer) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(container) or not is_instance_valid(margin):
		return

	var content_size: Vector2 = container.get_combined_minimum_size()
	var margin_x: float = float(margin.get_theme_constant("margin_left") + margin.get_theme_constant("margin_right"))
	var margin_y: float = float(margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom"))
	panel.custom_minimum_size = Vector2(
		maxf(620.0, content_size.x + margin_x),
		maxf(640.0, content_size.y + margin_y)
	)

func _refresh_pause_stats() -> void:
	if pause_stats_summary_label == null or not is_instance_valid(pause_stats_summary_label):
		return
	var stats: Dictionary = Global.get_level_statistics(Global.current_level)
	var attempt_count: int = int(stats.get("attempt_count", 0))
	var completion_count: int = int(stats.get("completion_count", 0))
	var best_time_value: int = int(stats.get("best_time", 0))
	var stars: int = int(stats.get("stars", 0))
	var best_time_text: String = "—"
	if best_time_value > 0:
		best_time_text = format_time_ms(best_time_value)

	pause_stats_summary_label.text = "Прохождений: %d\nВсего попыток: %d\nЛучшее время: %s\nЗвезды: %d/3" % [
		completion_count,
		attempt_count,
		best_time_text,
		stars
	]

	var top_attempts_text: Array[String] = []
	var rank: int = 1
	for attempt_variant in stats.get("top_attempts", []):
		var attempt_time: int = int(attempt_variant)
		if attempt_time <= 0:
			continue
		top_attempts_text.append("%d. %s" % [rank, format_time_ms(attempt_time)])
		rank += 1
		if rank > 5:
			break

	if pause_stats_top_label != null and is_instance_valid(pause_stats_top_label):
		if top_attempts_text.is_empty():
			pause_stats_top_label.text = "Топ 5 прохождений: пока нет успешных результатов."
		else:
			pause_stats_top_label.text = "Топ 5 прохождений:\n" + "\n".join(top_attempts_text)

	if pause_panel_ref != null and pause_panel_root != null and pause_margin_ref != null:
		call_deferred("_fit_pause_menu_panel", pause_panel_ref, pause_panel_root, pause_margin_ref)

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
		var settings_scene = load("res://app/ui/SettingsScene.tscn")
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
		_refresh_pause_stats()
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
	get_tree().change_scene_to_file("res://app/main_menu/main_scene.tscn")

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
	camera.fov = Global.camera_fov
	camera.near = 0.8
	camera.far = 100090.0
	
	var env = get_node_or_null("WorldEnvironment")
	if env and env.environment:
		Global.apply_environment_graphics(env.environment)

	var main_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if main_light != null:
		Global.apply_directional_light_graphics(main_light)

	if lights_container != null:
		for light_node in lights_container.get_children():
			var omni_light := light_node as OmniLight3D
			if omni_light != null:
				Global.apply_omni_light_graphics(omni_light)
	
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
	fill_light.position = Vector3(0, 54, 0)
	fill_light.light_color = Color(0.82, 0.69, 0.56)
	fill_light.light_energy = 0.82
	fill_light.omni_range = 196
	fill_light.shadow_enabled = false

	var room_light := OmniLight3D.new()
	room_light.name = "RoomLight"
	lights_container.add_child(room_light)
	room_light.position = Vector3(0, 128, 0)
	room_light.light_color = Color(0.96, 0.88, 0.76)
	room_light.light_energy = 1.24
	room_light.omni_range = 520
	room_light.shadow_enabled = false

	var drone_focus_light := SpotLight3D.new()
	drone_focus_light.name = "DroneFocusLight"
	lights_container.add_child(drone_focus_light)
	drone_focus_light.position = Vector3(0, 72, 8)
	drone_focus_light.look_at(Vector3(0, 0, 0), Vector3.UP)
	drone_focus_light.light_color = Color(0.96, 0.78, 0.52)
	drone_focus_light.light_energy = 0.68
	drone_focus_light.spot_range = 180
	drone_focus_light.spot_angle = 34
	drone_focus_light.shadow_enabled = true
	drone_focus_light.shadow_blur = 0.25
	drone_focus_light.shadow_bias = 0.08

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
		spot_light.light_color = Color(0.94, 0.73, 0.50)
		spot_light.light_energy = 0.24
		spot_light.spot_range = 38
		spot_light.spot_angle = 38
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
	table_node_instance = table_node
	table_node.name = "GameTable"
	
	var table_width = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_depth = GRID_CELLS_COUNT * GRID_SIZE + 100
	var table_height = 15
	
	var table_mesh = BoxMesh.new()
	table_mesh.size = Vector3(table_width, table_height, table_depth)
	table_node.mesh = table_mesh
	table_node.position = Vector3(0, -table_height/2 - 2, 0)
	
	var table_material = StandardMaterial3D.new()
	table_material.albedo_color = Color(0.12, 0.08, 0.05)
	table_material.roughness = 0.9
	table_material.metallic = 0.04
	table_material.emission_enabled = true
	table_material.emission = Color(0.035, 0.02, 0.01)
	table_material.emission_energy_multiplier = 0.10
	
	var wood_texture = load("res://content/environments/room3d/textures/wood.jpg")
	if wood_texture:
		table_material.albedo_texture = wood_texture
		table_material.uv1_scale = Vector3(4, 4, 4)
		table_material.roughness_texture = wood_texture
		table_material.metallic_texture = wood_texture
	
	table_material_instance = table_material
	table_node.material_override = table_material_instance
	add_child(table_node)
	table_node.owner = get_tree().edited_scene_root
	create_modern_table_legs(table_width, table_depth, table_height)
	print("✅ Красивый стол создан")

func create_modern_table_legs(table_width: float, table_depth: float, table_height: float):
	var leg_height = 80
	var leg_thickness = 12
	var leg_material = StandardMaterial3D.new()
	leg_material.albedo_color = Color(0.10, 0.08, 0.07)
	leg_material.roughness = 0.88
	leg_material.metallic = 0.18
	table_leg_material_instance = leg_material
	
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
	box_mesh.size = Vector3(GRID_SIZE, 0.1, GRID_SIZE)  # Полный размер клетки
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.mesh = box_mesh
	
	var highlight_material = StandardMaterial3D.new()
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Global.highlight_color.darkened(0.12)
	highlight_material.emission_enabled = true
	highlight_material.emission = Global.highlight_color * 0.10
	highlight_material.emission_energy = 0.10
	highlight_material.metallic = 0.3
	highlight_material.roughness = 0.36
	
	highlight_mesh.material_override = highlight_material
	grid_highlight.add_child(highlight_mesh)
	highlight_mesh.owner = get_tree().edited_scene_root
	grid_highlight.visible = false
	
	# Убеждаемся, что нет твина, который может мешать
	# Убираем старые твины если они есть
	var tweens = get_tree().get_nodes_in_group("highlight_tween")
	for tween in tweens:
		if is_instance_valid(tween):
			tween.kill()
	
	# Создаем новый твин для плавного свечения
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(highlight_mesh.material_override, "emission", 
							Global.highlight_color * 0.16, 0.7)
	glow_tween.tween_property(highlight_mesh.material_override, "emission", 
							Global.highlight_color * 0.08, 0.7)

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
	trail_material.albedo_color = Global.trail_color.darkened(0.14)
	trail_material.emission_enabled = true
	trail_material.emission = Global.trail_color * 0.06
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
	preview_material.albedo_color = Color(0.82, 0.62, 0.34, 0.28)
	preview_material.emission_enabled = true
	preview_material.emission = Color(0.92, 0.72, 0.40, 0.08)

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
		marker_material.albedo_color = Color(0.36, 0.78, 0.50, 0.30)
		marker_material.emission = Color(0.36, 0.78, 0.50, 0.08)
	else:
		marker_material.albedo_color = Color(0.82, 0.62, 0.34, 0.28)
		marker_material.emission = Color(0.92, 0.72, 0.40, 0.07)
	
	marker.material_override = marker_material
	trajectory_markers.append(marker)

# ==================== СИСТЕМА КАМЕРЫ ====================
func _clamp_camera_pivot_to_bounds():
	if camera_pivot == null:
		return
	var clamped_position: Vector3 = camera_pivot.global_position
	clamped_position.x = clampf(clamped_position.x, grid_boundary_min.x, grid_boundary_max.x)
	clamped_position.z = clampf(clamped_position.z, grid_boundary_min.z, grid_boundary_max.z)
	clamped_position.y = clampf(clamped_position.y, grid_boundary_min.y + MIN_CAMERA_HEIGHT, grid_boundary_max.y)
	camera_pivot.global_position = clamped_position

func update_camera_position():
	_clamp_camera_pivot_to_bounds()
	var camera_position = Vector3(
		sin(camera_rotation.y) * cos(camera_rotation.x),
		sin(camera_rotation.x),
		cos(camera_rotation.y) * cos(camera_rotation.x)
	) * camera_distance
	var minimum_world_camera_y: float = grid_boundary_min.y + CAMERA_WORLD_MIN_OFFSET
	if camera_pivot.global_position.y + camera_position.y < minimum_world_camera_y:
		camera_position.y = minimum_world_camera_y - camera_pivot.global_position.y
	camera.position = camera_position
	camera.look_at(camera_pivot.global_position, Vector3.UP)
	
	var time = Time.get_ticks_msec() / 1000.0
	camera.h_offset = sin(time * 0.5) * 0.01
	camera.v_offset = cos(time * 0.3) * 0.01

func reset_drone():
	print("🔄 Сбрасываем дрона...")
	_close_crash_canvas(get_node_or_null("CrashCanvas") as CanvasLayer)
	var legacy_crash_canvas: CanvasLayer = get_node_or_null("CrashMessageCanvas") as CanvasLayer
	if legacy_crash_canvas != null:
		legacy_crash_canvas.queue_free()
	
	if current_drone:
		if current_drone.has_method("set_target_reached"):
			current_drone.call("set_target_reached", false)
		if current_drone.has_method("reset_to_start"):
			await current_drone.call("reset_to_start")
			current_cell_position = _get_cell_position_from_world_position(current_drone.global_position)
			print("✅ Дрон сброшен через внутреннюю стартовую позицию")
			return
		# Возвращаем дрона в начальную позицию
		var start_pos = calculate_start_position()
		if not is_position_within_bounds(start_pos):
			start_pos = clamp_position_to_bounds(start_pos)
		
		var tween = create_tween()
		tween.tween_property(current_drone, "global_position", start_pos, 1.0)
		tween.parallel().tween_property(current_drone, "rotation_degrees", Vector3.ZERO, 0.5)
		await tween.finished
		
		# Останавливаем пропеллеры если есть метод
		if current_drone.has_method("stop_propellers"):
			current_drone.stop_propellers()
		current_cell_position = _get_cell_position_from_world_position(current_drone.global_position)
		
		print("✅ Дрон сброшен в позицию: ", start_pos)
	else:
		print("❌ Нет дрона для сброса")
		
func reset_program():
	"""Сбрасывает программу дрона и таймер"""
	print("🔄 Сбрасываем программу...")
	
	# Сбрасываем таймер
	reset_timer()
	
	# Очищаем предпросмотр траектории
	clear_trajectory_preview()
	
	# Останавливаем дрона если он выполняет программу
	if current_drone and current_drone.has_method("stop_execution"):
		current_drone.stop_execution()

func get_target_for_level(level: int) -> Vector3:
	# Здесь установите цели для каждого уровня
	var targets = {
		1: Vector3(GRID_SIZE * 3, 0, GRID_SIZE * 3),
		2: Vector3(GRID_SIZE * 5, GRID_SIZE * 2, GRID_SIZE * 5),
		3: Vector3(GRID_SIZE * 8, 0, -GRID_SIZE * 4),
		4: Vector3(GRID_SIZE * 10, GRID_SIZE * 1, 0),
		5: Vector3(GRID_SIZE * 6, GRID_SIZE * 3, GRID_SIZE * 6),
		6: Vector3(GRID_SIZE * 4, 0, GRID_SIZE * 8),
		7: Vector3(-GRID_SIZE * 5, GRID_SIZE * 2, GRID_SIZE * 7),
		8: Vector3(GRID_SIZE * 12, GRID_SIZE * 1, -GRID_SIZE * 5),
		9: Vector3(GRID_SIZE * 9, GRID_SIZE * 4, GRID_SIZE * 9),
		10: Vector3(0, GRID_SIZE * 2, GRID_SIZE * 12),
		11: Vector3(-GRID_SIZE * 7, 0, GRID_SIZE * 7),
		12: Vector3(GRID_SIZE * 15, GRID_SIZE * 3, 0),
		13: Vector3(GRID_SIZE * 8, GRID_SIZE * 5, GRID_SIZE * 8),
		14: Vector3(-GRID_SIZE * 10, GRID_SIZE * 1, -GRID_SIZE * 8),
		15: Vector3(GRID_SIZE * 20, GRID_SIZE * 4, GRID_SIZE * 15)
	}
	return targets.get(level, Vector3(GRID_SIZE * 2, 0, GRID_SIZE * 2))


# ==================== DEBUG: ОТСЛЕЖИВАНИЕ СПАВНА ====================
func _spawn_debug_track(drone_node: Node3D, expected_y: float) -> void:
	# Печатает, кто/когда меняет высоту сразу после спавна.
	# Если ты не видишь эти логи — значит у тебя запущен ДРУГОЙ DroneScene.gd.
	if drone_node == null or not is_instance_valid(drone_node):
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return

	for i in range(3):
		await tree.process_frame
		if drone_node == null or not is_instance_valid(drone_node):
			return
		print("🛠️ [SpawnDebug] frame=", i, " pos=", (drone_node as Node3D).global_position)

	await tree.physics_frame
	if drone_node == null or not is_instance_valid(drone_node):
		return
	print("🛠️ [SpawnDebug] physics_frame pos=", (drone_node as Node3D).global_position)

	var cur_y := (drone_node as Node3D).global_position.y
	if abs(cur_y - expected_y) > 0.1:
		print("❗ [SpawnDebug] Высота изменилась после спавна! Было y=", expected_y, " стало y=", cur_y)


# ==================== TUTORIAL HELPERS ====================
func _tutorial_setup_level() -> void:
	var use_clean_hint_setup: bool = ProjectSettings.has_setting("display/window/size/viewport_width")
	if use_clean_hint_setup:
		if not (block_ui and block_ui is Control):
			return
		var ui_control: Control = block_ui as Control
		var hint_button: Button = ui_control.get_node_or_null("TutorialHintButton") as Button
		var should_show_hint: bool = Global != null and int(Global.current_level) == 1
		if not should_show_hint:
			if hint_button != null:
				hint_button.queue_free()
			return

		var tut_node: Node = get_node_or_null("/root/tut")
		if hint_button == null:
			hint_button = Button.new()
			hint_button.name = "TutorialHintButton"
			hint_button.text = "Подсказка"
			hint_button.custom_minimum_size = Vector2(180, 46)
			hint_button.add_theme_font_size_override("font_size", 14)
			hint_button.mouse_filter = Control.MOUSE_FILTER_STOP
			ui_control.add_child(hint_button)
			if tut_node != null and tut_node.has_method("notify"):
				hint_button.pressed.connect(func():
					tut_node.notify("hint_pressed")
				)

		_style_drone_ui_button(hint_button, Color(0.35, 0.24, 0.16, 0.98), Color(0.88, 0.70, 0.45, 0.95), 16)
		var hint_callback: Callable = Callable(self, "_show_first_level_hint")
		if not hint_button.pressed.is_connected(hint_callback):
			hint_button.pressed.connect(hint_callback)
		call_deferred("_tutorial_place_hint_button", hint_button, ui_control)
		return
	if not (block_ui and block_ui is Control):
		return
	var ui: Control = block_ui as Control
	var existing_button: Button = ui.get_node_or_null("TutorialHintButton") as Button
	var show_hint_button: bool = Global != null and int(Global.current_level) == 1
	if not show_hint_button:
		if existing_button != null:
			existing_button.queue_free()
		return
	var tut := get_node_or_null("/root/tut")

	# Добавляем кнопку подсказки в BlockProgramming (если её нет)
	if existing_button == null:
		existing_button = Button.new()
		existing_button.name = "TutorialHintButton"
		var b: Button = existing_button
		existing_button.text = "Подсказка"
		existing_button.custom_minimum_size = Vector2(180, 46)
		if ui != null:
			b.text = "Подсказка"
			b.custom_minimum_size = Vector2(180, 46)
			b.add_theme_font_size_override("font_size", 14)
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			ui.add_child(b)

			b.pressed.connect(func():
				if tut != null and tut.has_method("notify"):
					tut.notify("hint_pressed")
			)

			call_deferred("_tutorial_place_hint_button", b, ui)

	_style_drone_ui_button(existing_button, Color(0.35, 0.24, 0.16, 0.98), Color(0.88, 0.70, 0.45, 0.95), 16)
	var hint_callback: Callable = Callable(self, "_show_first_level_hint")
	if not existing_button.pressed.is_connected(hint_callback):
		existing_button.pressed.connect(hint_callback)

func _show_first_level_hint() -> void:
	if Global == null or int(Global.current_level) != 1:
		return

	var existing_popup: Control = get_node_or_null("UI/FirstLevelHintPopup") as Control
	if existing_popup != null:
		existing_popup.queue_free()

	var popup: Panel = Panel.new()
	popup.name = "FirstLevelHintPopup"
	popup.anchor_left = 0.5
	popup.anchor_top = 0.5
	popup.anchor_right = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -250.0
	popup.offset_top = -110.0
	popup.offset_right = 250.0
	popup.offset_bottom = 110.0

	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.14, 0.10, 0.07, 0.97)
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.86, 0.68, 0.44, 0.92)
	popup_style.corner_radius_top_left = 18
	popup_style.corner_radius_top_right = 18
	popup_style.corner_radius_bottom_left = 18
	popup_style.corner_radius_bottom_right = 18
	popup_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	popup_style.shadow_size = 14
	popup.add_theme_stylebox_override("panel", popup_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	popup.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title: Label = Label.new()
	title.text = "Подсказка"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	layout.add_child(title)

	var body: Label = Label.new()
	body.text = LEVEL_ONE_HINT_TEXT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.91, 0.84, 0.76))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)

	var close_button: Button = Button.new()
	close_button.text = "Понятно"
	close_button.custom_minimum_size = Vector2(160, 46)
	_style_drone_ui_button(close_button, Color(0.42, 0.28, 0.17, 0.98), Color(0.88, 0.70, 0.45, 0.95), 16)
	close_button.pressed.connect(func(): popup.queue_free())
	layout.add_child(close_button)

	$UI.add_child(popup)

func _tutorial_place_hint_button(b: Button, ui: Control) -> void:
	if b == null or not is_instance_valid(b):
		return

	var palette := ui.get_node_or_null("BlockPalette") as Control
	if palette == null:
		# fallback: снизу слева
		b.position = Vector2(16, ui.size.y - b.size.y - 16)
		return

	await get_tree().process_frame
	await get_tree().process_frame

	# Ставим кнопку НИЖЕ панели команд, чтобы не накладывалась на список команд
	var x: float = palette.position.x
	var y: float = palette.position.y + palette.size.y + 12.0

	y = min(y, ui.size.y - b.size.y - 96.0)
	x = min(x, ui.size.x - b.size.x - 16.0)

	b.position = Vector2(x, y)

func _tutorial_notify_level_completed() -> void:
	var tut := get_node_or_null("/root/tut")
	if tut != null and tut.has_method("notify"):
		tut.notify("level_completed")

func _is_tutorial_active() -> bool:
	var tut := get_node_or_null("/root/tut")
	if tut == null:
		return false
	return bool(tut.get("active"))
