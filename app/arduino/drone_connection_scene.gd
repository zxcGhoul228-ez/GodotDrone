extends Control

const CREATE_DRONE_SCENE_PATH := "res://app/assembly/create_dron.tscn"
const MAIN_MENU_SCENE_PATH := "res://app/main_menu/main_scene.tscn"
const SLOT_NAMES := ["Передний правый", "Передний левый", "Задний правый", "Задний левый"]

@onready var graph: GraphEdit = $Background/MarginContainer/MainVBox/ContentSplit/GraphPanel/GraphMargin/GraphEdit
@onready var status_label: Label = $Background/MarginContainer/MainVBox/TopBar/StatusPanel/StatusMargin/StatusLabel
@onready var drone_summary_label: Label = $Background/MarginContainer/MainVBox/ContentSplit/LeftPanel/LeftMargin/LeftVBox/DroneSummaryLabel
@onready var pin_legend_label: Label = $Background/MarginContainer/MainVBox/ContentSplit/LeftPanel/LeftMargin/LeftVBox/PinLegendLabel
@onready var wiring_summary_label: Label = $Background/MarginContainer/MainVBox/ContentSplit/LeftPanel/LeftMargin/LeftVBox/WiringSummaryLabel
@onready var checklist_label: Label = $Background/MarginContainer/MainVBox/ContentSplit/RightPanel/RightMargin/RightVBox/ChecklistLabel
@onready var tips_label: Label = $Background/MarginContainer/MainVBox/ContentSplit/RightPanel/RightMargin/RightVBox/TipsLabel
@onready var auto_button: Button = $Background/MarginContainer/MainVBox/TopBar/AutoButton
@onready var save_button: Button = $Background/MarginContainer/MainVBox/TopBar/SaveButton
@onready var back_button: Button = $Background/MarginContainer/MainVBox/TopBar/BackButton
@onready var settings_button: Button = $Background/MarginContainer/MainVBox/ContentSplit/RightPanel/RightMargin/RightVBox/SettingsButton
@onready var reset_button: Button = $Background/MarginContainer/MainVBox/ContentSplit/RightPanel/RightMargin/RightVBox/ResetButton

var settings_menu = null
var drone_info: Dictionary = {}
var drone_signature := "пусто"
var board_present := false
var connections: Array = []
var motor_infos: Array = []
var prop_infos: Array = []

var _pause_layer: CanvasLayer = null
var _pause_overlay: Control = null
var _pause_panel: Panel = null
var _pause_center: CenterContainer = null
var _pause_open := false
var _pause_tween: Tween = null

func _ready():
	_configure_graph()
	_apply_visual_theme()
	_connect_ui()
	_load_settings_menu()
	_ensure_pause_menu()
	_load_drone_info()
	_build_component_infos()
	_build_graph()
	_restore_saved_wiring()
	_refresh_sidebar()
	_update_status()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if settings_menu != null and settings_menu.has_method("is_open") and bool(settings_menu.call("is_open")):
			return
		_toggle_pause_menu(not _pause_open)
		get_viewport().set_input_as_handled()

func _configure_graph():
	graph.show_grid = true
	graph.snapping_enabled = true
	graph.zoom_min = 0.5
	graph.zoom_max = 1.5
	graph.connection_lines_curvature = 0.45

func _apply_visual_theme():
	if graph != null:
		graph.add_theme_stylebox_override("panel", _build_card_style(Color(0.14, 0.10, 0.07, 0.94), Color(0.72, 0.56, 0.37, 0.72)))
		graph.add_theme_color_override("grid_minor", Color(0.25, 0.19, 0.14, 0.92))
		graph.add_theme_color_override("grid_major", Color(0.41, 0.31, 0.23, 0.98))
		graph.add_theme_color_override("selection_fill", Color(0.76, 0.58, 0.37, 0.14))
		graph.add_theme_color_override("selection_stroke", Color(0.88, 0.70, 0.46, 0.82))

	if status_label != null:
		status_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	if drone_summary_label != null:
		drone_summary_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	if pin_legend_label != null:
		pin_legend_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	if wiring_summary_label != null:
		wiring_summary_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	if checklist_label != null:
		checklist_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))
	if tips_label != null:
		tips_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.84))

	_style_action_button(auto_button, Color(0.31, 0.22, 0.15, 0.97), Color(0.82, 0.64, 0.40, 0.94))
	_style_action_button(save_button, Color(0.39, 0.27, 0.18, 0.97), Color(0.90, 0.71, 0.46, 0.94))
	_style_action_button(back_button, Color(0.23, 0.17, 0.12, 0.97), Color(0.67, 0.51, 0.34, 0.88))
	_style_action_button(settings_button, Color(0.27, 0.20, 0.14, 0.97), Color(0.75, 0.58, 0.39, 0.90))
	_style_action_button(reset_button, Color(0.33, 0.18, 0.15, 0.97), Color(0.78, 0.45, 0.33, 0.90))

