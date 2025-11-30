extends Node3D

const GRID_SIZE = 32

@onready var drone_scene = $DroneScene
var target_points = []
var collected_targets = 0
var total_targets = 2
var is_level_completed = false

func _ready():
	print("🎮 УРОВЕНЬ 4 ЗАГРУЖЕН")
	print("Собери 2 шарика на разных высотах!")
	
	await get_tree().process_frame
	setup_level()

func setup_level():
	create_target_points()
	await setup_drone()
	print("✅ Уровень 4 настроен")

func grid_to_world(grid_x: int, grid_z: int, y_height: float = 0) -> Vector3:
	var world_x = grid_x * GRID_SIZE + GRID_SIZE / 2
	var world_z = grid_z * GRID_SIZE + GRID_SIZE / 2
	return Vector3(world_x, y_height, world_z)

func create_target_points():
	# Первый шарик - на 1 блок выше начальной высоты
	create_target_point(1, 1, 32, Color.GREEN)  # x:1, z:1, высота: +1 блок
	
	# Второй шарик - на 2 блока выше начальной высоты
	create_target_point(3, -1, 64, Color.GREEN)  # x:3, z:-1, высота: +2 блока

func create_target_point(grid_x: int, grid_z: int, height: float, color: Color):
	var target_point = Area3D.new()
	target_point.name = "TargetPoint_%d_%d" % [grid_x, grid_z]
	
	# Коллизия
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 8.0
	collision.shape = sphere_shape
	target_point.add_child(collision)
	
	# Визуал
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	mesh_instance.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.3
	mesh_instance.material_override = material
	
	target_point.add_child(mesh_instance)
	
	# Позиция
	target_point.position = grid_to_world(grid_x, grid_z, height)
	
	# Настройки коллизий
	target_point.collision_layer = 2
	target_point.collision_mask = 1
	
	# Сигнал
	target_point.body_entered.connect(_on_target_body_entered.bind(target_point))
	
	add_child(target_point)
	target_points.append(target_point)
	print("✅ Целевая точка создана: %s (высота: %d)" % [target_point.position, height])


func _on_target_body_entered(body: Node, target_point: Area3D):
	if is_level_completed:
		return
	
	print("🎯 Обнаружено столкновение с шариком!")
	
	if body is CharacterBody3D and ("Drone" in body.name or "DefaultDrone" in body.name):
		# Помечаем шарик как собранный
		target_point.queue_free()
		collected_targets += 1
		
		print("✅ Собран шарик %d/%d" % [collected_targets, total_targets])
		
		# Воспроизводим звуковой эффект
		play_collection_sound()
		
		# Создаем эффект частиц
		create_collection_effect(target_point.position)
		
		if collected_targets >= total_targets:
			print("🎉 Все шарики собраны!")
			complete_level()

func play_collection_sound():
	# Здесь можно добавить звуковой эффект
	print("🔊 Звук сбора шарика")

func create_collection_effect(position: Vector3):
	# Создаем простой визуальный эффект
	var particles = GPUParticles3D.new()
	var particle_material = StandardMaterial3D.new()
	particle_material.albedo_color = Color(1, 0.8, 0)
	particle_material.emission_enabled = true
	
	particles.position = position
	particles.explosiveness = 0.8
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 1.0
	
	add_child(particles)
	particles.emitting = true
	
	# Автоматически удаляем через 2 секунды
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

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
	print("🚁 Начальная позиция дрона: ", drone.global_position)
	
	# Настраиваем маски коллизий
	drone.collision_layer = 1
	drone.collision_mask = 2
	
	# Подключаем сигнал завершения программы
	if drone.has_signal("program_finished"):
		drone.program_finished.connect(_on_drone_program_finished)
		print("✅ Сигнал program_finished подключен")
	else:
		print("❌ Сигнал program_finished не найден")

func _on_drone_program_finished(success: bool):
	print("🎯 Программа дрона завершена, собрано шариков: %d/%d" % [collected_targets, total_targets])
	
	if collected_targets >= total_targets:
		complete_level()
	else:
		print("❌ Не все шарики собраны!")

func complete_level():
	if is_level_completed:
		return
	
	is_level_completed = true
	print("🎉 УРОВЕНЬ 4 ЗАВЕРШЕН!")
	
	# Оповещаем дрон об успешном завершении
	var drone_scene = $DroneScene
	if drone_scene and drone_scene.has_method("_on_program_finished"):
		drone_scene._on_program_finished(true)
	
	# УДАЛЕНО: Global.complete_level(4, 10, 5) - теперь это делается автоматически в DroneScene
	print("✅ Прогресс будет сохранен автоматически")
	
	show_success_message()

func show_success_message():
	var success_ui = CanvasLayer.new()
	success_ui.layer = 15
	
	var panel = Panel.new()
	panel.size = Vector2(400, 200)
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color.GOLD
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "УРОВЕНЬ 4 ПРОЙДЕН!\n\nСобраны все шарики!\nАвтоматический возврат через 3 секунды..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.GOLD)
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
	get_tree().change_scene_to_file("res://UI/game_level.tscn")
