extends CanvasLayer

signal settings_saved
signal settings_cancelled
signal settings_closed

@onready var backdrop: ColorRect = $Backdrop
@onready var settings_panel: Panel = $Backdrop/CenterContainer/Panel
@onready var root_container: VBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root
@onready var content_tabs: TabContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs
@onready var title_label: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/Header/Title
@onready var subtitle_label: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/Header/Subtitle
@onready var controls_page: VBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Controls
@onready var audio_page: VBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Audio
@onready var graphics_scroll: ScrollContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll
@onready var graphics_page: VBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics
@onready var fps_option: OptionButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/FPSRow/FPSOption
@onready var mouse_sensitivity_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Controls/MouseRow/MouseSensitivitySlider
@onready var mouse_sensitivity_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Controls/MouseRow/MouseSensitivityValue
@onready var fov_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Controls/FOVRow/FOVSlider
@onready var fov_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Controls/FOVRow/FOVValue
@onready var music_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Audio/MusicRow/MusicSlider
@onready var music_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Audio/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Audio/SFXRow/SFXSlider
@onready var sfx_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/Audio/SFXRow/SFXValue
@onready var brightness_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/BrightnessRow/BrightnessSlider
@onready var brightness_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/BrightnessRow/BrightnessValue
@onready var render_scale_slider: HSlider = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/RenderScaleRow/RenderScaleSlider
@onready var render_scale_value: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/RenderScaleRow/RenderScaleValue
@onready var shadow_quality_option: OptionButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/ShadowRow/ShadowQualityOption
@onready var window_mode_label: Label = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/FullscreenRow/FullscreenLabel
@onready var window_mode_option: OptionButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/FullscreenRow/FullscreenToggle
@onready var resolution_option: OptionButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/ResolutionRow/ResolutionOption
@onready var glow_toggle: CheckButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/GlowRow/GlowToggle
@onready var ssao_toggle: CheckButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/SSAORow/SSAOToggle
@onready var highlight_row: HBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/HighlightRow
@onready var trail_row: HBoxContainer = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/TrailRow
@onready var highlight_picker: ColorPickerButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/HighlightRow/HighlightPicker
@onready var trail_picker: ColorPickerButton = $Backdrop/CenterContainer/Panel/MarginContainer/Root/ContentTabs/GraphicsScroll/Graphics/TrailRow/TrailPicker
@onready var save_button: Button = $Backdrop/CenterContainer/Panel/MarginContainer/Root/Footer/SaveButton
@onready var default_button: Button = $Backdrop/CenterContainer/Panel/MarginContainer/Root/Footer/DefaultButton
@onready var cancel_button: Button = $Backdrop/CenterContainer/Panel/MarginContainer/Root/Footer/CancelButton

var original_settings: Dictionary = {}
var resolution_keys: Array[String] = []
var custom_tab_holder: MarginContainer = null
var custom_tab_row: HBoxContainer = null
var custom_tab_buttons: Array[Button] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_setup_options()
	_setup_resolution_options()
	_apply_tab_titles()
	_ensure_custom_tab_row()
	_ensure_row_cards()
	_apply_visual_theme()
	_hide_cosmetic_rows()
	_connect_signals()
	load_settings_from_global()
	save_original_settings()
	_queue_layout_refresh()

func _unhandled_input(event: InputEvent):
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

func _setup_options():
	fps_option.clear()
	fps_option.add_item("30 FPS", 0)
	fps_option.add_item("60 FPS", 1)
	fps_option.add_item("120 FPS", 2)
	fps_option.add_item("VSync", 3)

	window_mode_label.text = "Режим окна"
	window_mode_option.clear()
	window_mode_option.add_item("В окне", Global.WINDOW_MODE_WINDOWED if Global else 0)
	window_mode_option.add_item("Без рамок", Global.WINDOW_MODE_BORDERLESS if Global else 1)
	window_mode_option.add_item("Полноэкранный", Global.WINDOW_MODE_FULLSCREEN if Global else 2)

	shadow_quality_option.clear()
	shadow_quality_option.add_item("Выкл.", 0)
	shadow_quality_option.add_item("Четкие", 1)
	shadow_quality_option.add_item("Сбалансированные", 2)
	shadow_quality_option.add_item("Мягкие", 3)

func _setup_resolution_options():
	resolution_option.clear()
	resolution_keys.clear()

	var available_resolutions: Array[Dictionary] = []
	if Global != null:
		available_resolutions = Global.get_available_window_resolutions()

	for entry_variant in available_resolutions:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var resolution_key: String = str(entry.get("key", Global.WINDOW_RESOLUTION_SYSTEM if Global else "system"))
		var resolution_label: String = str(entry.get("label", resolution_key))
		resolution_keys.append(resolution_key)
		resolution_option.add_item(resolution_label, resolution_keys.size() - 1)

