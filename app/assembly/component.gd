extends Node3D

const StlRuntimeLoader = preload("res://app/assembly/stl_runtime_loader.gd")

@export var component_name: String = ""
@export var component_type: String = ""  # "frame", "board", "motor", "propeller"
@export var component_variant: int = 1  # 1, 2 или 3
@export var drone_platform_type: String = DronePlatformConfig.PLATFORM_QUAD
@export var can_attach_to: PackedStringArray = []

# ФИЗИЧЕСКИЕ СВОЙСТВА
@export var component_mass: float = 0.0  # Масса компонента в кг
@export var component_thrust: float = 0.0  # Тяга (только для моторов и пропеллеров)
@export var component_size: Vector3 = Vector3(1, 1, 1)  # Габариты
@export var component_strength: float = 1.0  # Прочность (0-1)

var is_attached: bool = false
var attached_position: Vector3 = Vector3.ZERO
var is_active: bool = true  # Активен ли компонент

func _ready():
	# Инициализируем физические свойства в зависимости от типа
	match component_type:
		"frame":
			component_mass = get_frame_mass(component_variant)
			component_name = DronePlatformConfig.get_default_frame_type(drone_platform_type) if drone_platform_type != DronePlatformConfig.PLATFORM_QUAD else "Рама%d" % component_variant
			can_attach_to = ["board", "motor"]
		"board":
			component_mass = get_board_mass(component_variant)
			component_name = "Плата%d" % component_variant
			can_attach_to = []
		"motor":
			component_mass = get_motor_mass(component_variant)
			component_thrust = get_motor_thrust(component_variant)
			component_name = "Мотор%d" % component_variant
			can_attach_to = ["propeller"]
		"propeller":
			component_mass = get_propeller_mass(component_variant)
			component_thrust = get_propeller_thrust(component_variant)
			component_name = "Пропеллер%d" % component_variant
			can_attach_to = []
	
	setup_component()
	
	# ДОБАВЛЯЕМ МАРКИРОВКУ ДЛЯ ПРОПЕЛЛЕРОВ
	if component_type == "propeller":
		mark_as_propeller()
		
func get_frame_mass(variant: int) -> float:
	match variant:
		1: return 1.0  # Легкая
		2: return 1.5  # Средняя
		3: return 2.0  # Тяжелая
		_: return 1.0

func get_board_mass(variant: int) -> float:
	match variant:
		1: return 0.3
		2: return 0.35
		3: return 0.4
		_: return 0.3

func get_motor_mass(variant: int) -> float:
	match variant:
		1: return 0.2  # Легкий
		2: return 0.3  # Средний
		3: return 0.4  # Мощный
		_: return 0.3

func get_motor_thrust(variant: int) -> float:
	match variant:
		1: return 8.0  # Слабая тяга
		2: return 12.0 # Средняя тяга
		3: return 16.0 # Сильная тяга
		_: return 12.0

func get_propeller_thrust(variant: int) -> float:
	match variant:
		1: return 1.0   # Базовый
		2: return 1.15  # Усиленный
		3: return 1.3   # Максимальный
		_: return 1.2

func get_propeller_mass(variant: int) -> float:
	match variant:
		1: return 0.1
		2: return 0.14
		3: return 0.18
		_: return 0.1

func mark_as_propeller():
	set_meta("is_drone_propeller", true)
	add_to_group("drone_propellers", true)
	
	for child in get_children():
		if child is MeshInstance3D or child is Node3D:
			child.set_meta("is_drone_propeller", true)
			child.add_to_group("drone_propellers", true)

func _should_preserve_child_on_setup(child: Node) -> bool:
	if child == null:
		return false

	if child.has_meta("is_drone_propeller") and bool(child.get_meta("is_drone_propeller")):
		return true

	if child.has_method("get_component_type"):
		var child_type_variant: Variant = child.call("get_component_type")
		if typeof(child_type_variant) == TYPE_STRING and String(child_type_variant) == "propeller":
			return true

	var child_name := str(child.name).to_lower()
	return child_name.find("propeller") != -1

func get_component_type() -> String:
	return component_type

