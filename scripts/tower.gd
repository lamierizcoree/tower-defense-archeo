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
var tier := 1                  # niveau de la tour : 1, 2 ou 3
var spec := ""                 # spécialisation choisie au niveau 3 : "a" ou "b"
var spent := 0                 # or dépensé (pose + améliorations), la moitié est rendue à la revente

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


# --- Niveaux et spécialisations ---------------------------------------------

## Valeur d'une option de la spécialisation choisie, ou default.
func spec_val(key: String, default: Variant = null) -> Variant:
	if spec == "":
		return default
	return data["specs"][spec].get(key, default)


func spec_data(which: String) -> Dictionary:
	return data["specs"][which]


## Bonus du niveau 2 (et 3) sur les dégâts et les effets.
func tier_power() -> float:
	return TowerTypes.TIER2_POWER if tier >= 2 else 1.0


## Totem de rage : bonus de dégâts donné par les totems voisins spécialisés.
func rage_bonus() -> float:
	var bonus := 0.0
	for t in level.towers.values():
		if t == self or not is_instance_valid(t) or t.data["attack"] != "support":
			continue
		if t.spec_val("rage", 0.0) > 0.0 and global_position.distance_to(t.global_position) <= t.range_px():
			bonus = maxf(bonus, t.spec_val("rage", 0.0))
	return bonus


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
	var m := (1.0 + relic_bonus("effect")) * tier_power()
	if Run.has_family("alchimistes", 2):
		m *= 1.0 + Jokers.ALCHIMISTES_EFFECT
	return m


# --- Statistiques ------------------------------------------------------------

func range_px() -> float:
	var fixed: Variant = legendary("fixed_range")
	if fixed != null:
		return fixed
	var r: float = level.tower_range(type_id, cell) * (1.0 + relic_bonus("range"))
	if tier >= 2:
		r *= TowerTypes.TIER2_RANGE
	r *= float(spec_val("range_x", 1.0))
	if Run.has_family("batisseurs", 2):
		r *= 1.0 + Jokers.BATISSEURS_RANGE
	if Run.has_duo("forteresse") and level.blocked_neighbors(cell) >= 3:
		r *= Jokers.FORTERESSE_RANGE
	return r


## Bonus de cadence que ce Totem donne à ses voisins.
func buff_value() -> float:
	return float(data.get("buff", 0.0)) * effect_mult() * float(spec_val("buff_x", 1.0))


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
	rate *= (1.0 + bonus) * (1.0 + pack_bonus()) * float(spec_val("rate_x", 1.0))
	if Run.has_family("strateges", 2):
		rate *= 1.0 + Jokers.STRATEGES_RATE
	if rivalry():
		rate *= Difficulty.RIVALRY_RATE
	return rate


## Difficulté « Rivalité des ateliers » : trop de tours identiques tirent moins vite.
func rivalry() -> bool:
	if not Difficulty.active("rivalite"):
		return false
	var same := 0
	for t in level.towers.values():
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.type_id == type_id:
			same += 1
	return same >= Difficulty.RIVALRY_FROM


## Esprit de meute : +10 % de cadence par autre tour du même type, plafonné.
func pack_bonus() -> float:
	if not Run.has_joker("meute"):
		return 0.0
	var same := 0
	for t in level.towers.values():
		if t != self and is_instance_valid(t) and not t.is_queued_for_deletion() and t.type_id == type_id:
			same += 1
	return minf(same * Jokers.MEUTE_PER_TOWER, Jokers.MEUTE_MAX)


func _damage() -> float:
	var dmg: float = data["damage"]
	dmg *= (1.0 + relic_bonus("damage")) * float(legendary("damage_x", 1.0)) * Profile.damage_mult()
	dmg *= tier_power() * float(spec_val("damage_x", 1.0)) * (1.0 + rage_bonus())
	if Run.has_joker("cul_de_sac") and level.blocked_neighbors(cell) >= 3:
		dmg *= 2.0
	if Run.has_family("batisseurs", 3):
		dmg *= 1.0 + Jokers.BATISSEURS_WALL_DAMAGE * level.blocked_neighbors(cell)
	return dmg


