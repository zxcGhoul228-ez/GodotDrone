# Level1.gd
extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: MeshInstance3D
var is_level_completed = false

func _ready():
	print("🎮 УРОВЕНЬ 1 ЗАГРУЖЕН")
	print("Текущий уровень: ", Global.current_level)
	
	# Ждем полной загрузки
	await get_tree().process_frame
	
	setup_level()

func setup_level():
	# Создаем целевую точку и маркер клетки
	create_target_point()
	create_cell_marker(2, 2)  # Маркер для клетки (2, 2)
	
	# Настраиваем дрона
	setup_drone()
	
	print("✅ Уровень 1 настроен")

# Конвертирует координаты сетки в мировые координаты (центр клетки)
func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_target_point():
	target_point = MeshInstance3D.new()
	target_point.name = "TargetPoint"
	
	# Создаем сферу
	var sphere = SphereMesh.new()
	sphere.radius = 4
	sphere.height = 8
	target_point.mesh = sphere
	
	# Зеленый материал с свечением
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.3
	target_point.material_override = material
	
	# Позиция цели - В ЦЕНТРЕ клетки (2, 2) на высоте 8 единиц
	target_point.position = grid_to_world(2, 2, 8)
	
	add_child(target_point)
	print("✅ Целевая точка создана в центре клетки (2, 2): ", target_point.position)

func create_cell_marker(grid_x: int, grid_z: int):
	var marker = MeshInstance3D.new()
	marker.name = "CellMarker"
	
	# Создаем плоский квадрат для маркировки клетки
	var plane = PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * 0.9, GRID_SIZE * 0.9)
	marker.mesh = plane
	
	# Полупрозрачный зеленый материал
	var material = StandardMaterial3D.new()
	material.flags_transparent = true
	material.albedo_color = Color(0, 1, 0, 0.2)  # Зеленый, полупрозрачный
	marker.material_override = material
	
	# Позиция маркера - центр клетки чуть выше пола
	marker.position = grid_to_world(grid_x, grid_z, 0.1)
	
	# Поворачиваем на 90 градусов чтобы лежал плоско
	marker.rotation_degrees.x = 90
	
	add_child(marker)
	print("✅ Маркер клетки создан в: ", marker.position)

func setup_drone():
	if drone_scene == null:
		print("❌ DroneScene не найден")
		return
	
	# Находим дрона в DroneScene
	var drone = drone_scene.find_child("Drone") as CharacterBody3D
	if drone == null:
		print("❌ Дрон не найден в DroneScene")
		return
	
	print("✅ Дрон найден: ", drone.name)
	
	# Устанавливаем стартовую позицию - В ЦЕНТРЕ клетки (-2, -2) на стандартной высоте
	drone.global_position = grid_to_world(-2, -2, GRID_SIZE)
	print("🚁 Дрон установлен в центре клетки (-2, -2): ", drone.global_position)
	
	# Создаем маркер для стартовой клетки
	create_cell_marker(-2, -2)
	
	# Подключаем сигнал движения дрона
	if drone.has_signal("drone_moved"):
		drone.drone_moved.connect(_on_drone_moved)
		print("✅ Сигнал движения подключен")
	else:
		print("❌ Сигнал drone_moved не найден")

func _on_drone_moved():
	if is_level_completed:
		return
		
	check_level_completion()

func check_level_completion():
	if target_point == null:
		return
		
	var drone_scene = $DroneScene
	if drone_scene == null:
		return
		
	var drone = drone_scene.find_child("Drone") as CharacterBody3D
	if drone == null:
		return
	
	var distance = drone.global_position.distance_to(target_point.global_position)
	print("📏 Расстояние до цели: ", distance)
	
	# Если дрон близко к цели (в пределах четверти клетки)
	if distance < GRID_SIZE / 4:
		complete_level()

func complete_level():
	if is_level_completed:
		return
		
	is_level_completed = true
	print("🎉 УРОВЕНЬ 1 ЗАВЕРШЕН!")
	
	# Сохраняем прогресс
	if Global:
		Global.complete_level(1, 5, 3)
		print("✅ Прогресс сохранен")
	
	show_success_message()

func show_success_message():
	var label = Label.new()
	label.text = "УРОВЕНЬ 1 ЗАВЕРШЕН!\nОтличная работа!\n\nАвтоматический возврат через 3 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.GREEN)
	
	var panel = Panel.new()
	panel.size = Vector2(500, 200)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	panel.add_child(label)
	
	var canvas = CanvasLayer.new()
	canvas.add_child(panel)
	add_child(canvas)
	
	# Возвращаемся через 3 секунды
	await get_tree().create_timer(3.0).timeout
	return_to_selection()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_selection()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	get_tree().change_scene_to_file("res://script_game_level.tscn")