func get_drone_platform_type() -> String:
	return DronePlatformConfig.normalize_platform_type(drone_platform_type)

func get_component_mass() -> float:
	return component_mass

func get_component_thrust() -> float:
	return component_thrust

func set_active(active: bool):
	is_active = active
	# Можно добавить визуальные эффекты для неактивных компонентов

func is_functional() -> bool:
	return is_active and is_attached


func setup_component():
	print("DEBUG: Setting up component: ", component_type, " variant: ", component_variant)
	
	# Очищаем всех детей
	for child in get_children():
		if _should_preserve_child_on_setup(child):
			continue
		child.queue_free()
	
	match component_type:
		"frame":
			component_name = "Рама дрона"
			can_attach_to = ["board", "motor"]
			create_frame()
		"board":
			component_name = "Плата управления"
			can_attach_to = []
			create_board()
		"motor":
			component_name = "Двигатель"
			can_attach_to = ["propeller"]
			create_motor()
		"propeller":
			component_name = "Пропеллер"
			can_attach_to = []
			create_propeller()

# УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ ЗАГРУЗКИ МОДЕЛЕЙ
func _load_obj_mesh(mesh_path: String, scale_value: Vector3) -> Node3D:
	if mesh_path.is_empty() or not ResourceLoader.exists(mesh_path):
		return null
	var mesh = load(mesh_path)
	if mesh == null:
		return null
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.scale = scale_value
	return mesh_instance

func load_model(base_name: String, default_scale: Vector3 = Vector3(0.1, 0.1, 0.1)) -> Node3D:
	if component_type == "frame":
		var frame_visual: Dictionary = DronePlatformConfig.get_frame_visual_settings(drone_platform_type, component_variant)
		var frame_model: Node3D = _load_obj_mesh(str(frame_visual.get("path", "")), frame_visual.get("scale", default_scale))
		if frame_model != null:
			return frame_model

	var variant_str = str(component_variant)
	if component_type == "board" and component_variant in [2, 3]:
		var custom_board: Node3D = _build_custom_board_model(component_variant)
		if custom_board != null:
			return custom_board
	
	# Сначала пробуем .glb (только для платы)
	if component_type == "board":
		var glb_path = "res://app/assembly/models/" + base_name + variant_str + ".glb"
		print("DEBUG: Trying to load GLB: ", glb_path)
		
		if ResourceLoader.exists(glb_path):
			print("DEBUG: GLB file exists")
			var scene = load(glb_path)
			if scene and scene is PackedScene:
				print("DEBUG: GLB scene loaded successfully")
				var instance = scene.instantiate()
				
				# ИНДИВИДУАЛЬНЫЕ НАСТРОЙКИ ДЛЯ КАЖДОЙ ПЛАТЫ
				match component_variant:
					1:  # board1.tscn
						# Масштаб и поворот для board1
						instance.scale = Vector3(0.1, 0.1, 0.1)  # Уменьшить в 5 раз от 0.1
						instance.rotation_degrees = Vector3(0, 0, 0)  # Поворот для board1
						print("DEBUG: Applied settings for board1: scale=0.02, rotation=(0,0,0)")
					2:  # board2.tscn
						# Масштаб и поворот для board2
						instance.scale = Vector3(1, 1, 1)  # Увеличить
						instance.rotation_degrees = Vector3(-90, 0, 0)  # Поворот на 90 градусов по X
						print("DEBUG: Applied settings for board2: scale=2.5, rotation=(90,0,0)")
					3:  # board3.tscn
						# Масштаб и поворот для board3 (настройте по необходимости)
						instance.scale = Vector3(1.0, 1.0, 1.0)  # Нейтральный масштаб
						instance.rotation_degrees = Vector3(0, 0, 0)  # Без поворота
						print("DEBUG: Applied settings for board3: scale=1.0, rotation=(0,0,0)")
					_:  # По умолчанию
						instance.scale = Vector3(1.0, 1.0, 1.0)
						instance.rotation_degrees = Vector3(0, 0, 0)
				
				return instance
		
		# Если .glb не найден, пробуем .gltf
		var gltf_path = "res://app/assembly/models/" + base_name + variant_str + ".gltf"
		print("DEBUG: Trying to load GLTF: ", gltf_path)
		
		if ResourceLoader.exists(gltf_path):
			print("DEBUG: GLTF file exists")
			var scene = load(gltf_path)
			if scene and scene is PackedScene:
				print("DEBUG: GLTF scene loaded successfully")
				var instance = scene.instantiate()
				
				# Применяем те же индивидуальные настройки для .gltf
				match component_variant:
					1:
						instance.scale = Vector3(0.02, 0.02, 0.02)
						instance.rotation_degrees = Vector3(0, 0, 0)
					2:
						instance.scale = Vector3(2.5, 2.5, 2.5)
						instance.rotation_degrees = Vector3(90, 0, 0)
					3:
						instance.scale = Vector3(1.0, 1.0, 1.0)
						instance.rotation_degrees = Vector3(0, 0, 0)
					_:
						instance.scale = Vector3(1.0, 1.0, 1.0)
						instance.rotation_degrees = Vector3(0, 0, 0)
				return instance

	if component_type == "motor":
		var archive_motor: Node3D = _load_archive_motor_model()
		if archive_motor != null:
			return archive_motor

	if component_type == "propeller":
		var archive_propeller: Node3D = _load_archive_propeller_model()
		if archive_propeller != null:
			return archive_propeller
	
	# Для всех типов пробуем .obj (основной формат)
	var obj_path = "res://app/assembly/models/" + base_name + variant_str + ".obj"
	print("DEBUG: Trying to load OBJ: ", obj_path)
	
	if ResourceLoader.exists(obj_path):
		print("DEBUG: OBJ file exists")
		var mesh = load(obj_path)
		if mesh:
			print("DEBUG: OBJ mesh loaded successfully")
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = mesh
			mesh_instance.scale = default_scale
			return mesh_instance
	
	print("DEBUG: No model found for ", base_name, variant_str)
	return null

