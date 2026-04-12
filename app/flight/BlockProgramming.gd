extends Panel

@onready var block_palette = $BlockPalette
@onready var program_area = $ProgramArea

var dragged_block = null
var dragged_block_data = null
var program_blocks = []  # Хранит {type, container, count, color}
var is_dragging = false  # Флаг перетаскивания
var dragged_program_container: HBoxContainer = null
var dragged_program_preview: Control = null
var drag_overlay: Control = null
var dragged_program_original_index: int = -1
var dragged_program_current_index: int = -1
var pending_program_drag_container: HBoxContainer = null
var pending_program_drag_data: Dictionary = {}
var pending_program_drag_mouse_pos: Vector2 = Vector2.ZERO

const PROGRAM_DRAG_THRESHOLD := 14.0

# Сигнал для обновления предпросмотра траектории
signal trajectory_updated(sequence: Array)

func _ready():
	print("🧩 Инициализация панели программирования с перетаскиванием")
	setup_ui()
	_ensure_drag_overlay()
	apply_visual_theme()
	create_available_blocks()
	print("✅ Панель программирования готова")

func _ensure_drag_overlay() -> void:
	if drag_overlay != null and is_instance_valid(drag_overlay):
		return

	drag_overlay = Control.new()
	drag_overlay.name = "DragOverlay"
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_overlay.clip_contents = false
	drag_overlay.z_index = 200
	add_child(drag_overlay)

func setup_ui():
	# Настраиваем размеры панели
	custom_minimum_size = Vector2(600, 650)
	size = Vector2(600, 650)
	
	# Настраиваем контейнеры
	if block_palette:
		block_palette.custom_minimum_size = Vector2(200, 500)
		block_palette.size = Vector2(200, 500)
		block_palette.position = Vector2(20, 20)
	
	if program_area:
		program_area.custom_minimum_size = Vector2(350, 500)
		program_area.size = Vector2(350, 500)
		program_area.position = Vector2(230, 20)
		
		# Добавляем подсказку
		show_program_hint()

func apply_visual_theme():
	add_theme_stylebox_override("panel", _build_panel_style(
		Color(0.16, 0.11, 0.08, 0.96),
		Color(0.74, 0.57, 0.38, 0.82)
	))

	if block_palette:
		block_palette.add_theme_constant_override("separation", 10)

	if program_area:
		program_area.add_theme_constant_override("separation", 10)

func create_available_blocks():
	var blocks = [
		{"name": "Вперед", "type": 0, "color": Color.CORNFLOWER_BLUE, "icon": "⬆️"},
		{"name": "Назад", "type": 1, "color": Color.CORNFLOWER_BLUE, "icon": "⬇️"},
		{"name": "Влево", "type": 2, "color": Color.LIGHT_GREEN, "icon": "⬅️"},
		{"name": "Вправо", "type": 3, "color": Color.LIGHT_GREEN, "icon": "➡️"},
		{"name": "Вверх", "type": 4, "color": Color.GOLD, "icon": "🔼"},
		{"name": "Вниз", "type": 5, "color": Color.GOLD, "icon": "🔽"}
	]
	
	# Очищаем старые кнопки
	for child in block_palette.get_children():
		child.queue_free()
	
	# Создаем перетаскиваемые блоки
	for block_data in blocks:
		var draggable_block = create_draggable_block(block_data)
		block_palette.add_child(draggable_block)

func create_draggable_block(block_data: Dictionary) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 70)
	container.size = Vector2(180, 70)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Основная кнопка для перетаскивания
	var block_button = Button.new()
	block_button.text = block_data["icon"] + " " + block_data["name"]
	block_button.custom_minimum_size = Vector2(180, 60)
	block_button.size = Vector2(180, 60)
	block_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Яркий цветной стиль кнопки
	apply_block_style(block_button, block_data["color"])
	
	# Подсказка
	block_button.tooltip_text = "Перетащите в область программы"
	
	# Подключаем обработку перетаскивания
	block_button.gui_input.connect(_on_draggable_block_gui_input.bind(block_data, container))
	
	container.add_child(block_button)
	return container

func apply_block_style(button: Button, color: Color):
	var warm_color: Color = color.lerp(Color(0.60, 0.43, 0.26), 0.70)
	var normal: StyleBoxFlat = _build_button_style(warm_color, warm_color.lightened(0.16), 12)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = warm_color.lightened(0.08)
	hover.border_color = warm_color.lightened(0.24)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = warm_color.darkened(0.10)
	pressed.border_color = warm_color.lightened(0.08)
	
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color(0.98, 0.93, 0.86))
	button.add_theme_font_size_override("font_size", 16)

