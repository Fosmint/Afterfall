class_name HUDController
extends Control

# Игровой HUD для Android (landscape, iQOO Z9 5G): полоски выживания, джойстик, контекстная кнопка, быстрая панель и все окна
var _world_ctrl: WorldController = null

var _hp_bar: ProgressBar
var _hunger_bar: ProgressBar
var _thirst_bar: ProgressBar
var _energy_bar: ProgressBar
var _warmth_bar: ProgressBar
var _time_lbl: Label
var _compass_lbl: Label

var _joystick: VirtualJoystick
var _interact_btn: Button
var _quickbar_box: HBoxContainer
var _gather_box: PanelContainer
var _gather_bar: ProgressBar
var _gather_lbl: Label
var _notif_box: VBoxContainer
var _build_bar: PanelContainer
var _death_panel: PanelContainer
var _death_reason_lbl: Label

var _inv_panel: InventoryPanel
var _craft_panel: CraftingPanel
var _build_panel: BuildingPanel
var _modals: SkillsAndPausePanels

# Мультитач зум (щипок двумя пальцами)
var _touches: Dictionary = {}
var _prev_pinch_dist: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_ctrl = get_parent().get_parent() as WorldController

	_build_hud_layout()
	_build_windows()
	_connect_signals()

	# Первичное обновление быстрой панели и статов
	await get_tree().process_frame
	if _world_ctrl and _world_ctrl.survival:
		_on_stats_changed(_world_ctrl.survival.get_stats_dict())
	_refresh_quickbar()

