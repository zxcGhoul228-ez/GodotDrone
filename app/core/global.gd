extends Node

const GLOBAL_SETTINGS_PATH := "user://global_settings.cfg"
const ARDUINO_WIRING_PATH := "user://arduino_wiring.json"
const EXPORTED_DRONE_PROFILE_PATH := "user://exported_drone_profile.json"
const WINDOW_RESOLUTION_SYSTEM := "system"
const DEFAULT_VIEWPORT_SIZE := Vector2i(1920, 1080)
const WINDOW_MODE_WINDOWED := 0
const WINDOW_MODE_BORDERLESS := 1
const WINDOW_MODE_FULLSCREEN := 2
const BASIC_HIGHLIGHT_COLOR := Color(0.82, 0.64, 0.40, 0.6)
const BASIC_TRAIL_COLOR := Color(0.66, 0.48, 0.28, 0.5)
const CUSTOM_TEXTURES_DIR := "user://custom_cosmetics"
const MAX_ACTIVE_QUESTS := 3
const QUEST_REFRESH_COST := 120
const QUEST_REFRESH_COST_STEP := 80
const TEST_CRYSTAL_RESERVE := 50000
const LEVEL_IDEAL_COMMAND_DURATION_MS := 1000
const LEVEL_IDEAL_SEQUENCE_OVERHEAD_MS := 600
const DEFAULT_PURCHASED_ITEMS: Array[String] = ["Рама1", "РамаГекса", "РамаОкто", "Плата1", "Мотор1", "Пропеллер1"]
const DEFAULT_COSMETIC_UNLOCKS: Array[String] = ["color_default", "pattern_default", "texture_default", "aura_default", "trail_default"]
const LEVEL_IDEAL_COMMANDS := {
	1: 6,
	2: 7,
	3: 8,
	4: 10,
	5: 11,
	6: 12,
	7: 13,
	8: 14,
	9: 17,
	10: 18,
	11: 21,
	12: 23,
	13: 25,
	14: 27,
	15: 29
}

var purchased_items = DEFAULT_PURCHASED_ITEMS.duplicate()
var score := 100000
var crystals := 0
static var drone_data: Dictionary = {}
var current_level := 1
var levels_unlocked := 1
var levels_data: Dictionary = {}
var quest_definitions: Array = []
var quest_progress: Dictionary = {}
var active_quest_ids: Array[String] = []
var quest_refresh_streak := 0
var claimed_quests_in_cycle := 0
var drone_cosmetic_unlocks: Array[String] = []
var drone_cosmetic_profile: Dictionary = {}
var _cosmetic_texture_cache: Dictionary = {}

var _camera_fov := 75.0
var _mouse_sensitivity := 1.0
var _brightness := 1.0
var _music_volume := 50.0
var _sfx_volume := 50.0
var _fps_mode := 3
var _render_scale := 1.0
var _shadow_quality := 2
var _glow_enabled := true
var _ssao_enabled := true
var _window_mode := WINDOW_MODE_WINDOWED
var _resolution_key := WINDOW_RESOLUTION_SYSTEM
var _highlight_color := BASIC_HIGHLIGHT_COLOR
var _trail_color := BASIC_TRAIL_COLOR

var camera_fov: float:
	get:
		return _camera_fov
	set(value):
		value = clampf(value, 60.0, 120.0)
		if is_equal_approx(_camera_fov, value):
			return
		_camera_fov = value
		camera_fov_changed.emit(value)

var mouse_sensitivity: float:
	get:
		return _mouse_sensitivity
	set(value):
		value = clampf(value, 0.1, 3.0)
		if is_equal_approx(_mouse_sensitivity, value):
			return
		_mouse_sensitivity = value
		mouse_sensitivity_changed.emit(value)

var brightness: float:
	get:
		return _brightness
	set(value):
		value = clampf(value, 0.55, 1.6)
		if is_equal_approx(_brightness, value):
			return
		_brightness = value
		brightness_changed.emit(value)

var music_volume: float:
	get:
		return _music_volume
	set(value):
		value = clampf(value, 0.0, 100.0)
		if is_equal_approx(_music_volume, value):
			return
		_music_volume = value
		music_volume_changed.emit(value)

var sfx_volume: float:
	get:
		return _sfx_volume
	set(value):
		value = clampf(value, 0.0, 100.0)
		if is_equal_approx(_sfx_volume, value):
			return
		_sfx_volume = value
		sfx_volume_changed.emit(value)

var fps_mode: int:
	get:
		return _fps_mode
	set(value):
		value = clampi(value, 0, 3)
		if _fps_mode == value:
			return
		_fps_mode = value
		fps_mode_changed.emit(value)

var render_scale: float:
	get:
		return _render_scale
	set(value):
		value = clampf(value, 0.55, 1.3)
		if is_equal_approx(_render_scale, value):
			return
		_render_scale = value
		render_scale_changed.emit(value)

var shadow_quality: int:
	get:
		return _shadow_quality
	set(value):
		value = clampi(value, 0, 3)
		if _shadow_quality == value:
			return
		_shadow_quality = value
		shadow_quality_changed.emit(value)

var glow_enabled: bool:
	get:
		return _glow_enabled
	set(value):
		if _glow_enabled == value:
			return
		_glow_enabled = value
		glow_enabled_changed.emit(value)

var ssao_enabled: bool:
	get:
		return _ssao_enabled
	set(value):
		if _ssao_enabled == value:
			return
		_ssao_enabled = value
		ssao_enabled_changed.emit(value)

var fullscreen_enabled: bool:
	get:
		return _window_mode == WINDOW_MODE_FULLSCREEN
	set(value):
		window_mode = WINDOW_MODE_FULLSCREEN if value else WINDOW_MODE_WINDOWED

var window_mode: int:
	get:
		return _window_mode
	set(value):
		value = clampi(value, WINDOW_MODE_WINDOWED, WINDOW_MODE_FULLSCREEN)
		if _window_mode == value:
			return
		var previous_fullscreen: bool = fullscreen_enabled
		_window_mode = value
		window_mode_changed.emit(value)
		if previous_fullscreen != fullscreen_enabled:
			fullscreen_enabled_changed.emit(fullscreen_enabled)

var resolution_key: String:
	get:
		return _resolution_key
	set(value):
		var normalized_value: String = _sanitize_resolution_key(value)
		if _resolution_key == normalized_value:
			return
		_resolution_key = normalized_value
		resolution_changed.emit(normalized_value)

var highlight_color: Color:
	get:
		return _highlight_color
	set(value):
		if _highlight_color == value:
			return
		_highlight_color = value
		highlight_color_changed.emit(value)

var trail_color: Color:
	get:
		return _trail_color
	set(value):
		if _trail_color == value:
			return
		_trail_color = value
		trail_color_changed.emit(value)

signal mouse_sensitivity_changed(value: float)
signal camera_fov_changed(value: float)
signal brightness_changed(value: float)
signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal fps_mode_changed(value: int)
signal render_scale_changed(value: float)
signal shadow_quality_changed(value: int)
signal glow_enabled_changed(value: bool)
signal ssao_enabled_changed(value: bool)
signal fullscreen_enabled_changed(value: bool)
signal window_mode_changed(value: int)
signal resolution_changed(value: String)
signal highlight_color_changed(value: Color)
signal trail_color_changed(value: Color)
signal settings_saved
signal settings_loaded
signal quests_changed
signal crystals_changed
signal cosmetic_inventory_changed
signal cosmetic_profile_changed

var loading_screen: Control = null
var last_exported_drone_info: Dictionary = {}
var arduino_wiring_profile: Dictionary = {}

var level_star_thresholds = {
	1: [30000, 45000, 60000],
	2: [45000, 60000, 90000],
	3: [60000, 90000, 120000],
	4: [75000, 105000, 150000],
	5: [90000, 120000, 180000],
	6: [120000, 150000, 210000],
	7: [150000, 180000, 240000],
	8: [180000, 210000, 270000],
	9: [210000, 240000, 300000],
	10: [240000, 270000, 330000],
	11: [270000, 300000, 360000],
	12: [300000, 330000, 390000],
	13: [330000, 360000, 420000],
	14: [360000, 390000, 450000],
	15: [390000, 420000, 480000]
}

var star_rewards = {
	1: 25,
	2: 50,
	3: 100
}

var first_time_reward_multiplier := 1.18

func _ready():
	print("=== GLOBAL INIT ===")
	quest_definitions = _build_quest_definitions()
	load_game()
	_ensure_default_purchased_items()
	if crystals < TEST_CRYSTAL_RESERVE:
		crystals = TEST_CRYSTAL_RESERVE
		save_game()
	load_levels_data()
	load_global_settings()
	last_exported_drone_info = load_exported_drone_profile()
	arduino_wiring_profile = load_arduino_wiring()
	_sync_effect_colors_from_cosmetics()
	apply_global_settings()
	print("Уровней разблокировано: ", levels_unlocked)
	print("Текущие очки: ", score)

func save_global_settings():
	var config := ConfigFile.new()
	config.set_value("settings", "fps_mode", fps_mode)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "camera_fov", camera_fov)
	config.set_value("settings", "brightness", brightness)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "render_scale", render_scale)
	config.set_value("settings", "shadow_quality", shadow_quality)
	config.set_value("settings", "glow_enabled", glow_enabled)
	config.set_value("settings", "ssao_enabled", ssao_enabled)
	config.set_value("settings", "fullscreen_enabled", fullscreen_enabled)
	config.set_value("settings", "window_mode", window_mode)
	config.set_value("settings", "resolution_key", resolution_key)
	config.set_value("settings", "highlight_color", highlight_color)
	config.set_value("settings", "trail_color", trail_color)

	var error := config.save(GLOBAL_SETTINGS_PATH)
	if error == OK:
		settings_saved.emit()
	else:
		push_warning("Failed to save global settings: %s" % error)

