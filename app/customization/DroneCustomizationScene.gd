extends Node3D

const CREATE_DRONE_SCENE_PATH := "res://app/assembly/create_dron.tscn"
const PREVIEW_DRONE_PATHS: Array[String] = [
	"user://exported_drone.tscn",
	"res://exported_drone.tscn"
]
const SLOT_NAMES: Array[String] = ["Передний правый", "Передний левый", "Задний правый", "Задний левый"]

@onready var preview_root: Node3D = $PreviewRoot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var ui_layer: CanvasLayer = $UI

var preview_drone: Node3D = null
var selected_part_id: String = "frame"
var selected_mode: String = "color"
var selected_unlock_id: String = "color_default"
var selected_image_source: String = ""

var header_panel: Panel = null
var wallet_label: Label = null
var part_option: OptionButton = null
var mode_row: HBoxContainer = null
var options_scroll: ScrollContainer = null
var options_grid: GridContainer = null
var description_label: Label = null
var custom_color_box: VBoxContainer = null
var custom_color_picker: ColorPickerButton = null
var status_label: Label = null
var choose_image_button: Button = null
var apply_button: Button = null
var reset_button: Button = null
var file_dialog: FileDialog = null
var custom_color_preview: Color = Color(0.82, 0.67, 0.48, 1.0)

var part_ids: Array[String] = []
var part_labels: Dictionary = {}
var mode_buttons: Dictionary = {}
var preview_scene_closing: bool = false

func _ready() -> void:
	preview_scene_closing = false
	_build_stage()
	_build_ui()
	_load_preview_drone()
	_rebuild_part_selector()
	_refresh_wallet_display()
	_refresh_mode_buttons()
	_refresh_options()
	if Global != null:
		if not Global.crystals_changed.is_connected(_on_crystals_changed):
			Global.crystals_changed.connect(_on_crystals_changed)
		if not Global.cosmetic_inventory_changed.is_connected(_on_cosmetic_inventory_changed):
			Global.cosmetic_inventory_changed.connect(_on_cosmetic_inventory_changed)
		if not Global.cosmetic_profile_changed.is_connected(_on_cosmetic_profile_changed):
			Global.cosmetic_profile_changed.connect(_on_cosmetic_profile_changed)

func _exit_tree() -> void:
	preview_scene_closing = true

func _process(delta: float) -> void:
	if preview_drone != null and is_instance_valid(preview_drone):
		preview_drone.rotate_y(delta * 0.18)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_event: InputEventMouseButton = event
		var picked_part_id: String = _pick_part_at_screen_position(mouse_event.position)
		if not picked_part_id.is_empty():
			_select_part(picked_part_id)

