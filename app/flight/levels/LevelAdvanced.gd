extends Node3D

const GRID_SIZE = 32
const PLATFORM_THICKNESS = 3.2
const PLATFORM_MARGIN = 8.0
const GUIDE_BARRIER_THICKNESS = 1.6
const GUIDE_BARRIER_HEIGHT = 12.0
const GUIDE_BARRIER_OFFSET = 12.0
const GUIDE_DASH_LENGTH = 10.0
const GUIDE_DASH_GAP = 7.0
const MIN_SAFE_HEIGHT = 0.0

signal intro_closed

@onready var drone_scene: Node3D = $DroneScene
var target_point: Area3D
var is_level_completed = false
var platform_tweens: Array[Tween] = []
var intro_overlay: CanvasLayer = null
var is_intro_visible: bool = false
var intro_accepts_input: bool = false
var previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var previous_drone_scene_process_mode: int = Node.PROCESS_MODE_INHERIT
var level_description: String = ""
var guide_barrier_nodes: Array[Node3D] = []

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
	await _show_level_intro()
	setup_level()

func _show_level_intro():
	_set_drone_scene_active(false)
	previous_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	intro_overlay = CanvasLayer.new()
	intro_overlay.layer = 40
	add_child(intro_overlay)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.11, 0.07, 0.04, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_overlay.add_child(backdrop)

	var panel: Panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360
	panel.offset_top = -200
	panel.offset_right = 360
	panel.offset_bottom = 200
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _build_intro_panel_style())
	intro_overlay.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title_label: Label = Label.new()
	title_label.text = "Уровень %d" % level_number
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "Уровень %d" % level_number
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	layout.add_child(title_label)

	var hint_label: Label = Label.new()
	hint_label.text = level_hint
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.66))
	layout.add_child(hint_label)

	var body_label: Label = Label.new()
	body_label.text = level_description if not level_description.is_empty() else level_hint
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.80))
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body_label)

	var continue_label: Label = Label.new()
	continue_label.text = "Нажмите любую клавишу или кнопку мыши, чтобы продолжить"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.text = "Нажмите любую клавишу или кнопку мыши, чтобы продолжить"
	continue_label.add_theme_font_size_override("font_size", 16)
	continue_label.add_theme_color_override("font_color", Color(0.86, 0.68, 0.44))
	layout.add_child(continue_label)

	is_intro_visible = true
	intro_accepts_input = false
	await get_tree().process_frame
	await get_tree().create_timer(0.18).timeout
	intro_accepts_input = true
	await intro_closed

	_set_drone_scene_active(true)
	if previous_mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(previous_mouse_mode)

func _build_intro_body_text() -> String:
	if not level_description.is_empty():
		return level_description

	var platform_count: int = moving_platforms_data.size()
	var dynamic_gate_count: int = moving_obstacles_data.size()
	var static_count: int = static_obstacles_data.size()

	return "Задача: доведите дрон до светящейся цели.\n\nПлатформ по маршруту: %d\nДвижущихся преград: %d\nСтатичных препятствий: %d\nВысота финиша: %d" % [
		platform_count,
		dynamic_gate_count,
		static_count,
		int(target_height)
	]

func _build_level_story_text() -> String:
	if not level_description.is_empty():
		return level_description

	var platform_count: int = moving_platforms_data.size()
	var dynamic_gate_count: int = moving_obstacles_data.size()
	var static_count: int = static_obstacles_data.size()
	var description_parts: PackedStringArray = [level_hint]
	if platform_count > 0:
		description_parts.append("Следите за платформами: они двигаются мягко, но столкновение с ними уже считается аварией.")
	if dynamic_gate_count > 0:
		description_parts.append("Подвижные преграды требуют тайминга: проходите только когда окно действительно свободно.")
	if static_count > 0:
		description_parts.append("Маршрут стал плотнее, поэтому держите высоту и не цепляйте боковые препятствия.")
	return "\n\n".join(description_parts)

func _build_intro_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.12, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.80, 0.62, 0.40, 0.84)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 16
	return style

func _set_drone_scene_active(active: bool):
	if drone_scene == null:
		return
	if active:
		drone_scene.process_mode = previous_drone_scene_process_mode
	else:
		previous_drone_scene_process_mode = drone_scene.process_mode
		drone_scene.process_mode = Node.PROCESS_MODE_DISABLED