func load_global_settings():
	var config := ConfigFile.new()
	var error := config.load(GLOBAL_SETTINGS_PATH)
	if error != OK:
		save_global_settings()
		settings_loaded.emit()
		return

	fps_mode = int(config.get_value("settings", "fps_mode", 3))
	mouse_sensitivity = float(config.get_value("settings", "mouse_sensitivity", 1.0))
	camera_fov = float(config.get_value("settings", "camera_fov", 75.0))
	brightness = float(config.get_value("settings", "brightness", 1.0))
	music_volume = float(config.get_value("settings", "music_volume", 50.0))
	sfx_volume = float(config.get_value("settings", "sfx_volume", 50.0))
	render_scale = float(config.get_value("settings", "render_scale", 1.0))
	shadow_quality = int(config.get_value("settings", "shadow_quality", 2))
	glow_enabled = bool(config.get_value("settings", "glow_enabled", true))
	ssao_enabled = bool(config.get_value("settings", "ssao_enabled", true))
	var legacy_fullscreen: bool = bool(config.get_value("settings", "fullscreen_enabled", false))
	window_mode = int(config.get_value("settings", "window_mode", WINDOW_MODE_FULLSCREEN if legacy_fullscreen else WINDOW_MODE_WINDOWED))
	resolution_key = str(config.get_value("settings", "resolution_key", WINDOW_RESOLUTION_SYSTEM))
	highlight_color = config.get_value("settings", "highlight_color", Color(0.82, 0.64, 0.40, 0.6))
	trail_color = config.get_value("settings", "trail_color", Color(0.66, 0.48, 0.28, 0.5))
	settings_loaded.emit()

func apply_global_settings():
	match fps_mode:
		0:
			Engine.max_fps = 30
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1:
			Engine.max_fps = 60
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		2:
			Engine.max_fps = 120
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		3:
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

	call_deferred("_apply_window_mode")
	call_deferred("_apply_viewport_render_scale")
	_apply_audio_bus_volume_if_exists("Music", music_volume)
	_apply_audio_bus_volume_if_exists("SFX", sfx_volume)

func _apply_window_mode():
	var tree: SceneTree = get_tree()
	var root_window: Window = tree.root if tree != null else null
	if root_window == null:
		return
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = _get_current_screen_size()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		usable_rect = Rect2i(Vector2i.ZERO, screen_size)

	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root_window.content_scale_size = get_project_viewport_size()
	root_window.borderless = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	match window_mode:
		WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			root_window.mode = Window.MODE_FULLSCREEN
			root_window.size = screen_size
		WINDOW_MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root_window.mode = Window.MODE_WINDOWED
			root_window.borderless = true
			DisplayServer.window_set_size(usable_rect.size)
			DisplayServer.window_set_position(usable_rect.position)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			root_window.position = usable_rect.position
			root_window.size = usable_rect.size
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			root_window.mode = Window.MODE_WINDOWED
			var target_size: Vector2i = _get_windowed_resolution(usable_rect.size)
			DisplayServer.window_set_size(target_size)

			var target_position: Vector2i = Vector2i(
				usable_rect.position.x + int(round((usable_rect.size.x - target_size.x) * 0.5)),
				usable_rect.position.y + int(round((usable_rect.size.y - target_size.y) * 0.5))
			)
			DisplayServer.window_set_position(target_position)
			root_window.size = target_size
			root_window.position = target_position

func get_available_window_resolutions() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var seen: Dictionary = {}
	var screen_size: Vector2i = _get_current_screen_size()
	var screen_label: String = "По умолчанию системы (%d x %d)" % [screen_size.x, screen_size.y]
	options.append({"key": WINDOW_RESOLUTION_SYSTEM, "label": screen_label})
	seen[WINDOW_RESOLUTION_SYSTEM] = true

	var predefined_resolutions: Array[Vector2i] = [
		Vector2i(1024, 576),
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1440, 900),
		Vector2i(1600, 900),
		Vector2i(1680, 1050),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]

	for resolution in predefined_resolutions:
		_append_window_resolution_option(options, seen, resolution, screen_size)

	_append_window_resolution_option(options, seen, get_project_viewport_size(), screen_size)
	_append_window_resolution_option(options, seen, screen_size, screen_size)
	return options

func get_project_viewport_size() -> Vector2i:
	var viewport_width: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", DEFAULT_VIEWPORT_SIZE.x))
	var viewport_height: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", DEFAULT_VIEWPORT_SIZE.y))
	return Vector2i(maxi(viewport_width, 960), maxi(viewport_height, 540))

func get_resolution_label(key: String) -> String:
	var sanitized_key: String = _sanitize_resolution_key(key)
	if sanitized_key == WINDOW_RESOLUTION_SYSTEM:
		var screen_size: Vector2i = _get_current_screen_size()
		return "По умолчанию системы (%d x %d)" % [screen_size.x, screen_size.y]

	var resolution_size: Vector2i = _parse_resolution_key(sanitized_key)
	if resolution_size == Vector2i.ZERO:
		resolution_size = get_project_viewport_size()
	return "%d x %d" % [resolution_size.x, resolution_size.y]

func _append_window_resolution_option(options: Array[Dictionary], seen: Dictionary, resolution: Vector2i, screen_size: Vector2i):
	if resolution.x < 960 or resolution.y < 540:
		return
	if resolution.x > screen_size.x or resolution.y > screen_size.y:
		return

	var resolution_key_string: String = _format_resolution_key(resolution)
	if seen.has(resolution_key_string):
		return

	options.append({
		"key": resolution_key_string,
		"label": "%d x %d" % [resolution.x, resolution.y]
	})
	seen[resolution_key_string] = true

func _get_windowed_resolution(max_size: Vector2i) -> Vector2i:
	var project_size: Vector2i = get_project_viewport_size()
	if project_size.x <= max_size.x and project_size.y <= max_size.y:
		return project_size

	var width_ratio: float = float(max_size.x) / float(project_size.x)
	var height_ratio: float = float(max_size.y) / float(project_size.y)
	var scale_ratio: float = minf(width_ratio, height_ratio)
	var target_width: int = maxi(960, int(round(project_size.x * scale_ratio)))
	var target_height: int = maxi(540, int(round(project_size.y * scale_ratio)))
	return Vector2i(target_width, target_height)

func _get_selected_resolution(screen_size: Vector2i) -> Vector2i:
	if resolution_key == WINDOW_RESOLUTION_SYSTEM:
		return get_project_viewport_size()
	var explicit_resolution: Vector2i = _parse_resolution_key(resolution_key)
	return _clamp_resolution_to_bounds(explicit_resolution, screen_size)

func _get_resolution_quality_scale(screen_size: Vector2i) -> float:
	if resolution_key == WINDOW_RESOLUTION_SYSTEM:
		return 1.0
	var project_size: Vector2i = get_project_viewport_size()
	var selected_resolution: Vector2i = _get_selected_resolution(screen_size)
	var width_ratio: float = float(selected_resolution.x) / float(project_size.x)
	var height_ratio: float = float(selected_resolution.y) / float(project_size.y)
	return clampf(minf(width_ratio, height_ratio), 0.5, 1.0)

func _sanitize_resolution_key(value: String) -> String:
	var normalized_value: String = value.strip_edges().to_lower()
	if normalized_value.is_empty() or normalized_value == WINDOW_RESOLUTION_SYSTEM:
		return WINDOW_RESOLUTION_SYSTEM

	var parsed_resolution: Vector2i = _parse_resolution_key(normalized_value)
	if parsed_resolution == Vector2i.ZERO:
		return WINDOW_RESOLUTION_SYSTEM

	var screen_size: Vector2i = _get_current_screen_size()
	if parsed_resolution.x > screen_size.x or parsed_resolution.y > screen_size.y:
		return WINDOW_RESOLUTION_SYSTEM
	return _format_resolution_key(parsed_resolution)

func _parse_resolution_key(value: String) -> Vector2i:
	var normalized_value: String = value.strip_edges().to_lower()
	if normalized_value == WINDOW_RESOLUTION_SYSTEM:
		return Vector2i.ZERO

	var parts: PackedStringArray = normalized_value.split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i.ZERO

	var width: int = int(parts[0])
	var height: int = int(parts[1])
	if width <= 0 or height <= 0:
		return Vector2i.ZERO
	return Vector2i(width, height)

func _format_resolution_key(value: Vector2i) -> String:
	return "%dx%d" % [value.x, value.y]

func _clamp_resolution_to_bounds(value: Vector2i, max_size: Vector2i) -> Vector2i:
	if value == Vector2i.ZERO:
		value = get_project_viewport_size()

	var clamped_width: int = mini(maxi(value.x, 960), max_size.x)
	var clamped_height: int = mini(maxi(value.y, 540), max_size.y)
	return Vector2i(clamped_width, clamped_height)

func _get_current_screen_size() -> Vector2i:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return get_project_viewport_size()
	return screen_size

func apply_environment_graphics(environment: Environment):
	if environment == null:
		return
	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness
	environment.adjustment_contrast = max(environment.adjustment_contrast, 1.08)
	environment.adjustment_saturation = max(environment.adjustment_saturation, 1.02)
	environment.glow_enabled = glow_enabled
	if glow_enabled:
		environment.glow_strength = max(environment.glow_strength, 0.55)
		environment.glow_hdr_threshold = min(environment.glow_hdr_threshold, 1.2)
	environment.ssao_enabled = ssao_enabled
	if ssao_enabled:
		environment.ssao_radius = max(environment.ssao_radius, 1.1)
		environment.ssao_intensity = max(environment.ssao_intensity, 0.5)
		environment.ssao_light_affect = max(environment.ssao_light_affect, 0.15)

func apply_directional_light_graphics(light: DirectionalLight3D):
	if light == null:
		return
	match shadow_quality:
		0:
			light.shadow_enabled = false
			light.light_energy = max(light.light_energy, 0.85)
		1:
			light.shadow_enabled = true
			light.shadow_blur = 0.18
			light.shadow_bias = 0.07
			light.shadow_normal_bias = 0.95
			light.directional_shadow_max_distance = 320.0
			light.shadow_opacity = 0.52
		2:
			light.shadow_enabled = true
			light.shadow_blur = 0.82
			light.shadow_bias = 0.05
			light.shadow_normal_bias = 0.82
			light.directional_shadow_max_distance = 520.0
			light.shadow_opacity = 0.56
		3:
			light.shadow_enabled = true
			light.shadow_blur = 1.7
			light.shadow_bias = 0.035
			light.shadow_normal_bias = 0.7
			light.directional_shadow_max_distance = 760.0
			light.shadow_opacity = 0.6

func apply_omni_light_graphics(light: OmniLight3D):
	if light == null:
		return
	match shadow_quality:
		0:
			light.shadow_enabled = false
		1:
			light.shadow_enabled = false
			light.light_energy = max(light.light_energy, 0.2)
		2:
			light.shadow_enabled = false
			light.light_energy = max(light.light_energy, 0.28)
		3:
			light.shadow_enabled = true
			light.shadow_bias = 0.08
			light.shadow_normal_bias = 1.1
			light.light_energy = max(light.light_energy, 0.32)

