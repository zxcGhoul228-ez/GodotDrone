extends Control

@export var tutorial_button_path: NodePath

@onready var tutorial_button: Button = get_node_or_null(tutorial_button_path) as Button
@onready var background: TextureRect = $TextureRect
@onready var menu_shell: HBoxContainer = $TextureRect/HBoxContainer
@onready var menu_buttons_box: VBoxContainer = $TextureRect/HBoxContainer/VBoxContainer
@onready var start_button: Button = $TextureRect/HBoxContainer/VBoxContainer/GameButt
@onready var assembly_button: Button = $TextureRect/HBoxContainer/VBoxContainer/InvButt
@onready var shop_button: Button = $TextureRect/HBoxContainer/VBoxContainer/ShopButt
@onready var exit_button: Button = $TextureRect/HBoxContainer/VBoxContainer/Button
@onready var top_actions_box: HBoxContainer = $HBoxContainer2
@onready var settings_button: Button = $sett_button
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var score_box: VBoxContainer = $VBoxContainer
@onready var score_label: Label = $VBoxContainer/HBoxContainer/ScoreLabel
@onready var title_label: Label = $Label

var settings_menu = null

func _ready():
	_sync_root_rect()
	_prepare_layout_nodes()
	_apply_visual_theme()
	_layout_screen()
	_connect_buttons()
	_ensure_settings_menu()
	_connect_global_signals()
	update_score_display()
	apply_music_volume()
	apply_brightness()
	if audio_player and not audio_player.playing:
		audio_player.play()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_screen")

func _sync_root_rect():
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size

func _prepare_layout_nodes():
	_sync_root_rect()
	if background != null:
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.position = Vector2.ZERO
		background.size = get_viewport_rect().size
		background.custom_minimum_size = Vector2.ZERO
		background.expand_mode = 1
		background.stretch_mode = 6
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.z_index = 0

	_ensure_top_action_buttons()
	_integrate_aux_buttons_into_menu()

	if menu_shell != null:
		if menu_shell.get_parent() != self:
			menu_shell.reparent(self)
		menu_shell.z_index = 4

	if title_label != null:
		title_label.text = "DroneScript"
		title_label.z_index = 5

	if score_box != null:
		score_box.z_index = 6

	if settings_button != null:
		settings_button.z_index = 7

func _ensure_top_action_buttons():
	var action_parent: Control = menu_buttons_box if menu_buttons_box != null else top_actions_box
	if action_parent == null:
		return

	if top_actions_box != null:
		top_actions_box.z_index = 7
		top_actions_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_actions_box.visible = false

	if settings_button != null and settings_button.get_parent() != action_parent:
		settings_button.reparent(action_parent)

	if tutorial_button == null or not is_instance_valid(tutorial_button):
		tutorial_button = action_parent.get_node_or_null("tutorial_button") as Button
	if tutorial_button == null:
		tutorial_button = Button.new()
		tutorial_button.name = "tutorial_button"
		tutorial_button.focus_mode = Control.FOCUS_NONE
		tutorial_button.mouse_filter = Control.MOUSE_FILTER_STOP
		action_parent.add_child(tutorial_button)

	if settings_button != null:
		settings_button.visible = true
		settings_button.text = "Настройки"
		settings_button.icon = null
		settings_button.focus_mode = Control.FOCUS_NONE
		settings_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if tutorial_button != null:
		tutorial_button.visible = true
		tutorial_button.text = "Туториал"
		_style_top_action_button(tutorial_button, Color(0.30, 0.21, 0.14, 0.97), Color(0.82, 0.64, 0.42, 0.94))

	if settings_button != null:
		_style_top_action_button(settings_button, Color(0.30, 0.21, 0.14, 0.97), Color(0.82, 0.64, 0.42, 0.94))

