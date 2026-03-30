extends Control

# ==================== ОБУЧЕНИЕ (F1) ====================
const TUTORIAL_POPUP_SCRIPT := "res://tutorial/TutorialPopup.gd"
var tutorial_popup: Node = null

@onready var background: TextureRect = $TextureRect
@onready var shop_panel: Panel = $CenterContainer/Panel
@onready var shop_grid: VBoxContainer = $CenterContainer/VBoxContainer
@onready var top_row: HBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer
@onready var bottom_row: HBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer2
@onready var header_bar: HBoxContainer = $HBoxContainer
@onready var title_label: Label = $HBoxContainer/Label
@onready var back_button: Button = $HBoxContainer/back_butt
@onready var message_label: Button = $"message label"
@onready var refresh_button: Button = $refresh
@export var score_label: Label
var quests_button: Button = null
var quest_popup: Control = null
var title_overlay: Label = null
@onready var buttons: Array[TextureButton] = [
	$CenterContainer/VBoxContainer/HBoxContainer/Button1,
	$CenterContainer/VBoxContainer/HBoxContainer/Button2, 
	$CenterContainer/VBoxContainer/HBoxContainer2/Button4,
	$CenterContainer/VBoxContainer/HBoxContainer2/Button5,
	$CenterContainer/VBoxContainer/HBoxContainer/Button3,
	$CenterContainer/VBoxContainer/HBoxContainer2/Button6
]

# Варианты для магазина: только те детали, которые нужно покупать отдельно.
var board_variants: Array[String] = ["Плата2", "Плата3"]
var motor_variants: Array[String] = ["Мотор2", "Мотор3"]
var propeller_variants: Array[String] = ["Пропеллер2", "Пропеллер3"]
var booster_variants: Array[String] = ["Буст1", "Буст2"]
var shop_item_pool: Array[String] = []

# Текстуры для каждого предмета
var item_textures = {
	"Рама1": preload("res://content/shop/frame1.png"),
	"Рама2": preload("res://content/shop/frame2.png"),
	"Рама3": preload("res://content/shop/frame3.png"),
	"Плата1": preload("res://content/shop/board1.png"),
	"Плата2": preload("res://content/shop/board2.png"),
	"Плата3": preload("res://content/shop/board3.png"),
	"Мотор1": preload("res://content/shop/motor1.png"),
	"Мотор2": preload("res://content/shop/motor2.png"),
	"Мотор3": preload("res://content/shop/motor3.png"),
	"Пропеллер1": preload("res://content/shop/propeller1.png"),
	"Пропеллер2": preload("res://content/shop/propeller2.png"),
	"Пропеллер3": preload("res://content/shop/propeller3.png"),
	"Буст1": preload("res://content/shop/boost1.png"),
	"Буст2": preload("res://content/shop/boost2.png")
}

# Текущие отображаемые предметы
var current_items: Array[String] = []

var last_shop_roll: Array[String] = []

# Цены для каждого предмета
var item_prices := {
	"Плата2": 20,
	"Плата3": 50,
	"Мотор2": 30,
	"Мотор3": 45,
	"Пропеллер2": 25,
	"Пропеллер3": 40,
	"Буст1": 30,
	"Буст2": 50
}

# Стоимость обновления и коэффициент увеличения
var refresh_cost = 10
var refresh_cost_increase = 5
var product_button_size: Vector2 = Vector2(240, 236)

# Настройки текста для кнопок
var button_font_size = 32
var button_text_color = Color(0.97, 0.92, 0.85, 1.0)
var button_font = null  # Можно загрузить кастомный шрифт