func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.24, 0.19, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.50, 0.42)
	environment.ambient_light_energy = 1.28
	environment.glow_enabled = true
	environment.glow_strength = 0.08
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.08
	environment.adjustment_contrast = 1.06
	$WorldEnvironment.environment = environment

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(28.0, 0.6, 28.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.5, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.14, 0.10, 0.07)
	floor_material.roughness = 0.96
	floor.material_override = floor_material
	add_child(floor)

	var accent_plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(20.0, 20.0)
	accent_plane.mesh = plane_mesh
	accent_plane.rotation_degrees.x = -90.0
	accent_plane.position = Vector3(0.0, -0.14, 0.0)
	var accent_material := StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.22, 0.16, 0.12, 0.95)
	accent_material.emission_enabled = true
	accent_material.emission = Color(0.72, 0.54, 0.32) * 0.08
	accent_material.roughness = 0.88
	accent_plane.material_override = accent_material
	add_child(accent_plane)

	var main_light := DirectionalLight3D.new()
	main_light.rotation_degrees = Vector3(-48.0, -24.0, 0.0)
	main_light.light_color = Color(1.0, 0.91, 0.79)
	main_light.light_energy = 1.56
	main_light.shadow_enabled = true
	add_child(main_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 7.6, 5.0)
	fill_light.light_color = Color(0.94, 0.76, 0.58)
	fill_light.light_energy = 1.06
	fill_light.omni_range = 28.0
	add_child(fill_light)

	var rim_light := SpotLight3D.new()
	rim_light.position = Vector3(-7.0, 6.0, -6.0)
	rim_light.light_color = Color(0.88, 0.66, 0.42)
	rim_light.light_energy = 1.42
	rim_light.spot_range = 26.0
	rim_light.spot_angle = 38.0
	add_child(rim_light)
	rim_light.look_at_from_position(rim_light.position, Vector3.ZERO, Vector3.UP)

	camera.near = 0.05
	camera.far = 120.0
	camera.fov = 54.0
	camera_pivot.position = Vector3.ZERO
	camera.position = Vector3(9.0, 5.6, 9.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_layer.add_child(root)

	header_panel = Panel.new()
	header_panel.anchor_left = 0.0
	header_panel.anchor_right = 1.0
	header_panel.anchor_top = 0.0
	header_panel.anchor_bottom = 0.0
	header_panel.offset_left = 24.0
	header_panel.offset_top = 20.0
	header_panel.offset_right = -24.0
	header_panel.offset_bottom = 112.0
	header_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.16, 0.11, 0.08, 0.92), Color(0.80, 0.62, 0.40, 0.84), 24))
	root.add_child(header_panel)

	var header_margin := MarginContainer.new()
	header_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_margin.add_theme_constant_override("margin_left", 22)
	header_margin.add_theme_constant_override("margin_top", 14)
	header_margin.add_theme_constant_override("margin_right", 22)
	header_margin.add_theme_constant_override("margin_bottom", 14)
	header_panel.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header_margin.add_child(header_row)

	var back_button := Button.new()
	back_button.text = "Назад к сборке"
	back_button.custom_minimum_size = Vector2(220, 52)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(_on_back_pressed)
	_style_button(back_button, Color(0.29, 0.20, 0.14, 0.98), Color(0.76, 0.59, 0.39, 0.92))
	header_row.add_child(back_button)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	header_row.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "Кастомизация дрона"
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	title_box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Кликните по детали на превью или выберите ее справа, затем примените стиль за кристаллы."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.79, 0.68))
	title_box.add_child(subtitle_label)

	wallet_label = Label.new()
	wallet_label.custom_minimum_size = Vector2(360, 58)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet_label.add_theme_font_size_override("font_size", 24)
	wallet_label.add_theme_color_override("font_color", Color(0.97, 0.90, 0.82))
	header_row.add_child(wallet_label)

	var side_panel := Panel.new()
	side_panel.anchor_left = 1.0
	side_panel.anchor_right = 1.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = -560.0
	side_panel.offset_top = 124.0
	side_panel.offset_right = -24.0
	side_panel.offset_bottom = -24.0
	side_panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.15, 0.10, 0.07, 0.94), Color(0.74, 0.57, 0.37, 0.78), 28))
	root.add_child(side_panel)

	var side_margin := MarginContainer.new()
	side_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_margin.add_theme_constant_override("margin_left", 22)
	side_margin.add_theme_constant_override("margin_top", 20)
	side_margin.add_theme_constant_override("margin_right", 22)
	side_margin.add_theme_constant_override("margin_bottom", 20)
	side_panel.add_child(side_margin)

	var side_root := VBoxContainer.new()
	side_root.add_theme_constant_override("separation", 16)
	side_margin.add_child(side_root)

	var part_title := Label.new()
	part_title.text = "Деталь"
	part_title.add_theme_font_size_override("font_size", 20)
	part_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.80))
	side_root.add_child(part_title)

	part_option = OptionButton.new()
	part_option.custom_minimum_size = Vector2(0, 52)
	part_option.item_selected.connect(_on_part_selected)
	_style_option_button(part_option)
	side_root.add_child(part_option)

	mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	side_root.add_child(mode_row)

	options_scroll = ScrollContainer.new()
	options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_scroll.follow_focus = true
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.clip_contents = true
	side_root.add_child(options_scroll)

	options_grid = GridContainer.new()
	options_grid.columns = 1
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_grid.add_theme_constant_override("h_separation", 12)
	options_grid.add_theme_constant_override("v_separation", 12)
	options_scroll.add_child(options_grid)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 18)
	description_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.68))
	side_root.add_child(description_label)

	custom_color_box = VBoxContainer.new()
	custom_color_box.visible = false
	custom_color_box.add_theme_constant_override("separation", 8)
	side_root.add_child(custom_color_box)

	var custom_color_title := Label.new()
	custom_color_title.text = "RGB-палитра"
	custom_color_title.add_theme_font_size_override("font_size", 18)
	custom_color_title.add_theme_color_override("font_color", Color(0.94, 0.86, 0.78))
	custom_color_box.add_child(custom_color_title)

	custom_color_picker = ColorPickerButton.new()
	custom_color_picker.text = "Выбрать свой цвет"
	custom_color_picker.custom_minimum_size = Vector2(0, 48)
	custom_color_picker.edit_alpha = false
	custom_color_picker.color = custom_color_preview
	custom_color_picker.focus_mode = Control.FOCUS_NONE
	custom_color_picker.color_changed.connect(_on_custom_color_changed)
	_style_button(custom_color_picker, Color(0.29, 0.21, 0.14, 0.98), Color(0.76, 0.60, 0.40, 0.88))
	custom_color_box.add_child(custom_color_picker)

	choose_image_button = Button.new()
	choose_image_button.text = "Выбрать PNG/JPEG"
	choose_image_button.custom_minimum_size = Vector2(0, 48)
	choose_image_button.focus_mode = Control.FOCUS_NONE
	choose_image_button.pressed.connect(_on_choose_image_pressed)
	_style_button(choose_image_button, Color(0.29, 0.21, 0.14, 0.98), Color(0.74, 0.58, 0.38, 0.88))
	side_root.add_child(choose_image_button)

	apply_button = Button.new()
	apply_button.text = "Применить"
	apply_button.custom_minimum_size = Vector2(0, 56)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(_on_apply_pressed)
	_style_button(apply_button, Color(0.42, 0.28, 0.17, 0.98), Color(0.91, 0.72, 0.46, 0.94))
	side_root.add_child(apply_button)

	reset_button = Button.new()
	reset_button.text = "Вернуть стандарт"
	reset_button.custom_minimum_size = Vector2(0, 52)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_on_reset_pressed)
	_style_button(reset_button, Color(0.25, 0.18, 0.12, 0.98), Color(0.68, 0.52, 0.34, 0.84))
	side_root.add_child(reset_button)

	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0, 68)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.80))
	side_root.add_child(status_label)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPEG", "*.jpeg ; JPEG"])
	file_dialog.file_selected.connect(_on_image_selected)
	ui_layer.add_child(file_dialog)

