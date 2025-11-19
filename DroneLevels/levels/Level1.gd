extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var target_cell_highlight: MeshInstance3D  # Добавляем переменную для подсветки клетки

# Переменные для управления высотой дрона
var drone_height_level1: float = 0.0

func _ready():
	print("🎮 УРОВЕНЬ 1 ЗАГРУЖЕН")
	print("Текущий уровень: ", Global.current_level)
	
	await get_tree().process_frame
	setup_level()

func setup_level():
	create_target_point()
	create_cell_marker(2, 2)
	create_target_cell_highlight()  # Создаем подсветку клетки
	await setup_drone()
	
	# УСТАНАВЛИВАЕМ ВЫСОТУ ДРОНА ДЛЯ ЭТОГО УРОВНЯ
	set_drone_height_for_level()
	
	print("✅ Уровень 1 настроен")

# Функция для создания подсветки клетки под целью
func create_target_cell_highlight():
	# Удаляем старую подсветку если есть
	if has_node("TargetCellHighlight"):
		get_node("TargetCellHighlight").queue_free()
	
	target_cell_highlight = MeshInstance3D.new()
	target_cell_highlight.name = "TargetCellHighlight"
	
	# Создаем меш для подсветки - рамка по краям клетки
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE * 0.95, 0.5, GRID_SIZE * 0.95)  # Толстая рамка
	
	target_cell_highlight.mesh = box_mesh
	
	# Создаем материал с красным цветом и свечением
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.albedo_color = Color(1, 0, 0)  # Ярко-красный
	material.emission_enabled = true
	material.emission = Color(1, 0.2, 0.2) * 0.8  # Красное свечение
	
	target_cell_highlight.material_override = material
	
	# Позиционируем подсветку под целевой точкой на земле
	var target_world_pos = grid_to_world(2, 2, 0.25)  # Чуть выше земли
	target_cell_highlight.position = target_world_pos
	
	add_child(target_cell_highlight)
	print("🔴 Подсветка целевой клетки создана: ", target_cell_highlight.position)

# Функция для установки высоты дрона в этом уровне
func set_drone_height_for_level():
	if drone_scene and drone_scene.has_method("set_drone_height"):
		drone_scene.set_drone_height(drone_height_level1)
		print("🎯 Высота дрона установлена на: ", drone_height_level1)
	else:
		print("❌ Не могу установить высоту дрона")

# Пример: изменение высоты дрона во время выполнения
func change_drone_height(new_height: float):
	drone_height_level1 = new_height
	if drone_scene and drone_scene.has_method("set_drone_height"):
		drone_scene.set_drone_height(new_height)

# Пример: поднять дрон на определенное количество единиц
func raise_drone(amount: float):
	drone_height_level1 += amount
	if drone_scene and drone_scene.has_method("set_drone_height"):
		drone_scene.set_drone_height(drone_height_level1)
	print("⬆️ Дрон поднят на ", amount, " единиц. Текущая высота: ", drone_height_level1)

# Пример: опустить дрон на определенное количество единиц
func lower_drone(amount: float):
	drone_height_level1 = max(0, drone_height_level1 - amount)  # Не ниже 0
	if drone_scene and drone_scene.has_method("set_drone_height"):
		drone_scene.set_drone_height(drone_height_level1)
	print("⬇️ Дрон опущен на ", amount, " единиц. Текущая высота: ", drone_height_level1)

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_target_point():
	if has_node("TargetPoint"):
		get_node("TargetPoint").queue_free()
	
	target_point = Area3D.new()
	target_point.name = "TargetPoint"
	
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 8.0
	collision.shape = sphere_shape
	target_point.add_child(collision)
	
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	mesh_instance.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.3
	mesh_instance.material_override = material
	
	target_point.add_child(mesh_instance)
	
	# Целевая точка на высоте 32 единицы
	target_point.position = grid_to_world(2, 2, 32)
	
	target_point.collision_layer = 2
	target_point.collision_mask = 1
	
	target_point.body_entered.connect(_on_target_body_entered)
	
	add_child(target_point)
	print("✅ Целевая точка создана: ", target_point.position)
	print("🎯 Радиус коллизии: ", sphere_shape.radius)

