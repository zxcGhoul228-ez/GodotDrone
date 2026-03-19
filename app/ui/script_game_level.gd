extends Control

var level_containers: Array[HBoxContainer] = []
var back_button: Button = null
var selected_level: int = 0
var level_button_scene: PackedScene = preload("res://app/ui/LevelButton.tscn")
var quests_button: Button = null
var quest_spacer: Control = null
var quest_popup: Control = null

@onready var background: TextureRect = $TextureRect

func _ready():
	_sync_root_rect()
	_prepare_background()
	await get_tree().process_frame
	_find_nodes()
	_ensure_quest_ui()
	_apply_visual_theme()
	_create_level_buttons()
	_layout_screen()

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

func _prepare_background():
	_sync_root_rect()
	if background == null:
		return
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = 1
	background.stretch_mode = 6
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = get_viewport_rect().size

func _find_nodes():
	level_containers.clear()
	var container_paths: Array[String] = [
		"CenterContainer/VBoxContainer/HBoxContainer",
		"CenterContainer2/VBoxContainer/HBoxContainer",
		"CenterContainer3/VBoxContainer/HBoxContainer"
	]

	for path in container_paths:
		var container: HBoxContainer = get_node_or_null(path) as HBoxContainer
		if container != null:
			level_containers.append(container)

	back_button = get_node_or_null("HBoxContainer/VBoxContainer/back_butt") as Button
	if back_button == null:
		back_button = find_child("back_butt", true, false) as Button
	if back_button == null:
		_create_fallback_back_button()
	elif not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

func _create_fallback_back_button():
	back_button = Button.new()
	back_button.name = "back_butt"
	back_button.text = "Назад"
	back_button.custom_minimum_size = Vector2(196, 70)
	back_button.position = Vector2(32, 26)
	back_button.pressed.connect(_on_back_pressed)
	add_child(back_button)

func _create_level_buttons():
	for container in level_containers:
		for child in container.get_children():
			if child is Button or child.has_method("set_level_number"):
				child.queue_free()

	for level in range(1, 16):
		var button_node: Node = level_button_scene.instantiate()
		var button: Button = button_node as Button
		if button == null:
			continue

		button.custom_minimum_size = Vector2(188, 154)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.set("font_size", 40)
		button.call("set_level_number", level)
		button.pressed.connect(_on_level_pressed.bind(level))

		if Global != null:
			button.call("set_level_data", Global.get_level_data(level))

		var container_index: int = int(floor((level - 1) / 5.0))
		if container_index >= 0 and container_index < level_containers.size():
			level_containers[container_index].add_child(button)

