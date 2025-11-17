extends Node3D

@export var component_name: String = ""
@export var component_type: String = ""  # "frame", "board", "motor", "propeller"
@export var component_variant: int = 1  # 1, 2 или 3
@export var can_attach_to: PackedStringArray = []

var is_attached: bool = false

func _ready():
	setup_component()

func setup_component():
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

func create_frame():
	# Пытаемся загрузить .obj модель
	var model_path = "res://create_drone/models/frame" + str(component_variant) + ".obj"
	
	if ResourceLoader.exists(model_path):
		var mesh = load(model_path)
		if mesh:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = mesh
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.2, 0.2, 0.2)
			mesh_instance.material_override = material
			mesh_instance.scale = Vector3(0.1, 0.1, 0.1)
			add_child(mesh_instance)
			return
	
	# Fallback
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 0.1, 2.0)
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	mesh_instance.material_override = material
	add_child(mesh_instance)

func create_board():
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.05, 0.8)
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0.5, 0)
	mesh_instance.material_override = material
	add_child(mesh_instance)

func create_motor():
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
	# Пытаемся загрузить .obj модель
	var model_path = "res://create_drone/models/propeller" + str(component_variant) + ".obj"
	
	if ResourceLoader.exists(model_path):
		var mesh = load(model_path)
		if mesh:
			var mesh_instance = MeshInstance3D.new()
			mesh_instance.mesh = mesh
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.9, 0.9, 0.9)
			mesh_instance.material_override = material
			mesh_instance.scale = Vector3(0.01, 0.01, 0.01)  # Очень маленький масштаб
			add_child(mesh_instance)
			add_rotation_script(mesh_instance)
			return
	
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
		blade.rotation_degrees.y = i * 90
		blade.position.x = 0.75
		propeller_node.add_child(blade)
	
	add_child(propeller_node)
	add_rotation_script(propeller_node)

func add_rotation_script(node: Node3D):
	var rotation_script = GDScript.new()
	rotation_script.source_code = "extends Node3D\n\nvar rotation_speed = 360.0\n\nfunc _process(delta):\n\trotate_y(deg_to_rad(rotation_speed * delta))"
	rotation_script.reload()
	node.set_script(rotation_script)

func can_attach(component_type_to_attach: String) -> bool:
	return component_type_to_attach in can_attach_to

func get_component_type() -> String:
	return component_type

func get_component_name() -> String:
	return component_name
