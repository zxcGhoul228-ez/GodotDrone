extends Control
@onready var back_button = $HBoxContainer/back_butt
@onready var message_label = $"message label"
@onready var refresh_button = $refresh
@export var score_label: Label
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

# Текстуры для каждого предмета
var item_textures = {
	"Рама1": preload("res://assets/shop/frame1.png"),
	"Рама2": preload("res://assets/shop/frame2.png"),
	"Рама3": preload("res://assets/shop/frame3.png"),
	"Плата1": preload("res://assets/shop/board1.png"),
	"Плата2": preload("res://assets/shop/board2.png"),
	"Плата3": preload("res://assets/shop/board3.png"),
	"Мотор1": preload("res://assets/shop/motor1.png"),
	"Мотор2": preload("res://assets/shop/motor2.png"),
	"Мотор3": preload("res://assets/shop/motor3.png"),
	"Пропеллер1": preload("res://assets/shop/propeller1.png"),
	"Пропеллер2": preload("res://assets/shop/propeller2.png"),
	"Пропеллер3": preload("res://assets/shop/propeller3.png"),
	"Буст1": preload("res://assets/shop/boost1.png"),
	"Буст2": preload("res://assets/shop/boost2.png")
}

# Текущие отображаемые предметы
var current_items = []

var last_frame_index = -1
var last_board_index = -1
var last_motor_index = -1
var last_propeller_index = -1

# Цены для каждого предмета
var item_prices = [10, 20, 50, 30, 40, 50]

# Стоимость обновления и коэффициент увеличения
var refresh_cost = 10
var refresh_cost_increase = 5

# Настройки текста для кнопок
var button_font_size = 32
var button_text_color = Color(1.963, 0.0, 1.189, 1.0)
var button_font = null  # Можно загрузить кастомный шрифт

func _ready():
	# Загружаем кастомный шрифт, если нужно
	# button_font = load("res://fonts/my_font.tres")
	
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
		update_refresh_button_text()
		if not refresh_button.is_connected("pressed", _on_refresh_pressed):
			refresh_button.connect("pressed", _on_refresh_pressed)
	update_score_display()
	setup_buttons()
	update_buttons_state()
	if message_label:
		message_label.hide()
		message_label.text = "Недостаточно средств!"

func update_refresh_button_text():
	refresh_button.text = "Обновить\n(%d монет)" % refresh_cost

# Функция для установки текста на кнопке с настройками стиля
func set_button_text(button, text):
	if button is Button:
		# Для обычных кнопок
		button.text = text
		# Применяем настройки шрифта и цвета
		button.add_theme_font_size_override("font_size", button_font_size)
		button.add_theme_color_override("font_color", button_text_color)
		# Центрируем текст
		button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if button_font:
			button.add_theme_font_override("font", button_font)
	elif button is TextureButton:
		# Для TextureButton создаем или используем существующий Label
		var label = button.get_node_or_null("ButtonLabel")
		if not label:
			label = Label.new()
			label.name = "ButtonLabel"
			button.add_child(label)
			# Настраиваем Label для полного центрирования
			label.size = button.size
			label.position = Vector2.ZERO
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.modulate = button_text_color
			# Применяем настройки шрифта
			label.add_theme_font_size_override("font_size", button_font_size)
			if button_font:
				label.add_theme_font_override("font", button_font)
			
			# Устанавливаем автоперенос текста
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = false
		
		label.text = text

func setup_buttons():
	for i in range(buttons.size()):
		var button = buttons[i]
		var item_name = current_items[i]
		
		# Устанавливаем текстуру для TextureButton
		if item_textures.has(item_name):
			var texture = item_textures[item_name]
			if button is TextureButton:
				button.texture_normal = texture
		
		# Устанавливаем текст на кнопке
		var button_text = "%s\n%d монет" % [item_name, item_prices[i]]
		set_button_text(button, button_text)
		
		# Подключаем сигнал нажатия
		if not button.is_connected("pressed", _on_item_bought.bind(i)):
			button.connect("pressed", _on_item_bought.bind(i))

func get_random_index_different_from(array_size, last_index):
	if array_size <= 1:
		return 0
	
	var new_index = last_index
	while new_index == last_index:
		new_index = randi() % array_size
	
	return new_index

func _on_item_bought(item_index):
	var price = item_prices[item_index]
	var product_name = current_items[item_index]
	
	if product_name in Global.purchased_items:
		print("Этот предмет уже куплен!")
		return
	
	if Global.score >= price:
		Global.score -= price
		Global.purchased_items.append(product_name)
		update_score_display()
		update_buttons_state()
		print("Куплен: ", product_name)
		update_drone_creator_buttons()
	else:
		print("Недостаточно монет для покупки ", product_name)
		show_message()

func update_drone_creator_buttons():
	var drone_creator = get_tree().get_nodes_in_group("drone_creator")
	if drone_creator.size() > 0:
		for creator in drone_creator:
			if creator.has_method("update_buttons_availability"):
				creator.update_buttons_availability()

func _on_refresh_pressed():
	if Global.score >= refresh_cost:
		Global.score -= refresh_cost
		refresh_cost += refresh_cost_increase
		refresh_shop_items()
		setup_buttons()
		update_buttons_state()
		update_score_display()
		update_refresh_button_text()
		print("Ассортимент обновлен! Следующее обновление будет стоить: ", refresh_cost, " монет")
	else:
		print("Недостаточно монет для обновления ассортимента!")
		show_message()

func refresh_shop_items():
	current_items.clear()
	
	var frame_index = get_random_index_different_from(frame_variants.size(), last_frame_index)
	var board_index = get_random_index_different_from(board_variants.size(), last_board_index)
	var motor_index = get_random_index_different_from(motor_variants.size(), last_motor_index)
	var propeller_index = get_random_index_different_from(propeller_variants.size(), last_propeller_index)
	
	last_frame_index = frame_index
	last_board_index = board_index
	last_motor_index = motor_index
	last_propeller_index = propeller_index
	
	current_items.append(frame_variants[frame_index])
	current_items.append(board_variants[board_index])
	current_items.append(motor_variants[motor_index])
	current_items.append(propeller_variants[propeller_index])
	
	current_items.append("Буст1")
	current_items.append("Буст2")
	
	print("Новый ассортимент: ", current_items)

func update_buttons_state():
	for i in range(buttons.size()):
		var button = buttons[i]
		var product_name = current_items[i]
		
		if product_name in Global.purchased_items:
			button.disabled = true
			button.modulate = Color(0.779, 0.479, 0.461, 1.0)
			set_button_text(button, "%s\nКуплено" % product_name)
		else:
			button.disabled = false
			button.modulate = Color.WHITE
			set_button_text(button, "%s\n%d монет" % [product_name, item_prices[i]])

func _on_back_pressed():
	get_tree().change_scene_to_file("main_scene.tscn")

func update_score_display():
	score_label.text = "Счет: " + str(Global.score)

func show_message():
	if message_label:
		message_label.show()
		var timer = get_tree().create_timer(2.0)
		await timer.timeout
		message_label.hide()
