class_name InventoryPanel
extends PanelContainer

# Окно инвентаря (категории, детали, использование, выброс) + режим хранилища
var _world_ctrl: Node = null
var _active_storage: BuildingObject = null
var _selected_slot: int = -1
var _category_filter: String = "all"

var _title_lbl: Label
var _grid: GridContainer
var _storage_box: VBoxContainer
var _storage_grid: GridContainer
var _detail_name: Label
var _detail_desc: Label
var _use_btn: Button
var _drop_btn: Button
var _transfer_btn: Button
var _equip_lbl: Label

func setup(world_ctrl: Node) -> void:
	_world_ctrl = world_ctrl
	add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style())
	_build_ui()
	EventBus.inventory_changed.connect(refresh)
	EventBus.equipment_changed.connect(refresh)
	visible = false

func open_inventory() -> void:
	_active_storage = null
	_selected_slot = -1
	visible = true
	refresh()

func open_with_storage(storage_building: BuildingObject) -> void:
	_active_storage = storage_building
	_selected_slot = -1
	visible = true
	refresh()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Заголовок + кнопка закрытия
	var top := HBoxContainer.new()
	root.add_child(top)
	_title_lbl = Label.new()
	_title_lbl.text = "ИНВЕНТАРЬ"
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title_lbl)

	_equip_lbl = Label.new()
	_equip_lbl.add_theme_font_size_override("font_size", 15)
	_equip_lbl.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	top.add_child(_equip_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(46, 42)
	UIThemeHelper.style_button(close_btn, false, 18)
	close_btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		visible = false
	)
	top.add_child(close_btn)

	# Фильтр категорий
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	for pair in [["all", "Все"], ["resource", "Ресурсы"], ["food", "Еда"], ["tool", "Инструменты"], ["medicine", "Медицина"]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(96, 36)
		UIThemeHelper.style_button(b, false, 14)
		var cat_id: String = pair[0]
		b.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			_category_filter = cat_id
			_selected_slot = -1
			refresh()
		)
		tabs.add_child(b)

	# Основная область: сетка игрока + (опционально хранилище) + панель деталей
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	# Панель хранилища (видна только при открытии сундука)
	_storage_box = VBoxContainer.new()
	_storage_box.custom_minimum_size = Vector2(280, 0)
	_storage_box.visible = false
	body.add_child(_storage_box)
	var st_lbl := Label.new()
	st_lbl.text = "ХРАНИЛИЩЕ (нажмите, чтобы забрать)"
	st_lbl.add_theme_font_size_override("font_size", 14)
	st_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.45))
	_storage_box.add_child(st_lbl)
	_storage_grid = GridContainer.new()
	_storage_grid.columns = 4
	_storage_grid.add_theme_constant_override("h_separation", 6)
	_storage_grid.add_theme_constant_override("v_separation", 6)
	_storage_box.add_child(_storage_grid)

	# Правая карточка описания выбранного предмета
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(240, 0)
	detail_panel.add_theme_stylebox_override("panel", UIThemeHelper.make_panel_style(UIThemeHelper.COL_CARD))
	body.add_child(detail_panel)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail_panel.add_child(dv)

	_detail_name = Label.new()
	_detail_name.text = "Выберите предмет"
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_name.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	dv.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.text = "Нажмите на ячейку, чтобы увидеть характеристики и действия."
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_detail_desc)

	_use_btn = Button.new()
	_use_btn.text = "Использовать"
	_use_btn.custom_minimum_size = Vector2(0, 44)
	UIThemeHelper.style_button(_use_btn, true, 16)
	_use_btn.pressed.connect(_on_use_pressed)
	dv.add_child(_use_btn)

	_transfer_btn = Button.new()
	_transfer_btn.text = "Положить в хранилище"
	_transfer_btn.custom_minimum_size = Vector2(0, 42)
	UIThemeHelper.style_button(_transfer_btn, false, 15)
	_transfer_btn.pressed.connect(_on_transfer_to_storage)
	dv.add_child(_transfer_btn)

	_drop_btn = Button.new()
	_drop_btn.text = "Выбросить (1 шт.)"
	_drop_btn.custom_minimum_size = Vector2(0, 40)
	UIThemeHelper.style_button(_drop_btn, false, 15)
	_drop_btn.pressed.connect(_on_drop_pressed)
	dv.add_child(_drop_btn)