func _apply_tab_titles():
	content_tabs.set_tab_title(0, "Управление")
	content_tabs.set_tab_title(1, "Звук")
	content_tabs.set_tab_title(2, "Графика")

func _ensure_custom_tab_row():
	if root_container == null or content_tabs == null:
		return
	if custom_tab_row != null and is_instance_valid(custom_tab_row):
		return

	custom_tab_holder = MarginContainer.new()
	custom_tab_holder.name = "CustomTabHolder"
	custom_tab_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_tab_holder.add_theme_constant_override("margin_top", 6)
	custom_tab_holder.add_theme_constant_override("margin_bottom", 10)
	root_container.add_child(custom_tab_holder)
	root_container.move_child(custom_tab_holder, root_container.get_children().find(content_tabs))

	var tab_center := CenterContainer.new()
	tab_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_tab_holder.add_child(tab_center)

	custom_tab_row = HBoxContainer.new()
	custom_tab_row.name = "CustomTabRow"
	custom_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	custom_tab_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_tab_row.custom_minimum_size = Vector2(0, 72)
	custom_tab_row.add_theme_constant_override("separation", 18)
	tab_center.add_child(custom_tab_row)

	var tab_titles: Array[String] = ["Управление", "Звук", "Графика"]
	custom_tab_buttons.clear()
	for tab_index in range(tab_titles.size()):
		var tab_button := Button.new()
		tab_button.text = tab_titles[tab_index]
		tab_button.custom_minimum_size = Vector2(190, 58)
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.pressed.connect(_on_custom_tab_pressed.bind(tab_index))
		custom_tab_row.add_child(tab_button)
		custom_tab_buttons.append(tab_button)

func _get_setting_pages() -> Array[VBoxContainer]:
	var pages: Array[VBoxContainer] = []
	if controls_page != null:
		pages.append(controls_page)
	if audio_page != null:
		pages.append(audio_page)
	if graphics_page != null:
		pages.append(graphics_page)
	return pages

func _ensure_row_cards():
	for page in _get_setting_pages():
		for child in page.get_children():
			if child is PanelContainer:
				continue
			var row: HBoxContainer = child as HBoxContainer
			if row == null:
				continue

			var row_index: int = row.get_index()
			var card := PanelContainer.new()
			card.name = "%sCard" % row.name
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var padding := MarginContainer.new()
			padding.name = "Padding"
			padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
			padding.add_theme_constant_override("margin_left", 20)
			padding.add_theme_constant_override("margin_top", 12)
			padding.add_theme_constant_override("margin_right", 20)
			padding.add_theme_constant_override("margin_bottom", 12)

			page.remove_child(row)
			page.add_child(card)
			page.move_child(card, row_index)
			card.add_child(padding)
			padding.add_child(row)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _get_row_from_card(card: PanelContainer) -> HBoxContainer:
	if card == null or card.get_child_count() == 0:
		return null
	var padding: MarginContainer = card.get_child(0) as MarginContainer
	if padding == null or padding.get_child_count() == 0:
		return null
	return padding.get_child(0) as HBoxContainer