func _create_box_part(size: Vector3, position_value: Vector3, color: Color, roughness: float = 0.62, metallic: float = 0.08) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	mesh_instance.material_override = material
	return mesh_instance

func _create_cylinder_part(radius: float, height: float, position_value: Vector3, color: Color, roughness: float = 0.44, metallic: float = 0.52) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	mesh_instance.material_override = material
	return mesh_instance

func _create_board_decal(texture_path: String, size_value: Vector2, position_value: Vector3) -> MeshInstance3D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null

	var mesh_instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path)
	material.albedo_color = Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.34
	material.metallic = 0.04
	mesh_instance.material_override = material
	return mesh_instance

func _add_board_mounts(root: Node3D, offsets: Array[Vector3], radius: float, height: float) -> void:
	for offset in offsets:
		root.add_child(_create_cylinder_part(
			radius,
			height,
			offset,
			Color(0.82, 0.84, 0.88),
			0.28,
			0.82
		))

func _build_custom_board_model(variant: int) -> Node3D:
	match variant:
		2:
			return _build_board_variant_two()
		3:
			return _build_board_variant_three()
		_:
			return null

func _build_board_variant_two() -> Node3D:
	var root := Node3D.new()
	root.name = "Board2Visual"
	root.position = Vector3(0.0, 0.06, 0.0)

	root.add_child(_create_box_part(
		Vector3(0.94, 0.035, 0.94),
		Vector3.ZERO,
		Color(0.78, 0.16, 0.12),
		0.68,
		0.04
	))
	root.add_child(_create_box_part(Vector3(0.62, 0.07, 0.08), Vector3(0.0, 0.053, -0.18), Color(0.09, 0.09, 0.11), 0.74, 0.12))
	root.add_child(_create_box_part(Vector3(0.62, 0.07, 0.08), Vector3(0.0, 0.053, 0.20), Color(0.09, 0.09, 0.11), 0.74, 0.12))
	root.add_child(_create_box_part(Vector3(0.18, 0.10, 0.18), Vector3(-0.28, 0.058, 0.30), Color(0.16, 0.16, 0.18), 0.72, 0.14))
	root.add_child(_create_box_part(Vector3(0.16, 0.055, 0.16), Vector3(0.01, 0.050, 0.02), Color(0.15, 0.15, 0.17), 0.64, 0.16))
	root.add_child(_create_box_part(Vector3(0.12, 0.04, 0.06), Vector3(0.19, 0.045, 0.08), Color(0.88, 0.70, 0.24), 0.40, 0.22))
	root.add_child(_create_cylinder_part(0.07, 0.09, Vector3(-0.08, 0.053, 0.31), Color(0.74, 0.76, 0.80), 0.32, 0.72))
	_add_board_mounts(
		root,
		[
			Vector3(-0.40, 0.032, -0.40),
			Vector3(0.40, 0.032, -0.40),
			Vector3(-0.40, 0.032, 0.40),
			Vector3(0.40, 0.032, 0.40)
		],
		0.028,
		0.04
	)

	var decal := _create_board_decal(
		"res://content/shop/board2.png",
		Vector2(0.78, 0.78),
		Vector3(0.0, 0.0205, 0.0)
	)
	if decal != null:
		root.add_child(decal)

	return root

