extends Control

@export var audio_player: AudioStreamPlayer
@export var score_label: Label

# Переменные для меню настроек
var settings_menu = null
var is_settings_visible = false

# Временные переменные для хранения значений до открытия меню
var original_settings = {}

# Автоматические свойства для настроек
var mouse_sensitivity: 
	get: return Global.mouse_sensitivity
	set(value): Global.mouse_sensitivity = value

var camera_fov: 
	get: return Global.camera_fov
	set(value): Global.camera_fov = value

var brightness: 
	get: return Global.brightness
	set(value): Global.brightness = value

var music_volume: 
	get: return Global.music_volume
	set(value): Global.music_volume = value

var sfx_volume: 
	get: return Global.sfx_volume
	set(value): Global.sfx_volume = value

var fps_mode: 
	get: return Global.fps_mode
	set(value): Global.fps_mode = value

func _ready():
	print("=== MAIN MENU INIT ===")
	
	# Отладочная проверка структуры
	print("Дочерние узлы корня:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	# Подключаем сигналы кнопок
	var game_butt = get_node_or_null("TextureRect/HBoxContainer/VBoxContainer/GameButt")
	if game_butt:
		game_butt.pressed.connect(_on_start_pressed)
		print("✅ GameButt подключен")
	else:
		print("❌ GameButt не найден")
	
	var inv_butt = get_node_or_null("TextureRect/HBoxContainer/VBoxContainer/InvButt")
	if inv_butt:
		inv_butt.pressed.connect(_on_CreateDron_pressed)
		print("✅ InvButt подключен")
	else:
		print("❌ InvButt не найден")
	
	var shop_butt = get_node_or_null("TextureRect/HBoxContainer/VBoxContainer/ShopButt")
	if shop_butt:
		shop_butt.pressed.connect(_on_shop_pressed)
		print("✅ ShopButt подключен")
	else:
		print("❌ ShopButt не найден")
	
	# Подключаем кнопку настроек
	var sett_button = get_node_or_null("TextureRect/Label/VBoxContainer/HBoxContainer/sett_button")
	if sett_button:
		sett_button.pressed.connect(_on_settings_button_pressed)
		print("✅ sett_button найден и подключен по прямому пути")
	else:
		print("⚠️ sett_button не найден по прямому пути. Ищем...")
		
		# Альтернативный поиск
		var all_buttons = []
		find_all_buttons(self, all_buttons)
		
		print("Найдено кнопок: ", all_buttons.size())
		for btn in all_buttons:
			print("  - ", btn.name, " (", btn.get_parent().name if btn.get_parent() else "no parent", ")")
			
			# Если кнопка содержит "sett" в имени
			if "sett" in btn.name.to_lower():
				print("🎯 Найдена кнопка настроек: ", btn.name)
				btn.pressed.connect(_on_settings_button_pressed)
				break
	
	if score_label:
		update_score_display()
	else:
		print("⚠️ score_label не установлен в инспекторе!")
	
	# Воспроизводим музыку
	if audio_player:
		audio_player.play()
		apply_music_volume()
	else:
		print("⚠️ audio_player не установлен в инспекторе!")
	
	print("=== MAIN MENU READY ===")

func find_all_buttons(node: Node, buttons: Array):
	for child in node.get_children():
		if child is BaseButton:
			buttons.append(child)
		find_all_buttons(child, buttons)

func update_score_display():
	score_label.text = "Очки: " + str(Global.score)  # Просто используем Global.scor

func apply_music_volume():
	if audio_player:
		# Преобразуем проценты в децибелы
		# 0% = -80 dB (тишина), 100% = 0 dB (максимум)
		var db_value = linear_to_db(music_volume / 100.0)
		audio_player.volume_db = db_value
		print("🔊 Громкость музыки установлена: ", round(music_volume * 10) / 10, "% (", db_value, " dB)")

func apply_brightness():
	var canvas_modulate = get_node_or_null("CanvasModulate")
	if not canvas_modulate:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		add_child(canvas_modulate)
		move_child(canvas_modulate, 0)
	
	# Преобразуем проценты в значение яркости (1% = 0.02, 100% = 2.0)
	var brightness_value = brightness
	canvas_modulate.color = Color(brightness_value, brightness_value, brightness_value, 1.0)
	print("💡 Яркость установлена: ", round(brightness_value * 50 * 10) / 10, "%")

func _on_button_pressed():
	Global.score += 10
	update_score_display()

func _on_start_pressed():
	print("🎮 Переход к выбору уровней")
	get_tree().change_scene_to_file("res://UI/game_level.tscn")

func _on_shop_pressed():
	print("🛒 Переход в магазин")
	get_tree().change_scene_to_file("res://shop/shop.tscn")

func _on_CreateDron_pressed():
	print("🔧 Переход к созданию дрона")
	Global.load_scene_with_loading("res://create_drone/create_dron.tscn")

func _on_exit_pressed():
	get_tree().quit()

# ================== МЕНЮ НАСТРОЕК ==================
func _on_settings_button_pressed():
	print("⚙️ Открываем настройки")
	show_settings_menu()

func show_settings_menu():
	print("🔄 Показываем меню настроек...")
	
	# Сохраняем оригинальные значения перед изменением
	save_original_settings()
	
	if settings_menu == null:
		print("🆕 Создаем меню настроек")
		create_settings_menu()
	else:
		# Обновляем значения в UI при показе
		update_settings_ui()
	
	if settings_menu:
		settings_menu.visible = true
		is_settings_visible = true
		print("✅ Меню настроек видимо")
	else:
		print("❌ Меню настроек не создано!")

func save_original_settings():
	# Сохраняем оригинальные значения настроек
	original_settings = {
		"fps_mode": fps_mode,
		"mouse_sensitivity": mouse_sensitivity,
		"camera_fov": camera_fov,
		"brightness": brightness,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}
	print("💾 Сохранены оригинальные настройки")

func restore_original_settings():
	if original_settings.is_empty():
		return
	
	# Восстанавливаем оригинальные значения
	fps_mode = original_settings["fps_mode"]
	mouse_sensitivity = original_settings["mouse_sensitivity"]
	camera_fov = original_settings["camera_fov"]
	brightness = original_settings["brightness"]
	music_volume = original_settings["music_volume"]
	sfx_volume = original_settings["sfx_volume"]
	
	# Применяем восстановленные настройки
	apply_brightness()
	apply_music_volume()
	Global.apply_global_settings()
	
	print("↩️ Настройки восстановлены до исходных значений")

func hide_settings_menu():
	print("🔄 Скрываем меню настроек")
	
	if settings_menu:
		settings_menu.visible = false
		is_settings_visible = false
		print("✅ Меню настроек скрыто")
	else:
		print("❌ Нет меню настроек для скрытия")

func create_settings_menu():
	print("🔧 Создаем меню настроек...")
	
	# Создаем фон
	settings_menu = ColorRect.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.color = Color(0, 0, 0, 0.8)
	settings_menu.size = get_viewport().size
	settings_menu.visible = false
	settings_menu.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Создаем контейнер
	var container = VBoxContainer.new()
	container.name = "SettingsContainer"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size = Vector2(600, 700)
	
	# Центрируем
	var viewport_size = Vector2(get_viewport().size)
	container.position = (viewport_size - container.size) / 2
	
	# Заголовок
	var title = Label.new()
	title.name = "Title"
	title.text = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.WHITE)
	
	# Настройки FPS
	var fps_container = HBoxContainer.new()
	fps_container.name = "FPSContainer"
	var fps_label = Label.new()
	fps_label.text = "Частота кадров:"
	fps_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fps_option = OptionButton.new()
	fps_option.name = "FPSOption"
	fps_option.add_item("30 FPS", 0)
	fps_option.add_item("60 FPS", 1)
	fps_option.add_item("120 FPS", 2)
	fps_option.add_item("VSync", 3)
	fps_option.selected = fps_mode
	fps_option.item_selected.connect(_on_fps_selected)
	fps_container.add_child(fps_label)
	fps_container.add_child(fps_option)
	
	# Настройки чувствительности мыши (от 1 до 100%)
	var mouse_sens_container = HBoxContainer.new()
	mouse_sens_container.name = "MouseSensContainer"
	var mouse_sens_label = Label.new()
	mouse_sens_label.text = "Чувствительность мыши (%):"
	mouse_sens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var mouse_sens_slider = HSlider.new()
	mouse_sens_slider.name = "MouseSensSlider"
	mouse_sens_slider.min_value = 1  # Минимум 1%
	mouse_sens_slider.max_value = 100  # Максимум 100%
	mouse_sens_slider.step = 0.1  # Шаг 0.1% для плавности
	mouse_sens_slider.value = mouse_sensitivity * 50  # Преобразуем из диапазона 0.02-2.0 в 1-100
	
	mouse_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	
	var mouse_sens_value = Label.new()
	mouse_sens_value.name = "MouseSensValue"
	mouse_sens_value.text = str(round(mouse_sensitivity * 50 * 10) / 10) + "%"
	mouse_sens_value.custom_minimum_size = Vector2(60, 0)  # Увеличим место для процентов
	
	mouse_sens_container.add_child(mouse_sens_label)
	mouse_sens_container.add_child(mouse_sens_slider)
	mouse_sens_container.add_child(mouse_sens_value)
	
	# Настройки FOV
	var fov_container = HBoxContainer.new()
	fov_container.name = "FOVContainer"
	var fov_label = Label.new()
	fov_label.text = "Поле зрения (FOV):"
	fov_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fov_slider = HSlider.new()
	fov_slider.name = "FOVSlider"
	fov_slider.min_value = 60
	fov_slider.max_value = 120
	fov_slider.value = camera_fov
	fov_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_slider.value_changed.connect(_on_fov_changed)
	var fov_value = Label.new()
	fov_value.name = "FOVValue"
	fov_value.text = str(int(camera_fov))
	fov_value.custom_minimum_size = Vector2(40, 0)
	fov_container.add_child(fov_label)
	fov_container.add_child(fov_slider)
	fov_container.add_child(fov_value)
	
	# Настройки яркости (от 1 до 100%)
	var brightness_container = HBoxContainer.new()
	brightness_container.name = "BrightnessContainer"
	var brightness_label = Label.new()
	brightness_label.text = "Яркость (%):"
	brightness_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var brightness_slider = HSlider.new()
	brightness_slider.name = "BrightnessSlider"
	brightness_slider.min_value = 1  # Минимум 1%
	brightness_slider.max_value = 100  # Максимум 100%
	brightness_slider.step = 0.1  # Шаг 0.1% для плавности
	brightness_slider.value = brightness * 50  # Преобразуем из диапазона 0.02-2.0 в 1-100
	brightness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brightness_slider.value_changed.connect(_on_brightness_changed)
	var brightness_value = Label.new()
	brightness_value.name = "BrightnessValue"
	brightness_value.text = str(round(brightness * 50 * 10) / 10) + "%"
	brightness_value.custom_minimum_size = Vector2(60, 0)
	brightness_container.add_child(brightness_label)
	brightness_container.add_child(brightness_slider)
	brightness_container.add_child(brightness_value)
	
	# Настройки громкости музыки (от 0 до 100%)
	var music_volume_container = HBoxContainer.new()
	music_volume_container.name = "MusicVolumeContainer"
	var music_volume_label = Label.new()
	music_volume_label.text = "Громкость музыки (%):"
	music_volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var music_volume_slider = HSlider.new()
	music_volume_slider.name = "MusicVolumeSlider"
	music_volume_slider.min_value = 0  # Минимум 0% (выключено)
	music_volume_slider.max_value = 100  # Максимум 100%
	music_volume_slider.step = 0.1  # Шаг 0.1% для плавности
	music_volume_slider.value = music_volume  # Уже в процентах (0-100)
	music_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	var music_volume_value = Label.new()
	music_volume_value.name = "MusicVolumeValue"
	music_volume_value.text = str(round(music_volume * 10) / 10) + "%"
	music_volume_value.custom_minimum_size = Vector2(60, 0)
	music_volume_container.add_child(music_volume_label)
	music_volume_container.add_child(music_volume_slider)
	music_volume_container.add_child(music_volume_value)
	
	# Настройки громкости звуков (от 0 до 100%)
	var sfx_volume_container = HBoxContainer.new()
	sfx_volume_container.name = "SFXVolumeContainer"
	var sfx_volume_label = Label.new()
	sfx_volume_label.text = "Громкость звуков (%):"
	sfx_volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_volume_slider = HSlider.new()
	sfx_volume_slider.name = "SFXVolumeSlider"
	sfx_volume_slider.min_value = 0  # Минимум 0% (выключено)
	sfx_volume_slider.max_value = 100  # Максимум 100%
	sfx_volume_slider.step = 0.1  # Шаг 0.1% для плавности
	sfx_volume_slider.value = sfx_volume  # Уже в процентах (0-100)
	sfx_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	var sfx_volume_value = Label.new()
	sfx_volume_value.name = "SFXVolumeValue"
	sfx_volume_value.text = str(round(sfx_volume * 10) / 10) + "%"
	sfx_volume_value.custom_minimum_size = Vector2(60, 0)
	sfx_volume_container.add_child(sfx_volume_label)
	sfx_volume_container.add_child(sfx_volume_slider)
	sfx_volume_container.add_child(sfx_volume_value)
	
	# Разделитель
	var separator = HSeparator.new()
	separator.name = "Separator"
	separator.custom_minimum_size = Vector2(500, 2)
	
	# Кнопки управления
	var buttons_container = HBoxContainer.new()
	buttons_container.name = "ButtonsContainer"
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var save_btn = Button.new()
	save_btn.name = "SaveButton"
	save_btn.text = "Сохранить"
	save_btn.custom_minimum_size = Vector2(150, 40)
	save_btn.pressed.connect(_on_save_settings)
	
	var default_btn = Button.new()
	default_btn.name = "DefaultButton"
	default_btn.text = "По умолчанию"
	default_btn.custom_minimum_size = Vector2(150, 40)
	default_btn.pressed.connect(_on_default_settings)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(150, 40)
	cancel_btn.pressed.connect(_on_cancel_settings)
	
	buttons_container.add_child(save_btn)
	buttons_container.add_child(default_btn)
	buttons_container.add_child(cancel_btn)
	
	# Добавляем все элементы в контейнер
	container.add_child(title)
	container.add_child(fps_container)
	container.add_child(mouse_sens_container)
	container.add_child(fov_container)
	container.add_child(brightness_container)
	container.add_child(music_volume_container)
	container.add_child(sfx_volume_container)
	container.add_child(separator)
	container.add_child(buttons_container)
	
	container.add_theme_constant_override("separation", 20)
	
	# Добавляем контейнер в меню настроек
	settings_menu.add_child(container)
	
	# Добавляем меню настроек на сцену
	add_child(settings_menu)
	
	# Устанавливаем высокий z-index чтобы было поверх всего
	settings_menu.z_index = 100
	
	print("✅ Меню настроек создано с ", container.get_child_count(), " элементами")