func _rebuild_part_selector() -> void:
	part_option.clear()
	part_ids.clear()
	part_labels.clear()

	_register_part_option("frame", "Рама")
	_register_part_option("board", "Плата")

	var profile: Dictionary = Global.load_exported_drone_profile() if Global != null else {}
	for motor_variant in profile.get("motors", []):
		if typeof(motor_variant) != TYPE_DICTIONARY:
			continue
		var motor_data: Dictionary = motor_variant
		var slot: int = clampi(int(motor_data.get("slot", part_ids.size())), 0, SLOT_NAMES.size() - 1)
		_register_part_option("motor_%d" % slot, "%s: мотор" % SLOT_NAMES[slot])

	for prop_variant in profile.get("propellers", []):
		if typeof(prop_variant) != TYPE_DICTIONARY:
			continue
		var prop_data: Dictionary = prop_variant
		var slot: int = clampi(int(prop_data.get("slot", part_ids.size())), 0, SLOT_NAMES.size() - 1)
		_register_part_option("propeller_%d" % slot, "%s: пропеллер" % SLOT_NAMES[slot])

	for preview_part_id in _get_preview_part_ids():
		if preview_part_id in part_ids:
			continue
		_register_part_option(preview_part_id, _label_for_part_id(preview_part_id))

	_register_part_option("effect:highlight", "Аура клетки")
	_register_part_option("effect:trail", "След движения")

	var selected_index: int = maxi(part_ids.find(selected_part_id), 0)
	part_option.select(selected_index)
	selected_part_id = part_ids[selected_index]

func _register_part_option(part_id: String, label: String) -> void:
	if part_id in part_ids:
		return
	part_ids.append(part_id)
	part_labels[part_id] = label
	part_option.add_item(label)

func _get_preview_part_ids() -> Array[String]:
	var result: Array[String] = []
	if preview_drone == null or not is_instance_valid(preview_drone):
		return result
	var tagged_nodes: Array = []
	_collect_nodes_with_meta(preview_drone, "cosmetic_part_root", tagged_nodes)
	for node_variant in tagged_nodes:
		if not (node_variant is Node):
			continue
		var part_id: String = str((node_variant as Node).get_meta("cosmetic_part_root"))
		if part_id.is_empty() or part_id in result:
			continue
		result.append(part_id)
	return result

func _refresh_wallet() -> void:
	if wallet_label != null and Global != null:
		wallet_label.text = "Кристаллы: %d" % Global.crystals

func _refresh_mode_buttons() -> void:
	for child in mode_row.get_children():
		child.queue_free()
	mode_buttons.clear()

	var modes: Array[String] = []
	if selected_part_id.begins_with("effect:"):
		modes = ["effect"]
	else:
		modes = ["color", "pattern", "texture", "image"]
	if selected_mode not in modes:
		selected_mode = modes[0]

	for mode_name in modes:
		var button := Button.new()
		button.text = _mode_label(mode_name)
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_mode_pressed.bind(mode_name))
		mode_row.add_child(button)
		mode_buttons[mode_name] = button

	for mode_name_variant in mode_buttons.keys():
		var mode_name_key: String = str(mode_name_variant)
		var mode_button: Button = mode_buttons[mode_name_key]
		if mode_name_key == selected_mode:
			_style_button(mode_button, Color(0.40, 0.28, 0.18, 0.98), Color(0.90, 0.72, 0.46, 0.94))
		else:
			_style_button(mode_button, Color(0.23, 0.17, 0.12, 0.98), Color(0.62, 0.48, 0.32, 0.72))

func _refresh_options() -> void:
	for child in options_grid.get_children():
		child.queue_free()

	var options: Array = _get_options_for_current_mode()
	options_grid.columns = 1 if options.size() <= 1 or selected_mode == "image" else 2
	var current_unlock_id: String = _get_current_unlock_for_part()
	var option_ids: Array[String] = []
	for option_variant in options:
		if typeof(option_variant) != TYPE_DICTIONARY:
			continue
		option_ids.append(str((option_variant as Dictionary).get("id", "")))
	if selected_unlock_id.is_empty() or selected_unlock_id not in option_ids:
		selected_unlock_id = current_unlock_id if current_unlock_id in option_ids else _default_unlock_for_mode()
	for option_variant in options:
		if typeof(option_variant) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_variant
		options_grid.add_child(_build_option_button(option))

	_sync_custom_color_from_selection()
	_refresh_custom_color_box()
	choose_image_button.visible = selected_mode == "image"
	choose_image_button.disabled = selected_mode == "image" and not Global.is_cosmetic_unlocked("custom_image_pass")
	if selected_mode == "image" and selected_image_source.is_empty():
		description_label.text = "Откройте пропуск на свое изображение, затем выберите PNG или JPEG и примените его к выбранной детали."
	else:
		description_label.text = _describe_selected_option_modern()
	_refresh_apply_button_modern()