func _build_hud_layout() -> void:
	# 1. Верхний левый блок: показатели выживания
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.1, 0.12, 0.11, 0.82), UIThemeHelper.COL_BORDER, 8))
	stats_panel.position = Vector2(18, 14)
	stats_panel.custom_minimum_size = Vector2(236, 128)
	add_child(stats_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	stats_panel.add_child(sv)

	_hp_bar = _add_stat_row(sv, "HP", Color(0.82, 0.28, 0.26))
	_hunger_bar = _add_stat_row(sv, "Еда", Color(0.84, 0.56, 0.24))
	_thirst_bar = _add_stat_row(sv, "Вода", Color(0.28, 0.62, 0.86))
	_energy_bar = _add_stat_row(sv, "Сил", Color(0.88, 0.80, 0.32))
	_warmth_bar = _add_stat_row(sv, "Тепл", Color(0.92, 0.45, 0.28))

	# 2. Верхний центр: время, день, погода и ближайшая локация
	var time_panel := PanelContainer.new()
	time_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.1, 0.12, 0.11, 0.82), UIThemeHelper.COL_BORDER, 8))
	time_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	time_panel.anchor_left = 0.5
	time_panel.anchor_right = 0.5
	time_panel.offset_left = -180
	time_panel.offset_right = 180
	time_panel.offset_top = 14
	time_panel.offset_bottom = 78
	add_child(time_panel)

	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	time_panel.add_child(tv)

	_time_lbl = Label.new()
	_time_lbl.text = "День 1 | 08:00 (Утро) | Ясно"
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_lbl.add_theme_font_size_override("font_size", 16)
	_time_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	tv.add_child(_time_lbl)

	_compass_lbl = Label.new()
	_compass_lbl.text = "Исследуйте окрестности"
	_compass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_lbl.add_theme_font_size_override("font_size", 13)
	_compass_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
	tv.add_child(_compass_lbl)

	# 3. Верхний правый угол: Зум и Пауза
	var top_right := HBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -210
	top_right.offset_right = -18
	top_right.offset_top = 14
	top_right.offset_bottom = 66
	top_right.add_theme_constant_override("separation", 8)
	add_child(top_right)

	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.custom_minimum_size = Vector2(52, 48)
	UIThemeHelper.style_button(zoom_out, false, 20)
	zoom_out.pressed.connect(func():
		if _world_ctrl and _world_ctrl.player:
			_world_ctrl.player.adjust_camera_zoom(-0.2)
	)
	top_right.add_child(zoom_out)

	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.custom_minimum_size = Vector2(52, 48)
	UIThemeHelper.style_button(zoom_in, false, 20)
	zoom_in.pressed.connect(func():
		if _world_ctrl and _world_ctrl.player:
			_world_ctrl.player.adjust_camera_zoom(0.2)
	)
	top_right.add_child(zoom_in)

	var pause_btn := Button.new()
	pause_btn.text = "❚❚"
	pause_btn.custom_minimum_size = Vector2(64, 48)
	UIThemeHelper.style_button(pause_btn, false, 18)
	pause_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_close_game_panels()
		_modals.open_pause()
	)
	top_right.add_child(pause_btn)

	# 4. Нижний левый угол: Виртуальный джойстик
	_joystick = VirtualJoystick.new()
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.offset_left = 28
	_joystick.offset_right = 176
	_joystick.offset_top = -176
	_joystick.offset_bottom = -28
	_joystick.input_changed.connect(func(v: Vector2):
		if _world_ctrl and _world_ctrl.player:
			_world_ctrl.player.set_joystick_input(v)
	)
	add_child(_joystick)

	# 5. Нижний центр: Быстрая панель предметов (4 слота)
	_quickbar_box = HBoxContainer.new()
	_quickbar_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_quickbar_box.anchor_left = 0.5
	_quickbar_box.anchor_right = 0.5
	_quickbar_box.offset_left = -152
	_quickbar_box.offset_right = 152
	_quickbar_box.offset_top = -84
	_quickbar_box.offset_bottom = -18
	_quickbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_quickbar_box.add_theme_constant_override("separation", 8)
	add_child(_quickbar_box)

	# 6. Нижний правый угол: Контекстная кнопка взаимодействия + кнопки меню
	var right_col := VBoxContainer.new()
	right_col.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_col.offset_left = -310
	right_col.offset_right = -18
	right_col.offset_top = -168
	right_col.offset_bottom = -18
	right_col.add_theme_constant_override("separation", 10)
	add_child(right_col)

	_interact_btn = Button.new()
	_interact_btn.text = "Нет объектов рядом"
	_interact_btn.custom_minimum_size = Vector2(292, 62)
	_interact_btn.disabled = true
	UIThemeHelper.style_button(_interact_btn, true, 17)
	_interact_btn.pressed.connect(func():
		if _world_ctrl and _world_ctrl.player:
			_world_ctrl.player.trigger_interact()
	)
	right_col.add_child(_interact_btn)

	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 6)
	right_col.add_child(menu_row)

	for spec in [
		["Инв.", func(): _toggle_panel(_inv_panel, func(): _inv_panel.open_inventory())],
		["Крафт", func(): _toggle_panel(_craft_panel, func(): _craft_panel.open_crafting())],
		["Стройка", func(): _toggle_panel(_build_panel, func(): _build_panel.open_building())],
		["Навыки", func():
			_close_game_panels()
			_modals.open_skills()
		]
	]:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(68, 56)
		UIThemeHelper.style_button(b, false, 15)
		b.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			spec[1].call()
		)
		menu_row.add_child(b)

	# 7. Полоса прогресса добычи (по центру снизу над быстрой панелью)
	_gather_box = PanelContainer.new()
	_gather_box.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.1, 0.12, 0.11, 0.9), UIThemeHelper.COL_ACCENT, 8))
	_gather_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_gather_box.anchor_left = 0.5
	_gather_box.anchor_right = 0.5
	_gather_box.offset_left = -150
	_gather_box.offset_right = 150
	_gather_box.offset_top = -156
	_gather_box.offset_bottom = -98
	_gather_box.visible = false
	add_child(_gather_box)

	var gv := VBoxContainer.new()
	_gather_box.add_child(gv)
	_gather_lbl = Label.new()
	_gather_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gather_lbl.add_theme_font_size_override("font_size", 14)
	_gather_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	gv.add_child(_gather_lbl)

	_gather_bar = ProgressBar.new()
	_gather_bar.max_value = 1.0
	_gather_bar.show_percentage = false
	_gather_bar.custom_minimum_size = Vector2(0, 14)
	_gather_bar.add_theme_stylebox_override("background", UIThemeHelper.make_bar_bg())
	_gather_bar.add_theme_stylebox_override("fill", UIThemeHelper.make_bar_style(UIThemeHelper.COL_ACCENT))
	gv.add_child(_gather_bar)

	# 8. Панель подтверждения строительства (видна в режиме строительства)
	_build_bar = PanelContainer.new()
	_build_bar.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.12, 0.16, 0.13, 0.94), UIThemeHelper.COL_ACCENT, 8))
	_build_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_build_bar.anchor_left = 0.5
	_build_bar.anchor_right = 0.5
	_build_bar.offset_left = -210
	_build_bar.offset_right = 210
	_build_bar.offset_top = -158
	_build_bar.offset_bottom = -96
	_build_bar.visible = false
	add_child(_build_bar)

	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 10)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_bar.add_child(bh)

	var ok_b := Button.new()
	ok_b.text = "✓ Поставить"
	ok_b.custom_minimum_size = Vector2(180, 44)
	UIThemeHelper.style_button(ok_b, true, 16)
	ok_b.pressed.connect(func():
		if _world_ctrl:
			_world_ctrl.building_system.confirm_placement()
	)
	bh.add_child(ok_b)

	var cancel_b := Button.new()
	cancel_b.text = "✕ Отмена"
	cancel_b.custom_minimum_size = Vector2(140, 44)
	UIThemeHelper.style_button(cancel_b, false, 16)
	cancel_b.pressed.connect(func():
		if _world_ctrl:
			_world_ctrl.building_system.cancel_build_mode()
	)
	bh.add_child(cancel_b)

	# 9. Стек уведомлений
	_notif_box = VBoxContainer.new()
	_notif_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_notif_box.anchor_left = 0.5
	_notif_box.anchor_right = 0.5
	_notif_box.offset_left = -260
	_notif_box.offset_right = 260
	_notif_box.offset_top = 86
	_notif_box.offset_bottom = 220
	_notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notif_box)