func reset_settings_to_default():
	fps_mode = 3
	mouse_sensitivity = 1.0
	camera_fov = 75.0
	brightness = 1.0
	music_volume = 50.0
	sfx_volume = 50.0
	render_scale = 1.0
	shadow_quality = 2
	glow_enabled = true
	ssao_enabled = true
	window_mode = WINDOW_MODE_WINDOWED
	resolution_key = WINDOW_RESOLUTION_SYSTEM
	highlight_color = BASIC_HIGHLIGHT_COLOR
	trail_color = BASIC_TRAIL_COLOR
	save_global_settings()
	apply_global_settings()

func save_exported_drone_profile(profile: Dictionary):
	last_exported_drone_info = profile.duplicate(true)
	_save_json_dictionary(EXPORTED_DRONE_PROFILE_PATH, _serialize_variant(profile))

func load_exported_drone_profile() -> Dictionary:
	var raw := _load_json_dictionary(EXPORTED_DRONE_PROFILE_PATH)
	if raw.is_empty():
		last_exported_drone_info = {}
		return {}
	var profile_value: Variant = _deserialize_variant(raw)
	if typeof(profile_value) == TYPE_DICTIONARY:
		var profile: Dictionary = profile_value
		last_exported_drone_info = profile
		return profile
	last_exported_drone_info = {}
	return {}

func save_arduino_wiring(profile: Dictionary):
	arduino_wiring_profile = profile.duplicate(true)
	_save_json_dictionary(ARDUINO_WIRING_PATH, _serialize_variant(profile))

func load_arduino_wiring() -> Dictionary:
	var raw := _load_json_dictionary(ARDUINO_WIRING_PATH)
	if raw.is_empty():
		arduino_wiring_profile = {}
		return {}
	var profile_value: Variant = _deserialize_variant(raw)
	if typeof(profile_value) == TYPE_DICTIONARY:
		var profile: Dictionary = profile_value
		arduino_wiring_profile = profile
		return profile
	arduino_wiring_profile = {}
	return {}

func clear_arduino_wiring():
	arduino_wiring_profile = {}
	if FileAccess.file_exists(ARDUINO_WIRING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARDUINO_WIRING_PATH))

func get_recommended_motor_pins(platform_type: String = "") -> PackedStringArray:
	var effective_platform: String = platform_type
	if effective_platform.is_empty() and not last_exported_drone_info.is_empty():
		effective_platform = str(last_exported_drone_info.get("platform_type", ""))
	if effective_platform.is_empty():
		effective_platform = DronePlatformConfig.PLATFORM_QUAD
	return DronePlatformConfig.get_recommended_motor_pins(effective_platform)

func get_drone_signature(profile: Dictionary) -> String:
	if profile.is_empty():
		return "empty"
	var motor_slots: Array[int] = []
	for motor_variant in profile.get("motors", []):
		if typeof(motor_variant) != TYPE_DICTIONARY:
			continue
		var motor_data: Dictionary = motor_variant
		motor_slots.append(int(motor_data.get("slot", -1)))
	motor_slots.sort()
	var slot_parts: Array[String] = []
	for slot in motor_slots:
		slot_parts.append(str(slot))
	var slot_signature := ",".join(slot_parts)
	return "%s|%s|%s|%d|%d|%s" % [
		str(profile.get("platform_type", DronePlatformConfig.get_platform_for_frame_type(str(profile.get("frame_type", ""))))),
		str(profile.get("frame_type", "frame")),
		str(profile.get("board_type", "board")),
		str(profile.get("motor_type", "motor")),
		int(profile.get("motor_count", 0)),
		int(profile.get("propeller_count", 0)),
		slot_signature
	]

func get_arduino_wiring_summary(profile: Dictionary = {}) -> Dictionary:
	var active_profile := profile if not profile.is_empty() else arduino_wiring_profile
	var mapped_motors := int(active_profile.get("mapped_motor_count", 0))
	var total_motors := int(last_exported_drone_info.get("motor_count", 0))
	var assigned_pins: Array = []
	for entry_variant in active_profile.get("motor_pin_map", []):
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		assigned_pins.append(str(entry.get("pin", "")))

	return {
		"drone_signature": active_profile.get("drone_signature", get_drone_signature(last_exported_drone_info)),
		"mapped_motor_count": mapped_motors,
		"total_motor_count": total_motors,
		"is_complete": total_motors > 0 and mapped_motors >= total_motors,
		"assigned_pins": assigned_pins,
		"recommended_pins": get_recommended_motor_pins()
	}

func _build_quest_definitions() -> Array:
	return [
		{"id": "cells_50", "category": "distance", "title": "Разведка", "description": "Пролетите 50 клеток суммарно.", "metric": "cells_flown_total", "goal": 50, "reward": 24},
		{"id": "cells_180", "category": "distance", "title": "Длинный маршрут", "description": "Пролетите 180 клеток суммарно.", "metric": "cells_flown_total", "goal": 180, "reward": 60},
		{"id": "levels_1", "category": "progress", "title": "Первый вылет", "description": "Пройдите 1 уровень.", "metric": "unique_levels_completed", "goal": 1, "reward": 26},
		{"id": "levels_5", "category": "progress", "title": "Хороший темп", "description": "Пройдите 5 разных уровней.", "metric": "unique_levels_completed", "goal": 5, "reward": 58},
		{"id": "levels_10", "category": "progress", "title": "Почти вся кампания", "description": "Пройдите 10 разных уровней.", "metric": "unique_levels_completed", "goal": 10, "reward": 110},
		{"id": "stars_6", "category": "stars", "title": "Первые аплодисменты", "description": "Соберите 6 звезд.", "metric": "best_stars_total", "goal": 6, "reward": 36},
		{"id": "stars_18", "category": "stars", "title": "Точный пилот", "description": "Соберите 18 звезд.", "metric": "best_stars_total", "goal": 18, "reward": 78},
		{"id": "stars_32", "category": "stars", "title": "Созвездие маршрутов", "description": "Соберите 32 звезды.", "metric": "best_stars_total", "goal": 32, "reward": 148},
		{"id": "shop_2", "category": "shop", "title": "Комплектовщик", "description": "Купите 2 предмета в магазине.", "metric": "shop_purchases_total", "goal": 2, "reward": 32},
		{"id": "shop_6", "category": "shop", "title": "Склад пополняется", "description": "Купите 6 предметов в магазине.", "metric": "shop_purchases_total", "goal": 6, "reward": 86},
		{"id": "spend_180", "category": "economy", "title": "Инвестиции", "description": "Потратьте 180 монет.", "metric": "coins_spent_total", "goal": 180, "reward": 34},
		{"id": "spend_900", "category": "economy", "title": "Большой бюджет", "description": "Потратьте 900 монет.", "metric": "coins_spent_total", "goal": 900, "reward": 100},
		{"id": "earn_250", "category": "earnings", "title": "Чистая прибыль", "description": "Заработайте 250 монет за уровни.", "metric": "coins_earned_total", "goal": 250, "reward": 40},
		{"id": "earn_1800", "category": "earnings", "title": "Дрон-магнат", "description": "Заработайте 1800 монет за уровни.", "metric": "coins_earned_total", "goal": 1800, "reward": 132},
		{"id": "attempts_6", "category": "activity", "title": "Упрямый тестер", "description": "Сделайте 6 попыток прохождения.", "metric": "route_attempts_total", "goal": 6, "reward": 24},
		{"id": "attempts_20", "category": "activity", "title": "Полигон не отпускает", "description": "Сделайте 20 попыток прохождения.", "metric": "route_attempts_total", "goal": 20, "reward": 74},
		{"id": "fast_2", "category": "speed", "title": "Быстрый дубль", "description": "Завершите 2 уровня в хорошем темпе.", "metric": "fast_finishes_total", "goal": 2, "reward": 48},
		{"id": "fast_6", "category": "speed", "title": "Спидранер", "description": "Завершите 6 уровней в хорошем темпе.", "metric": "fast_finishes_total", "goal": 6, "reward": 120},
		{"id": "scheme_1", "category": "engineering", "title": "Схема в норме", "description": "Соберите 1 корректную Arduino-схему.", "metric": "valid_schemes_total", "goal": 1, "reward": 54},
		{"id": "scheme_4", "category": "engineering", "title": "Проводка под контролем", "description": "Соберите 4 корректные Arduino-схемы.", "metric": "valid_schemes_total", "goal": 4, "reward": 138},
		{"id": "cosmetics_2", "category": "style", "title": "Первый тюнинг", "description": "Разблокируйте 2 косметических улучшения.", "metric": "cosmetics_unlocked_total", "goal": 2, "reward": 56},
		{"id": "cosmetics_8", "category": "style", "title": "Дизайн-бюро", "description": "Разблокируйте 8 косметических улучшений.", "metric": "cosmetics_unlocked_total", "goal": 8, "reward": 158},
		{"id": "styles_4", "category": "style_apply", "title": "Художник ангара", "description": "Примените 4 разных стиля к деталям.", "metric": "styles_applied_total", "goal": 4, "reward": 52},
		{"id": "perfect_3", "category": "mastery", "title": "Чистое прохождение", "description": "Получите 3 уровня с тремя звездами.", "metric": "perfect_levels_total", "goal": 3, "reward": 96},
		{"id": "refresh_3", "category": "quests", "title": "Новый контракт", "description": "Обновите список квестов 3 раза.", "metric": "quest_refreshes_total", "goal": 3, "reward": 62}
	]

func _get_default_cosmetic_profile() -> Dictionary:
	return {
		"parts": {},
		"effects": {
			"highlight": {"mode": "default", "unlock_id": "aura_default"},
			"trail": {"mode": "default", "unlock_id": "trail_default"}
		}
	}

func _ensure_quest_state() -> void:
	if quest_definitions.is_empty():
		quest_definitions = _build_quest_definitions()
	var valid_ids: Array[String] = []
	var normalized: Dictionary = {}
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_variant
		var quest_id: String = str(definition.get("id", ""))
		if quest_id.is_empty():
			continue
		valid_ids.append(quest_id)
		var state_variant: Variant = quest_progress.get(quest_id, {})
		var state: Dictionary = state_variant if typeof(state_variant) == TYPE_DICTIONARY else {}
		var goal: int = int(definition.get("goal", 0))
		var progress_value: int = maxi(int(state.get("progress", 0)), 0)
		normalized[quest_id] = {
			"progress": progress_value,
			"completed": bool(state.get("completed", progress_value >= goal or goal <= 0)),
			"claimed": bool(state.get("claimed", false))
		}
	quest_progress = normalized

	var normalized_active: Array[String] = []
	for quest_id_variant in active_quest_ids:
		if normalized_active.size() >= MAX_ACTIVE_QUESTS:
			break
		var quest_id: String = str(quest_id_variant)
		if quest_id.is_empty() or quest_id not in valid_ids or quest_id in normalized_active:
			continue
		var active_state_variant: Variant = quest_progress.get(quest_id, {})
		var active_state: Dictionary = active_state_variant if typeof(active_state_variant) == TYPE_DICTIONARY else {}
		if bool(active_state.get("claimed", false)):
			continue
		normalized_active.append(quest_id)
	active_quest_ids = normalized_active
	_fill_active_quests(false)

