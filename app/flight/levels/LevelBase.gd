# LevelBase.gd
extends Node3D  # или какой тип у корневого узла DroneScene.tscn

class_name LevelBase

# Переменные уровня
var level_number: int = 1
var level_name: String = "Уровень 1"
var level_description: String = "Достигните целевой точки"
var target_steps: int = 10
var current_steps: int = 0
var is_level_completed: bool = false

# Ссылки на объекты уровня
@onready var target_point: Node3D = null
@onready var obstacles: Array = []
@onready var collectibles: Array = []

# Константы из DroneScene
const GRID_SIZE = 32

func _ready():
	setup_level()
	print("🎮 Загружен уровень: ", level_name)

func setup_level():
	# Этот метод будет переопределяться в каждом уровне
	create_target_point()
	setup_obstacles()
	setup_collectibles()
	
	# Находим дрона в сцене
	var drone = find_child("Drone") as CharacterBody3D
	if drone:
		drone.drone_moved.connect(_on_drone_moved)

func create_target_point():
	# Создаем целевую точку
	var target = MeshInstance3D.new()
	target.mesh = SphereMesh.new()
	target.mesh.radius = 8
	target.mesh.height = 16
	target.position = Vector3(0, 8, 0)
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.5
	target.material_override = material
	
	add_child(target)
	target_point = target

func setup_obstacles():
	# Будет переопределено в конкретных уровнях
	pass

func setup_collectibles():
	# Будет переопределено в конкретных уровнях
	pass

func _on_drone_moved():
	current_steps += 1
	check_level_conditions()

func check_level_conditions():
	if not target_point or is_level_completed:
		return
	
	# Находим дрона
	var drone = find_child("Drone") as CharacterBody3D
	if not drone:
		return
	
	# Проверяем достижение цели
	var distance = drone.global_position.distance_to(target_point.global_position)
	if distance < 16:  # Если дрон близко к цели
		complete_level()

func complete_level():
	if is_level_completed:
		return
		
	is_level_completed = true
	
	# Вычисляем звезды
	var stars = calculate_stars()
	
	# Сохраняем прогресс через Global
	if Global:
		var completion_time_ms := _estimate_completion_time_ms(stars)
		Global.complete_level(level_number, completion_time_ms)
	
	show_level_complete_ui(stars)

func _estimate_completion_time_ms(stars: int) -> int:
	if Global and Global.has_method("get_level_ideal_time_ms"):
		var ideal_time_ms: int = int(Global.call("get_level_ideal_time_ms", level_number))
		if ideal_time_ms > 0:
			match stars:
				3:
					return ideal_time_ms
				2:
					return int(round(float(ideal_time_ms) * 1.85))
				1:
					return int(round(float(ideal_time_ms) * 2.5))
				_:
					return int(round(float(ideal_time_ms) * 3.1))
	return maxi(current_steps, 1) * 1000

func calculate_stars() -> int:
	if current_steps <= target_steps * 0.5:
		return 3
	elif current_steps <= target_steps * 0.75:
		return 2
	elif current_steps <= target_steps:
		return 1
	else:
		return 1

func show_level_complete_ui(stars: int):
	# Создаем UI завершения уровня
	var complete_ui = CanvasLayer.new()
	var panel = Panel.new()
	panel.size = Vector2(400, 300)
	panel.position = (get_viewport().get_visible_rect().size - panel.size) / 2
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title = Label.new()
	title.text = "УРОВЕНЬ ЗАВЕРШЕН!"
	title.add_theme_font_size_override("font_size", 32)
	
	var level_label = Label.new()
	level_label.text = level_name
	level_label.add_theme_font_size_override("font_size", 24)
	
	var steps_label = Label.new()
	steps_label.text = "Шагов: " + str(current_steps)
	
	var stars_label = Label.new()
	stars_label.text = "Звезды: " + "★".repeat(stars)
	stars_label.add_theme_font_size_override("font_size", 24)
	stars_label.add_theme_color_override("font_color", Color.GOLD)
	
	var hbox = HBoxContainer.new()
	var next_btn = Button.new()
	next_btn.text = "Следующий уровень"
	next_btn.pressed.connect(_on_next_level_pressed)
	
	var retry_btn = Button.new()
	retry_btn.text = "Повторить"
	retry_btn.pressed.connect(_on_retry_pressed)
	
	var menu_btn = Button.new()
	menu_btn.text = "Выбор уровней"
	menu_btn.pressed.connect(_on_menu_pressed)
	
	hbox.add_child(retry_btn)
	hbox.add_child(menu_btn)
	if level_number < 15 and Global and Global.is_level_unlocked(level_number + 1):
		hbox.add_child(next_btn)
	
	vbox.add_child(title)
	vbox.add_child(level_label)
	vbox.add_child(steps_label)
	vbox.add_child(stars_label)
	vbox.add_child(hbox)
	
	panel.add_child(vbox)
	complete_ui.add_child(panel)
	add_child(complete_ui)

func _on_next_level_pressed():
	if Global:
		Global.current_level = level_number + 1
	get_tree().reload_current_scene()

func _on_retry_pressed():
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://app/ui/game_level.tscn")