func _on_target_body_entered(body: Node):
	if is_level_completed:
		return
		
	print("🎯 Обнаружено столкновение с: ", body.name)
	
	if body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name):
		print("🎯 Дрон достиг цели!")
		complete_level()

func create_cell_marker(grid_x: int, grid_z: int):
	var marker = MeshInstance3D.new()
	marker.name = "CellMarker"
	
	var plane = PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * 0.9, GRID_SIZE * 0.9)
	marker.mesh = plane
	
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.albedo_color = Color(0, 1, 0, 0.2)
	marker.material_override = material
	
	marker.position = grid_to_world(grid_x, grid_z, 0.1)
	marker.rotation_degrees.x = 90
	
	add_child(marker)
	print("✅ Маркер клетки создан в: ", marker.position)

func setup_drone():
	if drone_scene == null:
		print("❌ DroneScene не найден")
		return
	
	await get_tree().create_timer(0.2).timeout
	
	var drone = drone_scene.get_drone()
	if drone == null:
		print("❌ Дрон не найден в DroneScene")
		return
	
	print("✅ Дрон найден: ", drone.name)
	print("🚁 Позиция дрона: ", drone.global_position)
	
	var collision = drone.get_node_or_null("CollisionShape3D")
	if collision:
		print("✅ Коллизия дрона найдена")
		await get_tree().process_frame
		print("📍 Позиция коллизии: ", collision.global_position)
	else:
		print("❌ У дрона нет коллизии!")
	
	drone.collision_layer = 1
	drone.collision_mask = 2
	
	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)
		print("✅ Сигнал program_finished подключен")
	else:
		print("❌ Сигнал program_finished не найден")

func _on_drone_program_finished(success: bool):
	print("🎯 Программа дрона завершена, успех: ", success)
	if success:
		complete_level()

func complete_level():
	if is_level_completed:
		return
		
	is_level_completed = true
	print("🎉 УРОВЕНЬ 1 ЗАВЕРШЕН!")
	
	# Добавляем эффект мигания подсветки при завершении уровня
	if target_cell_highlight:
		blink_target_highlight()
	
	var drone_scene = $DroneScene
	if drone_scene and drone_scene.has_method("_on_program_finished"):
		drone_scene._on_program_finished(true)
	
	if Global:
		Global.complete_level(1, 5, 3)
		print("✅ Прогресс сохранен")

# Функция для мигания подсветки при завершении уровня
func blink_target_highlight():
	if not target_cell_highlight:
		return
	
	var tween = create_tween()
	tween.set_loops(3)  # Мигаем 3 раза
	
	# Мигание: ярко-красный -> почти прозрачный -> ярко-красный
	tween.tween_property(target_cell_highlight.material_override, "emission", Color(1, 0.2, 0.2) * 0.2, 0.3)
	tween.tween_property(target_cell_highlight.material_override, "emission", Color(1, 0.2, 0.2) * 1.5, 0.3)

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15
	
	var panel = Panel.new()
	panel.size = Vector2(400, 200)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color.GREEN
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "УРОВЕНЬ ПРОЙДЕН!\n\nАвтоматический возврат через 3 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.GREEN)
	label.size = panel.size
	
	panel.add_child(label)
	success_ui.add_child(panel)
	add_child(success_ui)
	
	await get_tree().create_timer(3.0).timeout
	return_to_selection()

func _input(event):
	if event is InputEventKey and event.pressed:
		# ТЕСТИРОВАНИЕ: Изменение высоты дрона клавишами
		match event.keycode:
			KEY_UP:
				raise_drone(16)  # Поднять на полклетки
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				lower_drone(16)  # Опустить на полклетки
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				return_to_selection()
				get_viewport().set_input_as_handled()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://script_game_level.tscn")
