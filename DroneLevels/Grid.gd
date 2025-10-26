# Grid.gd (присвойте этой ноде)
extends Node3D

const GRID_SIZE = 32
const GRID_COLOR = Color(0.3, 0.3, 0.3, 0.3)

func _ready():
	create_grid()

func create_grid():
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.albedo_color = GRID_COLOR
	
	for i in range(-5, 6):
		# Горизонтальные линии
		create_line(
			Vector3(i * GRID_SIZE, 0, -5 * GRID_SIZE),
			Vector3(i * GRID_SIZE, 0, 5 * GRID_SIZE),
			material
		)
		# Вертикальные линии
		create_line(
			Vector3(-5 * GRID_SIZE, 0, i * GRID_SIZE),
			Vector3(5 * GRID_SIZE, 0, i * GRID_SIZE),
			material
		)

func create_line(from: Vector3, to: Vector3, material: Material):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()
	
	mesh_instance.mesh = immediate_mesh
	add_child(mesh_instance)
