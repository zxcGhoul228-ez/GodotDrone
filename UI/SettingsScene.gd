extends CanvasLayer

# ==================== ССЫЛКИ НА ЭЛЕМЕНТЫ UI ====================
@onready var fps_option: OptionButton = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer/OptionButton

@onready var mouse_sens_slider: HSlider = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer2/HSlider
@onready var mouse_sens_value: Label = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer2/Label2

@onready var fov_slider: HSlider = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer4/HSlider
@onready var fov_value: Label = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer4/Label2

@onready var brightness_slider: HSlider = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer5/HSlider
@onready var brightness_value: Label = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer5/Label2

@onready var music_volume_slider: HSlider = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer6/HSlider
@onready var music_volume_value: Label = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer6/Label2

@onready var sfx_volume_slider: HSlider = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer7/HSlider
@onready var sfx_volume_value: Label = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer7/Label2

@onready var save_button: Button = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer3/Button
@onready var default_button: Button = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer3/Button2
@onready var cancel_button: Button = $ColorRect/CenterContainer/Panel/VBoxContainer/HBoxContainer3/Button3

# ==================== СИГНАЛЫ ====================
signal settings_saved
signal settings_cancelled
signal settings_closed

# ==================== ПЕРЕМЕННЫЕ ====================
var original_settings = {}

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
func _ready():
	print("🔄 Инициализация SettingsScene...")
	
	# Проверяем наличие ВСЕХ необходимых элементов
	_check_all_nodes()
	
	# Настраиваем OptionButton для FPS
	if fps_option:
		_setup_fps_option()
	else:
		print("❌ fps_option не найден - создайте OptionButton в HBoxContainer")
		return
	
	# Инициализируем значения из Global.gd
	load_settings_from_global()
	save_original_settings()
	
	# Подключаем сигналы
	connect_signals()
	
	# Настраиваем видимость
	visible = false
	
	print("✅ Сцена настроек инициализирована")

func _check_all_nodes():
	"""Проверяет наличие всех необходимых узлов"""
	var nodes_to_check = {
		"fps_option": fps_option,
		"mouse_sens_slider": mouse_sens_slider,
		"mouse_sens_value": mouse_sens_value,
		"fov_slider": fov_slider,
		"fov_value": fov_value,
		"brightness_slider": brightness_slider,
		"brightness_value": brightness_value,
		"music_volume_slider": music_volume_slider,
		"music_volume_value": music_volume_value,
		"sfx_volume_slider": sfx_volume_slider,
		"sfx_volume_value": sfx_volume_value,
		"save_button": save_button,
		"default_button": default_button,
		"cancel_button": cancel_button
	}
	
	for node_name in nodes_to_check:
		var node = nodes_to_check[node_name]
		if node != null:
			print("✅ Найден: ", node_name)
		else:
			print("❌ Не найден: ", node_name, " - проверьте путь в сцене")

func _setup_fps_option():
	"""Настраивает OptionButton для выбора FPS"""
	# Очищаем существующие элементы
	fps_option.clear()
	
	# Добавляем элементы
	fps_option.add_item("30 FPS", 0)
	fps_option.add_item("60 FPS", 1)
	fps_option.add_item("120 FPS", 2)
	fps_option.add_item("VSync", 3)
	
	print("✅ OptionButton для FPS настроен")

func connect_signals():
	"""Подключает все сигналы от элементов управления"""
	# FPS
	if fps_option:
		fps_option.item_selected.connect(_on_fps_selected)
	
	# Чувствительность мыши
	if mouse_sens_slider:
		mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	
	# FOV
	if fov_slider:
		fov_slider.value_changed.connect(_on_fov_changed)
	
	# Яркость
	if brightness_slider:
		brightness_slider.value_changed.connect(_on_brightness_changed)
	
	# Громкость музыки
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	
	# Громкость звуков
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Кнопки
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	
	if default_button:
		default_button.pressed.connect(_on_default_pressed)
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	
	print("✅ Все сигналы подключены")

# ==================== ЗАГРУЗКА И СОХРАНЕНИЕ НАСТРОЕК ====================
func load_settings_from_global():
	"""Загружает текущие значения из Global.gd"""
	print("🔄 Загружаем настройки из Global...")
	
	if not Global:
		print("❌ Global не найден")
		return
	
	# FPS
	if fps_option:
		fps_option.selected = Global.fps_mode
		print("✅ FPS установлен: ", Global.fps_mode)
	
	# Чувствительность мыши
	if mouse_sens_slider and mouse_sens_value:
		mouse_sens_slider.value = Global.mouse_sensitivity * 50.0
		mouse_sens_value.text = "%s%%" % [round(Global.mouse_sensitivity * 50.0 * 10.0) / 10.0]
		print("✅ Чувствительность мыши: ", mouse_sens_slider.value)
	
	# FOV
	if fov_slider and fov_value:
		fov_slider.value = Global.camera_fov
		fov_value.text = str(int(Global.camera_fov))
		print("✅ FOV: ", fov_slider.value)
	
	# Яркость
	if brightness_slider and brightness_value:
		brightness_slider.value = Global.brightness * 50.0
		brightness_value.text = "%s%%" % [round(Global.brightness * 50.0 * 10.0) / 10.0]
		print("✅ Яркость: ", brightness_slider.value)
	
	# Громкость музыки
	if music_volume_slider and music_volume_value:
		music_volume_slider.value = Global.music_volume
		music_volume_value.text = "%s%%" % [round(Global.music_volume * 10.0) / 10.0]
		print("✅ Громкость музыки: ", music_volume_slider.value)
	
	# Громкость звуков
	if sfx_volume_slider and sfx_volume_value:
		sfx_volume_slider.value = Global.sfx_volume
		sfx_volume_value.text = "%s%%" % [round(Global.sfx_volume * 10.0) / 10.0]
		print("✅ Громкость звуков: ", sfx_volume_slider.value)
	
	print("✅ Все настройки загружены")

