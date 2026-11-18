class_name SkillsAndPausePanels
extends Control

# Объединённый контроллер модальных окон: Навыки/Локации, Пауза и Настройки (оптимизация iQOO Z9 5G)
var _world_ctrl: Node = null
var skills_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer

var _skills_list: VBoxContainer
var _poi_list: VBoxContainer
var _quality_lbl: Label
var _fps_lbl: Label

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_skills_panel()
	_build_pause_panel()
	_build_settings_panel()

func open_skills() -> void:
	close_all()
	_refresh_skills()
	skills_panel.visible = true

func open_pause() -> void:
	close_all()
	get_tree().paused = true
	pause_panel.visible = true

func open_settings() -> void:
	close_all()
	_refresh_settings_labels()
	settings_panel.visible = true

func close_all() -> void:
	skills_panel.visible = false
	pause_panel.visible = false
	settings_panel.visible = false
	get_tree().paused = false

func _build_skills_panel() -> void:
	skills_panel = PanelContainer.new()
	skills_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	skills_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	skills_panel.set_anchors_preset(Control.PRESET_CENTER)
	skills_panel.custom_minimum_size = Vector2(680, 440)
	skills_panel.offset_left = -340
	skills_panel.offset_right = 340
	skills_panel.offset_top = -220
	skills_panel.offset_bottom = 220
	skills_panel.visible = false
	add_child(skills_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	skills_panel.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "НАВЫКИ И ИССЛЕДОВАНИЕ"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var close_b := Button.new()
	close_b.text = "✕"
	close_b.custom_minimum_size = Vector2(44, 40)
	UIThemeHelper.style_button(close_b, false, 18)
	close_b.pressed.connect(close_all)
	top.add_child(close_b)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	v.add_child(split)

	_skills_list = VBoxContainer.new()
	_skills_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_list.add_theme_constant_override("separation", 8)
	split.add_child(_skills_list)

	_poi_list = VBoxContainer.new()
	_poi_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_poi_list.add_theme_constant_override("separation", 6)
	split.add_child(_poi_list)

func _refresh_skills() -> void:
	if _world_ctrl == null:
		return
	for c in _skills_list.get_children():
		c.queue_free()
	for c in _poi_list.get_children():
		c.queue_free()

	var h1 := Label.new()
	h1.text = "Навыки выжившего"
	h1.add_theme_font_size_override("font_size", 17)
	h1.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_skills_list.add_child(h1)

	for sk_id in _world_ctrl.survival.skills.keys():
		var sk: Dictionary = _world_ctrl.survival.skills[sk_id]
		var lbl := Label.new()
		lbl.text = "%s — Ур. %d (%d/%d XP)" % [sk["name"], int(sk["level"]), int(sk["xp"]), int(sk["next_xp"])]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
		_skills_list.add_child(lbl)

		var pb := ProgressBar.new()
		pb.max_value = float(sk["next_xp"])
		pb.value = float(sk["xp"])
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 12)
		pb.add_theme_stylebox_override("background", UIThemeHelper.make_bar_bg())
		pb.add_theme_stylebox_override("fill", UIThemeHelper.make_bar_style(UIThemeHelper.COL_ACCENT))
		_skills_list.add_child(pb)

	var h2 := Label.new()
	h2.text = "Локации мира (Seed: %d)" % _world_ctrl.generator.seed_val
	h2.add_theme_font_size_override("font_size", 17)
	h2.add_theme_color_override("font_color", Color(0.7, 0.88, 0.95))
	_poi_list.add_child(h2)

	for poi in _world_ctrl.generator.pois:
		var lbl := Label.new()
		var disc := bool(poi["discovered"])
		lbl.text = ("✓ " + str(poi["name"])) if disc else "• ??? (не исследовано)"
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.92, 0.65) if disc else UIThemeHelper.COL_MUTED)
		_poi_list.add_child(lbl)

