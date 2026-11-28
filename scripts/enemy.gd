class_name Enemy
extends Node2D
## Un ennemi : suit le chemin calculé par AStarGrid2D jusqu'à la sortie.

signal died(enemy: Enemy)
signal reached_goal(enemy: Enemy)
signal phase_changed(enemy: Enemy)   # boss : passe en phase 2

var type_id := ""
var data: Dictionary = {}
var astar: AStarGrid2D
var goal: Vector2i
var ice: Dictionary = {}     # cases gelées du niveau (partagé avec level.gd)
var walls: Dictionary = {}   # murs du niveau (pour dessiner un fouisseur sous un mur)
var max_hp := 30.0
var hp := 30.0
var speed := 70.0            # pixels par seconde
var next_cell: Vector2i      # case vers laquelle l'ennemi marche en ce moment
var path: Array[Vector2i] = []   # cases restantes après next_cell
var dead := false

# Effets en cours
var slow_factor := 1.0       # 0.5 = deux fois plus lent
var slow_time := 0.0
var poison_dps := 0.0        # dégâts par seconde
var poison_time := 0.0
var venin := false           # joker « Venin glacé »
var alchemy := false         # clan Alchimistes 3 : ralenti + empoisonné = +25 % de dégâts
var hp_mult := 1.0           # multiplicateur de PV de la vague (sans le bonus d'élite)
var elite := false           # difficulté « Élites errants » : plus de PV, coûte 1 vie de plus
var acid := 0.0              # spécialisation Acide : dégâts subis en plus tant qu'il est empoisonné
var regen := 0.0             # difficulté « Chair maudite » : part des PV regagnée par seconde
var others: Array = []       # tous les ennemis du niveau (pour l'embaumeur)
var towers: Dictionary = {}  # toutes les tours du niveau (pour le pilleur)
var phase := 1               # boss : 2 sous la moitié des PV
var ability_timer := 1.0     # soin / sabotage
var heal_flash := 0.0        # affichage du soin
var sabotage_line := Vector2.ZERO
var sabotage_flash := 0.0
## Sprites des ennemis (art/sources/ennemis/*.svg). Ceux de TURNING regardent où ils vont,
## les autres restent debout et se dandinent en marchant.
const SPRITES := {
	"eclaireur": preload("res://art/sprites/ennemis/eclaireur.png"),
	"rapide": preload("res://art/sprites/ennemis/rapide.png"),
	"colosse": preload("res://art/sprites/ennemis/colosse.png"),
	"fouisseur": preload("res://art/sprites/ennemis/fouisseur.png"),
	"jarre": preload("res://art/sprites/ennemis/jarre.png"),
	"larve": preload("res://art/sprites/ennemis/larve.png"),
	"ibis": preload("res://art/sprites/ennemis/ibis.png"),
	"embaumeur": preload("res://art/sprites/ennemis/embaumeur.png"),
	"pilleur": preload("res://art/sprites/ennemis/pilleur.png"),
	"scarabee": preload("res://art/sprites/ennemis/scarabee.png"),
	"colosse_gele": preload("res://art/sprites/ennemis/colosse_gele.png"),
}
const TURNING := ["rapide", "fouisseur", "larve", "ibis", "scarabee"]
const SPRITE_SCALE := 3.0   # taille du sprite = rayon × 3

var last_hit: Node = null    # dernière tour qui l'a touché (bilan de fin de niveau)
var poison_source: Node = null


func setup(id: String, grid_astar: AStarGrid2D, start: Vector2i, goal_cell: Vector2i, hp_mult: float, speed_mult: float) -> void:
	type_id = id
	data = EnemyTypes.get_type(id)
	astar = grid_astar
	goal = goal_cell
	self.hp_mult = hp_mult
	max_hp = data["hp"] * hp_mult
	hp = max_hp
	speed = data["speed"] * speed_mult
	next_cell = start
	position = Grid.cell_to_world(start)
	if data.has("sabotage"):
		ability_timer = data["sabotage"][2] * 0.5
	repath()


## Transforme l'ennemi en élite (difficulté).
func make_elite(hp_factor: float) -> void:
	elite = true
	max_hp *= hp_factor
	hp = max_hp


