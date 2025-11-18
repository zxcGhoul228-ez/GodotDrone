extends Node3D

# Ссылки на узлы
var components_container
var list_panel
var component_list

var frame_buttons = []
var board_buttons = []
var motor_buttons = []
var propeller_buttons = []

# Переменные для хранения компонентов
var drone_frame = null
var drone_board = null
var motors = []
var propellers = []

# Словари префабов для каждого типа компонентов
var frame_prefabs = {
	"Рама1": preload("res://create_drone/components/frame1.tscn"),
	"Рама2": preload("res://create_drone/components/frame2.tscn"),
	"Рама3": preload("res://create_drone/components/frame3.tscn")
}

var board_prefabs = {
	"Плата1": preload("res://create_drone/components/board1.tscn"),
	"Плата2": preload("res://create_drone/components/board2.tscn"),
	"Плата3": preload("res://create_drone/components/board3.tscn")
}

var motor_prefabs = {
	"Мотор1": preload("res://create_drone/components/motor1.tscn"),
	"Мотор2": preload("res://create_drone/components/motor2.tscn"),
	"Мотор3": preload("res://create_drone/components/motor3.tscn")
}

var propeller_prefabs = {
	"Пропеллер1": preload("res://create_drone/components/propeller1.tscn"),
	"Пропеллер2": preload("res://create_drone/components/propeller2.tscn"),
	"Пропеллер3": preload("res://create_drone/components/propeller3.tscn")
}

# Текущие выбранные типы компонентов
var current_frame_type = "Рама1"
var current_board_type = "Плата1"
var current_motor_type = "Мотор1"
var current_propeller_type = "Пропеллер1"

# Переменные для управления камерой и вращения
var camera_rotation = Vector2(0, 0)
var camera_distance = 8.0
var is_rotating = false
var last_mouse_pos = Vector2(0, 0)

# Инерция вращения
var rotation_velocity = Vector2(0, 0)
var is_dragging_camera = false

# Чувствительность управления
const ROTATION_SPEED = 0.01
const ZOOM_SPEED = 0.1
const MIN_DISTANCE = 3.0
const MAX_DISTANCE = 20.0

# Настройки инерции
const FRICTION = 0.92
const MAX_VELOCITY = 0.1

# Ограничения камеры
const MIN_VERTICAL_ANGLE = 0.0
const MAX_VERTICAL_ANGLE = PI/2 - 0.2

# Переменные для системы перетаскивания КОМПОНЕНТОВ
var dragged_component = null
var original_component_position = Vector3.ZERO
var is_dragging_component = false
var drag_offset = Vector3.ZERO

# Для хранения смещений дочерних компонентов
var child_offsets = {}

# Для перетаскивания из списка
var is_dragging_from_list = false
var component_to_create_from_list = null

# Для перетаскивания после создания кнопкой
var component_created_by_button = null

# Задержка для корректного позиционирования
const DRAG_DELAY = 0.05

# Границы перемещения (как у сетки)
const BOUNDS_MIN = Vector3(-5, 0, -5)
const BOUNDS_MAX = Vector3(5, 3, 5)

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D

func _ready():
	# Получаем ссылки на узлы
	components_container = $Components
	list_panel = $UI/Hierarchy
	
	# Пробуем найти Complist разными способами
	component_list = find_component_list()
	
	if component_list == null:
		print("Ошибка: Complist не найден! Создаю новый...")
		create_component_list()
	
	# Скрываем панель иерархии при старте
	if list_panel:
		list_panel.visible = false
	else:
		print("Ошибка: Hierarchy не найден!")
	
	# Создаем UI через код
	create_component_selectors_ui()
	
	# Создаем сетку
	create_grid()
	
	# Создаем линию пола
	create_floor_line()
	
	# Добавляем кнопки сохранения/загрузки
	add_save_load_buttons()
	
	# Подключаем сигналы кнопок
	connect_buttons()
	
	# Создаем кнопки компонентов
	create_component_buttons()
	
	# Настраиваем начальную позицию камеры
	update_camera_position()
	
	# Добавляем эту сцену в группу для обновления из магазина
	add_to_group("drone_creator")
	
	# Обновляем доступность кнопок при старте
	update_buttons_availability()
	
	set_process_input(true)

func update_buttons_availability():
	update_component_buttons_availability(frame_buttons, frame_prefabs.keys())
	update_component_buttons_availability(board_buttons, board_prefabs.keys())
	update_component_buttons_availability(motor_buttons, motor_prefabs.keys())
	update_component_buttons_availability(propeller_buttons, propeller_prefabs.keys())
	
	update_current_selections()

func update_component_buttons_availability(buttons: Array, component_names: Array):
	for i in range(buttons.size()):
		var button = buttons[i]
		if i < component_names.size():
			var component_name = component_names[i]
			var is_available = Global.is_component_available("", component_name)
			
			if is_available:
				button.disabled = false
				button.add_theme_color_override("font_color", Color(0, 1, 0))
				button.tooltip_text = "Доступно"
			else:
				button.disabled = true
				button.add_theme_color_override("font_color", Color(1, 0, 0))
				button.tooltip_text = "Не куплено в магазине"

func update_current_selections():
	if not Global.is_component_available("", current_frame_type):
		current_frame_type = get_first_available_component(frame_prefabs.keys())
		update_button_selector(frame_buttons, current_frame_type)
	
	if not Global.is_component_available("", current_board_type):
		current_board_type = get_first_available_component(board_prefabs.keys())
		update_button_selector(board_buttons, current_board_type)
	
	if not Global.is_component_available("", current_motor_type):
		current_motor_type = get_first_available_component(motor_prefabs.keys())
		update_button_selector(motor_buttons, current_motor_type)
	
	if not Global.is_component_available("", current_propeller_type):
		current_propeller_type = get_first_available_component(propeller_prefabs.keys())
		update_button_selector(propeller_buttons, current_propeller_type)

func get_first_available_component(component_names: Array) -> String:
	for name in component_names:
		if Global.is_component_available("", name):
			return name
	return component_names[0] if component_names.size() > 0 else ""

func create_component_selectors_ui():
	var component_selectors = VBoxContainer.new()
	component_selectors.name = "ComponentSelectors"
	
	component_selectors.anchors_preset = Control.PRESET_BOTTOM_LEFT
	component_selectors.anchor_left = 0.0
	component_selectors.anchor_bottom = 1.0
	component_selectors.anchor_right = 0.0
	component_selectors.anchor_top = 1.0
	
	component_selectors.offset_left = 20
	component_selectors.offset_bottom = -20
	component_selectors.offset_right = 420
	component_selectors.offset_top = -620
	
	create_frame_section(component_selectors)
	create_board_section(component_selectors)
	create_motor_section(component_selectors)
	create_propeller_section(component_selectors)
	
	$UI.add_child(component_selectors)
	
	add_debug_style(component_selectors, Color(0, 0.5, 1, 0.3))

