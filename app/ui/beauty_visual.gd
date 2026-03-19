extends Node

var scene_root: Node3D = null
var env_node: WorldEnvironment = null
var lights: Node3D = null
var main_light: DirectionalLight3D = null
var fill_light: OmniLight3D = null
var accent_rig: Node3D = null
var halo: MeshInstance3D = null
var halo_material: StandardMaterial3D = null
var accent_lights: Array[OmniLight3D] = []
var key_spot: SpotLight3D = null

func _ready():
	scene_root = get_parent() as Node3D
	if scene_root == null:
		return

	env_node = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	lights = scene_root.get_node_or_null("LightsContainer") as Node3D

	_setup_environment()
	_setup_lights()
	_ensure_accent_rig()
	_ensure_floor_halo()
	set_process(true)

func _process(delta: float):
	if accent_rig != null:
		accent_rig.rotate_y(delta * 0.12)

	if main_light != null:
		Global.apply_directional_light_graphics(main_light)
	if fill_light != null:
		Global.apply_omni_light_graphics(fill_light)
	if key_spot != null:
		key_spot.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0016)
	if halo_material != null:
		var color := Global.highlight_color
		halo_material.albedo_color = Color(color.r, color.g, color.b, 0.16)
		halo_material.emission = Color(color.r, color.g, color.b, 1.0)
		halo_material.emission_energy_multiplier = 0.32 + pulse * 0.18

	for index in range(accent_lights.size()):
		var light := accent_lights[index]
		if light == null:
			continue
		var offset := float(index) * 0.7
		light.light_energy = 0.12 + 0.07 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0014 + offset))
		Global.apply_omni_light_graphics(light)

	if env_node != null and env_node.environment != null:
		Global.apply_environment_graphics(env_node.environment)

func _setup_environment():
	if env_node == null or env_node.environment == null:
		return

	var env := env_node.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.23, 0.18, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.ambient_light_energy = 0.54
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.06
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 0.96
	env.fog_enabled = false
	Global.apply_environment_graphics(env)

func _setup_lights():
	if lights == null:
		return

	main_light = lights.get_node_or_null("MainLight") as DirectionalLight3D
	if main_light != null:
		main_light.light_color = Color(1.0, 0.9, 0.78)
		main_light.light_energy = 1.36
		main_light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
		main_light.shadow_enabled = true
		main_light.shadow_blur = 0.12
		main_light.shadow_bias = 0.06
		main_light.shadow_normal_bias = 0.75
		Global.apply_directional_light_graphics(main_light)

	fill_light = lights.get_node_or_null("FillLight") as OmniLight3D
	if fill_light != null:
		fill_light.position = Vector3(0.0, 4.8, 0.0)
		fill_light.light_color = Color(0.62, 0.47, 0.32)
		fill_light.light_energy = 0.24
		fill_light.omni_range = 18.0
		Global.apply_omni_light_graphics(fill_light)

	key_spot = lights.get_node_or_null("DroneKeySpot") as SpotLight3D
	if key_spot == null:
		key_spot = SpotLight3D.new()
		key_spot.name = "DroneKeySpot"
		lights.add_child(key_spot)
	key_spot.position = Vector3(-5.8, 8.0, 7.2)
	key_spot.look_at(Vector3(0.0, 1.4, 0.0), Vector3.UP)
	key_spot.light_color = Color(1.0, 0.83, 0.56)
	key_spot.light_energy = 1.58
	key_spot.spot_range = 24.0
	key_spot.spot_angle = 34.0
	key_spot.shadow_enabled = true
	key_spot.shadow_blur = 0.18
	key_spot.shadow_bias = 0.05
	key_spot.shadow_normal_bias = 0.65

func _ensure_accent_rig():
	if lights == null:
		return

	accent_rig = lights.get_node_or_null("AccentRig") as Node3D
	if accent_rig == null:
		accent_rig = Node3D.new()
		accent_rig.name = "AccentRig"
		lights.add_child(accent_rig)

	if accent_rig.get_child_count() > 0:
		for child in accent_rig.get_children():
			if child is OmniLight3D:
				accent_lights.append(child as OmniLight3D)
			elif child.get_child_count() > 0 and child.get_child(0) is OmniLight3D:
				accent_lights.append(child.get_child(0) as OmniLight3D)
		return

	var colors := [
		Color(0.76, 0.57, 0.33),
		Color(0.91, 0.72, 0.44),
		Color(0.60, 0.42, 0.26),
		Color(0.84, 0.67, 0.48)
	]
	var positions := [
		Vector3(8.5, 2.2, 8.5),
		Vector3(-8.5, 2.4, 8.5),
		Vector3(-8.5, 2.6, -8.5),
		Vector3(8.5, 2.3, -8.5)
	]

	for index in range(positions.size()):
		var pivot := Node3D.new()
		pivot.name = "AccentPivot%d" % index
		accent_rig.add_child(pivot)

		var light := OmniLight3D.new()
		light.name = "AccentLight%d" % index
		light.position = positions[index]
		light.light_color = colors[index]
		light.light_energy = 0.18
		light.omni_range = 11.0
		pivot.add_child(light)
		accent_lights.append(light)
		Global.apply_omni_light_graphics(light)

func _ensure_floor_halo():
	halo = scene_root.get_node_or_null("AssemblyHalo") as MeshInstance3D
	if halo == null:
		halo = MeshInstance3D.new()
		halo.name = "AssemblyHalo"
		scene_root.add_child(halo)

	var mesh := CylinderMesh.new()
	mesh.top_radius = 8.0
	mesh.bottom_radius = 8.0
	mesh.height = 0.04
	halo.mesh = mesh
	halo.position = Vector3(0.0, 0.03, 0.0)

	halo_material = StandardMaterial3D.new()
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.albedo_color = Color(0.82, 0.64, 0.40, 0.16)
	halo_material.emission_enabled = true
	halo_material.emission = Color(0.82, 0.64, 0.40)
	halo_material.emission_energy_multiplier = 0.38
	halo_material.disable_receive_shadows = true
	halo.material_override = halo_material
