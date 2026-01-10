extends Control

@onready var graph: GraphEdit = $GraphEdit
@onready var status_label: Label = $TopBar/StatusLabel

const SAVE_PATH: String = "user://drone_connections.json"
const CREATE_DRONE_SCENE_PATH: String = "res://create_drone/create_dron.tscn"
const MAIN_MENU_SCENE_PATH: String = "main_scene.tscn"

var drone_info: Dictionary = {}
var connections: Array = [] # [{from_node, from_port, to_node, to_port}]

# (кнопки на сцене могут быть удалены — поэтому берём безопасно)
var btn_save: Button = null
var btn_auto: Button = null
var btn_back: Button = null

# Меню настроек (SettingsScene)
var settings_menu = null

# ESC-МЕНЮ
var _pause_layer: CanvasLayer = null
var _pause_overlay: Control = null
var _pause_panel: Panel = null
var _pause_open: bool = false
var _pause_tween: Tween = null


func _ready() -> void:
	# кнопки сверху (если ты их уберёшь из сцены — ошибок не будет)
	var top := get_node_or_null("TopBar")
	if top != null:
		btn_save = (top as Node).get_node_or_null("SaveButton") as Button
		btn_auto = (top as Node).get_node_or_null("AutoButton") as Button
		btn_back = (top as Node).get_node_or_null("BackButton") as Button

	if btn_save != null:
		btn_save.pressed.connect(_on_save_pressed)
	if btn_auto != null:
		btn_auto.pressed.connect(_on_auto_pressed)
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)

	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)

	_load_settings_menu()
	_ensure_pause_menu()

	_load_drone_info()
	_build_graph()
	_load_connections()
	_apply_connections()
	_update_status()


func _input(event: InputEvent) -> void:
	# ESC -> меню
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_menu != null and settings_menu.has_method("is_open") and bool(settings_menu.call("is_open")):
			return
		_toggle_pause_menu(not _pause_open)
		get_viewport().set_input_as_handled()
		return

	# Если меню открыто — блокируем граф
	if _pause_open:
		return

	# Если настройки открыты — тоже блокируем
	if settings_menu != null and settings_menu.has_method("is_open") and bool(settings_menu.call("is_open")):
		return


# ==================== SETTINGS SCENE ====================
func _load_settings_menu() -> void:
	if settings_menu != null and is_instance_valid(settings_menu):
		return

	var settings_scene: PackedScene = preload("res://UI/SettingsScene.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)


# ==================== DRONE INFO ====================
func _load_drone_info() -> void:
	drone_info = {}
	if FileAccess.file_exists("user://exported_drone.tscn"):
		var packed: PackedScene = ResourceLoader.load("user://exported_drone.tscn") as PackedScene
		if packed:
			var inst: Node = packed.instantiate()
			if inst and inst.has_meta("drone_info"):
				var v: Variant = inst.get_meta("drone_info")
				if typeof(v) == TYPE_DICTIONARY:
					drone_info = v as Dictionary
			inst.queue_free()

	if drone_info.is_empty():
		drone_info = {"motor_count": 0, "propeller_count": 0}


# ==================== GRAPH BUILD ====================
func _build_graph() -> void:
	for c in graph.get_children():
		if c is GraphNode:
			(c as Node).queue_free()

	var motor_count: int = int(drone_info.get("motor_count", 0))
	var prop_count: int = int(drone_info.get("propeller_count", 0))

	# Board
	var board: GraphNode = _make_node("Board", "Плата", Vector2(80, 120))
	board.set_slot(0, false, 0, Color.WHITE, true, 0, Color.WHITE) # выход
	graph.add_child(board)

	# Motors
	for i in range(motor_count):
		var mn: GraphNode = _make_node("Motor_%d" % (i + 1), "Мотор %d" % (i + 1), Vector2(380, 80 + i * 120))
		mn.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE) # input
		mn.set_slot(1, false, 0, Color.WHITE, true, 0, Color.WHITE) # output
		graph.add_child(mn)

	# Propellers
	for i in range(prop_count):
		var pn: GraphNode = _make_node("Prop_%d" % (i + 1), "Проп %d" % (i + 1), Vector2(700, 80 + i * 120))
		pn.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
		graph.add_child(pn)