func _ready():
	_sync_root_rect()
	_prepare_background()
	_ensure_centered_title()
	_apply_visual_theme()
	_layout_shop()
	# Загружаем кастомный шрифт, если нужно
	# button_font = load("res://content/fonts/my_font.tres")
	
	# Подключаем кнопку возврата
	if back_button:
		back_button.text = "Вернуться"
		if not back_button.is_connected("pressed", _on_back_pressed):
			back_button.connect("pressed", _on_back_pressed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Инициализируем генератор случайных чисел
	randomize()
	shop_item_pool = board_variants + motor_variants + propeller_variants + booster_variants
	
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
	_init_tutorial()
	_ensure_quest_ui()

func _notification(what: int):
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_shop")

func _sync_root_rect():
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = viewport_size
	custom_minimum_size = viewport_size

func _prepare_background():
	_sync_root_rect()
	if background == null:
		return
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = 1
	background.stretch_mode = 6
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = get_viewport_rect().size

func _ensure_centered_title():
	if title_overlay == null or not is_instance_valid(title_overlay):
		title_overlay = get_node_or_null("ShopTitleOverlay") as Label
	if title_overlay == null:
		title_overlay = Label.new()
		title_overlay.name = "ShopTitleOverlay"
		title_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_overlay.z_index = 5
		add_child(title_overlay)
	if title_label != null:
		if header_bar != null and title_label.get_parent() == header_bar:
			title_label.reparent(self)
		title_label.visible = false
		title_label.text = ""
		title_label.custom_minimum_size = Vector2.ZERO
	title_overlay.text = "Магазин"
	title_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _ensure_floating_wallet():
	if score_label == null:
		return
	if header_bar != null and score_label.get_parent() == header_bar:
		score_label.reparent(self)
	score_label.z_index = 6
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_visual_theme():
	_ensure_centered_title()
	_ensure_floating_wallet()
	if shop_panel != null:
		shop_panel.add_theme_stylebox_override("panel", _build_card_style(
			Color(0.16, 0.11, 0.08, 0.88),
			Color(0.74, 0.57, 0.38, 0.78)
		))

	var tint: ColorRect = background.get_node_or_null("ShopTint") as ColorRect
	if tint == null:
		tint = ColorRect.new()
		tint.name = "ShopTint"
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(0.11, 0.07, 0.04, 0.24)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(tint)
		background.move_child(tint, 0)

	title_label.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))
	title_label.add_theme_font_size_override("font_size", 64)
	if title_overlay != null:
		title_overlay.add_theme_color_override("font_color", Color(0.97, 0.91, 0.84))
		title_overlay.add_theme_font_size_override("font_size", 56)
	if score_label != null:
		score_label.add_theme_color_override("font_color", Color(0.94, 0.87, 0.78))
		score_label.add_theme_font_size_override("font_size", 28)
	_style_action_button(back_button, Color(0.31, 0.22, 0.15, 0.97), Color(0.81, 0.63, 0.41, 0.94))
	_style_action_button(quests_button, Color(0.38, 0.27, 0.18, 0.97), Color(0.88, 0.69, 0.45, 0.94))
	_style_action_button(refresh_button, Color(0.28, 0.20, 0.14, 0.97), Color(0.73, 0.56, 0.38, 0.90))
	_style_action_button(message_label, Color(0.34, 0.18, 0.15, 0.97), Color(0.80, 0.45, 0.33, 0.94))
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_shop():
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	_sync_root_rect()

	if background != null:
		background.position = Vector2.ZERO
		background.size = viewport_size

	var panel_size: Vector2 = Vector2(
		clampf(viewport_size.x - 140.0, 780.0, 1260.0),
		clampf(viewport_size.y - 140.0, 620.0, 820.0)
	)
	var panel_left: float = 0.5 * (viewport_size.x - panel_size.x)
	var panel_top: float = 0.5 * (viewport_size.y - panel_size.y)
	var button_width: float = clampf((panel_size.x - 220.0) / 3.0, 180.0, 280.0)
	var button_height: float = clampf(panel_size.y * 0.33, 220.0, 270.0)
	var row_separation: int = clampi(int(round((panel_size.x - button_width * 3.0) / 2.0)), 36, 72)
	product_button_size = Vector2(button_width, button_height)

	if shop_panel != null:
		shop_panel.custom_minimum_size = panel_size

	if shop_grid != null:
		shop_grid.custom_minimum_size = Vector2(panel_size.x - 120.0, panel_size.y - 210.0)
		shop_grid.add_theme_constant_override("separation", 42)

	if top_row != null:
		top_row.custom_minimum_size = Vector2(panel_size.x - 120.0, button_height)
		top_row.add_theme_constant_override("separation", row_separation)

	if bottom_row != null:
		bottom_row.custom_minimum_size = Vector2(panel_size.x - 120.0, button_height)
		bottom_row.add_theme_constant_override("separation", row_separation)

	for button in buttons:
		if button == null:
			continue
		button.custom_minimum_size = product_button_size
		var preview_frame: Panel = button.get_node_or_null("PreviewFrame") as Panel
		if preview_frame != null:
			preview_frame.offset_left = 18.0
			preview_frame.offset_top = 16.0
			preview_frame.offset_right = -18.0
			preview_frame.offset_bottom = -clampf(button_height * 0.33, 86.0, 108.0)
		var info_panel: Panel = button.get_node_or_null("InfoPanel") as Panel
		if info_panel != null:
			info_panel.offset_top = -clampf(button_height * 0.30, 74.0, 90.0)
		var label: Label = button.get_node_or_null("InfoPanel/ButtonLabel") as Label
		if label != null:
			label.add_theme_font_size_override("font_size", clampi(int(round(product_button_size.x * 0.10)), 18, 24))

	if header_bar != null:
		header_bar.anchor_left = 0.0
		header_bar.anchor_right = 0.0
		header_bar.anchor_top = 0.0
		header_bar.anchor_bottom = 0.0
		header_bar.offset_left = panel_left + 44.0
		header_bar.offset_top = panel_top + 22.0
		header_bar.offset_right = panel_left + 420.0
		header_bar.offset_bottom = panel_top + 96.0
		header_bar.add_theme_constant_override("separation", 18)

	if title_label != null:
		title_label.add_theme_font_size_override("font_size", clampi(int(round(viewport_size.x * 0.028)), 40, 56))
		title_label.custom_minimum_size = Vector2(0.0, 72.0)
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if title_overlay != null:
		var title_width: float = clampf(panel_size.x * 0.34, 320.0, 460.0)
		title_overlay.size = Vector2(title_width, 72.0)
		title_overlay.position = Vector2(panel_left + (panel_size.x - title_width) * 0.5, panel_top + 24.0)
		title_overlay.add_theme_font_size_override("font_size", clampi(int(round(viewport_size.x * 0.028)), 40, 56))
		title_overlay.z_index = 6

	if back_button != null:
		back_button.custom_minimum_size = Vector2(176.0, 64.0)
		back_button.add_theme_font_size_override("font_size", 22)

	if quests_button != null:
		quests_button.custom_minimum_size = Vector2(168.0, 64.0)
		quests_button.add_theme_font_size_override("font_size", 22)

	if score_label != null:
		var wallet_width: float = 280.0
		score_label.add_theme_font_size_override("font_size", clampi(int(round(viewport_size.x * 0.013)), 22, 28))
		score_label.custom_minimum_size = Vector2(wallet_width, 74.0)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		score_label.position = Vector2(panel_left + panel_size.x - wallet_width - 44.0, panel_top + 22.0)
		score_label.size = Vector2(wallet_width, 74.0)

	if refresh_button != null:
		var refresh_width: float = 220.0
		var refresh_height: float = 86.0
		refresh_button.offset_left = 0.5 * (viewport_size.x - refresh_width)
		refresh_button.offset_top = panel_top + panel_size.y - 110.0
		refresh_button.offset_right = refresh_button.offset_left + refresh_width
		refresh_button.offset_bottom = refresh_button.offset_top + refresh_height
		refresh_button.add_theme_font_size_override("font_size", 22)

	if message_label != null:
		var message_width: float = 360.0
		var message_height: float = 62.0
		message_label.offset_left = 0.5 * (viewport_size.x - message_width)
		message_label.offset_top = panel_top + panel_size.y - 186.0
		message_label.offset_right = message_label.offset_left + message_width
		message_label.offset_bottom = message_label.offset_top + message_height

