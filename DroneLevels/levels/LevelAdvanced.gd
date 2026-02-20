extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_point: Area3D
var is_level_completed = false
var mission_failed = false
var platform_tweens: Array[Tween] = []

var level_number: int = 7
var level_title: String = "УРОВЕНЬ"
var level_hint: String = "Пройди маршрут"
var completion_text: String = "Отличная работа!"

var start_grid: Vector2i = Vector2i(-2, -2)
var start_height: float = 8.0
var target_grid: Vector2i = Vector2i(3, 2)
var target_height: float = 64.0
var drone_in_target: bool = false

# Дополнительные механики миссий
var mission_time_limit_sec: float = 0.0
var mission_timer: Timer = null
var required_collectibles: int = 0
var collected_collectibles: int = 0
var collectibles_data: Array[Dictionary] = []

# Режим цели уровня
var requires_cargo_delivery: bool = false
var cargo_start_grid: Vector2i = Vector2i(0, 0)
var cargo_start_height: float = 8.0
var cargo_drop_grid: Vector2i = Vector2i(2, 2)
var cargo_drop_height: float = 8.0
var cargo_delivered: bool = false
var cargo_object: Node3D = null
var cargo_drop_marker: Node3D = null

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
	create_collectibles()
	if requires_cargo_delivery:
		create_cargo_objective()
	setup_mission_timer()
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

func create_collectibles():
	collected_collectibles = 0
	for i in range(collectibles_data.size()):
		var data = collectibles_data[i]
		var collectible := Area3D.new()
		collectible.name = "Collectible_%d" % i
		collectible.set_meta("collectible_index", i)

		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 5.0
		collision.shape = shape
		collectible.add_child(collision)

		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 3.5
		sphere.height = 7.0
		mesh_instance.mesh = sphere

		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.9, 0.2)
		material.emission_enabled = true
		material.emission = Color(0.95, 0.9, 0.2) * 0.45
		mesh_instance.material_override = material
		collectible.add_child(mesh_instance)

		collectible.position = grid_to_world(data["grid"].x, data["grid"].y, data["height"])
		collectible.body_entered.connect(_on_collectible_body_entered.bind(collectible))
		add_child(collectible)

func setup_mission_timer():
	if mission_time_limit_sec <= 0:
		return
	mission_timer = Timer.new()
	mission_timer.one_shot = true
	mission_timer.wait_time = mission_time_limit_sec
	mission_timer.timeout.connect(_on_mission_time_expired)
	add_child(mission_timer)
	mission_timer.start()

func _on_collectible_body_entered(body: Node, collectible: Area3D):
	if mission_failed or is_level_completed:
		return
	if not (body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name)):
		return
	if collectible == null or not is_instance_valid(collectible):
		return

	collectible.queue_free()
	collected_collectibles += 1
	print("⭐ Собран предмет: %d/%d" % [collected_collectibles, required_collectibles])
	try_complete_level()

func create_cargo_objective():
	create_cargo_object()
	create_cargo_drop_zone()
	create_cargo_hint()

func create_cargo_object():
	cargo_object = StaticBody3D.new()
	cargo_object.name = "CargoBox"
	cargo_object.add_to_group("grabbable_cargo")

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(12, 12, 12)
	collision.shape = shape
	cargo_object.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(12, 12, 12)
	mesh_instance.mesh = mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.6, 0.15)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.15) * 0.25
	mesh_instance.material_override = material
	cargo_object.add_child(mesh_instance)

	cargo_object.position = grid_to_world(cargo_start_grid.x, cargo_start_grid.y, cargo_start_height)
	add_child(cargo_object)

func create_cargo_drop_zone():
	cargo_drop_marker = Node3D.new()
	cargo_drop_marker.name = "CargoDropZone"
	cargo_drop_marker.position = grid_to_world(cargo_drop_grid.x, cargo_drop_grid.y, cargo_drop_height)

	var ring = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 12
	cylinder.bottom_radius = 12
	cylinder.height = 1.5
	ring.mesh = cylinder

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.95, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.3, 0.95, 1.0) * 0.4
	ring.material_override = material
	cargo_drop_marker.add_child(ring)

	var label_3d = Label3D.new()
	label_3d.text = "Зона доставки"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 14
	label_3d.modulate = Color(0.6, 1, 1)
	label_3d.position = Vector3(0, 10, 0)
	cargo_drop_marker.add_child(label_3d)

	add_child(cargo_drop_marker)

func create_cargo_hint():
	var hint = Label3D.new()
	hint.text = "🧲 Захвати контейнер и доставь в зону"
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.font_size = 16
	hint.modulate = Color(1.0, 0.95, 0.5)
	hint.position = grid_to_world(cargo_start_grid.x, cargo_start_grid.y, cargo_start_height + 18)
	add_child(hint)

func _on_target_body_entered(body: Node):
	if is_level_completed or mission_failed:
		return

	if body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name):
		drone_in_target = true
		try_complete_level()

func setup_drone():
	if drone_scene == null:
		print("❌ DroneScene не найден")
		return

	await get_tree().create_timer(0.2).timeout

	var drone = drone_scene.get_drone()
	if drone == null:
		print("❌ Дрон не найден в DroneScene")
		return

	drone.global_position = grid_to_world(start_grid.x, start_grid.y, start_height)
	drone.collision_layer = 1
	drone.collision_mask = 2

	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)

	if requires_cargo_delivery and drone.has_signal("action_executed"):
		drone.action_executed.connect(_on_drone_action_executed)
	if requires_cargo_delivery and drone.has_signal("drone_moved"):
		drone.drone_moved.connect(_on_drone_moved)

func _on_drone_action_executed(_action_type: int):
	check_cargo_delivery_condition()

func _on_drone_moved():
	check_cargo_delivery_condition()

func check_cargo_delivery_condition():
	if not requires_cargo_delivery or cargo_delivered or mission_failed:
		return
	if cargo_object == null or not is_instance_valid(cargo_object):
		return
	if cargo_drop_marker == null:
		return

	var drone = drone_scene.get_drone()
	if drone and drone.has_method("has_carried_cargo") and drone.has_carried_cargo():
		return

	var drop_distance = cargo_object.global_position.distance_to(cargo_drop_marker.global_position)
	if drop_distance <= 14.0:
		cargo_delivered = true
		print("✅ Контейнер доставлен в зону")
		try_complete_level()

func _on_drone_program_finished(success: bool):
	if not success or mission_failed:
		return
	try_complete_level()

func try_complete_level():
	if is_level_completed or mission_failed:
		return
	if not _mission_goals_done():
		return
	complete_level()

func _mission_goals_done() -> bool:
	if requires_cargo_delivery and not cargo_delivered:
		return false
	if required_collectibles > 0 and collected_collectibles < required_collectibles:
		return false
	if not requires_cargo_delivery and not drone_in_target:
		return false
	return true

func _on_mission_time_expired():
	if is_level_completed:
		return
	mission_failed = true
	print("⏰ Время миссии истекло")
	show_failure_message()

func show_failure_message():
	var fail_ui = CanvasLayer.new()
	fail_ui.layer = 16

	var panel = Panel.new()
	panel.size = Vector2(520, 190)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2

	var label = Label.new()
	label.text = "ВРЕМЯ ВЫШЛО!\nПовтор через 2 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = panel.size
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))

	panel.add_child(label)
	fail_ui.add_child(panel)
	add_child(fail_ui)

	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func complete_level():
	if is_level_completed:
		return

	is_level_completed = true
	if mission_timer and is_instance_valid(mission_timer):
		mission_timer.stop()

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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://UI/game_level.tscn")