## Vies perdues si l'ennemi atteint la sortie.
func lives_cost() -> int:
	return int(data["damage"]) + (1 if elite else 0)


func digs() -> bool:
	return data.get("digs", false)


func is_boss() -> bool:
	return data.get("boss", false)


func flies() -> bool:
	return data.get("flies", false)


## Recalcule le chemin. Appelé à chaque fois que la grille change.
## On part de la case visée pour que l'ennemi ne fasse jamais demi-tour au milieu d'une case.
func repath() -> void:
	if flies():
		next_cell = goal  # vole tout droit, les murs ne changent rien
		path.clear()
		return
	var new_path: Array[Vector2i] = astar.get_id_path(next_cell, goal)
	if new_path.is_empty() and next_cell != goal:
		return  # aucun chemin (cas très rare) : on garde l'ancien
	if new_path.size() > 0:
		new_path.remove_at(0)  # le premier élément est next_cell elle-même
	path = new_path


func _process(delta: float) -> void:
	_update_effects(delta)
	if dead:
		return
	var current_speed := speed * slow_factor
	if ice.has(Grid.world_to_cell(position)) and not flies():
		current_speed *= 2.0  # ça glisse !
	var target := Grid.cell_to_world(next_cell)
	var step := current_speed * delta
	if position.distance_to(target) <= step:
		position = target
		if next_cell == goal:
			reached_goal.emit(self)
			return
		if path.size() > 0:
			next_cell = path.pop_front()
	else:
		position = position.move_toward(target, step)
	queue_redraw()


func _update_effects(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
	if poison_time > 0.0:
		poison_time -= delta
		var dps := poison_dps * (2.0 if venin and slow_time > 0.0 else 1.0)
		take_damage(dps * delta, poison_source)
		if poison_time <= 0.0:
			poison_dps = 0.0
	elif regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * regen * delta)
	heal_flash = maxf(0.0, heal_flash - delta)
	sabotage_flash = maxf(0.0, sabotage_flash - delta)
	if data.has("heal") or data.has("sabotage"):
		ability_timer -= delta
		if ability_timer <= 0.0:
			if data.has("heal"):
				ability_timer = 1.0
				_heal_others()
			else:
				ability_timer = data["sabotage"][2]
				_sabotage()


## Embaumeur : soigne les ennemis proches (pas lui-même, pas les empoisonnés).
func _heal_others() -> void:
	var healed := false
	for e in others:
		if e == self or not is_instance_valid(e) or e.dead or e.is_poisoned() or e.hp >= e.max_hp:
			continue
		if e.position.distance_to(position) <= data["heal_range"]:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * data["heal"])
			e.heal_flash = 0.4
			healed = true
	if healed:
		heal_flash = 0.6


## Pilleur : bloque la tour la plus proche à portée.
func _sabotage() -> void:
	var best: Node2D = null
	var best_d: float = data["sabotage"][0]
	for t in towers.values():
		if not is_instance_valid(t) or t.is_queued_for_deletion():
			continue
		var d := position.distance_to(t.position)
		if d <= best_d:
			best = t
			best_d = d
	if best == null:
		ability_timer = 0.5  # personne à portée : on réessaie vite
		return
	best.jam(data["sabotage"][1])
	sabotage_line = best.position - position
	sabotage_flash = 0.35


## source = la tour qui inflige les dégâts (pour le bilan), ou null.
func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	if acid > 0.0 and poison_time > 0.0:
		amount *= 1.0 + acid
	if alchemy and poison_time > 0.0 and slow_time > 0.0:
		amount *= 1.0 + Jokers.ALCHIMISTES_DAMAGE
	if source != null and is_instance_valid(source):
		source.dealt += minf(amount, maxf(hp, 0.0))
		last_hit = source
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)
	elif phase == 1 and data.has("phase2") and hp <= max_hp * 0.5:
		phase = 2
		speed *= float(data["phase2"]["speed_x"])
		phase_changed.emit(self)


## Ralentit l'ennemi. Le ralentissement le plus fort l'emporte, il ne se cumule pas.
func apply_slow(factor: float, duration: float) -> void:
	if is_boss():
		factor = lerpf(factor, 1.0, 0.5)  # les boss résistent à moitié
	slow_factor = minf(slow_factor, factor)
	slow_time = maxf(slow_time, duration)


