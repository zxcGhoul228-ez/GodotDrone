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
# 14 -> (пропуск) экспорт происходит автоматически при загрузке
# 16 -> подсказка: ESC -> в главное меню
# 17 -> ждать сцены главного меню
# 18 -> подсветить "Выбор уровня"
# 19 -> ждать сцены выбора уровней
# 20 -> подсветить 1-й уровень
# 21 -> ждать загрузки уровня
# 22 -> подсказка: TAB -> программирование
# 23 -> ждать programming_open
# 24 -> подсветка кнопки "Подсказка" (алгоритм по нажатию)
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
var _hint_panel: Panel

var _highlight: Panel
var _skip_btn: Button

# Затемнение вокруг подсветки (дырка под target)
var dim_alpha: float = 0.55
var _shade: Control
var _shade_top: ColorRect
var _shade_bottom: ColorRect
var _shade_left: ColorRect
var _shade_right: ColorRect

# Стрелка к подсвеченному элементу
var _arrow_enabled: bool = true
var _arrow_line: Line2D
var _arrow_head: Polygon2D

var _target: Control = null
var _target_padding: Vector2 = Vector2(10, 10)

var _last_scene_path: String = ""

# Повтор подсветки (если UI появляется позже, например после ESC)
var _pending_mode: String = ""
var _pending_arg: String = ""

# Для подсказки в программировании
var _hint_revealed: bool = false
const _PROGRAM_HINT := "Алгоритм: [b]3 назад[/b], [b]3 вправо[/b], [b]1 вверх[/b]."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process_input(true)

func start_tutorial() -> void:
	active = true
	step = 0
	_hint_revealed = false
	_last_scene_path = _get_scene_path()
	_show()
	_advance()

func stop_tutorial(go_to_main: bool = true) -> void:
	active = false
	_hide()
	step = 0
	_target = null
	if go_to_main and get_tree():
		get_tree().change_scene_to_file(SCENE_MAIN)

# Вызывается из других скриптов: tut.notify("event", data)
func notify(event_name: String, data: Variant = null) -> void:
	if not active:
		return

	match event_name:
		# Меню выбора (первый вариант)
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
			if step == 7:
				var count: int = int(data)
				if count >= 4:
					_next() # -> 8
				else:
					var left: int = 4 - count
					_set_text("Отлично! Мотор установлен. Осталось поставить [b]%d[/b].\nНажми [b]«Мотор»[/b], выбери вариант и поставь следующий." % left)
					_highlight_node_path("UI/ComponentSelectors/MotorSelector/MotorButton")
					_arrow_enabled = true
		"propellers_count":
			if step == 9:
				var count: int = int(data)
				if count >= 4:
					_next() # -> 10
				else:
					var left: int = 4 - count
					_set_text("Отлично! Пропеллер установлен. Осталось поставить [b]%d[/b].\nНажми [b]«Пропеллер»[/b], выбери вариант и поставь следующий." % left)
					_highlight_node_path("UI/ComponentSelectors/PropellerSelector/PropellerButton")
					_arrow_enabled = true

		"saved":
			if step == 11:
				_next() # -> 12
		"loaded":
			if step == 13:
				# Экспорт происходит автоматически при загрузке: не требуем отдельный шаг "Экспорт".
				step = 16
				_advance()
		"programming_open":
			if step == 23:
				_next() # -> 24
		"hint_pressed":
			# Подсказка на уровне (не двигает шаги)
			if step == 25 and not _hint_revealed:
				_hint_revealed = true
				_set_text(_get_programming_text())
		"level_completed":
			if step == 25:
				_handle_level_completed()
		_:
			pass

func _process(_delta: float) -> void:
	if not active:
		return

	var sp := _get_scene_path()
	if sp != _last_scene_path:
		_last_scene_path = sp
		_on_scene_changed(sp)

	_retry_pending_highlight()
	_update_highlight_position()
	_poll_create_progress()
	_adjust_hint_panel_position()

func _adjust_hint_panel_position() -> void:
	if _hint_panel == null or not is_instance_valid(_hint_panel):
		return
	var sp: String = _get_scene_path()
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var is_level: bool = (sp != "" and sp != SCENE_MAIN and sp != SCENE_CREATE and sp != SCENE_LEVEL_SELECT and sp != SCENE_SHOP)
	var prog_open: bool = false
	if is_level:
		var bp: Node = root.get_node_or_null("UI/BlockProgramming")
		if bp != null and bp is CanvasItem:
			prog_open = (bp as CanvasItem).visible
	if is_level and prog_open:
		# немного сдвигаем текст обучения влево, чтобы он не налезал на блок-программирование
		_hint_panel.anchor_left = 0.35
		_hint_panel.anchor_right = 0.35
	else:
		_hint_panel.anchor_left = 0.5
		_hint_panel.anchor_right = 0.5

