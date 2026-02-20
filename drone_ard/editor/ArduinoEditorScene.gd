extends Control

@onready var graph: GraphEdit = $GraphEdit
@onready var status_label: Label = $TopBar/StatusLabel

const SAVE_PATH: String = "user://arduino_editor_project.json"
const CREATE_DRONE_SCENE_PATH: String = "res://create_drone/create_dron.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://main_scene.tscn"

enum PinType { POWER, GROUND, PWM, SIGNAL, I2C, UART }

var connections: Array = []
var selected_node_name: String = ""

var left_panel: PanelContainer
var right_panel: PanelContainer
var library_list: VBoxContainer
var inspector_title: Label
var inspector_body: RichTextLabel

var component_catalog: Dictionary = {
	"Board": {
		"title": "Arduino Nano",
		"pins": [
			{"name": "VIN", "dir": "in", "type": PinType.POWER, "required": true},
			{"name": "GND", "dir": "in", "type": PinType.GROUND, "required": true},
			{"name": "PWM D3", "dir": "out", "type": PinType.PWM},
			{"name": "PWM D5", "dir": "out", "type": PinType.PWM},
			{"name": "PWM D6", "dir": "out", "type": PinType.PWM},
			{"name": "PWM D9", "dir": "out", "type": PinType.PWM},
			{"name": "SDA", "dir": "out", "type": PinType.I2C},
			{"name": "SCL", "dir": "out", "type": PinType.I2C}
		]
	},
	"Battery": {
		"title": "LiPo 3S",
		"pins": [
			{"name": "+", "dir": "out", "type": PinType.POWER},
			{"name": "-", "dir": "out", "type": PinType.GROUND}
		]
	},
	"ESC": {
		"title": "ESC 30A",
		"pins": [
			{"name": "VCC", "dir": "in", "type": PinType.POWER, "required": true},
			{"name": "GND", "dir": "in", "type": PinType.GROUND, "required": true},
			{"name": "PWM", "dir": "in", "type": PinType.PWM, "required": true},
			{"name": "MOTOR", "dir": "out", "type": PinType.SIGNAL, "required": true}
		]
	},
	"Motor": {
		"title": "BLDC Motor",
		"pins": [
			{"name": "IN", "dir": "in", "type": PinType.SIGNAL, "required": true}
		]
	},
	"IMU": {
		"title": "MPU6050",
		"pins": [
			{"name": "VCC", "dir": "in", "type": PinType.POWER, "required": true},
			{"name": "GND", "dir": "in", "type": PinType.GROUND, "required": true},
			{"name": "SDA", "dir": "in", "type": PinType.I2C, "required": true},
			{"name": "SCL", "dir": "in", "type": PinType.I2C, "required": true}
		]
	},
	"GPS": {
		"title": "GPS NEO-6M",
		"pins": [
			{"name": "VCC", "dir": "in", "type": PinType.POWER, "required": true},
			{"name": "GND", "dir": "in", "type": PinType.GROUND, "required": true},
			{"name": "TX", "dir": "out", "type": PinType.UART},
			{"name": "RX", "dir": "in", "type": PinType.UART}
		]
	}
}

func _ready() -> void:
	_ensure_top_buttons()
	_build_editor_layout()

	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)

	_load_project()
	if _count_component_nodes() == 0:
		_seed_default_project()
	_validate_and_render_status()

func _ensure_top_buttons() -> void:
	var top := get_node_or_null("TopBar") as HBoxContainer
	if top == null:
		return

	_add_top_button_if_missing(top, "SaveButton", "💾 Save", Callable(self, "_on_save_pressed"))
	_add_top_button_if_missing(top, "AutoButton", "⚡ Auto", Callable(self, "_on_auto_pressed"))
	_add_top_button_if_missing(top, "BackButton", "← Back", Callable(self, "_on_back_pressed"))

func _add_top_button_if_missing(top: HBoxContainer, name_id: String, text_value: String, cb: Callable) -> void:
	var b := top.get_node_or_null(name_id) as Button
	if b == null:
		b = Button.new()
		b.name = name_id
		b.text = text_value
		top.add_child(b)
	if not b.is_connected("pressed", cb):
		b.pressed.connect(cb)