func _build_board_variant_three() -> Node3D:
	var root := Node3D.new()
	root.name = "Board3Visual"
	root.position = Vector3(0.0, 0.06, 0.0)

	root.add_child(_create_box_part(
		Vector3(0.84, 0.035, 1.02),
		Vector3.ZERO,
		Color(0.11, 0.31, 0.63),
		0.66,
		0.06
	))
	root.add_child(_create_box_part(Vector3(0.28, 0.065, 0.42), Vector3(0.0, 0.053, 0.04), Color(0.14, 0.15, 0.18), 0.70, 0.16))
	root.add_child(_create_box_part(Vector3(0.07, 0.08, 0.78), Vector3(-0.33, 0.054, 0.0), Color(0.08, 0.08, 0.10), 0.74, 0.14))
	root.add_child(_create_box_part(Vector3(0.07, 0.08, 0.78), Vector3(0.33, 0.054, 0.0), Color(0.08, 0.08, 0.10), 0.74, 0.14))
	root.add_child(_create_box_part(Vector3(0.18, 0.08, 0.10), Vector3(0.20, 0.058, -0.34), Color(0.72, 0.75, 0.80), 0.30, 0.72))
	root.add_child(_create_box_part(Vector3(0.16, 0.045, 0.12), Vector3(-0.12, 0.045, -0.18), Color(0.78, 0.80, 0.83), 0.36, 0.54))
	root.add_child(_create_box_part(Vector3(0.10, 0.04, 0.10), Vector3(0.14, 0.044, 0.28), Color(0.80, 0.82, 0.86), 0.34, 0.58))
	_add_board_mounts(
		root,
		[
			Vector3(-0.33, 0.032, -0.44),
			Vector3(0.33, 0.032, -0.44),
			Vector3(-0.33, 0.032, 0.44),
			Vector3(0.33, 0.032, 0.44)
		],
		0.026,
		0.04
	)

	var decal := _create_board_decal(
		"res://content/shop/board3.png",
		Vector2(0.68, 0.84),
		Vector3(0.0, 0.0205, 0.0)
	)
	if decal != null:
		root.add_child(decal)

	return root

