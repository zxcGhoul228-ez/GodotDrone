extends CanvasLayer

const PANEL_MIN_SIZE: Vector2 = Vector2(760.0, 440.0)

var tutorial_id: String = ""
var tutorial_title: String = "Обучение"
var tutorial_steps: Array[Dictionary] = []
var current_step: int = 0

var backdrop: ColorRect
var panel: Panel
var title_label: Label
var step_label: Label
var body_label: RichTextLabel
var footer_label: Label
var prev_button: Button
var next_button: Button
var close_button: Button

func _ready():
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func setup(section_id: String, section_title: String, steps: Array) -> void:
	tutorial_id = section_id
	tutorial_title = section_title
	tutorial_steps.clear()

	for step_value in steps:
		if step_value is Dictionary:
			tutorial_steps.append(step_value)

	current_step = 0
	_refresh_content()

func toggle() -> void:
	if visible:
		hide_popup()
	else:
		show_popup()

func show_popup() -> void:
	visible = true
	get_tree().paused = false
	_refresh_content()

func hide_popup() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_F1:
			hide_popup()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		hide_popup()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	if backdrop != null:
		return

	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.09, 0.06, 0.04, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = PANEL_MIN_SIZE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _build_panel_style(
		Color(0.18, 0.12, 0.08, 0.97),
		Color(0.76, 0.58, 0.37, 0.92)
	))
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))
	root.add_child(title_label)

	step_label = Label.new()
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 18)
	step_label.add_theme_color_override("font_color", Color(0.86, 0.74, 0.60))
	root.add_child(step_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = false
	body_label.scroll_active = true
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.custom_minimum_size = Vector2(0.0, 220.0)
	body_label.add_theme_font_size_override("normal_font_size", 22)
	body_label.add_theme_color_override("default_color", Color(0.95, 0.89, 0.81))
	root.add_child(body_label)

	footer_label = Label.new()
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.add_theme_font_size_override("font_size", 16)
	footer_label.add_theme_color_override("font_color", Color(0.84, 0.72, 0.58))
	footer_label.text = "F1 или Esc - закрыть. Правая кнопка мыши тоже закрывает окно."
	root.add_child(footer_label)

	var footer_buttons: HBoxContainer = HBoxContainer.new()
	footer_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_buttons.add_theme_constant_override("separation", 16)
	root.add_child(footer_buttons)

	prev_button = Button.new()
	prev_button.text = "Назад"
	prev_button.pressed.connect(_on_prev_pressed)
	_style_button(prev_button, Color(0.25, 0.18, 0.12, 0.98), Color(0.73, 0.56, 0.37, 0.88))
	footer_buttons.add_child(prev_button)

	next_button = Button.new()
	next_button.text = "Далее"
	next_button.pressed.connect(_on_next_pressed)
	_style_button(next_button, Color(0.35, 0.24, 0.16, 0.98), Color(0.86, 0.67, 0.44, 0.96))
	footer_buttons.add_child(next_button)

	close_button = Button.new()
	close_button.text = "Закрыть"
	close_button.pressed.connect(hide_popup)
	_style_button(close_button, Color(0.30, 0.18, 0.14, 0.98), Color(0.79, 0.46, 0.34, 0.92))
	footer_buttons.add_child(close_button)

func _refresh_content() -> void:
	if title_label == null or body_label == null or step_label == null:
		return

	title_label.text = tutorial_title

	if tutorial_steps.is_empty():
		step_label.text = "Обучение пока недоступно"
		body_label.text = "Для этого раздела шаги обучения ещё не настроены."
		if prev_button != null:
			prev_button.disabled = true
		if next_button != null:
			next_button.disabled = true
		return

	current_step = clampi(current_step, 0, tutorial_steps.size() - 1)
	var step_data: Dictionary = tutorial_steps[current_step]
	var step_title: String = str(step_data.get("title", "Шаг"))
	var step_text: String = str(step_data.get("text", ""))

	step_label.text = "Шаг %d из %d: %s" % [current_step + 1, tutorial_steps.size(), step_title]
	body_label.text = step_text

	if prev_button != null:
		prev_button.disabled = current_step <= 0
	if next_button != null:
		next_button.disabled = current_step >= tutorial_steps.size() - 1

func _on_prev_pressed() -> void:
	if current_step <= 0:
		return
	current_step -= 1
	_refresh_content()

func _on_next_pressed() -> void:
	if current_step >= tutorial_steps.size() - 1:
		return
	current_step += 1
	_refresh_content()

func _style_button(button: Button, fill: Color, border: Color) -> void:
	button.custom_minimum_size = Vector2(156.0, 52.0)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = border
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_right = 14
	normal.corner_radius_bottom_left = 14
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

func _build_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 18
	return style