func _layout_screen():
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	_sync_root_rect()

	if background != null:
		background.position = Vector2.ZERO
		background.size = viewport_size

	var header_top: float = 28.0
	var title_height: float = clampf(viewport_size.y * 0.12, 104.0, 136.0)
	var title_width: float = clampf(viewport_size.x * 0.44, 520.0, 840.0)
	var row_width: float = clampf(viewport_size.x - 190.0, 1120.0, 1540.0)
	var row_height: float = clampf(viewport_size.y * 0.22, 214.0, 252.0)
	var row_gap: float = clampf(viewport_size.y * 0.018, 14.0, 22.0)
	var rows_start: float = header_top + title_height + 42.0
	var row_card_extra: float = 130.0
	var row_inner_margin: float = clampf(row_width * 0.14, 128.0, 190.0)
	var inter_button_gap: float = clampf(viewport_size.x * 0.018, 32.0, 44.0)
	var button_width: float = clampf((row_width - row_inner_margin * 2.0 - inter_button_gap * 4.0) / 5.0, 180.0, 198.0)
	var button_height: float = clampf(button_width * 0.82, 148.0, 160.0)

	var title_container: CenterContainer = get_node_or_null("CenterContainer4") as CenterContainer
	var title_label: Label = get_node_or_null("CenterContainer4/Label") as Label
	if title_container != null:
		title_container.anchor_left = 0.0
		title_container.anchor_right = 1.0
		title_container.anchor_top = 0.0
		title_container.anchor_bottom = 0.0
		title_container.offset_left = 0.0
		title_container.offset_top = header_top
		title_container.offset_right = 0.0
		title_container.offset_bottom = header_top + title_height
	if title_label != null:
		title_label.text = "Выбор уровня"
		title_label.custom_minimum_size = Vector2(title_width, title_height)
		title_label.add_theme_font_size_override("font_size", clampi(int(round(viewport_size.x * 0.042)), 64, 86))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var title_card: Panel = get_node_or_null("TitleCard") as Panel
	if title_card != null:
		title_card.anchor_left = 0.5
		title_card.anchor_right = 0.5
		title_card.offset_left = -0.5 * (title_width + 120.0)
		title_card.offset_right = 0.5 * (title_width + 120.0)
		title_card.offset_top = header_top - 8.0
		title_card.offset_bottom = header_top + title_height + 10.0

	var back_shell: HBoxContainer = get_node_or_null("HBoxContainer") as HBoxContainer
	if back_shell != null:
		back_shell.anchor_left = 0.0
		back_shell.anchor_right = 1.0
		back_shell.anchor_top = 0.0
		back_shell.anchor_bottom = 0.0
		back_shell.offset_left = 32.0
		back_shell.offset_top = 24.0
		back_shell.offset_right = -32.0
		back_shell.offset_bottom = 116.0
		back_shell.alignment = BoxContainer.ALIGNMENT_BEGIN

	if back_button != null:
		back_button.text = "Назад"
		back_button.custom_minimum_size = Vector2(196, 70)
		back_button.add_theme_font_size_override("font_size", 28)

	if quests_button != null:
		quests_button.custom_minimum_size = Vector2(188, 70)
		quests_button.add_theme_font_size_override("font_size", 26)

	for index in range(level_containers.size()):
		var container: HBoxContainer = level_containers[index]
		var row_box: VBoxContainer = container.get_parent() as VBoxContainer
		var center: CenterContainer = row_box.get_parent() as CenterContainer
		var row_top: float = rows_start + index * (row_height + row_gap)

		container.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_theme_constant_override("separation", int(inter_button_gap))
		container.custom_minimum_size = Vector2(button_width * 5.0 + inter_button_gap * 4.0, maxf(button_height + 10.0, row_height - 72.0))
		row_box.custom_minimum_size = Vector2(row_width, row_height)

		for child in container.get_children():
			var level_button: Button = child as Button
			if level_button == null:
				continue
			level_button.custom_minimum_size = Vector2(button_width, button_height)
			level_button.set("font_size", clampi(int(round(button_width * 0.24)), 34, 42))
			level_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			level_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if center != null:
			center.anchor_left = 0.0
			center.anchor_right = 1.0
			center.anchor_top = 0.0
			center.anchor_bottom = 0.0
			center.offset_left = 0.0
			center.offset_right = 0.0
			center.offset_top = row_top - 6.0
			center.offset_bottom = row_top + row_height - 18.0

		var row_card: Panel = get_node_or_null("RowCard%d" % index) as Panel
		if row_card != null:
			row_card.anchor_left = 0.5
			row_card.anchor_right = 0.5
			row_card.offset_left = -0.5 * (row_width + row_card_extra)
			row_card.offset_right = 0.5 * (row_width + row_card_extra)
			row_card.offset_top = row_top + 10.0
			row_card.offset_bottom = row_top + row_height - 4.0

func _apply_visual_theme():
	_ensure_background_tint()
	_ensure_row_cards()

	var title_label: Label = get_node_or_null("CenterContainer4/Label") as Label
	if title_label != null:
		title_label.text = "Выбор уровня"
		title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))

	if back_button != null:
		back_button.text = "Назад"
		_style_back_button(back_button)
	if quests_button != null:
		quests_button.text = "Квесты"
		_style_back_button(quests_button)