func _make_node(name_id: String, title: String, pos: Vector2) -> GraphNode:
	var n: GraphNode = GraphNode.new()
	n.name = name_id
	n.title = title
	n.position_offset = pos
	n.resizable = false

	var lbl: Label = Label.new()
	lbl.text = title
	n.add_child(lbl)
	return n


# ==================== CONNECTION RULES ====================
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var fn: String = String(from_node)
	var tn: String = String(to_node)

	if fn == "Board" and tn.begins_with("Motor_") and from_port == 0 and to_port == 0:
		graph.connect_node(from_node, from_port, to_node, to_port)
		_store_connection(from_node, from_port, to_node, to_port)
		_update_status()
		return

	if fn.begins_with("Motor_") and tn.begins_with("Prop_") and from_port == 1 and to_port == 0:
		graph.connect_node(from_node, from_port, to_node, to_port)
		_store_connection(from_node, from_port, to_node, to_port)
		_update_status()
		return

	status_label.text = "❌ Нельзя так соединить"

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	_remove_connection(from_node, from_port, to_node, to_port)
	_update_status()


# ==================== SAVE / LOAD ====================
func _store_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var rec: Dictionary = {"from_node": String(from_node), "from_port": from_port, "to_node": String(to_node), "to_port": to_port}
	for c in connections:
		if c == rec:
			return
	connections.append(rec)

func _remove_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var fn: String = String(from_node)
	var tn: String = String(to_node)
	for i in range(connections.size() - 1, -1, -1):
		var d: Dictionary = connections[i] as Dictionary
		if str(d.get("from_node","")) == fn and int(d.get("from_port", -1)) == from_port \
		and str(d.get("to_node","")) == tn and int(d.get("to_port", -1)) == to_port:
			connections.remove_at(i)

func _on_auto_pressed() -> void:
	var motor_count: int = int(drone_info.get("motor_count", 0))
	var prop_count: int = int(drone_info.get("propeller_count", 0))

	_clear_all_connections()

	for i in range(motor_count):
		var mn: StringName = StringName("Motor_%d" % (i + 1))
		if graph.has_node(NodePath(mn)):
			graph.connect_node("Board", 0, mn, 0)
			_store_connection("Board", 0, mn, 0)

	for i in range(min(motor_count, prop_count)):
		var mn2: StringName = StringName("Motor_%d" % (i + 1))
		var pn2: StringName = StringName("Prop_%d" % (i + 1))
		if graph.has_node(NodePath(mn2)) and graph.has_node(NodePath(pn2)):
			graph.connect_node(mn2, 1, pn2, 0)
			_store_connection(mn2, 1, pn2, 0)

	_update_status()

func _clear_all_connections() -> void:
	for c in graph.get_connection_list():
		var d: Dictionary = c as Dictionary
		graph.disconnect_node(
			StringName(str(d.get("from_node",""))),
			int(d.get("from_port", 0)),
			StringName(str(d.get("to_node",""))),
			int(d.get("to_port", 0))
		)
	connections.clear()

func _on_save_pressed() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"connections": connections, "drone_info": drone_info}))
		file.close()
	status_label.text = "✅ Подключения сохранены"

func _load_connections() -> void:
	connections.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var s: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(s) != OK:
		return
	var v: Variant = json.data
	if typeof(v) != TYPE_DICTIONARY:
		return
	var d: Dictionary = v as Dictionary
	var arr: Array = d.get("connections", []) as Array
	for x in arr:
		if typeof(x) == TYPE_DICTIONARY:
			connections.append(x)

func _apply_connections() -> void:
	for c in connections:
		var d: Dictionary = c as Dictionary
		var fn: StringName = StringName(str(d.get("from_node","")))
		var tn: StringName = StringName(str(d.get("to_node","")))
		var fp: int = int(d.get("from_port", 0))
		var tp: int = int(d.get("to_port", 0))
		if graph.has_node(NodePath(fn)) and graph.has_node(NodePath(tn)):
			if not graph.is_node_connected(fn, fp, tn, tp):
				graph.connect_node(fn, fp, tn, tp)