func refresh() -> void:
	if not visible or _world_ctrl == null:
		return
	var inv: InventorySystem = _world_ctrl.inventory
	_title_lbl.text = "ИНВЕНТАРЬ (%d слотов)" % inv.max_slots
	if inv.equipped_tool_id.is_empty():
		_equip_lbl.text = "Инструмент: нет  "
	else:
		_equip_lbl.text = "В руках: %s (%d)  " % [DataManager.get_item_name(inv.equipped_tool_id), inv.equipped_tool_durability]

	for c in _grid.get_children():
		c.queue_free()

	for i in range(inv.slots.size()):
		var entry = inv.slots[i]
		if _category_filter != "all":
			if entry == null:
				continue
			var def := DataManager.get_item(str(entry["id"]))
			if str(def.get("category", "")) != _category_filter:
				continue
		var btn := _create_slot_button(entry, i == _selected_slot)
		var slot_idx := i
		btn.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			_selected_slot = slot_idx
			refresh()
		)
		_grid.add_child(btn)

	# Хранилище
	_storage_box.visible = _active_storage != null and is_instance_valid(_active_storage)
	if _storage_box.visible:
		for c in _storage_grid.get_children():
			c.queue_free()
		for i in range(_active_storage.storage_slots.size()):
			var entry = _active_storage.storage_slots[i]
			var btn := _create_slot_button(entry, false)
			var st_idx := i
			btn.pressed.connect(func(): _on_take_from_storage(st_idx))
			_storage_grid.add_child(btn)

	_refresh_details()

func _create_slot_button(entry, selected: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(68, 68)
	var bg := Color(0.24, 0.30, 0.24, 0.95) if selected else Color(0.16, 0.19, 0.17, 0.92)
	var border := UIThemeHelper.COL_ACCENT if selected else UIThemeHelper.COL_BORDER
	btn.add_theme_stylebox_override("normal", UIThemeHelper.make_panel_style(bg, border, 6))
	btn.add_theme_stylebox_override("hover", UIThemeHelper.make_panel_style(bg, border, 6))
	btn.add_theme_stylebox_override("pressed", UIThemeHelper.make_panel_style(bg.darkened(0.15), UIThemeHelper.COL_ACCENT, 6))

	if entry != null:
		var tex := DataManager.get_item_icon(str(entry["id"]))
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
		var cnt := int(entry["count"])
		if cnt > 1:
			var lbl := Label.new()
			lbl.text = str(cnt)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.position = Vector2(44, 46)
			btn.add_child(lbl)
	return btn

func _refresh_details() -> void:
	var inv: InventorySystem = _world_ctrl.inventory
	if _selected_slot < 0 or _selected_slot >= inv.slots.size() or inv.slots[_selected_slot] == null:
		_detail_name.text = "Выберите предмет"
		_detail_desc.text = "Нажмите на ячейку инвентаря для просмотра информации."
		_use_btn.disabled = true
		_drop_btn.disabled = true
		_transfer_btn.visible = _storage_box.visible
		_transfer_btn.disabled = true
		return

	var entry: Dictionary = inv.slots[_selected_slot]
	var def := DataManager.get_item(str(entry["id"]))
	_detail_name.text = "%s (×%d)" % [str(def.get("name", entry["id"])), int(entry["count"])]
	_detail_desc.text = str(def.get("description", ""))
	var can_use := bool(def.get("usable", false)) or bool(def.get("equippable", false))
	_use_btn.disabled = not can_use
	_use_btn.text = "Экипировать" if bool(def.get("equippable", false)) else "Использовать"
	_drop_btn.disabled = false
	_transfer_btn.visible = _storage_box.visible
	_transfer_btn.disabled = false

func _on_use_pressed() -> void:
	if _selected_slot >= 0:
		_world_ctrl.inventory.use_slot(_selected_slot, _world_ctrl.survival)
		if _world_ctrl.building_system.active:
			visible = false
		refresh()

func _on_drop_pressed() -> void:
	if _selected_slot >= 0:
		var removed := _world_ctrl.inventory.remove_at_slot(_selected_slot, 1)
		if not removed.is_empty():
			AudioManager.play_sfx("ui_click")
			EventBus.notification_requested.emit("Выброшено: %s" % DataManager.get_item_name(str(removed["id"])), Color(0.85, 0.72, 0.55))
		refresh()

func _on_transfer_to_storage() -> void:
	if _active_storage == null or _selected_slot < 0:
		return
	var inv: InventorySystem = _world_ctrl.inventory
	var entry = inv.slots[_selected_slot]
	if entry == null:
		return
	for i in range(_active_storage.storage_slots.size()):
		if _active_storage.storage_slots[i] == null:
			_active_storage.storage_slots[i] = entry.duplicate(true)
			inv.slots[_selected_slot] = null
			_selected_slot = -1
			AudioManager.play_sfx("pickup")
			EventBus.inventory_changed.emit()
			refresh()
			return
	EventBus.notification_requested.emit("Хранилище заполнено!", Color(0.95, 0.5, 0.4))

func _on_take_from_storage(st_idx: int) -> void:
	if _active_storage == null or st_idx < 0 or st_idx >= _active_storage.storage_slots.size():
		return
	var entry = _active_storage.storage_slots[st_idx]
	if entry == null:
		return
	var left := _world_ctrl.inventory.add_item(str(entry["id"]), int(entry["count"]), int(entry.get("durability", -1)))
	if left == 0:
		_active_storage.storage_slots[st_idx] = null
		AudioManager.play_sfx("pickup")
	else:
		entry["count"] = left
		EventBus.notification_requested.emit("Инвентарь полон!", Color(0.95, 0.5, 0.4))
	refresh()