func _input(event: InputEvent) -> void:
	if not active:
		return

	# В финале обучения реагируем на ЛЮБОЕ нажатие (даже если UI "съедает" событие)
	if step == 30:
		if event is InputEventMouseButton and event.pressed:
			stop_tutorial(true)
		elif event is InputEventKey and event.pressed:
			stop_tutorial(true)

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

func _handle_level_completed() -> void:
	if not active:
		return

	# На некоторых уровнях игра не возвращает в меню автоматически.
	# Поэтому делаем переход сами.
	_set_text("Уровень пройден! Возвращаемся в главное меню…")
	_clear_highlight()
	_arrow_enabled = false
	step = 26
	if get_tree():
		get_tree().change_scene_to_file(SCENE_MAIN)

func _advance() -> void:
	match step:
		0:
			_set_text("Нажми [b]«Сборка дрона»[/b], чтобы собрать своего первого дрона.")
			_highlight_button_by_text("Сборка")
			_arrow_enabled = true
			step = 1

		2:
			_set_text("Сначала сделаем [b]раму[/b]. Нажми кнопку [b]«Рама»[/b] и выбери вариант.")
			_highlight_node_path("UI/ComponentSelectors/FrameSelector/FrameButton")
			_arrow_enabled = true
			step = 3
			call_deferred("_poll_create_progress")

		4:
			_set_text("Теперь нужна [b]плата[/b]. Нажми [b]«Плата»[/b] и выбери вариант.")
			_highlight_node_path("UI/ComponentSelectors/BoardSelector/BoardButton")
			_arrow_enabled = true
			step = 5
			call_deferred("_poll_create_progress")

		6:
			_set_text("Поставь [b]4 мотора[/b]. Нажимай [b]«Мотор»[/b], выбирай вариант и [b]ставь по одному мотору[/b] (нужно 4).")
			_highlight_node_path("UI/ComponentSelectors/MotorSelector/MotorButton")
			_arrow_enabled = true
			step = 7
			call_deferred("_poll_create_progress")

		8:
			_set_text("Остались [b]пропеллеры[/b]. Нажимай [b]«Пропеллер»[/b] и [b]ставь по одному[/b] (нужно 4).")
			_highlight_node_path("UI/ComponentSelectors/PropellerSelector/PropellerButton")
			_arrow_enabled = true
			step = 9
			call_deferred("_poll_create_progress")

		10:
			_set_text("Нажми [b]ESC[/b], затем [b]«Сохранить»[/b], чтобы сохранить дрона в ячейку.")
			_highlight_button_by_text("Сохран")
			_arrow_enabled = true
			step = 11

		12:
			_set_text("Теперь нажми [b]«Загрузить»[/b]. После загрузки дрон [b]автоматически экспортируется на уровни[/b] — можно сразу идти в выбор уровня.")
			_highlight_button_by_text("Загруз")
			_arrow_enabled = true
			step = 13

		16:
			_set_text("Нажми [b]ESC[/b], затем в меню выдели [b]«В главное меню»[/b] и нажми на неё.")
			_highlight_button_by_text("главн")
			_arrow_enabled = true
			step = 17

		18:
			_set_text("Теперь нажми [b]«Выбор уровня»[/b].")
			_highlight_button_by_text("Выбор")
			_arrow_enabled = true
			step = 19

		20:
			_set_text("Выбери [b]первый уровень[/b].")
			_highlight_first_level_button()
			_arrow_enabled = true
			step = 21

		22:
			_set_text("На уровне нажми [b]TAB[/b], чтобы открыть блок программирования.")
			_clear_highlight()
			_arrow_enabled = false
			step = 23

		24:
			_hint_revealed = false
			_set_text(_get_programming_text())
			_highlight_hint_button()
			_arrow_enabled = true
			step = 25

		27:
			_set_text("Уровень пройден! Заглянем в [b]магазин[/b]. Нажми [b]«Магазин»[/b].")
			_highlight_button_by_text("Магаз")
			_arrow_enabled = true
			step = 28

		29:
			_set_text("В магазине можно покупать новые, улучшенные детали и усиления для дрона.\n\n[b]Поздравляю![/b] Ты прошёл обучение 🎉\nНажми любую кнопку, чтобы вернуться в главное меню.")
			_clear_highlight()
			_arrow_enabled = false
			step = 30

		_:
			pass