func _refresh_graphics_scroll():
	if graphics_page == null or graphics_scroll == null:
		return
	var target_width: float = maxf(graphics_scroll.size.x - 28.0, 0.0)
	graphics_page.custom_minimum_size = Vector2(target_width, graphics_page.get_combined_minimum_size().y + 24.0)
	graphics_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _apply_visual_theme():
	settings_panel.custom_minimum_size = Vector2(1260, 920)
	root_container.add_theme_constant_override("separation", 26)
	content_tabs.custom_minimum_size = Vector2(0, 710)
	graphics_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graphics_scroll.follow_focus = true

	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.88, 0.79, 0.68))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for page in _get_setting_pages():
		page.add_theme_constant_override("separation", 22)
		for child in page.get_children():
			if child is Label:
				var hint: Label = child as Label
				hint.add_theme_color_override("font_color", Color(0.88, 0.79, 0.68))
				hint.add_theme_font_size_override("font_size", 20)
				hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				continue

			var card: PanelContainer = child as PanelContainer
			var row: HBoxContainer = _get_row_from_card(card)
			if row == null:
				continue

			_style_row_card(card)
			card.custom_minimum_size = Vector2(0, 108)
			row.custom_minimum_size = Vector2(0, 72)
			row.add_theme_constant_override("separation", 12)
			row.alignment = BoxContainer.ALIGNMENT_CENTER

			if row.get_child_count() > 0 and row.get_child(0) is Control:
				var title_control: Control = row.get_child(0) as Control
				title_control.custom_minimum_size = Vector2(220, 44)
				title_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				if title_control is Label:
					var title_label_control: Label = title_control as Label
					title_label_control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			for row_index in range(row.get_child_count()):
				var row_child: Node = row.get_child(row_index)
				if row_child is Range:
					var slider: Range = row_child as Range
					slider.custom_minimum_size = Vector2(0, 24)
					slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					slider.size_flags_stretch_ratio = 1.2
				elif row_child is ColorPickerButton:
					var picker: ColorPickerButton = row_child as ColorPickerButton
					picker.custom_minimum_size = Vector2(300, 52)
					picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					_style_picker(picker)
				elif row_child is BaseButton:
					var base_button: BaseButton = row_child as BaseButton
					base_button.custom_minimum_size = Vector2(maxf(base_button.custom_minimum_size.x, 220.0), 52)
					base_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					_style_input_button(base_button)
				elif row_child is Label:
					var label: Label = row_child as Label
					label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.84))
					label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					if row_index == 0:
						label.add_theme_font_size_override("font_size", 24)
					else:
						label.custom_minimum_size = Vector2(maxf(label.custom_minimum_size.x, 110.0), 40)
						label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						label.add_theme_font_size_override("font_size", 22)

	_style_tab_bar()
	_style_input_button(fps_option)
	_style_input_button(window_mode_option)
	_style_input_button(resolution_option)
	_style_input_button(shadow_quality_option)
	_style_input_button(glow_toggle)
	_style_input_button(ssao_toggle)
	_style_picker(highlight_picker)
	_style_picker(trail_picker)
	_style_action_button(save_button, Color(0.42, 0.28, 0.17, 0.97), Color(0.82, 0.64, 0.40, 0.94))
	_style_action_button(default_button, Color(0.32, 0.23, 0.16, 0.97), Color(0.72, 0.56, 0.37, 0.84))
	_style_action_button(cancel_button, Color(0.30, 0.18, 0.16, 0.97), Color(0.78, 0.45, 0.34, 0.86))
	_refresh_custom_tab_row()

func _style_tab_bar():
	if content_tabs == null:
		return
	content_tabs.tabs_visible = false
	_refresh_custom_tab_row()

func _refresh_custom_tab_row():
	if custom_tab_row == null or not is_instance_valid(custom_tab_row):
		return
	for tab_index in range(custom_tab_buttons.size()):
		var tab_button: Button = custom_tab_buttons[tab_index]
		if tab_button == null:
			continue
		tab_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if tab_index == content_tabs.current_tab:
			_style_action_button(tab_button, Color(0.40, 0.27, 0.17, 0.98), Color(0.88, 0.70, 0.45, 0.96))
		else:
			_style_action_button(tab_button, Color(0.23, 0.17, 0.12, 0.94), Color(0.62, 0.48, 0.32, 0.66))

func _on_custom_tab_pressed(tab_index: int):
	if content_tabs == null:
		return
	content_tabs.current_tab = tab_index
	_refresh_custom_tab_row()

func _queue_layout_refresh() -> void:
	call_deferred("_refresh_layout_pass")

func _refresh_layout_pass() -> void:
	if not is_inside_tree():
		return
	_apply_tab_titles()
	_apply_visual_theme()
	_hide_cosmetic_rows()
	_refresh_graphics_scroll()
	call_deferred("_refresh_layout_pass_second")

func _refresh_layout_pass_second() -> void:
	if not is_inside_tree():
		return
	_style_tab_bar()
	_hide_cosmetic_rows()
	_refresh_graphics_scroll()

func _hide_cosmetic_rows():
	_hide_row_card(highlight_row)
	_hide_row_card(trail_row)

func _hide_row_card(row: HBoxContainer):
	if row == null:
		return
	var padding: MarginContainer = row.get_parent() as MarginContainer
	if padding != null:
		var card: PanelContainer = padding.get_parent() as PanelContainer
		if card != null:
			card.visible = false
	row.visible = false

func _set_tab_bar_alignment(tab_bar: TabBar):
	for property_variant in tab_bar.get_property_list():
		if typeof(property_variant) != TYPE_DICTIONARY:
			continue
		var property_info: Dictionary = property_variant
		var property_name: String = str(property_info.get("name", ""))
		if property_name == "tab_alignment" or property_name == "alignment":
			tab_bar.set(property_name, 1)
			return

