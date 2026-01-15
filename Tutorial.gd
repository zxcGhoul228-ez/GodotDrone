extends Node

# AutoLoad name in your project: tut
# Path: res://tutorial/Tutorial.gd

const SCENE_MAIN := "res://main_scene.tscn"
const SCENE_CREATE := "res://create_drone/create_dron.tscn"
const SCENE_LEVEL_SELECT := "res://UI/game_level.tscn"
const SCENE_SHOP := "res://shop/shop.tscn"

# Шаги:
# 0  -> подсветить "Сборка"
# 1  -> ждать перехода в сцену сборки
# 2  -> подсветить кнопку "Рама"
# 3  -> ждать установки рамы
# 4  -> подсветить кнопку "Плата"
# 5  -> ждать установки платы
# 6  -> подсветить кнопку "Мотор"
# 7  -> ждать 4 мотора
# 8  -> подсветить кнопку "Пропеллер"
# 9  -> ждать 4 пропеллера
# 10 -> подсветить "Сохранить"
# 11 -> ждать saved
# 12 -> подсветить "Загрузить"
# 13 -> ждать loaded
# 14 -> (пропуск) Экспорт происходит автоматически при загрузке
# 15 -> (пропуск)
# 16 -> подсказка: ESC -> в главное меню
# 17 -> ждать сцены главного меню
# 18 -> подсветить "Выбор уровня"
# 19 -> ждать сцены выбора уровней
# 20 -> подсветить 1-й уровень
# 21 -> ждать загрузки уровня
# 22 -> подсказка: TAB -> программирование
# 23 -> ждать programming_open
# 24 -> подсказка/подсветка кнопки "Подсказка" + алгоритм
# 25 -> ждать level_completed
# 26 -> ждать возврата в главное меню
# 27 -> подсветить "Магазин"
# 28 -> ждать сцены магазина
# 29 -> финал
# 30 -> ожидание клика для завершения

var active: bool = false
var step: int = 0

var _overlay: CanvasLayer
var _ui: Control
var _label: RichTextLabel
var _highlight: Panel
var _skip_btn: Button

var dim_alpha: float = 0.0
var _dim: ColorRect

var _target: Control = null
var _target_padding: Vector2 = Vector2(10, 10)

var _last_scene_path: String = ""

var _level_hint_revealed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func start_tutorial() -> void:
	active = true
	step = 0

	_level_hint_revealed = false
	_last_scene_path = _get_scene_path()
	_show()
	_advance()

func stop_tutorial(go_to_main: bool = true) -> void:
	active = false
	_hide()
	step = 0
	if go_to_main and get_tree():
		get_tree().change_scene_to_file(SCENE_MAIN)

# Вызывается из других скриптов: tut.notify("event", data)
func notify(event_name: String, data: Variant = null) -> void:
	if not active:
		return

	match event_name:
		# Меню выбора/первый вариант
		"frame_menu_open":
			if step == 3:
				_set_text("Выбери [b]раму[/b]: нажми первый доступный вариант в списке.")
				_highlight_first_enabled_in_container("UI/ComponentSelectors/FrameSelector/FrameOptionsContainer")
		"board_menu_open":
			if step == 5:
				_set_text("Выбери [b]плату[/b]: нажми первый доступный вариант в списке.")
				_highlight_first_enabled_in_container("UI/ComponentSelectors/BoardSelector/BoardOptionsContainer")
		"motor_menu_open":
			if step == 7:
				_set_text("Выбери [b]мотор[/b]: нажми первый доступный вариант, затем поставь 4 мотора.")
				_highlight_first_enabled_in_container("UI/ComponentSelectors/MotorSelector/MotorOptionsContainer")
		"propeller_menu_open":
			if step == 9:
				_set_text("Выбери [b]пропеллер[/b]: нажми первый доступный вариант, затем поставь 4 пропеллера.")
				_highlight_first_enabled_in_container("UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer")

		# Спавн детали (после нажатия варианта) — меняем текст на "перетащи"
		"frame_spawned":
			if step == 3:
				_set_text("Отлично! Теперь [b]перетащи раму[/b] и [b]отпусти ЛКМ[/b], чтобы установить её.")
				_clear_highlight()
		"board_spawned":
			if step == 5:
				_set_text("Теперь [b]перетащи плату[/b] на раму и [b]отпусти ЛКМ[/b], чтобы закрепить.")
				_clear_highlight()
		"motor_spawned":
			if step == 7:
				_set_text("Перетащи мотор на точку крепления и отпусти ЛКМ. Нужно поставить [b]4 мотора[/b].")
				_clear_highlight()
		"propeller_spawned":
			if step == 9:
				_set_text("Перетащи пропеллер на мотор и отпусти ЛКМ. Нужно поставить [b]4 пропеллера[/b].")
				_clear_highlight()

		# Факт установки/прогресс
		"frame_added":
			if step == 3:
				_next() # -> 4
		"board_added":
			if step == 5:
				_next() # -> 6
		"motors_count":
			if step == 7 and int(data) >= 4:
				_next() # -> 8
		"propellers_count":
			if step == 9 and int(data) >= 4:
				_next() # -> 10
		"saved":
			if step == 11:
				_next() # -> 12
		"loaded":
			if step == 13:
				# Экспорт происходит автоматически при загрузке: не требуем отдельный шаг "Экспорт".
				step = 16
				_advance()
		"exported":
			# Экспорт может прилететь автоматически после загрузки — обычно игнорируем.
			if step == 15:
				_next() # -> 16
		"programming_open":
			if step == 23:
				_next() # -> 24
		"hint_pressed":
			# Показываем алгоритм только по нажатию на кнопку "Подсказка"
			if step == 25 and not _level_hint_revealed:
				_level_hint_revealed = true
				_set_text("Задай путь до цели (шарика). Перетащи/добавь команды в программу.\nНажми на команду в программе, чтобы указать количество её выполнений.\n\n[b]Подсказка:[/b] 3 назад, 3 вправо, 1 вверх")
		"level_completed":
			if step == 25:
				_next() # -> 26
		_:
			pass

