# DroneScene.gd
extends Node3D

const GRID_SIZE = 32

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var drone_container = $DroneContainer
@onready var block_ui = $UI/BlockProgramming
@onready var programming_button = $UI/Control/ProgrammingButton

var camera_rotation = Vector2(0, 0)
var camera_distance = 40.0
var ROTATION_SPEED = 0.003
var ZOOM_SPEED = 3.0
var MIN_DISTANCE = 6.0
var MAX_DISTANCE = 150.0
var MIN_VERTICAL_ANGLE = -1.0
var MAX_VERTICAL_ANGLE = 1.5
var CAMERA_MOVE_SPEED = 25.0
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
var max_trail_length = 10
var trail_fade_time = 2.0
var start_point_x: int = 0
var start_point_z: int = 0
var start_point_y: int = GRID_SIZE
var highlight_color: Color = Color(0, 1, 0, 0.6)
var trail_color: Color = Color(0, 1, 0, 0.3)

func _ready():
	print("=== ИНИЦИАЛИЗАЦИЯ СЦЕНЫ ДРОНА ===")
	load_settings()
	load_drone()
	create_grid()
	create_grid_highlight()
	block_ui.hide()
	update_camera_position()
	connect_buttons()
	
	# Устанавливаем процесс режим чтобы input работал даже на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Захватываем мышь сразу при запуске
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Сцена готова!")

func load_drone():
	for child in drone_container.get_children():
		child.queue_free()
	var exported_drone_path = "user://exported_drone.tscn"
	if FileAccess.file_exists(exported_drone_path):
		print("✅ Найден экспортированный дрон: ", exported_drone_path)
		load_exported_drone(exported_drone_path)
	else:
		print("❌ Экспортированный дрон не найден, создаем дрон по умолчанию")
		create_default_drone()