func _on_draggable_block_gui_input(event: InputEvent, block_data: Dictionary, container: Control):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			start_dragging(block_data, container)
			get_viewport().set_input_as_handled()
	
	# Обрабатываем перемещение мыши при активном перетаскивании
	elif event is InputEventMouseMotion and is_dragging:
		if dragged_block:
			set_drag_position(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func start_dragging(block_data: Dictionary, _original_container: Control):
	print("🎯 Начинаем перетаскивание: ", block_data["name"])
	
	# Создаем визуал перетаскиваемого блока с ТАКИМ ЖЕ ЦВЕТОМ
	dragged_block = create_drag_visual(block_data)
	dragged_block_data = block_data
	dragged_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Добавляем визуал в локальный overlay, чтобы центр ровно совпадал с курсором
	_ensure_drag_overlay()
	drag_overlay.add_child(dragged_block)
	
	set_drag_position(Vector2.ZERO)
	is_dragging = true

func create_drag_visual(block_data: Dictionary) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 60)
	container.size = Vector2(180, 60)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var visual = Button.new()
	visual.text = block_data["icon"] + " " + block_data["name"]
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.disabled = true
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Применяем ТАКОЙ ЖЕ цветной стиль как у оригинального блока
	apply_block_style(visual, block_data["color"])
	
	# Добавляем эффект тени для визуального выделения
	var shadow_style = style_box_with_shadow(block_data["color"])
	visual.add_theme_stylebox_override("disabled", shadow_style)
	
	container.add_child(visual)
	return container

func style_box_with_shadow(color: Color) -> StyleBoxFlat:
	var warm_color: Color = color.lerp(Color(0.60, 0.43, 0.26), 0.70)
	var style_box: StyleBoxFlat = _build_button_style(warm_color, warm_color.lightened(0.16), 12)
	style_box.shadow_color = Color(0, 0, 0, 0.6)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(3, 3)
	return style_box

func _apply_tool_button_style(button: Button, fill: Color, border: Color):
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))

	var normal: StyleBoxFlat = _build_button_style(fill, border, 10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.border_color = border.lightened(0.08)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

func _apply_line_edit_style(line_edit: LineEdit):
	line_edit.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.82, 0.71, 0.58))
	line_edit.add_theme_font_size_override("font_size", 16)

	var normal: StyleBoxFlat = _build_button_style(Color(0.21, 0.16, 0.11, 0.98), Color(0.70, 0.55, 0.36, 0.84), 10)
	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", normal)
	line_edit.add_theme_stylebox_override("read_only", normal)

func _build_button_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = fill
	style_box.border_color = border
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.content_margin_left = 12.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_right = 12.0
	style_box.content_margin_bottom = 8.0
	return style_box

func _build_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = fill
	style_box.border_color = border
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 18
	style_box.corner_radius_top_right = 18
	style_box.corner_radius_bottom_right = 18
	style_box.corner_radius_bottom_left = 18
	style_box.shadow_color = Color(0, 0, 0, 0.28)
	style_box.shadow_size = 14
	return style_box