func _process(_delta: float) -> void:
	if not active:
		return

	var sp := _get_scene_path()
	if sp != _last_scene_path:
		_last_scene_path = sp
		_on_scene_changed(sp)


	# AUTO: block programming already open -> продвигаем шаг
	if step == 23:
		var root := get_tree().current_scene
		if root != null:
			var bp := root.get_node_or_null("UI/BlockProgramming")
			if bp != null and bp is CanvasItem and (bp as CanvasItem).visible:
				_next()

	_update_highlight_position()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	# В финале любой клик/клавиша завершает
	if step >= 30:
		if event is InputEventMouseButton and event.pressed:
			stop_tutorial(true)
		elif event is InputEventKey and event.pressed:
			stop_tutorial(true)

func _on_scene_changed(scene_path: String) -> void:
	# Переходы между сценами
	if step == 1 and scene_path == SCENE_CREATE:
		_next() # -> 2
	elif step == 17 and scene_path == SCENE_MAIN:
		_next() # -> 18
	elif step == 19 and scene_path == SCENE_LEVEL_SELECT:
		_next() # -> 20
	elif step == 21:
		# Считаем что попали на уровень (любая сцена, не являющаяся меню/созданием/магазином)
		if scene_path != "" and scene_path != SCENE_LEVEL_SELECT and scene_path != SCENE_MAIN and scene_path != SCENE_CREATE and scene_path != SCENE_SHOP:
			_next() # -> 22
	elif step == 26 and scene_path == SCENE_MAIN:
		_next() # -> 27
	elif step == 28 and scene_path == SCENE_SHOP:
		_next() # -> 29

func _advance() -> void:
	match step:
		0:
			_set_text("Нажми [b]«Сборка дрона»[/b], чтобы собрать своего первого дрона.")
			_highlight_button_by_text("Сборка")
			step = 1

		2:
			_set_text("Сначала сделаем [b]раму[/b]. Нажми кнопку [b]«Рама»[/b] и выбери вариант.")
			_highlight_node_path("UI/ComponentSelectors/FrameSelector/FrameButton")
			step = 3

		4:
			_set_text("Теперь нужна [b]плата[/b]. Нажми [b]«Плата»[/b] и выбери вариант.")
			_highlight_node_path("UI/ComponentSelectors/BoardSelector/BoardButton")
			step = 5

		6:
			_set_text("Поставь [b]4 мотора[/b]. Нажми [b]«Мотор»[/b], выбери мотор и размести 4 штуки.")
			_highlight_node_path("UI/ComponentSelectors/MotorSelector/MotorButton")
			step = 7

		8:
			_set_text("Остались [b]пропеллеры[/b]. Выбери и установи [b]4 пропеллера[/b].")
			_highlight_node_path("UI/ComponentSelectors/PropellerSelector/PropellerButton")
			step = 9

		10:
			_set_text("Нажми [b]ESC[/b] (если нужно) и затем [b]«Сохранить»[/b], чтобы сохранить дрона в ячейку.")
			_highlight_button_by_text("Сохран")
			step = 11

		12:
			_set_text("Теперь нажми [b]«Загрузить»[/b]. После загрузки дрон [b]автоматически экспортируется на уровни[/b] — можно сразу идти в выбор уровня.")
			_highlight_button_by_text("Загруз")
			step = 13

		14:
			# Шаг "Экспорт" пропущен, т.к. экспорт выполняется автоматически при загрузке.
			step = 16
			call_deferred("_advance")

		16:
			_set_text("Нажми [b]ESC[/b], затем в меню выдели [b]«В главное меню»[/b] и нажми на неё.")
			# Если кнопка в ESC-меню тоже Button, попробуем подсветить по тексту
			_highlight_button_by_text("главн")
			step = 17

		18:
			_set_text("Теперь нажми [b]«Выбор уровня»[/b].")
			_highlight_button_by_text("Выбор")
			step = 19

		20:
			_set_text("Выбери [b]первый уровень[/b].")
			_highlight_first_level_button()
			step = 21

		22:
			_set_text("На уровне нажми [b]TAB[/b], чтобы открыть блок программирования.")
			_clear_highlight()
			step = 23

		24:
			_level_hint_revealed = false
			_set_text("Задай путь до цели (шарика). Добавляй команды в программу.\nНажми на команду в программе, чтобы указать количество её выполнений.\n\nЕсли нужна помощь — нажми [b]«Подсказка»[/b].")
			_highlight_hint_button()
			step = 25

		27:
			_set_text("Уровень пройден! Заглянем в [b]магазин[/b]. Нажми [b]«Магазин»[/b].")
			_highlight_button_by_text("Магаз")
			step = 28

		29:
			_set_text("В магазине можно покупать новые, улучшенные детали и усиления для дрона.\n\nПОЗДРАВЛЯЮ, ТЫ ПРОШЕЛ ОБУЧЕНИЕ! Нажми кнопку завершить обучение.")
			_clear_highlight()
			step = 30

		_:
			pass