func _build_windows() -> void:
	_inv_panel = InventoryPanel.new()
	_inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inv_panel.offset_left = -430
	_inv_panel.offset_right = 430
	_inv_panel.offset_top = -255
	_inv_panel.offset_bottom = 255
	add_child(_inv_panel)
	_inv_panel.setup(_world_ctrl)

	_craft_panel = CraftingPanel.new()
	_craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	_craft_panel.offset_left = -380
	_craft_panel.offset_right = 380
	_craft_panel.offset_top = -250
	_craft_panel.offset_bottom = 250
	add_child(_craft_panel)
	_craft_panel.setup(_world_ctrl)

	_build_panel = BuildingPanel.new()
	_build_panel.set_anchors_preset(Control.PRESET_CENTER)
	_build_panel.offset_left = -380
	_build_panel.offset_right = 380
	_build_panel.offset_top = -250
	_build_panel.offset_bottom = 250
	add_child(_build_panel)
	_build_panel.setup(_world_ctrl)

	_modals = SkillsAndPausePanels.new()
	add_child(_modals)
	_modals.setup(_world_ctrl)

	# Окно гибели персонажа
	_death_panel = PanelContainer.new()
	_death_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.14, 0.08, 0.08, 0.96), Color(0.85, 0.32, 0.28, 1.0), 12))
	_death_panel.set_anchors_preset(Control.PRESET_CENTER)
	_death_panel.offset_left = -240
	_death_panel.offset_right = 240
	_death_panel.offset_top = -130
	_death_panel.offset_bottom = 130
	_death_panel.visible = false
	add_child(_death_panel)

	var dv := VBoxContainer.new()
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_theme_constant_override("separation", 12)
	_death_panel.add_child(dv)

	var dt := Label.new()
	dt.text = "ВЫ ПОГИБЛИ"
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dt.add_theme_font_size_override("font_size", 26)
	dt.add_theme_color_override("font_color", Color(0.95, 0.42, 0.38))
	dv.add_child(dt)

	_death_reason_lbl = Label.new()
	_death_reason_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_reason_lbl.add_theme_font_size_override("font_size", 16)
	_death_reason_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	dv.add_child(_death_reason_lbl)

	var restart_b := Button.new()
	restart_b.text = "Начать заново"
	restart_b.custom_minimum_size = Vector2(0, 48)
	UIThemeHelper.style_button(restart_b, true, 18)
	restart_b.pressed.connect(func(): GameManager.start_new_game())
	dv.add_child(restart_b)

	var menu_b := Button.new()
	menu_b.text = "В главное меню"
	menu_b.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.style_button(menu_b, false, 16)
	menu_b.pressed.connect(func(): GameManager.return_to_main_menu())
	dv.add_child(menu_b)

