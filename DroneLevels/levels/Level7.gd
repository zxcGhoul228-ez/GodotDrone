extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var moving_platforms = []
var platform_tweens = []

func _ready():
	print("🎮 УРОВЕНЬ 7 ЗАГРУЖЕН")
	print("Комбинируй платформы и препятствия!")
	
	await get_tree().process_frame
	setup_level()

func setup_level():
	create_moving_platforms()
	create_static_obstacles()
	create_target_point()
	await setup_drone()
	print("✅ Уровень 7 настроен")

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_moving_platforms():
	create_moving_platform(
		"Platform_A",
		grid_to_world(-2, -2, 8),
		grid_to_world(1, -2, 8),
		3.5,
		Color(0.9, 0.4, 0.2)
	)
	
	create_moving_platform(
		"Platform_B",
		grid_to_world(0, 0, 24),
		grid_to_world(2, 1, 24),
		4.2,
		Color(0.2, 0.7, 0.9)
	)
	
	create_moving_platform(
		"Platform_C",
		grid_to_world(-1, 1, 40),
		grid_to_world(1, 2, 40),
		3.8,
		Color(0.3, 0.9, 0.5)
	)

func create_moving_platform(name: String, start_pos: Vector3, end_pos: Vector3, speed: float, color: Color):
	var platform = StaticBody3D.new()
	platform.name = name
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(GRID_SIZE - 6, 2, GRID_SIZE - 6)
	collision.shape = box_shape
	platform.add_child(collision)
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE - 6, 2, GRID_SIZE - 6)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.25
	mesh_instance.material_override = material
	
	platform.add_child(mesh_instance)
	platform.position = start_pos
	
	var label_3d = Label3D.new()
	label_3d.text = "↔"
	label_3d.font_size = 14
	label_3d.modulate = Color(1, 1, 1, 0.7)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = Vector3(0, 3, 0)
	platform.add_child(label_3d)
	
	add_child(platform)
	moving_platforms.append(platform)
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(platform, "position", end_pos, speed)
	tween.tween_property(platform, "position", start_pos, speed)
	platform_tweens.append(tween)

func create_static_obstacles():
	var obstacles = [
		{"pos": grid_to_world(-1, -1, 0), "size": Vector3(GRID_SIZE, 18, GRID_SIZE)},
		{"pos": grid_to_world(1, -1, 0), "size": Vector3(GRID_SIZE, 26, GRID_SIZE)},
		{"pos": grid_to_world(-2, 1, 0), "size": Vector3(GRID_SIZE, 30, GRID_SIZE)},
		{"pos": grid_to_world(1, 2, 0), "size": Vector3(GRID_SIZE, 34, GRID_SIZE)}
	]
	
	for i in range(obstacles.size()):
		var obstacle_data = obstacles[i]
		var obstacle = StaticBody3D.new()
		obstacle.name = "Obstacle_%d" % i
		
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = obstacle_data["size"]
		collision.shape = box_shape
		obstacle.add_child(collision)
		
		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = obstacle_data["size"]
		mesh_instance.mesh = box_mesh
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.3, 0.3)
		mesh_instance.material_override = material
		
		obstacle.add_child(mesh_instance)
		obstacle.position = obstacle_data["pos"]
		add_child(obstacle)

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
	material.albedo_color = Color(0.3, 1, 0.4)
	material.emission_enabled = true
	material.emission = Color(0.3, 1, 0.4) * 0.3
	mesh_instance.material_override = material
	
	target_point.add_child(mesh_instance)
	
	target_point.position = grid_to_world(2, 2, 52)
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
		print("🎯 Дрон достиг цели!")
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
	
	drone.global_position = grid_to_world(-2, -2, 8)
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
	print("🎉 УРОВЕНЬ 7 ЗАВЕРШЕН!")
	
	for tween in platform_tweens:
		tween.kill()
	
	var current_drone_scene = $DroneScene
	if current_drone_scene and current_drone_scene.has_method("_on_program_finished"):
		current_drone_scene._on_program_finished(true)
	
	print("✅ Прогресс будет сохранен автоматически")
	show_success_message()

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15
	
	var panel = Panel.new()
	panel.size = Vector2(500, 220)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color(0.3, 1, 0.4)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "УРОВЕНЬ 7 ПРОЙДЕН!\n\nОтличная работа с платформами!\nАвтоматический возврат через 4 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
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
	
	var level_selection_path = "res://script_game_level.tscn"
	if FileAccess.file_exists(level_selection_path):
		get_tree().change_scene_to_file(level_selection_path)
	else:
		get_tree().change_scene_to_file("res://main_scene.tscn")
