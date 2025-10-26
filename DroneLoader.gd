# DroneLoader.gd
extends Node

func load_drone() -> Node3D:
	var file = FileAccess.open("user://saved_drone.json", FileAccess.READ)
	if not file:
		print("❌ Файл saved_drone.json не найден")
		return create_default_drone()
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("❌ Ошибка парсинга JSON: ", json.get_error_message())
		return create_default_drone()
	
	var drone_data = json.data
	return create_drone_from_data(drone_data)

func create_drone_from_data(data: Dictionary) -> Node3D:
	var drone = CharacterBody3D.new()
	drone.name = "Drone"
	
	# Создаем пропорциональный дрон
	create_proportional_drone_visual(drone)
	
	# Коллизия для дрона
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8, 1.5, 8)
	collision.shape = shape
	drone.add_child(collision)
	
	# Скрипт
	drone.script = load("res://Drone.gd")
	
	return drone

func create_proportional_drone_visual(drone: Node3D):
	# 1. РАМА
	var frame = MeshInstance3D.new()
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(8, 0.4, 8)
	frame.mesh = frame_mesh
	
	var frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.2, 0.8, 0.2)
	frame.material_override = frame_material
	drone.add_child(frame)
	
	# 2. ПЛАТА
	var board = MeshInstance3D.new()
	var board_mesh = BoxMesh.new()
	board_mesh.size = Vector3(3, 0.2, 3)
	board.mesh = board_mesh
	
	var board_material = StandardMaterial3D.new()
	board_material.albedo_color = Color(0.8, 0.8, 0.2)
	board.material_override = board_material
	board.position = Vector3(0, 0.3, 0)
	drone.add_child(board)
	
	# 3. МОТОРЫ (4 штуки)
	var motor_positions = [
		Vector3(3, 0.2, 3),
		Vector3(-3, 0.2, 3),
		Vector3(3, 0.2, -3),
		Vector3(-3, 0.2, -3)
	]
	
	for i in range(4):
		var motor = MeshInstance3D.new()
		var motor_mesh = CylinderMesh.new()
		motor_mesh.top_radius = 0.5
		motor_mesh.bottom_radius = 0.5
		motor_mesh.height = 0.8
		motor.mesh = motor_mesh
		
		var motor_material = StandardMaterial3D.new()
		motor_material.albedo_color = Color(0.3, 0.3, 0.3)
		motor.material_override = motor_material
		motor.position = motor_positions[i]
		drone.add_child(motor)
	
	# 4. ПРОПЕЛЛЕРЫ (4 штуки)
	var propeller_positions = [
		Vector3(3, 0.6, 3),
		Vector3(-3, 0.6, 3),
		Vector3(3, 0.6, -3),
		Vector3(-3, 0.6, -3)
	]
	
	for i in range(4):
		var propeller = MeshInstance3D.new()
		var propeller_mesh = BoxMesh.new()
		propeller_mesh.size = Vector3(2.5, 0.1, 2.5)
		propeller.mesh = propeller_mesh
		
		var propeller_material = StandardMaterial3D.new()
		propeller_material.albedo_color = Color(0.8, 0.8, 0.8)
		propeller.material_override = propeller_material
		propeller.position = propeller_positions[i]
		drone.add_child(propeller)

func create_default_drone() -> Node3D:
	var drone = CharacterBody3D.new()
	drone.name = "Drone"
	
	create_proportional_drone_visual(drone)
	
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(8, 1.5, 8)
	collision.shape = shape
	drone.add_child(collision)
	
	drone.position = Vector3(0, 32, 0)
	drone.script = load("res://Drone.gd")
	
	return drone
