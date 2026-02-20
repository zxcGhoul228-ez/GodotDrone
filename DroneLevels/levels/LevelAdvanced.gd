extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var platform_tweens: Array[Tween] = []

var level_number: int = 7
var level_title: String = "УРОВЕНЬ"
var level_hint: String = "Пройди маршрут"
var completion_text: String = "Отличная работа!"

var start_grid: Vector2i = Vector2i(-2, -2)
var start_height: float = 8.0
var target_grid: Vector2i = Vector2i(3, 2)
var target_height: float = 64.0

var moving_platforms_data: Array[Dictionary] = []
var moving_obstacles_data: Array[Dictionary] = []
var static_obstacles_data: Array[Dictionary] = []

func _ready():
	print("🎮 %s %d ЗАГРУЖЕН" % [level_title, level_number])
	print(level_hint)

	await get_tree().process_frame
	setup_level()

func setup_level():
	create_moving_platforms()
	create_moving_obstacles()
	create_static_obstacles()
	create_target_point()
	await setup_drone()
	print("✅ Уровень %d настроен" % level_number)

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0.0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_moving_platforms():
	for i in range(moving_platforms_data.size()):
		var data = moving_platforms_data[i]
		create_moving_platform(
			"Platform_%d" % i,
			grid_to_world(data["from"].x, data["from"].y, data["height"]),
			grid_to_world(data["to"].x, data["to"].y, data["height"]),
			data["speed"],
			data["color"]
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

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(platform, "position", end_pos, speed)
	tween.tween_property(platform, "position", start_pos, speed)
	platform_tweens.append(tween)

func create_moving_obstacles():
	for i in range(moving_obstacles_data.size()):
		var data = moving_obstacles_data[i]
		create_moving_obstacle(
			"Gate_%d" % i,
			grid_to_world(data["from"].x, data["from"].y, data["height"]),
			grid_to_world(data["to"].x, data["to"].y, data["height"]),
			data["speed"],
			data["size"],
			data["color"]
		)

func create_moving_obstacle(name: String, start_pos: Vector3, end_pos: Vector3, speed: float, size: Vector3, color: Color):
	var obstacle = StaticBody3D.new()
	obstacle.name = name

	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	obstacle.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.2
	mesh_instance.material_override = material

	obstacle.add_child(mesh_instance)
	obstacle.position = start_pos
	add_child(obstacle)

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(obstacle, "position", end_pos, speed)
	tween.tween_property(obstacle, "position", start_pos, speed)
	platform_tweens.append(tween)

func create_static_obstacles():
	for i in range(static_obstacles_data.size()):
		var data = static_obstacles_data[i]
		var obstacle = StaticBody3D.new()
		obstacle.name = "Obstacle_%d" % i

		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = data["size"]
		collision.shape = box_shape
		obstacle.add_child(collision)

		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = data["size"]
		mesh_instance.mesh = box_mesh

		var material = StandardMaterial3D.new()
		material.albedo_color = data.get("color", Color(0.25, 0.25, 0.35))
		mesh_instance.material_override = material

		obstacle.add_child(mesh_instance)
		obstacle.position = grid_to_world(data["grid"].x, data["grid"].y, data["height"])
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
	material.albedo_color = Color(0.2, 1, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.2, 1, 0.7) * 0.35
	mesh_instance.material_override = material

	target_point.add_child(mesh_instance)
	target_point.position = grid_to_world(target_grid.x, target_grid.y, target_height)
	target_point.collision_layer = 2
	target_point.collision_mask = 1
	target_point.body_entered.connect(_on_target_body_entered)

	add_child(target_point)
	print("✅ Целевая точка создана: ", target_point.position)

func _on_target_body_entered(body: Node):
	if is_level_completed:
		return

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
	drone.global_position = grid_to_world(start_grid.x, start_grid.y, start_height)
	drone.collision_layer = 1
	drone.collision_mask = 2

	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)
		print("✅ Сигнал program_finished подключен")

func _on_drone_program_finished(success: bool):
	if success:
		complete_level()

func complete_level():
	if is_level_completed:
		return

	is_level_completed = true
	print("🎉 УРОВЕНЬ %d ЗАВЕРШЕН!" % level_number)

	for tween in platform_tweens:
		tween.kill()

	var current_drone_scene = $DroneScene
	if current_drone_scene and current_drone_scene.has_method("_on_program_finished"):
		current_drone_scene._on_program_finished(true)

	show_success_message()

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15

	var panel = Panel.new()
	panel.size = Vector2(560, 240)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.82)
	style.border_color = Color(0.2, 1, 0.7)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "УРОВЕНЬ %d ПРОЙДЕН!\n\n%s\nАвтоматический возврат через 4 секунды..." % [level_number, completion_text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.2, 1, 0.7))
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
	get_tree().change_scene_to_file("res://UI/game_level.tscn")