func _get_programming_text() -> String:
	var t := "Задай путь до цели (шарика). Добавляй команды в программу.\n"
	t += "Нажми на команду в программе, чтобы указать количество её выполнений.\n\n"
	t += "Если нужна помощь — нажми [b]«Подсказка»[/b]."
	if _hint_revealed:
		t += "\n\n" + _PROGRAM_HINT
	return t

func _next() -> void:
	if not active:
		return
	step += 1
	_advance()

# ================= Синхронизация прогресса (fix багов) =================
func _poll_create_progress() -> void:
	if not active:
		return
	if _get_scene_path() != SCENE_CREATE:
		return

	if step != 3 and step != 5 and step != 7 and step != 9:
		return

	var creator := _get_drone_creator()
	if creator == null:
		return

	# Не перескакиваем, если игрок сейчас тащит компонент
	var dragging := bool(creator.get("is_dragging_component"))
	if dragging:
		return

	match step:
		3:
			var fr: Variant = creator.get("drone_frame")
			if fr is Node and is_instance_valid(fr):
				_next() # -> 4
		5:
			var br: Variant = creator.get("drone_board")
			if br is Node and is_instance_valid(br):
				_next() # -> 6
		7:
			var ms: Variant = creator.get("motors")
			var cnt: int = _count_valid_nodes(ms)
			if cnt >= 4:
				_next() # -> 8
			elif cnt > 0:
				# Фолбэк: иногда notify("motors_count") не долетает (или приходит не в тот кадр).
				# Тогда возвращаем подсветку на кнопку "Мотор" через polling.
				var options_open: bool = _is_ui_visible("UI/ComponentSelectors/MotorSelector/MotorOptionsContainer")
				if not options_open:
					var left: int = 4 - cnt
					_set_text("Отлично! Мотор установлен. Осталось поставить [b]%d[/b].\nНажми [b]«Мотор»[/b], выбери вариант и поставь следующий." % left)
					_highlight_node_path("UI/ComponentSelectors/MotorSelector/MotorButton")
					_arrow_enabled = true
		9:
			var ps: Variant = creator.get("propellers")
			var cnt: int = _count_valid_nodes(ps)
			if cnt >= 4:
				_next() # -> 10
			elif cnt > 0:
				var options_open: bool = _is_ui_visible("UI/ComponentSelectors/PropellerSelector/PropellerOptionsContainer")
				if not options_open:
					var left: int = 4 - cnt
					_set_text("Отлично! Пропеллер установлен. Осталось поставить [b]%d[/b].\nНажми [b]«Пропеллер»[/b], выбери вариант и поставь следующий." % left)
					_highlight_node_path("UI/ComponentSelectors/PropellerSelector/PropellerButton")
					_arrow_enabled = true
		_:
			pass

func _get_drone_creator() -> Node:
	var root: Node = get_tree().current_scene
	if root == null:
		return null

	# Правильно: группа берется через SceneTree (Node не имеет get_nodes_in_group)
	var nodes: Array = get_tree().get_nodes_in_group("drone_creator")
	if nodes.size() > 0:
		var n0: Variant = nodes[0]
		if n0 is Node and is_instance_valid(n0):
			return n0

	# Fallback: ищем узел по имени скрипта create_dron.gd
	var found: Node = _find_node_by_script_file(root, "create_dron.gd")
	return found

func _find_node_by_script_file(root: Node, file_name: String) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s: Script = n.get_script()
		if s != null and s.resource_path.get_file() == file_name:
			return n
		for ch in n.get_children():
			if ch is Node:
				stack.append(ch)
	return null

