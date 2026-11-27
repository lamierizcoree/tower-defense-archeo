class_name Tower
extends Node2D
## Une tour posée sur un mur. Son comportement dépend de son type (voir tower_types.gd),
## du biome (tempête, froid), des jokers du joueur et des reliques posées dedans.

var type_id := "arbalete"
var data: Dictionary = {}
var cell: Vector2i
var level: Node            # le niveau (level.gd)
var cooldown := 0.0
var relics: Array[int] = []    # index des reliques de Run.relics posées dans cette tour
var line_dir := Vector2i.RIGHT # direction de tir avec la Lance du Pharaon

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


# --- Reliques ----------------------------------------------------------------

## Nombre de reliques que la tour peut porter : 1, ou 2 avec le joker Écrin double.
## Dans tous les cas, une seule légendaire par tour.
func slot_count() -> int:
	return 2 if Run.has_joker("ecrin") else 1


func relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in relics:
		ids.append(Run.relics[i])
	return ids


## Somme d'un bonus en pourcentage sur toutes les reliques de la tour.
func relic_bonus(stat: String) -> float:
	var total := 0.0
	for id in relic_ids():
		total += float(Relics.get_relic(id).get(stat, 0.0))
	return total


## Valeur d'un bonus de légendaire (multiplicateur ou option), ou default si absent.
func legendary(key: String, default: Variant = null) -> Variant:
	for id in relic_ids():
		var r := Relics.get_relic(id)
		if r.has(key):
			return r[key]
	return default


func has_legendary() -> bool:
	for id in relic_ids():
		if Relics.is_legendary(id):
			return true
	return false


func is_line() -> bool:
	return legendary("line", false)


## Longueur de la ligne de tir, en cases : la portée de base de la tour.
func line_cells() -> int:
	return maxi(1, roundi(float(data["range"]) / Grid.CELL))


## Multiplicateur des effets spéciaux (ralentissement, poison, explosion, totem).
func effect_mult() -> float:
	return 1.0 + relic_bonus("effect")


# --- Statistiques ------------------------------------------------------------

func range_px() -> float:
	var fixed: Variant = legendary("fixed_range")
	if fixed != null:
		return fixed
	return level.tower_range(type_id, cell) * (1.0 + relic_bonus("range"))


## Bonus de cadence que ce Totem donne à ses voisins.
func buff_value() -> float:
	return float(data.get("buff", 0.0)) * effect_mult()


func _process(delta: float) -> void:
	shot_time -= delta
	if data["attack"] == "support":
		queue_redraw()
		return
	cooldown -= delta * _fire_rate()
	if cooldown <= 0.0 and _attack():
		cooldown = data["delay"]
	queue_redraw()


## Vitesse de tir : froid du biome × reliques × bonus des totems voisins.
func _fire_rate() -> float:
	var rate: float = Run.biome()["tower_cadence"]
	rate *= (1.0 + relic_bonus("rate")) * float(legendary("rate_x", 1.0)) * Profile.rate_mult()
	var bonus := 0.0
	for t in level.towers.values():
		if t == self or not is_instance_valid(t) or t.data["attack"] != "support":
			continue
		if global_position.distance_to(t.global_position) <= t.range_px():
			if Run.has_joker("ancetres"):
				bonus += t.buff_value()
			else:
				bonus = maxf(bonus, t.buff_value())
	return rate * (1.0 + bonus)


func _damage() -> float:
	var dmg: float = data["damage"]
	dmg *= (1.0 + relic_bonus("damage")) * float(legendary("damage_x", 1.0)) * Profile.damage_mult()
	if Run.has_joker("cul_de_sac") and level.blocked_neighbors(cell) >= 3:
		dmg *= 2.0
	return dmg


## Multiplicateur de dégâts des reliques (utilisé pour le poison).
func _damage_mult() -> float:
	return (1.0 + relic_bonus("damage")) * float(legendary("damage_x", 1.0)) * Profile.damage_mult()


func _poison_dps() -> float:
	return float(data["poison_dps"]) * _damage_mult() * effect_mult()


func _slow() -> Array:
	var slow: float = data["slow"]
	var slow_time: float = float(data["slow_time"]) * effect_mult()
	if Run.has_joker("givre_eternel"):
		slow = 0.35
		slow_time *= 2.0
	return [slow, slow_time]


func _splash_radius() -> float:
	return float(data["splash_radius"]) * (1.5 if Run.has_joker("artilleur") else 1.0) * effect_mult()


# --- Attaque -----------------------------------------------------------------

## Tire si possible. Renvoie true si un tir a eu lieu.
func _attack() -> bool:
	if is_line():
		return _attack_line()
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
			var s := _slow()
			for e in level.enemies.duplicate():
				if _in_range(e):
					e.apply_slow(s[0], s[1])
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
			target.apply_poison(_poison_dps(), data["poison_time"])
	return true


## Lance du Pharaon : touche tous les ennemis sur la ligne de tir.
func _attack_line() -> bool:
	var hits := []
	for e in level.enemies:
		if _in_line(e) and _target_allowed(e):
			hits.append(e)
	if hits.is_empty():
		return false
	shot_time = SHOT_DURATION * 1.5
	for e in hits:
		match data["attack"]:
			"aura":
				var s := _slow()
				e.apply_slow(s[0], s[1])
				e.take_damage(_damage())
			"poison":
				e.apply_poison(_poison_dps(), data["poison_time"])
			_:
				e.take_damage(_damage())
	return true


## Vrai si l'ennemi est dans la bande de cases devant la tour.
func _in_line(e: Enemy) -> bool:
	if not is_instance_valid(e) or e.dead:
		return false
	var rel := e.global_position - global_position
	var dir := Vector2(line_dir)
	var along := rel.dot(dir)
	var side := absf(rel.dot(dir.orthogonal()))
	return along >= Grid.CELL * 0.3 and along <= (line_cells() + 0.5) * Grid.CELL and side <= Grid.CELL * 0.5


## Cœur du Colosse gelé : seuls les ennemis ralentis peuvent être visés.
func _target_allowed(e: Enemy) -> bool:
	return not legendary("only_slowed", false) or e.slow_time > 0.0


func _in_range(e: Enemy, min_range := 0.0) -> bool:
	if not is_instance_valid(e) or e.dead or not _target_allowed(e):
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
	if is_line():
		# Bande de tir de la Lance du Pharaon
		var band := _line_rect()
		var flash := shot_time > 0.0
		draw_rect(band, Color(1.0, 0.75, 0.2, 0.45 if flash else 0.14))
		draw_rect(band, Color(1.0, 0.75, 0.2, 0.6), false, 1.5)
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

	# Reliques posées : une pierre par relique, de la couleur de sa rareté
	var ids := relic_ids()
	for k in ids.size():
		var p := Vector2(-s / 2 + 5 + k * 9, s / 2 - 4)
		draw_circle(p, 4.5, Color(0, 0, 0, 0.6))
		draw_circle(p, 3.5, Relics.RARITY_COLORS[Relics.get_relic(ids[k])["rarity"]])

	if shot_time > 0.0 and not is_line():
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


## Rectangle de la ligne de tir, en coordonnées de la tour.
func _line_rect() -> Rect2:
	var length := line_cells() * Grid.CELL
	var half := Grid.CELL * 0.5
	match line_dir:
		Vector2i.RIGHT:
			return Rect2(half, -half, length, Grid.CELL)
		Vector2i.LEFT:
			return Rect2(-half - length, -half, length, Grid.CELL)
		Vector2i.DOWN:
			return Rect2(-half, half, Grid.CELL, length)
	return Rect2(-half, -half - length, Grid.CELL, length)
