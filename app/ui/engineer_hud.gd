extends CanvasLayer

var panel: Panel
var title_label: Label
var body_label: Label
var state_strip: ColorRect

func _ready() -> void:
	_create_ui()
	set_process(true)

func _process(_delta: float) -> void:
	var creator: Node = get_parent()
	if creator == null:
		return

	var stats_variant: Variant = creator.get("drone_stats")
	if typeof(stats_variant) != TYPE_DICTIONARY:
		return

	var stats: Dictionary = stats_variant
	_update_text(stats)

func _create_ui() -> void:
	panel = Panel.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -430
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = 280
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(panel)

	title_label = Label.new()
	title_label.anchor_left = 0.0
	title_label.anchor_top = 0.0
	title_label.anchor_right = 1.0
	title_label.anchor_bottom = 0.0
	title_label.offset_left = 18
	title_label.offset_top = 14
	title_label.offset_right = -18
	title_label.offset_bottom = 46
	title_label.text = "Инженерный анализ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.86))
	panel.add_child(title_label)

	body_label = Label.new()
	body_label.anchor_left = 0.0
	body_label.anchor_top = 0.0
	body_label.anchor_right = 1.0
	body_label.anchor_bottom = 1.0
	body_label.offset_left = 18
	body_label.offset_top = 54
	body_label.offset_right = -18
	body_label.offset_bottom = -24
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_label.add_theme_font_size_override("font_size", 16)
	body_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	panel.add_child(body_label)

	state_strip = ColorRect.new()
	state_strip.anchor_left = 0.0
	state_strip.anchor_top = 1.0
	state_strip.anchor_right = 1.0
	state_strip.anchor_bottom = 1.0
	state_strip.offset_left = 0
	state_strip.offset_top = -12
	state_strip.offset_right = 0
	state_strip.offset_bottom = 0
	state_strip.color = Color(0.72, 0.56, 0.36)
	panel.add_child(state_strip)

func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.08, 0.94)
	style.border_color = Color(0.78, 0.59, 0.38, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 12
	return style

func _update_text(stats: Dictionary) -> void:
	var mass: float = float(stats.get("total_mass", 0.0))
	var thrust: float = float(stats.get("total_thrust", 0.0))
	var motors_missing: int = int(stats.get("missing_motors", 0))
	var balanced: bool = bool(stats.get("is_balanced", false))
	var ratio: float = thrust / maxf(mass, 0.1)

	var lines: PackedStringArray = []
	lines.append("Масса: %.2f кг" % mass)
	lines.append("Тяга: %.2f ед." % thrust)
	lines.append("Тяга / масса: %.2f" % ratio)

	if balanced:
		lines.append("Баланс: стабилен")
		state_strip.color = Color(0.72, 0.56, 0.36)
	else:
		lines.append("Баланс: нарушен")
		lines.append("Пустых моторных слотов: %d" % motors_missing)
		state_strip.color = Color(0.70, 0.32, 0.24)

	if ratio < 1.0:
		lines.append("Вердикт: тяги недостаточно для уверенного взлета.")
	elif ratio < 1.5:
		lines.append("Вердикт: взлет возможен, но дрон будет нервным.")
	else:
		lines.append("Вердикт: запас тяги достаточный.")

	body_label.text = "\n".join(lines)