func create_frame_section(parent: VBoxContainer):
	var frame_section = HBoxContainer.new()
	frame_section.name = "FrameSelector"
	frame_section.custom_minimum_size = Vector2(0, 120)
	frame_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var frame_label = Label.new()
	frame_label.name = "FrameLabel"
	frame_label.text = "Рамы      "
	frame_label.custom_minimum_size = Vector2(80, 0)
	frame_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var frame_container = ScrollContainer.new()
	frame_container.name = "FrameContainer"
	frame_container.custom_minimum_size = Vector2(300, 120)
	frame_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var frame_hbox = HBoxContainer.new()
	frame_hbox.name = "FrameHBox"
	frame_hbox.custom_minimum_size = Vector2(400, 120)
	
	frame_container.add_child(frame_hbox)
	frame_section.add_child(frame_label)
	frame_section.add_child(frame_container)
	parent.add_child(frame_section)
	
	add_debug_style(frame_section, Color(1, 0, 0, 0.2))

func create_board_section(parent: VBoxContainer):
	var board_section = HBoxContainer.new()
	board_section.name = "BoardSelector"
	board_section.custom_minimum_size = Vector2(0, 120)
	board_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var board_label = Label.new()
	board_label.name = "BoardLabel"
	board_label.text = "Платы     "
	board_label.custom_minimum_size = Vector2(80, 0)
	board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var board_container = ScrollContainer.new()
	board_container.name = "BoardContainer"
	board_container.custom_minimum_size = Vector2(300, 120)
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var board_hbox = HBoxContainer.new()
	board_hbox.name = "BoardHBox"
	board_hbox.custom_minimum_size = Vector2(400, 120)
	
	board_container.add_child(board_hbox)
	board_section.add_child(board_label)
	board_section.add_child(board_container)
	parent.add_child(board_section)
	
	add_debug_style(board_section, Color(0, 1, 0, 0.2))

func create_motor_section(parent: VBoxContainer):
	var motor_section = HBoxContainer.new()
	motor_section.name = "MotorSelector"
	motor_section.custom_minimum_size = Vector2(0, 120)
	motor_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var motor_label = Label.new()
	motor_label.name = "MotorLabel"
	motor_label.text = "Двигатели "
	motor_label.custom_minimum_size = Vector2(80, 0)
	motor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var motor_container = ScrollContainer.new()
	motor_container.name = "MotorContainer"
	motor_container.custom_minimum_size = Vector2(300, 120)
	motor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var motor_hbox = HBoxContainer.new()
	motor_hbox.name = "MotorHBox"
	motor_hbox.custom_minimum_size = Vector2(400, 120)
	
	motor_container.add_child(motor_hbox)
	motor_section.add_child(motor_label)
	motor_section.add_child(motor_container)
	parent.add_child(motor_section)
	
	add_debug_style(motor_section, Color(1, 1, 0, 0.2))

func create_propeller_section(parent: VBoxContainer):
	var propeller_section = HBoxContainer.new()
	propeller_section.name = "PropellerSelector"
	propeller_section.custom_minimum_size = Vector2(0, 120)
	propeller_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var propeller_label = Label.new()
	propeller_label.name = "PropellerLabel"
	propeller_label.text = "Пропеллеры"
	propeller_label.custom_minimum_size = Vector2(80, 0)
	propeller_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var propeller_container = ScrollContainer.new()
	propeller_container.name = "PropellerContainer"
	propeller_container.custom_minimum_size = Vector2(300, 120)
	propeller_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var propeller_hbox = HBoxContainer.new()
	propeller_hbox.name = "PropellerHBox"
	propeller_hbox.custom_minimum_size = Vector2(400, 120)
	
	propeller_container.add_child(propeller_hbox)
	propeller_section.add_child(propeller_label)
	propeller_section.add_child(propeller_container)
	parent.add_child(propeller_section)
	
	add_debug_style(propeller_section, Color(0.5, 0, 1, 0.2))

func add_debug_style(control: Control, color: Color):
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.border_width_bottom = 1
	stylebox.border_width_left = 1
	stylebox.border_width_right = 1
	stylebox.border_width_top = 1
	stylebox.border_color = Color(1, 1, 1, 0.5)
	control.add_theme_stylebox_override("panel", stylebox)

func create_component_buttons():
	create_frame_buttons()
	create_board_buttons()
	create_motor_buttons()
	create_propeller_buttons()

func create_frame_buttons():
	var frame_hbox = $UI/ComponentSelectors/FrameSelector/FrameContainer/FrameHBox
	
	for child in frame_hbox.get_children():
		child.queue_free()
	frame_buttons.clear()
	
	for frame_name in frame_prefabs.keys():
		var button = Button.new()
		button.text = frame_name
		button.custom_minimum_size = Vector2(100, 100)
		button.connect("pressed", _on_frame_button_pressed.bind(frame_name))
		frame_hbox.add_child(button)
		frame_buttons.append(button)
	
	if frame_buttons.size() > 0:
		update_button_selector(frame_buttons, current_frame_type)

func create_board_buttons():
	var board_hbox = $UI/ComponentSelectors/BoardSelector/BoardContainer/BoardHBox
	
	for child in board_hbox.get_children():
		child.queue_free()
	board_buttons.clear()
	
	for board_name in board_prefabs.keys():
		var button = Button.new()
		button.text = board_name
		button.custom_minimum_size = Vector2(100, 100)
		button.connect("pressed", _on_board_button_pressed.bind(board_name))
		board_hbox.add_child(button)
		board_buttons.append(button)
	
	if board_buttons.size() > 0:
		update_button_selector(board_buttons, current_board_type)

func create_motor_buttons():
	var motor_hbox = $UI/ComponentSelectors/MotorSelector/MotorContainer/MotorHBox
	
	for child in motor_hbox.get_children():
		child.queue_free()
	motor_buttons.clear()
	
	for motor_name in motor_prefabs.keys():
		var button = Button.new()
		button.text = motor_name
		button.custom_minimum_size = Vector2(100, 100)
		button.connect("pressed", _on_motor_button_pressed.bind(motor_name))
		motor_hbox.add_child(button)
		motor_buttons.append(button)
	
	if motor_buttons.size() > 0:
		update_button_selector(motor_buttons, current_motor_type)