func _close_intro_overlay():
	if not is_intro_visible:
		return
	is_intro_visible = false
	intro_accepts_input = false
	if intro_overlay != null and is_instance_valid(intro_overlay):
		intro_overlay.queue_free()
	intro_overlay = null
	emit_signal("intro_closed")

func setup_level():
	_clear_guide_barriers()
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
		var data: Dictionary = moving_platforms_data[i]
		create_moving_platform(
			"Platform_%d" % i,
			grid_to_world(data["from"].x, data["from"].y, data["height"]),
			grid_to_world(data["to"].x, data["to"].y, data["height"]),
			data["speed"],
			data["color"]
		)

func create_moving_platform(name: String, start_pos: Vector3, end_pos: Vector3, speed: float, color: Color):
	var platform: StaticBody3D = StaticBody3D.new()
	platform.name = name
	platform.collision_layer = 2
	platform.collision_mask = 0
	platform.add_to_group("crash_hazard")
	platform.set_meta("hazard_kind", "moving_platform")

	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(GRID_SIZE - PLATFORM_MARGIN, PLATFORM_THICKNESS, GRID_SIZE - PLATFORM_MARGIN)
	collision.shape = box_shape
	platform.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(GRID_SIZE - PLATFORM_MARGIN, PLATFORM_THICKNESS, GRID_SIZE - PLATFORM_MARGIN)
	mesh_instance.mesh = box_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.06)
	material.emission_enabled = true
	material.emission = color * 0.92
	material.emission_energy_multiplier = 1.15
	material.roughness = 0.36
	material.metallic = 0.18
	mesh_instance.material_override = material

	platform.add_child(mesh_instance)
	platform.position = start_pos
	platform.position.y = maxf(platform.position.y, MIN_SAFE_HEIGHT + PLATFORM_THICKNESS * 0.5)

	var glow_plate: MeshInstance3D = MeshInstance3D.new()
	var glow_mesh: BoxMesh = BoxMesh.new()
	glow_mesh.size = Vector3(GRID_SIZE - PLATFORM_MARGIN - 2.0, 0.4, GRID_SIZE - PLATFORM_MARGIN - 2.0)
	glow_plate.mesh = glow_mesh
	glow_plate.position = Vector3(0, PLATFORM_THICKNESS * 0.18, 0)
	var glow_material: StandardMaterial3D = StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(color.r, color.g, color.b, 0.98)
	glow_material.emission_enabled = true
	glow_material.emission = color
	glow_material.emission_energy_multiplier = 1.25
	glow_material.roughness = 0.18
	glow_plate.material_override = glow_material
	platform.add_child(glow_plate)

	var accent_plate: MeshInstance3D = MeshInstance3D.new()
	var accent_mesh: BoxMesh = BoxMesh.new()
	accent_mesh.size = Vector3(GRID_SIZE - PLATFORM_MARGIN - 10.0, 0.24, GRID_SIZE - PLATFORM_MARGIN - 10.0)
	accent_plate.mesh = accent_mesh
	accent_plate.position = Vector3(0, PLATFORM_THICKNESS * 0.34, 0)
	var accent_material: StandardMaterial3D = StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.98, 0.92, 0.82, 0.94)
	accent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	accent_material.emission_enabled = true
	accent_material.emission = color * 0.60
	accent_material.emission_energy_multiplier = 1.08
	accent_material.roughness = 0.18
	accent_plate.material_override = accent_material
	platform.add_child(accent_plate)

	var label_3d = Label3D.new()
	label_3d.text = "↔"
	label_3d.font_size = 20
	label_3d.modulate = Color(0.98, 0.95, 0.88, 0.90)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = Vector3(0, 5.8, 0)
	platform.add_child(label_3d)

	add_child(platform)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(platform, "position", end_pos, speed)
	tween.tween_property(platform, "position", start_pos, speed)
	platform_tweens.append(tween)

func _clear_guide_barriers():
	for barrier_node in guide_barrier_nodes:
		if barrier_node != null and is_instance_valid(barrier_node):
			barrier_node.queue_free()
	guide_barrier_nodes.clear()

