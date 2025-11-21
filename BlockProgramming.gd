extends Panel

@onready var block_palette = $BlockPalette
@onready var program_area = $ProgramArea

var dragged_block = null
var dragged_block_data = null
var program_blocks = []  # Хранит {type, container, count, color}
var is_dragging = false  # Флаг перетаскивания

# Сигнал для обновления предпросмотра траектории
signal trajectory_updated(sequence: Array)

func _ready():
	print("🧩 Инициализация панели программирования с перетаскиванием")
	setup_ui()
	create_available_blocks()
	print("✅ Панель программирования готова")

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
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.border_color = color.darkened(0.4)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	
	button.add_theme_stylebox_override("normal", style_box)
	button.add_theme_stylebox_override("disabled", style_box)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 14)

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

func start_dragging(block_data: Dictionary, original_container: Control):
	print("🎯 Начинаем перетаскивание: ", block_data["name"])
	
	# Создаем визуал перетаскиваемого блока с ТАКИМ ЖЕ ЦВЕТОМ
	dragged_block = create_drag_visual(block_data)
	dragged_block_data = block_data
	dragged_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Добавляем на верхний уровень
	get_parent().add_child(dragged_block)
	
	set_drag_position(get_global_mouse_position())
	is_dragging = true

func create_drag_visual(block_data: Dictionary) -> Control:
	var container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var visual = Button.new()
	visual.text = block_data["icon"] + " " + block_data["name"]
	visual.custom_minimum_size = Vector2(180, 60)
	visual.size = Vector2(180, 60)
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
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.border_color = color.darkened(0.4)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.shadow_color = Color(0, 0, 0, 0.6)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(3, 3)
	return style_box

func _input(event):
	# Завершаем перетаскивание при отпускании кнопки
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			finish_dragging()
			get_viewport().set_input_as_handled()

func set_drag_position(position: Vector2):
	if dragged_block:
		dragged_block.global_position = position - dragged_block.size / 2

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

# Остальные функции остаются без изменений...
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
	container.custom_minimum_size = Vector2(330, 55)
	container.size = Vector2(330, 55)
	
	# Кнопка перемещения вверх
	var up_btn = Button.new()
	up_btn.text = "↑"
	up_btn.custom_minimum_size = Vector2(30, 45)
	up_btn.tooltip_text = "Переместить выше"
	up_btn.add_theme_font_size_override("font_size", 12)
	up_btn.pressed.connect(_on_move_up.bind(container))
	
	# Кнопка перемещения вниз
	var down_btn = Button.new()
	down_btn.text = "↓"
	down_btn.custom_minimum_size = Vector2(30, 45)
	down_btn.tooltip_text = "Переместить ниже"
	down_btn.add_theme_font_size_override("font_size", 12)
	down_btn.pressed.connect(_on_move_down.bind(container))
	
	# Блок команды с редактируемым количеством
	var block_content = Button.new()
	update_block_content_text(block_content, block_data, count)
	block_content.custom_minimum_size = Vector2(150, 45)
	block_content.size = Vector2(150, 45)
	block_content.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Применяем ТАКОЙ ЖЕ цветной стиль
	apply_block_style(block_content, block_data["color"])
	
	# Подключаем редактирование количества по клику
	block_content.pressed.connect(_on_edit_count.bind(container, block_data))
	
	# Поле ввода количества (изначально скрыто)
	var count_edit = LineEdit.new()
	count_edit.custom_minimum_size = Vector2(50, 45)
	count_edit.visible = false
	count_edit.placeholder_text = str(count)
	count_edit.text = str(count)
	count_edit.focus_exited.connect(_on_count_edit_focus_exited.bind(container, count_edit, block_data))
	count_edit.text_submitted.connect(_on_count_text_submitted.bind(container, count_edit, block_data))
	
	# Кнопка удаления
	var delete_btn = Button.new()
	delete_btn.text = "🗑️"
	delete_btn.custom_minimum_size = Vector2(40, 45)
	delete_btn.tooltip_text = "Удалить блок"
	delete_btn.add_theme_font_size_override("font_size", 12)
	
	# Стиль для кнопки удаления
	var delete_style = StyleBoxFlat.new()
	delete_style.bg_color = Color(0.8, 0.2, 0.2)
	delete_style.corner_radius_top_left = 5
	delete_style.corner_radius_top_right = 5
	delete_style.corner_radius_bottom_right = 5
	delete_style.corner_radius_bottom_left = 5
	delete_btn.add_theme_stylebox_override("normal", delete_style)
	delete_btn.add_theme_color_override("font_color", Color.WHITE)
	
	delete_btn.pressed.connect(_on_delete_block.bind(container))
	
	container.add_child(up_btn)
	container.add_child(down_btn)
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
	var block_content = container.get_child(2) as Button
	var count_edit = container.get_child(3) as LineEdit
	
	# Показываем поле ввода, скрываем кнопку
	block_content.visible = false
	count_edit.visible = true
	count_edit.grab_focus()
	count_edit.select_all()

func _on_count_edit_focus_exited(container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	apply_count_change(container, count_edit, block_data)

func _on_count_text_submitted(new_text: String, container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	apply_count_change(container, count_edit, block_data)

func apply_count_change(container: HBoxContainer, count_edit: LineEdit, block_data: Dictionary):
	var block_content = container.get_child(2) as Button
	
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

func _on_move_up(container: HBoxContainer):
	var index = -1
	for i in range(program_blocks.size()):
		if program_blocks[i]["container"] == container:
			index = i
			break
	
	if index > 0:
		# Меняем местами в массиве
		var temp = program_blocks[index]
		program_blocks[index] = program_blocks[index - 1]
		program_blocks[index - 1] = temp
		
		# Меняем порядок в UI
		program_area.move_child(container, index - 1)
		update_block_numbers()
		
		# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
		update_trajectory_preview()

func _on_move_down(container: HBoxContainer):
	var index = -1
	for i in range(program_blocks.size()):
		if program_blocks[i]["container"] == container:
			index = i
			break
	
	if index >= 0 and index < program_blocks.size() - 1:
		# Меняем местами в массиве
		var temp = program_blocks[index]
		program_blocks[index] = program_blocks[index + 1]
		program_blocks[index + 1] = temp
		
		# Меняем порядок в UI
		program_area.move_child(container, index + 1)
		update_block_numbers()
		
		# ОБНОВЛЯЕМ ПРЕДПРОСМОТР ТРАЕКТОРИИ
		update_trajectory_preview()

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
	# Обновляем номера у всех блоков
	for i in range(program_blocks.size()):
		var container = program_blocks[i]["container"]
		# Номера теперь не отображаем, так есть кнопки перемещения

func show_program_hint():
	# Удаляем старую подсказку
	for child in program_area.get_children():
		if child is Label:
			child.queue_free()
	
	var hint_label = Label.new()
	hint_label.text = "Перетащите блоки сюда"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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
