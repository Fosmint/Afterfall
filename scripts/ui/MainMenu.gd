extends Control

# Главное меню Afterfall: Последний выживший
var _continue_btn: Button
var _seed_input: LineEdit
var _save_info_lbl: Label
var _settings_overlay: SkillsAndPausePanels

func _ready() -> void:
	_build_menu()
	_refresh_save_state()

func _build_menu() -> void:
	# Атмосферный фон
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Декоративные спрайты на фоне
	for spec in [
		["res://assets/sprites/objects/house_ruin.png", Vector2(180, 390), Vector2(3.0, 3.0)],
		["res://assets/sprites/objects/tree_pine.png", Vector2(1050, 360), Vector2(3.2, 3.2)],
		["res://assets/sprites/buildings/campfire_lit.png", Vector2(280, 520), Vector2(3.0, 3.0)]
	]:
		var sp := TextureRect.new()
		sp.texture = DataManager.get_texture(spec[0])
		sp.position = spec[1]
		sp.scale = spec[2]
		sp.modulate = Color(0.55, 0.6, 0.56, 0.42)
		add_child(sp)

	# Центральная карточка меню
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(Color(0.11, 0.13, 0.12, 0.94), UIThemeHelper.COL_ACCENT, 14))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = -245
	card.offset_bottom = 245
	add_child(card)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var title := Label.new()
	title.text = "AFTERFALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	v.add_child(title)

	var sub := Label.new()
	sub.text = "ПОСЛЕДНИЙ ВЫЖИВШИЙ"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
	v.add_child(sub)

	_save_info_lbl = Label.new()
	_save_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_info_lbl.add_theme_font_size_override("font_size", 14)
	_save_info_lbl.add_theme_color_override("font_color", Color(0.68, 0.88, 0.72))
	v.add_child(_save_info_lbl)

	_continue_btn = Button.new()
	_continue_btn.text = "Продолжить выживание"
	_continue_btn.custom_minimum_size = Vector2(0, 54)
	UIThemeHelper.style_button(_continue_btn, true, 19)
	_continue_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.continue_saved_game()
	)
	v.add_child(_continue_btn)

	var new_btn := Button.new()
	new_btn.text = "Новая игра"
	new_btn.custom_minimum_size = Vector2(0, 52)
	UIThemeHelper.style_button(new_btn, false, 18)
	new_btn.pressed.connect(_on_new_game_pressed)
	v.add_child(new_btn)

	# Поле необязательного Seed мира
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	v.add_child(seed_row)
	var slbl := Label.new()
	slbl.text = "Seed мира:"
	slbl.add_theme_font_size_override("font_size", 15)
	slbl.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
	seed_row.add_child(slbl)

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Случайный (оставьте пустым)"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.custom_minimum_size = Vector2(0, 38)
	seed_row.add_child(_seed_input)

	var set_btn := Button.new()
	set_btn.text = "Настройки (iQOO Z9 5G)"
	set_btn.custom_minimum_size = Vector2(0, 48)
	UIThemeHelper.style_button(set_btn, false, 17)
	set_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_settings_overlay.open_settings()
	)
	v.add_child(set_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Выход"
	exit_btn.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.style_button(exit_btn, false, 16)
	exit_btn.pressed.connect(func(): get_tree().quit())
	v.add_child(exit_btn)

	var ver := Label.new()
	ver.text = "Android Edition • Godot 4.3 • Оптимизировано для Snapdragon 7 Gen 3"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.5, 0.54, 0.5))
	v.add_child(ver)

	_settings_overlay = SkillsAndPausePanels.new()
	add_child(_settings_overlay)
	_settings_overlay.setup(null)

func _refresh_save_state() -> void:
	var summary := SaveManager.get_save_summary()
	if summary.is_empty():
		_continue_btn.disabled = true
		_save_info_lbl.text = "Нет сохранённой игры"
	else:
		_continue_btn.disabled = false
		_save_info_lbl.text = "Сохранение: День %d | Seed: %d" % [int(summary["day"]), int(summary["world_seed"])]

func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	var txt := _seed_input.text.strip_edges()
	var custom_seed := -1
	if not txt.is_empty():
		custom_seed = int(txt.to_int()) if txt.is_valid_int() else abs(txt.hash())
	GameManager.start_new_game(custom_seed)
