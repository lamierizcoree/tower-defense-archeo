class_name Enemy
extends Node2D
## Un ennemi : suit le chemin calculé par AStarGrid2D jusqu'à la sortie.

signal died(enemy: Enemy)
signal reached_goal(enemy: Enemy)

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


func setup(id: String, grid_astar: AStarGrid2D, start: Vector2i, goal_cell: Vector2i, hp_mult: float, speed_mult: float) -> void:
	type_id = id
	data = EnemyTypes.get_type(id)
	astar = grid_astar
	goal = goal_cell
	max_hp = data["hp"] * hp_mult
	hp = max_hp
	speed = data["speed"] * speed_mult
	next_cell = start
	position = Grid.cell_to_world(start)
	repath()


func digs() -> bool:
	return data.get("digs", false)


func is_boss() -> bool:
	return data.get("boss", false)


## Recalcule le chemin. Appelé à chaque fois que la grille change.
## On part de la case visée pour que l'ennemi ne fasse jamais demi-tour au milieu d'une case.
func repath() -> void:
	var new_path: Array[Vector2i] = astar.get_id_path(next_cell, goal)
	if new_path.size() > 0:
		new_path.remove_at(0)  # le premier élément est next_cell elle-même
	path = new_path


func _process(delta: float) -> void:
	_update_effects(delta)
	if dead:
		return
	var current_speed := speed * slow_factor
	if ice.has(Grid.world_to_cell(position)):
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
		take_damage(dps * delta)
		if poison_time <= 0.0:
			poison_dps = 0.0


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)


## Ralentit l'ennemi. Le ralentissement le plus fort l'emporte, il ne se cumule pas.
func apply_slow(factor: float, duration: float) -> void:
	if is_boss():
		factor = lerpf(factor, 1.0, 0.5)  # les boss résistent à moitié
	slow_factor = minf(slow_factor, factor)
	slow_time = maxf(slow_time, duration)


## Empoisonne l'ennemi. Un nouveau poison remplace l'ancien s'il est plus fort.
func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)


func is_poisoned() -> bool:
	return poison_time > 0.0


## Nombre de cases avant la sortie (sert aux tours à viser le plus avancé).
func remaining_steps() -> int:
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
		"boss":
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

	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, r + 3, 0.0, TAU, 24, Color("7fd6e8"), 3.0)

	# Barre de vie
	var w := maxf(30.0, r * 2.2)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, -r - 10, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, -r - 10, w * ratio, 5), Color("6fd36a"))