func _build_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 16
	return style

func _style_action_button(button: Button, fill: Color, border: Color):
	if button == null:
		return
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 150.0), maxf(button.custom_minimum_size.y, 54.0))
	button.add_theme_font_size_override("font_size", 24)
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

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

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
		button.custom_minimum_size = product_button_size
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button.ignore_texture_size = true

		var frame_panel: Panel = button.get_node_or_null("FramePanel") as Panel
		if frame_panel == null:
			frame_panel = Panel.new()
			frame_panel.name = "FramePanel"
			frame_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
			frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(frame_panel)
			button.move_child(frame_panel, 0)
		frame_panel.add_theme_stylebox_override("panel", _build_card_style(
			Color(0.18, 0.13, 0.09, 0.24),
			Color(0.69, 0.53, 0.35, 0.74)
		))

		var preview_frame: Panel = button.get_node_or_null("PreviewFrame") as Panel
		if preview_frame == null:
			preview_frame = Panel.new()
			preview_frame.name = "PreviewFrame"
			preview_frame.anchor_left = 0.0
			preview_frame.anchor_top = 0.0
			preview_frame.anchor_right = 1.0
			preview_frame.anchor_bottom = 1.0
			preview_frame.offset_left = 18.0
			preview_frame.offset_top = 16.0
			preview_frame.offset_right = -18.0
			preview_frame.offset_bottom = -92.0
			preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(preview_frame)
			button.move_child(preview_frame, 1)
		preview_frame.add_theme_stylebox_override("panel", _build_card_style(
			Color(0.62, 0.59, 0.56, 0.20),
			Color(0.73, 0.59, 0.41, 0.48)
		))

		var preview_texture: TextureRect = preview_frame.get_node_or_null("PreviewTexture") as TextureRect
		if preview_texture == null:
			preview_texture = TextureRect.new()
			preview_texture.name = "PreviewTexture"
			preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			preview_texture.offset_left = 10.0
			preview_texture.offset_top = 10.0
			preview_texture.offset_right = -10.0
			preview_texture.offset_bottom = -10.0
			preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview_frame.add_child(preview_texture)

		var info_panel: Panel = button.get_node_or_null("InfoPanel") as Panel
		if info_panel == null:
			info_panel = Panel.new()
			info_panel.name = "InfoPanel"
			info_panel.anchor_left = 0.0
			info_panel.anchor_top = 1.0
			info_panel.anchor_right = 1.0
			info_panel.anchor_bottom = 1.0
			info_panel.offset_left = 12
			info_panel.offset_top = -82
			info_panel.offset_right = -12
			info_panel.offset_bottom = -12
			info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(info_panel)
		info_panel.add_theme_stylebox_override("panel", _build_card_style(
			Color(0.22, 0.16, 0.11, 0.94),
			Color(0.76, 0.59, 0.39, 0.76)
		))

		var label: Label = info_panel.get_node_or_null("ButtonLabel") as Label
		if label == null:
			label = Label.new()
			label.name = "ButtonLabel"
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info_panel.add_child(label)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.clip_text = false
			if button_font:
				label.add_theme_font_override("font", button_font)
			label.add_theme_color_override("font_color", Color(0.97, 0.92, 0.85))

		label.add_theme_font_size_override("font_size", clampi(int(round(product_button_size.x * 0.10)), 18, 24))
		label.text = text

