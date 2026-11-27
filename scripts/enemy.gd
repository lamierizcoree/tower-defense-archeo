class_name Enemy
extends Node2D
## Un ennemi : suit le chemin calculé par AStarGrid2D jusqu'à l'objectif.

signal died(enemy: Enemy)
signal reached_goal(enemy: Enemy)

const RADIUS := 14.0

var astar: AStarGrid2D
var max_hp := 30.0
var hp := 30.0
var speed := 70.0           # pixels par seconde
var next_cell: Vector2i     # case vers laquelle l'ennemi marche en ce moment
var path: Array[Vector2i] = []  # cases restantes après next_cell
var dead := false

# Effets en cours
var slow_factor := 1.0      # 0.5 = deux fois plus lent
var slow_time := 0.0
var poison_dps := 0.0       # dégâts par seconde
var poison_time := 0.0


func setup(grid_astar: AStarGrid2D, start: Vector2i, hp_value: float, speed_value: float) -> void:
	astar = grid_astar
	max_hp = hp_value
	hp = hp_value
	speed = speed_value
	next_cell = start
	position = Grid.cell_to_world(start)
	repath()


## Recalcule le chemin. Appelé à chaque fois qu'un mur est posé ou retiré.
## On part de la case visée pour que l'ennemi ne fasse jamais demi-tour au milieu d'une case.
func repath() -> void:
	var new_path: Array[Vector2i] = astar.get_id_path(next_cell, Grid.GOAL)
	if new_path.size() > 0:
		new_path.remove_at(0)  # le premier élément est next_cell elle-même
	path = new_path


func _process(delta: float) -> void:
	_update_effects(delta)
	if dead:
		return
	var target := Grid.cell_to_world(next_cell)
	var step := speed * slow_factor * delta
	if position.distance_to(target) <= step:
		position = target
		if next_cell == Grid.GOAL:
			reached_goal.emit(self)
			return
		if path.size() > 0:
			next_cell = path.pop_front()
	else:
		position = position.move_toward(target, step)
	queue_redraw()


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)


func _update_effects(delta: float) -> void:
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
	if poison_time > 0.0:
		poison_time -= delta
		take_damage(poison_dps * delta)
		if poison_time <= 0.0:
			poison_dps = 0.0


## Ralentit l'ennemi. Le ralentissement le plus fort l'emporte, il ne se cumule pas.
func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_time = maxf(slow_time, duration)


## Empoisonne l'ennemi. Un nouveau poison remplace l'ancien s'il est plus fort.
func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)


func is_poisoned() -> bool:
	return poison_time > 0.0


## Nombre de cases avant l'objectif (sert aux tours à viser le plus avancé).
func remaining_steps() -> int:
	return path.size()


func _draw() -> void:
	var body := Color("c94a3d")
	if is_poisoned():
		body = body.lerp(Color("6aa84f"), 0.5)
	draw_circle(Vector2.ZERO, RADIUS, body)
	if slow_time > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 3, 0.0, TAU, 24, Color("7fd6e8"), 3.0)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("5a1f1a"), 2.0)
	# Barre de vie
	var w := 30.0
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2, -RADIUS - 9, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, -RADIUS - 9, w * ratio, 5), Color("6fd36a"))
