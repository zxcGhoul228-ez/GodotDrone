extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var wall: StaticBody3D

func _ready():
	print("🎮 УРОВЕНЬ 3 ЗАГРУЖЕН")
	print("Текущий уровень: ", Global.current_level)
	
	await get_tree().process_frame
	setup_level()

func setup_level():
	create_target_point()
	create_wall_obstacle()
	create_cell_marker(4, 4)
	await setup_drone()
	print("✅ Уровень 3 настроен")

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_target_point():
	# Удаляем старую цель если есть
	if has_node("TargetPoint"):
		get_node("TargetPoint").queue_free()
	
	# Создаем Area3D
	target_point = Area3D.new()
	target_point.name = "TargetPoint"
	
	# Добавляем коллизию
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 8.0
	collision.shape = sphere_shape
	target_point.add_child(collision)
	
	# Добавляем визуальную сферу
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
	
	# Позиция цели ЗА стеной на высоте
	target_point.position = grid_to_world(4, 4, 32)
	
	# Настраиваем маски коллизий
	target_point.collision_layer = 2
	target_point.collision_mask = 1
	
	# Подключаем сигнал столкновения
	target_point.body_entered.connect(_on_target_body_entered)
	
	add_child(target_point)
	print("✅ Целевая точка создана: ", target_point.position)

func create_wall_obstacle():
	# Создаем стену как StaticBody3D
	wall = StaticBody3D.new()
	wall.name = "WallObstacle"
	
	# Добавляем коллизию для стены
	var wall_collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	# РАСШИРЯЕМ СТЕНУ: было 3 клетки, стало 7 клеток в ширину
	box_shape.size = Vector3(GRID_SIZE * 7, GRID_SIZE * 2, 1)  # Широкая и высокая стена
	wall_collision.shape = box_shape
	wall.add_child(wall_collision)
	
	# Добавляем визуальную часть стены
	var wall_mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	# Соответственно расширяем визуальную часть
	box_mesh.size = Vector3(GRID_SIZE * 7, GRID_SIZE * 2, 2)  # Немного толще для видимости
	wall_mesh.mesh = box_mesh
	
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.7, 0.3, 0.1)  # Коричневый цвет
	wall_mesh.material_override = wall_material
	
	wall.add_child(wall_mesh)
	
	# Позиционируем стену между стартом и целью
	wall.position = grid_to_world(2, 2, GRID_SIZE)  # Стена на высоте одной клетки
	
	add_child(wall)
	print("✅ Расширенная стена-препятствие создана: ", wall.position)
	print("📏 Размер стены: ", box_shape.size)

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
	
	# Позиционируем дрона ПЕРЕД стеной
	drone.global_position = grid_to_world(0, 0, GRID_SIZE)
	
	# Настраиваем маски коллизий дрона
	drone.collision_layer = 1
	drone.collision_mask = 2   # Реагирует на слой 2 (цель)
	
	# Подключаем сигнал завершения программы
	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)
		print("✅ Сигнал program_finished подключен")
	else:
		print("❌ Сигнал program_finished не найден")

func _on_target_body_entered(body: Node):
	if is_level_completed:
		return
		
	print("🎯 Обнаружено столкновение с: ", body.name)
	
	# Проверяем что это дрон
	if body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name):
		print("🎯 Дрон достиг цели!")
		complete_level()

func _on_drone_program_finished(success: bool):
	print("🎯 Программа дрона завершена, успех: ", success)
	if success:
		complete_level()

func complete_level():
	if is_level_completed:
		return
		
	is_level_completed = true
	print("🎉 УРОВЕНЬ 3 ЗАВЕРШЕН!")
	
	# Оповещаем дрон об успешном завершении
	var drone_scene = $DroneScene
	if drone_scene and drone_scene.has_method("_on_program_finished"):
		drone_scene._on_program_finished(true)
	
	# Сохраняем прогресс
	if Global:
		Global.complete_level(3, 8, 3)  # level_number, target_steps, max_stars
		print("✅ Прогресс сохранен")

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
	label.text = "УРОВЕНЬ 3 ПРОЙДЕН!\n\nПреодолено широкое препятствие!\nАвтоматический возврат через 3 секунды..."
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_selection()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://script_game_level.tscn")