func _get_quest_definition_by_id(quest_id: String) -> Dictionary:
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("id", "")) == quest_id:
			return definition
	return {}

func _get_quest_category(definition: Dictionary) -> String:
	return str(definition.get("category", definition.get("metric", "generic")))

func _get_quest_candidate_ids(excluded_ids: Array[String] = []) -> Array[String]:
	var incomplete_ids: Array[String] = []
	var ready_ids: Array[String] = []
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_variant
		var quest_id: String = str(definition.get("id", ""))
		if quest_id.is_empty() or quest_id in excluded_ids:
			continue
		var state_variant: Variant = quest_progress.get(quest_id, {})
		var state: Dictionary = state_variant if typeof(state_variant) == TYPE_DICTIONARY else {}
		if bool(state.get("claimed", false)):
			continue
		if bool(state.get("completed", false)):
			ready_ids.append(quest_id)
		else:
			incomplete_ids.append(quest_id)
	return incomplete_ids + ready_ids

func _fill_active_quests(prefer_new_ids: bool) -> void:
	var excluded_ids: Array[String] = active_quest_ids.duplicate()
	var candidate_ids: Array[String] = []
	if prefer_new_ids:
		candidate_ids = _get_quest_candidate_ids(excluded_ids)
	else:
		candidate_ids = _get_quest_candidate_ids([])
	if candidate_ids.is_empty() and prefer_new_ids:
		candidate_ids = _get_quest_candidate_ids([])
	var missing_count: int = MAX_ACTIVE_QUESTS - active_quest_ids.size()
	if missing_count <= 0:
		return
	var picked_ids: Array[String] = _pick_diverse_quest_ids(candidate_ids, missing_count, active_quest_ids)
	for quest_id in picked_ids:
		if quest_id in active_quest_ids:
			continue
		active_quest_ids.append(quest_id)

func _all_active_quests_completed() -> bool:
	if active_quest_ids.size() < MAX_ACTIVE_QUESTS:
		return false
	for quest_id in active_quest_ids:
		var state_variant: Variant = quest_progress.get(quest_id, {})
		var state: Dictionary = state_variant if typeof(state_variant) == TYPE_DICTIONARY else {}
		if not bool(state.get("completed", false)):
			return false
	return true

func _replace_active_quest(quest_id: String) -> void:
	var quest_index: int = active_quest_ids.find(quest_id)
	if quest_index >= 0:
		active_quest_ids.remove_at(quest_index)
	_fill_active_quests(true)

func get_quest_refresh_cost() -> int:
	return QUEST_REFRESH_COST + quest_refresh_streak * QUEST_REFRESH_COST_STEP

func _pick_diverse_quest_ids(candidate_ids: Array[String], desired_count: int, existing_ids: Array[String] = []) -> Array[String]:
	var shuffled_ids: Array[String] = candidate_ids.duplicate()
	shuffled_ids.shuffle()

	var used_categories: Array[String] = []
	for existing_id in existing_ids:
		var existing_definition: Dictionary = _get_quest_definition_by_id(existing_id)
		if existing_definition.is_empty():
			continue
		var existing_category: String = _get_quest_category(existing_definition)
		if existing_category not in used_categories:
			used_categories.append(existing_category)

	var picked_ids: Array[String] = []
	for quest_id in shuffled_ids:
		if picked_ids.size() >= desired_count:
			break
		var definition: Dictionary = _get_quest_definition_by_id(quest_id)
		if definition.is_empty():
			continue
		var category: String = _get_quest_category(definition)
		if category in used_categories:
			continue
		used_categories.append(category)
		picked_ids.append(quest_id)

	for quest_id in shuffled_ids:
		if picked_ids.size() >= desired_count:
			break
		if quest_id in picked_ids:
			continue
		picked_ids.append(quest_id)

	return picked_ids

func _ensure_cosmetic_state() -> void:
	var unlocks: Array[String] = []
	for unlock_id in drone_cosmetic_unlocks:
		var normalized_id: String = str(unlock_id)
		if normalized_id.is_empty() or normalized_id in unlocks:
			continue
		unlocks.append(normalized_id)
	for default_unlock in DEFAULT_COSMETIC_UNLOCKS:
		if default_unlock not in unlocks:
			unlocks.append(default_unlock)
	drone_cosmetic_unlocks = unlocks

	if typeof(drone_cosmetic_profile) != TYPE_DICTIONARY or drone_cosmetic_profile.is_empty():
		drone_cosmetic_profile = _get_default_cosmetic_profile()

	var parts_variant: Variant = drone_cosmetic_profile.get("parts", {})
	if typeof(parts_variant) != TYPE_DICTIONARY:
		drone_cosmetic_profile["parts"] = {}

	var effects_variant: Variant = drone_cosmetic_profile.get("effects", {})
	if typeof(effects_variant) != TYPE_DICTIONARY:
		drone_cosmetic_profile["effects"] = {}

	var effects: Dictionary = drone_cosmetic_profile["effects"]
	if typeof(effects.get("highlight", {})) != TYPE_DICTIONARY:
		effects["highlight"] = {"mode": "default", "unlock_id": "aura_default"}
	if typeof(effects.get("trail", {})) != TYPE_DICTIONARY:
		effects["trail"] = {"mode": "default", "unlock_id": "trail_default"}
	drone_cosmetic_profile["effects"] = effects

func get_quest_definitions() -> Array:
	_ensure_quest_state()
	var result: Array = []
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		result.append((definition_variant as Dictionary).duplicate(true))
	return result

func get_quest_entries() -> Array:
	_ensure_quest_state()
	var entries: Array = []
	for quest_id in active_quest_ids:
		var definition: Dictionary = _get_quest_definition_by_id(quest_id)
		if definition.is_empty():
			continue
		var state_variant: Variant = quest_progress.get(quest_id, {})
		var state: Dictionary = state_variant if typeof(state_variant) == TYPE_DICTIONARY else {}
		var entry: Dictionary = definition.duplicate(true)
		entry["progress"] = int(state.get("progress", 0))
		entry["completed"] = bool(state.get("completed", false))
		entry["claimed"] = bool(state.get("claimed", false))
		entries.append(entry)
	return entries

func claim_quest_reward(quest_id: String) -> bool:
	_ensure_quest_state()
	if not quest_progress.has(quest_id):
		return false
	var state_variant: Variant = quest_progress.get(quest_id, {})
	var state: Dictionary = state_variant if typeof(state_variant) == TYPE_DICTIONARY else {}
	if not bool(state.get("completed", false)) or bool(state.get("claimed", false)):
		return false

	var definition: Dictionary = _get_quest_definition_by_id(quest_id)
	if definition.is_empty():
		return false

	state["claimed"] = true
	quest_progress[quest_id] = state
	add_crystals(int(definition.get("reward", 0)))
	claimed_quests_in_cycle += 1
	if claimed_quests_in_cycle >= MAX_ACTIVE_QUESTS:
		claimed_quests_in_cycle = 0
		quest_refresh_streak = 0
	_replace_active_quest(quest_id)
	save_game()
	quests_changed.emit()
	return true

func refresh_active_quests() -> bool:
	_ensure_quest_state()
	var refresh_cost: int = get_quest_refresh_cost()
	if not spend_score(refresh_cost):
		return false
	quest_refresh_streak += 1
	_update_quest_metric("quest_refreshes_total", 1, false)
	var previous_active: Array[String] = active_quest_ids.duplicate()
	active_quest_ids.clear()
	var candidate_ids: Array[String] = _get_quest_candidate_ids(previous_active)
	if candidate_ids.is_empty():
		candidate_ids = _get_quest_candidate_ids([])
	var next_ids: Array[String] = _pick_diverse_quest_ids(candidate_ids, MAX_ACTIVE_QUESTS)
	for quest_id in next_ids:
		active_quest_ids.append(quest_id)
	_fill_active_quests(false)
	save_game()
	quests_changed.emit()
	return true

func record_cells_flown(count: int) -> void:
	_update_quest_metric("cells_flown_total", maxi(count, 0), false)

func record_shop_purchase(_item_name: String, _cost: int) -> void:
	_update_quest_metric("shop_purchases_total", 1, true)

func record_valid_scheme(valid: bool) -> void:
	if valid:
		_update_quest_metric("valid_schemes_total", 1, true)

func record_level_completion_quests(level_number: int, stars: int, time_ms: int) -> void:
	var unique_completed: int = 0
	var best_stars_total: int = 0
	var perfect_levels_total: int = 0
	for level_key_variant in levels_data.keys():
		var level_key: String = str(level_key_variant)
		_normalize_level_data_entry(level_key)
		var level_data_entry: Dictionary = levels_data[level_key]
		if bool(level_data_entry.get("completed", false)):
			unique_completed += 1
		var level_stars: int = int(level_data_entry.get("stars", 0))
		best_stars_total += level_stars
		if level_stars >= 3:
			perfect_levels_total += 1
	_set_quest_metric("unique_levels_completed", unique_completed, true)
	_set_quest_metric("best_stars_total", best_stars_total, true)
	_set_quest_metric("perfect_levels_total", perfect_levels_total, true)
	if time_ms > 0 and time_ms <= int(round(float(get_level_ideal_time_ms(level_number)) * 1.55)):
		_update_quest_metric("fast_finishes_total", 1, true)

func record_level_attempt_quest() -> void:
	_update_quest_metric("route_attempts_total", 1, true)

func can_afford(cost: int) -> bool:
	return score >= maxi(cost, 0)

func can_afford_crystals(cost: int) -> bool:
	return crystals >= maxi(cost, 0)

func spend_score(amount: int) -> bool:
	var final_amount: int = maxi(amount, 0)
	if final_amount <= 0:
		return true
	if score < final_amount:
		return false
	score -= final_amount
	_update_quest_metric("coins_spent_total", final_amount, false)
	save_game()
	return true

func add_crystals(amount: int) -> void:
	var final_amount: int = maxi(amount, 0)
	if final_amount <= 0:
		return
	crystals += final_amount
	save_game()
	crystals_changed.emit(crystals)

