extends Button

@export var level_number: int = 1
@export var hover_color: Color = Color(0.90, 0.72, 0.47, 1.0)
@export var pressed_color: Color = Color(0.75, 0.56, 0.34, 1.0)

# Добавьте эти свойства для настройки шрифта
@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 40
@export var font_color: Color = Color(0.97, 0.92, 0.85)
@export var font_outline_color: Color = Color(0.15, 0.10, 0.07, 0.96)
@export var font_outline_size: int = 2

@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelNumber
@onready var stars_container: HBoxContainer = $MarginContainer/VBoxContainer/StarsContainer
@onready var lock_icon: TextureRect = $MarginContainer/VBoxContainer/LockIcon
@onready var background_texture: TextureRect = $TextureRect

var level_data: Dictionary = {}
var is_hovered: bool = false
var base_color: Color = Color(0.94, 0.86, 0.74)

func _ready():
	# Убираем стандартные стили кнопки
	remove_standard_styles()
	
	set_level_number(level_number)
	update_appearance()
	apply_font_settings()  # Применяем настройки шрифта
	
	# Подключаем сигналы мыши
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# Новая функция для применения настроек шрифта
func apply_font_settings():
	if level_label:
		# Применяем кастомный шрифт если он задан
		if custom_font:
			level_label.add_theme_font_override("font", custom_font)
		
		# Устанавливаем размер шрифта
		level_label.add_theme_font_size_override("font_size", font_size)
		
		# Устанавливаем цвет шрифта
		level_label.add_theme_color_override("font_color", font_color)
		
		# Настройка обводки текста (если нужно)
		if font_outline_size > 0:
			level_label.add_theme_constant_override("outline_size", font_outline_size)
			level_label.add_theme_color_override("font_outline_color", font_outline_color)

func remove_standard_styles():
	# Создаем пустые стили для всех состояний кнопки
	var empty_style = StyleBoxEmpty.new()
	
	# Убираем все стандартные стили
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	
	# Убираем отступы текста
	add_theme_constant_override("hseparation", 0)
	
	# Убеждаемся, что текст не мешает
	if level_label:
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_mouse_entered():
	if not disabled:  # Только если кнопка не заблокирована
		is_hovered = true
		background_texture.modulate = hover_color

func _on_mouse_exited():
	is_hovered = false
	update_appearance()  # Вернем нормальный цвет

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# При нажатии кнопки мыши
			if not disabled:
				background_texture.modulate = pressed_color
		else:
			# При отпускании кнопки мыши
			if not disabled:
				if is_hovered:
					background_texture.modulate = hover_color
				else:
					update_appearance()

func set_level_data(data: Dictionary):
	level_data = data

func set_level_number(number: int):
	level_number = number
	if level_label:
		level_label.text = str(number)

func update_appearance():
	# Если данные не переданы, используем жесткие
	if level_data.is_empty():
		level_data = {
			"unlocked": level_number == 1,
			"completed": false,
			"stars": 0
		}
	
	var unlocked: bool = bool(level_data.get("unlocked", false))
	var completed: bool = bool(level_data.get("completed", false))
	var stars: int = int(level_data.get("stars", 0))
	
	set_locked(!unlocked)
	
	if unlocked:
		update_stars_display(stars)
		
		if completed:
			base_color = Color(0.76, 0.58, 0.37, 1.0)
		else:
			base_color = Color(0.94, 0.86, 0.74)
		
		# Применяем базовый цвет (если не наведен)
		if not is_hovered:
			background_texture.modulate = base_color

func set_locked(locked: bool):
	disabled = locked
	if lock_icon:
		lock_icon.visible = locked
	
	if locked:
		base_color = Color(0.42, 0.34, 0.27, 1.0)
		background_texture.modulate = base_color
		clear_stars_display()
		print("🔒 Level ", level_number, " заблокирован")
	else:
		base_color = Color(0.94, 0.86, 0.74)
		if not is_hovered:
			background_texture.modulate = base_color
		print("🔓 Level ", level_number, " разблокирован")

func update_stars_display(stars_count: int):
	for child in stars_container.get_children():
		child.queue_free()
	
	for i in range(3):
		var star_label = Label.new()
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		if i < stars_count:
			star_label.text = "★"
			star_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.44))
			star_label.add_theme_font_size_override("font_size", 20)
		else:
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", Color(0.54, 0.45, 0.37))
			star_label.add_theme_font_size_override("font_size", 20)
		
		stars_container.add_child(star_label)

func clear_stars_display():
	for child in stars_container.get_children():
		child.queue_free()
