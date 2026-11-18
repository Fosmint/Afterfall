extends Node

# Менеджер звуковых эффектов и эмбиента с пулом плееров для Android
const SFX_POOL_SIZE := 6

var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient_player: AudioStreamPlayer
var _fire_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _sfx_index: int = 0
var sfx_volume: float = 0.85
var ambient_volume: float = 0.45
var muted: bool = false

func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_fire_player = AudioStreamPlayer.new()
	add_child(_fire_player)
	_preload_sounds()
	EventBus.settings_changed.connect(_on_settings_changed)

func _preload_sounds() -> void:
	var names := [
		"step_grass", "step_asphalt", "chop_wood", "mine_stone",
		"scavenge_metal", "pickup", "craft", "build", "eat",
		"drink", "ui_click", "level_up", "rain_loop", "wind_loop", "campfire_loop"
	]
	for n in names:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)

func play_sfx(sound_name: String, pitch_jitter: float = 0.08) -> void:
	if muted or sfx_volume <= 0.01:
		return
	if not _streams.has(sound_name):
		return
	var p := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	p.stream = _streams[sound_name]
	p.volume_db = linear_to_db(clampf(sfx_volume, 0.01, 1.0))
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()

func set_ambient_weather(weather: String) -> void:
	if muted or ambient_volume <= 0.01:
		_ambient_player.stop()
		return
	var target := "rain_loop" if (weather == "rain" or weather == "storm") else "wind_loop"
	if not _streams.has(target):
		return
	if _ambient_player.stream != _streams[target] or not _ambient_player.playing:
		var stream: AudioStreamWAV = _streams[target]
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_ambient_player.stream = stream
		_ambient_player.volume_db = linear_to_db(clampf(ambient_volume * (1.0 if target == "rain_loop" else 0.55), 0.01, 1.0))
		_ambient_player.play()

func set_campfire_ambient(active: bool) -> void:
	if muted or ambient_volume <= 0.01 or not active:
		if _fire_player.playing:
			_fire_player.stop()
		return
	if _streams.has("campfire_loop") and not _fire_player.playing:
		var stream: AudioStreamWAV = _streams["campfire_loop"]
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_fire_player.stream = stream
		_fire_player.volume_db = linear_to_db(clampf(ambient_volume * 0.7, 0.01, 1.0))
		_fire_player.play()

func stop_all_ambient() -> void:
	_ambient_player.stop()
	_fire_player.stop()

func _on_settings_changed(settings: Dictionary) -> void:
	sfx_volume = float(settings.get("sfx_volume", 0.85))
	ambient_volume = float(settings.get("ambient_volume", 0.45))
	muted = bool(settings.get("muted", false))
	if muted:
		stop_all_ambient()