func _get_options_for_current_mode() -> Array:
	var catalog: Dictionary = Global.get_customization_catalog()
	if selected_mode == "effect":
		var effect_key: String = "highlight" if selected_part_id == "effect:highlight" else "trail"
		var filtered: Array = []
		for entry_variant in catalog.get("effects", []):
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_variant
			if str(entry.get("effect_type", "")) == effect_key:
				filtered.append(entry)
		return filtered
	if selected_mode == "image":
		return [catalog.get("image_unlock", {})]
	return catalog.get("%ss" % selected_mode, [])

func _build_option_button(option: Dictionary) -> Button:
	var button := Button.new()
	var unlock_id: String = str(option.get("id", ""))
	var is_owned: bool = Global.is_cosmetic_unlocked(unlock_id)
	var cost: int = int(option.get("cost", 0))
	var label: String = str(option.get("label", unlock_id))
	var suffix: String = "Уже открыто" if is_owned or cost <= 0 else "%d крист." % cost
	button.text = ""
	button.custom_minimum_size = Vector2(196, 196)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	button.pressed.connect(_on_option_pressed.bind(unlock_id))
	if unlock_id == selected_unlock_id:
		_style_button(button, Color(0.42, 0.29, 0.18, 0.98), Color(0.92, 0.73, 0.46, 0.94))
	else:
		_style_button(button, Color(0.24, 0.17, 0.12, 0.98), Color(0.64, 0.49, 0.33, 0.74))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var preview_center := CenterContainer.new()
	preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview_center)
	preview_center.add_child(_build_option_preview(option))

	var title_label := Label.new()
	title_label.text = label
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	content.add_child(title_label)

	var info_label := Label.new()
	info_label.text = suffix
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(0.87, 0.77, 0.66))
	content.add_child(info_label)
	return button

func _build_option_preview(option: Dictionary) -> Control:
	var preview_shell := Panel.new()
	preview_shell.custom_minimum_size = Vector2(120, 120)
	preview_shell.size = Vector2(120, 120)
	preview_shell.clip_contents = true
	preview_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shell.add_theme_stylebox_override("panel", _build_panel_style(
		Color(0.20, 0.14, 0.10, 0.98),
		Color(0.72, 0.56, 0.36, 0.72),
		20
	))

	var preview_fill := Panel.new()
	preview_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_fill.offset_left = 8.0
	preview_fill.offset_top = 8.0
	preview_fill.offset_right = -8.0
	preview_fill.offset_bottom = -8.0
	preview_fill.clip_contents = true
	preview_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shell.add_child(preview_fill)

	var fill_style := StyleBoxFlat.new()
	fill_style.corner_radius_top_left = 16
	fill_style.corner_radius_top_right = 16
	fill_style.corner_radius_bottom_left = 16
	fill_style.corner_radius_bottom_right = 16
	fill_style.bg_color = Color(0.30, 0.22, 0.15, 1.0)
	preview_fill.add_theme_stylebox_override("panel", fill_style)

	var unlock_id: String = str(option.get("id", ""))
	if selected_mode == "color":
		var preview_color_variant: Variant = option.get("color", Color(0.82, 0.67, 0.48))
		var preview_color: Color = preview_color_variant if typeof(preview_color_variant) == TYPE_COLOR else Color(0.82, 0.67, 0.48)
		if unlock_id == "color_rgb_custom":
			preview_color = custom_color_preview
		fill_style.bg_color = preview_color
	elif selected_mode == "effect":
		var effect_color_variant: Variant = option.get("color", Global.highlight_color)
		var effect_color: Color = effect_color_variant if typeof(effect_color_variant) == TYPE_COLOR else Global.highlight_color
		fill_style.bg_color = effect_color
		fill_style.border_width_left = 2
		fill_style.border_width_top = 2
		fill_style.border_width_right = 2
		fill_style.border_width_bottom = 2
		fill_style.border_color = effect_color.lightened(0.18)
	else:
		var preview_texture := TextureRect.new()
		preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_texture.stretch_mode = TextureRect.STRETCH_SCALE
		preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_fill.add_child(preview_texture)
		if selected_mode == "pattern" or selected_mode == "texture":
			var base_color: Color = Global.get_part_base_color(selected_part_id)
			var preview_style: Dictionary = {
				"mode": selected_mode,
				"unlock_id": unlock_id,
				"base_color": base_color
			}
			var texture: Texture2D = Global._build_cosmetic_texture(preview_style, option, base_color)
			preview_texture.texture = texture
		else:
			var icon_label := Label.new()
			icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_label.text = "PNG"
			icon_label.add_theme_font_size_override("font_size", 24)
			icon_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.82))
			icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_fill.add_child(icon_label)

	return preview_shell

func _describe_selected_option() -> String:
	var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
	if entry.is_empty():
		return "Стандартный стиль без дополнительной оплаты."
	var cost: int = int(entry.get("cost", 0))
	var cost_text: String = "Уже открыто" if Global.is_cosmetic_unlocked(selected_unlock_id) or cost <= 0 else "Цена: %d крист." % cost
	return "%s\n%s" % [str(entry.get("label", "Стиль")), cost_text]