func save_original_settings():
	"""Сохраняет оригинальные значения для возможности отмены"""
	if not Global:
		print("❌ Global не найден")
		return
	
	original_settings = {
		"fps_mode": Global.fps_mode,
		"mouse_sensitivity": Global.mouse_sensitivity,
		"camera_fov": Global.camera_fov,
		"brightness": Global.brightness,
		"music_volume": Global.music_volume,
		"sfx_volume": Global.sfx_volume
	}
	
	print("💾 Оригинальные настройки сохранены")

func restore_original_settings():
	"""Восстанавливает оригинальные значения"""
	if original_settings.is_empty() or not Global:
		print("❌ Не могу восстановить настройки")
		return
	
	print("↩️ Восстанавливаем оригинальные настройки...")
	
	Global.fps_mode = original_settings["fps_mode"]
	Global.mouse_sensitivity = original_settings["mouse_sensitivity"]
	Global.camera_fov = original_settings["camera_fov"]
	Global.brightness = original_settings["brightness"]
	Global.music_volume = original_settings["music_volume"]
	Global.sfx_volume = original_settings["sfx_volume"]
	
	load_settings_from_global()
	print("✅ Настройки восстановлены")

# ==================== ОБРАБОТЧИКИ СИГНАЛОВ ====================
func _on_fps_selected(index: int):
	if Global:
		Global.fps_mode = index
		print("📊 Выбрана частота кадров: ", index)

func _on_mouse_sens_changed(value: float):
	if Global:
		Global.mouse_sensitivity = value / 50.0
		if mouse_sens_value:
			mouse_sens_value.text = "%s%%" % [round(value * 10.0) / 10.0]
		print("🐭 Чувствительность мыши: ", value, "%")

func _on_fov_changed(value: float):
	if Global:
		Global.camera_fov = value
		if fov_value:
			fov_value.text = str(int(value))
		print("👁️ Поле зрения: ", value)

func _on_brightness_changed(value: float):
	if Global:
		Global.brightness = value / 50.0
		if brightness_value:
			brightness_value.text = "%s%%" % [round(value * 10.0) / 10.0]
		print("💡 Яркость: ", value, "%")

func _on_music_volume_changed(value: float):
	if Global:
		Global.music_volume = value
		if music_volume_value:
			music_volume_value.text = "%s%%" % [round(value * 10.0) / 10.0]
		print("🎵 Громкость музыки: ", value, "%")

func _on_sfx_volume_changed(value: float):
	if Global:
		Global.sfx_volume = value
		if sfx_volume_value:
			sfx_volume_value.text = "%s%%" % [round(value * 10.0) / 10.0]
		print("🔊 Громкость звуков: ", value, "%")

func _on_save_pressed():
	print("💾 Нажата кнопка Сохранить")
	
	if not Global:
		print("❌ Global не найден")
		return
	
	# Сохраняем настройки
	Global.save_global_settings()
	# Применяем настройки
	Global.apply_global_settings()
	
	emit_signal("settings_saved")
	close()
	print("✅ Настройки сохранены и применены")

func _on_default_pressed():
	print("⚙️ Нажата кнопка По умолчанию")
	
	if not Global:
		print("❌ Global не найден")
		return
	
	# Сброс к значениям по умолчанию
	Global.fps_mode = 3
	Global.mouse_sensitivity = 1.0
	Global.camera_fov = 75.0
	Global.brightness = 1.0
	Global.music_volume = 50.0
	Global.sfx_volume = 50.0
	
	load_settings_from_global()
	print("✅ Настройки сброшены по умолчанию")

func _on_cancel_pressed():
	print("❌ Нажата кнопка Отмена")
	
	# Восстанавливаем оригинальные значения
	restore_original_settings()
	emit_signal("settings_cancelled")
	close()
	print("✅ Изменения отменены")

# ==================== УПРАВЛЕНИЕ ОТКРЫТИЕМ/ЗАКРЫТИЕМ ====================
func open():
	"""Открывает меню настроек"""
	print("📋 Открываем меню настроек...")
	
	if not Global:
		print("❌ Global не найден")
		return
	
	load_settings_from_global()
	save_original_settings()
	
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Фокус на кнопку сохранения
	if save_button:
		save_button.grab_focus()
	
	print("✅ Меню настроек открыто")

func close():
	"""Закрывает меню настроек"""
	print("📋 Закрываем меню настроек...")
	
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	
	emit_signal("settings_closed")
	print("✅ Меню настроек закрыто")

func toggle():
	"""Переключает видимость меню настроек"""
	if visible:
		close()
	else:
		open()

func is_open() -> bool:
	return visible

# ==================== ОБРАБОТКА ВВОДА ====================
func _input(event):
	# Закрытие по ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			print("⎋ Нажата ESC в меню настроек")
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()