func _integrate_aux_buttons_into_menu():
	if menu_buttons_box == null:
		return

	if top_actions_box != null:
		top_actions_box.visible = false

	if tutorial_button == null or not is_instance_valid(tutorial_button):
		tutorial_button = menu_buttons_box.get_node_or_null("tutorial_button") as Button
	if tutorial_button == null:
		tutorial_button = Button.new()
		tutorial_button.name = "tutorial_button"
		tutorial_button.focus_mode = Control.FOCUS_NONE
		tutorial_button.mouse_filter = Control.MOUSE_FILTER_STOP
		menu_buttons_box.add_child(tutorial_button)

	if settings_button != null and settings_button.get_parent() != menu_buttons_box:
		settings_button.reparent(menu_buttons_box)
	if tutorial_button.get_parent() != menu_buttons_box:
		tutorial_button.reparent(menu_buttons_box)

	if tutorial_button != null:
		tutorial_button.visible = true
		tutorial_button.text = "Туториал"
	if settings_button != null:
		settings_button.visible = true
		settings_button.text = "Настройки"
		settings_button.icon = null

	var exit_index: int = menu_buttons_box.get_child_count()
	if exit_button != null and exit_button.get_parent() == menu_buttons_box:
		exit_index = exit_button.get_index()
	if tutorial_button != null and tutorial_button.get_parent() == menu_buttons_box:
		menu_buttons_box.move_child(tutorial_button, exit_index)
		exit_index = tutorial_button.get_index() + 1
	if settings_button != null and settings_button.get_parent() == menu_buttons_box:
		menu_buttons_box.move_child(settings_button, exit_index)
	_reorder_menu_buttons()

func _reorder_menu_buttons():
	if menu_buttons_box == null:
		return

	var ordered_buttons: Array[Button] = [
		assembly_button,
		start_button,
		shop_button,
		settings_button,
		tutorial_button,
		exit_button
	]

	var target_index: int = 0
	for button in ordered_buttons:
		if button == null or button.get_parent() != menu_buttons_box:
			continue
		menu_buttons_box.move_child(button, target_index)
		target_index += 1

func _apply_visual_theme():
	_ensure_menu_card()
	_ensure_subtitle()
	_ensure_status_card()
	_ensure_top_action_buttons()
	_integrate_aux_buttons_into_menu()

	menu_buttons_box.add_theme_constant_override("separation", 12)
	title_label.modulate = Color(0.43, 0.13, 0.13)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))
	score_label.modulate = Color.WHITE
	score_label.add_theme_color_override("font_color", Color(0.94, 0.87, 0.78))
	score_label.add_theme_font_size_override("font_size", 32)

	var menu_fill := Color(0.30, 0.21, 0.14, 0.97)
	var menu_border := Color(0.82, 0.64, 0.42, 0.94)
	_style_main_button(assembly_button, menu_fill, menu_border)
	_style_main_button(start_button, menu_fill, menu_border)
	_style_main_button(shop_button, menu_fill, menu_border)
	if tutorial_button != null:
		_style_main_button(tutorial_button, menu_fill, menu_border)
	if settings_button != null:
		_style_main_button(settings_button, menu_fill, menu_border)
	_style_main_button(exit_button, menu_fill, menu_border)

