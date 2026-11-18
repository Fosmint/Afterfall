class_name VirtualJoystick
extends Control

# Мультитач-совместимый виртуальный джойстик для Android (левый нижний угол)
signal input_changed(vec: Vector2)

const MAX_RADIUS: float = 52.0
var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _base_tex: TextureRect
var _knob_tex: TextureRect
var _center: Vector2 = Vector2(74, 74)

func _ready() -> void:
	custom_minimum_size = Vector2(148, 148)
	size = Vector2(148, 148)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_base_tex = TextureRect.new()
	_base_tex.texture = DataManager.get_texture("res://assets/textures/ui/joystick_base.png")
	_base_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_base_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_base_tex.size = Vector2(128, 128)
	_base_tex.position = Vector2(10, 10)
	_base_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base_tex)

	_knob_tex = TextureRect.new()
	_knob_tex.texture = DataManager.get_texture("res://assets/textures/ui/joystick_knob.png")
	_knob_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_knob_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_knob_tex.size = Vector2(58, 58)
	_knob_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_knob_tex)
	_reset_knob()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed and _touch_index == -1:
			_touch_index = ev.index
			_update_knob(ev.position)
			accept_event()
		elif not ev.pressed and ev.index == _touch_index:
			_touch_index = -1
			_reset_knob()
			accept_event()
	elif event is InputEventScreenDrag:
		var ev := event as InputEventScreenDrag
		if ev.index == _touch_index:
			_update_knob(ev.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_index = 99
				_update_knob(mb.position)
				accept_event()
			elif _touch_index == 99:
				_touch_index = -1
				_reset_knob()
				accept_event()
	elif event is InputEventMouseMotion and _touch_index == 99:
		_update_knob((event as InputEventMouseMotion).position)
		accept_event()

func _update_knob(local_pos: Vector2) -> void:
	var delta := local_pos - _center
	if delta.length() > MAX_RADIUS:
		delta = delta.normalized() * MAX_RADIUS
	_knob_tex.position = _center + delta - _knob_tex.size * 0.5
	output = delta / MAX_RADIUS
	if output.length() < 0.12:
		output = Vector2.ZERO
	input_changed.emit(output)

func _reset_knob() -> void:
	_knob_tex.position = _center - _knob_tex.size * 0.5
	output = Vector2.ZERO
	input_changed.emit(output)