func _refresh_apply_button() -> void:
	if selected_mode == "image":
		var has_pass: bool = Global.is_cosmetic_unlocked("custom_image_pass")
		var entry: Dictionary = Global.get_cosmetic_entry("custom_image_pass")
		if not has_pass:
			apply_button.text = "Купить пропуск (%d крист.)" % int(entry.get("cost", 0))
			apply_button.disabled = false
			return
		if selected_image_source.is_empty():
			apply_button.text = "Сначала выберите файл"
			apply_button.disabled = true
			return
		apply_button.text = "Применить изображение"
		apply_button.disabled = false
		return

	var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
	var owned: bool = Global.is_cosmetic_unlocked(selected_unlock_id)
	var cost: int = int(entry.get("cost", 0))
	apply_button.text = "Применить" if owned or cost <= 0 else "Купить и применить (%d крист.)" % cost
	apply_button.disabled = false

func _describe_selected_option_modern() -> String:
	var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
	if entry.is_empty():
		return "Стандартный стиль без дополнительной оплаты."
	var cost: int = int(entry.get("cost", 0))
	var cost_text: String = "Уже открыто" if Global.is_cosmetic_unlocked(selected_unlock_id) or cost <= 0 else "Цена: %d крист." % cost
	if selected_unlock_id == "color_rgb_custom":
		return "%s\n%s\nRGB: #%s" % [str(entry.get("label", "Стиль")), cost_text, custom_color_preview.to_html(false).to_upper()]
	return "%s\n%s" % [str(entry.get("label", "Стиль")), cost_text]

func _refresh_apply_button_modern() -> void:
	if selected_mode == "image":
		var has_pass: bool = Global.is_cosmetic_unlocked("custom_image_pass")
		var image_entry: Dictionary = Global.get_cosmetic_entry("custom_image_pass")
		if not has_pass:
			apply_button.text = "Купить пропуск (%d крист.)" % int(image_entry.get("cost", 0))
			apply_button.disabled = false
			return
		if selected_image_source.is_empty():
			apply_button.text = "Сначала выберите файл"
			apply_button.disabled = true
			return
		apply_button.text = "Применить изображение"
		apply_button.disabled = false
		return

	var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
	var owned: bool = Global.is_cosmetic_unlocked(selected_unlock_id)
	var cost: int = int(entry.get("cost", 0))
	if selected_unlock_id == "color_rgb_custom":
		apply_button.text = "Применить RGB-цвет" if owned or cost <= 0 else "Купить RGB-палитру и применить (%d крист.)" % cost
	else:
		apply_button.text = "Применить" if owned or cost <= 0 else "Купить и применить (%d крист.)" % cost
	apply_button.disabled = false

func _sync_custom_color_from_selection() -> void:
	var style: Dictionary = Global.get_part_customization(selected_part_id)
	var style_unlock_id: String = str(style.get("unlock_id", ""))
	var custom_color_variant: Variant = style.get("custom_color", null)
	if selected_unlock_id == "color_rgb_custom" and style_unlock_id == "color_rgb_custom" and typeof(custom_color_variant) == TYPE_COLOR:
		custom_color_preview = custom_color_variant
		return
	var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
	var entry_color_variant: Variant = entry.get("color", Color(0.82, 0.67, 0.48, 1.0))
	custom_color_preview = entry_color_variant if typeof(entry_color_variant) == TYPE_COLOR else Color(0.82, 0.67, 0.48, 1.0)

func _refresh_wallet_display() -> void:
	if wallet_label != null and Global != null:
		wallet_label.text = Global.format_wallet_label(true)

func _refresh_custom_color_box() -> void:
	if custom_color_box == null or custom_color_picker == null:
		return
	var should_show: bool = selected_mode == "color" and selected_unlock_id == "color_rgb_custom"
	custom_color_box.visible = should_show
	if not should_show:
		return
	custom_color_picker.color = custom_color_preview
	custom_color_picker.text = "RGB #%s" % custom_color_preview.to_html(false).to_upper()

func _on_custom_color_changed(color: Color) -> void:
	custom_color_preview = Color(color.r, color.g, color.b, 1.0)
	if custom_color_picker != null:
		custom_color_picker.text = "RGB #%s" % custom_color_preview.to_html(false).to_upper()
	description_label.text = _describe_selected_option_modern()
	_refresh_apply_button_modern()

func _get_current_unlock_for_part() -> String:
	var style: Dictionary = Global.get_part_customization(selected_part_id)
	if style.is_empty():
		return _default_unlock_for_mode()
	return str(style.get("unlock_id", _default_unlock_for_mode()))

func _default_unlock_for_mode() -> String:
	match selected_mode:
		"color":
			return "color_default"
		"pattern":
			return "pattern_default"
		"texture":
			return "texture_default"
		"image":
			return "custom_image_pass"
		"effect":
			return "aura_default" if selected_part_id == "effect:highlight" else "trail_default"
		_:
			return "color_default"

func _apply_to_preview() -> void:
	if preview_drone == null or not is_instance_valid(preview_drone):
		return
	Global.apply_customization_to_drone_root(preview_drone)