func _count_valid_nodes(v: Variant) -> int:
	if not (v is Array):
		return 0
	var a: Array = v
	var c: int = 0
	for it in a:
		if it != null and is_instance_valid(it):
			c += 1
	return c

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

	# --- Shade (4 прямоугольника вокруг подсветки) ---
	_shade = Control.new()
	_shade.name = "Shade"
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_shade)

	_shade_top = _make_shade_rect("Top")
	_shade_bottom = _make_shade_rect("Bottom")
	_shade_left = _make_shade_rect("Left")
	_shade_right = _make_shade_rect("Right")
	_shade.add_child(_shade_top)
	_shade.add_child(_shade_bottom)
	_shade.add_child(_shade_left)
	_shade.add_child(_shade_right)
	_shade.visible = false

	# --- Highlight рамка ---
	_highlight = Panel.new()
	_highlight.name = "Highlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 5
	sb.border_width_right = 5
	sb.border_width_top = 5
	sb.border_width_bottom = 5
	sb.border_color = Color(1, 0.85, 0.2, 1)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	_highlight.add_theme_stylebox_override("panel", sb)
	_ui.add_child(_highlight)

	# --- Arrow ---
	_arrow_line = Line2D.new()
	_arrow_line.name = "ArrowLine"
	_arrow_line.width = 6.0
	_arrow_line.default_color = Color(1, 0.85, 0.2, 1)
	_arrow_line.antialiased = true
	_arrow_line.visible = false
	_ui.add_child(_arrow_line)

	_arrow_head = Polygon2D.new()
	_arrow_head.name = "ArrowHead"
	_arrow_head.color = Color(1, 0.85, 0.2, 1)
	_arrow_head.antialiased = true
	_arrow_head.visible = false
	_ui.add_child(_arrow_head)

	# --- Hint panel (текст обучения) ---
	_hint_panel = Panel.new()
	_hint_panel.name = "HintPanel"
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.anchor_top = 0.0
	_hint_panel.anchor_bottom = 0.0
	_hint_panel.offset_left = -460
	_hint_panel.offset_right = 460
	_hint_panel.offset_top = 18
	_hint_panel.offset_bottom = 270
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	psb.corner_radius_top_left = 14
	psb.corner_radius_top_right = 14
	psb.corner_radius_bottom_left = 14
	psb.corner_radius_bottom_right = 14
	_hint_panel.add_theme_stylebox_override("panel", psb)
	_ui.add_child(_hint_panel)

	_label = RichTextLabel.new()
	_label.name = "Hint"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.fit_content = true
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0
	_label.anchor_right = 1
	_label.anchor_top = 0
	_label.anchor_bottom = 1
	_label.offset_left = 18
	_label.offset_right = -18
	_label.offset_top = 14
	_label.offset_bottom = -14
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_font_size_override("bold_font_size", 28)
	_label.add_theme_font_size_override("mono_font_size", 26)
	_hint_panel.add_child(_label)

	_skip_btn = Button.new()
	_skip_btn.name = "Skip"
	_skip_btn.text = "⏭ Завершить обучение"
	_skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# Чтобы не перекрывать команды в BlockProgramming, держим кнопку слева
	_skip_btn.anchor_left = 0.0
	_skip_btn.anchor_right = 0.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_left = 16
	_skip_btn.offset_right = 320
	_skip_btn.offset_top = 16
	_skip_btn.offset_bottom = 60
	_skip_btn.add_theme_font_size_override("font_size", 18)
	_skip_btn.pressed.connect(func():
		stop_tutorial(true)
	)
	_ui.add_child(_skip_btn)

	_ui.hide()

