class_name StlRuntimeLoader
extends RefCounted

static var _mesh_cache: Dictionary = {}
static var _bounds_cache: Dictionary = {}

static func build_multipart_model(parts: Array, scale_value: Vector3 = Vector3.ONE, rotation_degrees: Vector3 = Vector3.ZERO, model_name: String = "RuntimeStlModel", center_mode: String = "bounds_center") -> Node3D:
	var cached_parts: Array[Dictionary] = []
	var overall_min: Vector3 = Vector3(INF, INF, INF)
	var overall_max: Vector3 = Vector3(-INF, -INF, -INF)

	for part_variant in parts:
		var part: Dictionary = part_variant as Dictionary
		var path: String = str(part.get("path", ""))
		if path.is_empty():
			continue

		var mesh_data: Dictionary = _load_binary_stl_mesh(path)
		if mesh_data.is_empty():
			continue

		var min_v: Vector3 = mesh_data.get("min", Vector3.ZERO)
		var max_v: Vector3 = mesh_data.get("max", Vector3.ZERO)
		overall_min = _vector_min(overall_min, min_v)
		overall_max = _vector_max(overall_max, max_v)
		cached_parts.append({
			"mesh": mesh_data.get("mesh", null),
			"name": str(part.get("name", "")),
			"color": part.get("color", Color.WHITE),
			"roughness": float(part.get("roughness", 0.65)),
			"metallic": float(part.get("metallic", 0.0))
		})

	if cached_parts.is_empty():
		return null

	var root := Node3D.new()
	root.name = model_name
	root.scale = scale_value
	root.rotation_degrees = rotation_degrees
	root.set_meta("runtime_material_ready", true)

	var resolved_center_mode: String = center_mode.strip_edges().to_lower()
	var center: Vector3 = Vector3.ZERO
	if resolved_center_mode != "origin":
		center = (overall_min + overall_max) * 0.5
	for i in range(cached_parts.size()):
		var part_data: Dictionary = cached_parts[i]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = str(part_data.get("name", "Part%d" % (i + 1)))
		mesh_instance.mesh = part_data.get("mesh", null)
		mesh_instance.position = -center
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

		var material := StandardMaterial3D.new()
		material.albedo_color = part_data.get("color", Color.WHITE)
		material.roughness = float(part_data.get("roughness", 0.65))
		material.metallic = float(part_data.get("metallic", 0.0))
		mesh_instance.material_override = material
		root.add_child(mesh_instance)

	return root

static func _load_binary_stl_mesh(path: String) -> Dictionary:
	if _mesh_cache.has(path) and _bounds_cache.has(path):
		var cached_bounds: Dictionary = _bounds_cache[path]
		return {
			"mesh": _mesh_cache[path],
			"min": cached_bounds.get("min", Vector3.ZERO),
			"max": cached_bounds.get("max", Vector3.ZERO)
		}

	if not FileAccess.file_exists(path):
		push_warning("STL file not found: %s" % path)
		return {}

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 84:
		push_warning("STL file is too small: %s" % path)
		return {}

	var stream := StreamPeerBuffer.new()
	stream.data_array = bytes
	stream.big_endian = false
	stream.seek(80)

	var triangle_count: int = int(stream.get_u32())
	var expected_size: int = 84 + triangle_count * 50
	if triangle_count <= 0 or expected_size > bytes.size():
		push_warning("Unsupported STL payload: %s" % path)
		return {}

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(triangle_count * 3)
	normals.resize(triangle_count * 3)

	var write_index: int = 0
	var min_v: Vector3 = Vector3(INF, INF, INF)
	var max_v: Vector3 = Vector3(-INF, -INF, -INF)

	for _triangle_index in range(triangle_count):
		var normal := Vector3(stream.get_float(), stream.get_float(), stream.get_float())
		var triangle_vertices: Array[Vector3] = [
			Vector3(stream.get_float(), stream.get_float(), stream.get_float()),
			Vector3(stream.get_float(), stream.get_float(), stream.get_float()),
			Vector3(stream.get_float(), stream.get_float(), stream.get_float())
		]
		stream.get_u16()

		if normal.length_squared() < 0.000001:
			normal = _compute_triangle_normal(triangle_vertices)

		for vertex in triangle_vertices:
			vertices[write_index] = vertex
			normals[write_index] = normal
			write_index += 1
			min_v = _vector_min(min_v, vertex)
			max_v = _vector_max(max_v, vertex)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_mesh_cache[path] = mesh
	_bounds_cache[path] = {"min": min_v, "max": max_v}
	return {"mesh": mesh, "min": min_v, "max": max_v}

static func _compute_triangle_normal(vertices: Array[Vector3]) -> Vector3:
	if vertices.size() < 3:
		return Vector3.UP
	var normal: Vector3 = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).normalized()
	return normal if normal.length_squared() > 0.0 else Vector3.UP

static func _vector_min(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))

static func _vector_max(a: Vector3, b: Vector3) -> Vector3:
	return Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
