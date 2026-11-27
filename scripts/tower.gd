class_name Tower
extends Node2D
## Une tour posée sur un mur. Son comportement dépend de son type (voir tower_types.gd),
## du biome (tempête, froid) et des jokers du joueur.

var type_id := "arbalete"
var data: Dictionary = {}
var cell: Vector2i
var level: Node            # le niveau (level.gd)
var cooldown := 0.0

# Effets visuels du dernier tir
var shot_target := Vector2.ZERO
var echo_target := Vector2.ZERO
var has_echo := false
var shot_time := 0.0
const SHOT_DURATION := 0.12

const ECHO_RANGE := 110.0
const ECHO_DAMAGE := 0.6


func setup(id: String, lvl: Node, at: Vector2i) -> void:
	type_id = id
	data = TowerTypes.get_type(id)
	level = lvl
	cell = at
	position = Grid.cell_to_world(at)


func range_px() -> float:
	return level.tower_range(type_id, cell)


func _process(delta: float) -> void:
	shot_time -= delta
	if data["attack"] == "support":
		queue_redraw()
		return
	cooldown -= delta * _fire_rate()
	if cooldown <= 0.0 and _attack():
		cooldown = data["delay"]
	queue_redraw()


## Vitesse de tir : froid du biome × bonus des totems voisins.
func _fire_rate() -> float:
	var rate: float = Run.biome()["tower_cadence"]
	var bonus := 0.0
	for t in level.towers.values():
		if t == self or not is_instance_valid(t) or t.data["attack"] != "support":
			continue
		if global_position.distance_to(t.global_position) <= t.range_px():
			if Run.has_joker("ancetres"):
				bonus += t.data["buff"]
			else:
				bonus = maxf(bonus, t.data["buff"])
	return rate * (1.0 + bonus)


func _damage() -> float:
	var dmg: float = data["damage"]
	if Run.has_joker("cul_de_sac") and level.blocked_neighbors(cell) >= 3:
		dmg *= 2.0
	return dmg


## Tire si possible. Renvoie true si un tir a eu lieu.
func _attack() -> bool:
	match data["attack"]:
		"single":
			var target := _find_target()
			if target == null:
				return false
			_show_shot(target)
			has_echo = false
			if Run.has_joker("echo"):
				var second := _closest_other(target)
				if second:
					has_echo = true
					echo_target = second.global_position - global_position
					second.take_damage(_damage() * ECHO_DAMAGE)
			target.take_damage(_damage())
		"splash":
			var target := _find_target(data.get("min_range", 0.0))
			if target == null:
				return false
			_show_shot(target)
			var center := target.global_position
			for e in level.enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(center) <= _splash_radius():
					e.take_damage(_damage())
		"aura":
			var hit := false
			var slow: float = data["slow"]
			var slow_time: float = data["slow_time"]
			if Run.has_joker("givre_eternel"):
				slow = 0.35
				slow_time *= 2.0
			for e in level.enemies.duplicate():
				if _in_range(e):
					e.apply_slow(slow, slow_time)
					e.take_damage(_damage())
					hit = true
			if not hit:
				return false
			shot_time = SHOT_DURATION * 2
		"poison":
			var target := _find_target(0.0, true)
			if target == null:
				return false
			_show_shot(target)
			target.apply_poison(data["poison_dps"], data["poison_time"])
	return true


func _splash_radius() -> float:
	return data["splash_radius"] * (1.5 if Run.has_joker("artilleur") else 1.0)


func _in_range(e: Enemy, min_range := 0.0) -> bool:
	if not is_instance_valid(e) or e.dead:
		return false
	var d := global_position.distance_to(e.global_position)
	return d <= range_px() and d >= min_range


## Vise l'ennemi à portée le plus proche de la sortie.
## Si prefer_healthy est vrai, préfère les ennemis qui ne sont pas encore empoisonnés.
func _find_target(min_range := 0.0, prefer_healthy := false) -> Enemy:
	var best: Enemy = null
	for e in level.enemies:
		if not _in_range(e, min_range):
			continue
		if best == null:
			best = e
			continue
		if prefer_healthy and best.is_poisoned() != e.is_poisoned():
			if not e.is_poisoned():
				best = e
			continue
		if e.remaining_steps() < best.remaining_steps():
			best = e
	return best


## L'ennemi le plus proche d'une cible (pour le rebond de l'Écho).
func _closest_other(target: Enemy) -> Enemy:
	var best: Enemy = null
	var best_d := ECHO_RANGE
	for e in level.enemies:
		if e == target or not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(target.global_position)
		if d <= best_d:
			best = e
			best_d = d
	return best


func _show_shot(target: Enemy) -> void:
	shot_target = target.global_position - global_position
	shot_time = SHOT_DURATION


func _draw() -> void:
	var color: Color = data["color"]
	var s := Grid.CELL * 0.7
	var dark := color.darkened(0.5)
	match data["attack"]:
		"single":
			if type_id == "baliste":
				# Losange
				var pts := PackedVector2Array([Vector2(0, -s / 2), Vector2(s / 2, 0), Vector2(0, s / 2), Vector2(-s / 2, 0)])
				draw_colored_polygon(pts, color)
				pts.append(pts[0])
				draw_polyline(pts, dark, 2.0)
			else:
				draw_rect(Rect2(-s / 2, -s / 2, s, s), color)
				draw_rect(Rect2(-s / 2, -s / 2, s, s), dark, false, 2.0)
		"splash":
			draw_circle(Vector2.ZERO, s / 2, color)
			draw_arc(Vector2.ZERO, s / 2, 0.0, TAU, 24, dark, 2.0)
			draw_circle(Vector2.ZERO, s / 5, dark)
		"aura":
			# Étoile de givre
			for i in 3:
				var dir := Vector2.from_angle(i * PI / 3) * s / 2
				draw_line(-dir, dir, color, 6.0)
			draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
		"poison":
			# Fiole : rond + goulot
			draw_rect(Rect2(-5, -s / 2, 10, s / 3), dark)
			draw_circle(Vector2(0, 4), s / 3, color)
			draw_arc(Vector2(0, 4), s / 3, 0.0, TAU, 24, dark, 2.0)
		"support":
			# Triangle
			var pts := PackedVector2Array([Vector2(0, -s / 2), Vector2(s / 2, s / 2), Vector2(-s / 2, s / 2)])
			draw_colored_polygon(pts, color)
			pts.append(pts[0])
			draw_polyline(pts, dark, 2.0)
			draw_arc(Vector2.ZERO, range_px(), 0.0, TAU, 48, Color(color, 0.25), 1.5)

	if shot_time > 0.0:
		match data["attack"]:
			"single":
				var w := 5.0 if type_id == "baliste" else 3.0
				draw_line(Vector2.ZERO, shot_target, Color("ffe066"), w)
				if has_echo:
					draw_line(shot_target, echo_target, Color("ffe066", 0.6), 2.0)
			"splash":
				draw_circle(shot_target, _splash_radius(), Color(1.0, 0.55, 0.15, 0.35))
			"aura":
				draw_circle(Vector2.ZERO, range_px(), Color(0.6, 0.9, 1.0, 0.25))
			"poison":
				draw_line(Vector2.ZERO, shot_target, Color("8fd14f"), 3.0)