func _load_archive_motor_model() -> Node3D:
	match component_variant:
		2:
			return StlRuntimeLoader.build_multipart_model(
				[
					{
						"path": "res://app/assembly/models/archive/motor2_base_stator.stl",
						"name": "Motor2Base",
						"color": Color(0.18, 0.18, 0.18),
						"roughness": 0.72,
						"metallic": 0.18
					},
					{
						"path": "res://app/assembly/models/archive/motor2_shell.stl",
						"name": "Motor2Shell",
						"color": Color(0.09, 0.09, 0.09),
						"roughness": 0.78,
						"metallic": 0.22
					},
					{
						"path": "res://app/assembly/models/archive/motor2_top_core.stl",
						"name": "Motor2TopCore",
						"color": Color(0.78, 0.80, 0.84),
						"roughness": 0.36,
						"metallic": 0.88
					},
					{
						"path": "res://app/assembly/models/archive/motor2_bottom_core.stl",
						"name": "Motor2BottomCore",
						"color": Color(0.64, 0.66, 0.72),
						"roughness": 0.42,
						"metallic": 0.70
					}
				],
				Vector3(0.0060, 0.0060, 0.0060),
				Vector3(-90.0, 0.0, 0.0),
				"Motor2Archive"
			)
		3:
			return StlRuntimeLoader.build_multipart_model(
				[
					{
						"path": "res://app/assembly/models/archive/motor3_base.stl",
						"name": "Motor3Base",
						"color": Color(0.19, 0.19, 0.19),
						"roughness": 0.74,
						"metallic": 0.20
					},
					{
						"path": "res://app/assembly/models/archive/motor3_rotor.stl",
						"name": "Motor3Rotor",
						"color": Color(0.08, 0.08, 0.08),
						"roughness": 0.76,
						"metallic": 0.26
					},
					{
						"path": "res://app/assembly/models/archive/motor3_core.stl",
						"name": "Motor3Core",
						"color": Color(0.82, 0.83, 0.87),
						"roughness": 0.34,
						"metallic": 0.90
					},
					{
						"path": "res://app/assembly/models/archive/motor3_screws.stl",
						"name": "Motor3Screws",
						"color": Color(0.34, 0.34, 0.36),
						"roughness": 0.56,
						"metallic": 0.64
					}
				],
				Vector3(0.0064, 0.0064, 0.0064),
				Vector3(-90.0, 0.0, 0.0),
				"Motor3Archive"
			)
		_:
			return null

func _load_archive_propeller_model() -> Node3D:
	match component_variant:
		2:
			return StlRuntimeLoader.build_multipart_model(
				[
					{
						"path": "res://app/assembly/models/archive/propeller2_three_blade.stl",
						"name": "Propeller2ThreeBlade",
						"color": Color(0.92, 0.93, 0.95),
						"roughness": 0.48,
						"metallic": 0.10
					}
				],
				Vector3(0.0105, 0.0105, 0.0105),
				Vector3(-90.0, 0.0, 0.0),
				"Propeller2Archive",
				"origin"
			)
		3:
			return StlRuntimeLoader.build_multipart_model(
				[
					{
						"path": "res://app/assembly/models/archive/propeller3_four_blade.stl",
						"name": "Propeller3FourBlade",
						"color": Color(0.94, 0.95, 0.98),
						"roughness": 0.44,
						"metallic": 0.12
					}
				],
				Vector3(0.0120, 0.0120, 0.0120),
				Vector3(0.0, 0.0, 0.0),
				"Propeller3Archive"
			)
		_:
			return null

func create_frame():
	print("DEBUG: Creating frame...")
	var default_scale: Vector3 = DronePlatformConfig.get_frame_visual_settings(drone_platform_type, component_variant).get("scale", Vector3(0.1, 0.1, 0.1))
	var model = load_model("frame", default_scale)
	if model:
		print("DEBUG: Frame model loaded successfully")
		add_child(model)
		
		# Добавляем материал для рамы
		if model is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.2, 0.2, 0.2)
			model.material_override = material
		else:
			# Если это сцена, ищем MeshInstance3D внутри
			var mesh_instance = find_mesh_instance(model)
			if mesh_instance:
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.2, 0.2, 0.2)
				mesh_instance.material_override = material
		return
	
	print("DEBUG: Using fallback frame")
	# Fallback - простая рама
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 0.1, 2.0)
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	mesh_instance.material_override = material
	add_child(mesh_instance)

func create_board():
	print("DEBUG: Creating board variant ", component_variant, "...")
	var model = load_model("board", Vector3(0.1, 0.1, 0.1))
	if model:
		print("DEBUG: Board model loaded successfully")
		print("DEBUG: Board scale: ", model.scale)
		print("DEBUG: Board rotation: ", model.rotation_degrees)
		add_child(model)
		
		# Проверим размеры и ориентацию модели
		await get_tree().process_frame  # Ждем один кадр для загрузки
		check_model_size_and_orientation(model)
		return
	
	print("DEBUG: Using fallback board")
	# Fallback - простая плата
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.05, 0.8)
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0.5, 0)
	mesh_instance.material_override = material
	add_child(mesh_instance)