func spend_crystals(amount: int) -> bool:
	var final_amount: int = maxi(amount, 0)
	if final_amount <= 0:
		return true
	if crystals < final_amount:
		return false
	crystals -= final_amount
	_update_quest_metric("crystals_spent_total", final_amount, false)
	save_game()
	crystals_changed.emit(crystals)
	return true

func get_customization_catalog() -> Dictionary:
	return {
		"colors": [
			{"id": "color_default", "label": "Стандарт", "cost": 0, "color": Color(1.0, 1.0, 1.0)},
			{"id": "color_sand", "label": "Песочный", "cost": 60, "color": Color(0.82, 0.67, 0.48)},
			{"id": "color_copper", "label": "Медный", "cost": 70, "color": Color(0.74, 0.48, 0.28)},
			{"id": "color_walnut", "label": "Орех", "cost": 70, "color": Color(0.46, 0.31, 0.22)},
			{"id": "color_graphite", "label": "Графит", "cost": 80, "color": Color(0.24, 0.25, 0.28)},
			{"id": "color_cream", "label": "Кремовый", "cost": 65, "color": Color(0.90, 0.86, 0.76)},
			{"id": "color_crimson", "label": "Кармин", "cost": 90, "color": Color(0.60, 0.22, 0.20)},
			{"id": "color_mint", "label": "Мята", "cost": 90, "color": Color(0.40, 0.70, 0.62)},
			{"id": "color_rgb_custom", "label": "Своя RGB-палитра", "cost": 160, "color": Color(0.86, 0.72, 0.56)}
		],
		"patterns": [
			{"id": "pattern_default", "label": "Без узора", "cost": 0, "pattern": "default", "primary": Color(1.0, 1.0, 1.0), "secondary": Color(0.76, 0.60, 0.42)},
			{"id": "pattern_carbon", "label": "Карбон", "cost": 150, "pattern": "carbon", "primary": Color(0.26, 0.26, 0.28), "secondary": Color(0.44, 0.34, 0.26)},
			{"id": "pattern_hex", "label": "Соты", "cost": 160, "pattern": "hex", "primary": Color(0.58, 0.44, 0.28), "secondary": Color(0.26, 0.19, 0.13)},
			{"id": "pattern_chevron", "label": "Шеврон", "cost": 170, "pattern": "chevron", "primary": Color(0.74, 0.57, 0.39), "secondary": Color(0.30, 0.21, 0.14)},
			{"id": "pattern_wave", "label": "Волны", "cost": 180, "pattern": "wave", "primary": Color(0.84, 0.70, 0.52), "secondary": Color(0.45, 0.29, 0.18)},
			{"id": "pattern_diamond", "label": "Ромбики", "cost": 190, "pattern": "diamond", "primary": Color(0.88, 0.76, 0.60), "secondary": Color(0.50, 0.34, 0.20)},
			{"id": "pattern_dots", "label": "Кружочки", "cost": 195, "pattern": "dots", "primary": Color(0.72, 0.58, 0.40), "secondary": Color(0.22, 0.16, 0.11)},
			{"id": "pattern_rings", "label": "Кольца", "cost": 205, "pattern": "rings", "primary": Color(0.87, 0.73, 0.54), "secondary": Color(0.34, 0.23, 0.15)}
		],
		"textures": [
			{"id": "texture_default", "label": "Стандарт", "cost": 0, "texture": "default", "primary": Color(1.0, 1.0, 1.0), "secondary": Color(0.94, 0.94, 0.94)},
			{"id": "texture_matte", "label": "Матовый металл", "cost": 180, "texture": "matte", "primary": Color(0.54, 0.52, 0.50), "secondary": Color(0.36, 0.34, 0.33)},
			{"id": "texture_bronze", "label": "Бронза", "cost": 210, "texture": "bronze", "primary": Color(0.63, 0.45, 0.28), "secondary": Color(0.34, 0.23, 0.15)},
			{"id": "texture_ceramic", "label": "Керамика", "cost": 220, "texture": "ceramic", "primary": Color(0.82, 0.80, 0.74), "secondary": Color(0.66, 0.64, 0.60)},
			{"id": "texture_varnish", "label": "Тёмный лак", "cost": 240, "texture": "varnish", "primary": Color(0.20, 0.16, 0.14), "secondary": Color(0.44, 0.30, 0.20)},
			{"id": "texture_metallic", "label": "Полированный металл", "cost": 260, "texture": "metallic", "primary": Color(0.72, 0.74, 0.78), "secondary": Color(0.34, 0.36, 0.40)},
			{"id": "texture_glow", "label": "Светящийся композит", "cost": 290, "texture": "glow", "primary": Color(0.84, 0.66, 0.32), "secondary": Color(0.25, 0.18, 0.10)},
			{"id": "texture_brushed", "label": "Шлифованный сплав", "cost": 275, "texture": "brushed", "primary": Color(0.68, 0.60, 0.52), "secondary": Color(0.38, 0.33, 0.28)}
		],
		"effects": [
			{"id": "aura_default", "label": "Базовая аура", "cost": 0, "effect_type": "highlight", "color": BASIC_HIGHLIGHT_COLOR},
			{"id": "aura_amber", "label": "Янтарная аура", "cost": 130, "effect_type": "highlight", "color": Color(0.95, 0.73, 0.36, 0.62)},
			{"id": "aura_mint", "label": "Мятная аура", "cost": 130, "effect_type": "highlight", "color": Color(0.46, 0.86, 0.74, 0.62)},
			{"id": "aura_crimson", "label": "Рубиновая аура", "cost": 140, "effect_type": "highlight", "color": Color(0.92, 0.42, 0.34, 0.62)},
			{"id": "trail_default", "label": "Базовый след", "cost": 0, "effect_type": "trail", "color": BASIC_TRAIL_COLOR},
			{"id": "trail_sand", "label": "Песчаный след", "cost": 120, "effect_type": "trail", "color": Color(0.82, 0.68, 0.42, 0.54)},
			{"id": "trail_copper", "label": "Медный след", "cost": 120, "effect_type": "trail", "color": Color(0.74, 0.45, 0.24, 0.56)},
			{"id": "trail_ice", "label": "Холодный след", "cost": 130, "effect_type": "trail", "color": Color(0.58, 0.76, 0.96, 0.56)}
		],
		"image_unlock": {"id": "custom_image_pass", "label": "Свое изображение", "cost": 450}
	}

func get_cosmetic_entry(unlock_id: String) -> Dictionary:
	var catalog: Dictionary = get_customization_catalog()
	for key_variant in catalog.keys():
		var key: String = str(key_variant)
		if key == "image_unlock":
			var single_entry: Dictionary = catalog[key]
			if str(single_entry.get("id", "")) == unlock_id:
				return single_entry.duplicate(true)
			continue
		var list: Array = catalog[key]
		for entry_variant in list:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			if str(entry.get("id", "")) == unlock_id:
				return entry.duplicate(true)
	return {}

func is_cosmetic_unlocked(unlock_id: String) -> bool:
	_ensure_cosmetic_state()
	return unlock_id in drone_cosmetic_unlocks

func unlock_cosmetic(unlock_id: String) -> bool:
	_ensure_cosmetic_state()
	if unlock_id in drone_cosmetic_unlocks:
		return true
	drone_cosmetic_unlocks.append(unlock_id)
	_set_quest_metric("cosmetics_unlocked_total", maxi(drone_cosmetic_unlocks.size() - DEFAULT_COSMETIC_UNLOCKS.size(), 0), true)
	save_game()
	cosmetic_inventory_changed.emit()
	return true

func get_drone_cosmetic_profile() -> Dictionary:
	_ensure_cosmetic_state()
	return drone_cosmetic_profile.duplicate(true)

func set_part_customization(part_id: String, style: Dictionary) -> void:
	_ensure_cosmetic_state()
	var next_style: Dictionary = style.duplicate(true)
	if not part_id.begins_with("effect:"):
		var mode_name: String = str(next_style.get("mode", "default"))
		if mode_name == "pattern" or mode_name == "texture":
			if not next_style.has("base_color"):
				next_style["base_color"] = get_part_base_color(part_id)
		elif mode_name == "color" and not next_style.has("base_color"):
			var next_unlock_id: String = str(next_style.get("unlock_id", ""))
			next_style["base_color"] = _resolve_style_base_color(next_style, get_cosmetic_entry(next_unlock_id))
	var previous_style: Dictionary = get_part_customization(part_id)
	var did_change: bool = previous_style != next_style
	if part_id.begins_with("effect:"):
		var effect_name: String = part_id.trim_prefix("effect:")
		var effects: Dictionary = drone_cosmetic_profile.get("effects", {})
		effects[effect_name] = next_style
		drone_cosmetic_profile["effects"] = effects
	else:
		var parts: Dictionary = drone_cosmetic_profile.get("parts", {})
		parts[part_id] = next_style
		drone_cosmetic_profile["parts"] = parts
	if did_change and str(next_style.get("mode", "default")) != "default":
		_update_quest_metric("styles_applied_total", 1, false)
	_sync_effect_colors_from_cosmetics()
	save_game()
	cosmetic_profile_changed.emit()

func reset_part_customization(part_id: String) -> void:
	_ensure_cosmetic_state()
	if part_id.begins_with("effect:"):
		var effect_name: String = part_id.trim_prefix("effect:")
		var effects: Dictionary = drone_cosmetic_profile.get("effects", {})
		effects[effect_name] = {"mode": "default", "unlock_id": "%s_default" % effect_name}
		drone_cosmetic_profile["effects"] = effects
	else:
		var parts: Dictionary = drone_cosmetic_profile.get("parts", {})
		parts.erase(part_id)
		drone_cosmetic_profile["parts"] = parts
	_sync_effect_colors_from_cosmetics()
	save_game()
	cosmetic_profile_changed.emit()

func get_part_customization(part_id: String) -> Dictionary:
	_ensure_cosmetic_state()
	if part_id.begins_with("effect:"):
		var effect_name: String = part_id.trim_prefix("effect:")
		var effects: Dictionary = drone_cosmetic_profile.get("effects", {})
		var effect_variant: Variant = effects.get(effect_name, {})
		return effect_variant if typeof(effect_variant) == TYPE_DICTIONARY else {}
	var parts: Dictionary = drone_cosmetic_profile.get("parts", {})
	var part_variant: Variant = parts.get(part_id, {})
	if typeof(part_variant) == TYPE_DICTIONARY:
		return part_variant
	if part_id.begins_with("motor_"):
		var grouped_motor_variant: Variant = parts.get("motors", {})
		return grouped_motor_variant if typeof(grouped_motor_variant) == TYPE_DICTIONARY else {}
	if part_id.begins_with("propeller_"):
		var grouped_prop_variant: Variant = parts.get("propellers", {})
		return grouped_prop_variant if typeof(grouped_prop_variant) == TYPE_DICTIONARY else {}
	return {}