func _build_tab_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 26.0
	style.content_margin_top = 12.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 12.0
	return style

func _style_row_card(card: PanelContainer):
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.21, 0.15, 0.10, 0.84)
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.border_color = Color(0.72, 0.56, 0.37, 0.54)
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_right = 16
	panel.corner_radius_bottom_left = 16
	panel.shadow_color = Color(0, 0, 0, 0.16)
	panel.shadow_size = 4
	card.add_theme_stylebox_override("panel", panel)

func _style_input_button(button: BaseButton):
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.23, 0.17, 0.12, 0.97)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.72, 0.56, 0.37, 0.78)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_right = 12
	normal.corner_radius_bottom_left = 12
	normal.content_margin_left = 14.0
	normal.content_margin_top = 10.0
	normal.content_margin_right = 14.0
	normal.content_margin_bottom = 10.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.29, 0.21, 0.15, 0.99)
	hover.border_color = Color(0.86, 0.69, 0.47, 0.98)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.18, 0.13, 0.09, 0.99)
	pressed.border_color = Color(0.93, 0.75, 0.50, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.96, 0.91, 0.84))
	button.add_theme_font_size_override("font_size", 20)

func _style_action_button(button: Button, fill_color: Color, border_color: Color):
	if button == null:
		return
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 188.0), 60)
	_style_input_button(button)
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	var hover: StyleBoxFlat = button.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
	var pressed: StyleBoxFlat = button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
	normal.bg_color = fill_color
	normal.border_color = border_color
	hover.bg_color = fill_color.lightened(0.08)
	hover.border_color = border_color.lightened(0.08)
	pressed.bg_color = fill_color.darkened(0.08)
	pressed.border_color = border_color
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

func _style_picker(picker: ColorPickerButton):
	if picker == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.23, 0.17, 0.12, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.56, 0.37, 0.78)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	picker.add_theme_stylebox_override("normal", style)
	picker.add_theme_stylebox_override("hover", style)
	picker.add_theme_stylebox_override("pressed", style)
	picker.add_theme_stylebox_override("focus", style)
	picker.add_theme_font_size_override("font_size", 18)

func _update_toggle_text(toggle: CheckButton, enabled: bool):
	if toggle == null:
		return
	toggle.text = "Включено" if enabled else "Выключено"

func _select_resolution_option(target_key: String):
	var normalized_key: String = target_key
	if normalized_key.is_empty() and Global != null:
		normalized_key = Global.resolution_key
	for index in range(resolution_keys.size()):
		if resolution_keys[index] == normalized_key:
			resolution_option.select(index)
			return
	if not resolution_keys.is_empty():
		resolution_option.select(0)

