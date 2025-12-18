extends Node

@onready var env_node: WorldEnvironment = get_parent().get_node("WorldEnvironment")
@onready var lights: Node3D = get_parent().get_node("LightsContainer")

func _ready() -> void:
	_setup_environment()
	_setup_lights()

# ================= ENVIRONMENT =================

func _setup_environment() -> void:
	var env := env_node.environment

	# 🎬 Киношный тон
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.5

	# 🎨 Цветокор
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.08

	# 🌫 ТУМАН (очень мягкий)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(1.0, 0.92, 0.85) # тёплый
	env.fog_density = 0.015
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 45.0

# ================= LIGHT =================

func _setup_lights() -> void:
	var main: DirectionalLight3D = lights.get_node("MainLight")
	var fill: OmniLight3D = lights.get_node("FillLight")

	# 🔥 ТЁПЛЫЙ КЛЮЧЕВОЙ СВЕТ
	main.light_color = Color(1.0, 0.9, 0.78)
	main.light_energy = 0.95
	main.shadow_enabled = true
	main.shadow_blur = 1.6
	main.shadow_bias = 0.04
	main.shadow_normal_bias = 0.8

	# 💡 ХОЛОДНЫЙ ЗАПОЛНЯЮЩИЙ
	fill.light_color = Color(0.7, 0.82, 1.0)
	fill.light_energy = 0.25
	fill.omni_range = 14.0