func setup_buttons():
	for i in range(buttons.size()):
		var button: TextureButton = buttons[i]
		var item_name: String = current_items[i]
		
		# Устанавливаем текст на кнопке
		var button_text: String = "%s\n%d монет" % [item_name, int(item_prices.get(item_name, 0))]
		set_button_text(button, button_text)

		# Устанавливаем текстуру превью после создания внутренних нод кнопки
		if item_textures.has(item_name):
			var texture: Texture2D = item_textures[item_name] as Texture2D
			var preview_frame: Panel = button.get_node_or_null("PreviewFrame") as Panel
			var preview_texture: TextureRect = preview_frame.get_node_or_null("PreviewTexture") as TextureRect if preview_frame != null else null
			if preview_texture != null:
				preview_texture.texture = texture
			button.texture_normal = null
		
		# Подключаем сигнал нажатия
		if not button.is_connected("pressed", _on_item_bought.bind(i)):
			button.connect("pressed", _on_item_bought.bind(i))

func get_random_index_different_from(array_size: int, last_index: int) -> int:
	if array_size <= 1:
		return 0
	
	var new_index: int = last_index
	while new_index == last_index:
		new_index = randi() % array_size
	
	return new_index

func _on_item_bought(item_index):
	var product_name: String = current_items[item_index]
	var price: int = int(item_prices.get(product_name, 0))
	
	if product_name in Global.purchased_items:
		print("Этот предмет уже куплен!")
		return
	
	if Global.spend_score(price):
		Global.purchased_items.append(product_name)
		Global.record_shop_purchase(product_name, price)
		Global.save_game()
		update_score_display()
		update_buttons_state()
		print("Куплен: ", product_name)
		update_drone_creator_buttons()
	else:
		print("Недостаточно монет для покупки ", product_name)
		show_message()

func update_drone_creator_buttons():
	var drone_creator: Array = get_tree().get_nodes_in_group("drone_creator")
	if drone_creator.size() > 0:
		for creator in drone_creator:
			if creator.has_method("update_buttons_availability"):
				creator.update_buttons_availability()

func _on_refresh_pressed():
	if Global.spend_score(refresh_cost):
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