func _create_platform_guide_barriers(platform_name: String, start_pos: Vector3, end_pos: Vector3, color: Color):
	var path_vector: Vector3 = end_pos - start_pos
	var flat_path: Vector3 = Vector3(path_vector.x, 0.0, path_vector.z)
	var path_length: float = flat_path.length()
	if path_length < 0.01:
		return

	var direction: Vector3 = flat_path.normalized()
	var perpendicular: Vector3 = Vector3(-direction.z, 0.0, direction.x) * GUIDE_BARRIER_OFFSET
	var dash_step: float = GUIDE_DASH_LENGTH + GUIDE_DASH_GAP
	var dash_count: int = maxi(1, int(ceil(path_length / dash_step)))
	var barrier_center_y: float = start_pos.y + GUIDE_BARRIER_HEIGHT * 0.5

	for dash_index in range(dash_count):
		var distance_along_path: float = minf(float(dash_index) * dash_step + GUIDE_DASH_LENGTH * 0.5, path_length)
		var base_position: Vector3 = start_pos + direction * distance_along_path
		base_position.y = barrier_center_y
		_create_barrier_dash("%s_Left_%d" % [platform_name, dash_index], base_position + perpendicular, direction, color)
		_create_barrier_dash("%s_Right_%d" % [platform_name, dash_index], base_position - perpendicular, direction, color)

func _create_barrier_dash(name: String, position: Vector3, direction: Vector3, color: Color):
	var barrier: StaticBody3D = StaticBody3D.new()
	barrier.name = name
	barrier.collision_layer = 2
	barrier.collision_mask = 0
	barrier.add_to_group("crash_hazard")
	barrier.set_meta("hazard_kind", "guide_barrier")

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(GUIDE_DASH_LENGTH, GUIDE_BARRIER_HEIGHT, GUIDE_BARRIER_THICKNESS)
	collision_shape.shape = box_shape
	barrier.add_child(collision_shape)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_shape.size
	mesh_instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.24)
	material.emission_enabled = true
	material.emission = color * 0.16
	material.roughness = 0.92
	mesh_instance.material_override = material
	barrier.add_child(mesh_instance)

	barrier.position = position
	barrier.rotation.y = atan2(direction.x, direction.z)
	add_child(barrier)
	guide_barrier_nodes.append(barrier)

func create_moving_obstacles():
	for i in range(moving_obstacles_data.size()):
		var data: Dictionary = moving_obstacles_data[i]
		create_moving_obstacle(
			"Gate_%d" % i,
			grid_to_world(data["from"].x, data["from"].y, data["height"]),
			grid_to_world(data["to"].x, data["to"].y, data["height"]),
			data["speed"],
			data["size"],
			data["color"]
		)

func create_moving_obstacle(name: String, start_pos: Vector3, end_pos: Vector3, speed: float, size: Vector3, color: Color):
	var obstacle: StaticBody3D = StaticBody3D.new()
	obstacle.name = name
	obstacle.collision_layer = 2
	obstacle.collision_mask = 0
	obstacle.add_to_group("crash_hazard")
	obstacle.set_meta("hazard_kind", "moving_obstacle")

	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	obstacle.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.02)
	material.emission_enabled = true
	material.emission = color * 0.78
	material.emission_energy_multiplier = 1.02
	material.roughness = 0.48
	material.metallic = 0.10
	mesh_instance.material_override = material

	obstacle.add_child(mesh_instance)
	obstacle.position = start_pos
	add_child(obstacle)

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(obstacle, "position", end_pos, speed)
	tween.tween_property(obstacle, "position", start_pos, speed)
	platform_tweens.append(tween)