func _style_action_button(button: Button, fill: Color, border: Color):
	if button == null:
		return
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
	normal.content_margin_left = 18.0
	normal.content_margin_top = 12.0
	normal.content_margin_right = 18.0
	normal.content_margin_bottom = 12.0

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

func _build_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style

func _connect_ui():
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	auto_button.pressed.connect(_on_auto_pressed)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

func _load_settings_menu():
	if settings_menu != null and is_instance_valid(settings_menu):
		return
	var settings_scene: PackedScene = preload("res://app/ui/SettingsScene.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func _load_drone_info():
	drone_info = Global.load_exported_drone_profile()
	if drone_info.is_empty() and FileAccess.file_exists("user://exported_drone.tscn"):
		var packed: PackedScene = ResourceLoader.load("user://exported_drone.tscn") as PackedScene
		if packed:
			var instance := packed.instantiate()
			if instance != null and instance.has_meta("drone_info"):
				var profile_value: Variant = instance.get_meta("drone_info")
				if typeof(profile_value) == TYPE_DICTIONARY:
					var profile: Dictionary = profile_value
					drone_info = profile
			instance.queue_free()

	if drone_info.is_empty():
		drone_info = {
			"frame_type": "Неизвестно",
			"board_type": "Плата не установлена",
			"motor_type": "Неизвестно",
			"propeller_type": "Неизвестно",
			"motor_count": 0,
			"propeller_count": 0,
			"motors": [],
			"propellers": [],
			"board_present": false
		}

	board_present = bool(drone_info.get("board_present", not str(drone_info.get("board_type", "")).is_empty()))
	drone_signature = Global.get_drone_signature(drone_info)

func _build_component_infos():
	motor_infos.clear()
	prop_infos.clear()

	var recommended_pins: PackedStringArray = Global.get_recommended_motor_pins()
	var motors: Array = drone_info.get("motors", [])
	var props: Array = drone_info.get("propellers", [])
	var motor_count: int = int(drone_info.get("motor_count", motors.size()))
	var prop_count: int = int(drone_info.get("propeller_count", props.size()))
	var occupied_motor_slots: Array[int] = []
	var occupied_prop_slots: Array[int] = []

	for i in range(motor_count):
		var motor_data: Dictionary = motors[i] if i < motors.size() and typeof(motors[i]) == TYPE_DICTIONARY else {}
		var requested_slot: int = clampi(int(motor_data.get("slot", i)), 0, SLOT_NAMES.size() - 1)
		var slot: int = _claim_unique_slot(occupied_motor_slots, requested_slot, i)
		var pin: String = recommended_pins[slot] if slot < recommended_pins.size() else "D?"
		motor_infos.append({
			"id": "Motor_%d" % (i + 1),
			"index": i,
			"slot": slot,
			"source_slot": requested_slot,
			"slot_name": _get_slot_name(slot),
			"type": str(motor_data.get("type", drone_info.get("motor_type", "Мотор"))),
			"pin": str(motor_data.get("recommended_pin", pin)),
			"display_order": i
		})

	for i in range(prop_count):
		var prop_data: Dictionary = props[i] if i < props.size() and typeof(props[i]) == TYPE_DICTIONARY else {}
		var requested_slot: int = clampi(int(prop_data.get("slot", i)), 0, SLOT_NAMES.size() - 1)
		var slot: int = _claim_unique_slot(occupied_prop_slots, requested_slot, i)
		prop_infos.append({
			"id": "Prop_%d" % (i + 1),
			"index": i,
			"slot": slot,
			"source_slot": requested_slot,
			"slot_name": _get_slot_name(slot),
			"type": str(prop_data.get("type", drone_info.get("propeller_type", "Пропеллер"))),
			"display_order": i
		})

	motor_infos.sort_custom(Callable(self, "_sort_by_slot"))
	prop_infos.sort_custom(Callable(self, "_sort_by_slot"))

	for i in range(motor_infos.size()):
		var motor_info: Dictionary = motor_infos[i]
		motor_info["display_order"] = i
		motor_infos[i] = motor_info

	for i in range(prop_infos.size()):
		var prop_info: Dictionary = prop_infos[i]
		prop_info["display_order"] = i
		prop_infos[i] = prop_info

func _build_graph():
	_clear_all_connections()
	for child in graph.get_children():
		if child is GraphNode:
			child.queue_free()

	if board_present:
		graph.add_child(_make_board_node())

	for info in motor_infos:
		graph.add_child(_make_motor_node(info))

	for info in prop_infos:
		graph.add_child(_make_prop_node(info))

func _make_board_node() -> GraphNode:
	var node := GraphNode.new()
	node.name = "Board"
	node.title = "Контроллер: %s" % str(drone_info.get("board_type", "Плата"))
	node.position_offset = Vector2(72, 92)
	node.resizable = false

	for info in motor_infos:
		var row := int(info.get("slot", 0))
		var label := Label.new()
		label.text = "%s -> %s" % [info.get("pin", "D?"), info.get("slot_name", "Мотор")]
		node.add_child(label)
		node.set_slot(row, false, 0, Color.WHITE, true, 0, Color(0.74, 0.55, 0.33))

	return node

func _make_motor_node(info: Dictionary) -> GraphNode:
	var node := GraphNode.new()
	node.name = str(info.get("id", "Motor"))
	node.title = "%s: мотор" % str(info.get("slot_name", "Мотор"))
	node.position_offset = Vector2(430, 72 + int(info.get("display_order", info.get("slot", 0))) * 145)
	node.resizable = false
	node.set_meta("slot", int(info.get("slot", 0)))

	var top_label := Label.new()
	top_label.text = "%s | PWM %s" % [str(info.get("type", "Мотор")), str(info.get("pin", "D?"))]
	node.add_child(top_label)
	node.set_slot(0, true, 0, Color(0.86, 0.68, 0.44), false, 0, Color.WHITE)

	var bottom_label := Label.new()
	bottom_label.text = "Выход на пропеллер"
	node.add_child(bottom_label)
	node.set_slot(1, false, 0, Color.WHITE, true, 0, Color(0.91, 0.72, 0.42))

	return node

func _make_prop_node(info: Dictionary) -> GraphNode:
	var node := GraphNode.new()
	node.name = str(info.get("id", "Prop"))
	node.title = "%s: пропеллер" % str(info.get("slot_name", "Пропеллер"))
	node.position_offset = Vector2(840, 72 + int(info.get("display_order", info.get("slot", 0))) * 145)
	node.resizable = false
	node.set_meta("slot", int(info.get("slot", 0)))

	var label := Label.new()
	label.text = str(info.get("type", "Пропеллер"))
	node.add_child(label)
	node.set_slot(0, true, 0, Color(0.91, 0.72, 0.42), false, 0, Color.WHITE)

	return node

func _restore_saved_wiring():
	var saved_profile := Global.load_arduino_wiring()
	if saved_profile.is_empty():
		return
	if str(saved_profile.get("drone_signature", "")) != drone_signature:
		return
	var saved_connections: Array = saved_profile.get("connections", [])
	for connection_variant in saved_connections:
		if typeof(connection_variant) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = connection_variant
		var from_node := StringName(str(record.get("from_node", "")))
		var to_node := StringName(str(record.get("to_node", "")))
		var from_port := int(record.get("from_port", 0))
		var to_port := int(record.get("to_port", 0))
		if graph.has_node(NodePath(from_node)) and graph.has_node(NodePath(to_node)):
			graph.connect_node(from_node, from_port, to_node, to_port)
			_store_connection(from_node, from_port, to_node, to_port)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	var from_name := String(from_node)
	var to_name := String(to_node)
	if (from_name == "Board" and to_name.begins_with("Motor_")) or (to_name == "Board" and from_name.begins_with("Motor_")):
		var motor_id: String = to_name if to_name.begins_with("Motor_") else from_name
		_connect_board_to_motor(motor_id)
		return
	if (from_name.begins_with("Motor_") and to_name.begins_with("Prop_")) or (from_name.begins_with("Prop_") and to_name.begins_with("Motor_")):
		var motor_target: String = from_name if from_name.begins_with("Motor_") else to_name
		var prop_target: String = to_name if to_name.begins_with("Prop_") else from_name
		_connect_motor_to_prop(motor_target, prop_target)
		return

	if from_name == "Board" and to_name.begins_with("Motor_"):
		var motor_info := _find_component_info(motor_infos, to_name)
		if motor_info.is_empty():
			return
		var required_slot := int(motor_info.get("slot", -1))
		if from_port != required_slot or to_port != 0:
			status_label.text = "Используйте %s для узла \"%s\"." % [motor_info.get("pin", "D?"), motor_info.get("slot_name", "мотор")]
			return
		if _board_port_is_busy(from_port) or _motor_has_board_connection(to_name):
			status_label.text = "Этот PWM-канал уже занят."
			return
		graph.connect_node(from_node, from_port, to_node, to_port)
		_store_connection(from_node, from_port, to_node, to_port)
		_refresh_sidebar()
		_update_status()
		return

	if from_name.begins_with("Motor_") and to_name.begins_with("Prop_"):
		var motor_info := _find_component_info(motor_infos, from_name)
		var prop_info := _find_component_info(prop_infos, to_name)
		if motor_info.is_empty() or prop_info.is_empty():
			return
		if int(motor_info.get("slot", -1)) != int(prop_info.get("slot", -2)) or from_port != 1 or to_port != 0:
			status_label.text = "Пропеллер должен быть подключен к мотору на том же луче."
			return
		if _motor_has_prop_connection(from_name) or _prop_has_connection(to_name):
			status_label.text = "Этот мотор или пропеллер уже соединен."
			return
		graph.connect_node(from_node, from_port, to_node, to_port)
		_store_connection(from_node, from_port, to_node, to_port)
		_refresh_sidebar()
		_update_status()
		return

	status_label.text = "Разрешены только связи Плата -> Мотор и Мотор -> Пропеллер."

func _connect_board_to_motor(motor_id: String):
	var motor_info: Dictionary = _find_component_info(motor_infos, motor_id)
	if motor_info.is_empty():
		return

	var required_slot: int = int(motor_info.get("slot", -1))
	if _board_port_is_busy(required_slot) or _motor_has_board_connection(motor_id):
		status_label.text = "Этот PWM-канал уже занят."
		return

	graph.connect_node("Board", required_slot, StringName(motor_id), 0)
	_store_connection("Board", required_slot, StringName(motor_id), 0)
	_refresh_sidebar()
	_update_status()

func _connect_motor_to_prop(motor_id: String, prop_id: String):
	var motor_info: Dictionary = _find_component_info(motor_infos, motor_id)
	var prop_info: Dictionary = _find_component_info(prop_infos, prop_id)
	if motor_info.is_empty() or prop_info.is_empty():
		return
	if int(motor_info.get("slot", -1)) != int(prop_info.get("slot", -2)):
		status_label.text = "Пропеллер должен быть подключен к мотору на том же луче."
		return
	if _motor_has_prop_connection(motor_id) or _prop_has_connection(prop_id):
		status_label.text = "Этот мотор или пропеллер уже соединен."
		return

	graph.connect_node(StringName(motor_id), 1, StringName(prop_id), 0)
	_store_connection(StringName(motor_id), 1, StringName(prop_id), 0)
	_refresh_sidebar()
	_update_status()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	_remove_connection(from_node, from_port, to_node, to_port)
	_refresh_sidebar()
	_update_status()

func _store_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	var record := {
		"from_node": String(from_node),
		"from_port": from_port,
		"to_node": String(to_node),
		"to_port": to_port
	}
	for existing in connections:
		if existing == record:
			return
	connections.append(record)

func _remove_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	var from_name := String(from_node)
	var to_name := String(to_node)
	for index in range(connections.size() - 1, -1, -1):
		var record: Dictionary = connections[index]
		if str(record.get("from_node", "")) == from_name \
		and int(record.get("from_port", -1)) == from_port \
		and str(record.get("to_node", "")) == to_name \
		and int(record.get("to_port", -1)) == to_port:
			connections.remove_at(index)

func _clear_all_connections():
	for connection in graph.get_connection_list():
		var record: Dictionary = connection
		graph.disconnect_node(
			StringName(str(record.get("from_node", ""))),
			int(record.get("from_port", 0)),
			StringName(str(record.get("to_node", ""))),
			int(record.get("to_port", 0))
		)
	connections.clear()

func _on_auto_pressed():
	_clear_all_connections()
	if board_present:
		for info in motor_infos:
			var motor_id := StringName(str(info.get("id", "")))
			var slot := int(info.get("slot", 0))
			if graph.has_node(NodePath(motor_id)):
				graph.connect_node("Board", slot, motor_id, 0)
				_store_connection("Board", slot, motor_id, 0)

	for info in motor_infos:
		var prop_id := _find_prop_id_for_slot(int(info.get("slot", -1)))
		if prop_id.is_empty():
			continue
		var motor_id := StringName(str(info.get("id", "")))
		var prop_name := StringName(prop_id)
		if graph.has_node(NodePath(motor_id)) and graph.has_node(NodePath(prop_name)):
			graph.connect_node(motor_id, 1, prop_name, 0)
			_store_connection(motor_id, 1, prop_name, 0)

	_refresh_sidebar()
	_update_status()

func _on_save_pressed():
	var wiring_profile := _build_wiring_profile()
	Global.save_arduino_wiring(wiring_profile)
	Global.record_valid_scheme(_is_scheme_valid())
	status_label.text = "Схема сохранена для платы %s." % str(drone_info.get("board_type", "плата"))
	_refresh_sidebar()
	_update_status()

func _on_reset_pressed():
	_clear_all_connections()
	Global.clear_arduino_wiring()
	status_label.text = "Схема сброшена."
	_refresh_sidebar()
	_update_status()

func _on_back_pressed():
	get_tree().change_scene_to_file(CREATE_DRONE_SCENE_PATH)

func _on_settings_pressed():
	if settings_menu != null and settings_menu.has_method("open"):
		settings_menu.call("open")

func _build_wiring_profile() -> Dictionary:
	var motor_pin_map: Array = []
	for motor_info in motor_infos:
		var motor_id := str(motor_info.get("id", ""))
		if not _motor_has_board_connection(motor_id):
			continue
		motor_pin_map.append({
			"motor_id": motor_id,
			"slot": int(motor_info.get("slot", -1)),
			"slot_name": str(motor_info.get("slot_name", "")),
			"pin": str(motor_info.get("pin", "")),
			"propeller_id": _find_prop_for_motor(motor_id)
		})

	return {
		"drone_signature": drone_signature,
		"board_type": str(drone_info.get("board_type", "")),
		"motor_pin_map": motor_pin_map,
		"mapped_motor_count": motor_pin_map.size(),
		"connections": connections.duplicate(true),
		"saved_at_unix": Time.get_unix_time_from_system()
	}

func _refresh_sidebar():
	drone_summary_label.text = _build_drone_summary_text()
	pin_legend_label.text = _build_pin_legend_text()
	wiring_summary_label.text = _build_wiring_summary_text()
	checklist_label.text = _build_checklist_text()
	tips_label.text = "1. Сначала экспортируйте дрон из сцены сборки.\n2. Выходы платы привязаны к рекомендованным PWM-пинам.\n3. На каждом луче должен быть один мотор и один пропеллер того же слота.\n4. После полной проверки сохраните схему."

func _update_status():
	var scheme_text: String = _get_scheme_state_label()
	var board_links_new: int = 0
	var prop_links_new: int = 0
	for record_variant in connections:
		var record_new: Dictionary = record_variant
		var from_name_new: String = str(record_new.get("from_node", ""))
		var to_name_new: String = str(record_new.get("to_node", ""))
		if from_name_new == "Board" and to_name_new.begins_with("Motor_"):
			board_links_new += 1
		if from_name_new.begins_with("Motor_") and to_name_new.begins_with("Prop_"):
			prop_links_new += 1
	status_label.text = "%s | Моторы %d/%d | Пропеллеры %d/%d" % [scheme_text, board_links_new, motor_infos.size(), prop_links_new, prop_infos.size()]

func _build_drone_summary_text() -> String:
	var physics: Dictionary = drone_info.get("physics", {})
	var mass_text := ""
	var thrust_text := ""
	if typeof(physics) == TYPE_DICTIONARY and not physics.is_empty():
		mass_text = "\nМасса: %.2f" % float(physics.get("mass", physics.get("total_mass", 0.0)))
		thrust_text = "\nТяга: %.2f" % float(physics.get("thrust", physics.get("total_thrust", 0.0)))

	return "Рама: %s\nПлата: %s\nМоторов: %d\nПропеллеров: %d%s%s" % [
		str(drone_info.get("frame_type", "Неизвестно")),
		str(drone_info.get("board_type", "Отсутствует")),
		int(drone_info.get("motor_count", 0)),
		int(drone_info.get("propeller_count", 0)),
		mass_text,
		thrust_text
	]

func _build_pin_legend_text() -> String:
	if motor_infos.is_empty():
		return "Из сцены сборки еще не был экспортирован ни один мотор."
	var lines: Array[String] = []
	for info in motor_infos:
		lines.append("%s: %s" % [str(info.get("slot_name", "")), str(info.get("pin", ""))])
	return "\n".join(lines)

func _build_wiring_summary_text() -> String:
	var summary_new: Dictionary = Global.get_arduino_wiring_summary(_build_wiring_profile())
	var pin_parts_new: Array[String] = []
	for pin_variant in summary_new.get("assigned_pins", []):
		pin_parts_new.append(str(pin_variant))
	return "Сигнатура: %s\nНазначенные пины: %s\nСборка: %s\nГотово: %s" % [
		str(summary_new.get("drone_signature", "пусто")),
		", ".join(pin_parts_new),
		"Норма" if _is_scheme_valid() else "Не норм",
		"Да" if bool(summary_new.get("is_complete", false)) else "Нет"
	]

func _build_checklist_text() -> String:
	var board_links_new: int = 0
	var prop_links_new: int = 0
	for record_variant_new in connections:
		var record_new: Dictionary = record_variant_new
		var from_name_new: String = str(record_new.get("from_node", ""))
		var to_name_new: String = str(record_new.get("to_node", ""))
		if from_name_new == "Board" and to_name_new.begins_with("Motor_"):
			board_links_new += 1
		if from_name_new.begins_with("Motor_") and to_name_new.begins_with("Prop_"):
			prop_links_new += 1

	return "Плата экспортирована: %s\nКаналы моторов: %d/%d\nСвязи пропеллеров: %d/%d\nСборка: %s\nГотово к сохранению: %s" % [
		"Да" if board_present else "Нет",
		board_links_new,
		motor_infos.size(),
		prop_links_new,
		prop_infos.size(),
		"Норма" if _is_scheme_valid() else "Не норм",
		"Да" if board_present and board_links_new == motor_infos.size() and prop_links_new == prop_infos.size() else "Нет"
	]

func _find_component_info(list: Array, node_name: String) -> Dictionary:
	for entry_variant in list:
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) == node_name:
			return entry
	return {}

