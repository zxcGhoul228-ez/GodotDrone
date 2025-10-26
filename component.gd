extends Node3D

@export var component_name: String = ""
@export var component_type: String = ""  # "frame", "board", "motor", "propeller"
@export var can_attach_to: PackedStringArray = []
var is_attached: bool = false

func _ready():
	# Настраиваем компонент
	setup_component()

func setup_component():
	match component_type:
		"frame":
			component_name = "Рама дрона"
			can_attach_to = ["board", "motor"]
			create_frame_mesh()
		"board":
			component_name = "Плата управления"
			can_attach_to = []
			create_board_mesh()
		"motor":
			component_name = "Двигатель"
			can_attach_to = ["propeller"]
			create_motor_mesh()
		"propeller":
			component_name = "Пропеллер"
			can_attach_to = []
			create_propeller_mesh()

func create_frame_mesh():
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(2.2, 0.2, 2.2)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = frame_mesh
	
	var frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.1, 0.1, 0.1)
	mesh_instance.material_override = frame_material
	
	add_child(mesh_instance)

func create_board_mesh():
	var board_mesh = BoxMesh.new()
	board_mesh.size = Vector3(0.8, 0.1, 0.8)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = board_mesh
	
	var board_material = StandardMaterial3D.new()
	board_material.albedo_color = Color(0, 0.5, 0)
	mesh_instance.material_override = board_material
	
	add_child(mesh_instance)

func create_motor_mesh():
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.2
	cylinder_mesh.bottom_radius = 0.2
	cylinder_mesh.height = 0.3
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = cylinder_mesh
	
	var motor_material = StandardMaterial3D.new()
	motor_material.albedo_color = Color(0.8, 0.8, 0.8)
	mesh_instance.material_override = motor_material
	
	add_child(mesh_instance)

func create_propeller_mesh():
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(1.5, 0.05, 0.2)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = blade_mesh
	
	var propeller_material = StandardMaterial3D.new()
	propeller_material.albedo_color = Color(0.9, 0.9, 0.9)
	mesh_instance.material_override = propeller_material
	
	add_child(mesh_instance)
