class_name Tower
extends Node2D
## Une tour à cible unique (future « Arbalète »). Elle se pose sur un mur.

const RANGE := 150.0       # portée en pixels
const DAMAGE := 10.0
const FIRE_DELAY := 0.6    # secondes entre deux tirs

var cell: Vector2i
var enemies: Array[Enemy] = []  # même tableau que celui de main.gd
var cooldown := 0.0
var shot_target := Vector2.ZERO
var shot_time := 0.0


func _process(delta: float) -> void:
	cooldown -= delta
	shot_time -= delta
	if cooldown <= 0.0:
		var target := _find_target()
		if target:
			shot_target = target.global_position - global_position
			shot_time = 0.08
			cooldown = FIRE_DELAY
			target.take_damage(DAMAGE)
	queue_redraw()


## Vise l'ennemi à portée le plus proche de l'objectif.
func _find_target() -> Enemy:
	var best: Enemy = null
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) > RANGE:
			continue
		if best == null or e.remaining_steps() < best.remaining_steps():
			best = e
	return best


func _draw() -> void:
	var s := Grid.CELL * 0.7
	draw_rect(Rect2(-s / 2, -s / 2, s, s), Color("3f7fd1"))
	draw_rect(Rect2(-s / 2, -s / 2, s, s), Color("1d3d66"), false, 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color("cfe3ff"))
	if shot_time > 0.0:
		draw_line(Vector2.ZERO, shot_target, Color("ffe066"), 3.0)