func _get_slot_name(slot: int) -> String:
	if slot >= 0 and slot < SLOT_NAMES.size():
		return SLOT_NAMES[slot]
	return "Слот %d" % slot

func _board_port_is_busy(slot: int) -> bool:
	for record_variant in connections:
		var record: Dictionary = record_variant
		if str(record.get("from_node", "")) == "Board" and int(record.get("from_port", -1)) == slot:
			return true
	return false

func _motor_has_board_connection(motor_id: String) -> bool:
	for record_variant in connections:
		var record: Dictionary = record_variant
		if str(record.get("from_node", "")) == "Board" and str(record.get("to_node", "")) == motor_id:
			return true
	return false

func _motor_has_prop_connection(motor_id: String) -> bool:
	for record_variant in connections:
		var record: Dictionary = record_variant
		if str(record.get("from_node", "")) == motor_id and str(record.get("to_node", "")).begins_with("Prop_"):
			return true
	return false

func _prop_has_connection(prop_id: String) -> bool:
	for record_variant in connections:
		var record: Dictionary = record_variant
		if str(record.get("to_node", "")) == prop_id:
			return true
	return false

func _find_prop_for_motor(motor_id: String) -> String:
	for record_variant in connections:
		var record: Dictionary = record_variant
		if str(record.get("from_node", "")) == motor_id and str(record.get("to_node", "")).begins_with("Prop_"):
			return str(record.get("to_node", ""))
	return ""