func create_propeller_buttons():
	var propeller_hbox = $UI/ComponentSelectors/PropellerSelector/PropellerContainer/PropellerHBox
	
	for child in propeller_hbox.get_children():
		child.queue_free()
	propeller_buttons.clear()
	
	for propeller_name in propeller_prefabs.keys():
		var button = Button.new()
		button.text = propeller_name
		button.custom_minimum_size = Vector2(100, 100)
		button.connect("pressed", _on_propeller_button_pressed.bind(propeller_name))
		propeller_hbox.add_child(button)
		propeller_buttons.append(button)
	
	if propeller_buttons.size() > 0:
		update_button_selector(propeller_buttons, current_propeller_type)

func _on_frame_button_pressed(frame_name):
	if Global.is_component_available("frame", frame_name):
		current_frame_type = frame_name
		add_frame()
		update_button_selector(frame_buttons, frame_name)

func _on_board_button_pressed(board_name):
	if Global.is_component_available("board", board_name):
		current_board_type = board_name
		add_board()
		update_button_selector(board_buttons, board_name)

func _on_motor_button_pressed(motor_name):
	if Global.is_component_available("motor", motor_name):
		current_motor_type = motor_name
		add_motor()
		update_button_selector(motor_buttons, motor_name)

func _on_propeller_button_pressed(propeller_name):
	if Global.is_component_available("propeller", propeller_name):
		current_propeller_type = propeller_name
		add_propeller()
		update_button_selector(propeller_buttons, propeller_name)

func update_button_selector(buttons, selected_name):
	for button in buttons:
		if button.text == selected_name:
			button.add_theme_color_override("font_color", Color(0, 1, 0))
		else:
			button.add_theme_color_override("font_color", Color(1, 1, 1))

func find_component_list():
	if has_node("UI/Hierarchy/Complist"):
		return $UI/Hierarchy/Complist
	elif has_node("UI/Hierarchy/ComponentList"):
		return $UI/Hierarchy/ComponentList
	elif has_node("UI/Hierarchy/List"):
		return $UI/Hierarchy/List
	else:
		var hierarchy = $UI/Hierarchy
		if hierarchy and hierarchy.get_child_count() > 0:
			for child in hierarchy.get_children():
				if child is ItemList:
					return child
				elif child.get_child_count() > 0:
					for grandchild in child.get_children():
						if grandchild is ItemList:
							return grandchild
	return null

func create_component_list():
	component_list = ItemList.new()
	component_list.name = "Complist"
	component_list.size = Vector2(280, 350)
	
	if list_panel:
		list_panel.add_child(component_list)
		component_list.position = Vector2(10, 10)
	else:
		print("Не могу создать Complist - нет панели Hierarchy")

func add_save_load_buttons():
	var save_load_container = HBoxContainer.new()
	save_load_container.position = Vector2(1920/2-200, 0)
	save_load_container.size = Vector2(200, 50)
	
	var save_button = Button.new()
	save_button.text = "💾 Сохранить дрон"
	save_button.connect("pressed", save_drone)
	
	var load_button = Button.new()
	load_button.text = "📂 Загрузить дрон"
	load_button.connect("pressed", load_drone)
	
	var export_button = Button.new()
	export_button.text = "🚀 Экспорт сцены"
	export_button.connect("pressed", export_drone_scene)
	
	save_load_container.add_child(save_button)
	save_load_container.add_child(load_button)
	save_load_container.add_child(export_button)
	
	$UI.add_child(save_load_container)

func connect_buttons():
	if has_node("UI/OpenClose"):
		$UI/OpenClose.connect("pressed", _on_OpenClose_pressed)
	else:
		print("Кнопка OpenClose не найдена!")
	
	if component_list:
		if not component_list.is_connected("item_clicked", _on_component_list_item_clicked):
			component_list.connect("item_clicked", _on_component_list_item_clicked)
		
		# Добавляем обработку перетаскивания из списка
		if not component_list.is_connected("item_selected", _on_component_list_item_selected):
			component_list.connect("item_selected", _on_component_list_item_selected)

func create_grid():
	for x in range(-5, 6):
		for z in range(-5, 6):
			var grid_cube = MeshInstance3D.new()
			var cube_mesh = BoxMesh.new()
			cube_mesh.size = Vector3(0.9, 0.1, 0.9)
			
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.3)
			cube_mesh.material = material
			
			grid_cube.mesh = cube_mesh
			grid_cube.position = Vector3(x, 0, z)
			$Grid.add_child(grid_cube)

func create_floor_line():
	var line_mesh = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	material.albedo_color = Color(1, 0, 0, 0.8)
	material.flags_unshaded = true
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(Vector3(-6, 0.02, 0))
	immediate_mesh.surface_add_vertex(Vector3(6, 0.02, 0))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.02, -6))
	immediate_mesh.surface_add_vertex(Vector3(0, 0.02, 6))
	immediate_mesh.surface_end()
	
	line_mesh.mesh = immediate_mesh
	add_child(line_mesh)

# Функция для проверки границ
func is_position_within_bounds(position: Vector3) -> bool:
	return (position.x >= BOUNDS_MIN.x and position.x <= BOUNDS_MAX.x and
			position.y >= BOUNDS_MIN.y and position.y <= BOUNDS_MAX.y and
			position.z >= BOUNDS_MIN.z and position.z <= BOUNDS_MAX.z)

# Функция для ограничения позиции в пределах границ
func clamp_position(position: Vector3) -> Vector3:
	return Vector3(
		clamp(position.x, BOUNDS_MIN.x, BOUNDS_MAX.x),
		clamp(position.y, BOUNDS_MIN.y, BOUNDS_MAX.y),
		clamp(position.z, BOUNDS_MIN.z, BOUNDS_MAX.z)
	)