func _build_editor_layout() -> void:
	# Освобождаем место под панель библиотеки и инспектор
	graph.offset_left = 250
	graph.offset_right = -320

	left_panel = PanelContainer.new()
	left_panel.name = "LibraryPanel"
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 8
	left_panel.offset_top = 64
	left_panel.offset_right = 240
	left_panel.offset_bottom = -8
	add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)
	var lib_title := Label.new()
	lib_title.text = "Библиотека компонентов"
	left_vbox.add_child(lib_title)

	library_list = VBoxContainer.new()
	left_vbox.add_child(library_list)
	for key in component_catalog.keys():
		var btn := Button.new()
		btn.text = "+ %s" % component_catalog[key]["title"]
		btn.pressed.connect(_on_add_component_pressed.bind(key))
		library_list.add_child(btn)

	right_panel = PanelContainer.new()
	right_panel.name = "InspectorPanel"
	right_panel.anchor_left = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -312
	right_panel.offset_top = 64
	right_panel.offset_right = -8
	right_panel.offset_bottom = -8
	add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)
	inspector_title = Label.new()
	inspector_title.text = "Inspector"
	right_vbox.add_child(inspector_title)
	inspector_body = RichTextLabel.new()
	inspector_body.fit_content = true
	inspector_body.scroll_active = true
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(inspector_body)

	_update_inspector()

func _seed_default_project() -> void:
	_create_component_node("Battery", Vector2(40, 80))
	_create_component_node("Board", Vector2(300, 60))
	for i in range(4):
		_create_component_node("ESC", Vector2(620, 40 + i * 130))
		_create_component_node("Motor", Vector2(900, 40 + i * 130))
	_create_component_node("IMU", Vector2(320, 390))

func _on_add_component_pressed(component_key: String) -> void:
	var count := _count_nodes_by_type(component_key)
	_create_component_node(component_key, Vector2(260 + count * 24, 100 + count * 18))
	_validate_and_render_status()

func _create_component_node(component_key: String, position: Vector2) -> void:
	if not component_catalog.has(component_key):
		return

	var template: Dictionary = component_catalog[component_key]
	var node := GraphNode.new()
	node.name = "%s_%d" % [component_key, int(Time.get_unix_time_from_system()) + (randi() % 1000)]
	node.title = template["title"]
	node.position_offset = position
	node.resizable = false
	node.set_meta("component_type", component_key)
	node.set_meta("pins", template["pins"])
	node.gui_input.connect(_on_graph_node_gui_input.bind(node.name))

	var pins: Array = template["pins"]
	for i in range(pins.size()):
		var pin: Dictionary = pins[i]
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%d. %s" % [i, pin["name"]]
		row.add_child(lbl)
		node.add_child(row)
		var pin_type: int = int(pin["type"])
		var c := _pin_color(pin_type)
		if pin["dir"] == "in":
			node.set_slot(i, true, pin_type, c, false, pin_type, c)
		else:
			node.set_slot(i, false, pin_type, c, true, pin_type, c)

	graph.add_child(node)

func _pin_color(pin_type: int) -> Color:
	match pin_type:
		PinType.POWER: return Color(0.95, 0.3, 0.2)
		PinType.GROUND: return Color(0.2, 0.2, 0.2)
		PinType.PWM: return Color(0.9, 0.75, 0.2)
		PinType.SIGNAL: return Color(0.3, 0.85, 1.0)
		PinType.I2C: return Color(0.55, 0.8, 1.0)
		PinType.UART: return Color(0.6, 1.0, 0.6)
		_: return Color.WHITE