## Empoisonne l'ennemi. Un nouveau poison remplace l'ancien s'il est plus fort.
func apply_poison(dps: float, duration: float, source: Node = null) -> void:
	if dps >= poison_dps:
		poison_source = source
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)


func is_poisoned() -> bool:
	return poison_time > 0.0


## Nombre de cases avant la sortie (sert aux tours à viser le plus avancé).
func remaining_steps() -> int:
	if flies():
		return int(position.distance_to(Grid.cell_to_world(goal)) / Grid.CELL)
	return path.size()


func _draw() -> void:
	var r: float = data["radius"]
	var body: Color = data["color"]
	if is_poisoned():
		body = body.lerp(Color("6aa84f"), 0.5)
	var under_wall := digs() and walls.has(Grid.world_to_cell(position))
	if under_wall:
		body.a = 0.45  # le fouisseur est sous terre
	var edge := body.darkened(0.5)

	if SPRITES.has(type_id):
		_draw_sprite(r, under_wall)
	else:
		_draw_shape(r, body, edge)

	if data["shape"] == "healer" and heal_flash > 0.0:
		draw_arc(Vector2.ZERO, data["heal_range"] * (1.0 - heal_flash * 0.5), 0.0, TAU, 40, Color(0.5, 1.0, 0.8, heal_flash * 0.5), 2.0)
	if data["shape"] == "saboteur" and sabotage_flash > 0.0:
		draw_line(Vector2.ZERO, sabotage_line, Color(0.75, 0.55, 1.0, sabotage_flash * 2.5), 3.0)
	_draw_status(r)