func _connect_signals():
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	fps_option.item_selected.connect(_on_fps_selected)
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	render_scale_slider.value_changed.connect(_on_render_scale_changed)
	shadow_quality_option.item_selected.connect(_on_shadow_quality_selected)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	glow_toggle.toggled.connect(_on_glow_toggled)
	ssao_toggle.toggled.connect(_on_ssao_toggled)
	save_button.pressed.connect(_on_save_pressed)
	default_button.pressed.connect(_on_default_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func load_settings_from_global():
	if Global == null:
		return
	fps_option.select(Global.fps_mode)
	mouse_sensitivity_slider.value = Global.mouse_sensitivity
	mouse_sensitivity_value.text = "%.2fx" % Global.mouse_sensitivity
	fov_slider.value = Global.camera_fov
	fov_value.text = "%d" % int(round(Global.camera_fov))
	music_slider.value = Global.music_volume
	music_value.text = "%d%%" % int(round(Global.music_volume))
	sfx_slider.value = Global.sfx_volume
	sfx_value.text = "%d%%" % int(round(Global.sfx_volume))
	brightness_slider.value = Global.brightness
	brightness_value.text = "%d%%" % int(round(Global.brightness * 100.0))
	render_scale_slider.value = Global.render_scale
	render_scale_value.text = "%d%%" % int(round(Global.render_scale * 100.0))
	shadow_quality_option.select(Global.shadow_quality)
	window_mode_option.select(Global.window_mode)
	_select_resolution_option(Global.resolution_key)
	glow_toggle.button_pressed = Global.glow_enabled
	ssao_toggle.button_pressed = Global.ssao_enabled
	_update_toggle_text(glow_toggle, Global.glow_enabled)
	_update_toggle_text(ssao_toggle, Global.ssao_enabled)

func save_original_settings():
	if Global == null:
		return
	original_settings = {
		"fps_mode": Global.fps_mode,
		"mouse_sensitivity": Global.mouse_sensitivity,
		"camera_fov": Global.camera_fov,
		"music_volume": Global.music_volume,
		"sfx_volume": Global.sfx_volume,
		"brightness": Global.brightness,
		"render_scale": Global.render_scale,
		"shadow_quality": Global.shadow_quality,
		"window_mode": Global.window_mode,
		"resolution_key": Global.resolution_key,
		"glow_enabled": Global.glow_enabled,
		"ssao_enabled": Global.ssao_enabled
	}

func restore_original_settings():
	if original_settings.is_empty() or Global == null:
		return
	Global.fps_mode = int(original_settings["fps_mode"])
	Global.mouse_sensitivity = float(original_settings["mouse_sensitivity"])
	Global.camera_fov = float(original_settings["camera_fov"])
	Global.music_volume = float(original_settings["music_volume"])
	Global.sfx_volume = float(original_settings["sfx_volume"])
	Global.brightness = float(original_settings["brightness"])
	Global.render_scale = float(original_settings["render_scale"])
	Global.shadow_quality = int(original_settings["shadow_quality"])
	Global.window_mode = int(original_settings["window_mode"])
	Global.resolution_key = str(original_settings["resolution_key"])
	Global.glow_enabled = bool(original_settings["glow_enabled"])
	Global.ssao_enabled = bool(original_settings["ssao_enabled"])
	Global.apply_global_settings()
	load_settings_from_global()

func _apply_default_preview():
	if Global == null:
		return
	Global.fps_mode = 3
	Global.mouse_sensitivity = 1.0
	Global.camera_fov = 75.0
	Global.music_volume = 50.0
	Global.sfx_volume = 50.0
	Global.brightness = 1.0
	Global.render_scale = 1.0
	Global.shadow_quality = 2
	Global.window_mode = Global.WINDOW_MODE_WINDOWED
	Global.resolution_key = Global.WINDOW_RESOLUTION_SYSTEM
	Global.glow_enabled = true
	Global.ssao_enabled = true
	Global.apply_global_settings()
	load_settings_from_global()

func _on_backdrop_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position == Vector2.ZERO:
			return

func _on_fps_selected(index: int):
	Global.fps_mode = index
	Global.apply_global_settings()

func _on_mouse_sensitivity_changed(value: float):
	Global.mouse_sensitivity = value
	mouse_sensitivity_value.text = "%.2fx" % value

func _on_fov_changed(value: float):
	Global.camera_fov = value
	fov_value.text = "%d" % int(round(value))

func _on_music_changed(value: float):
	Global.music_volume = value
	music_value.text = "%d%%" % int(round(value))
	Global.apply_global_settings()

func _on_sfx_changed(value: float):
	Global.sfx_volume = value
	sfx_value.text = "%d%%" % int(round(value))
	Global.apply_global_settings()

func _on_brightness_changed(value: float):
	Global.brightness = value
	brightness_value.text = "%d%%" % int(round(value * 100.0))

func _on_render_scale_changed(value: float):
	Global.render_scale = value
	render_scale_value.text = "%d%%" % int(round(value * 100.0))
	Global.apply_global_settings()

func _on_shadow_quality_selected(index: int):
	Global.shadow_quality = index
	Global.apply_global_settings()

func _on_window_mode_selected(index: int):
	Global.window_mode = int(window_mode_option.get_item_id(index))
	Global.apply_global_settings()

func _on_resolution_selected(index: int):
	if index < 0 or index >= resolution_keys.size():
		return
	Global.resolution_key = resolution_keys[index]
	Global.apply_global_settings()

func _on_glow_toggled(toggled_on: bool):
	Global.glow_enabled = toggled_on
	_update_toggle_text(glow_toggle, toggled_on)

func _on_ssao_toggled(toggled_on: bool):
	Global.ssao_enabled = toggled_on
	_update_toggle_text(ssao_toggle, toggled_on)

func _on_save_pressed():
	if Global == null:
		return
	Global.save_global_settings()
	Global.apply_global_settings()
	settings_saved.emit()
	close()

func _on_default_pressed():
	_apply_default_preview()

func _on_cancel_pressed():
	restore_original_settings()
	settings_cancelled.emit()
	close()

func open():
	_setup_resolution_options()
	load_settings_from_global()
	save_original_settings()
	visible = true
	graphics_scroll.scroll_vertical = 0
	_queue_layout_refresh()
	save_button.grab_focus()

func close():
	if not visible:
		return
	visible = false
	settings_closed.emit()

func toggle():
	if visible:
		close()
	else:
		open()

func is_open() -> bool:
	return visible
