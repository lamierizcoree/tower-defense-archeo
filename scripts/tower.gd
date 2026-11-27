class_name Tower
extends Node2D
## Une tour posée sur un mur. Son comportement dépend de son type (voir tower_types.gd).

var type_id := "arbalete"
var data: Dictionary = {}
var cell: Vector2i
var enemies: Array[Enemy] = []  # même tableau que celui de main.gd
var towers: Dictionary = {}     # même dictionnaire que celui de main.gd (pour les totems)
var cooldown := 0.0

# Effets visuels du dernier tir
var shot_target := Vector2.ZERO
var shot_time := 0.0
const SHOT_DURATION := 0.12


func setup(id: String) -> void:
	type_id = id
	data = TowerTypes.get_type(id)


func range_px() -> float:
	return data["range"]


func _process(delta: float) -> void:
	shot_time -= delta
	if data["attack"] == "support":
		queue_redraw()
		return
	cooldown -= delta * _fire_rate_bonus()
	if cooldown <= 0.0 and _attack():
		cooldown = data["delay"]
	queue_redraw()


## Les totems voisins accélèrent la cadence (un seul totem compte, ils ne se cumulent pas).
func _fire_rate_bonus() -> float:
	for t in towers.values():
		if t != self and is_instance_valid(t) and t.data["attack"] == "support":
			if global_position.distance_to(t.global_position) <= t.range_px():
				return 1.0 + t.data["buff"]
	return 1.0


## Tire si possible. Renvoie true si un tir a eu lieu.
func _attack() -> bool:
	match data["attack"]:
		"single":
			var target := _find_target()
			if target == null:
				return false
			_show_shot(target)
			target.take_damage(data["damage"])
		"splash":
			var target := _find_target(data.get("min_range", 0.0))
			if target == null:
				return false
			_show_shot(target)
			var center := target.global_position
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(center) <= data["splash_radius"]:
					e.take_damage(data["damage"])
		"aura":
			var hit := false
			for e in enemies.duplicate():
				if _in_range(e):
					e.apply_slow(data["slow"], data["slow_time"])
					e.take_damage(data["damage"])
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


func _in_range(e: Enemy, min_range := 0.0) -> bool:
	if not is_instance_valid(e) or e.dead:
		return false
	var d := global_position.distance_to(e.global_position)
	return d <= range_px() and d >= min_range


## Vise l'ennemi à portée le plus proche de l'objectif.
## Si prefer_healthy est vrai, préfère les ennemis qui ne sont pas encore empoisonnés.
func _find_target(min_range := 0.0, prefer_healthy := false) -> Enemy:
	var best: Enemy = null
	for e in enemies:
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
			"splash":
				draw_circle(shot_target, data["splash_radius"], Color(1.0, 0.55, 0.15, 0.35))
			"aura":
				draw_circle(Vector2.ZERO, range_px(), Color(0.6, 0.9, 1.0, 0.25))
			"poison":
				draw_line(Vector2.ZERO, shot_target, Color("8fd14f"), 3.0)
