extends Control

@onready var background: TextureRect = $Background
@onready var scrim: ColorRect = $Scrim
@onready var loading_text: Label = $VBoxContainer/CenterContainer/LoadingText
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var vbox: VBoxContainer = $VBoxContainer

var current_progress: float = 0.0
var target_progress: float = 0.0
var is_active: bool = false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if background != null:
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if scrim != null:
		scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0.07, 0.05, 0.04, 0.62)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	loading_text.text = "Подготовка сцены..."
	loading_text.modulate.a = 0.0
	loading_text.add_theme_font_size_override("font_size", 28)
	loading_text.add_theme_color_override("font_color", Color(0.97, 0.92, 0.86))

	progress_bar.visible = false
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	_apply_progress_bar_theme()

	vbox.modulate.a = 0.0

func _apply_progress_bar_theme() -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.15, 0.10, 0.07, 0.92)
	base_style.border_width_left = 2
	base_style.border_width_top = 2
	base_style.border_width_right = 2
	base_style.border_width_bottom = 2
	base_style.border_color = Color(0.75, 0.57, 0.37, 0.86)
	base_style.corner_radius_top_left = 14
	base_style.corner_radius_top_right = 14
	base_style.corner_radius_bottom_right = 14
	base_style.corner_radius_bottom_left = 14

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.82, 0.61, 0.35, 0.96)
	fill_style.corner_radius_top_left = 12
	fill_style.corner_radius_top_right = 12
	fill_style.corner_radius_bottom_right = 12
	fill_style.corner_radius_bottom_left = 12

	progress_bar.add_theme_stylebox_override("background", base_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func start_loading():
	is_active = true
	current_progress = 0.0
	target_progress = 0.0
	progress_bar.value = 0.0
	progress_bar.visible = true
	start_entrance_animation()

func start_entrance_animation():
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.45)
	tween.tween_callback(start_animations)

func start_animations():
	start_text_animation()

func start_text_animation():
	var text_tween: Tween = create_tween()
	text_tween.set_loops()
	text_tween.tween_property(loading_text, "modulate:a", 1.0, 0.8)
	text_tween.tween_property(loading_text, "modulate:a", 0.72, 0.8)

func set_progress(progress: float):
	target_progress = progress * 100.0
	update_loading_text_based_on_progress(progress)

func update_loading_text(status: String):
	loading_text.text = status

func update_loading_text_based_on_progress(progress: float):
	if progress < 0.15:
		loading_text.text = "Подготовка сцены..."
	elif progress < 0.35:
		loading_text.text = "Загрузка окружения..."
	elif progress < 0.55:
		loading_text.text = "Подключение систем..."
	elif progress < 0.8:
		loading_text.text = "Сборка игрового поля..."
	elif progress < 0.97:
		loading_text.text = "Финальные штрихи..."
	else:
		loading_text.text = "Готово"

func _process(delta: float):
	if not is_active:
		return

	if absf(current_progress - target_progress) > 0.5:
		current_progress = lerpf(current_progress, target_progress, delta * 5.0)
	else:
		current_progress = target_progress
	progress_bar.value = current_progress

func complete_loading():
	target_progress = 100.0
	loading_text.text = "Готово"
	await get_tree().create_timer(0.4).timeout
	hide()

func _exit_tree():
	is_active = false