func _ensure_background_tint():
	var tint: ColorRect = get_node_or_null("LevelTint") as ColorRect
	if tint == null:
		tint = ColorRect.new()
		tint.name = "LevelTint"
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(0.11, 0.07, 0.04, 0.22)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint)
		move_child(tint, 1)

func _ensure_row_cards():
	for index in range(3):
		var card_name: String = "RowCard%d" % index
		var row_card: Panel = get_node_or_null(card_name) as Panel
		if row_card == null:
			row_card = Panel.new()
			row_card.name = card_name
			row_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(row_card)
			move_child(row_card, 2 + index)
		row_card.add_theme_stylebox_override("panel", _build_card_style(
			Color(0.16, 0.11, 0.08, 0.84),
			Color(0.73, 0.56, 0.37, 0.68)
		))

	var title_card: Panel = get_node_or_null("TitleCard") as Panel
	if title_card == null:
		title_card = Panel.new()
		title_card.name = "TitleCard"
		title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_card)
		move_child(title_card, 2)
	title_card.add_theme_stylebox_override("panel", _build_card_style(
		Color(0.14, 0.10, 0.07, 0.88),
		Color(0.80, 0.62, 0.40, 0.74)
	))

func _style_back_button(button: Button):
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.24, 0.17, 0.11, 0.97)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.78, 0.61, 0.40, 0.92)
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_right = 14
	normal.corner_radius_bottom_left = 14
	normal.content_margin_left = 18.0
	normal.content_margin_top = 12.0
	normal.content_margin_right = 18.0
	normal.content_margin_bottom = 12.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.31, 0.22, 0.15, 0.99)
	hover.border_color = Color(0.90, 0.71, 0.47, 0.98)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	button.add_theme_font_size_override("font_size", 28)

func _ensure_quest_ui() -> void:
	var back_shell: HBoxContainer = get_node_or_null("HBoxContainer") as HBoxContainer
	if back_shell == null:
		return

	if quest_spacer == null or not is_instance_valid(quest_spacer):
		quest_spacer = Control.new()
		quest_spacer.name = "QuestSpacer"
		quest_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if quests_button == null or not is_instance_valid(quests_button):
		quests_button = Button.new()
		quests_button.name = "QuestsButton"
		quests_button.text = "Квесты"
		quests_button.focus_mode = Control.FOCUS_NONE
		quests_button.pressed.connect(_on_quests_pressed)

	if quest_spacer.get_parent() != back_shell:
		back_shell.add_child(quest_spacer)

	if quests_button.get_parent() != back_shell:
		back_shell.add_child(quests_button)

	if quest_spacer.get_index() > quests_button.get_index():
		back_shell.move_child(quest_spacer, quests_button.get_index())

	if quest_popup == null or not is_instance_valid(quest_popup):
		var popup_script: Script = load("res://app/ui/QuestPopup.gd")
		if popup_script != null:
			quest_popup = popup_script.new()
			add_child(quest_popup)
			if quest_popup.has_method("set_popup_title"):
				quest_popup.call("set_popup_title", "Квесты уровней")

func _on_quests_pressed() -> void:
	if quest_popup != null and is_instance_valid(quest_popup) and quest_popup.has_method("toggle"):
		quest_popup.call("toggle")

func _build_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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

func _on_level_pressed(level_number: int):
	selected_level = level_number
	var timer := Timer.new()
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_load_level)
	timer.start(0.1)

func _load_level():
	if Global != null:
		Global.current_level = selected_level

	var level_path: String = "res://app/flight/levels/Level%d.tscn" % selected_level
	if not FileAccess.file_exists(level_path):
		level_path = "res://app/flight/DroneScene.tscn"

	Global.load_scene_with_loading(level_path)

func _on_back_pressed():
	var path: String = "res://app/main_menu/main_scene.tscn"
	if not ResourceLoader.exists(path):
		push_error("Не найдена сцена: " + path)
		return
	get_tree().change_scene_to_file(path)
