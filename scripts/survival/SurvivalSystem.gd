class_name SurvivalSystem
extends Node

# Характеристики выживания персонажа
var health: float = 100.0
var max_health: float = 100.0
var hunger: float = 95.0
var thirst: float = 95.0
var energy: float = 100.0
var max_energy: float = 100.0
var warmth: float = 85.0 # Комфорт/тепло (влияет ночь, дождь, костёр, навес)

var has_warm_coat: bool = false
var is_near_fire: bool = false
var is_under_shelter: bool = false
var is_dead: bool = false

# Система навыков выжившего
var skills: Dictionary = {
	"gathering": { "name": "Собирательство", "level": 1, "xp": 0, "next_xp": 100 },
	"crafting": { "name": "Ремесло", "level": 1, "xp": 0, "next_xp": 100 },
	"building": { "name": "Строительство", "level": 1, "xp": 0, "next_xp": 100 },
	"survival": { "name": "Выживание", "level": 1, "xp": 0, "next_xp": 100 }
}

var _tick_timer: float = 0.0
var _current_weather: String = "clear"
var _current_phase: String = "day"

func _ready() -> void:
	EventBus.weather_changed.connect(func(w: String): _current_weather = w)
	EventBus.time_updated.connect(func(_d: int, _h: float, phase: String): _current_phase = phase)
	_emit_stats()

func _process(delta: float) -> void:
	if is_dead:
		return
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_survival(_tick_timer)
		_tick_timer = 0.0

func _tick_survival(dt: float) -> void:
	var surv_lvl: int = int(skills["survival"]["level"])
	var drain_mult: float = maxf(0.65, 1.0 - (surv_lvl - 1) * 0.04)

	# Постепенный расход голода, жажды и энергии
	hunger = maxf(0.0, hunger - 0.14 * dt * drain_mult)
	thirst = maxf(0.0, thirst - 0.19 * dt * drain_mult)
	energy = maxf(0.0, energy - 0.08 * dt * drain_mult)

	# Расчёт тепла и комфорта
	var warmth_delta: float = 0.0
	if is_near_fire:
		warmth_delta += 3.5
	if is_under_shelter:
		warmth_delta += 0.8
	if _current_phase == "night":
		warmth_delta -= 0.45
	elif _current_phase == "evening":
		warmth_delta -= 0.15
	else:
		warmth_delta += 0.25
	if _current_weather == "rain" and not is_under_shelter:
		warmth_delta -= 0.65
	elif _current_weather == "storm" and not is_under_shelter:
		warmth_delta -= 1.05
	if has_warm_coat and warmth_delta < 0.0:
		warmth_delta *= 0.5
	warmth = clampf(warmth + warmth_delta * dt, 0.0, 100.0)

	# Последствия критических показателей
	var hp_delta: float = 0.0
	if hunger <= 0.0:
		hp_delta -= 0.7
	if thirst <= 0.0:
		hp_delta -= 0.9
	if warmth <= 10.0:
		hp_delta -= 0.45
	if hunger > 65.0 and thirst > 65.0 and warmth > 50.0 and health < max_health:
		hp_delta += 0.22

	health = clampf(health + hp_delta * dt, 0.0, max_health)
	if health <= 0.0 and not is_dead:
		is_dead = true
		var reason := "Истощение организма"
		if thirst <= 0.0:
			reason = "Обезвоживание"
		elif hunger <= 0.0:
			reason = "Голод"
		elif warmth <= 10.0:
			reason = "Переохлаждение"
		EventBus.player_died.emit(reason)

	_emit_stats()

func consume_energy(amount: float) -> void:
	energy = maxf(0.0, energy - amount)
	_emit_stats()

func apply_item_effects(effects: Dictionary) -> void:
	health = clampf(health + float(effects.get("health", 0.0)), 0.0, max_health)
	hunger = clampf(hunger + float(effects.get("hunger", 0.0)), 0.0, 100.0)
	thirst = clampf(thirst + float(effects.get("thirst", 0.0)), 0.0, 100.0)
	energy = clampf(energy + float(effects.get("energy", 0.0)), 0.0, max_energy)
	warmth = clampf(warmth + float(effects.get("warmth", 0.0)), 0.0, 100.0)
	add_skill_xp("survival", 5)
	_emit_stats()

func rest_on_bed() -> void:
	energy = max_energy
	health = minf(max_health, health + 30.0)
	hunger = maxf(10.0, hunger - 12.0)
	thirst = maxf(10.0, thirst - 15.0)
	warmth = minf(100.0, warmth + 25.0)
	add_skill_xp("survival", 12)
	_emit_stats()

func get_gathering_speed_multiplier() -> float:
	var lvl: int = int(skills["gathering"]["level"])
	var energy_penalty: float = 0.75 if energy < 15.0 else 1.0
	return (1.0 + (lvl - 1) * 0.1) * energy_penalty

func get_bonus_drop_chance() -> float:
	var lvl: int = int(skills["gathering"]["level"])
	return minf(0.45, (lvl - 1) * 0.06)

func add_skill_xp(skill_id: String, amount: int) -> void:
	if not skills.has(skill_id) or amount <= 0:
		return
	var sk: Dictionary = skills[skill_id]
	sk["xp"] = int(sk["xp"]) + amount
	var leveled := false
	while int(sk["xp"]) >= int(sk["next_xp"]):
		sk["xp"] = int(sk["xp"]) - int(sk["next_xp"])
		sk["level"] = int(sk["level"]) + 1
		sk["next_xp"] = int(round(int(sk["next_xp"]) * 1.45))
		leveled = true
		if skill_id == "survival":
			max_energy = 100.0 + (int(sk["level"]) - 1) * 10.0
		EventBus.skill_leveled_up.emit(skill_id, int(sk["level"]))
		EventBus.notification_requested.emit("Навык «%s» повышен до ур. %d!" % [sk["name"], int(sk["level"])], Color(0.95, 0.82, 0.38))
		AudioManager.play_sfx("level_up", 0.02)
	EventBus.skills_changed.emit(skills)
	if leveled:
		_emit_stats()

func get_stats_dict() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"thirst": thirst,
		"energy": energy,
		"max_energy": max_energy,
		"warmth": warmth,
		"is_near_fire": is_near_fire,
		"is_under_shelter": is_under_shelter,
		"has_warm_coat": has_warm_coat
	}

func _emit_stats() -> void:
	EventBus.stats_changed.emit(get_stats_dict())

func to_save_dict() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"hunger": hunger,
		"thirst": thirst,
		"energy": energy,
		"max_energy": max_energy,
		"warmth": warmth,
		"has_warm_coat": has_warm_coat,
		"skills": skills.duplicate(true)
	}

func load_from_dict(data: Dictionary) -> void:
	health = float(data.get("health", 100.0))
	max_health = float(data.get("max_health", 100.0))
	hunger = float(data.get("hunger", 95.0))
	thirst = float(data.get("thirst", 95.0))
	energy = float(data.get("energy", 100.0))
	max_energy = float(data.get("max_energy", 100.0))
	warmth = float(data.get("warmth", 85.0))
	has_warm_coat = bool(data.get("has_warm_coat", false))
	is_dead = false
	var saved_skills = data.get("skills", {})
	if typeof(saved_skills) == TYPE_DICTIONARY:
		for k in saved_skills.keys():
			if skills.has(k):
				skills[k] = saved_skills[k]
	EventBus.skills_changed.emit(skills)
	_emit_stats()