func save_drone():
	if not is_drone_complete():
		print("Дрон не собран полностью! Нельзя сохранить.")
		return
	
	var drone_data = {
		"frame": get_component_data(drone_frame),
		"board": get_component_data(drone_board) if drone_board else null,
		"motors": [],
		"propellers": []
	}
	
	for motor in motors:
		if is_instance_valid(motor):
			drone_data["motors"].append(get_component_data(motor))
	
	for propeller in propellers:
		if is_instance_valid(propeller):
			drone_data["propellers"].append(get_component_data(propeller))
	
	var file = FileAccess.open("user://saved_drone.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(drone_data))
		file.close()
		print("Дрон сохранен в user://saved_drone.json")
	else:
		print("Ошибка сохранения дрона!")

func load_drone():
	var file = FileAccess.open("user://saved_drone.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var drone_data = json.data
			clear_drone()
			create_drone_from_data(drone_data)
			print("Дрон загружен!")
		else:
			print("Ошибка загрузки дрона: неверный формат файла")
	else:
		print("Файл сохранения не найден!")

func export_drone_scene():
	if not is_drone_complete():
		print("Дрон не собран полностью! Нельзя экспортировать.")
		return
	
	var drone_scene = PackedScene.new()
	var drone_root = CharacterBody3D.new()
	drone_root.name = "ExportedDrone"
	
	var drone_script = load("res://DroneLevels/Drone.gd")
	if drone_script:
		drone_root.set_script(drone_script)
		print("✅ Добавлен скрипт Drone.gd")
	
	if drone_frame and is_instance_valid(drone_frame):
		var frame_copy = drone_frame.duplicate()
		drone_root.add_child(frame_copy)
		frame_copy.owner = drone_root
		print("✅ Скопирована рама")
	
	if drone_board and is_instance_valid(drone_board):
		var board_copy = drone_board.duplicate()
		drone_root.add_child(board_copy)
		board_copy.owner = drone_root
		print("✅ Скопирована плата")
	
	for i in range(motors.size()):
		if is_instance_valid(motors[i]):
			var motor_copy = motors[i].duplicate()
			drone_root.add_child(motor_copy)
			motor_copy.owner = drone_root
			print("✅ Скопирован двигатель ", i+1)
	
	for i in range(propellers.size()):
		if is_instance_valid(propellers[i]):
			var propeller_copy = propellers[i].duplicate()
			drone_root.add_child(propeller_copy)
			propeller_copy.owner = drone_root
			print("✅ Скопирован пропеллер ", i+1)
	
	drone_root.position = Vector3(0, 1, 0)
	add_collision_to_drone(drone_root)
	
	var result = drone_scene.pack(drone_root)
	if result == OK:
		var error = ResourceSaver.save(drone_scene, "user://exported_drone.tscn")
		if error == OK:
			print("✅ Сцена дрона экспортирована в user://exported_drone.tscn")
			print_drone_structure(drone_root)
		else:
			print("❌ Ошибка экспорта сцены!")
	else:
		print("❌ Ошибка упаковки сцены!")

func add_collision_to_drone(drone_node: CharacterBody3D):
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3, 1, 3)
	collision.shape = shape
	collision.position = Vector3(0, 0.5, 0)
	drone_node.add_child(collision)
	collision.owner = drone_node
	print("✅ Добавлена коллизия дрону")

func print_drone_structure(node: Node, indent: int = 0):
	var indent_str = "  ".repeat(indent)
	print(indent_str + "└─ " + node.name + " (" + node.get_class() + ") позиция: " + str(node.position))
	for child in node.get_children():
		if child is Node3D:
			print_drone_structure(child, indent + 1)

func get_component_data(component):
	if component == null or not is_instance_valid(component):
		return null
	
	var component_type = ""
	
	if component == drone_frame:
		component_type = current_frame_type
	elif component == drone_board:
		component_type = current_board_type
	elif component in motors:
		component_type = current_motor_type
	elif component in propellers:
		component_type = current_propeller_type
	
	return {
		"component_type": component_type,
		"component_name": component.component_name if component.has_method("get_component_name") else component_type,
		"position": {
			"x": component.position.x,
			"y": component.position.y,
			"z": component.position.z
		},
		"rotation": {
			"x": component.rotation.x,
			"y": component.rotation.y,
			"z": component.rotation.z
		}
	}

func create_drone_from_data(drone_data):
	clear_drone()
	
	if drone_data.get("frame"):
		add_frame_from_data(drone_data["frame"])
	
	if drone_data.get("board"):
		add_board_from_data(drone_data["board"])
	
	if drone_data.get("motors"):
		for motor_data in drone_data["motors"]:
			add_motor_from_data(motor_data)
	
	if drone_data.get("propellers"):
		for propeller_data in drone_data["propellers"]:
			add_propeller_from_data(propeller_data)
	
	update_component_list()
	print("Дрон полностью загружен из данных")
	
func add_frame_from_data(frame_data):
	if frame_data == null:
		return
		
	var frame_type = frame_data.get("component_type", "Рама1")
	var frame_prefab = frame_prefabs.get(frame_type)
	
	if frame_prefab:
		var new_frame = frame_prefab.instantiate()
		components_container.add_child(new_frame)
		new_frame.position = Vector3(frame_data["position"]["x"], frame_data["position"]["y"], frame_data["position"]["z"])
		new_frame.rotation = Vector3(frame_data["rotation"]["x"], frame_data["rotation"]["y"], frame_data["rotation"]["z"])
		drone_frame = new_frame
		current_frame_type = frame_type
		update_button_selector(frame_buttons, frame_type)
		print("Рама создана из данных, тип: ", current_frame_type, " позиция: ", new_frame.position)
	else:
		print("Ошибка: не найден префаб для рамы типа ", frame_type)
		add_frame()

func add_board_from_data(board_data):
	if board_data == null:
		return
		
	var board_type = board_data.get("component_type", "Плата1")
	var board_prefab = board_prefabs.get(board_type)
	
	if board_prefab:
		var new_board = board_prefab.instantiate()
		components_container.add_child(new_board)
		new_board.position = Vector3(board_data["position"]["x"], board_data["position"]["y"], board_data["position"]["z"])
		new_board.rotation = Vector3(board_data["rotation"]["x"], board_data["rotation"]["y"], board_data["rotation"]["z"])
		drone_board = new_board
		current_board_type = board_type
		update_button_selector(board_buttons, board_type)
		print("Плата создана из данных, тип: ", current_board_type, " позиция: ", new_board.position)
	else:
		print("Ошибка: не найден префаб для платы типа ", board_type)
		add_board()

func add_motor_from_data(motor_data):
	if motor_data == null:
		return
		
	var motor_type = motor_data.get("component_type", "Мотор1")
	var motor_prefab = motor_prefabs.get(motor_type)
	
	if motor_prefab:
		var new_motor = motor_prefab.instantiate()
		components_container.add_child(new_motor)
		new_motor.position = Vector3(motor_data["position"]["x"], motor_data["position"]["y"], motor_data["position"]["z"])
		new_motor.rotation = Vector3(motor_data["rotation"]["x"], motor_data["rotation"]["y"], motor_data["rotation"]["z"])
		motors.append(new_motor)
		
		if motors.size() == 1:
			current_motor_type = motor_type
			update_button_selector(motor_buttons, motor_type)
		
		print("Двигатель создан из данных, тип: ", motor_type, " позиция: ", new_motor.position)
	else:
		print("Ошибка: не найден префаб для мотора типа ", motor_type)
		add_motor()

func add_propeller_from_data(propeller_data):
	if propeller_data == null:
		return
		
	var propeller_type = propeller_data.get("component_type", "Пропеллер1")
	var propeller_prefab = propeller_prefabs.get(propeller_type)
	
	if propeller_prefab:
		var new_propeller = propeller_prefab.instantiate()
		components_container.add_child(new_propeller)
		new_propeller.position = Vector3(propeller_data["position"]["x"], propeller_data["position"]["y"], propeller_data["position"]["z"])
		new_propeller.rotation = Vector3(propeller_data["rotation"]["x"], propeller_data["rotation"]["y"], propeller_data["rotation"]["z"])
		propellers.append(new_propeller)
		
		if propellers.size() == 1:
			current_propeller_type = propeller_type
			update_button_selector(propeller_buttons, propeller_type)
		
		print("Пропеллер создан из данных, тип: ", propeller_type, " позиция: ", new_propeller.position)
	else:
		print("Ошибка: не найден префаб для пропеллера типа ", propeller_type)
		add_propeller()

func clear_drone():
	if drone_frame and is_instance_valid(drone_frame):
		drone_frame.queue_free()
	drone_frame = null
	
	if drone_board and is_instance_valid(drone_board):
		drone_board.queue_free()
	drone_board = null
	
	for motor in motors:
		if is_instance_valid(motor):
			motor.queue_free()
	motors.clear()
	
	for propeller in propellers:
		if is_instance_valid(propeller):
			propeller.queue_free()
	propellers.clear()
	
	current_frame_type = "Рама1"
	current_board_type = "Плата1" 
	current_motor_type ="Мотор1"
	current_propeller_type = "Пропеллер1"
	
	update_button_selector(frame_buttons, current_frame_type)
	update_button_selector(board_buttons, current_board_type)
	update_button_selector(motor_buttons, current_motor_type)
	update_button_selector(propeller_buttons, current_propeller_type)
	
	update_component_list()

func is_drone_complete():
	return (drone_frame != null and is_instance_valid(drone_frame) and
			drone_board != null and is_instance_valid(drone_board) and 
			motors.size() >= 4 and 
			propellers.size() >= 4)

# ========== СИСТЕМА ПЕРЕТАСКИВАНИЯ КОМПОНЕНТОВ ==========

func _input(event):
	# Вращение камеры
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_rotating = true
			is_dragging_camera = true
			last_mouse_pos = event.position
			rotation_velocity = Vector2(0, 0)
		else:
			is_rotating = false
			is_dragging_camera = false
	
	# Вращение камеры
	if event is InputEventMouseMotion and is_rotating:
		var mouse_delta = event.position - last_mouse_pos
		rotation_velocity = Vector2(
			-mouse_delta.y * ROTATION_SPEED * 0.5,
			-mouse_delta.x * ROTATION_SPEED * 0.5
		)
		camera_rotation.x += -mouse_delta.y * ROTATION_SPEED
		camera_rotation.y += -mouse_delta.x * ROTATION_SPEED
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		last_mouse_pos = event.position
		update_camera_position()
	
	# Зум колесиком
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clamp(camera_distance - ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clamp(camera_distance + ZOOM_SPEED, MIN_DISTANCE, MAX_DISTANCE)
			update_camera_position()
	
	# Перетаскивание компонентов ЛЕВОЙ кнопкой
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Если перетаскиваем из списка
			if is_dragging_from_list and component_to_create_from_list:
				create_component_from_list_drag(event.position)
			else:
				# Обычное перетаскивание существующего компонента
				var component = get_component_under_mouse(event.position)
				if component and is_component_draggable(component):
					start_component_dragging(component, event.position)
		else:
			if is_dragging_component:
				stop_component_dragging()
			is_dragging_from_list = false
			component_to_create_from_list = null
	
	# Движение при перетаскивании
	if event is InputEventMouseMotion and is_dragging_component and dragged_component:
		update_component_dragging(event.position)

# Функция для центрирования мыши на элементе
func center_mouse_on_component(component):
	if not component or not is_instance_valid(component):
		return
	
	var viewport = get_viewport()
	var camera = $CameraPivot/Camera3D
	
	# Получаем позицию компонента в экранных координатах
	var screen_pos = camera.unproject_position(component.global_position)
	
	# Устанавливаем позицию мыши точно в центр компонента
	Input.warp_mouse(screen_pos)
	
	# Обновляем last_mouse_pos для корректной работы перетаскивания
	last_mouse_pos = screen_pos
	
	print("Мышь центрирована на компоненте: ", get_component_name(component), " позиция: ", screen_pos)

# Обработка выбора в списке компонентов (для перетаскивания)
func _on_component_list_item_selected(index: int):
	var item_text = component_list.get_item_text(index)
	print("Выбран элемент списка: ", item_text)
	
	# Определяем тип компонента по тексту
	if item_text.begins_with("Рама:"):
		component_to_create_from_list = "frame"
	elif item_text.begins_with("Плата:"):
		component_to_create_from_list = "board"
	elif item_text.begins_with("Двигатель"):
		component_to_create_from_list = "motor"
	elif item_text.begins_with("Пропеллер"):
		component_to_create_from_list = "propeller"
	
	if component_to_create_from_list:
		is_dragging_from_list = true
		print("Начато перетаскивание из списка: ", component_to_create_from_list)

# Создание компонента при перетаскивании из списка
func create_component_from_list_drag(mouse_position):
	var component_type = component_to_create_from_list
	
	match component_type:
		"frame":
			if not drone_frame:
				add_frame()
				if drone_frame:
					# Для списка используем текущую позицию мыши, а не центрирование
					start_component_dragging(drone_frame, mouse_position)
		"board":
			if not drone_board and drone_frame:
				add_board()
				if drone_board:
					start_component_dragging(drone_board, mouse_position)
		"motor":
			if drone_frame and motors.size() < 4:
				add_motor()
				if motors.size() > 0:
					var new_motor = motors[motors.size() - 1]
					start_component_dragging(new_motor, mouse_position)
		"propeller":
			if motors.size() > 0 and propellers.size() < motors.size():
				add_propeller()
				if propellers.size() > 0:
					var new_propeller = propellers[propellers.size() - 1]
					start_component_dragging(new_propeller, mouse_position)
	
	is_dragging_from_list = false
	component_to_create_from_list = null

# Находим компонент под мышью
# Примерный радиус компонента
func get_component_radius(component) -> float:
	var component_type = get_component_type(component)
	match component_type:
		"frame": return 2.0
		"board": return 0.5
		"motor": return 0.3
		"propeller": return 0.4
		_: return 0.5

# Проверяем, можно ли перетаскивать компонент
func is_component_draggable(component):
	if component == null or not is_instance_valid(component):
		return false
	return (component == drone_frame or 
			component == drone_board or 
			motors.has(component) or 
			propellers.has(component))

# Начинаем перетаскивание
# Автоматическая привязка к раме
# Находим компонент под мышью - ПРОСТАЯ И РАБОЧАЯ ВЕРСИЯ
func get_component_under_mouse(mouse_position: Vector2) -> Node3D:
	var camera = $CameraPivot/Camera3D
	var from = camera.project_ray_origin(mouse_position)
	var ray_dir = camera.project_ray_normal(mouse_position)
	
	var all_components = get_all_drone_components()
	var closest_component = null
	var closest_distance = INF
	
	for component in all_components:
		if not is_instance_valid(component):
			continue
		
		# Используем простой расчет расстояния до центра компонента
		var component_pos = component.global_position
		var to_comp = component_pos - from
		var projection = to_comp.dot(ray_dir)
		
		if projection > 0:
			var closest_point = from + ray_dir * projection
			var distance = closest_point.distance_to(component_pos)
			
			# Увеличиваем радиус для лучшего обнаружения
			var component_radius = 1.5  # Большой радиус для надежности
			
			if distance < component_radius and distance < closest_distance:
				closest_distance = distance
				closest_component = component
	
	return closest_component

# Получаем все компоненты дрона - УПРОЩЕННАЯ ВЕРСИЯ
func get_all_drone_components() -> Array:
	var components = []
	
	if drone_frame and is_instance_valid(drone_frame):
		components.append(drone_frame)
	if drone_board and is_instance_valid(drone_board):
		components.append(drone_board)
	
	for motor in motors:
		if is_instance_valid(motor):
			components.append(motor)
	
	for propeller in propellers:
		if is_instance_valid(propeller):
			components.append(propeller)
	
	return components

# Начинаем перетаскивание - УПРОЩЕННАЯ И РАБОЧАЯ ВЕРСИЯ
func start_component_dragging(component, mouse_position):
	if not is_instance_valid(component):
		return
		
	dragged_component = component
	original_component_position = component.global_position
	is_dragging_component = true
	
	# Очищаем старые смещения
	child_offsets.clear()
	
	# Если перетаскиваем раму - сохраняем смещения всех прикрепленных компонентов
	if component == drone_frame:
		if drone_board and is_instance_valid(drone_board):
			child_offsets[drone_board] = drone_board.global_position - component.global_position
		
		for motor in motors:
			if is_instance_valid(motor):
				child_offsets[motor] = motor.global_position - component.global_position
		
		for propeller in propellers:
			if is_instance_valid(propeller):
				child_offsets[propeller] = propeller.global_position - component.global_position
	
	# Вычисляем смещение для точного перетаскивания
	var camera = $CameraPivot/Camera3D
	var from = camera.project_ray_origin(mouse_position)
	var ray_dir = camera.project_ray_normal(mouse_position)
	
	var drag_plane = Plane(Vector3.UP, component.global_position.y)
	var intersection = drag_plane.intersects_ray(from, from + ray_dir * 1000)
	
	if intersection:
		drag_offset = component.global_position - intersection
	else:
		drag_offset = Vector3.ZERO
	
	print("🚀 Начато перетаскивание: ", get_component_name(component))

# Обновляем перетаскивание - УПРОЩЕННАЯ ВЕРСИЯ
func update_component_dragging(mouse_position):
	if not dragged_component or not is_instance_valid(dragged_component):
		stop_component_dragging()
		return
	
	var camera = $CameraPivot/Camera3D
	var from = camera.project_ray_origin(mouse_position)
	var ray_dir = camera.project_ray_normal(mouse_position)
	
	var drag_plane = Plane(Vector3.UP, original_component_position.y)
	var intersection = drag_plane.intersects_ray(from, from + ray_dir * 1000)
	
	if intersection:
		var new_position = intersection + drag_offset
		new_position.y = original_component_position.y  # Сохраняем высоту
		
		# Ограничиваем в пределах границ
		new_position = clamp_position(new_position)
		
		# Вычисляем дельту перемещения
		var delta = new_position - dragged_component.global_position
		
		# Перемещаем основной компонент
		dragged_component.global_position = new_position
		
		# Перемещаем все дочерние компоненты (если перетаскиваем раму)
		for child in child_offsets:
			if is_instance_valid(child):
				var child_new_position = child.global_position + delta
				child_new_position = clamp_position(child_new_position)
				child.global_position = child_new_position
		
		# Для отдельных компонентов (не рамы) делаем автопривязку во время перетаскивания
		if dragged_component != drone_frame:
			preview_auto_snap()

# Предварительная автопривязка при перетаскивании
func preview_auto_snap():
	if not dragged_component or not is_instance_valid(dragged_component):
		return
	
	var component_type = get_component_type(dragged_component)
	
	if component_type == "board" and drone_frame:
		var target_pos = drone_frame.global_position + Vector3(0, 0.2, 0)
		var current_pos = dragged_component.global_position
		if current_pos.distance_to(target_pos) < 1.0:
			# Визуальная обратная связь - можно добавить свечение
			print("Близко к центру рамы - отпустите для прикрепления")

# Заканчиваем перетаскивание - УПРОЩЕННАЯ ВЕРСИЯ
func stop_component_dragging():
	if dragged_component and is_instance_valid(dragged_component):
		# Финальная автопривязка
		auto_snap_to_frame()
		
		# Обновляем структуру данных
		var component_type = get_component_type(dragged_component)
		
		# Для пропеллеров - усиленная проверка прикрепления
		if component_type == "propeller":
			var attached_to_motor = false
			for motor in motors:
				if is_instance_valid(motor):
					var target_pos = motor.global_position + Vector3(0, 0.3, 0)
					var current_pos = dragged_component.global_position
					
					if current_pos.distance_to(target_pos) < 0.8:
						dragged_component.global_position = target_pos
						dragged_component.rotation = motor.rotation
						attached_to_motor = true
						print("✅ Пропеллер прикреплен к двигателю")
						break
			
			if not attached_to_motor:
				print("⚠️ Пропеллер не прикреплен к двигателю")
		
		# Обновляем списки компонентов
		match component_type:
			"board":
				drone_board = dragged_component
				print("✅ Плата установлена")
			"motor":
				if not motors.has(dragged_component):
					motors.append(dragged_component)
					print("✅ Двигатель добавлен")
			"propeller":
				if not propellers.has(dragged_component):
					propellers.append(dragged_component)
					print("✅ Пропеллер добавлен")
		
		update_component_list()
		print("🏁 Завершено перетаскивание: ", get_component_name(dragged_component))
	
	is_dragging_component = false
	dragged_component = null
	child_offsets.clear()

# Упрощенная автопривязка
func auto_snap_to_frame():
	if not dragged_component or not is_instance_valid(dragged_component):
		return
	
	var component_type = get_component_type(dragged_component)
	
	if component_type == "board" and drone_frame:
		var target_pos = drone_frame.global_position + Vector3(0, 0.2, 0)
		var current_pos = dragged_component.global_position
		if current_pos.distance_to(target_pos) < 1.0:
			dragged_component.global_position = target_pos
	
	elif component_type == "motor" and drone_frame:
		var motor_points = [
			drone_frame.global_position + Vector3(1, 0.2, 1),
			drone_frame.global_position + Vector3(-1, 0.2, 1),
			drone_frame.global_position + Vector3(1, 0.2, -1),
			drone_frame.global_position + Vector3(-1, 0.2, -1)
		]
		
		var current_pos = dragged_component.global_position
		for point in motor_points:
			if current_pos.distance_to(point) < 1.0:
				var position_free = true
				for motor in motors:
					if motor != dragged_component and is_instance_valid(motor) and motor.global_position.distance_to(point) < 0.5:
						position_free = false
						break
				
				if position_free:
					dragged_component.global_position = point
					break
# Заканчиваем перетаскивание

# Получаем тип компонента
func get_component_type(component):
	if component == drone_frame:
		return "frame"
	elif component == drone_board:
		return "board"
	elif motors.has(component):
		return "motor"
	elif propellers.has(component):
		return "propeller"
	else:
		return "unknown"

# Получаем имя компонента
func get_component_name(component):
	if component == drone_frame:
		return "Рама"
	elif component == drone_board:
		return "Плата"
	elif motors.has(component):
		var index = motors.find(component)
		return "Двигатель " + str(index + 1)
	elif propellers.has(component):
		var index = propellers.find(component)
		return "Пропеллер " + str(index + 1)
	else:
		return "Неизвестный компонент"

# ========== ОСТАЛЬНЫЕ ФУНКЦИИ ==========

func _process(delta):
	# Обновляем инерцию камеры
	if not is_dragging_camera and (rotation_velocity.x != 0 or rotation_velocity.y != 0):
		camera_rotation.x += rotation_velocity.x
		camera_rotation.y += rotation_velocity.y
		camera_rotation.x = clamp(camera_rotation.x, MIN_VERTICAL_ANGLE, MAX_VERTICAL_ANGLE)
		rotation_velocity *= FRICTION
		
		if abs(rotation_velocity.x) < 0.0001 and abs(rotation_velocity.y) < 0.0001:
			rotation_velocity = Vector2(0, 0)
		
		update_camera_position()

func update_camera_position():
	var target_position = Vector3.ZERO
	var camera_position = Vector3(
		sin(camera_rotation.y) * cos(camera_rotation.x),
		sin(camera_rotation.x),
		cos(camera_rotation.y) * cos(camera_rotation.x)
	) * camera_distance
	
	camera.position = camera_position
	camera.look_at(target_position, Vector3.UP)

func _on_OpenClose_pressed():
	if list_panel and component_list:
		list_panel.visible = !list_panel.visible
		update_component_list()

func update_component_list():
	if component_list == null:
		return
		
	component_list.clear()
	
	if drone_frame and is_instance_valid(drone_frame):
		component_list.add_item("Рама: " + current_frame_type)
	if drone_board and is_instance_valid(drone_board):
		component_list.add_item("Плата: " + current_board_type)
	
	for i in range(motors.size()):
		if i < motors.size() and is_instance_valid(motors[i]):
			component_list.add_item("Двигатель " + str(i+1) + ": " + current_motor_type)
	
	for i in range(propellers.size()):
		if i < propellers.size() and is_instance_valid(propellers[i]):
			component_list.add_item("Пропеллер " + str(i+1) + ": " + current_propeller_type)

func _on_component_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	print("Клик по элементу ", index, " кнопкой мыши ", mouse_button_index)
	
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		delete_component_by_index(index)

func delete_component_by_index(index: int):
	if component_list == null:
		print("Complist не найден")
		return
	
	var item_count = component_list.item_count
	if index < 0 or index >= item_count:
		print("Неверный индекс: ", index)
		return
	
	var item_text = component_list.get_item_text(index)
	print("Удаление компонента по тексту: ", item_text)
	
	if item_text.begins_with("Рама:"):
		print("Удаляем раму")
		delete_frame()
	elif item_text.begins_with("Плата:"):
		print("Удаляем плату")
		delete_board()
	elif item_text.begins_with("Двигатель"):
		var motor_number = extract_number_from_text(item_text)
		if motor_number != -1:
			print("Удаляем двигатель ", motor_number)
			delete_motor(motor_number - 1)
		else:
			print("Не удалось извлечь номер двигателя из: ", item_text)
	elif item_text.begins_with("Пропеллер"):
		var propeller_number = extract_number_from_text(item_text)
		if propeller_number != -1:
			print("Удаляем пропеллер ", propeller_number)
			delete_propeller(propeller_number - 1)
		else:
			print("Не удалось извлечь номер пропеллера из: ", item_text)

func extract_number_from_text(text: String) -> int:
	var regex = RegEx.new()
	regex.compile("(\\d+)")
	var result = regex.search(text)
	if result:
		return result.get_string(1).to_int()
	return -1

func delete_frame():
	if drone_frame and is_instance_valid(drone_frame):
		print("Начинаем удаление рамы")
		delete_board()
		
		while motors.size() > 0:
			delete_motor(0)
		
		drone_frame.queue_free()
		drone_frame = null
		update_component_list()
		print("Рама удалена")
	else:
		print("Рама уже удалена")

func delete_board():
	if drone_board and is_instance_valid(drone_board):
		print("Удаляем плату")
		drone_board.queue_free()
		drone_board = null
		update_component_list()
		print("Плата удалена")
	else:
		print("Плата уже удалена")

func delete_motor(index: int):
	if index >= 0 and index < motors.size() and is_instance_valid(motors[index]):
		print("Удаляем двигатель ", index + 1)
		if index < propellers.size():
			delete_propeller(index)
		
		motors[index].queue_free()
		motors.remove_at(index)
		update_component_list()
		print("Двигатель ", index + 1, " удален")
	else:
		print("Неверный индекс двигателя: ", index)

func delete_propeller(index: int):
	if index >= 0 and index < propellers.size() and is_instance_valid(propellers[index]):
		print("Удаляем пропеллер ", index + 1)
		propellers[index].queue_free()
		propellers.remove_at(index)
		update_component_list()
		print("Пропеллер ", index + 1, " удален")
	else:
		print("Неверный индекс пропеллера: ", index)


# ... (весь предыдущий код остается без изменений до функций создания компонентов)

func add_frame():
	if not Global.is_component_available("frame", current_frame_type):
		print("Рама '", current_frame_type, "' не доступна! Купите в магазине.")
		return
	if drone_frame == null:
		print("Создаем новую раму типа: ", current_frame_type)
		var frame_prefab = frame_prefabs.get(current_frame_type)
		if frame_prefab:
			var new_frame = frame_prefab.instantiate()
			components_container.add_child(new_frame)
			
			# Устанавливаем позицию под курсором без ограничений
			var mouse_pos = get_viewport().get_mouse_position()
			var world_pos = screen_to_world_position_unbounded(mouse_pos)
			new_frame.position = world_pos
			
			drone_frame = new_frame
			print("Рама создана, тип: ", current_frame_type, " позиция: ", new_frame.position)
			update_component_list()
			
			# Немедленно начинаем перетаскивание
			start_component_dragging(drone_frame, mouse_pos)
		else:
			print("Ошибка: префаб для рамы ", current_frame_type, " не найден!")
	else:
		print("Рама уже существует")

func add_board():
	if not Global.is_component_available("board", current_board_type):
		print("Плата '", current_board_type, "' не доступна! Купите в магазине.")
		return
	if drone_frame != null and drone_board == null:
		print("Создаем новую плату типа: ", current_board_type)
		var board_prefab = board_prefabs.get(current_board_type)
		if board_prefab:
			var new_board = board_prefab.instantiate()
			components_container.add_child(new_board)
			
			# Устанавливаем позицию под курсором без ограничений
			var mouse_pos = get_viewport().get_mouse_position()
			var world_pos = screen_to_world_position_unbounded(mouse_pos)
			new_board.position = world_pos
			
			drone_board = new_board
			print("Плата создана, тип: ", current_board_type, " позиция: ", new_board.position)
			update_component_list()
			
			# Немедленно начинаем перетаскивание
			start_component_dragging(drone_board, mouse_pos)
		else:
			print("Ошибка: префаб для платы ", current_board_type, " не найден!")
	else:
		print("Не могу создать плату: ", "нет рамы" if drone_frame == null else "плата уже существует")

func add_motor():
	if not Global.is_component_available("motor", current_motor_type):
		print("Мотор '", current_motor_type, "' не доступна! Купите в магазине.")
		return
	if drone_frame != null and motors.size() < 4:
		print("Создаем новый двигатель типа: ", current_motor_type)
		var motor_prefab = motor_prefabs.get(current_motor_type)
		if motor_prefab:
			var new_motor = motor_prefab.instantiate()
			components_container.add_child(new_motor)
			
			# Устанавливаем позицию под курсором без ограничений
			var mouse_pos = get_viewport().get_mouse_position()
			var world_pos = screen_to_world_position_unbounded(mouse_pos)
			new_motor.position = world_pos
			
			motors.append(new_motor)
			print("Двигатель создан, тип: ", current_motor_type, " позиция: ", new_motor.position)
			update_component_list()
			
			# Немедленно начинаем перетаскивание
			start_component_dragging(new_motor, mouse_pos)
		else:
			print("Ошибка: префаб для мотора ", current_motor_type, " не найден!")
	else:
		print("Не могу создать двигатель: ", "нет рамы" if drone_frame == null else "достигнут лимит двигателей")

func add_propeller():
	if not Global.is_component_available("propeller", current_propeller_type):
		print("Пропеллер '", current_propeller_type, "' не доступна! Купите в магазине.")
		return
	if motors.size() > 0 and propellers.size() < motors.size():
		print("Создаем новый пропеллер типа: ", current_propeller_type)
		var propeller_prefab = propeller_prefabs.get(current_propeller_type)
		if propeller_prefab:
			var new_propeller = propeller_prefab.instantiate()
			components_container.add_child(new_propeller)
			
			# Устанавливаем позицию под курсором без ограничений
			var mouse_pos = get_viewport().get_mouse_position()
			var world_pos = screen_to_world_position_unbounded(mouse_pos)
			new_propeller.position = world_pos
			
			propellers.append(new_propeller)
			print("Пропеллер создан, тип: ", current_propeller_type, " позиция: ", new_propeller.position)
			update_component_list()
			
			# Немедленно начинаем перетаскивание
			start_component_dragging(new_propeller, mouse_pos)
		else:
			print("Ошибка: префаб для пропеллера ", current_propeller_type, " не найден!")
	else:
		print("Не могу создать пропеллер: ", "нет двигателей" if motors.size() == 0 else "у всех двигателей уже есть пропеллеры")
	
# Функция для преобразования экранных координат в мировые БЕЗ ограничений
func screen_to_world_position_unbounded(screen_pos: Vector2) -> Vector3:
	var camera = $CameraPivot/Camera3D
	var from = camera.project_ray_origin(screen_pos)
	var ray_dir = camera.project_ray_normal(screen_pos)
	
	# Используем плоскость на уровне сетки (y=0.5)
	var drag_plane = Plane(Vector3.UP, 0.5)
	var intersection = drag_plane.intersects_ray(from, from + ray_dir * 1000)
	
	if intersection:
		return intersection  # Возвращаем позицию без ограничений
	else:
		return Vector3(0, 0.5, 0)


# Функция для проверки, находится ли позиция за границами
func is_out_of_bounds(position: Vector3) -> bool:
	return (position.x < BOUNDS_MIN.x or position.x > BOUNDS_MAX.x or
			position.z < BOUNDS_MIN.z or position.z > BOUNDS_MAX.z)

# ... (остальной код остается без изменений)
