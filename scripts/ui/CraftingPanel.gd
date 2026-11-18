class_name CraftingPanel
extends PanelContainer

# Окно крафта: список рецептов, проверка станций (костёр / верстак), материалы и кнопка создания
var _world_ctrl: Node = null
var _list_box: VBoxContainer
var _station_lbl: Label

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	_build_ui()
	EventBus.inventory_changed.connect(refresh)
	visible = false

func open_crafting() -> void:
	visible = true
	refresh()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)

	var title := Label.new()
	title.text = "КРАФТ И РЕМЕСЛО"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	_station_lbl = Label.new()
	_station_lbl.add_theme_font_size_override("font_size", 14)
	_station_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.72))
	top.add_child(_station_lbl)

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
	var stations: Array[String] = _world_ctrl.crafting.nearby_stations
	var st_names: PackedStringArray = ["Ручной крафт"]
	if stations.has("campfire"):
		st_names.append("Костёр")
	if stations.has("workbench"):
		st_names.append("Верстак")
	_station_lbl.text = "Доступно: %s  " % ", ".join(st_names)

	for c in _list_box.get_children():
		c.queue_free()

	for recipe in DataManager.recipes:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(UIThemeHelper.COL_CARD, UIThemeHelper.COL_BORDER, 8))
		_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var res_id := str(recipe["result"])
		var icon := TextureRect.new()
		icon.texture = DataManager.get_item_icon(res_id)
		icon.custom_minimum_size = Vector2(44, 44)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var station := str(recipe.get("station", "none"))
		var st_tag := ""
		if station == "campfire":
			st_tag = " [Костёр]"
		elif station == "workbench":
			st_tag = " [Верстак]"

		var name_lbl := Label.new()
		name_lbl.text = "%s ×%d%s" % [DataManager.get_item_name(res_id), int(recipe.get("amount", 1)), st_tag]
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
		info.add_child(name_lbl)

		var ing_parts: PackedStringArray = []
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for mat_id in ingredients.keys():
			var need := int(ingredients[mat_id])
			var have: int = _world_ctrl.inventory.get_item_count(str(mat_id))
			ing_parts.append("%s: %d/%d" % [DataManager.get_item_name(str(mat_id)), have, need])

		var mat_lbl := Label.new()
		mat_lbl.text = "Материалы: " + "  |  ".join(ing_parts)
		mat_lbl.add_theme_font_size_override("font_size", 14)
		var can: bool = _world_ctrl.crafting.can_craft(recipe)
		mat_lbl.add_theme_color_override("font_color", Color(0.68, 0.9, 0.68) if can else Color(0.86, 0.58, 0.52))
		mat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.add_child(mat_lbl)

		var craft_btn := Button.new()
		craft_btn.text = "Создать"
		craft_btn.custom_minimum_size = Vector2(118, 46)
		craft_btn.disabled = not can
		UIThemeHelper.style_button(craft_btn, can, 16)
		var r_id := str(recipe["id"])
		craft_btn.pressed.connect(func():
			_world_ctrl.crafting.craft(r_id)
			refresh()
		)
		row.add_child(craft_btn)