func get_part_base_color(part_id: String) -> Color:
	var style: Dictionary = get_part_customization(part_id)
	var unlock_id: String = str(style.get("unlock_id", ""))
	return _resolve_style_base_color(style, get_cosmetic_entry(unlock_id))

func _resolve_style_base_color(style: Dictionary, entry: Dictionary) -> Color:
	var base_color_variant: Variant = style.get("base_color", null)
	if typeof(base_color_variant) == TYPE_COLOR:
		return base_color_variant

	var custom_color_variant: Variant = style.get("custom_color", null)
	if typeof(custom_color_variant) == TYPE_COLOR:
		return custom_color_variant

	var entry_color_variant: Variant = entry.get("color", entry.get("primary", Color(0.82, 0.67, 0.48)))
	if typeof(entry_color_variant) == TYPE_COLOR:
		return entry_color_variant
	return Color(0.82, 0.67, 0.48)

func import_custom_cosmetic_image(source_path: String, part_id: String) -> String:
	if source_path.is_empty():
		return ""
	var image: Image = Image.load_from_file(source_path)
	if image == null or image.is_empty():
		return ""
	var target_dir: String = ProjectSettings.globalize_path(CUSTOM_TEXTURES_DIR)
	DirAccess.make_dir_recursive_absolute(target_dir)
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var safe_part: String = part_id.replace(":", "_").replace("/", "_")
	var save_path: String = "%s/%s_%d.png" % [CUSTOM_TEXTURES_DIR, safe_part, Time.get_unix_time_from_system()]
	var save_error: int = image.save_png(ProjectSettings.globalize_path(save_path))
	if save_error != OK:
		return ""
	_cosmetic_texture_cache.erase(save_path)
	return save_path

func get_effect_color(effect_name: String) -> Color:
	_ensure_cosmetic_state()
	var effect_part_id: String = "effect:%s" % effect_name
	var style: Dictionary = get_part_customization(effect_part_id)
	var custom_color_variant: Variant = style.get("custom_color", null)
	if typeof(custom_color_variant) == TYPE_COLOR:
		return custom_color_variant
	var unlock_id: String = str(style.get("unlock_id", "%s_default" % effect_name))
	var entry: Dictionary = get_cosmetic_entry(unlock_id)
	if entry.is_empty():
		return BASIC_HIGHLIGHT_COLOR if effect_name == "highlight" else BASIC_TRAIL_COLOR
	return entry.get("color", BASIC_HIGHLIGHT_COLOR if effect_name == "highlight" else BASIC_TRAIL_COLOR)

func _sync_effect_colors_from_cosmetics() -> void:
	_highlight_color = get_effect_color("highlight")
	_trail_color = get_effect_color("trail")
	highlight_color_changed.emit(_highlight_color)
	trail_color_changed.emit(_trail_color)

func apply_customization_to_drone(frame: Node3D, board: Node3D, motor_nodes: Array, prop_nodes: Array) -> void:
	_apply_style_to_node(frame, get_part_customization("frame"))
	_apply_style_to_node(board, get_part_customization("board"))
	var grouped_motor_style: Dictionary = get_part_customization("motors")
	var grouped_prop_style: Dictionary = get_part_customization("propellers")
	for index in range(motor_nodes.size()):
		var motor: Node3D = motor_nodes[index] as Node3D
		if motor == null or not is_instance_valid(motor):
			continue
		var slot: int = int(motor.get_meta("motor_slot")) if motor.has_meta("motor_slot") else index
		_apply_style_to_node(motor, grouped_motor_style if not grouped_motor_style.is_empty() else get_part_customization("motor_%d" % slot))
	for index in range(prop_nodes.size()):
		var propeller: Node3D = prop_nodes[index] as Node3D
		if propeller == null or not is_instance_valid(propeller):
			continue
		var slot: int = int(propeller.get_meta("motor_slot")) if propeller.has_meta("motor_slot") else index
		_apply_style_to_node(propeller, grouped_prop_style if not grouped_prop_style.is_empty() else get_part_customization("propeller_%d" % slot))

func apply_customization_to_drone_root(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var tagged_roots: Array = []
	_collect_nodes_with_meta(root, "cosmetic_part_root", tagged_roots)
	for node_variant in tagged_roots:
		if not (node_variant is Node):
			continue
		var node: Node = node_variant
		var part_id: String = str(node.get_meta("cosmetic_part_root"))
		_apply_style_to_node(node, get_part_customization(part_id))

func _collect_nodes_with_meta(root: Node, meta_name: String, result: Array) -> void:
	if root == null:
		return
	if root.has_meta(meta_name):
		result.append(root)
	for child in root.get_children():
		_collect_nodes_with_meta(child, meta_name, result)

func _ensure_default_material_snapshot(mesh_node: MeshInstance3D) -> void:
	if mesh_node == null or not is_instance_valid(mesh_node):
		return
	if mesh_node.has_meta("cosmetic_default_material_captured"):
		return
	mesh_node.set_meta("cosmetic_default_material_captured", true)
	mesh_node.set_meta("cosmetic_default_material_override", mesh_node.material_override)

func _restore_default_material_snapshot(mesh_node: MeshInstance3D) -> void:
	if mesh_node == null or not is_instance_valid(mesh_node):
		return
	if mesh_node.has_meta("cosmetic_default_material_override"):
		mesh_node.material_override = mesh_node.get_meta("cosmetic_default_material_override") as Material
	else:
		mesh_node.material_override = null

func _apply_style_to_node(root: Node, style: Dictionary) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is MeshInstance3D:
		var mesh_node: MeshInstance3D = root as MeshInstance3D
		_ensure_default_material_snapshot(mesh_node)
		var material: Material = _build_cosmetic_material(style)
		if material == null:
			_restore_default_material_snapshot(mesh_node)
		else:
			mesh_node.material_override = material
	for child in root.get_children():
		_apply_style_to_node(child, style)

func _build_cosmetic_material(style: Dictionary) -> Material:
	if style.is_empty():
		return null
	var mode: String = str(style.get("mode", "default"))
	if mode == "default":
		return null

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.roughness = 0.62
	material.metallic = 0.16
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.uv1_scale = Vector3(3.0, 3.0, 1.0)

	var unlock_id: String = str(style.get("unlock_id", ""))
	var entry: Dictionary = get_cosmetic_entry(unlock_id)
	var base_color: Color = _resolve_style_base_color(style, entry)
	material.albedo_color = base_color

	if mode == "pattern" or mode == "texture":
		var texture: Texture2D = _build_cosmetic_texture(style, entry, base_color)
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
	elif mode == "image":
		var image_path: String = str(style.get("image_path", ""))
		var image_texture: Texture2D = _load_custom_image_texture(image_path)
		if image_texture != null:
			material.albedo_texture = image_texture
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	if mode == "texture":
		_apply_texture_finish(material, str(entry.get("texture", "default")), base_color)
	elif mode == "color" and style.has("custom_color"):
		material.roughness = 0.34
		material.metallic = 0.08

	return material

func _apply_texture_finish(material: StandardMaterial3D, texture_key: String, base_color: Color) -> void:
	match texture_key:
		"metallic":
			material.roughness = 0.14
			material.metallic = 0.92
			material.clearcoat_enabled = true
			material.clearcoat = 0.35
		"glow":
			material.roughness = 0.18
			material.metallic = 0.26
			material.emission_enabled = true
			material.emission = base_color.lightened(0.22)
			material.emission_energy_multiplier = 1.35
		"brushed":
			material.roughness = 0.28
			material.metallic = 0.58
		"bronze":
			material.roughness = 0.30
			material.metallic = 0.48
		"ceramic":
			material.roughness = 0.52
			material.metallic = 0.02
		"varnish":
			material.roughness = 0.20
			material.metallic = 0.06
			material.clearcoat_enabled = true
			material.clearcoat = 0.44
		_:
			material.roughness = 0.42
			material.metallic = 0.22

func _build_cosmetic_texture(style: Dictionary, entry: Dictionary, base_color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> Texture2D:
	var mode: String = str(style.get("mode", ""))
	var unlock_id: String = str(style.get("unlock_id", ""))
	var cache_key: String = "%s|%s|%s" % [mode, unlock_id, base_color.to_html(false)]
	if _cosmetic_texture_cache.has(cache_key):
		return _cosmetic_texture_cache[cache_key]

	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var primary: Color = base_color
	var entry_secondary_variant: Variant = entry.get("secondary", base_color.darkened(0.20))
	var entry_secondary: Color = entry_secondary_variant if typeof(entry_secondary_variant) == TYPE_COLOR else base_color.darkened(0.20)
	var secondary: Color = primary.darkened(0.22).lerp(entry_secondary, 0.18)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = primary
			if mode == "pattern":
				var pattern_key: String = str(entry.get("pattern", "carbon"))
				match pattern_key:
					"carbon":
						var carbon_band: bool = int((x + y) / 12) % 2 == 0
						var carbon_cross: bool = int((x - y + 256) / 18) % 2 == 0
						pixel = secondary if carbon_band else primary
						if carbon_cross:
							pixel = pixel.darkened(0.10)
					"hex":
						var local_x: int = x % 32
						var local_y: int = y % 28
						var border_hit: bool = abs(local_x - 16) > 11 or abs(local_y - 14) > 9
						pixel = secondary if border_hit else primary
					"chevron":
						pixel = secondary if int((x + y * 2) / 18) % 2 == 0 else primary
					"wave":
						var wave_value: float = sin(float(x) * 0.10) + cos(float(y) * 0.14)
						pixel = secondary if wave_value > 0.25 else primary
					"diamond":
						var diamond_size: int = 18
						var local_dx: int = abs((x % (diamond_size * 2)) - diamond_size)
						var local_dy: int = abs((y % (diamond_size * 2)) - diamond_size)
						pixel = secondary if (local_dx + local_dy) < int(diamond_size * 0.75) else primary
					"dots":
						var dot_grid: int = 30
						var local_dot_x: float = float((x % dot_grid) - dot_grid / 2)
						var local_dot_y: float = float((y % dot_grid) - dot_grid / 2)
						pixel = secondary if sqrt(local_dot_x * local_dot_x + local_dot_y * local_dot_y) < 7.5 else primary
					"rings":
						var ring_x: float = float(x - 128)
						var ring_y: float = float(y - 128)
						var ring_distance: float = sqrt(ring_x * ring_x + ring_y * ring_y)
						var ring_band: float = fposmod(ring_distance, 28.0)
						pixel = secondary if ring_band < 8.0 or ring_band > 20.0 else primary
					_:
						pixel = primary
			else:
				var texture_key: String = str(entry.get("texture", "matte"))
				match texture_key:
					"matte":
						var noise_value: float = float((x * 37 + y * 17) % 100) / 100.0
						pixel = primary.lerp(secondary, noise_value * 0.28)
					"bronze":
						var stripe: float = 0.5 + 0.5 * sin(float(x) * 0.18)
						pixel = primary.lerp(secondary, stripe * 0.42)
					"ceramic":
						var spot: bool = int((x / 24) + (y / 24)) % 2 == 0
						pixel = secondary.lightened(0.10) if spot else primary
					"varnish":
						var gloss: float = clampf(float(y) / 255.0, 0.0, 1.0)
						pixel = primary.lerp(secondary, gloss)
					"metallic":
						var metallic_wave: float = 0.5 + 0.5 * sin(float(x) * 0.24 + float(y) * 0.07)
						var metallic_sheen: float = 0.5 + 0.5 * cos(float(y) * 0.18)
						pixel = primary.lerp(secondary.lightened(0.18), metallic_wave * 0.55 + metallic_sheen * 0.20)
					"glow":
						var glow_core: float = 0.5 + 0.5 * sin(float(x + y) * 0.11)
						pixel = primary.lightened(glow_core * 0.16).lerp(secondary, 0.18)
					"brushed":
						var brushed_line: float = float((x * 53 + y * 7) % 100) / 100.0
						var brushed_mix: float = clampf(0.18 + brushed_line * 0.42, 0.0, 1.0)
						pixel = primary.lerp(secondary, brushed_mix)
					_:
						pixel = primary
			image.set_pixel(x, y, pixel)

	var texture: Texture2D = ImageTexture.create_from_image(image)
	_cosmetic_texture_cache[cache_key] = texture
	return texture

func _load_custom_image_texture(image_path: String) -> Texture2D:
	if image_path.is_empty():
		return null
	if _cosmetic_texture_cache.has(image_path):
		return _cosmetic_texture_cache[image_path]
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		return null
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_cosmetic_texture_cache[image_path] = texture
	return texture

func _set_quest_metric(metric: String, value: int, save_now: bool) -> void:
	_ensure_quest_state()
	var did_change: bool = false
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("metric", "")) != metric:
			continue
		var quest_id: String = str(definition.get("id", ""))
		var state: Dictionary = quest_progress.get(quest_id, {})
		var previous_progress: int = int(state.get("progress", 0))
		var goal: int = int(definition.get("goal", 0))
		var next_progress: int = clampi(value, 0, goal)
		if next_progress == previous_progress and bool(state.get("completed", false)) == (next_progress >= goal):
			continue
		state["progress"] = next_progress
		state["completed"] = next_progress >= goal
		quest_progress[quest_id] = state
		did_change = true
	if did_change:
		if _all_active_quests_completed():
			quest_refresh_streak = 0
			claimed_quests_in_cycle = 0
			save_now = true
		if save_now:
			save_game()
		quests_changed.emit()

func _update_quest_metric(metric: String, delta: int, save_now: bool) -> void:
	_ensure_quest_state()
	var did_change: bool = false
	var should_save: bool = save_now
	for definition_variant in quest_definitions:
		if typeof(definition_variant) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_variant
		if str(definition.get("metric", "")) != metric:
			continue
		var quest_id: String = str(definition.get("id", ""))
		var state: Dictionary = quest_progress.get(quest_id, {})
		var goal: int = int(definition.get("goal", 0))
		var previous_progress: int = int(state.get("progress", 0))
		var next_progress: int = clampi(previous_progress + delta, 0, goal)
		if next_progress == previous_progress and bool(state.get("completed", false)) == (next_progress >= goal):
			continue
		state["progress"] = next_progress
		state["completed"] = next_progress >= goal
		quest_progress[quest_id] = state
		if next_progress >= goal and previous_progress < goal:
			should_save = true
		did_change = true
	if did_change:
		if _all_active_quests_completed():
			quest_refresh_streak = 0
			claimed_quests_in_cycle = 0
			should_save = true
		if should_save:
			save_game()
		quests_changed.emit()

func _apply_viewport_render_scale():
	var tree: SceneTree = get_tree()
	var viewport: Viewport = tree.root if tree != null else null
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var resolution_quality_scale: float = _get_resolution_quality_scale(_get_current_screen_size())
	viewport.scaling_3d_scale = clampf(render_scale * resolution_quality_scale, 0.35, 1.3)

func _apply_audio_bus_volume_if_exists(bus_name: String, volume_percent: float):
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear_value := clampf(volume_percent / 100.0, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))
	AudioServer.set_bus_mute(bus_index, volume_percent <= 0.0)