func update_settings_ui():
	if not settings_menu:
		return
	
	var container = settings_menu.get_child(0)
	
	# Обновляем все UI элементы текущими значениями
	
	# FPS
	var fps_container = container.get_child(1)
	var fps_option = fps_container.get_child(1)
	fps_option.selected = fps_mode
	
	# Чувствительность мыши
	var mouse_sens_container = container.get_child(2)
	var mouse_sens_slider = mouse_sens_container.get_child(1)
	var mouse_sens_value = mouse_sens_container.get_child(2)
	mouse_sens_slider.value = mouse_sensitivity * 50  # Преобразуем в проценты
	mouse_sens_value.text = str(round(mouse_sensitivity * 50 * 10) / 10) + "%"
	
	# FOV
	var fov_container = container.get_child(3)
	var fov_slider = fov_container.get_child(1)
	var fov_value = fov_container.get_child(2)
	fov_slider.value = camera_fov
	fov_value.text = str(int(camera_fov))
	
	# Яркость
	var brightness_container = container.get_child(4)
	var brightness_slider = brightness_container.get_child(1)
	var brightness_value = brightness_container.get_child(2)
	brightness_slider.value = brightness * 50  # Преобразуем в проценты
	brightness_value.text = str(round(brightness * 50 * 10) / 10) + "%"
	
	# Громкость музыки
	var music_container = container.get_child(5)
	var music_slider = music_container.get_child(1)
	var music_value = music_container.get_child(2)
	music_slider.value = music_volume
	music_value.text = str(round(music_volume * 10) / 10) + "%"
	
	# Громкость звуков
	var sfx_container = container.get_child(6)
	var sfx_slider = sfx_container.get_child(1)
	var sfx_value = sfx_container.get_child(2)
	sfx_slider.value = sfx_volume
	sfx_value.text = str(round(sfx_volume * 10) / 10) + "%"