# Функция для проверки размеров и ориентации модели
func check_model_size_and_orientation(model_node: Node3D):
	# Ищем все MeshInstance3D в модели
	var mesh_instances = []
	find_all_mesh_instances(model_node, mesh_instances)
	
	print("DEBUG: Found ", mesh_instances.size(), " mesh instances in board model")
	for i in range(mesh_instances.size()):
		var mesh_instance = mesh_instances[i]
		if mesh_instance.mesh:
			var aabb = mesh_instance.get_aabb()
			print("DEBUG: Mesh ", i, " AABB size: ", aabb.size)
			print("DEBUG: Mesh ", i, " AABB min: ", aabb.position, " max: ", aabb.end)

# Рекурсивно ищем все MeshInstance3D
func find_all_mesh_instances(node: Node, result: Array):
	if node is MeshInstance3D:
		result.append(node)
	
	for child in node.get_children():
		find_all_mesh_instances(child, result)

func create_motor():
	print("DEBUG: Creating motor...")
	var model = load_model("motor", Vector3(0.1, 0.1, 0.1))
	if model:
		print("DEBUG: Motor model loaded successfully")
		add_child(model)
		if model.has_meta("runtime_material_ready") and bool(model.get_meta("runtime_material_ready")):
			return
		
		# Добавляем материал для мотора
		if model is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.7, 0.7, 0.7)
			model.material_override = material
		else:
			var mesh_instance = find_mesh_instance(model)
			if mesh_instance:
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.7, 0.7, 0.7)
				mesh_instance.material_override = material
		return
	
	print("DEBUG: Using fallback motor")
	# Fallback - простой двигатель
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.2
	mesh.height = 0.3
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.7)
	mesh_instance.material_override = material
	add_child(mesh_instance)

func create_propeller():
	print("DEBUG: Creating propeller...")
	var model = load_model("propeller", Vector3(0.01, 0.01, 0.01))  # Маленький масштаб для пропеллера
	if model:
		print("DEBUG: Propeller model loaded successfully")
		add_child(model)
		if model.has_meta("runtime_material_ready") and bool(model.get_meta("runtime_material_ready")):
			return
		
		# Добавляем материал для пропеллера
		if model is MeshInstance3D:
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.9, 0.9, 0.9)
			model.material_override = material
		else:
			var mesh_instance = find_mesh_instance(model)
			if mesh_instance:
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(0.9, 0.9, 0.9)
				mesh_instance.material_override = material
		return
	
	print("DEBUG: Using fallback propeller")
	# Fallback - простой пропеллер
	var propeller_node = Node3D.new()
	
	# Центральная втулка
	var hub = MeshInstance3D.new()
	var hub_mesh = CylinderMesh.new()
	hub_mesh.top_radius = 0.1
	hub_mesh.bottom_radius = 0.1
	hub_mesh.height = 0.05
	hub.mesh = hub_mesh
	var hub_material = StandardMaterial3D.new()
	hub_material.albedo_color = Color(0.3, 0.3, 0.3)
	hub.material_override = hub_material
	propeller_node.add_child(hub)
	
	# 2 лопасти
	for i in range(2):
		var blade = MeshInstance3D.new()
		var blade_mesh = BoxMesh.new()
		blade_mesh.size = Vector3(1.5, 0.02, 0.3)
		blade.mesh = blade_mesh
		var blade_material = StandardMaterial3D.new()
		blade_material.albedo_color = Color(0.9, 0.9, 0.9)
		blade.material_override = blade_material
		blade.rotation_degrees.y = i * 180  # Противоположные лопасти
		blade.position.x = 0.75
		propeller_node.add_child(blade)
	
	add_child(propeller_node)

# Вспомогательная функция для поиска MeshInstance3D в иерархии
func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = find_mesh_instance(child)
		if result:
			return result
	
	return null

func can_attach(component_type_to_attach: String) -> bool:
	return component_type_to_attach in can_attach_to



func get_component_name() -> String:
	return component_name
