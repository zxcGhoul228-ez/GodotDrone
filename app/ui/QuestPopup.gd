extends Control

signal popup_closed

var popup_title: String = "Квесты пилота"
var status_note: String = ""

var backdrop: ColorRect = null
var panel: Panel = null
var title_label: Label = null
var summary_label: Label = null
var quest_scroll: ScrollContainer = null
var quest_list: VBoxContainer = null
var refresh_button: Button = null
var close_button: Button = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if Global != null and not Global.quests_changed.is_connected(_refresh_view):
		Global.quests_changed.connect(_refresh_view)

func set_popup_title(value: String) -> void:
	popup_title = value
	if title_label != null:
		title_label.text = popup_title

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	status_note = ""
	_refresh_view()
	visible = true
	move_to_front()

func close() -> void:
	if not visible:
		return
	visible = false
	popup_closed.emit()

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.07, 0.04, 0.03, 0.76)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = Panel.new()
	panel.custom_minimum_size = Vector2(920, 760)
	panel.add_theme_stylebox_override("panel", _build_panel_style(Color(0.16, 0.11, 0.08, 0.96), Color(0.82, 0.64, 0.40, 0.88), 28))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 8)
	header.add_child(title_box)

	title_label = Label.new()
	title_label.text = popup_title
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	title_box.add_child(title_label)

	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 20)
	summary_label.add_theme_color_override("font_color", Color(0.87, 0.78, 0.67))
	title_box.add_child(summary_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	header.add_child(actions)

	refresh_button = Button.new()
	refresh_button.custom_minimum_size = Vector2(210, 58)
	refresh_button.focus_mode = Control.FOCUS_NONE
	refresh_button.pressed.connect(_on_refresh_pressed)
	_style_button(refresh_button, Color(0.40, 0.28, 0.18, 0.98), Color(0.90, 0.71, 0.47, 0.95))
	actions.add_child(refresh_button)

	close_button = Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size = Vector2(170, 58)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	_style_button(close_button, Color(0.32, 0.22, 0.14, 0.98), Color(0.84, 0.66, 0.42, 0.94))
	actions.add_child(close_button)

	quest_scroll = ScrollContainer.new()
	quest_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_scroll.follow_focus = true
	root.add_child(quest_scroll)

	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_constant_override("separation", 14)
	quest_scroll.add_child(quest_list)

func _refresh_view() -> void:
	if title_label != null:
		title_label.text = popup_title
	if quest_list == null:
		return

	for child in quest_list.get_children():
		child.queue_free()

	var entries: Array = Global.get_quest_entries() if Global != null else []
	entries.sort_custom(Callable(self, "_sort_quests"))

	var completed_count: int = 0
	var claimed_count: int = 0
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		if bool(entry.get("completed", false)):
			completed_count += 1
		if bool(entry.get("claimed", false)):
			claimed_count += 1
		quest_list.add_child(_build_quest_card(entry))

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Все квесты уже выполнены."
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.add_theme_color_override("font_color", Color(0.95, 0.87, 0.78))
		quest_list.add_child(empty_label)

	var crystals_text: int = Global.crystals if Global != null else 0
	var refresh_cost: int = Global.get_quest_refresh_cost() if Global != null else 0
	var max_active: int = Global.MAX_ACTIVE_QUESTS if Global != null else 3
	if summary_label != null:
		var summary := "Активно: %d/%d   Выполнено: %d   Получено: %d   Кристаллы: %d   Обновить: %d монет" % [
			entries.size(),
			max_active,
			completed_count,
			claimed_count,
			crystals_text,
			refresh_cost
		]
		if not status_note.is_empty():
			summary += "\n" + status_note
		summary_label.text = summary

	if refresh_button != null:
		refresh_button.text = "Обновить за %d" % refresh_cost

func _build_quest_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _build_panel_style(
		Color(0.21, 0.15, 0.10, 0.96),
		Color(0.73, 0.56, 0.37, 0.78),
		20
	))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	header.add_child(title_box)

	var title := Label.new()
	title.text = str(entry.get("title", "Квест"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	title_box.add_child(title)

	var description := Label.new()
	description.text = str(entry.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 18)
	description.add_theme_color_override("font_color", Color(0.88, 0.79, 0.68))
	title_box.add_child(description)

	var reward := Label.new()
	reward.text = "+%d крист." % int(entry.get("reward", 0))
	reward.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 22)
	reward.add_theme_color_override("font_color", Color(0.95, 0.76, 0.46))
	header.add_child(reward)

	var progress_bar := ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = maxf(float(entry.get("goal", 1)), 1.0)
	progress_bar.value = clampf(float(entry.get("progress", 0)), 0.0, progress_bar.max_value)
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 18)
	_style_progress(progress_bar)
	root.add_child(progress_bar)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	root.add_child(footer)

	var progress_label := Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.text = "%d / %d" % [int(entry.get("progress", 0)), int(entry.get("goal", 0))]
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.65))
	footer.add_child(progress_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(190, 46)
	action_button.focus_mode = Control.FOCUS_NONE
	var quest_id: String = str(entry.get("id", ""))
	if bool(entry.get("claimed", false)):
		action_button.text = "Получено"
		action_button.disabled = true
		_style_button(action_button, Color(0.23, 0.18, 0.13, 0.98), Color(0.52, 0.42, 0.30, 0.72))
	elif bool(entry.get("completed", false)):
		action_button.text = "Забрать"
		action_button.pressed.connect(_on_claim_pressed.bind(quest_id))
		_style_button(action_button, Color(0.46, 0.31, 0.18, 0.98), Color(0.92, 0.73, 0.46, 0.95))
	else:
		action_button.text = "В процессе"
		action_button.disabled = true
		_style_button(action_button, Color(0.25, 0.18, 0.12, 0.98), Color(0.61, 0.49, 0.33, 0.74))
	footer.add_child(action_button)

	return card

func _style_progress(bar: ProgressBar) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.11, 0.08, 0.06, 0.88)
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_left = 8
	background.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.84, 0.63, 0.34, 0.96)
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("fill", fill)

func _style_button(button: Button, fill: Color, border: Color) -> void:
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
	normal.content_margin_left = 18.0
	normal.content_margin_top = 10.0
	normal.content_margin_right = 18.0
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 18
	return style

func _sort_quests(a: Variant, b: Variant) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return true
	var quest_a: Dictionary = a
	var quest_b: Dictionary = b
	if bool(quest_a.get("claimed", false)) != bool(quest_b.get("claimed", false)):
		return not bool(quest_a.get("claimed", false))
	if bool(quest_a.get("completed", false)) != bool(quest_b.get("completed", false)):
		return bool(quest_a.get("completed", false))
	var progress_a: float = float(quest_a.get("progress", 0)) / maxf(float(quest_a.get("goal", 1)), 1.0)
	var progress_b: float = float(quest_b.get("progress", 0)) / maxf(float(quest_b.get("goal", 1)), 1.0)
	return progress_a > progress_b

func _on_claim_pressed(quest_id: String) -> void:
	if Global != null:
		Global.claim_quest_reward(quest_id)
	status_note = "Награда получена."
	_refresh_view()

func _on_refresh_pressed() -> void:
	if Global == null:
		return
	if Global.refresh_active_quests():
		status_note = "Список квестов обновлен."
	else:
		status_note = "Недостаточно монет для обновления списка."
	_refresh_view()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