func _add_stat_row(parent: VBoxContainer, label_text: String, bar_col: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(42, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	row.add_child(lbl)

	var pb := ProgressBar.new()
	pb.max_value = 100.0
	pb.value = 100.0
	pb.show_percentage = false
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size = Vector2(0, 14)
	pb.add_theme_stylebox_override("background", UIThemeHelper.make_bar_bg())
	pb.add_theme_stylebox_override("fill", UIThemeHelper.make_bar_style(bar_col))
	row.add_child(pb)
	return pb

func _connect_signals() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	EventBus.time_updated.connect(_on_time_updated)
	EventBus.interactable_changed.connect(_on_interactable_changed)
	EventBus.gather_progress.connect(_on_gather_progress)
	EventBus.notification_requested.connect(_show_notification)
	EventBus.inventory_changed.connect(_refresh_quickbar)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.storage_opened.connect(func(b: Node):
		_close_game_panels()
		_inv_panel.open_with_storage(b as BuildingObject)
	)
	EventBus.open_crafting_station.connect(func(_st: String):
		_close_game_panels()
		_craft_panel.open_crafting()
	)
	EventBus.player_died.connect(func(reason: String):
		_close_game_panels()
		_death_reason_lbl.text = "Причина: %s" % reason
		_death_panel.visible = true
	)

func _on_stats_changed(stats: Dictionary) -> void:
	_hp_bar.max_value = float(stats.get("max_health", 100.0))
	_hp_bar.value = float(stats.get("health", 100.0))
	_hunger_bar.value = float(stats.get("hunger", 100.0))
	_thirst_bar.value = float(stats.get("thirst", 100.0))
	_energy_bar.max_value = float(stats.get("max_energy", 100.0))
	_energy_bar.value = float(stats.get("energy", 100.0))
	_warmth_bar.value = float(stats.get("warmth", 100.0))

func _on_time_updated(_day: int, _hour: float, _phase: String) -> void:
	if _world_ctrl == null or _world_ctrl.time_weather == null:
		return
	var tw := _world_ctrl.time_weather
	_time_lbl.text = "День %d  |  %s (%s)  |  %s" % [tw.day, tw.get_formatted_time(), tw.get_phase_label(), tw.get_weather_label()]
	_update_compass()

func _update_compass() -> void:
	if _world_ctrl == null or _world_ctrl.player == null:
		return
	var p_tile := IsoMath.world_to_tile(_world_ctrl.player.position)
	var nearest_name := ""
	var nearest_dist := 9999.0
	for poi in _world_ctrl.generator.pois:
		var pt: Vector2i = poi["tile"]
		var d := p_tile.distance_to(pt)
		if d < nearest_dist:
			nearest_dist = d
			nearest_name = str(poi["name"]) if bool(poi["discovered"]) else "Неизвестный объект"
	if not nearest_name.is_empty():
		_compass_lbl.text = "Рядом: %s (%d м)" % [nearest_name, int(nearest_dist * 3.0)]

func _on_interactable_changed(target: Node, label_text: String) -> void:
	if _world_ctrl and _world_ctrl.building_system.active:
		return
	if target == null:
		_interact_btn.text = "Нет объектов рядом"
		_interact_btn.disabled = true
	else:
		_interact_btn.text = label_text
		_interact_btn.disabled = false

func _on_gather_progress(active: bool, progress: float, label_text: String) -> void:
	_gather_box.visible = active
	_gather_bar.value = progress
	_gather_lbl.text = label_text

func _on_build_mode_changed(active: bool, building_id: String) -> void:
	_build_bar.visible = active
	if active:
		var b_name := str(DataManager.get_building(building_id).get("name", building_id))
		_interact_btn.text = "Поставить: %s" % b_name
		_interact_btn.disabled = false
		_show_notification("Режим строительства: коснитесь экрана или подойдите, чтобы выбрать место.", Color(0.7, 0.92, 0.72))
	else:
		_interact_btn.text = "Нет объектов рядом"
		_interact_btn.disabled = true

func _refresh_quickbar() -> void:
	if _world_ctrl == null or _world_ctrl.inventory == null:
		return
	for c in _quickbar_box.get_children():
		c.queue_free()
	var inv := _world_ctrl.inventory
	for item_id in inv.quickbar_ids:
		var cnt := inv.get_item_count(item_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(66, 62)
		UIThemeHelper.style_button(btn, false, 13)
		btn.disabled = cnt <= 0
		var tex := DataManager.get_item_icon(item_id)
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
		var lbl := Label.new()
		lbl.text = str(cnt)
		lbl.position = Vector2(44, 42)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color.WHITE if cnt > 0 else Color(0.5, 0.5, 0.5))
		btn.add_child(lbl)
		var id_copy := item_id
		btn.pressed.connect(func():
			inv.use_item_by_id(id_copy, _world_ctrl.survival)
		)
		_quickbar_box.add_child(btn)

func _show_notification(msg: String, col: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.08, 0.1, 0.09, 0.88), col, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(lbl)
	_notif_box.add_child(panel)

	# Ограничиваем число одновременных уведомлений
	while _notif_box.get_child_count() > 3:
		_notif_box.get_child(0).queue_free()

	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

func _toggle_panel(panel: Control, opener: Callable) -> void:
	var was_open := panel.visible
	_close_game_panels()
	if not was_open:
		opener.call()

func _close_game_panels() -> void:
	_inv_panel.visible = false
	_craft_panel.visible = false
	_build_panel.visible = false
	_modals.close_all()

func _unhandled_input(event: InputEvent) -> void:
	if _world_ctrl == null or _world_ctrl.player == null:
		return

	# Мультитач зум двумя пальцами + касание для наведения постройки
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1 and _world_ctrl.building_system.active:
				var world_pos := _world_ctrl.get_global_mouse_position()
				_world_ctrl.building_system.set_target_world_pos(world_pos)
		else:
			_touches.erase(ev.index)
			_prev_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		var ev := event as InputEventScreenDrag
		_touches[ev.index] = ev.position
		if _touches.size() == 2:
			var keys := _touches.keys()
			var dist := (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)
			if _prev_pinch_dist > 0.0:
				var delta_z := (dist - _prev_pinch_dist) * 0.003
				_world_ctrl.player.adjust_camera_zoom(delta_z)
			_prev_pinch_dist = dist
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_world_ctrl.player.adjust_camera_zoom(0.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_world_ctrl.player.adjust_camera_zoom(-0.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _world_ctrl.building_system.active:
			_world_ctrl.building_system.set_target_world_pos(_world_ctrl.get_global_mouse_position())