## Multiplicateur de dégâts des reliques (utilisé pour le poison).
func _damage_mult() -> float:
	return (1.0 + relic_bonus("damage")) * float(legendary("damage_x", 1.0)) * Profile.damage_mult()


func _poison_dps() -> float:
	return float(data["poison_dps"]) * _damage_mult() * effect_mult() * float(spec_val("poison_x", 1.0)) * (1.0 + rage_bonus())


func _slow() -> Array:
	var slow: float = data["slow"]
	var slow_time: float = float(data["slow_time"]) * effect_mult()
	if Run.has_joker("givre_eternel"):
		slow = 0.35
		slow_time *= 2.0
	slow = minf(slow, float(spec_val("deep_slow", 1.0)))
	return [slow, slow_time]


func _splash_radius() -> float:
	return float(data["splash_radius"]) * (1.5 if Run.has_joker("artilleur") else 1.0) * effect_mult() * float(spec_val("radius_x", 1.0))


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
			if spec_val("pierce", false):
				# Perce-rangs : touche tout ce qui est sur la trajectoire, jusqu'à la portée
				var end := global_position + (target.global_position - global_position).normalized() * range_px()
				shot_target = end - global_position
				for e in level.enemies.duplicate():
					if e != target and is_instance_valid(e) and not e.dead \
							and Geometry2D.get_closest_point_to_segment(e.global_position, global_position, end).distance_to(e.global_position) <= 18.0:
						e.take_damage(_damage())
			var harpoon: Variant = spec_val("harpoon")
			if harpoon != null:
				target.apply_slow(harpoon[0], harpoon[1])
			has_echo = false
			if Run.has_joker("echo"):
				var second := _closest_other(target)
				if second:
					has_echo = true
					echo_target = second.global_position - global_position
					second.take_damage(_damage() * (1.0 if Run.has_duo("arsenal") else ECHO_DAMAGE))
			target.take_damage(_damage())
		"splash":
			var target := _find_target(data.get("min_range", 0.0))
			if target == null:
				return false
			_show_shot(target)
			var center := target.global_position
			var fire: Variant = spec_val("fire")
			for e in level.enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.global_position.distance_to(center) <= _splash_radius():
					if fire != null:
						e.apply_poison(fire[0] * _damage_mult() * tier_power(), fire[1])
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
			_poison(target)
			var cloud: float = spec_val("cloud", 0.0)
			if cloud > 0.0:
				for e in level.enemies:
					if e != target and is_instance_valid(e) and not e.dead and e.global_position.distance_to(target.global_position) <= cloud:
						_poison(e)
	return true


## Empoisonne un ennemi (et le rend vulnérable avec la spécialisation Acide).
func _poison(e: Enemy) -> void:
	e.apply_poison(_poison_dps(), data["poison_time"])
	if Run.has_duo("cryotoxine"):
		e.apply_slow(Jokers.CRYOTOXINE_SLOW, data["poison_time"])
	var acid: float = spec_val("acid", 0.0)
	if acid > 0.0:
		e.acid = acid


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
				_poison(e)
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
		if spec_val("strongest", false):
			if e.hp > best.hp:
				best = e
		elif e.remaining_steps() < best.remaining_steps():
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

	# Niveau de la tour : un chevron doré par niveau au-dessus du premier
	for k in tier - 1:
		var x := s / 2 - 6 - k * 9
		draw_colored_polygon(PackedVector2Array([Vector2(x - 4, -s / 2 + 7), Vector2(x, -s / 2 + 2), Vector2(x + 4, -s / 2 + 7)]), Color("ffd54a"))
	if spec != "":
		draw_string(ThemeDB.fallback_font, Vector2(-s / 2 + 2, -s / 2 + 11), spec.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffd54a"))

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