func _build_pause_panel() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -200
	pause_panel.offset_right = 200
	pause_panel.offset_top = -170
	pause_panel.offset_bottom = 170
	pause_panel.visible = false
	add_child(pause_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	v.add_child(title)

	for spec in [
		["Продолжить", true, func(): close_all()],
		["Сохранить игру", false, func():
			if _world_ctrl:
				_world_ctrl.save_world(true)
				EventBus.notification_requested.emit("Игра сохранена!", Color(0.62, 0.92, 0.65))
			close_all()
		],
		["Настройки (iQOO Z9)", false, func(): open_settings()],
		["Главное меню", false, func():
			if _world_ctrl:
				_world_ctrl.save_world(false)
			GameManager.return_to_main_menu()
		]
	]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 50)
		UIThemeHelper.style_button(b, spec[1], 18)
		b.pressed.connect(spec[2])
		v.add_child(b)

func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -280
	settings_panel.offset_right = 280
	settings_panel.offset_top = -210
	settings_panel.offset_bottom = 210
	settings_panel.visible = false
	add_child(settings_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	settings_panel.add_child(v)

	var title := Label.new()
	title.text = "НАСТРОЙКИ И ОПТИМИЗАЦИЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	v.add_child(title)

	_quality_lbl = Label.new()
	_quality_lbl.add_theme_font_size_override("font_size", 15)
	_quality_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	v.add_child(_quality_lbl)

	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 6)
	v.add_child(q_row)
	for pair in [["low", "Низкое"], ["medium", "Среднее"], ["high", "Высокое (Z9)"], ["ultra", "Ультра 90Hz"]]:
		var b := Button.new()
		b.text = pair[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 42)
		UIThemeHelper.style_button(b, pair[0] == "high", 14)
		var p_id: String = pair[0]
		b.pressed.connect(func():
			GameManager.apply_quality_preset(p_id)
			_refresh_settings_labels()
		)
		q_row.add_child(b)

	_fps_lbl = Label.new()
	_fps_lbl.add_theme_font_size_override("font_size", 15)
	_fps_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	v.add_child(_fps_lbl)

	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 6)
	v.add_child(fps_row)
	for fps_val in [30, 60, 90, 120]:
		var b := Button.new()
		b.text = "%d FPS" % fps_val
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 42)
		UIThemeHelper.style_button(b, false, 15)
		var fv: int = fps_val
		b.pressed.connect(func():
			GameManager.settings["target_fps"] = fv
			GameManager.apply_settings()
			GameManager.save_settings()
			_refresh_settings_labels()
		)
		fps_row.add_child(b)

	var sound_btn := Button.new()
	sound_btn.text = "Звук: Вкл / Выкл"
	sound_btn.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.style_button(sound_btn, false, 16)
	sound_btn.pressed.connect(func():
		GameManager.settings["muted"] = not bool(GameManager.settings.get("muted", false))
		GameManager.apply_settings()
		GameManager.save_settings()
		_refresh_settings_labels()
	)
	v.add_child(sound_btn)

	var vib_btn := Button.new()
	vib_btn.text = "Вибрация: Вкл / Выкл"
	vib_btn.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.style_button(vib_btn, false, 16)
	vib_btn.pressed.connect(func():
		GameManager.settings["vibration"] = not bool(GameManager.settings.get("vibration", true))
		GameManager.save_settings()
		_refresh_settings_labels()
	)
	v.add_child(vib_btn)

	var back_btn := Button.new()
	back_btn.text = "Готово"
	back_btn.custom_minimum_size = Vector2(0, 46)
	UIThemeHelper.style_button(back_btn, true, 17)
	back_btn.pressed.connect(close_all)
	v.add_child(back_btn)

func _refresh_settings_labels() -> void:
	var s := GameManager.settings
	_quality_lbl.text = "Качество: %s | Чанки: %d | Свет: %s" % [
		str(s.get("quality_preset", "high")).to_upper(),
		int(s.get("chunk_view_radius", 2)),
		"Да" if bool(s.get("dynamic_lights", true)) else "Нет"
	]
	_fps_lbl.text = "Лимит FPS: %d | Звук: %s | Вибрация: %s" % [
		int(s.get("target_fps", 60)),
		"Выкл" if bool(s.get("muted", false)) else "Вкл",
		"Вкл" if bool(s.get("vibration", true)) else "Выкл"
	]
