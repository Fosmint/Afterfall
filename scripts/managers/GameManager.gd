extends Node

# Глобальное состояние игры и оптимизация настроек под iQOO Z9 5G (Snapdragon 7 Gen 3)
var world_seed: int = 0
var is_loading_save: bool = false
var pending_save_data: Dictionary = {}
var current_world_node: Node = null

# Настройки по умолчанию подобраны специально под iQOO Z9 5G (Snapdragon 7 Gen 3, 8 ГБ RAM, 120 Гц экран)
var settings: Dictionary = {
	"quality_preset": "high", # low, medium, high
	"target_fps": 60,         # 30, 60, 90, 120 (60 по умолчанию — идеал плавности без нагрева)
	"chunk_view_radius": 2,   # радиус активных чанков (2 = 5x5 чанков)
	"particles_enabled": true,
	"dynamic_lights": true,
	"sfx_volume": 0.85,
	"ambient_volume": 0.45,
	"muted": false,
	"vibration": true,
	"joystick_scale": 1.0,
	"autosave_interval": 120
}

const SETTINGS_PATH := "user://afterfall_settings.json"

func _ready() -> void:
	load_settings()
	apply_settings()

func start_new_game(custom_seed: int = -1) -> void:
	is_loading_save = false
	pending_save_data = {}
	if custom_seed <= 0:
		world_seed = randi_range(100000, 9999999)
	else:
		world_seed = custom_seed
	get_tree().change_scene_to_file("res://scenes/main/LoadingScreen.tscn")

func continue_saved_game() -> bool:
	var data := SaveManager.load_game_data()
	if data.is_empty():
		return false
	is_loading_save = true
	pending_save_data = data
	world_seed = int(data.get("world_seed", 123456))
	get_tree().change_scene_to_file("res://scenes/main/LoadingScreen.tscn")
	return true

func return_to_main_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_all_ambient()
	current_world_node = null
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func apply_quality_preset(preset: String) -> void:
	settings["quality_preset"] = preset
	match preset:
		"low":
			settings["target_fps"] = 30
			settings["chunk_view_radius"] = 1
			settings["particles_enabled"] = false
			settings["dynamic_lights"] = false
		"medium":
			settings["target_fps"] = 60
			settings["chunk_view_radius"] = 2
			settings["particles_enabled"] = true
			settings["dynamic_lights"] = true
		"high":
			# Сбалансированный пресет для iQOO Z9 5G (Snapdragon 7 Gen 3)
			settings["target_fps"] = 60
			settings["chunk_view_radius"] = 2
			settings["particles_enabled"] = true
			settings["dynamic_lights"] = true
		"ultra":
			settings["target_fps"] = 90
			settings["chunk_view_radius"] = 3
			settings["particles_enabled"] = true
			settings["dynamic_lights"] = true
	apply_settings()
	save_settings()

func apply_settings() -> void:
	Engine.max_fps = int(settings.get("target_fps", 60))
	EventBus.settings_changed.emit(settings)

func vibrate_short(ms: int = 22) -> void:
	if bool(settings.get("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			settings[k] = parsed[k]