func _save_json_dictionary(file_path: String, data: Dictionary):
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open file for writing: %s" % file_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _load_json_dictionary(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data

func _serialize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in (value as Dictionary).keys():
				result[str(key)] = _serialize_variant(value[key])
			return result
		TYPE_ARRAY:
			var array_result: Array = []
			for item in value:
				array_result.append(_serialize_variant(item))
			return array_result
		TYPE_PACKED_STRING_ARRAY:
			return Array(value)
		TYPE_VECTOR2:
			return {"__type": "Vector2", "x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"__type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"__type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_STRING_NAME:
			return str(value)
		_:
			return value

func _deserialize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			if source.has("__type"):
				match str(source["__type"]):
					"Vector2":
						return Vector2(float(source.get("x", 0.0)), float(source.get("y", 0.0)))
					"Vector3":
						return Vector3(float(source.get("x", 0.0)), float(source.get("y", 0.0)), float(source.get("z", 0.0)))
					"Color":
						return Color(
							float(source.get("r", 1.0)),
							float(source.get("g", 1.0)),
							float(source.get("b", 1.0)),
							float(source.get("a", 1.0))
						)
			var restored := {}
			for key in source.keys():
				restored[key] = _deserialize_variant(source[key])
			return restored
		TYPE_ARRAY:
			var restored_array: Array = []
			for item in value:
				restored_array.append(_deserialize_variant(item))
			return restored_array
		_:
			return value

func load_scene_with_loading(scene_path: String):
	print("🌐 Начинаем загрузку: ", scene_path)

	_hide_current_scene_for_loading()
	var screen: Control = show_loading_screen()
	await get_tree().process_frame
	await slow_progress_simulation(scene_path, screen)

func slow_progress_simulation(scene_path: String, screen: Control):
	var progress = 0.0
	
	while progress < 0.8:
		progress += 0.04
		screen.set_progress(progress)
		await get_tree().create_timer(0.15).timeout
	
	screen.set_progress(0.9)
	screen.update_loading_text("Завершение...")
	
	await get_tree().create_timer(0.5).timeout
	_direct_scene_load(scene_path)

func show_loading_screen() -> Control:
	if not loading_screen:
		var loading_scene: PackedScene = preload("res://app/ui/LoadingScreen.tscn")
		loading_screen = loading_scene.instantiate()
		get_tree().root.add_child(loading_screen)
		loading_screen.start_loading()
	return loading_screen

func hide_loading_screen():
	if loading_screen:
		loading_screen.queue_free()
		loading_screen = null

func _direct_scene_load(scene_path: String):
	print("🔄 Прямая загрузка сцены...")
	
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		print("❌ Файл не найден: ", scene_path)
		get_tree().change_scene_to_file("res://app/main_menu/main_scene.tscn")
	
	hide_loading_screen()

func _hide_current_scene_for_loading():
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	if current_scene is CanvasItem:
		var canvas_scene: CanvasItem = current_scene as CanvasItem
		canvas_scene.visible = false

func is_component_available(component_type: String, component_name: String) -> bool:
	if component_name.begins_with("Буст"):
		return true
	return component_name in purchased_items

func get_available_components(component_names: Array) -> Array:
	var available = []
	for name in component_names:
		if is_component_available("", name):
			available.append(name)
	return available

func initialize_levels_data():
	levels_data = {}
	for i in range(1, 16):
		levels_data[str(i)] = _create_default_level_data(i == 1)

func _create_default_level_data(unlocked: bool) -> Dictionary:
	return {
		"unlocked": unlocked,
		"completed": false,
		"best_steps": 0,
		"stars": 0,
		"best_time": 0,
		"attempt_count": 0,
		"completion_count": 0,
		"top_attempts": []
	}

func _normalize_level_data_entry(level_key: String) -> void:
	var level_index: int = int(level_key) if level_key.is_valid_int() else 1
	var entry_variant: Variant = levels_data.get(level_key, _create_default_level_data(level_index == 1))
	if typeof(entry_variant) != TYPE_DICTIONARY:
		levels_data[level_key] = _create_default_level_data(level_index == 1)
		return

	var entry: Dictionary = entry_variant
	var defaults: Dictionary = _create_default_level_data(bool(entry.get("unlocked", level_index == 1)))
	for key_variant in defaults.keys():
		var key: String = str(key_variant)
		if not entry.has(key):
			entry[key] = defaults[key]

	var normalized_top_attempts: Array = []
	for attempt_variant in entry.get("top_attempts", []):
		if typeof(attempt_variant) == TYPE_INT or typeof(attempt_variant) == TYPE_FLOAT:
			normalized_top_attempts.append(int(attempt_variant))
	normalized_top_attempts.sort()
	if normalized_top_attempts.size() > 5:
		normalized_top_attempts.resize(5)
	entry["top_attempts"] = normalized_top_attempts
	entry["attempt_count"] = int(entry.get("attempt_count", 0))
	entry["completion_count"] = int(entry.get("completion_count", 0))
	entry["best_time"] = int(entry.get("best_time", 0))
	entry["stars"] = int(entry.get("stars", 0))
	entry["completed"] = bool(entry.get("completed", false))
	entry["unlocked"] = bool(entry.get("unlocked", level_index == 1))
	levels_data[level_key] = entry

func calculate_stars(level: int, actual_time_ms: int) -> int:
	var ideal_time_ms: int = get_level_ideal_time_ms(level)
	if ideal_time_ms <= 0 or actual_time_ms <= 0:
		return 0

	var three_star_limit: int = int(round(float(ideal_time_ms) * 1.50))
	var two_star_limit: int = int(round(float(ideal_time_ms) * 2.15))
	var one_star_limit: int = int(round(float(ideal_time_ms) * 2.85))

	if actual_time_ms <= three_star_limit:
		return 3
	elif actual_time_ms <= two_star_limit:
		return 2
	elif actual_time_ms <= one_star_limit:
		return 1
	else:
		return 0

func get_level_ideal_command_count(level: int) -> int:
	if LEVEL_IDEAL_COMMANDS.has(level):
		return int(LEVEL_IDEAL_COMMANDS[level])
	return 0

func get_level_ideal_time_ms(level: int) -> int:
	var command_count: int = get_level_ideal_command_count(level)
	if command_count <= 0:
		return 0
	return command_count * LEVEL_IDEAL_COMMAND_DURATION_MS + LEVEL_IDEAL_SEQUENCE_OVERHEAD_MS

func calculate_level_reward(level: int, actual_time_ms: int, first_time: bool) -> Dictionary:
	var stars: int = calculate_stars(level, actual_time_ms)
	var ideal_command_count: int = get_level_ideal_command_count(level)
	var ideal_time_ms: int = get_level_ideal_time_ms(level)
	var safe_time_ms: int = maxi(actual_time_ms, 1)
	var time_ratio: float = clampf(float(ideal_time_ms) / float(safe_time_ms), 0.35, 2.25)
	var base_reward: int = int(round((55.0 + float(level) * 16.0 + float(ideal_command_count) * 6.0) * time_ratio))
	var bonus: int = int(round(float(base_reward) * (first_time_reward_multiplier - 1.0))) if first_time else 0
	var total_reward: int = maxi(base_reward + bonus, 0)

	return {
		"stars": stars,
		"reward": total_reward,
		"base_reward": base_reward,
		"bonus": bonus,
		"ideal_time_ms": ideal_time_ms,
		"time_ratio": time_ratio
	}

func complete_level(level_number: int, time_ms: int):
	var level_key = str(level_number)
	if level_key in levels_data:
		_normalize_level_data_entry(level_key)
		var was_completed = levels_data[level_key]["completed"]
		var previous_stars = levels_data[level_key].get("stars", 0)
		var previous_best_time = levels_data[level_key].get("best_time", 0)
		
		var result = calculate_level_reward(level_number, time_ms, not was_completed)
		var stars = result["stars"]
		var reward = result["reward"]
		
		var is_improvement = false
		if stars > previous_stars or (stars == previous_stars and time_ms < previous_best_time):
			levels_data[level_key]["best_time"] = time_ms
			levels_data[level_key]["stars"] = stars
			is_improvement = true
		
		levels_data[level_key]["completed"] = true
		
		if level_number < 15:
			var next_key = str(level_number + 1)
			levels_data[next_key]["unlocked"] = true
			if level_number + 1 > levels_unlocked:
				levels_unlocked = level_number + 1
		
		print("🎯 Условия начисления: был завершен=%s, улучшение=%s, звезды=%d, награда=%d" % [was_completed, is_improvement, stars, reward])
		
		if not was_completed or is_improvement:
			add_score(reward)
			print("🎉 Уровень %d: %d звезд, награда: %d очков" % [level_number, stars, reward])
		else:
			print("ℹ️ Уровень уже был пройден без улучшения, очки не начислены")
		
		record_level_completion_quests(level_number, stars, time_ms)
		save_levels_data()
		save_game()
		
		var tut := get_node_or_null("/root/tut")
		if tut != null:
			tut.notify("level_completed")
		return result
	return {"stars": 0, "reward": 0, "base_reward": 0, "bonus": 0}

func add_score(amount: int):
	score += amount
	if amount > 0:
		_update_quest_metric("coins_earned_total", amount, false)
	save_game()
	print("💰 Получено очков: ", amount, ". Всего: ", score)

func get_score() -> int:
	return score

func format_wallet_label(multiline: bool = false) -> String:
	if multiline:
		return "Монеты: %d\nКристаллы: %d" % [score, crystals]
	return "Монеты: %d   Кристаллы: %d" % [score, crystals]
	
func save_game():
	var config = ConfigFile.new()
	config.set_value("game", "score", score)
	config.set_value("game", "crystals", crystals)
	config.set_value("game", "purchased_items", purchased_items)
	config.set_value("game", "quest_progress", _serialize_variant(quest_progress))
	config.set_value("game", "active_quest_ids", Array(active_quest_ids))
	config.set_value("game", "quest_refresh_streak", quest_refresh_streak)
	config.set_value("game", "claimed_quests_in_cycle", claimed_quests_in_cycle)
	config.set_value("game", "drone_cosmetic_unlocks", Array(drone_cosmetic_unlocks))
	config.set_value("game", "drone_cosmetic_profile", _serialize_variant(drone_cosmetic_profile))
	config.save("user://game_save.cfg")
	print("💾 Игра сохранена. Очки: ", score)

func load_game():
	var config = ConfigFile.new()
	var error = config.load("user://game_save.cfg")
	if error == OK:
		score = config.get_value("game", "score", 100000)
		crystals = int(config.get_value("game", "crystals", 0))
		purchased_items = config.get_value("game", "purchased_items", DEFAULT_PURCHASED_ITEMS.duplicate())
		quest_refresh_streak = int(config.get_value("game", "quest_refresh_streak", 0))
		claimed_quests_in_cycle = int(config.get_value("game", "claimed_quests_in_cycle", 0))
		var quest_value: Variant = _deserialize_variant(config.get_value("game", "quest_progress", {}))
		quest_progress = quest_value if typeof(quest_value) == TYPE_DICTIONARY else {}
		active_quest_ids.clear()
		var active_quests_value: Variant = config.get_value("game", "active_quest_ids", [])
		if typeof(active_quests_value) == TYPE_ARRAY:
			for quest_id_variant in active_quests_value:
				active_quest_ids.append(str(quest_id_variant))
		var unlocks_variant: Variant = config.get_value("game", "drone_cosmetic_unlocks", DEFAULT_COSMETIC_UNLOCKS.duplicate())
		drone_cosmetic_unlocks.clear()
		if typeof(unlocks_variant) == TYPE_ARRAY:
			for unlock_id_variant in unlocks_variant:
				drone_cosmetic_unlocks.append(str(unlock_id_variant))
		var profile_value: Variant = _deserialize_variant(config.get_value("game", "drone_cosmetic_profile", _get_default_cosmetic_profile()))
		drone_cosmetic_profile = profile_value if typeof(profile_value) == TYPE_DICTIONARY else _get_default_cosmetic_profile()
		_ensure_quest_state()
		_ensure_cosmetic_state()
		print("📁 Игра загружена. Очки: ", score)
	else:
		print("📁 Игра не найдена, используются значения по умолчанию")
		purchased_items = DEFAULT_PURCHASED_ITEMS.duplicate()
		crystals = 0
		quest_progress = {}
		active_quest_ids.clear()
		quest_refresh_streak = 0
		claimed_quests_in_cycle = 0
		drone_cosmetic_unlocks = DEFAULT_COSMETIC_UNLOCKS.duplicate()
		drone_cosmetic_profile = _get_default_cosmetic_profile()
		_ensure_quest_state()
		_ensure_cosmetic_state()
		save_game()

func _ensure_default_purchased_items() -> void:
	var did_change: bool = false
	for item_name in DEFAULT_PURCHASED_ITEMS:
		if item_name in purchased_items:
			continue
		purchased_items.append(item_name)
		did_change = true
	if did_change:
		save_game()

func save_levels_data():
	var file = FileAccess.open("user://levels_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(levels_data))
		file.close()

func load_levels_data():
	var file = FileAccess.open("user://levels_data.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			levels_data = json.data
			for level in range(1, 16):
				_normalize_level_data_entry(str(level))
			levels_unlocked = 1
			for level in range(1, 16):
				if str(level) in levels_data and levels_data[str(level)]["unlocked"]:
					levels_unlocked = level
				else:
					break
		else:
			initialize_levels_data()
	else:
		initialize_levels_data()

func record_level_attempt(level_number: int, time_ms: int, completed: bool) -> void:
	var level_key: String = str(level_number)
	if not levels_data.has(level_key):
		levels_data[level_key] = _create_default_level_data(level_number == 1)
	_normalize_level_data_entry(level_key)

	var entry: Dictionary = levels_data[level_key]
	entry["attempt_count"] = int(entry.get("attempt_count", 0)) + 1

	if completed:
		entry["completion_count"] = int(entry.get("completion_count", 0)) + 1
		var top_attempts: Array = entry.get("top_attempts", [])
		top_attempts.append(maxi(time_ms, 0))
		top_attempts.sort()
		if top_attempts.size() > 5:
			top_attempts.resize(5)
		entry["top_attempts"] = top_attempts

		var current_best_time: int = int(entry.get("best_time", 0))
		if current_best_time <= 0 or (time_ms > 0 and time_ms < current_best_time):
			entry["best_time"] = time_ms

	levels_data[level_key] = entry
	save_levels_data()
	record_level_attempt_quest()

func get_level_statistics(level_number: int) -> Dictionary:
	var level_key: String = str(level_number)
	if not levels_data.has(level_key):
		return _create_default_level_data(level_number == 1)
	_normalize_level_data_entry(level_key)
	return (levels_data[level_key] as Dictionary).duplicate(true)

func is_level_unlocked(level_number: int) -> bool:
	return str(level_number) in levels_data and levels_data[str(level_number)]["unlocked"]

func get_level_data(level_number: int) -> Dictionary:
	var level_key = str(level_number)
	if level_key in levels_data:
		return levels_data[level_key].duplicate()
	return {}

func has_item(item_name: String) -> bool:
	return item_name in purchased_items

func get_purchased_items() -> Array:
	return purchased_items.duplicate()

func test_level_thresholds():
	print("=== ТЕСТИРОВАНИЕ ПОРОГОВ УРОВНЕЙ ===")
	for level in range(1, 16):
		if level_star_thresholds.has(level):
			var thresholds = level_star_thresholds[level]
			print("Уровень %d: 3★ - %s, 2★ - %s, 1★ - %s" % [
				level,
				format_test_time(thresholds[0]),
				format_test_time(thresholds[1]),
				format_test_time(thresholds[2])
			])

func format_test_time(ms: int) -> String:
	var seconds = ms / 1000.0
	return "%.1f сек" % seconds

func format_time_ms(milliseconds: int) -> String:
	var total_seconds = milliseconds / 1000
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	var ms = milliseconds % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, ms]