func _layout_screen():
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	_sync_root_rect()

	if background != null:
		background.position = Vector2.ZERO
		background.size = viewport_size

	var left_margin: float = clampf(viewport_size.x * 0.05, 36.0, 92.0)
	var title_top: float = clampf(viewport_size.y * 0.09, 48.0, 104.0)
	var panel_top: float = clampf(viewport_size.y * 0.18, 176.0, 226.0)
	var panel_width: float = clampf(viewport_size.x * 0.31, 430.0, 560.0)
	var panel_height: float = clampf(viewport_size.y * 0.69, 520.0, 690.0)
	var button_height: float = clampf(viewport_size.y * 0.071, 60.0, 78.0)
	var button_font_size: int = clampi(int(round(viewport_size.x * 0.0155)), 24, 34)
	var title_font_size: int = clampi(int(round(viewport_size.x * 0.034)), 52, 76)
	var subtitle_font_size: int = clampi(int(round(viewport_size.x * 0.0105)), 18, 23)

	var menu_card: Panel = get_node_or_null("MenuCard") as Panel
	if menu_card != null:
		menu_card.position = Vector2(left_margin, panel_top)
		menu_card.size = Vector2(panel_width, panel_height)

	if title_label != null:
		title_label.position = Vector2(left_margin + 14.0, title_top)
		title_label.size = Vector2(panel_width - 28.0, title_font_size + 12.0)
		title_label.add_theme_font_size_override("font_size", title_font_size)

	var subtitle: Label = get_node_or_null("SubtitleLabel") as Label
	if subtitle != null:
		subtitle.position = Vector2(left_margin + 24.0, panel_top + 28.0)
		subtitle.size = Vector2(panel_width - 48.0, 72.0)
		subtitle.add_theme_font_size_override("font_size", subtitle_font_size)
		subtitle.z_index = 5

	if menu_shell != null:
		menu_shell.anchor_left = 0.0
		menu_shell.anchor_top = 0.0
		menu_shell.anchor_right = 0.0
		menu_shell.anchor_bottom = 0.0
		menu_shell.offset_left = left_margin + 28.0
		menu_shell.offset_top = panel_top + 126.0
		menu_shell.offset_right = left_margin + panel_width - 28.0
		menu_shell.offset_bottom = panel_top + panel_height - 28.0

	if menu_buttons_box != null:
		menu_buttons_box.custom_minimum_size = Vector2(panel_width - 56.0, 0.0)
		menu_buttons_box.add_theme_constant_override("separation", 12)

	for button in [assembly_button, start_button, shop_button, tutorial_button, settings_button, exit_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(panel_width - 56.0, button_height)
		button.add_theme_font_size_override("font_size", button_font_size)

	var status_card: Panel = get_node_or_null("TopStatusCard") as Panel
	var status_width: float = clampf(viewport_size.x * 0.28, 340.0, 520.0)
	var status_right: float = 24.0
	if status_card != null:
		status_card.anchor_left = 0.0
		status_card.anchor_right = 0.0
		status_card.offset_left = viewport_size.x - status_width - status_right
		status_card.offset_top = 18.0
		status_card.offset_right = viewport_size.x - status_right
		status_card.offset_bottom = 128.0

	if top_actions_box != null:
		top_actions_box.visible = false

	if score_box != null:
		score_box.anchor_left = 0.0
		score_box.anchor_right = 0.0
		score_box.anchor_top = 0.0
		score_box.anchor_bottom = 0.0
		score_box.offset_left = viewport_size.x - status_width - status_right + 28.0
		score_box.offset_top = 28.0
		score_box.offset_right = viewport_size.x - status_right - 28.0
		score_box.offset_bottom = 112.0
		score_box.custom_minimum_size = Vector2(status_width - 56.0, 84.0)
		score_box.add_theme_constant_override("separation", 2)

	if score_label != null:
		score_label.add_theme_font_size_override("font_size", clampi(int(round(viewport_size.x * 0.014)), 22, 30))
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		score_label.custom_minimum_size = Vector2(status_width - 56.0, 76.0)
		var score_row: Control = score_label.get_parent() as Control
		if score_row != null:
			score_row.custom_minimum_size = Vector2(status_width - 56.0, 76.0)

func _ensure_menu_card():
	var menu_card: Panel = get_node_or_null("MenuCard") as Panel
	if menu_card == null:
		menu_card = Panel.new()
		menu_card.name = "MenuCard"
		menu_card.position = Vector2(48, 246)
		menu_card.size = Vector2(620, 660)
		menu_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(menu_card)
		move_child(menu_card, background.get_index() + 1)
	menu_card.z_index = 2
	menu_card.add_theme_stylebox_override("panel", _build_card_style(
		Color(0.15, 0.11, 0.08, 0.86),
		Color(0.72, 0.56, 0.37, 0.72)
	))

	var tint: ColorRect = get_node_or_null("MenuTint") as ColorRect
	if tint == null:
		tint = ColorRect.new()
		tint.name = "MenuTint"
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.color = Color(0.11, 0.07, 0.04, 0.14)
		add_child(tint)
		move_child(tint, background.get_index() + 1)
	tint.z_index = 1

func _ensure_subtitle():
	var subtitle: Label = get_node_or_null("SubtitleLabel") as Label
	if subtitle == null:
		subtitle = Label.new()
		subtitle.name = "SubtitleLabel"
		subtitle.position = Vector2(144, 286)
		subtitle.size = Vector2(560, 44)
		add_child(subtitle)
	subtitle.text = "Собирайте дрон, настраивайте схему и летите в испытания."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.89, 0.78, 0.66, 0.94))
	subtitle.z_index = 5