func _on_fps_selected(index: int):
	print("📊 Выбрана частота кадров: ", index)
	fps_mode = index

func _on_mouse_sens_changed(value: float):
	print("🐭 Чувствительность мыши изменена: ", value, "%")
	# Преобразуем из процентов (1-100) в диапазон 0.02-2.0
	mouse_sensitivity = value / 50.0
	if settings_menu:
		var container = settings_menu.get_child(0)
		var mouse_sens_container = container.get_child(2)
		var value_label = mouse_sens_container.get_child(2)
		value_label.text = str(round(value * 10) / 10) + "%"  # Округляем до 0.1%

func _on_fov_changed(value: float):
	print("👁️ Поле зрения изменено: ", value)
	camera_fov = value
	if settings_menu:
		var container = settings_menu.get_child(0)
		var fov_container = container.get_child(3)
		var value_label = fov_container.get_child(2)
		value_label.text = str(int(value))

func _on_brightness_changed(value: float):
	print("💡 Яркость изменена: ", value, "%")
	# Преобразуем из процентов (1-100) в диапазон 0.02-2.0
	brightness = value / 50.0
	if settings_menu:
		var container = settings_menu.get_child(0)
		var brightness_container = container.get_child(4)
		var value_label = brightness_container.get_child(2)
		value_label.text = str(round(value * 10) / 10) + "%"
	
	apply_brightness()

