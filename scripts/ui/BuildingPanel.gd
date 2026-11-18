class_name BuildingPanel
extends PanelContainer

# Панель выбора построек убежища для перехода в режим размещения
var _world_ctrl: Node = null
var _list_box: VBoxContainer

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	_build_ui()
	EventBus.inventory_changed.connect(refresh)
	visible = false

func open_building() -> void:
	visible = true
	refresh()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "СТРОИТЕЛЬСТВО УБЕЖИЩА"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(46, 42)
	UIThemeHelper.style_button(close_btn, false, 18)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		visible = false
	)
	top.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)

func refresh() -> void:
	if not visible or _world_ctrl == null:
		return
	for c in _list_box.get_children():
		c.queue_free()

	for b_id in DataManager.buildings.keys():
		var def: Dictionary = DataManager.buildings[b_id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(UIThemeHelper.COL_CARD, UIThemeHelper.COL_BORDER, 8))
		_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var icon := TextureRect.new()
		icon.texture = DataManager.get_texture(str(def.get("sprite", "")))
		icon.custom_minimum_size = Vector2(52, 52)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = str(def.get("name", b_id))
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(def.get("description", ""))
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.add_child(desc_lbl)

		var cost: Dictionary = def.get("cost", {})
		var cost_parts: PackedStringArray = []
		for mat_id in cost.keys():
			var need := int(cost[mat_id])
			var have := _world_ctrl.inventory.get_item_count(str(mat_id))
			cost_parts.append("%s: %d/%d" % [DataManager.get_item_name(str(mat_id)), have, need])

		var has_kit := (b_id == "campfire" and _world_ctrl.inventory.get_item_count("campfire_kit") > 0) or (b_id == "storage_chest" and _world_ctrl.inventory.get_item_count("wooden_crate") > 0)
		var can := has_kit or _world_ctrl.inventory.has_items(cost)

		var cost_lbl := Label.new()
		cost_lbl.text = ("Готовый набор в инвентаре!" if has_kit else "Нужно: " + "  |  ".join(cost_parts))
		cost_lbl.add_theme_font_size_override("font_size", 14)
		cost_lbl.add_theme_color_override("font_color", Color(0.68, 0.9, 0.68) if can else Color(0.86, 0.58, 0.52))
		info.add_child(cost_lbl)

		var place_btn := Button.new()
		place_btn.text = "Построить"
		place_btn.custom_minimum_size = Vector2(120, 46)
		place_btn.disabled = not can
		UIThemeHelper.style_button(place_btn, can, 16)
		var target_id: String = str(b_id)
		place_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			visible = false
			EventBus.build_mode_changed.emit(true, target_id)
		)
		row.add_child(place_btn)