func _input(event):
	if event is InputEventMouseMotion:
		if is_dragging and dragged_block:
			set_drag_position(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif dragged_program_preview != null:
			_set_program_drag_position(get_global_mouse_position())
			_preview_program_reorder(get_global_mouse_position())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			finish_dragging()
			get_viewport().set_input_as_handled()
		elif dragged_program_preview != null:
			finish_program_reorder()
			get_viewport().set_input_as_handled()

func set_drag_position(position: Vector2):
	if dragged_block:
		var visual_size: Vector2 = _get_drag_visual_size(dragged_block)
		var pointer_position: Vector2 = drag_overlay.get_local_mouse_position() if drag_overlay != null else position
		dragged_block.position = pointer_position - visual_size * 0.5

func finish_dragging():
	if not dragged_block or not dragged_block_data:
		return
		
	var drop_position = get_global_mouse_position()
	var program_rect = program_area.get_global_rect()
	
	if program_rect.has_point(drop_position):
		print("✅ Блок помещен в область программы")
		# Добавляем блок с количеством по умолчанию 1
		add_block_to_program(dragged_block_data, 1)
	else:
		print("❌ Блок помещен вне области программы")
	
	# Удаляем визуал перетаскивания
	dragged_block.queue_free()
	dragged_block = null
	dragged_block_data = null
	is_dragging = false

func add_block_to_program(block_data: Dictionary, count: int):
	# Убираем подсказку если она есть
	if program_area.get_child_count() > 0 and program_area.get_child(0) is Label:
		program_area.get_child(0).queue_free()
	
	var program_block = create_program_block(block_data, count)
	program_area.add_child(program_block)
	
	# Сохраняем блок в массиве
	program_blocks.append({
		"type": block_data["type"],
		"container": program_block,
		"count": count,
		"color": block_data["color"],
		"name": block_data["name"],
		"icon": block_data["icon"]
	})
	
	update_block_numbers()
	
	# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
	update_trajectory_preview()
	
	print("✅ Блок '", block_data["name"], "' добавлен в программу. Всего блоков: ", program_blocks.size())

func create_program_block(block_data: Dictionary, count: int) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(330, 58)
	container.size = Vector2(330, 58)
	container.add_theme_constant_override("separation", 8)
	
	# Блок команды с редактируемым количеством
	var block_content = Button.new()
	update_block_content_text(block_content, block_data, count)
	block_content.custom_minimum_size = Vector2(228, 46)
	block_content.size = Vector2(228, 46)
	block_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_content.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Применяем ТАКОЙ ЖЕ цветной стиль
	apply_block_style(block_content, block_data["color"])
	
	# Подключаем редактирование количества по клику
	block_content.gui_input.connect(_on_program_block_gui_input.bind(container, block_data))
	
	# Поле ввода количества (изначально скрыто)
	var count_edit = LineEdit.new()
	count_edit.custom_minimum_size = Vector2(58, 46)
	count_edit.visible = false
	count_edit.placeholder_text = str(count)
	count_edit.text = str(count)
	count_edit.focus_exited.connect(_on_count_edit_focus_exited.bind(container, count_edit, block_data))
	count_edit.text_submitted.connect(_on_count_text_submitted.bind(container, count_edit, block_data))
	_apply_line_edit_style(count_edit)
	
	# Кнопка удаления
	var delete_btn = Button.new()
	delete_btn.text = "🗑️"
	delete_btn.custom_minimum_size = Vector2(44, 46)
	delete_btn.tooltip_text = "Удалить блок"
	delete_btn.add_theme_font_size_override("font_size", 12)
	
	# Стиль для кнопки удаления
	_apply_tool_button_style(delete_btn, Color(0.48, 0.22, 0.18, 0.98), Color(0.82, 0.47, 0.36, 0.94))
	
	delete_btn.pressed.connect(_on_delete_block.bind(container))
	
	container.add_child(block_content)
	container.add_child(count_edit)
	container.add_child(delete_btn)
	
	return container

func update_block_content_text(button: Button, block_data: Dictionary, count: int):
	if count > 1:
		button.text = block_data["icon"] + " " + block_data["name"] + " ×" + str(count)
	else:
		button.text = block_data["icon"] + " " + block_data["name"]

func _on_edit_count(container: HBoxContainer, block_data: Dictionary):
	var block_content = container.get_child(0) as Button
	var count_edit = container.get_child(1) as LineEdit
	
	# Показываем поле ввода, скрываем кнопку
	block_content.visible = false
	count_edit.visible = true
	count_edit.grab_focus()
	count_edit.select_all()

func _on_count_edit_focus_exited(container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	apply_count_change(container, count_edit, block_data)

func _on_count_text_submitted(_new_text: String, container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	apply_count_change(container, count_edit, block_data)

func apply_count_change(container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	var block_content = container.get_child(0) as Button
	
	# Восстанавливаем видимость
	count_edit.visible = false
	block_content.visible = true
	
	# Обновляем количество
	var count = 1
	if count_edit.text.is_valid_int():
		count = clamp(count_edit.text.to_int(), 1, 25)
		count_edit.text = str(count)
	
	# Обновляем текст кнопки
	update_block_content_text(block_content, block_data, count)
	
	# Обновляем данные в массиве
	for i in range(program_blocks.size()):
		if program_blocks[i]["container"] == container:
			program_blocks[i]["count"] = count
			break
	
	# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
	update_trajectory_preview()

func _on_program_block_gui_input(event: InputEvent, container: HBoxContainer, block_data: Dictionary):
	var count_edit = container.get_child(1) as LineEdit
	if count_edit != null and count_edit.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pending_program_drag_container = container
			pending_program_drag_data = block_data.duplicate(true)
			pending_program_drag_mouse_pos = get_global_mouse_position()
			get_viewport().set_input_as_handled()
		elif pending_program_drag_container == container and dragged_program_preview == null:
			_clear_pending_program_drag()
			_on_edit_count(container, block_data)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pending_program_drag_container == container:
		if pending_program_drag_mouse_pos.distance_to(get_global_mouse_position()) >= PROGRAM_DRAG_THRESHOLD:
			_clear_pending_program_drag()
			start_program_reorder(container)
			get_viewport().set_input_as_handled()

func _clear_pending_program_drag() -> void:
	pending_program_drag_container = null
	pending_program_drag_data.clear()
	pending_program_drag_mouse_pos = Vector2.ZERO

func start_program_reorder(container: HBoxContainer) -> void:
	var block_index: int = _find_program_block_index(container)
	if block_index == -1:
		return

	var block_data: Dictionary = program_blocks[block_index]
	dragged_program_original_index = block_index
	dragged_program_current_index = block_index
	dragged_program_container = container
	dragged_program_preview = create_program_drag_visual(block_data)
	dragged_program_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_ensure_drag_overlay()
	drag_overlay.add_child(dragged_program_preview)
	_set_program_drag_position(Vector2.ZERO)

func _preview_program_reorder(drop_position: Vector2) -> void:
	if dragged_program_container == null:
		return

	var reorder_rect: Rect2 = program_area.get_global_rect().grow(24.0)
	if not reorder_rect.has_point(drop_position):
		if dragged_program_original_index != -1 and dragged_program_current_index != dragged_program_original_index:
			_reorder_program_block(dragged_program_container, dragged_program_original_index)
			dragged_program_current_index = dragged_program_original_index
		return

	var drop_index: int = _calculate_program_drop_index(drop_position)
	if drop_index == dragged_program_current_index:
		return

	_reorder_program_block(dragged_program_container, drop_index)
	dragged_program_current_index = _find_program_block_index(dragged_program_container)

func create_program_drag_visual(block_data: Dictionary) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(260, 50)
	preview.size = preview.custom_minimum_size

	var card := Button.new()
	var preview_color: Color = block_data.get("color", Color(0.60, 0.43, 0.26))
	update_block_content_text(card, block_data, int(block_data.get("count", 1)))
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.disabled = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_block_style(card, preview_color)

	var disabled_style: StyleBoxFlat = style_box_with_shadow(preview_color)
	card.add_theme_stylebox_override("disabled", disabled_style)
	card.modulate = Color(1.0, 1.0, 1.0, 0.96)

	preview.add_child(card)
	return preview

func _set_program_drag_position(position: Vector2) -> void:
	if dragged_program_preview != null:
		var visual_size: Vector2 = _get_drag_visual_size(dragged_program_preview)
		var pointer_position: Vector2 = drag_overlay.get_local_mouse_position() if drag_overlay != null else position
		dragged_program_preview.position = pointer_position - visual_size * 0.5

func _get_drag_visual_size(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	var size_value: Vector2 = control.size
	if size_value == Vector2.ZERO:
		size_value = control.get_combined_minimum_size()
	return size_value

func finish_program_reorder() -> void:
	if dragged_program_container == null:
		return

	var drop_position: Vector2 = get_global_mouse_position()
	if not program_area.get_global_rect().grow(24.0).has_point(drop_position):
		if dragged_program_original_index != -1:
			_reorder_program_block(dragged_program_container, dragged_program_original_index)
		_clear_program_drag_state()
		return

	_preview_program_reorder(drop_position)
	_clear_program_drag_state()
	update_block_numbers()
	update_trajectory_preview()

func _clear_program_drag_state() -> void:
	_clear_pending_program_drag()
	if dragged_program_container != null:
		dragged_program_container.modulate = Color(1, 1, 1, 1)
	if dragged_program_preview != null:
		dragged_program_preview.queue_free()
	dragged_program_container = null
	dragged_program_preview = null
	dragged_program_original_index = -1
	dragged_program_current_index = -1

func _calculate_program_drop_index(drop_position: Vector2) -> int:
	var logical_index := 0
	for child in program_area.get_children():
		if child is Label or child == dragged_program_container:
			continue
		var row := child as Control
		if row == null:
			continue
		var row_rect: Rect2 = row.get_global_rect()
		if drop_position.y < row_rect.position.y + row_rect.size.y * 0.5:
			return logical_index
		logical_index += 1
	return logical_index

func _reorder_program_block(container: HBoxContainer, insert_index: int) -> void:
	var from_index: int = _find_program_block_index(container)
	if from_index == -1:
		return

	var block_entry: Dictionary = program_blocks[from_index]
	program_blocks.remove_at(from_index)
	insert_index = maxi(0, mini(insert_index, program_blocks.size()))
	program_blocks.insert(insert_index, block_entry)
	program_area.move_child(container, insert_index)

func _find_program_block_index(container: HBoxContainer) -> int:
	for i in range(program_blocks.size()):
		if program_blocks[i]["container"] == container:
			return i
	return -1

func _on_delete_block(block_container: HBoxContainer):
	# Находим и удаляем блок из массива
	for i in range(program_blocks.size()):
		if program_blocks[i]["container"] == block_container:
			program_blocks.remove_at(i)
			break
	
	block_container.queue_free()
	
	# Обновляем номера оставшихся блоков
	update_block_numbers()
	
	# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
	update_trajectory_preview()
	
	print("🗑️ Блок удален. Осталось блоков: ", program_blocks.size())
	
	# Если программа пуста, показываем подсказку
	if program_blocks.is_empty():
		show_program_hint()

func update_block_numbers():
	# Номера блоков больше не показываем, но оставляем хук для совместимости
	return

func show_program_hint():
	# Удаляем старую подсказку
	for child in program_area.get_children():
		if child is Label:
			child.queue_free()
	
	var hint_label = Label.new()
	hint_label.text = "Перетащите блоки сюда"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.74, 0.62))
	program_area.add_child(hint_label)

func get_program_sequence() -> Array:
	var sequence = []
	
	print("📋 Получение последовательности программы...")
	print("Всего блоков в программе: ", program_blocks.size())
	
	for i in range(program_blocks.size()):
		var block_data = program_blocks[i]
		# Добавляем команду count раз
		for j in range(block_data["count"]):
			sequence.append(block_data["type"])
		print("  Блок ", i + 1, ": ", block_data["name"], " ×", block_data["count"])
	
	print("🎯 Итоговая последовательность: ", sequence)
	return sequence

func _on_clear_button_pressed():
	print("🧹 Очищаем программу...")
	print("Было блоков: ", program_blocks.size())
	
	# Удаляем все контейнеры
	for block_data in program_blocks:
		block_data["container"].queue_free()
	
	# Очищаем массив
	program_blocks.clear()
	
	# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
	update_trajectory_preview()
	
	# Показываем подсказку
	show_program_hint()
	
	print("✅ Программа очищена! Стало блоков: ", program_blocks.size())

func _on_close_button_pressed():
	print("❌ Закрываем панель программирования")
	hide()

# ================== ПРЕДПРОСМОТР ТРАЕКТОРИИ ==================
func update_trajectory_preview():
	var sequence = get_program_sequence()
	
	# Отправляем сигнал с последовательностью для предпросмотра
	trajectory_updated.emit(sequence)
	
	print("👀 Обновлен предпросмотр траектории для ", sequence.size(), " команд")

# ИСПРАВЛЕННАЯ ФУНКЦИЯ ВЫПОЛНЕНИЯ КОМАНД (для победы)
func execute_actions(sequence: Array) -> bool:
	if sequence.is_empty():
		print("⚠️ Пустая программа")
		return false
	
	print("🎯 Выполнение команд")
	
	for i in range(sequence.size()):
		var action = sequence[i]
		var command_name = get_direction_name(action)
		print("   ", i + 1, "/", sequence.size(), ": ", command_name)
		
		var move_success = await perform_movement(action)
		if not move_success:
			print("❌ Ошибка движения")
			return false
		
		if not await _wait_for_tree_timer(0.1):
			return false
	
	# После выполнения всех команд
	print("✅ Все команды выполнены успешно")
	print("🎯 ПРОГРАММА ЗАВЕРШЕНА С УСПЕХОМ")
	return true

func _wait_for_tree_timer(duration: float) -> bool:
	if duration <= 0.0:
		return get_tree() != null and is_inside_tree()
	if get_tree() == null or not is_inside_tree():
		return false
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	if timer == null:
		return false
	await timer.timeout
	return get_tree() != null and is_inside_tree()

# Вспомогательная функция для получения имени направления
func get_direction_name(direction: int) -> String:
	match direction:
		0: return "ВПЕРЕД"
		1: return "НАЗАД"
		2: return "ВЛЕВО"
		3: return "ВПРАВО"
		4: return "ВВЕРХ"
		5: return "ВНИЗ"
		_: return "???"

# Вспомогательная функция для выполнения движения
func perform_movement(direction: int) -> bool:
	# Эта функция в BlockProgramming.gd не используется для реального движения
	# Она только для отладки
	return true
