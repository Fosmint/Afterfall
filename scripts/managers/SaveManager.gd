extends Node

# Надёжная система JSON-сохранений с резервной копией и проверкой целостности
const SAVE_PATH := "user://afterfall_save.json"
const BACKUP_PATH := "user://afterfall_save.bak"
const SAVE_VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

func save_game_data(data: Dictionary, is_manual: bool = false) -> bool:
	data["save_version"] = SAVE_VERSION
	data["saved_at_unix"] = int(Time.get_unix_time_from_system())
	var json_str := JSON.stringify(data)
	if json_str.is_empty():
		return false

	# Создаём резервную копию предыдущего валидного сохранения
	if FileAccess.file_exists(SAVE_PATH):
		var old_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old_file:
			var old_text := old_file.get_as_text()
			old_file.close()
			if not old_text.is_empty():
				var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
				if bak:
					bak.store_string(old_text)
					bak.close()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: не удалось открыть файл для записи.")
		return false
	file.store_string(json_str)
	file.close()
	EventBus.game_saved.emit(is_manual)
	return true

func load_game_data() -> Dictionary:
	var primary := _try_load_file(SAVE_PATH)
	if not primary.is_empty():
		return primary
	# Если основной файл повреждён, пытаемся восстановить из резервной копии
	var backup := _try_load_file(BACKUP_PATH)
	if not backup.is_empty():
		push_warning("SaveManager: основное сохранение повреждено, загружена резервная копия.")
		return backup
	return {}

func _try_load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	# Минимальная проверка структуры сохранения
	if not parsed.has("world_seed") or not parsed.has("player"):
		return {}
	return parsed

func get_save_summary() -> Dictionary:
	var data := load_game_data()
	if data.is_empty():
		return {}
	var time_data: Dictionary = data.get("time", {})
	return {
		"day": int(time_data.get("day", 1)),
		"hour": float(time_data.get("hour", 8.0)),
		"world_seed": int(data.get("world_seed", 0)),
		"saved_at_unix": int(data.get("saved_at_unix", 0))
	}

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
