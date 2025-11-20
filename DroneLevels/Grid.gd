# Grid.gd
extends Node3D

const GRID_SIZE = 32
const GRID_CELLS_COUNT = 32  # 1024 / 32 = 32 клетки

func _ready():
	create_elegant_grid()

func create_elegant_grid():
	# Очищаем старую сетку
	for child in get_children():
		child.queue_free()
	
	var total_size = GRID_CELLS_COUNT * GRID_SIZE
	var half_size = total_size / 2
	
	# Создаем объемные линии сетки
	create_volumetric_grid_lines(total_size, half_size)
	
	# Добавляем маркеры
	create_grid_markers(half_size)

func create_volumetric_grid_lines(total_size: float, half_size: float):
	# Материал для обычных линий
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
	line_material.emission_enabled = true
	line_material.emission = Color(0.1, 0.1, 0.1, 0.3)
	
	# Материал для основных линий (каждые 4 клетки)
	var major_line_material = StandardMaterial3D.new()
	major_line_material.albedo_color = Color(0.4, 0.4, 0.4, 0.9)
	major_line_material.emission_enabled = true
	major_line_material.emission = Color(0.2, 0.2, 0.2, 0.4)
	
	# Материал для центральных осей
	var axis_material = StandardMaterial3D.new()
	axis_material.albedo_color = Color(0.8, 0.2, 0.2, 0.8)
	axis_material.emission_enabled = true
	axis_material.emission = Color(0.4, 0.1, 0.1, 0.5)
	
	# Создаем линии сетки
	for i in range(-GRID_CELLS_COUNT/2, GRID_CELLS_COUNT/2 + 1):
		var is_major_line = (i % 4 == 0) and (i != 0)  # Основные линии каждые 4 клетки, кроме центра
		var is_axis = (i == 0)  # Центральные оси
		
		var material = line_material
		var thickness = 0.25
		var height = 0.15
		
		if is_axis:
			material = axis_material
			thickness = 0.4
			height = 0.2
		elif is_major_line:
			material = major_line_material
			thickness = 0.3
			height = 0.18
		
		# Горизонтальные линии (вдоль Z)
		create_thick_line(
			Vector3(i * GRID_SIZE, height, -half_size),
			Vector3(i * GRID_SIZE, height, half_size),
			material,
			thickness
		)
		
		# Вертикальные линии (вдоль X)
		create_thick_line(
			Vector3(-half_size, height, i * GRID_SIZE),
			Vector3(half_size, height, i * GRID_SIZE),
			material,
			thickness
		)

func create_thick_line(from: Vector3, to: Vector3, material: Material, thickness: float):
	var mesh_instance = MeshInstance3D.new()
	
	# Создаем толстую линию как прямоугольник
	var distance = from.distance_to(to)
	var direction = (to - from).normalized()
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(thickness, thickness, distance)
	
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	
	# Позиционируем и поворачиваем
	var center = (from + to) / 2
	mesh_instance.position = center
	
	# Поворачиваем в нужном направлении
	if abs(direction.x) > 0.5:  # Горизонтальная линия
		mesh_instance.rotation_degrees = Vector3(0, 0, 90)
	else:  # Вертикальная линия
		mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	
	add_child(mesh_instance)

func create_grid_markers(half_size: float):
	# Угловые маркеры
	var corner_material = StandardMaterial3D.new()
	corner_material.albedo_color = Color(0.9, 0.7, 0.1)
	corner_material.emission_enabled = true
	corner_material.emission = Color(0.9, 0.7, 0.1, 0.4)
	
	var corners = [
		Vector3(-half_size, 0.25, -half_size),
		Vector3(half_size, 0.25, -half_size),
		Vector3(-half_size, 0.25, half_size),
		Vector3(half_size, 0.25, half_size)
	]
	
	for corner in corners:
		var marker = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 2.0
		cylinder.bottom_radius = 2.0
		cylinder.height = 0.5
		marker.mesh = cylinder
		marker.material_override = corner_material
		marker.position = corner
		add_child(marker)
	
	# Центральный маркер
	var center_material = StandardMaterial3D.new()
	center_material.albedo_color = Color(0.1, 0.8, 0.2)
	center_material.emission_enabled = true
	center_material.emission = Color(0.1, 0.8, 0.2, 0.3)
	
	var center_marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 2.5
	sphere.height = 5.0
	center_marker.mesh = sphere
	center_marker.material_override = center_material
	center_marker.position = Vector3(0, 0.25, 0)
	add_child(center_marker)
