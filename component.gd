extends Node3D

@export var component_name: String = ""
@export var component_type: String = ""  # "frame", "board", "motor", "propeller"
@export var component_variant: int = 1  # 1, 2 или 3
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
			component_name = "Рама%d" % component_variant
			can_attach_to = ["board", "motor"]
		"board":
			component_mass = 0.3
			component_name = "Плата%d" % component_variant
			can_attach_to = []
		"motor":
			component_mass = get_motor_mass(component_variant)
			component_thrust = get_motor_thrust(component_variant)
			component_name = "Мотор%d" % component_variant
			can_attach_to = ["propeller"]
		"propeller":
			component_mass = 0.1
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
		1: return 1.0  # Маленький
		2: return 1.2  # Средний
		3: return 1.5  # Большой
		_: return 1.2

func mark_as_propeller():
	set_meta("is_drone_propeller", true)
	add_to_group("drone_propellers")
	
	for child in get_children():
		if child is MeshInstance3D or child is Node3D:
			child.set_meta("is_drone_propeller", true)
			child.add_to_group("drone_propellers")

func get_component_type() -> String:
	return component_type

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
func load_model(base_name: String, default_scale: Vector3 = Vector3(0.1, 0.1, 0.1)) -> Node3D:
	var variant_str = str(component_variant)
	
	# Сначала пробуем .glb (только для платы)
	if component_type == "board":
		var glb_path = "res://create_drone/models/" + base_name + variant_str + ".glb"
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
		var gltf_path = "res://create_drone/models/" + base_name + variant_str + ".gltf"
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
	
	# Для всех типов пробуем .obj (основной формат)
	var obj_path = "res://create_drone/models/" + base_name + variant_str + ".obj"
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

func create_frame():
	print("DEBUG: Creating frame...")
	var model = load_model("frame", Vector3(0.1, 0.1, 0.1))
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