func _find_prop_id_for_slot(slot: int) -> String:
	for info_variant in prop_infos:
		var info: Dictionary = info_variant
		if int(info.get("slot", -1)) == slot:
			return str(info.get("id", ""))
	return ""

func _sort_by_slot(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("slot", 0)) < int(b.get("slot", 0))

func _claim_unique_slot(used_slots: Array[int], preferred_slot: int, fallback_index: int) -> int:
	var slot: int = clampi(preferred_slot, 0, SLOT_NAMES.size() - 1)
	if not used_slots.has(slot):
		used_slots.append(slot)
		return slot

	for candidate in range(SLOT_NAMES.size()):
		if not used_slots.has(candidate):
			used_slots.append(candidate)
			return candidate

	return posmod(fallback_index, SLOT_NAMES.size())

func _ensure_pause_menu():
	if _pause_layer != null and is_instance_valid(_pause_layer):
		return

	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 500
	add_child(_pause_layer)

	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.gui_input.connect(_on_pause_overlay_gui_input)
	_pause_layer.add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.05, 0.03, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(dim)

	_pause_center = CenterContainer.new()
	_pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(_pause_center)

	_pause_panel = Panel.new()
	_pause_panel.custom_minimum_size = Vector2(560, 520)
	_pause_panel.pivot_offset = Vector2(280, 260)
	_pause_panel.scale = Vector2(0.92, 0.92)
	_pause_panel.modulate.a = 0.0
	_pause_center.add_child(_pause_panel)
	_pause_panel.add_theme_stylebox_override("panel", _build_card_style(Color(0.18, 0.13, 0.09, 0.96), Color(0.80, 0.62, 0.40, 0.82)))
	call_deferred("_sync_pause_panel_pivot")

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_pause_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(320, 468)
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Меню"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())
	vbox.add_child(_pm_btn("Продолжить", Callable(self, "_pm_resume")))
	vbox.add_child(_pm_btn("Автосвязь", Callable(self, "_pm_auto")))
	vbox.add_child(_pm_btn("Сохранить схему", Callable(self, "_pm_save")))
	vbox.add_child(_pm_btn("Настройки", Callable(self, "_pm_settings")))
	vbox.add_child(_pm_btn("Назад к сборке", Callable(self, "_pm_back")))
	vbox.add_child(_pm_btn("Главное меню", Callable(self, "_pm_main_menu")))
	vbox.add_child(_pm_btn("Выход", Callable(self, "_pm_quit")))

