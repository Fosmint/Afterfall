extends Control

# Экран загрузки мира с советами по выживанию и асинхронной загрузкой сцены
const TIPS := [
	"Совет: Постройте костёр до наступления ночи — он согреет и осветит лагерь.",
	"Совет: Сборщик дождевой воды наполняется намного быстрее во время дождя.",
	"Совет: Рабочий стол открывает рецепты железных инструментов, фонарика и рюкзака.",
	"Совет: Исследуйте заброшенные магазины, склады и АЗС ради редких припасов.",
	"Совет: Кровать позволяет пропустить холодную ночь и восстановить энергию."
]

var _progress: ProgressBar
var _status_lbl: Label
var _target_scene := "res://scenes/world/GameWorld.tscn"
var _started := false

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -90
	box.offset_bottom = 90
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "AFTERFALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65))
	box.add_child(title)

	_status_lbl = Label.new()
	_status_lbl.text = "Загрузка мира (Seed: %d)..." % GameManager.world_seed
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 16)
	_status_lbl.add_theme_color_override("font_color", UIThemeHelper.COL_TEXT)
	box.add_child(_status_lbl)

	_progress = ProgressBar.new()
	_progress.max_value = 100.0
	_progress.value = 15.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 18)
	_progress.add_theme_stylebox_override("background", UIThemeHelper.make_bar_bg())
	_progress.add_theme_stylebox_override("fill", UIThemeHelper.make_bar_style(UIThemeHelper.COL_ACCENT))
	box.add_child(_progress)

	var tip := Label.new()
	tip.text = TIPS[randi() % TIPS.size()]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", UIThemeHelper.COL_MUTED)
	box.add_child(tip)

	ResourceLoader.load_threaded_request(_target_scene)
	_started = true

func _process(_delta: float) -> void:
	if not _started:
		return
	var prog := []
	var status := ResourceLoader.load_threaded_get_status(_target_scene, prog)
	if prog.size() > 0:
		_progress.value = maxf(_progress.value, float(prog[0]) * 100.0)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_started = false
		_progress.value = 100.0
		var packed := ResourceLoader.load_threaded_get(_target_scene) as PackedScene
		if packed:
			get_tree().change_scene_to_packed(packed)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_started = false
		get_tree().change_scene_to_file(_target_scene)