func _make_shade_rect(nm: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = nm
	r.color = Color(0, 0, 0, dim_alpha)
	# Блокируем клики по всему экрану, кроме подсвеченной области ("дырки")
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

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

func _is_ui_visible(rel_path: String) -> bool:
	var root: Node = get_tree().current_scene
	if root == null:
		return false
	var n: Node = root.get_node_or_null(rel_path)
	if n == null:
		return false
	if n is CanvasItem:
		return (n as CanvasItem).visible
	return false

func _retry_pending_highlight() -> void:
	if _pending_mode == "":
		return
	# Если текущая цель валидна и имеет ненулевой размер — ничего не делаем
	if _target != null and is_instance_valid(_target):
		if _target is Control:
			var rr: Rect2 = (_target as Control).get_global_rect()
			if rr.size.x > 4.0 and rr.size.y > 4.0:
				return
		else:
			return

	var root := get_tree().current_scene
	if root == null:
		return

	match _pending_mode:
		"text":
			_target = _find_button_by_text(root, _pending_arg)
		"path":
			var n := root.get_node_or_null(_pending_arg)
			_target = n as Control if n is Control else null
		"hint_button":
			var hn := root.get_node_or_null("UI/BlockProgramming/TutorialHintButton")
			_target = hn as Control if hn is Control else null
		"level1":
			_target = _find_level1_target(root)
		"first_enabled":
			var cont := root.get_node_or_null(_pending_arg)
			if cont == null:
				_target = null
			else:
				for c in cont.get_children():
					if c is Button:
						var bb := c as Button
						if bb.visible and not bb.disabled:
							_target = bb
							return
					elif c is Control:
						var cc := c as Control
						if cc.visible:
							_target = cc
							return
				_target = null
		_:
			pass

# ================= Highlight helpers =================
func _find_button_by_text(root: Node, contains_text: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			var b: Button = n as Button
			if b.text.findn(contains_text) != -1:
				return b
		for c: Node in n.get_children():
			stack.append(c)
	return null


func _get_view_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp != null:
		return vp.get_visible_rect().size
	if get_tree() != null and get_tree().root != null:
		return get_tree().root.get_visible_rect().size
	return Vector2(1920, 1080)

func _is_level1_name(nm: String) -> bool:
	if nm == "1":
		return true
	if nm == "level1" or nm == "level_1" or nm == "level 1":
		return true
	if nm.begins_with("level1") or nm.begins_with("level_1"):
		return true
	if (nm.find("level") != -1 or nm.find("lvl") != -1) and (nm.ends_with("1") or nm.ends_with("_1")):
		# Не путаем с 10-15
		if not (nm.ends_with("10") or nm.ends_with("11") or nm.ends_with("12") or nm.ends_with("13") or nm.ends_with("14") or nm.ends_with("15")):
			return true
	return false

func _is_level1_text(tx: String) -> bool:
	var t: String = tx.strip_edges().to_lower()
	if t == "1":
		return true
	if t == "level 1" or t == "уровень 1":
		return true
	# Не путаем с 10-15
	if t.begins_with("1") and not (t.begins_with("10") or t.begins_with("11") or t.begins_with("12") or t.begins_with("13") or t.begins_with("14") or t.begins_with("15")):
		return true
	return false

func _collect_text_from_control(ctrl: Control) -> String:
	var parts: Array[String] = []
	var stack: Array[Node] = [ctrl]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			parts.append((n as Label).text)
		elif n is RichTextLabel:
			parts.append((n as RichTextLabel).text)
		for ch in n.get_children():
			if ch is Node:
				stack.append(ch)
	return " ".join(parts)

func _pick_best_level_tile(arr: Array[Control]) -> Control:
	# Выбираем плитку: не крошечную, почти квадратную и не на весь экран.
	var vp: Vector2 = _get_view_size()
	var best: Control = arr[0]
	var best_score: float = -1.0

	for c in arr:
		if c == null or not is_instance_valid(c):
			continue
		var r: Rect2 = c.get_global_rect()
		var w: float = r.size.x
		var h: float = r.size.y
		if w < 60.0 or h < 60.0:
			continue
		if w > vp.x * 0.9 or h > vp.y * 0.9:
			continue

		var aspect: float = w / max(1.0, h)
		var aspect_score: float = 1.0 - abs(1.0 - aspect)
		var area_score: float = min(1.0, (w * h) / 40000.0)
		var score: float = aspect_score * 0.7 + area_score * 0.3
		if score > best_score:
			best_score = score
			best = c

	return best

func _ascend_to_level_tile(from_node: Node) -> Control:
	# Поднимаемся вверх от найденного узла (Label/BaseButton/etc.) и
	# выбираем лучший 'квадратный' контейнер плитки уровня.
	# Это нужно, потому что иногда цифра '1' лежит внутри левой части,
	# и подсветка цепляет только половину.
	var cur: Node = from_node
	var best: Control = null
	var best_area: float = 0.0
	var vp: Vector2 = _get_view_size()
	var vp_area: float = vp.x * vp.y
	var steps: int = 0

	while cur != null and steps < 18:
		steps += 1
		if cur is Control:
			var c: Control = cur as Control
			if c.visible and c.is_visible_in_tree() and not c.is_queued_for_deletion():
				var r: Rect2 = c.get_global_rect()
				var w: float = r.size.x
				var h: float = r.size.y
				if w > 1.0 and h > 1.0:
					# Слишком большие контейнеры (фон/весь экран) не берём
					if w * h > vp_area * 0.70:
						break

					# Отсекаем микроноды
					if w >= 80.0 and h >= 80.0 and w <= vp.x * 0.90 and h <= vp.y * 0.90:
						var area: float = w * h
						var aspect: float = w / max(1.0, h)
						# Если контейнер уже очень широкий (полоса/ряд) — выше обычно ещё хуже
						if aspect > 3.2:
							break

						# Плитка уровня почти квадратная
						var square_like: bool = (aspect >= 0.55 and aspect <= 2.10)
						# Предпочитаем квадратные и более крупные
						if square_like and area >= best_area:
							best = c
							best_area = area
						elif best == null and cur is BaseButton and area > best_area:
							# Фолбэк: если квадратного не нашли — хотя бы BaseButton
							best = c
							best_area = area

		cur = cur.get_parent()

	return best

func _find_level1_target(root: Node) -> Control:
	# Ищем именно плитку/кнопку 1-го уровня (BaseButton/TextureButton/Button),
	# не контейнер и не лейбл.
	if root == null:
		return null

	var candidates: Array[Control] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n is BaseButton:
			var bb: BaseButton = n as BaseButton
			var c: Control = bb as Control
			if c.visible and c.is_visible_in_tree() and not c.is_queued_for_deletion():
				var nm: String = bb.name.strip_edges().to_lower()
				var ok: bool = _is_level1_name(nm)

				if not ok and bb is Button:
					var tx: String = (bb as Button).text.strip_edges().to_lower()
					if _is_level1_text(tx):
						ok = true

				if not ok:
					var inner: String = _collect_text_from_control(c).strip_edges().to_lower()
					if _is_level1_text(inner):
						ok = true

				if ok:
					var tile: Control = _ascend_to_level_tile(c)
					if tile != null:
						candidates.append(tile)

		for ch in n.get_children():
			if ch is Node:
				stack.append(ch)

	if candidates.size() > 0:
		return _pick_best_level_tile(candidates)

	# Фолбэк: если цифра '1' внутри Label/RichTextLabel, поднимаемся к плитке
	var via: Control = _find_level1_via_label(root)
	return via


func _pick_smallest_control(arr: Array[Control]) -> Control:
	var best: Control = null
	var best_area: float = 1e18
	for c in arr:
		if c == null or not is_instance_valid(c):
			continue
		var r: Rect2 = c.get_global_rect()
		var a: float = r.size.x * r.size.y
		if a <= 0.0:
			continue
		if a < best_area:
			best_area = a
			best = c
	return best

func _collect_text_from_button(bb: BaseButton) -> String:

	var out: String = ""
	if bb is Button:
		out += (bb as Button).text + " "
	out += (bb as Control).tooltip_text + " "

	var stack: Array[Node] = [bb]
	var safety: int = 0
	while not stack.is_empty() and safety < 128:
		safety += 1
		var n: Node = stack.pop_back()
		if n is Label:
			out += (n as Label).text + " "
		elif n is RichTextLabel:
			out += (n as RichTextLabel).text + " "
		for c: Node in n.get_children():
			stack.append(c)
	return out

func _find_level1_via_label(root: Node) -> Control:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()

		if n is Label:
			var tx: String = (n as Label).text.strip_edges().to_lower()
			if _is_level1_text(tx):
				var tile: Control = _ascend_to_level_tile(n)
				if tile != null:
					return tile

		elif n is RichTextLabel:
			var tx2: String = (n as RichTextLabel).text.strip_edges().to_lower()
			if _is_level1_text(tx2):
				var tile2: Control = _ascend_to_level_tile(n)
				if tile2 != null:
					return tile2

		for c in n.get_children():
			if c is Node:
				stack.append(c)

	return null


func _normalize_level_target(c: Control) -> Control:
	if c == null or not is_instance_valid(c):
		return null

	var r0: Rect2 = c.get_global_rect()
	if r0.size.x < 4.0 or r0.size.y < 4.0:
		# Размер ещё не посчитан (layout не прошёл) — пусть ретраится в _retry_pending_highlight()
		return c

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var vp_area: float = vp.x * vp.y

	var best: Control = c
	var best_area: float = r0.size.x * r0.size.y
	var cur: Control = c

	for _i in range(10):
		var p: Node = cur.get_parent()
		if p == null or not (p is Control):
			break
		var pc: Control = p as Control
		if not pc.visible:
			break

		var rr: Rect2 = pc.get_global_rect()
		var area: float = rr.size.x * rr.size.y
		if area > vp_area * 0.85:
			break
		if area > best_area * 1.15:
			best = pc
			best_area = area
		cur = pc

	return best

func _highlight_button_by_text(contains_text: String) -> void:
	_pending_mode = "text"
	_pending_arg = contains_text
	var root := get_tree().current_scene
	if root == null:
		_clear_highlight()
		return
	var b := _find_button_by_text(root, contains_text)
	_target = b

func _highlight_node_path(rel_path: String) -> void:
	_pending_mode = "path"
	_pending_arg = rel_path
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	var n := root.get_node_or_null(rel_path)
	_target = n as Control if n is Control else null

func _highlight_first_level_button() -> void:
	_pending_mode = "level1"
	_pending_arg = ""
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	_target = _find_level1_target(root)

func _highlight_hint_button() -> void:
	_pending_mode = "hint_button"
	_pending_arg = ""
	var root := get_tree().current_scene
	if root == null:
		_target = null
		return
	var n := root.get_node_or_null("UI/BlockProgramming/TutorialHintButton")
	_target = n as Control if n is Control else null

func _highlight_first_enabled_in_container(rel_path: String) -> void:
	_pending_mode = "first_enabled"
	_pending_arg = rel_path
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
	_pending_mode = ""
	_pending_arg = ""
	if _highlight and is_instance_valid(_highlight):
		_highlight.visible = false
	if _shade and is_instance_valid(_shade):
		_shade.visible = false
	if _arrow_line and is_instance_valid(_arrow_line):
		_arrow_line.visible = false
	if _arrow_head and is_instance_valid(_arrow_head):
		_arrow_head.visible = false

func _update_highlight_position() -> void:
	if not _highlight or not is_instance_valid(_highlight):
		return

	if _target == null or not is_instance_valid(_target):
		_highlight.visible = false
		_shade.visible = false
		_arrow_line.visible = false
		_arrow_head.visible = false
		return

	_highlight.visible = true
	var r: Rect2 = _target.get_global_rect()
	r.position -= _target_padding
	r.size += _target_padding * 2.0
	_highlight.global_position = r.position
	_highlight.size = r.size

	_update_shade(r)
	_update_arrow(r)

func _update_shade(r: Rect2) -> void:
	if not _shade:
		return
	if dim_alpha <= 0.0:
		_shade.visible = false
		return
	_shade.visible = true

	# Явная типизация (у тебя warning'и трактуются как error)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var w: float = vs.x
	var h: float = vs.y
	var x1: float = clampf(r.position.x, 0.0, w)
	var y1: float = clampf(r.position.y, 0.0, h)
	var x2: float = clampf(r.position.x + r.size.x, 0.0, w)
	var y2: float = clampf(r.position.y + r.size.y, 0.0, h)

	_shade_top.position = Vector2(0, 0)
	_shade_top.size = Vector2(w, y1)

	_shade_bottom.position = Vector2(0, y2)
	_shade_bottom.size = Vector2(w, max(0.0, h - y2))

	_shade_left.position = Vector2(0, y1)
	_shade_left.size = Vector2(x1, max(0.0, y2 - y1))

	_shade_right.position = Vector2(x2, y1)
	_shade_right.size = Vector2(max(0.0, w - x2), max(0.0, y2 - y1))

func _update_arrow(r: Rect2) -> void:
	if not _arrow_enabled:
		_arrow_line.visible = false
		_arrow_head.visible = false
		return
	if _hint_panel == null or not is_instance_valid(_hint_panel):
		_arrow_line.visible = false
		_arrow_head.visible = false
		return

	var pr: Rect2 = _hint_panel.get_global_rect()
	var start: Vector2 = pr.position + pr.size * Vector2(0.5, 0.5)
	var end: Vector2 = r.position + r.size * Vector2(0.5, 0.5)

	# Если start почти совпадает с end — прячем
	if start.distance_to(end) < 10.0:
		_arrow_line.visible = false
		_arrow_head.visible = false
		return

	_arrow_line.visible = true
	_arrow_head.visible = true
	_arrow_line.points = PackedVector2Array([start, end])

	var dir := (end - start).normalized()
	var head_len := 24.0
	var head_w := 14.0
	var base := end - dir * head_len
	var perp := Vector2(-dir.y, dir.x)
	var p1 := end
	var p2 := base + perp * head_w
	var p3 := base - perp * head_w
	_arrow_head.polygon = PackedVector2Array([p1, p2, p3])