func _pm_btn(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_style_action_button(button, Color(0.28, 0.20, 0.14, 0.97), Color(0.77, 0.60, 0.40, 0.90))
	return button

func _toggle_pause_menu(open: bool):
	_ensure_pause_menu()
	_sync_pause_panel_pivot()
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
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2.ONE, 0.14)
	else:
		_pause_tween.tween_property(_pause_panel, "modulate:a", 0.0, 0.10)
		_pause_tween.parallel().tween_property(_pause_panel, "scale", Vector2(0.92, 0.92), 0.10)
		_pause_tween.tween_callback(Callable(self, "_pm_hide_overlay"))

func _sync_pause_panel_pivot() -> void:
	if _pause_panel == null or not is_instance_valid(_pause_panel):
		return
	var panel_size: Vector2 = _pause_panel.size
	if panel_size == Vector2.ZERO:
		panel_size = _pause_panel.get_combined_minimum_size()
	_pause_panel.pivot_offset = panel_size * 0.5

func _pm_hide_overlay():
	if not _pause_open and _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.visible = false

func _on_pause_overlay_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_pause_menu(false)

func _pm_resume():
	_toggle_pause_menu(false)

func _is_scheme_valid() -> bool:
	if not board_present:
		return false
	if motor_infos.is_empty() or prop_infos.is_empty():
		return false

	var board_links: int = 0
	var prop_links: int = 0
	for record_variant in connections:
		var record: Dictionary = record_variant
		var from_name: String = str(record.get("from_node", ""))
		var to_name: String = str(record.get("to_node", ""))
		if from_name == "Board" and to_name.begins_with("Motor_"):
			board_links += 1
		if from_name.begins_with("Motor_") and to_name.begins_with("Prop_"):
			prop_links += 1

	return board_links == motor_infos.size() and prop_links == prop_infos.size()

func _get_scheme_state_label() -> String:
	return "СХЕМА: НОРМА" if _is_scheme_valid() else "СХЕМА: НУЖНА ПРОВЕРКА"

func _pm_auto():
	_toggle_pause_menu(false)
	_on_auto_pressed()

func _pm_save():
	_toggle_pause_menu(false)
	_on_save_pressed()

func _pm_settings():
	_toggle_pause_menu(false)
	_on_settings_pressed()

func _pm_back():
	_toggle_pause_menu(false)
	_on_back_pressed()

func _pm_main_menu():
	_toggle_pause_menu(false)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _pm_quit():
	get_tree().quit()
