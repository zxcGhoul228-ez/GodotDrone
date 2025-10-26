extends Control
@onready var back_button = $HBoxContainer/back_butt
@onready var message_label = $"message label"
@onready var refresh_button = $refresh
@export var score_label: Label  # Перетащите ноду в инспекторе
@onready var buttons = [
	$CenterContainer/VBoxContainer/HBoxContainer/Button1,
	$CenterContainer/VBoxContainer/HBoxContainer/Button2, 
	$CenterContainer/VBoxContainer/HBoxContainer2/Button4,
	$CenterContainer/VBoxContainer/HBoxContainer2/Button5,
	$CenterContainer/VBoxContainer/HBoxContainer/Button3,
	$CenterContainer/VBoxContainer/HBoxContainer2/Button6
]
# Варианты для каждого типа предметов
var frame_variants = ["Рама1", "Рама2", "Рама3"]
var board_variants = ["Плата1", "Плата2", "Плата3"]
var motor_variants = ["Мотор1", "Мотор2", "Мотор3"]
var propeller_variants = ["Пропеллер1", "Пропеллер2", "Пропеллер3"]

# Текущие отображаемые предметы
var current_items = []

var last_frame_index = -1
var last_board_index = -1
var last_motor_index = -1
var last_propeller_index = -1


# Цены для каждого предмета (первые 4 будут меняться, последние 2 - нет)
var item_prices = [10, 20, 50, 30, 40, 50]  # Можете настроить по своему усмотрению
func _ready():
	# Подключаем кнопку возврата
	if back_button:
		back_button.text = "Вернуться"
		if not back_button.is_connected("pressed", _on_back_pressed):
			back_button.connect("pressed", _on_back_pressed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Инициализируем генератор случайных чисел
	randomize()
	
	# Инициализируем начальный ассортимент
	refresh_shop_items()
	
	# Подключаем кнопку обновления
	if refresh_button:
		refresh_button.text = "Обновить\n(10 монет)"
		if not refresh_button.is_connected("pressed", _on_refresh_pressed):
			refresh_button.connect("pressed", _on_refresh_pressed)
	update_score_display()
	connect_buttons()
	setup_buttons()
	update_buttons_state()
	if message_label:
		message_label.hide()
		message_label.text = "Недостаточно средств!"
	
func connect_buttons():
	for i in range(buttons.size()):
		var button = buttons[i]
		if not button.is_connected("pressed", _on_item_bought.bind(i)):
			button.connect("pressed", _on_item_bought.bind(i))
func setup_buttons():
	for i in range(buttons.size()):
		var button = buttons[i]
		# Устанавливаем текст кнопки с названием и ценой
		button.text = "%s\n%d монет" % [current_items[i], item_prices[i]]
		# Подключаем сигнал нажатия
		button.connect("pressed", _on_item_bought.bind(i))
func get_random_index_different_from(array_size, last_index):
	if array_size <= 1:
		return 0  # Если только один вариант, всегда возвращаем 0
	
	var new_index = last_index
	# Продолжаем генерировать новый индекс, пока он не станет отличным от предыдущего
	while new_index == last_index:
		new_index = randi() % array_size
	
	return new_index

func _on_item_bought(item_index):
	var price = item_prices[item_index]
	var product_name = current_items[item_index]
	
	# Проверяем, не куплен ли уже предмет
	if product_name in Global.purchased_items:
		print("Этот предмет уже куплен!")
		return
	
	if Global.score >= price:
		Global.score -= price
		Global.purchased_items.append(product_name)  # Добавляем предмет в список купленных
		update_score_display()
		update_buttons_state()
		print("Куплен: ", product_name)
	else:
		print("Недостаточно монет для покупки ", product_name)
		show_message()
func _on_refresh_pressed():
	# Проверяем, хватает ли монет для обновления
	if Global.score >= 10:
		Global.score -= 10
		refresh_shop_items()
		setup_buttons()
		update_buttons_state()
		update_score_display()
		print("Ассортимент обновлен!")
	else:
		print("Недостаточно монет для обновления ассортимента!")
		show_message()
func refresh_shop_items():
	current_items.clear()
	
	# Выбираем случайные индексы, отличные от предыдущих
	var frame_index = get_random_index_different_from(frame_variants.size(), last_frame_index)
	var board_index = get_random_index_different_from(board_variants.size(), last_board_index)
	var motor_index = get_random_index_different_from(motor_variants.size(), last_motor_index)
	var propeller_index = get_random_index_different_from(propeller_variants.size(), last_propeller_index)
	
	# Сохраняем выбранные индексы для следующего обновления
	last_frame_index = frame_index
	last_board_index = board_index
	last_motor_index = motor_index
	last_propeller_index = propeller_index
	
	# Добавляем выбранные предметы
	current_items.append(frame_variants[frame_index])
	current_items.append(board_variants[board_index])
	current_items.append(motor_variants[motor_index])
	current_items.append(propeller_variants[propeller_index])
	
	# Добавляем неизменяемые предметы
	current_items.append("Буст1")
	current_items.append("Буст2")
	
	print("Новый ассортимент: ", current_items)

func update_buttons_state():
	# Обновляем состояние кнопок (активны/неактивны) в зависимости от того, куплен ли предмет
	for i in range(buttons.size()):
		var button = buttons[i]
		var product_name = current_items[i]
		
		if product_name in Global.purchased_items:
			button.disabled = true
			button.text = "%s\nКуплено" % product_name
			button.modulate = Color.GRAY  # Визуально показываем, что предмет куплен
		else:
			button.disabled = false
			button.text = "%s\n%d монет" % [product_name, item_prices[i]]
			button.modulate = Color.WHITE
func _on_back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")
func update_score_display():
	score_label.text = "Счет: " + str(Global.score)
func show_message():
	if message_label:
		message_label.show()
		# Создаем таймер для скрытия сообщения через 2 секунды
		var timer = get_tree().create_timer(2.0)
		await timer.timeout
		message_label.hide()