func _freeze_preview_node_tree(root: Node) -> void:
	if root == null:
		return
	root.process_mode = Node.PROCESS_MODE_DISABLED
	root.set_process(false)
	root.set_physics_process(false)
	root.set_process_input(false)
	root.set_process_unhandled_input(false)
	root.set_process_unhandled_key_input(false)
	if root.get_script() != null:
		root.set_script(null)
	if root is CollisionObject3D:
		var collision_object: CollisionObject3D = root as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if root is RigidBody3D:
		var rigid_body: RigidBody3D = root as RigidBody3D
		rigid_body.freeze = true
		rigid_body.linear_velocity = Vector3.ZERO
		rigid_body.angular_velocity = Vector3.ZERO
	if root is GPUParticles3D:
		(root as GPUParticles3D).emitting = false
	if root is CPUParticles3D:
		(root as CPUParticles3D).emitting = false
	for child in root.get_children():
		_freeze_preview_node_tree(child)

func _load_preview_drone() -> void:
	for child in preview_root.get_children():
		child.queue_free()

	preview_drone = null
	for scene_path in PREVIEW_DRONE_PATHS:
		if not ResourceLoader.exists(scene_path):
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		if instance is Node3D:
			preview_drone = instance as Node3D
			_freeze_preview_node_tree(preview_drone)
			break

	if preview_drone == null:
		var fallback := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(4.5, 1.2, 4.5)
		fallback.mesh = mesh
		fallback.set_meta("cosmetic_part_root", "frame")
		preview_drone = fallback
		_freeze_preview_node_tree(preview_drone)

	preview_root.add_child(preview_drone)
	_prepare_preview_for_display()
	_apply_to_preview()
	call_deferred("_focus_camera_on_preview")

func _prepare_preview_for_display() -> void:
	if preview_drone == null or not is_instance_valid(preview_drone):
		return
	if not preview_drone.is_inside_tree():
		return
	preview_drone.position = Vector3.ZERO
	preview_drone.rotation_degrees = Vector3.ZERO
	preview_drone.scale = Vector3.ONE
	var initial_focus: Dictionary = _get_preview_focus_data(preview_drone)
	var size_variant: Variant = initial_focus.get("size", Vector3.ONE)
	var size: Vector3 = size_variant if typeof(size_variant) == TYPE_VECTOR3 else Vector3.ONE
	var max_dimension: float = maxf(size.x, maxf(size.y, size.z))
	if max_dimension > 0.001:
		var target_dimension: float = 9.0
		var preview_scale: float = clampf(target_dimension / max_dimension, 0.12, 1.45)
		preview_drone.scale = Vector3.ONE * preview_scale

func _focus_camera_on_preview() -> void:
	if preview_scene_closing or not is_inside_tree():
		return
	if preview_drone == null or not is_instance_valid(preview_drone):
		return
	if not preview_drone.is_inside_tree():
		return
	if camera == null or camera_pivot == null:
		return
	var focus_data: Dictionary = _get_preview_focus_data(preview_drone)
	var center: Vector3 = focus_data.get("center", Vector3.ZERO)
	var size_variant: Variant = focus_data.get("size", Vector3.ONE * 4.0)
	var size: Vector3 = size_variant if typeof(size_variant) == TYPE_VECTOR3 else Vector3.ONE * 4.0
	var radius: float = clampf(maxf(float(focus_data.get("radius", 4.0)), maxf(size.y * 0.58, 1.6)), 1.8, 6.0)
	camera_pivot.position = center
	camera.position = Vector3(radius * 0.98, radius * 0.54, radius * 1.08)
	camera.look_at(center + Vector3(0.0, minf(size.y * 0.12, 0.75), 0.0), Vector3.UP)

func _get_preview_focus_data(root: Node3D, ignore_nested_roots: bool = false) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return {
			"center": Vector3.ZERO,
			"radius": 1.8,
			"size": Vector3.ONE,
			"bounds_min": Vector3.ONE * -0.5,
			"bounds_max": Vector3.ONE * 0.5
		}
	if not root.is_inside_tree():
		return {
			"center": root.position,
			"radius": 1.8,
			"size": Vector3.ONE,
			"bounds_min": root.position - Vector3.ONE * 0.5,
			"bounds_max": root.position + Vector3.ONE * 0.5
		}
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	var mesh_count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null or not is_instance_valid(node):
			continue
		if node is Node3D and not (node as Node3D).is_inside_tree():
			continue
		for child in node.get_children():
			if ignore_nested_roots and child != root and child.has_meta("cosmetic_part_root"):
				continue
			stack.append(child)
		if not (node is MeshInstance3D):
			continue
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if not mesh_node.is_inside_tree():
			continue
		if mesh_node.mesh == null:
			continue
		var local_aabb: AABB = mesh_node.get_aabb()
		var local_corners: Array[Vector3] = [
			local_aabb.position,
			local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
			local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
			local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
			local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
			local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
			local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
			local_aabb.position + local_aabb.size
		]
		for corner_variant in local_corners:
			var world_corner: Vector3 = mesh_node.to_global(corner_variant)
			bounds_min = bounds_min.min(world_corner)
			bounds_max = bounds_max.max(world_corner)
		mesh_count += 1
	if mesh_count == 0:
		return {
			"center": root.global_position,
			"radius": 1.4,
			"size": Vector3.ONE,
			"bounds_min": root.global_position - Vector3.ONE * 0.7,
			"bounds_max": root.global_position + Vector3.ONE * 0.7
		}
	var center: Vector3 = (bounds_min + bounds_max) * 0.5
	var size: Vector3 = bounds_max - bounds_min
	var radius: float = maxf(size.length() * 0.5, 0.75)
	return {
		"center": center,
		"radius": radius,
		"size": size,
		"bounds_min": bounds_min,
		"bounds_max": bounds_max
	}

