extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var maze_walls = []

func _ready():
	print("🎮 УРОВЕНЬ 5 ЗАГРУЖЕН")
	print("Пройди 3D-лабиринт!")
	
	await get_tree().process_frame
	setup_level()

func setup_level():
	create_maze()
	create_target_point()
	await setup_drone()
	print("✅ Лабиринт настроен")

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_maze():
	# Очищаем предыдущие стены
	for wall in maze_walls:
		wall.queue_free()
	maze_walls.clear()
	
	# Определяем структуру лабиринта 5x5x2 (x,z,y) - ТОЛЬКО 2 УРОВНЯ
	# 0 = проход, 1 = стена
	var maze_layout = [
		# Уровень 0 (земля)
		[
			[0, 1, 0, 0, 0],
			[0, 1, 0, 1, 0],
			[0, 0, 0, 1, 0],
			[1, 1, 0, 1, 0],
			[0, 0, 0, 1, 0]
		],
		# Уровень 1 (высота 32) - ТЕПЕРЬ ЭТО ВЕРХНИЙ УРОВЕНЬ
		[
			[1, 1, 1, 1, 0],
			[0, 0, 0, 1, 0],
			[0, 1, 0, 0, 0],
			[0, 1, 1, 1, 1],
			[0, 0, 0, 0, 0]
		]
		# Уровень 2 (высота 64) - УБРАН ПОЛНОСТЬЮ
	]
	
	# Создаем стены лабиринта только для 2 уровней
	for y in range(2):  # БЫЛО 3, СТАЛО 2
		for x in range(5):
			for z in range(5):
				if maze_layout[y][x][z] == 1:
					create_wall(x - 2, z - 2, y * GRID_SIZE)

func create_wall(grid_x: int, grid_z: int, height: float):
	var wall = StaticBody3D.new()
	wall.name = "Wall_%d_%d_%d" % [grid_x, grid_z, height]
	
	# Коллизия
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(GRID_SIZE, GRID_SIZE, GRID_SIZE)
	collision.shape = box_shape
	wall.add_child(collision)
	
	# Визуал - разные цвета для разных уровней
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE, GRID_SIZE, GRID_SIZE)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	if height == 0:
		material.albedo_color = Color(0.5, 0.3, 0.1)  # Коричневый - земля
	elif height == 32:
		material.albedo_color = Color(0.3, 0.3, 0.3)  # Серый - первый уровень
	else:
		material.albedo_color = Color(0.1, 0.1, 0.5)  # Синий - второй уровень
	
	mesh_instance.material_override = material
	wall.add_child(mesh_instance)
	
	wall.position = grid_to_world(grid_x, grid_z, height + GRID_SIZE/2)
	add_child(wall)
	maze_walls.append(wall)


func create_direction_arrows():
	# Стрелки для подсказок маршрута (обновленные для 2 уровней)
	var arrow_positions = [
		{"pos": Vector3(-16, 16, -48), "text": "↑ Начни здесь"},
		{"pos": Vector3(16, 48, 0), "text": "↗ Поднимись"},
		{"pos": Vector3(48, 16, 48), "text": "↓ Спустись к цели"}
	]
	
	for arrow in arrow_positions:
		create_floating_text(arrow["pos"], arrow["text"])

func create_floating_text(position: Vector3, text: String):
	var label_3d = Label3D.new()
	label_3d.text = text
	label_3d.font_size = 16
	label_3d.modulate = Color(1, 1, 0, 0.8)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = position
	add_child(label_3d)

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
	
	# Цель в дальнем углу лабиринта на земле
	target_point.position = grid_to_world(2, 2, 0)
	
	target_point.collision_layer = 2
	target_point.collision_mask = 1
	target_point.body_entered.connect(_on_target_body_entered)
	
	add_child(target_point)
	print("✅ Целевая точка создана: ", target_point.position)

func _on_target_body_entered(body: Node):
	if is_level_completed:
		return
		
	print("🎯 Обнаружено столкновение с: ", body.name)
	
	if body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name):
		print("🎯 Дрон достиг цели лабиринта!")
		complete_level()

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
	print("🚁 Стартовая позиция дрона: ", drone.global_position)
	
	# Начальная позиция дрона в лабиринте
	drone.global_position = grid_to_world(-2, -2, 16)
	
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
	print("🎉 ЛАБИРИНТ ПРОЙДЕН!")
	
	var drone_scene = $DroneScene
	if drone_scene and drone_scene.has_method("_on_program_finished"):
		drone_scene._on_program_finished(true)
	
	# УДАЛЕНО: Global.complete_level(5, 20, 8) - теперь это делается автоматически в DroneScene
	print("✅ Прогресс будет сохранен автоматически")
	
	show_success_message()

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15
	
	var panel = Panel.new()
	panel.size = Vector2(450, 220)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color(0, 1, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "ЛАБИРИНТ ПРОЙДЕН!\n\nОтличная работа с 3D-навигацией!\nАвтоматический возврат через 4 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0, 1, 1))
	label.size = panel.size
	
	panel.add_child(label)
	success_ui.add_child(panel)
	add_child(success_ui)
	
	await get_tree().create_timer(4.0).timeout
	return_to_selection()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_selection()

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://script_game_level.gd")