func load_exported_drone(scene_path: String):
	var drone_scene = load(scene_path)
	if drone_scene:
		var drone_instance = drone_scene.instantiate()
		drone_container.add_child(drone_instance)
		var root_drone = find_drone_root(drone_instance)
		if root_drone:
			print("✅ Найден корень дрона: ", root_drone.name)
			current_drone = create_drone_from_parts(root_drone)
			setup_drone(current_drone)
		else:
			print("❌ Не удалось найти корень дрона, создаем нового")
			current_drone = create_default_character_drone()
	else:
		print("❌ Ошибка загрузки сцены дрона")
		current_drone = create_default_character_drone()

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
		@warning_ignore("unused_variable")
		var original_global_pos = drone_node.global_position
		var children_to_copy = []
		for child in drone_node.get_children():
			children_to_copy.append(child)
		for child in children_to_copy:
			if child is Node3D:
				print("  📥 Копируем: ", child.name, " относительная позиция: ", child.position)
				var relative_transform = child.transform
				var child_name = child.name
				drone_node.remove_child(child)
				new_drone.add_child(child)
				child.owner = get_tree().edited_scene_root
				child.transform = relative_transform
				child.name = child_name
				print("  ✅ Скопирован: ", child.name, " новая позиция: ", child.position)
	# Округляем до центра клетки
	@warning_ignore("integer_division")
	var aligned_x = round((start_point_x + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	@warning_ignore("integer_division")
	var aligned_z = round((start_point_z + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	new_drone.global_position = Vector3(aligned_x, start_point_y, aligned_z)
	if drone_node.get_parent() and drone_node.get_parent() != drone_container:
		drone_node.queue_free()
	print("✅ Дрон создан из частей")
	return new_drone
func setup_drone(drone_node: CharacterBody3D):
	print("🔧 Настраиваем дрон...")
	# Округляем до центра клетки (середина между линиями сетки)
	@warning_ignore("integer_division")
	var aligned_x = round((start_point_x + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	@warning_ignore("integer_division")
	var aligned_z = round((start_point_z + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
	drone_node.global_position = Vector3(aligned_x, start_point_y, aligned_z)
	drone_node.scale = Vector3(3, 3, 3)
	add_collision_if_needed(drone_node)
	if drone_node.has_signal("drone_moved"):
		drone_node.drone_moved.connect(on_drone_moved)
	print("✅ Дрон настроен: ", drone_node.name)
	print("🎯 Стартовая позиция выровнена: ", drone_node.global_position)
func print_drone_structure(node: Node, indent: int = 0):
	var indent_str = "  ".repeat(indent)
	print(indent_str + "└─ " + node.name + " (" + node.get_class() + ") позиция: " + str(node.global_position))
	for child in node.get_children():
		if child is Node3D:
			print_drone_structure(child, indent + 1)

func add_collision_if_needed(drone_node: CharacterBody3D):
	if drone_node.get_node_or_null("CollisionShape3D") == null:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		var bounds = calculate_drone_bounds(drone_node)
		shape.size = bounds.size
		collision.shape = shape
		collision.position = bounds.center
		drone_node.add_child(collision)
		collision.owner = get_tree().edited_scene_root
		print("✅ Добавлена коллизия дрону: ", bounds.size)

func calculate_drone_bounds(node: Node3D) -> Dictionary:
	var min_point = Vector3.INF
	var max_point = -Vector3.INF
	calculate_mesh_bounds(node, Transform3D.IDENTITY, min_point, max_point)
	if min_point == Vector3.INF:
		return {"size": Vector3(6, 1.5, 6), "center": Vector3.ZERO}
	var size = max_point - min_point
	var center = (min_point + max_point) / 2
	size += Vector3(1, 1, 1)
	return {"size": size, "center": center}

func calculate_mesh_bounds(node: Node3D, parent_transform: Transform3D, min_point: Vector3, max_point: Vector3):
	var node_transform = parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			var aabb = mesh.get_aabb()
			var transformed_min = node_transform * aabb.position
			var transformed_max = node_transform * aabb.end
			min_point = min_point.min(transformed_min)
			min_point = min_point.min(transformed_max)
			max_point = max_point.max(transformed_min)
			max_point = max_point.max(transformed_max)
	for child in node.get_children():
		if child is Node3D:
			calculate_mesh_bounds(child, node_transform, min_point, max_point)

func create_default_drone():
	print("🔧 Создаем дрон по умолчанию...")
	current_drone = create_default_character_drone()

func create_default_character_drone() -> CharacterBody3D:
	var drone_node = CharacterBody3D.new()
	drone_node.name = "DefaultDrone"
	drone_container.add_child(drone_node)
	drone_node.owner = get_tree().edited_scene_root
	var drone_script = load("res://DroneLevels/Drone.gd")
	if drone_script:
		drone_node.set_script(drone_script)
	setup_drone(drone_node)
	print("✅ Дрон по умолчанию создан")
	return drone_node

func get_drone() -> CharacterBody3D:
	return current_drone

func create_grid():
	var grid = $Grid
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.albedo_color = Color(0.3, 0.3, 0.3)
	for child in grid.get_children():
		child.queue_free()
	for i in range(-5, 6):
		create_grid_line(
			Vector3(i * GRID_SIZE, 0, -5 * GRID_SIZE),
			Vector3(i * GRID_SIZE, 0, 5 * GRID_SIZE),
			material, 0.3
		)
		create_grid_line(
			Vector3(-5 * GRID_SIZE, 0, i * GRID_SIZE),
			Vector3(5 * GRID_SIZE, 0, i * GRID_SIZE),
			material, 0.3
		)

@warning_ignore("unused_parameter")
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
	grid_highlight.global_position = Vector3(drone_pos.x, 0.1, drone_pos.z)
	grid_highlight.visible = true
	var new_cell_position = Vector3(drone_pos.x, 0, drone_pos.z)
	if new_cell_position != current_cell_position and current_cell_position != Vector3.ZERO:
		create_trail_marker(current_cell_position)
	current_cell_position = new_cell_position

@warning_ignore("shadowed_variable_base_class")
func create_trail_marker(position: Vector3):
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
	# Сохраняем ссылку на трейл до начала анимации
	var trail_index = trail_meshes.find(trail_mesh)
	
	var tween = create_tween()
	tween.tween_property(trail_mesh, "scale", Vector3(0.5, 0.5, 0.5), trail_fade_time * 0.7)
	tween.parallel().tween_property(trail_mesh.material_override, "albedo_color:a", 0.0, trail_fade_time)
	
	# Используем индекс вместо прямой ссылки на объект
	tween.tween_callback(_on_trail_fade_finished.bind(trail_index))

func _on_trail_fade_finished(trail_index: int):
	# Проверяем что индекс валидный и объект еще существует
	if trail_index >= 0 and trail_index < trail_meshes.size():
		var trail_mesh = trail_meshes[trail_index]
		if is_instance_valid(trail_mesh):
			trail_mesh.queue_free()
		# Удаляем из массива по индексу
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
func _input(event):
	# Обрабатываем ESC всегда, даже когда игра на паузе
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return
func _unhandled_input(event):
	# Обрабатываем Tab для программирования
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_programming()
		get_viewport().set_input_as_handled()
		return
	
	# Остальной input только когда игра не на паузе и не открыто программирование
	if is_paused or block_ui.visible:
		return
	
	# Вращение камеры при движении мыши
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
	
	# Приближение/отдаление колесиком мыши
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
func toggle_programming():
	if block_ui.visible:
		# Закрываем программирование
		block_ui.hide()
		programming_button.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("❌ Закрываем панель программирования")
	else:
		# Открываем программирование
		block_ui.show()
		programming_button.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("🧩 Открываем панель программирования")
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
	
	# Применяем инерцию вращения
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

func connect_buttons():
	# Убираем кнопку назад
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
	
	print("✅ Все кнопки подключены")

func _on_programming_button_pressed():
	# Кнопка программирования в UI тоже работает
	toggle_programming()

	# Мышь остается захваченной - для UI будет работать даже при захваченной мыши

func _on_back_button_pressed():
	print("◀️ Возвращаемся к выбору уровней")
	get_tree().change_scene_to_file("res://game_level.tscn")

func _on_start_button_pressed():
	print("🟢 Запускаем программу дрона")
	var drone = get_drone()
	if drone and drone.has_method("execute_sequence"):
		var sequence = block_ui.get_program_sequence()
		print("Полученная последовательность: ", sequence)
		if sequence.size() > 0:
			print("✅ Запускаем программу из ", sequence.size(), " команд")
			drone.execute_sequence(sequence)
		else:
			print("❌ Программа пуста! Добавьте блоки команд.")
	else:
		print("❌ Дрон не найден или не имеет метода execute_sequence")

func _on_clear_button_pressed():
	print("🗑️ Очищаем программу")
	if block_ui and block_ui.has_method("_on_clear_button_pressed"):
		# Вызываем метод очистки внутри BlockProgramming
		block_ui._on_clear_button_pressed()
	elif block_ui and block_ui.has_method("clear_program"):
		# Альтернативное имя метода
		block_ui.clear_program()
	else:
		print("❌ BlockProgramming UI не найден или не имеет метода очистки")		

func _on_close_button_pressed():
	# Кнопка закрытия в UI
	toggle_programming()

func toggle_pause_menu():
	print("🔄 Нажата кнопка ESC, текущая пауза:", is_paused)
	
	# Если открыты настройки, закрываем их
	if settings_menu and settings_menu.visible:
		print("📋 Закрываем настройки")
		close_settings()
		return
	
	# Если открыто программирование, закрываем его вместо паузы
	if block_ui.visible:
		print("🧩 Закрываем программирование вместо паузы")
		toggle_programming()
		return
	
	# Создаем меню если его нет
	if pause_menu == null:
		print("🆕 Создаем меню паузы впервые")
		create_pause_menu()
	
	# Переключаем состояние
	is_paused = !is_paused
	print("🎯 Новое состояние паузы:", is_paused)
	
	# Обновляем видимость
	pause_menu.visible = is_paused
	
	# Управляем мышью
	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		print("⏸️ Меню паузы ОТКРЫТО - мышь видима")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		print("▶️ Меню паузы ЗАКРЫТО - мышь захвачена")
	
	# Ставим игру на паузу
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
	var start_point_separator = HSeparator.new()
	start_point_separator.custom_minimum_size = Vector2(400, 5)
	var start_point_label = Label.new()
	start_point_label.text = "=== СТАРТОВАЯ ТОЧКА ДРОНА ==="
	start_point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_point_label.add_theme_color_override("font_color", Color.YELLOW)
	var start_x_container = HBoxContainer.new()
	var start_x_label = Label.new()
	start_x_label.text = "Стартовая позиция X:"
	start_x_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_x_slider = HSlider.new()
	start_x_slider.min_value = -2 * GRID_SIZE
	start_x_slider.max_value = 2 * GRID_SIZE
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
	var start_z_container = HBoxContainer.new()
	var start_z_label = Label.new()
	start_z_label.text = "Стартовая позиция Z:"
	start_z_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start_z_slider = HSlider.new()
	start_z_slider.min_value = -2 * GRID_SIZE
	start_z_slider.max_value = 2 * GRID_SIZE
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
	var apply_start_btn = Button.new()
	apply_start_btn.text = "Применить стартовую позицию"
	apply_start_btn.custom_minimum_size = Vector2(300, 40)
	apply_start_btn.pressed.connect(_on_apply_start_position)
	var back_btn = Button.new()
	back_btn.text = "Назад"
	back_btn.custom_minimum_size = Vector2(300, 50)
	back_btn.pressed.connect(close_settings)
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
		# Округляем до центра клетки
		@warning_ignore("integer_division")
		var aligned_x = round((start_point_x + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
		@warning_ignore("integer_division")
		var aligned_z = round((start_point_z + GRID_SIZE/2) / GRID_SIZE) * GRID_SIZE - GRID_SIZE/2
		current_drone.global_position = Vector3(aligned_x, start_point_y, aligned_z)
		on_drone_moved()
	save_settings()

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_scene.tscn")

func quit_game():
	get_tree().quit()

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