func _ensure_quest_ui() -> void:
	if header_bar == null:
		return

	if quests_button == null or not is_instance_valid(quests_button):
		quests_button = Button.new()
		quests_button.name = "QuestsButton"
		quests_button.text = "Квесты"
		quests_button.focus_mode = Control.FOCUS_NONE
		quests_button.pressed.connect(_on_quests_pressed)

	if quests_button.get_parent() != header_bar:
		header_bar.add_child(quests_button)
		if score_label != null and score_label.get_parent() == header_bar:
			header_bar.move_child(quests_button, score_label.get_index())

	if quest_popup == null or not is_instance_valid(quest_popup):
		var popup_script: Script = load("res://app/ui/QuestPopup.gd")
		if popup_script != null:
			quest_popup = popup_script.new()
			add_child(quest_popup)
			if quest_popup.has_method("set_popup_title"):
				quest_popup.call("set_popup_title", "Квесты магазина")

	_apply_visual_theme()

func _on_quests_pressed() -> void:
	if quest_popup != null and is_instance_valid(quest_popup) and quest_popup.has_method("toggle"):
		quest_popup.call("toggle")

func refresh_shop_items():
	current_items.clear()

	var candidates: Array[String] = shop_item_pool.duplicate()
	candidates.shuffle()
	var target_count: int = mini(buttons.size(), candidates.size())
	for i in range(target_count):
		current_items.append(candidates[i])

	if current_items == last_shop_roll and candidates.size() > 1:
		var first_item: String = str(candidates[0])
		candidates.remove_at(0)
		candidates.append(first_item)
		current_items.clear()
		for i in range(target_count):
			current_items.append(candidates[i])

	last_shop_roll = current_items.duplicate()
	
	print("Новый ассортимент: ", current_items)

func update_buttons_state():
	for i in range(buttons.size()):
		var button: TextureButton = buttons[i]
		var product_name: String = current_items[i]
		
		if product_name in Global.purchased_items:
			button.disabled = true
			button.modulate = Color(0.76, 0.67, 0.55, 0.78)
			set_button_text(button, "%s\nКуплено" % product_name)
		else:
			button.disabled = false
			button.modulate = Color.WHITE
			set_button_text(button, "%s\n%d монет" % [product_name, int(item_prices.get(product_name, 0))])

func _on_back_pressed():
	get_tree().change_scene_to_file("res://app/main_menu/main_scene.tscn")

func update_score_display():
	score_label.text = Global.format_wallet_label(true)

func show_message():
	if message_label:
		message_label.show()
		var timer: SceneTreeTimer = get_tree().create_timer(2.0)
		await timer.timeout
		message_label.hide()

# ==================== ОБУЧЕНИЕ (F1) ====================
func _init_tutorial() -> void:
	if not ResourceLoader.exists(TUTORIAL_POPUP_SCRIPT):
		push_warning("Не найден tutorial popup: %s" % TUTORIAL_POPUP_SCRIPT)
		return
	var popup_script: Script = load(TUTORIAL_POPUP_SCRIPT)
	if popup_script == null:
		return
	tutorial_popup = popup_script.new()
	add_child(tutorial_popup)
	if tutorial_popup.has_method("setup"):
		tutorial_popup.setup("shop", "Магазин", _get_tutorial_steps())

func _get_tutorial_steps() -> Array:
	return [
		{"title": "Как работает магазин", "text": """На экране 6 карточек-товаров (TextureButton). На каждой: название и цена.

• Клик по товару — покупка (если хватает монет).
• Купленные вещи складываются в [b]Global.purchased_items[/b] и станут доступны в создании дрона."""},
		{"title": "Типы деталей", "text": """В магазине могут попадаться:
• [b]Платы[/b] (Плата2/3)
• [b]Моторы[/b] (Мотор2/3)
• [b]Пропеллеры[/b] (Пропеллер2/3)
• [b]Бусты[/b] (Буст1/2) — если ты используешь их в логике, они тоже покупаются как предмет."""},
		{"title": "Обновление витрины", "text": """Кнопка [b]refresh[/b] меняет набор товаров.
Стоимость обновления начинается с [b]10[/b] монет и увеличивается на [b]+5[/b] после каждого обновления."""},
		{"title": "Назад", "text": """Кнопка [b]Вернуться[/b] возвращает в меню/назад."""}
	]

func _input(event: InputEvent) -> void:
	# F1 -> открыть/закрыть обучение
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if tutorial_popup != null and is_instance_valid(tutorial_popup) and tutorial_popup.has_method("toggle"):
			tutorial_popup.toggle()
			get_viewport().set_input_as_handled()