func _on_graph_node_gui_input(event: InputEvent, node_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_node_name = node_name
		_update_inspector()

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if not _is_connection_allowed(String(from_node), from_port, String(to_node), to_port):
		status_label.text = "❌ Недопустимое соединение: типы пинов не совпадают"
		return

	graph.connect_node(from_node, from_port, to_node, to_port)
	_store_connection(from_node, from_port, to_node, to_port)
	_validate_and_render_status()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	_remove_connection(from_node, from_port, to_node, to_port)
	_validate_and_render_status()

func _is_connection_allowed(from_node: String, from_port: int, to_node: String, to_port: int) -> bool:
	var from_pin := _get_pin_info(from_node, from_port)
	var to_pin := _get_pin_info(to_node, to_port)
	if from_pin.is_empty() or to_pin.is_empty():
		return false
	if from_pin.get("dir", "") != "out":
		return false
	if to_pin.get("dir", "") != "in":
		return false
	return int(from_pin["type"]) == int(to_pin["type"])

func _get_pin_info(node_name: String, pin_index: int) -> Dictionary:
	var n := graph.get_node_or_null(node_name) as GraphNode
	if n == null:
		return {}
	var pins: Array = n.get_meta("pins", [])
	if pin_index < 0 or pin_index >= pins.size():
		return {}
	return pins[pin_index]

func _store_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var rec := {
		"from_node": String(from_node),
		"from_port": from_port,
		"to_node": String(to_node),
		"to_port": to_port
	}
	for c in connections:
		if c == rec:
			return
	connections.append(rec)

func _remove_connection(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	for i in range(connections.size() - 1, -1, -1):
		var c: Dictionary = connections[i]
		if c["from_node"] == String(from_node) and c["from_port"] == from_port and c["to_node"] == String(to_node) and c["to_port"] == to_port:
			connections.remove_at(i)

func _validate_and_render_status() -> void:
	var errors: Array[String] = []
	var infos: Array[String] = []

	var board_count := _count_nodes_by_type("Board")
	var battery_count := _count_nodes_by_type("Battery")
	var esc_count := _count_nodes_by_type("ESC")
	var motor_count := _count_nodes_by_type("Motor")

	if board_count == 0:
		errors.append("Нет Arduino платы")
	if battery_count == 0:
		errors.append("Нет источника питания (Battery)")
	if esc_count == 0:
		errors.append("Нет ESC")
	if motor_count == 0:
		errors.append("Нет моторов")

	for node in graph.get_children():
		if not (node is GraphNode):
			continue
		var gn := node as GraphNode
		var pins: Array = gn.get_meta("pins", [])
		for i in range(pins.size()):
			var pin: Dictionary = pins[i]
			if bool(pin.get("required", false)) and not _is_pin_connected(gn.name, i, String(pin.get("dir", "in"))):
				errors.append("%s: обязательный пин '%s' не подключен" % [gn.title, pin["name"]])

	infos.append("Nodes: Board=%d, Battery=%d, ESC=%d, Motor=%d" % [board_count, battery_count, esc_count, motor_count])
	infos.append("Connections: %d" % connections.size())

	if errors.is_empty():
		status_label.text = "✅ Схема валидна | %s" % infos[1]
	else:
		status_label.text = "⚠️ Ошибок: %d | %s" % [errors.size(), infos[1]]

	_update_inspector(errors, infos)

func _is_pin_connected(node_name: String, pin_index: int, dir: String) -> bool:
	for c in connections:
		if dir == "in" and c["to_node"] == node_name and c["to_port"] == pin_index:
			return true
		if dir == "out" and c["from_node"] == node_name and c["from_port"] == pin_index:
			return true
	return false

func _update_inspector(errors: Array[String] = [], infos: Array[String] = []) -> void:
	if inspector_body == null:
		return

	inspector_body.clear()
	if selected_node_name != "":
		var n := graph.get_node_or_null(selected_node_name) as GraphNode
		if n:
			inspector_title.text = "Inspector: %s" % n.title
			inspector_body.append_text("[b]Node:[/b] %s\n" % n.name)
			var pins: Array = n.get_meta("pins", [])
			for i in range(pins.size()):
				var pin: Dictionary = pins[i]
				var state := "✅" if _is_pin_connected(n.name, i, String(pin.get("dir", "in"))) else "⚪"
				inspector_body.append_text("%s %d. %s (%s)\n" % [state, i, pin["name"], pin["dir"]])
			inspector_body.append_text("\n")
	else:
		inspector_title.text = "Inspector"

	inspector_body.append_text("[b]Validation:[/b]\n")
	for info in infos:
		inspector_body.append_text("• %s\n" % info)
	if errors.is_empty():
		inspector_body.append_text("✅ Ошибок нет\n")
	else:
		for e in errors:
			inspector_body.append_text("❌ %s\n" % e)

func _on_save_pressed() -> void:
	_save_project()
	status_label.text = "💾 Проект сохранен"

func _on_auto_pressed() -> void:
	_auto_wire_basics()
	_validate_and_render_status()

func _on_back_pressed() -> void:
	_save_project()
	get_tree().change_scene_to_file(CREATE_DRONE_SCENE_PATH)

func _auto_wire_basics() -> void:
	# Простой автопровод: Battery -> Board/ESC, Board PWM -> ESC PWM, ESC MOTOR -> Motor IN
	var batteries := _get_nodes_by_type("Battery")
	var boards := _get_nodes_by_type("Board")
	var escs := _get_nodes_by_type("ESC")
	var motors := _get_nodes_by_type("Motor")
	if batteries.is_empty() or boards.is_empty():
		return

	var battery: GraphNode = batteries[0]
	var board: GraphNode = boards[0]
	_try_connect(battery.name, 0, board.name, 0)
	_try_connect(battery.name, 1, board.name, 1)

	for esc in escs:
		_try_connect(battery.name, 0, esc.name, 0)
		_try_connect(battery.name, 1, esc.name, 1)

	var count := min(escs.size(), motors.size())
	for i in range(count):
		var esc: GraphNode = escs[i]
		var motor: GraphNode = motors[i]
		# board pwm ports 2..5
		var pwm_port := 2 + (i % 4)
		_try_connect(board.name, pwm_port, esc.name, 2)
		_try_connect(esc.name, 3, motor.name, 0)

func _try_connect(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	if _is_connection_allowed(from_node, from_port, to_node, to_port) and not _has_connection(from_node, from_port, to_node, to_port):
		graph.connect_node(from_node, from_port, to_node, to_port)
		_store_connection(from_node, from_port, to_node, to_port)

func _has_connection(from_node: String, from_port: int, to_node: String, to_port: int) -> bool:
	for c in connections:
		if c["from_node"] == from_node and c["from_port"] == from_port and c["to_node"] == to_node and c["to_port"] == to_port:
			return true
	return false

func _save_project() -> void:
	var nodes_data: Array = []
	for child in graph.get_children():
		if child is GraphNode:
			var g := child as GraphNode
			nodes_data.append({
				"name": g.name,
				"title": g.title,
				"position": [g.position_offset.x, g.position_offset.y],
				"component_type": String(g.get_meta("component_type", ""))
			})

	var data := {
		"version": 2,
		"nodes": nodes_data,
		"connections": connections
	}
	var fa := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(data, "\t"))

func _load_project() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var fa := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa == null:
		return

	var txt := fa.get_as_text()
	var p := JSON.parse_string(txt)
	if typeof(p) != TYPE_DICTIONARY:
		return

	for c in graph.get_children():
		if c is GraphNode:
			c.queue_free()
	connections.clear()

	var nodes: Array = p.get("nodes", [])
	for n in nodes:
		var ct := String(n.get("component_type", ""))
		if not component_catalog.has(ct):
			continue
		_create_component_node(ct, Vector2(float(n["position"][0]), float(n["position"][1])))
		# переименуем в сохраненное имя
		var created := graph.get_child(graph.get_child_count() - 1) as GraphNode
		created.name = String(n.get("name", created.name))
		created.title = String(n.get("title", created.title))

	var conns: Array = p.get("connections", [])
	for c in conns:
		var fn := String(c.get("from_node", ""))
		var fp := int(c.get("from_port", -1))
		var tn := String(c.get("to_node", ""))
		var tp := int(c.get("to_port", -1))
		if graph.get_node_or_null(fn) and graph.get_node_or_null(tn) and _is_connection_allowed(fn, fp, tn, tp):
			graph.connect_node(fn, fp, tn, tp)
			_store_connection(fn, fp, tn, tp)

func _count_component_nodes() -> int:
	var n := 0
	for child in graph.get_children():
		if child is GraphNode:
			n += 1
	return n

func _count_nodes_by_type(component_type: String) -> int:
	var n := 0
	for child in graph.get_children():
		if child is GraphNode and String((child as GraphNode).get_meta("component_type", "")) == component_type:
			n += 1
	return n

func _get_nodes_by_type(component_type: String) -> Array[GraphNode]:
	var arr: Array[GraphNode] = []
	for child in graph.get_children():
		if child is GraphNode and String((child as GraphNode).get_meta("component_type", "")) == component_type:
			arr.append(child as GraphNode)
	return arr