func _project_part_bounds(bounds_min: Vector3, bounds_max: Vector3) -> Rect2:
	var corners: Array[Vector3] = [
		Vector3(bounds_min.x, bounds_min.y, bounds_min.z),
		Vector3(bounds_min.x, bounds_min.y, bounds_max.z),
		Vector3(bounds_min.x, bounds_max.y, bounds_min.z),
		Vector3(bounds_min.x, bounds_max.y, bounds_max.z),
		Vector3(bounds_max.x, bounds_min.y, bounds_min.z),
		Vector3(bounds_max.x, bounds_min.y, bounds_max.z),
		Vector3(bounds_max.x, bounds_max.y, bounds_min.z),
		Vector3(bounds_max.x, bounds_max.y, bounds_max.z)
	]
	var has_projection: bool = false
	var projected_rect := Rect2()
	for corner_variant in corners:
		var corner: Vector3 = corner_variant
		if camera.is_position_behind(corner):
			continue
		var screen_point: Vector2 = camera.unproject_position(corner)
		if not has_projection:
			projected_rect = Rect2(screen_point, Vector2.ZERO)
			has_projection = true
		else:
			projected_rect = projected_rect.expand(screen_point)
	if not has_projection:
		return Rect2()
	return projected_rect

func _pick_part_at_screen_position(mouse_position: Vector2) -> String:
	if preview_drone == null or not is_instance_valid(preview_drone):
		return ""
	var tagged_nodes: Array = []
	_collect_nodes_with_meta(preview_drone, "cosmetic_part_root", tagged_nodes)
	var best_part_id: String = ""
	var best_score: float = INF
	for node_variant in tagged_nodes:
		if not (node_variant is Node3D):
			continue
		var part_root: Node3D = node_variant as Node3D
		var pick_info: Dictionary = _get_preview_focus_data(part_root, true)
		var center_variant: Variant = pick_info.get("center", part_root.global_position)
		var center: Vector3 = center_variant if typeof(center_variant) == TYPE_VECTOR3 else part_root.global_position
		if camera.is_position_behind(center):
			continue
		var part_id: String = str(part_root.get_meta("cosmetic_part_root"))
		var bounds_min_variant: Variant = pick_info.get("bounds_min", center - Vector3.ONE)
		var bounds_max_variant: Variant = pick_info.get("bounds_max", center + Vector3.ONE)
		var bounds_min: Vector3 = bounds_min_variant if typeof(bounds_min_variant) == TYPE_VECTOR3 else center - Vector3.ONE
		var bounds_max: Vector3 = bounds_max_variant if typeof(bounds_max_variant) == TYPE_VECTOR3 else center + Vector3.ONE
		var projected_rect: Rect2 = _project_part_bounds(bounds_min, bounds_max)
		if projected_rect.size.x <= 1.0 or projected_rect.size.y <= 1.0:
			continue
		if part_id == "board":
			var board_shrink: Vector2 = projected_rect.size * 0.28
			projected_rect = Rect2(
				projected_rect.position + board_shrink,
				Vector2(
					maxf(projected_rect.size.x - board_shrink.x * 2.0, 12.0),
					maxf(projected_rect.size.y - board_shrink.y * 2.0, 12.0)
				)
			)
		elif part_id == "frame":
			projected_rect = projected_rect.grow(18.0)
		if not projected_rect.has_point(mouse_position):
			continue
		var rect_area: float = projected_rect.size.x * projected_rect.size.y
		var normalized_distance: float = mouse_position.distance_to(projected_rect.get_center()) / maxf(projected_rect.size.length(), 1.0)
		var depth: float = camera.global_position.distance_to(center)
		var candidate_score: float = rect_area * 0.0018 + normalized_distance * 140.0 + depth * 0.04
		if part_id == "frame":
			candidate_score *= 0.72
		elif part_id == "board":
			candidate_score *= 1.34
		if candidate_score < best_score:
			best_score = candidate_score
			best_part_id = part_id
	return best_part_id

func _collect_nodes_with_meta(root: Node, meta_name: String, result: Array) -> void:
	if root == null:
		return
	if root.has_meta(meta_name):
		result.append(root)
	for child in root.get_children():
		_collect_nodes_with_meta(child, meta_name, result)

func _select_part(part_id: String) -> void:
	var part_index: int = part_ids.find(part_id)
	if part_index < 0:
		return
	selected_part_id = part_id
	selected_image_source = ""
	part_option.select(part_index)
	_refresh_mode_buttons()
	_refresh_options()
	status_label.text = "Выбрана деталь: %s" % _label_for_part_id(part_id)

func _label_for_part_id(part_id: String) -> String:
	if part_labels.has(part_id):
		return str(part_labels[part_id])
	if part_id == "frame":
		return "Рама"
	if part_id == "board":
		return "Плата"
	if part_id.begins_with("motor_"):
		var slot: int = clampi(int(part_id.trim_prefix("motor_")), 0, SLOT_NAMES.size() - 1)
		return "%s: мотор" % SLOT_NAMES[slot]
	if part_id.begins_with("propeller_"):
		var slot: int = clampi(int(part_id.trim_prefix("propeller_")), 0, SLOT_NAMES.size() - 1)
		return "%s: пропеллер" % SLOT_NAMES[slot]
	if part_id == "effect:highlight":
		return "Аура клетки"
	if part_id == "effect:trail":
		return "След движения"
	return part_id