func _on_music_volume_changed(value: float):
	print("🎵 Громкость музыки изменена: ", value, "%")
	music_volume = value  # Уже в процентах
	if settings_menu:
		var container = settings_menu.get_child(0)
		var music_container = container.get_child(5)
		var value_label = music_container.get_child(2)
		value_label.text = str(round(value * 10) / 10) + "%"
	
	apply_music_volume()

func _on_sfx_volume_changed(value: float):
	print("🔊 Громкость звуков изменена: ", value, "%")
	sfx_volume = value  # Уже в процентах
	if settings_menu:
		var container = settings_menu.get_child(0)
		var sfx_container = container.get_child(6)
		var value_label = sfx_container.get_child(2)
		value_label.text = str(round(value * 10) / 10) + "%"

func _on_save_settings():
	print("💾 Сохраняем настройки")
	Global.save_global_settings()
	Global.apply_global_settings()
	hide_settings_menu()
	print("✅ Настройки сохранены")

func _on_cancel_settings():
	print("❌ Отмена изменений настроек")
	# Восстанавливаем оригинальные настройки
	restore_original_settings()
	hide_settings_menu()
	print("↩️ Настройки возвращены к исходным значениям")

func _on_default_settings():
	print("⚙️ Сбрасываем настройки по умолчанию")
	
	# Сбрасываем значения по умолчанию
	fps_mode = 3
	mouse_sensitivity = 1.0  # Это будет 50% (1.0 / 50 = 0.02)
	camera_fov = 75.0
	brightness = 1.0  # Это будет 50% (1.0 / 50 = 0.02)
	music_volume = 50.0  # 50%
	sfx_volume = 50.0  # 50%
	
	# Обновляем UI
	if settings_menu:
		var container = settings_menu.get_child(0)
		
		# FPS
		var fps_container = container.get_child(1)
		var fps_option = fps_container.get_child(1)
		fps_option.selected = fps_mode
		
		# Чувствительность мыши
		var mouse_sens_container = container.get_child(2)
		var mouse_sens_slider = mouse_sens_container.get_child(1)
		var mouse_sens_value = mouse_sens_container.get_child(2)
		mouse_sens_slider.value = mouse_sensitivity * 50  # Преобразуем в проценты
		mouse_sens_value.text = str(round(mouse_sensitivity * 50 * 10) / 10) + "%"
		
		# FOV
		var fov_container = container.get_child(3)
		var fov_slider = fov_container.get_child(1)
		var fov_value = fov_container.get_child(2)
		fov_slider.value = camera_fov
		fov_value.text = str(int(camera_fov))
		
		# Яркость
		var brightness_container = container.get_child(4)
		var brightness_slider = brightness_container.get_child(1)
		var brightness_value = brightness_container.get_child(2)
		brightness_slider.value = brightness * 50  # Преобразуем в проценты
		brightness_value.text = str(round(brightness * 50 * 10) / 10) + "%"
		
		# Громкость музыки
		var music_container = container.get_child(5)
		var music_slider = music_container.get_child(1)
		var music_value = music_container.get_child(2)
		music_slider.value = music_volume
		music_value.text = str(round(music_volume * 10) / 10) + "%"
		
		# Громкость звуков
		var sfx_container = container.get_child(6)
		var sfx_slider = sfx_container.get_child(1)
		var sfx_value = sfx_container.get_child(2)
		sfx_slider.value = sfx_volume
		sfx_value.text = str(round(sfx_volume * 10) / 10) + "%"
	
	# Применяем изменения
	apply_brightness()
	apply_music_volume()
	
	print("✅ Настройки сброшены по умолчанию")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("⎋ Нажата клавиша ESC")
		
		if is_settings_visible:
			print("🔄 Закрываем меню настроек по ESC")
			# При закрытии через ESC отменяем изменения
			_on_cancel_settings()
			get_viewport().set_input_as_handled()
		else:
			print("🔄 Открываем меню настроек по ESC")
			# Открываем меню настроек
			show_settings_menu()
			get_viewport().set_input_as_handled()
