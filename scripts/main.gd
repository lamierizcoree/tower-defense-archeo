extends Node2D
## Scène principale du prototype : la grille, les murs, les vagues et l'interface.
##
## Contrôles :
##   Clic gauche  : poser (un mur, ou une tour sur un mur)
##   Clic droit   : retirer une tour, sinon un mur
##   1            : mode Mur
##   2 à 7        : choisir une tour (voir tower_types.gd)
##   Espace       : lancer la vague suivante
##   R            : recommencer

const WALL_COST := 2
const KILL_REWARD := 3
const WAVE_BONUS := 10
const SPAWN_INTERVAL := 0.8

var astar := AStarGrid2D.new()
var walls := {}                  # Vector2i -> true
var towers := {}                 # Vector2i -> Tower
var enemies: Array[Enemy] = []
var path_preview: Array[Vector2i] = []

var gold := 60
var lives := 20
var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var selected := ""   # "" = mur, sinon l'identifiant de la tour choisie
var game_over := false
var message := ""
var message_time := 0.0


func _ready() -> void:
	astar.region = Rect2i(0, 0, Grid.COLS, Grid.ROWS)
	astar.cell_size = Vector2(Grid.CELL, Grid.CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # déplacements en croix uniquement
	astar.update()
	_refresh_path()
	_say("Pose des murs pour allonger le chemin, puis Espace")


# --- Boucle de jeu -----------------------------------------------------------

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
	if not game_over and to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_enemy()
			to_spawn -= 1
			spawn_timer = SPAWN_INTERVAL
	queue_redraw()


func _start_wave() -> void:
	if game_over:
		return
	if to_spawn > 0 or not enemies.is_empty():
		_say("Une vague est déjà en cours")
		return
	wave += 1
	to_spawn = 5 + wave * 2
	spawn_timer = 0.0
	_say("Vague %d !" % wave)


func _spawn_enemy() -> void:
	var e := Enemy.new()
	e.setup(astar, Grid.SPAWN, 30.0 + wave * 12.0, 70.0 + wave * 3.0)
	e.died.connect(_on_enemy_died)
	e.reached_goal.connect(_on_enemy_reached_goal)
	enemies.append(e)
	add_child(e)


func _on_enemy_died(e: Enemy) -> void:
	gold += KILL_REWARD
	_remove_enemy(e)


func _on_enemy_reached_goal(e: Enemy) -> void:
	lives -= 1
	if lives <= 0:
		lives = 0
		game_over = true
		for other in enemies:
			other.set_process(false)
		_say("Défaite ! Appuie sur R pour recommencer", 9999.0)
	_remove_enemy(e)


func _remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	e.queue_free()
	if not game_over and to_spawn == 0 and enemies.is_empty() and wave > 0:
		gold += WAVE_BONUS
		# Plus tard : c'est ici qu'on proposera le choix d'un joker.
		_say("Vague %d terminée ! +%d or" % [wave, WAVE_BONUS])


# --- Construction ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				selected = ""
			KEY_SPACE:
				_start_wave()
			KEY_R:
				get_tree().reload_current_scene()
		for id in TowerTypes.ORDER:
			if event.keycode == TowerTypes.get_type(id)["key"]:
				selected = id
		return

	if game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		var cell := Grid.world_to_cell(get_global_mouse_position())
		if not Grid.in_bounds(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if selected == "":
				_try_place_wall(cell)
			else:
				_try_place_tower(cell, selected)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_at(cell)


func _try_place_wall(cell: Vector2i) -> void:
	if walls.has(cell):
		return
	if cell == Grid.SPAWN or cell == Grid.GOAL:
		_say("Impossible de construire ici")
		return
	if gold < WALL_COST:
		_say("Pas assez d'or")
		return
	if _cell_has_enemy(cell):
		_say("Un ennemi est sur cette case")
		return

	# On essaie le mur, et on l'annule s'il bloque complètement le passage.
	astar.set_point_solid(cell, true)
	if not _every_path_open():
		astar.set_point_solid(cell, false)
		_say("Ce mur bloquerait le chemin")
		return

	walls[cell] = true
	gold -= WALL_COST
	_on_grid_changed()


func _try_place_tower(cell: Vector2i, id: String) -> void:
	if not walls.has(cell):
		_say("Une tour se pose sur un mur")
		return
	if towers.has(cell):
		_say("Il y a déjà une tour ici")
		return
	var cost: int = TowerTypes.get_type(id)["cost"]
	if gold < cost:
		_say("Pas assez d'or")
		return
	var t := Tower.new()
	t.setup(id)
	t.cell = cell
	t.enemies = enemies
	t.towers = towers
	t.position = Grid.cell_to_world(cell)
	towers[cell] = t
	add_child(t)
	gold -= cost


func _remove_at(cell: Vector2i) -> void:
	if towers.has(cell):
		var t: Tower = towers[cell]
		gold += int(t.data["cost"]) / 2  # on récupère la moitié du prix
		t.queue_free()
		towers.erase(cell)
	elif walls.has(cell):
		walls.erase(cell)
		astar.set_point_solid(cell, false)
		gold += WALL_COST
		_on_grid_changed()


## Vérifie qu'il reste un chemin depuis l'entrée ET depuis chaque ennemi déjà en route.
func _every_path_open() -> bool:
	if astar.get_id_path(Grid.SPAWN, Grid.GOAL).is_empty():
		return false
	for e in enemies:
		if astar.get_id_path(e.next_cell, Grid.GOAL).is_empty():
			return false
	return true


func _cell_has_enemy(cell: Vector2i) -> bool:
	for e in enemies:
		if e.next_cell == cell or Grid.world_to_cell(e.position) == cell:
			return true
	return false


## Appelé après chaque mur posé ou retiré : tout le monde recalcule son chemin.
func _on_grid_changed() -> void:
	_refresh_path()
	for e in enemies:
		e.repath()


func _refresh_path() -> void:
	path_preview = astar.get_id_path(Grid.SPAWN, Grid.GOAL)


func _say(text: String, duration := 2.5) -> void:
	message = text
	message_time = duration


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var c := float(Grid.CELL)

	# Fond
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("2b2420"))

	# Cases (couleurs façon désert)
	for x in Grid.COLS:
		for y in Grid.ROWS:
			var r := Rect2(Grid.OFFSET + Vector2(x, y) * c, Vector2(c, c))
			var sand := Color("e0c38c") if (x + y) % 2 == 0 else Color("d8b981")
			draw_rect(r, sand)

	# Chemin actuel des ennemis
	for cell in path_preview:
		draw_circle(Grid.cell_to_world(cell), 4.0, Color(0.55, 0.2, 0.15, 0.5))

	# Entrée (vert) et sortie (violet)
	_draw_cell(Grid.SPAWN, Color("4caf50"))
	_draw_cell(Grid.GOAL, Color("8e44ad"))

	# Murs
	for cell in walls:
		var r := Rect2(Grid.OFFSET + Vector2(cell) * c, Vector2(c, c)).grow(-2)
		draw_rect(r, Color("6b5a45"))
		draw_rect(r, Color("43382b"), false, 2.0)

	# Case survolée + aperçu de la portée d'une tour
	var hover := Grid.world_to_cell(get_global_mouse_position())
	if Grid.in_bounds(hover) and not game_over:
		var hr := Rect2(Grid.OFFSET + Vector2(hover) * c, Vector2(c, c))
		draw_rect(hr, Color(1, 1, 1, 0.8), false, 2.0)
		var preview_range := 0.0
		if towers.has(hover):
			preview_range = towers[hover].range_px()
		elif selected != "":
			preview_range = TowerTypes.get_type(selected)["range"]
		if preview_range > 0.0:
			draw_arc(Grid.cell_to_world(hover), preview_range, 0.0, TAU, 48, Color(0.25, 0.5, 0.82, 0.7), 2.0)

	# Textes
	var mode_name := "Mur (%d or)" % WALL_COST
	if selected != "":
		var d := TowerTypes.get_type(selected)
		mode_name = "%s (%d or) : %s" % [d["name"], d["cost"], d["desc"]]
	var hud := "Or : %d   Vies : %d   Vague : %d   %s" % [gold, lives, wave, mode_name]
	draw_string(font, Vector2(12, 26), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var help := "Clic gauche : poser   Clic droit : retirer   Espace : vague   R : recommencer"
	draw_string(font, Vector2(12, 52), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	if message_time > 0.0:
		draw_string(font, Vector2(620, 52), message, HORIZONTAL_ALIGNMENT_LEFT, 330, 15, Color("ffe066"))

	_draw_build_bar(font)


## Barre du bas : les choix de construction, avec leur touche et leur prix.
func _draw_build_bar(font: Font) -> void:
	var top := Grid.OFFSET.y + Grid.ROWS * Grid.CELL
	var slot_w := 960.0 / 7.0
	var entries := [["", "1 Mur", WALL_COST, Color("6b5a45")]]
	for i in TowerTypes.ORDER.size():
		var id: String = TowerTypes.ORDER[i]
		var d := TowerTypes.get_type(id)
		entries.append([id, "%d %s" % [i + 2, d["name"]], d["cost"], d["color"]])
	for i in entries.size():
		var e: Array = entries[i]
		var r := Rect2(i * slot_w + 3, top + 4, slot_w - 6, 40)
		var active: bool = e[0] == selected
		draw_rect(r, Color(1, 1, 1, 0.15) if active else Color(1, 1, 1, 0.05))
		if active:
			draw_rect(r, Color("ffe066"), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(6, 12), Vector2(16, 16)), e[3])
		var can_pay := gold >= int(e[2])
		var text_color := Color.WHITE if can_pay else Color(1, 1, 1, 0.4)
		draw_string(font, r.position + Vector2(28, 18), e[1], HORIZONTAL_ALIGNMENT_LEFT, slot_w - 34, 14, text_color)
		draw_string(font, r.position + Vector2(28, 34), "%d or" % e[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


func _draw_cell(cell: Vector2i, color: Color) -> void:
	var r := Rect2(Grid.OFFSET + Vector2(cell) * Grid.CELL, Vector2(Grid.CELL, Grid.CELL)).grow(-4)
	draw_rect(r, color)