func _next() -> void:
	if not active:
		return
	step += 1
	_advance()

# ================= Overlay =================
func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "TutorialLayer"
	_overlay.layer = 1000
	add_child(_overlay)

	_ui = Control.new()
	_ui.name = "TutorialUI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Оверлей НЕ должен блокировать клики по UI под ним.
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_ui)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0, 0, 0, dim_alpha)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_dim)

	_highlight = Panel.new()
	_highlight.name = "Highlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 0.85, 0.2, 1)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	_highlight.add_theme_stylebox_override("panel", sb)
	_ui.add_child(_highlight)

	var panel := Panel.new()
	panel.name = "HintPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = 20
	panel.offset_bottom = 170
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	psb.corner_radius_top_left = 12
	psb.corner_radius_top_right = 12
	psb.corner_radius_bottom_left = 12
	psb.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", psb)
	_ui.add_child(panel)

	_label = RichTextLabel.new()
	_label.name = "Hint"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.anchor_left = 0
	_label.anchor_right = 1
	_label.anchor_top = 0
	_label.anchor_bottom = 1
	_label.offset_left = 16
	_label.offset_right = -16
	_label.offset_top = 12
	_label.offset_bottom = -12
	panel.add_child(_label)

	_skip_btn = Button.new()
	_skip_btn.name = "Skip"
	_skip_btn.text = "⏭ Завершить обучение"
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_right = -16
	_skip_btn.offset_left = -240
	_skip_btn.offset_top = 16
	_skip_btn.offset_bottom = 52
	_skip_btn.pressed.connect(func():
		stop_tutorial(true)
	)
	_ui.add_child(_skip_btn)

	_ui.hide()

func _show() -> void:
	if _ui:
		_ui.show()

func _hide() -> void:
	if _ui:
		_ui.hide()

func _set_text(t: String) -> void:
	if _label:
		_label.text = t

func _get_scene_path() -> String:
	if get_tree() and get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		return get_tree().current_scene.scene_file_path
	return ""

# ================= Highlight helpers =================
func _find_button_by_text(root: Node, contains_text: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			var b: Button = n as Button
			if b.text.findn(contains_text) != -1:
				return b
		for c in n.get_children():
			stack.append(c)
	return null

func _highlight_button_by_text(contains_text: String) -> void:
	var root := get_tree().current_scene
	if root == null:
		_clear_highlight()
		return
	var b := _find_button_by_text(root, contains_text)
	_target = b

func _highlight_node_path(rel_path: String) -> void:
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	var n := root.get_node_or_null(rel_path)
	_target = n as Control if n is Control else null

func _highlight_first_level_button() -> void:
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	# Пытаемся найти кнопку "Level 1" или просто "1"
	var b := _find_button_by_text(root, "Level 1")
	if b == null:
		b = _find_button_by_text(root, "1")
	_target = b

func _highlight_hint_button() -> void:
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	var n := root.get_node_or_null("UI/BlockProgramming/TutorialHintButton")
	_target = n as Control if n is Control else null

func _highlight_first_enabled_in_container(rel_path: String) -> void:
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	var cont := root.get_node_or_null(rel_path)
	if cont == null:
		_target = null
		return

	for c in cont.get_children():
		if c is Button:
			var b := c as Button
			if b.visible and not b.disabled:
				_target = b
				return
		elif c is Control:
			var cc := c as Control
			if cc.visible:
				_target = cc
				return
	_target = null

func _clear_highlight() -> void:
	_target = null

func _update_highlight_position() -> void:
	if not _highlight or not is_instance_valid(_highlight):
		return
	if _target == null or not is_instance_valid(_target):
		_highlight.visible = false
		return

	_highlight.visible = true
	var r: Rect2 = _target.get_global_rect()
	r.position -= _target_padding
	r.size += _target_padding * 2.0
	_highlight.global_position = r.position
	_highlight.size = r.size