func _mode_label(mode_name: String) -> String:
	match mode_name:
		"color":
			return "Цвет"
		"pattern":
			return "Узор"
		"texture":
			return "Текстура"
		"image":
			return "Изображение"
		"effect":
			return "Эффект"
		_:
			return mode_name.capitalize()

func _style_option_button(button: OptionButton) -> void:
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.26, 0.18, 0.12, 0.98)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.72, 0.56, 0.36, 0.84)
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 16.0
	normal.content_margin_top = 10.0
	normal.content_margin_right = 16.0
	normal.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", normal)

func _style_button(button: BaseButton, fill: Color, border: Color) -> void:
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	button.add_theme_font_size_override("font_size", 20)

	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = border
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 16.0
	normal.content_margin_top = 10.0
	normal.content_margin_right = 16.0
	normal.content_margin_bottom = 10.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.08)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

func _build_panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 20
	return style

func _on_back_pressed() -> void:
	preview_scene_closing = true
	get_tree().change_scene_to_file(CREATE_DRONE_SCENE_PATH)

func _on_part_selected(index: int) -> void:
	if index < 0 or index >= part_ids.size():
		return
	selected_part_id = part_ids[index]
	selected_image_source = ""
	_refresh_mode_buttons()
	_refresh_options()
	status_label.text = "Выбрана деталь: %s" % _label_for_part_id(selected_part_id)

func _on_mode_pressed(mode_name: String) -> void:
	selected_mode = mode_name
	selected_unlock_id = _default_unlock_for_mode()
	selected_image_source = ""
	_refresh_mode_buttons()
	_refresh_options()

func _on_option_pressed(unlock_id: String) -> void:
	selected_unlock_id = unlock_id
	_sync_custom_color_from_selection()
	_refresh_options()

func _on_choose_image_pressed() -> void:
	if file_dialog != null:
		file_dialog.popup_centered_ratio(0.72)

func _on_image_selected(path: String) -> void:
	selected_image_source = path
	status_label.text = "Файл выбран: %s" % path.get_file()
	_refresh_apply_button_modern()

func _on_apply_pressed() -> void:
	if selected_mode == "image":
		if not Global.is_cosmetic_unlocked("custom_image_pass"):
			var image_pass: Dictionary = Global.get_cosmetic_entry("custom_image_pass")
			var pass_cost: int = int(image_pass.get("cost", 0))
			if not Global.spend_crystals(pass_cost):
				status_label.text = "Недостаточно кристаллов для открытия пользовательского изображения."
				return
			Global.unlock_cosmetic("custom_image_pass")
		if selected_image_source.is_empty():
			status_label.text = "Сначала выберите PNG или JPEG."
			return
		var imported_path: String = Global.import_custom_cosmetic_image(selected_image_source, selected_part_id)
		if imported_path.is_empty():
			status_label.text = "Не удалось импортировать изображение."
			return
		Global.set_part_customization(selected_part_id, {
			"mode": "image",
			"unlock_id": "custom_image_pass",
			"image_path": imported_path
		})
		status_label.text = "Изображение применено."
	else:
		var entry: Dictionary = Global.get_cosmetic_entry(selected_unlock_id)
		var cost: int = int(entry.get("cost", 0))
		if not Global.is_cosmetic_unlocked(selected_unlock_id) and cost > 0:
			if not Global.spend_crystals(cost):
				status_label.text = "Недостаточно кристаллов для этого стиля."
				return
			Global.unlock_cosmetic(selected_unlock_id)

		var mode_to_apply: String = "effect" if selected_mode == "effect" else selected_mode
		var style_to_apply: Dictionary = {
			"mode": mode_to_apply,
			"unlock_id": selected_unlock_id
		}
		if selected_mode == "color":
			style_to_apply["base_color"] = custom_color_preview if selected_unlock_id == "color_rgb_custom" else entry.get("color", Color(0.82, 0.67, 0.48))
		elif selected_mode == "pattern" or selected_mode == "texture":
			style_to_apply["base_color"] = Global.get_part_base_color(selected_part_id)
		if selected_mode == "color" and selected_unlock_id == "color_rgb_custom":
			style_to_apply["custom_color"] = custom_color_preview
		Global.set_part_customization(selected_part_id, style_to_apply)
		status_label.text = "Стиль применен."

	_refresh_wallet_display()
	_apply_to_preview()
	_refresh_options()

func _on_reset_pressed() -> void:
	Global.reset_part_customization(selected_part_id)
	selected_image_source = ""
	status_label.text = "Возвращен стандартный стиль."
	_apply_to_preview()
	_refresh_options()

func _on_crystals_changed(new_value: int) -> void:
	if new_value < 0:
		return
	_refresh_wallet_display()
	_refresh_apply_button_modern()

func _on_cosmetic_inventory_changed() -> void:
	_refresh_wallet_display()
	_refresh_options()

func _on_cosmetic_profile_changed() -> void:
	_apply_to_preview()
	_refresh_options()