func _update_status() -> void:
	var motor_count: int = int(drone_info.get("motor_count", 0))
	var prop_count: int = int(drone_info.get("propeller_count", 0))

	var board_to_motors: int = 0
	var motor_to_props: int = 0

	for c in connections:
		var d: Dictionary = c as Dictionary
		var fn: String = str(d.get("from_node",""))
		var tn: String = str(d.get("to_node",""))
		var fp: int = int(d.get("from_port", -1))
		var tp: int = int(d.get("to_port", -1))
		if fn == "Board" and tn.begins_with("Motor_") and fp == 0 and tp == 0:
			board_to_motors += 1
		if fn.begins_with("Motor_") and tn.begins_with("Prop_") and fp == 1 and tp == 0:
			motor_to_props += 1

	status_label.text = "Board→Motors: %d/%d | Motors→Props: %d/%d" % [
		board_to_motors, motor_count,
		motor_to_props, min(motor_count, prop_count)
	]

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CREATE_DRONE_SCENE_PATH)


# ==================== ESC-МЕНЮ (ПО ЦЕНТРУ) ====================
func _ensure_pause_menu() -> void:
	if _pause_layer != null and is_instance_valid(_pause_layer):
		return

	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseMenuLayer"
	_pause_layer.layer = 500
	add_child(_pause_layer)

	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(_pause_overlay)

	_pause_overlay.gui_input.connect(_on_pause_overlay_gui_input)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dim)

	_pause_panel = Panel.new()
	_pause_panel.size = Vector2(420, 380)
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -_pause_panel.size.x * 0.5
	_pause_panel.offset_top = -_pause_panel.size.y * 0.5
	_pause_panel.offset_right = _pause_panel.size.x * 0.5
	_pause_panel.offset_bottom = _pause_panel.size.y * 0.5
	_pause_panel.pivot_offset = _pause_panel.size * 0.5
	_pause_panel.scale = Vector2(0.92, 0.92)
	_pause_panel.modulate.a = 0.0
	_pause_overlay.add_child(_pause_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.96)
	style.border_color = Color(0.3, 0.5, 1.0, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	_pause_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_top = 18
	vbox.offset_right = -18
	vbox.offset_bottom = -18
	vbox.add_theme_constant_override("separation", 8)
	_pause_panel.add_child(vbox)

	var title := Label.new()
	title.text = "МЕНЮ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "ESC — закрыть меню"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1,1,1,0.75)
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_pm_btn("▶ Продолжить", Callable(self, "_pm_resume")))
	vbox.add_child(_pm_btn("🤖 Авто", Callable(self, "_pm_auto")))
	vbox.add_child(_pm_btn("💾 Сохранить", Callable(self, "_pm_save")))
	vbox.add_child(_pm_btn("⚙ Настройки", Callable(self, "_pm_settings")))
	vbox.add_child(_pm_btn("← Назад в сборку", Callable(self, "_pm_back")))
	vbox.add_child(_pm_btn("🏠 В главное меню", Callable(self, "_pm_main_menu")))
	vbox.add_child(_pm_btn("⛔ Выйти из игры", Callable(self, "_pm_quit")))

func _pm_btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _toggle_pause_menu(open: bool) -> void:
	_ensure_pause_menu()
	_pause_open = open
	_pause_overlay.visible = true

	if _pause_tween != null and is_instance_valid(_pause_tween):
		_pause_tween.kill()

	if open:
		_pause_panel.scale = Vector2(0.92, 0.92)
		_pause_panel.modulate.a = 0.0

	_pause_tween = create_tween()
	_pause_tween.set_trans(Tween.TRANS_QUAD)
	_pause_tween.set_ease(Tween.EASE_OUT)

	if open:
		_pause_tween.tween_property(_pause_panel, "modulate:a", 1.0, 0.12)
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2(1, 1), 0.14)
	else:
		_pause_tween.tween_property(_pause_panel, "modulate:a", 0.0, 0.10)
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2(0.92, 0.92), 0.10)
		_pause_tween.tween_callback(Callable(self, "_pm_hide_overlay"))

func _pm_hide_overlay() -> void:
	if (not _pause_open) and _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false

func _on_pause_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_pause_menu(false)

func _pm_resume() -> void:
	_toggle_pause_menu(false)

func _pm_auto() -> void:
	_toggle_pause_menu(false)
	_on_auto_pressed()

func _pm_save() -> void:
	_toggle_pause_menu(false)
	_on_save_pressed()

func _pm_settings() -> void:
	_toggle_pause_menu(false)
	if settings_menu != null and settings_menu.has_method("open"):
		settings_menu.call("open")

func _pm_back() -> void:
	_toggle_pause_menu(false)
	_on_back_pressed()

func _pm_main_menu() -> void:
	_toggle_pause_menu(false)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _pm_quit() -> void:
	get_tree().quit()
