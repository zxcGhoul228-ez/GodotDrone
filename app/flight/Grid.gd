extends Node3D

const GRID_SIZE = 32
const GRID_CELLS_COUNT = 32
const LINE_WIDTH = 0.05  # Толщина линий в мировых единицах

# Цвета сетки
const GRID_COLOR = Color(0.3, 0.3, 0.3, 0.3)  # Основные линии
const MAJOR_GRID_COLOR = Color(0.5, 0.5, 0.5, 0.5)  # Каждые 4 клетки
const AXIS_COLOR = Color(0.8, 0.2, 0.2, 0.6)  # Центральные оси
const CENTER_COLOR = Color(0.9, 0.9, 0.1, 0.8)  # Центр

@onready var camera = get_viewport().get_camera_3d()

func _ready():
	create_crisp_grid()
	set_process(true)

func _process(delta):
	# Обновляем сетку для следования за камерой (опционально)
	update_grid_for_camera()

func create_crisp_grid():
	# Очищаем старую сетку
	for child in get_children():
		child.queue_free()
	
	var total_size = GRID_CELLS_COUNT * GRID_SIZE
	var half_size = total_size / 2
	
	# 1. Создаем фон сетки (одна плоскость)
	create_grid_background(total_size)
	
	# 2. Создаем все линии в одном ImmediateMesh для производительности
	create_all_grid_lines(total_size, half_size)
	
	# 3. Создаем центральные оси отдельно (они должны быть сверху)
	create_center_axes(half_size)
	
	# 4. Создаем маркеры углов и центра
	create_grid_markers(half_size)

func create_grid_background(total_size: float):
	# Создаем полупрозрачную плоскость под сеткой
	var background = MeshInstance3D.new()
	background.name = "GridBackground"
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(total_size, total_size)
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.05, 0.08, 0.1)  # Очень темный, едва заметный
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	plane_mesh.material = material
	background.mesh = plane_mesh
	background.position = Vector3(0, 0.001, 0)  # Чуть выше пола
	background.rotation_degrees = Vector3(-90, 0, 0)  # Горизонтально
	
	add_child(background)

func create_all_grid_lines(total_size: float, half_size: float):
	# Создаем ВСЕ линии сетки в одном меше для производительности
	var grid_mesh = MeshInstance3D.new()
	grid_mesh.name = "GridLines"
	
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	# НАСТРОЙКИ МАТЕРИАЛА ДЛЯ ЧЕТКИХ ЛИНИЙ:
	material.albedo_color = GRID_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.flags_unshaded = true  # Без освещения
	material.vertex_color_use_as_albedo = true  # Используем цвета вершин
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.render_priority = 10  # Рисуем позже
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	
	# Рисуем ВСЕ линии сетки за один вызов
	for i in range(-GRID_CELLS_COUNT/2, GRID_CELLS_COUNT/2 + 1):
		var is_major = (i % 4 == 0) and (i != 0)
		var is_center = (i == 0)
		
		# Выбираем цвет в зависимости от типа линии
		var line_color = GRID_COLOR
		var line_height = 0.02
		
		if is_major:
			line_color = MAJOR_GRID_COLOR
			line_height = 0.025
		elif is_center:
			continue  # Центральные оси сделаем отдельно
		
		# Вертикальные линии (вдоль Z)
		immediate_mesh.surface_set_color(line_color)
		immediate_mesh.surface_add_vertex(Vector3(i * GRID_SIZE, line_height, -half_size))
		immediate_mesh.surface_add_vertex(Vector3(i * GRID_SIZE, line_height, half_size))
		
		# Горизонтальные линии (вдоль X)
		immediate_mesh.surface_set_color(line_color)
		immediate_mesh.surface_add_vertex(Vector3(-half_size, line_height, i * GRID_SIZE))
		immediate_mesh.surface_add_vertex(Vector3(half_size, line_height, i * GRID_SIZE))
	
	immediate_mesh.surface_end()
	
	grid_mesh.mesh = immediate_mesh
	grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(grid_mesh)

func create_center_axes(half_size: float):
	# Создаем центральные оси отдельным мешем (они поверх других линий)
	var axes_mesh = MeshInstance3D.new()
	axes_mesh.name = "CenterAxes"
	
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	# Материал для осей (яркий, с небольшим свечением)
	material.albedo_color = AXIS_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.8, 0.2, 0.2, 0.3)
	material.emission_energy = 0.5
	material.flags_unshaded = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.render_priority = 11  # Рисуем поверх сетки
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	
	# Ось X (красная)
	immediate_mesh.surface_set_color(Color(1.0, 0.3, 0.3, 0.8))
	immediate_mesh.surface_add_vertex(Vector3(-half_size, 0.03, 0))
	immediate_mesh.surface_add_vertex(Vector3(half_size, 0.03, 0))
	
	# Ось Z (синяя)
	immediate_mesh.surface_set_color(Color(0.3, 0.3, 1.0, 0.8))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.03, -half_size))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.03, half_size))
	
	immediate_mesh.surface_end()
	
	axes_mesh.mesh = immediate_mesh
	axes_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	add_child(axes_mesh)

func create_grid_markers(half_size: float):
	# Угловые маркеры (просто точки)
	var corner_material = StandardMaterial3D.new()
	corner_material.albedo_color = Color(0.5, 0.5, 0.5, 0.4)
	corner_material.emission_enabled = true
	corner_material.emission = Color(0.5, 0.5, 0.5, 0.2)
	corner_material.flags_unshaded = true
	
	var corners = [
		Vector3(-half_size, 0.04, -half_size),
		Vector3(half_size, 0.04, -half_size),
		Vector3(-half_size, 0.04, half_size),
		Vector3(half_size, 0.04, half_size)
	]
	
	for corner in corners:
		var marker = create_simple_sphere(corner, 0.5, corner_material)
		add_child(marker)
	
	# Центральный маркер
	var center_material = StandardMaterial3D.new()
	center_material.albedo_color = CENTER_COLOR
	center_material.emission_enabled = true
	center_material.emission = Color(0.9, 0.9, 0.1, 0.4)
	center_material.emission_energy = 1.0
	center_material.flags_unshaded = true
	
	var center_marker = create_simple_sphere(Vector3(0, 0.04, 0), 1.0, center_material)
	add_child(center_marker)

func create_simple_sphere(position: Vector3, radius: float, material: StandardMaterial3D) -> MeshInstance3D:
	var marker = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	marker.mesh = sphere
	marker.material_override = material
	marker.position = position
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return marker

func update_grid_for_camera():
	# Эта функция может обновлять видимость или качество сетки в зависимости от расстояния камеры
	if not camera:
		return
	
	var distance_to_grid = camera.global_position.distance_to(Vector3(0, 0, 0))
	
	# Можно динамически менять видимость или качество сетки
	# Например, скрывать вспомогательные линии при удалении
	pass