func _ensure_status_card():
	var status_card: Panel = get_node_or_null("TopStatusCard") as Panel
	if status_card == null:
		status_card = Panel.new()
		status_card.name = "TopStatusCard"
		status_card.anchor_left = 1.0
		status_card.anchor_right = 1.0
		status_card.offset_left = -760
		status_card.offset_top = 18
		status_card.offset_right = -18
		status_card.offset_bottom = 108
		status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(status_card)
		move_child(status_card, $VBoxContainer.get_index())
	status_card.z_index = 5
	status_card.add_theme_stylebox_override("panel", _build_card_style(
		Color(0.17, 0.12, 0.08, 0.88),
		Color(0.68, 0.52, 0.35, 0.64)
	))

func _style_main_button(button: Button, fill: Color, border: Color):
	if button == null:
		return
	button.custom_minimum_size = Vector2(0, 82)
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = border
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_right = 16
	normal.corner_radius_bottom_left = 16
	normal.content_margin_left = 22.0
	normal.content_margin_top = 18.0
	normal.content_margin_right = 22.0
	normal.content_margin_bottom = 18.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.08)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = fill.darkened(0.10)
	pressed.border_color = border

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

func _style_top_action_button(button: Button, fill: Color, border: Color):
	if button == null:
		return
	button.scale = Vector2.ONE
	button.clip_contents = false
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_constant_override("hseparation", 0)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = border
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_right = 16
	normal.corner_radius_bottom_left = 16
	normal.content_margin_left = 12.0
	normal.content_margin_top = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_bottom = 12.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.08)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

func _build_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 16
	return style

func _connect_buttons():
	start_button.pressed.connect(_on_start_pressed)
	assembly_button.pressed.connect(_on_assembly_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	if settings_button != null and not settings_button.is_connected("pressed", Callable(self, "_on_settings_pressed")):
		settings_button.pressed.connect(_on_settings_pressed)
	if tutorial_button != null:
		if not tutorial_button.is_connected("pressed", Callable(self, "_on_tutorial_pressed")):
			tutorial_button.pressed.connect(_on_tutorial_pressed)

func _ensure_settings_menu():
	if settings_menu != null and is_instance_valid(settings_menu):
		return
	var scene: PackedScene = preload("res://app/ui/SettingsScene.tscn")
	settings_menu = scene.instantiate()
	add_child(settings_menu)
	settings_menu.settings_saved.connect(_on_settings_saved)
	settings_menu.settings_cancelled.connect(_on_settings_cancelled)

func _connect_global_signals():
	Global.music_volume_changed.connect(_on_music_volume_changed)
	Global.brightness_changed.connect(_on_brightness_changed)

func update_score_display():
	score_label.text = Global.format_wallet_label(true)

func apply_music_volume():
	if audio_player == null:
		return
	var linear_value: float = clampf(Global.music_volume / 100.0, 0.0001, 1.0)
	audio_player.volume_db = linear_to_db(linear_value)

func apply_brightness():
	var canvas_modulate: CanvasModulate = get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas_modulate == null:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		add_child(canvas_modulate)
		move_child(canvas_modulate, 0)
	var value: float = Global.brightness
	canvas_modulate.color = Color(value, value, value, 1.0)

func _on_music_volume_changed(_value: float):
	apply_music_volume()

func _on_brightness_changed(_value: float):
	apply_brightness()

func _on_settings_saved():
	apply_music_volume()
	apply_brightness()
	update_score_display()

func _on_settings_cancelled():
	apply_music_volume()
	apply_brightness()

func _on_tutorial_pressed():
	if tut != null:
		tut.start_tutorial()

func _on_start_pressed():
	get_tree().change_scene_to_file("res://app/ui/game_level.tscn")

func _on_assembly_pressed():
	Global.load_scene_with_loading("res://app/assembly/create_dron.tscn")

func _on_shop_pressed():
	get_tree().change_scene_to_file("res://app/shop/shop.tscn")

func _on_exit_pressed():
	get_tree().quit()

func _on_settings_pressed():
	_ensure_settings_menu()
	settings_menu.open()