## Ennemi en sprite : ombre au sol, puis l'image, tournée vers sa route ou qui se dandine.
func _draw_sprite(r: float, under_wall: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 97) * 0.13
	var size := r * SPRITE_SCALE
	var fly := flies()
	if is_boss() and phase == 2:
		draw_circle(Vector2.ZERO, r + 12, Color(1, 0.3, 0.2, 0.18 + 0.1 * sin(t * 8.0)))
	# ombre (plus loin et plus petite pour les volants)
	var shadow_at := Vector2(6, r * 0.9) if fly else Vector2(1, r * 0.6)
	var shadow := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		shadow.append(shadow_at + Vector2(cos(a) * r * (0.7 if fly else 0.95), sin(a) * r * 0.35))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.12 if under_wall else 0.25))
	var angle := 0.0
	var scale := Vector2.ONE
	if type_id in TURNING:
		var target := Grid.cell_to_world(goal if fly else next_cell)
		var dir := target - position
		angle = dir.angle() if dir.length() > 0.5 else 0.0
		if fly:
			scale.y = 0.75 + 0.25 * sin(t * 12.0)  # battements d'ailes
	else:
		angle = sin(t * 7.0) * 0.08  # se dandine
	var tint := Color.WHITE
	if is_poisoned():
		tint = Color(0.7, 1.0, 0.6)
	if under_wall:
		tint.a = 0.45  # le fouisseur est sous terre
	draw_set_transform(Vector2(0, -2), angle, scale)
	draw_texture_rect(SPRITES[type_id], Rect2(-size / 2.0, -size / 2.0, size, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ancien dessin par formes (ennemis sans sprite).
func _draw_shape(r: float, body: Color, edge: Color) -> void:
	match data["shape"]:
		"triangle":
			var dir := (Grid.cell_to_world(next_cell) - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var side := dir.orthogonal()
			var pts := PackedVector2Array([dir * r * 1.2, -dir * r + side * r, -dir * r - side * r])
			draw_colored_polygon(pts, body)
		"square":
			draw_rect(Rect2(-r, -r, r * 2, r * 2), body)
			draw_rect(Rect2(-r, -r, r * 2, r * 2), edge, false, 2.0)
		"digger":
			draw_circle(Vector2.ZERO, r, body)
			for k in [-1, 1]:
				draw_line(Vector2(-r * 0.7, k * r * 0.35), Vector2(r * 0.7, k * r * 0.35), edge, 2.0)
		"jar":
			# Jarre ventrue avec un col et un couvercle
			draw_circle(Vector2(0, r * 0.15), r * 0.85, body)
			draw_arc(Vector2(0, r * 0.15), r * 0.85, 0.0, TAU, 24, edge, 2.0)
			draw_rect(Rect2(-r * 0.4, -r, r * 0.8, r * 0.45), body)
			draw_rect(Rect2(-r * 0.55, -r * 1.05, r * 1.1, r * 0.22), edge)
			draw_line(Vector2(-r * 0.6, r * 0.15), Vector2(r * 0.6, r * 0.15), edge, 2.0)
		"larva":
			# Petite larve en trois segments, orientée vers où elle va
			var dir := (Grid.cell_to_world(next_cell) - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			for k in 3:
				draw_circle(dir * r * (0.7 - k * 0.7), r * (0.75 - k * 0.15), body if k > 0 else body.darkened(0.2))
		"bird":
			# Oiseau momifié vu de dessus : deux ailes qui battent, un bec
			var dir := (Grid.cell_to_world(goal) - position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			var side := dir.orthogonal()
			var flap := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 90.0)
			draw_circle(Vector2(4, 8), r * 0.7, Color(0, 0, 0, 0.18))  # ombre au sol
			for k in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([side * k * r * 0.3, side * k * r * 1.5 * flap - dir * r * 0.5, -dir * r * 0.5 + side * k * r * 0.2]), body)
			draw_circle(Vector2.ZERO, r * 0.45, body)
			draw_colored_polygon(PackedVector2Array([dir * r * 0.35 + side * 3, dir * r * 1.1, dir * r * 0.35 - side * 3]), Color("2b2b2b"))
			for k in 2:
				draw_line(side * (k * 4 - 2) - dir * 2, side * (k * 4 - 2) + dir * 2, edge, 1.0)
		"healer":
			draw_circle(Vector2.ZERO, r, body)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0)
			draw_rect(Rect2(-r * 0.18, -r * 0.6, r * 0.36, r * 1.2), Color("eafff6"))
			draw_rect(Rect2(-r * 0.6, -r * 0.18, r * 1.2, r * 0.36), Color("eafff6"))
		"saboteur":
			# Pilleur encapuchonné avec un sac
			draw_circle(Vector2.ZERO, r, body)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0)
			draw_circle(Vector2(0, -r * 0.15), r * 0.5, edge)
			draw_circle(Vector2(-r * 0.18, -r * 0.2), 2.0, Color("ffe066"))
			draw_circle(Vector2(r * 0.18, -r * 0.2), 2.0, Color("ffe066"))
			draw_circle(Vector2(r * 0.75, r * 0.5), r * 0.4, Color("a08455"))
		"boss":
			if phase == 2:
				draw_circle(Vector2.ZERO, r + 12, Color(1, 0.3, 0.2, 0.18 + 0.1 * sin(Time.get_ticks_msec() / 120.0)))
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(Vector2.from_angle(a) * r, Vector2.from_angle(a) * (r + 7), edge, 4.0)
			draw_circle(Vector2.ZERO, r, body)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, edge, 3.0)
			draw_circle(Vector2(-r * 0.35, -r * 0.2), r * 0.16, Color("ffe066"))
			draw_circle(Vector2(r * 0.35, -r * 0.2), r * 0.16, Color("ffe066"))
		_:
			draw_circle(Vector2.ZERO, r, body)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0)



## Anneaux d'état et barre de vie, communs à tous les ennemis.
func _draw_status(r: float) -> void:
	if heal_flash > 0.0 and data["shape"] != "healer":
		draw_string(ThemeDB.fallback_font, Vector2(r * 0.6, -r - 2), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1.0, 0.7, heal_flash * 2.0))
	if elite:
		draw_arc(Vector2.ZERO, r + 6, 0.0, TAU, 28, Color("ffd54a"), 2.5)
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, r + 3, 0.0, TAU, 24, Color("7fd6e8"), 3.0)

	# Barre de vie
	var w := maxf(30.0, r * 2.2)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, -r - 10, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, -r - 10, w * ratio, 5), Color("6fd36a"))
