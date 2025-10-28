# LevelButton.gd
extends Button

@export var level_number: int = 1
@onready var level_label = $MarginContainer/VBoxContainer/LevelNumber
@onready var stars_container = $MarginContainer/VBoxContainer/StarsContainer
@onready var lock_icon = $MarginContainer/VBoxContainer/LockIcon

var level_data: Dictionary = {}

func _ready():
	set_level_number(level_number)
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
	
	var unlocked = level_data.get("unlocked", false)
	var completed = level_data.get("completed", false)
	var stars = level_data.get("stars", 0)
	
	set_locked(!unlocked)
	
	if unlocked:
		update_stars_display(stars)
		
		if completed:
			var style = get_theme_stylebox("normal").duplicate()
			style.bg_color = Color(0.1, 0.3, 0.1)
			add_theme_stylebox_override("normal", style)
		else:
			var style = get_theme_stylebox("normal").duplicate()
			style.bg_color = Color(0.1, 0.1, 0.3)
			add_theme_stylebox_override("normal", style)

func set_locked(locked: bool):
	disabled = locked
	if lock_icon:
		lock_icon.visible = locked
	
	if locked:
		var style = get_theme_stylebox("normal").duplicate()
		style.bg_color = Color(0.1, 0.1, 0.15)
		add_theme_stylebox_override("normal", style)
		clear_stars_display()
		print("🔒 Level ", level_number, " заблокирован")
	else:
		var style = get_theme_stylebox("normal").duplicate()
		style.bg_color = Color(0.1, 0.1, 0.3)
		add_theme_stylebox_override("normal", style)
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
			star_label.add_theme_color_override("font_color", Color.GOLD)
			star_label.add_theme_font_size_override("font_size", 16)
		else:
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", Color.GRAY)
			star_label.add_theme_font_size_override("font_size", 16)
		
		stars_container.add_child(star_label)

func clear_stars_display():
	for child in stars_container.get_children():
		child.queue_free()
