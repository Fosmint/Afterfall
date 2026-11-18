class_name TimeWeatherSystem
extends Node

# Цикл дня и ночи (24 часа), плавное освещение, погода и случайные события
const SECONDS_PER_GAME_HOUR: float = 28.0 # Полные сутки ≈ 11.2 мин реального времени

var day: int = 1
var hour: float = 8.0 # Начинаем утром в 08:00
var current_phase: String = "morning"
var current_weather: String = "clear" # clear, cloudy, rain, storm

var _canvas_modulate: CanvasModulate = null
var _weather_timer: float = 160.0
var _event_timer: float = 240.0
var _emit_accum: float = 0.0

func setup(modulate_node: CanvasModulate) -> void:
	_canvas_modulate = modulate_node
	_update_phase_and_color()
	AudioManager.set_ambient_weather(current_weather)
	EventBus.time_updated.emit(day, hour, current_phase)
	EventBus.weather_changed.emit(current_weather)

func _process(delta: float) -> void:
	hour += delta / SECONDS_PER_GAME_HOUR
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		EventBus.notification_requested.emit("Наступил День %d" % day, Color(0.95, 0.88, 0.62))

	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_roll_next_weather()

	_event_timer -= delta
	if _event_timer <= 0.0:
		_trigger_random_event()

	_emit_accum += delta
	if _emit_accum >= 0.4:
		_emit_accum = 0.0
		_update_phase_and_color()
		EventBus.time_updated.emit(day, hour, current_phase)

func advance_hours(hours_to_add: float) -> void:
	hour += hours_to_add
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	_update_phase_and_color()
	EventBus.time_updated.emit(day, hour, current_phase)

func _update_phase_and_color() -> void:
	var new_phase := "day"
	if hour >= 5.5 and hour < 10.0:
		new_phase = "morning"
	elif hour >= 10.0 and hour < 17.5:
		new_phase = "day"
	elif hour >= 17.5 and hour < 21.0:
		new_phase = "evening"
	else:
		new_phase = "night"
	current_phase = new_phase

	if _canvas_modulate == null:
		return

	# Плавная интерполяция освещения по времени суток
	var target_col := _sample_time_color(hour)
	# Коррекция на пасмурную/дождливую погоду
	if current_weather == "cloudy":
		target_col = target_col.lerp(Color(0.75, 0.78, 0.82, 1.0), 0.22)
	elif current_weather == "rain":
		target_col = target_col.lerp(Color(0.58, 0.65, 0.74, 1.0), 0.35)
	elif current_weather == "storm":
		target_col = target_col.lerp(Color(0.42, 0.48, 0.58, 1.0), 0.5)
	_canvas_modulate.color = _canvas_modulate.color.lerp(target_col, 0.15)

func _sample_time_color(h: float) -> Color:
	var c_night := Color(0.24, 0.28, 0.40, 1.0)
	var c_morning := Color(0.95, 0.86, 0.76, 1.0)
	var c_day := Color(1.0, 1.0, 0.97, 1.0)
	var c_evening := Color(0.88, 0.62, 0.48, 1.0)
	if h < 5.0:
		return c_night
	elif h < 8.0:
		return c_night.lerp(c_morning, (h - 5.0) / 3.0)
	elif h < 11.0:
		return c_morning.lerp(c_day, (h - 8.0) / 3.0)
	elif h < 17.0:
		return c_day
	elif h < 20.0:
		return c_day.lerp(c_evening, (h - 17.0) / 3.0)
	elif h < 22.0:
		return c_evening.lerp(c_night, (h - 20.0) / 2.0)
	return c_night

func _roll_next_weather() -> void:
	_weather_timer = randf_range(120.0, 240.0)
	var roll := randf()
	var next_w := "clear"
	if roll < 0.48:
		next_w = "clear"
	elif roll < 0.72:
		next_w = "cloudy"
	elif roll < 0.90:
		next_w = "rain"
	else:
		next_w = "storm"

	if next_w != current_weather:
		current_weather = next_w
		AudioManager.set_ambient_weather(current_weather)
		EventBus.weather_changed.emit(current_weather)
		var labels := {
			"clear": "Погода прояснилась.",
			"cloudy": "Небо затянуло облаками.",
			"rain": "Начался дождь. Сборщики воды наполняются быстрее.",
			"storm": "Надвигается гроза! Укройтесь под навесом или у костра."
		}
		EventBus.notification_requested.emit(labels[current_weather], Color(0.72, 0.84, 0.96))

func _trigger_random_event() -> void:
	_event_timer = randf_range(220.0, 380.0)
	var events := [
		"Слышен далёкий гул ветра среди руин...",
		"Вдалеке промелькнула стая птиц. Природа возвращает своё.",
		"Похолодало. Проверьте запас дров для костра."
	]
	EventBus.notification_requested.emit(events[randi() % events.size()], Color(0.82, 0.85, 0.78))

func get_formatted_time() -> String:
	var hh := int(hour)
	var mm := int((hour - hh) * 60.0)
	return "%02d:%02d" % [hh, mm]

func get_phase_label() -> String:
	match current_phase:
		"morning": return "Утро"
		"day": return "День"
		"evening": return "Вечер"
		_: return "Ночь"

func get_weather_label() -> String:
	match current_weather:
		"clear": return "Ясно"
		"cloudy": return "Облачно"
		"rain": return "Дождь"
		"storm": return "Гроза"
		_: return "Ясно"

func is_night() -> bool:
	return current_phase == "night" or (current_phase == "evening" and hour >= 19.5)

func to_save_dict() -> Dictionary:
	return {
		"day": day,
		"hour": hour,
		"weather": current_weather
	}

func load_from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = float(data.get("hour", 8.0))
	current_weather = str(data.get("weather", "clear"))
	_update_phase_and_color()
	AudioManager.set_ambient_weather(current_weather)
	EventBus.time_updated.emit(day, hour, current_phase)
	EventBus.weather_changed.emit(current_weather)