func create_static_obstacles():
	for i in range(static_obstacles_data.size()):
		var data: Dictionary = static_obstacles_data[i]
		var obstacle: StaticBody3D = StaticBody3D.new()
		obstacle.name = "Obstacle_%d" % i
		obstacle.collision_layer = 2
		obstacle.collision_mask = 0
		obstacle.add_to_group("crash_hazard")
		obstacle.set_meta("hazard_kind", "static_obstacle")

		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = data["size"]
		collision.shape = box_shape
		obstacle.add_child(collision)

		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = data["size"]
		mesh_instance.mesh = box_mesh

		var material: StandardMaterial3D = StandardMaterial3D.new()
		var obstacle_color: Color = data.get("color", Color(0.40, 0.28, 0.19))
		material.albedo_color = obstacle_color.darkened(0.02)
		material.emission_enabled = true
		material.emission = obstacle_color * 0.30
		material.emission_energy_multiplier = 0.92
		material.roughness = 0.72
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

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.90, 0.62)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.88, 0.60) * 0.42
	material.emission_energy_multiplier = 0.58
	mesh_instance.material_override = material

	target_point.add_child(mesh_instance)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	var beacon_mesh: CylinderMesh = CylinderMesh.new()
	beacon_mesh.top_radius = 3.4
	beacon_mesh.bottom_radius = 3.4
	beacon_mesh.height = 22.0
	beacon.mesh = beacon_mesh
	beacon.position = Vector3(0.0, 11.0, 0.0)
	var beacon_material: StandardMaterial3D = StandardMaterial3D.new()
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_material.albedo_color = Color(1.0, 0.90, 0.60, 0.18)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(1.0, 0.90, 0.62) * 0.46
	beacon_material.emission_energy_multiplier = 0.64
	beacon.material_override = beacon_material
	target_point.add_child(beacon)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 9.8
	ring_mesh.bottom_radius = 9.8
	ring_mesh.height = 0.26
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, -3.8, 0.0)
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(1.0, 0.92, 0.64, 0.34)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.90, 0.62) * 0.38
	ring_material.emission_energy_multiplier = 0.52
	ring.material_override = ring_material
	target_point.add_child(ring)
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

	var drone: CharacterBody3D = null
	for _i in range(180):
		drone = drone_scene.get_drone()
		if drone != null and is_instance_valid(drone):
			break
		await get_tree().process_frame

	if drone == null:
		print("❌ Дрон не найден в DroneScene")
		return

	print("✅ Дрон найден: ", drone.name)
	drone.global_position = grid_to_world(start_grid.x, start_grid.y, start_height)
	drone.collision_layer = 1
	drone.collision_mask = 3
	if drone.has_method("set_floor_height"):
		drone.call("set_floor_height", MIN_SAFE_HEIGHT)
	if target_point != null and drone.has_method("set_target_position"):
		drone.call("set_target_position", target_point.global_position)
	if drone.has_method("set_boundaries"):
		drone.call("set_boundaries", drone_scene.grid_boundary_min, drone_scene.grid_boundary_max)

	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)
		print("✅ Сигнал program_finished подключен")

func _on_drone_program_finished(success: bool):
	if not success or is_level_completed:
		return

	var current_drone_scene: Node = $DroneScene
	var current_drone: CharacterBody3D = current_drone_scene.get_drone() if current_drone_scene != null and current_drone_scene.has_method("get_drone") else null
	var target_reached_now: bool = false
	if current_drone != null and current_drone.has_method("get_has_reached_target"):
		target_reached_now = bool(current_drone.call("get_has_reached_target"))

	if target_reached_now:
		complete_level()

func _exit_tree():
	for tween in platform_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	platform_tweens.clear()
	_clear_guide_barriers()

func complete_level():
	if is_level_completed:
		return

	is_level_completed = true
	print("🎉 УРОВЕНЬ %d ЗАВЕРШЕН!" % level_number)

	for tween in platform_tweens:
		tween.kill()

	var current_drone_scene = $DroneScene
	var current_drone: CharacterBody3D = current_drone_scene.get_drone() if current_drone_scene != null and current_drone_scene.has_method("get_drone") else null
	if current_drone != null and current_drone.has_method("set_target_reached"):
		current_drone.call("set_target_reached", true)
	if current_drone_scene and current_drone_scene.has_method("_on_program_finished"):
		current_drone_scene._on_program_finished(true)

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15

	var panel = Panel.new()
	panel.size = Vector2(560, 240)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.06, 0.86)
	style.border_color = Color(0.88, 0.70, 0.44)
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
	label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))
	label.size = panel.size

	panel.add_child(label)
	success_ui.add_child(panel)
	add_child(success_ui)

	await get_tree().create_timer(4.0).timeout
	return_to_selection()

func _input(event):
	if is_intro_visible:
		if event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return
		if intro_accepts_input and _is_intro_continue_event(event):
			_close_intro_overlay()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_selection()

func _is_intro_continue_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false

func return_to_selection():
	print("🔄 Возвращаемся к выбору уровней...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://app/ui/game_level.tscn")
