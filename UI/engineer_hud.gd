extends CanvasLayer

var panel: Panel
var label: Label
var danger_bar: ColorRect

func _ready() -> void:
	_create_ui()
	set_process(true)

func _process(_delta: float) -> void:
	var creator: Node = get_parent()
	if creator == null:
		return

	var stats_variant = creator.get("drone_stats")
	if stats_variant == null:
		return

	var stats: Dictionary = stats_variant as Dictionary
	_update_text(stats)

# ================= UI =================

func _create_ui() -> void:
	panel = Panel.new()

	# === Якоря: ВЕРХ-ПРАВО ===
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0

	# === Отступы от правого верхнего угла ===
	panel.offset_left = -440   # ширина панели + отступ
	panel.offset_top = 20
	panel.offset_right = -20
	panel.offset_bottom = 280  # высота панели

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.9)
	style.border_color = Color(0.2, 0.8, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	label = Label.new()
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_top = 12
	label.offset_right = -12
	label.offset_bottom = -22

	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
	panel.add_child(label)

	danger_bar = ColorRect.new()
	danger_bar.anchor_left = 0.0
	danger_bar.anchor_top = 1.0
	danger_bar.anchor_right = 1.0
	danger_bar.anchor_bottom = 1.0
	danger_bar.offset_left = 0
	danger_bar.offset_top = -10
	danger_bar.offset_right = 0
	danger_bar.offset_bottom = 0
	danger_bar.color = Color.GREEN

	panel.add_child(danger_bar)


# ================= DATA =================

func _update_text(stats: Dictionary) -> void:
	var mass: float = float(stats.get("total_mass", 0.0))
	var thrust: float = float(stats.get("total_thrust", 0.0))
	var motors_missing: int = int(stats.get("missing_motors", 0))
	var balanced: bool = bool(stats.get("is_balanced", false))

	var ratio: float = thrust / max(mass, 0.1)

	var text: String = ""
	text += "ИНЖЕНЕРНЫЙ АНАЛИЗ ДРОНА\n"
	text += "────────────────────────\n"
	text += "Масса: %.2f кг\n" % mass
	text += "Тяга: %.2f ед.\n" % thrust
	text += "Тяга / Масса: %.2f\n\n" % ratio

	if balanced:
		text += "Состояние: ✅ СБАЛАНСИРОВАН\n"
		danger_bar.color = Color(0.2, 0.9, 0.3)
	else:
		text += "Состояние: ❌ НЕСБАЛАНСИРОВАН\n"
		text += "Не хватает моторов: %d\n" % motors_missing
		danger_bar.color = Color(0.9, 0.2, 0.2)

	if ratio < 1.0:
		text += "\n⚠️ ТЯГИ НЕДОСТАТОЧНО ДЛЯ ВЗЛЁТА"
	elif ratio < 1.5:
		text += "\n⚠️ ВЗЛЁТ ВОЗМОЖЕН, НО НЕСТАБИЛЕН"
	else:
		text += "\n✅ ЗАПАС ТЯГИ ДОСТАТОЧЕН"

	label.text = text
