extends Control

@onready var loading_text: Label = $VBoxContainer/CenterContainer/LoadingText
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var vbox: VBoxContainer = $VBoxContainer

var current_progress: float = 0.0
var target_progress: float = 0.0
var is_active: bool = false

func _ready():
	# ТОЛЬКО минимальные настройки, не влияющие на позиционирование
	loading_text.modulate.a = 0.0
	progress_bar.visible = false
	vbox.modulate.a = 0.0
	
	# Настройка прогресс-бара (только значения)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0

func start_loading():
	print("🎬 Экран загрузки активирован")
	is_active = true
	
	# Сбрасываем прогресс
	current_progress = 0.0
	target_progress = 0.0
	progress_bar.value = 0
	progress_bar.visible = true
	
	# Запускаем анимацию появления
	start_entrance_animation()

func start_entrance_animation():
	var tween = create_tween()
	tween.set_parallel(true)
	
	# ТОЛЬКО анимация прозрачности, без изменения позиции
	tween.tween_property(vbox, "modulate:a", 1.0, 0.5)
	
	tween.tween_callback(start_animations)

func start_animations():
	# Запускаем анимацию текста
	start_text_animation()

func start_text_animation():
	# Анимация пульсации текста
	var text_tween = create_tween()
	text_tween.set_loops(0)
	text_tween.tween_property(loading_text, "modulate:a", 1.0, 0.8)
	text_tween.tween_property(loading_text, "modulate:a", 0.7, 0.8)

func set_progress(progress: float):
	# Устанавливаем целевое значение прогресса (0.0 - 1.0)
	target_progress = progress * 100
	update_loading_text_based_on_progress(progress)

func update_loading_text(status: String):
	loading_text.text = status

func update_loading_text_based_on_progress(progress: float):
	if progress < 0.2:
		loading_text.text = "Подготовка..."
	elif progress < 0.4:
		loading_text.text = "Загрузка ресурсов..."
	elif progress < 0.6:
		loading_text.text = "Инициализация..."
	elif progress < 0.8:
		loading_text.text = "Настройка сцены..."
	elif progress < 0.95:
		loading_text.text = "Завершение..."
	else:
		loading_text.text = "Готово!"

func _process(delta):
	if not is_active:
		return
	
	# Плавное обновление прогресс-бара к целевому значению
	if abs(current_progress - target_progress) > 0.5:
		current_progress = lerp(current_progress, target_progress, delta * 5)
		progress_bar.value = current_progress
	else:
		current_progress = target_progress
		progress_bar.value = current_progress

func complete_loading():
	# Устанавливаем прогресс в 100%
	target_progress = 100.0
	loading_text.text = "Готово!"
	
	# Ждем немного перед скрытием
	await get_tree().create_timer(0.5).timeout
	hide()

func _exit_tree():
	is_active = false
