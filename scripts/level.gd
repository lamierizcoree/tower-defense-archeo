extends Node2D
## Un niveau : la grille, les murs, les vagues et l'interface.
##
## Contrôles :
##   Clic gauche  : poser (un mur, ou une tour sur un mur)
##   Clic droit   : retirer une tour, sinon un mur
##   1            : mode Mur
##   2 à 7        : choisir une tour (voir tower_types.gd)
##   Espace       : lancer la vague suivante
##   F            : vitesse x2

const WALL_COST := 2
const KILL_REWARD := 3
const WAVE_BONUS := 10
const SPAWN_INTERVAL := 0.7
const DUNES_PER_WAVE := 4
const DIG_WEIGHT := 6.0     # un fouisseur « paie » 6 cases pour passer sous un mur
const STORM_RANGE := 0.75
const MACON_RANGE := 12.0

var node: Dictionary
var biome: Dictionary
var layout: Dictionary

var rocks := {}      # Vector2i -> true : bloquent, on ne construit pas dessus
var ice := {}        # Vector2i -> true : les ennemis y glissent
var dunes := {}      # Vector2i -> true : désert, bloquent pendant une vague
var spawns: Array[Vector2i] = []
var goal := Vector2i.ZERO

var astar := AStarGrid2D.new()       # chemin des ennemis normaux
var dig_astar := AStarGrid2D.new()   # chemin des fouisseurs, qui passent sous les murs
var walls := {}                      # Vector2i -> true
var towers := {}                     # Vector2i -> Tower
var enemies: Array[Enemy] = []
var path_previews: Array = []        # un chemin par entrée

var waves: Array = []
var wave_index := -1                 # vague en cours ou dernière jouée (-1 = aucune)
var spawn_queue: Array[String] = []
var spawn_timer := 0.0
var spawn_turn := 0
var wave_running := false
var storm := false

var gold := 0
var selected := ""   # "" = mur, sinon l'identifiant de la tour choisie
var ended := false
var message := ""
var message_time := 0.0


func _ready() -> void:
	node = Run.current_node()
	biome = Run.biome()
	layout = Levels.get_layout(node["layout"])
	_load_layout()
	waves = Levels.make_waves(Run.rng, Run.biome_index, Run.current.x, node["type"])
	gold = 70 + 5 * (Run.biome_index * 5 + Run.current.x)
	if Run.has_joker("rempart"):
		Run.lives += 2
	_shift_dunes()
	_refresh_paths()
	_say("Construis ton labyrinthe, puis appuie sur Espace")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _load_layout() -> void:
	for g in [astar, dig_astar]:
		g.region = Rect2i(0, 0, Grid.COLS, Grid.ROWS)
		g.cell_size = Vector2(Grid.CELL, Grid.CELL)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # déplacements en croix uniquement
		g.update()
	var rows: Array = layout["rows"]
	for y in Grid.ROWS:
		for x in Grid.COLS:
			var cell := Vector2i(x, y)
			match rows[y][x]:
				"#":
					rocks[cell] = true
					astar.set_point_solid(cell, true)
					dig_astar.set_point_solid(cell, true)
				"~":
					ice[cell] = true
				"S":
					spawns.append(cell)
				"G":
					goal = cell


# --- Boucle de jeu -----------------------------------------------------------

func _process(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
	if wave_running and not ended:
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy(spawn_queue.pop_front())
				spawn_timer = SPAWN_INTERVAL
		elif enemies.is_empty():
			_end_wave()
	queue_redraw()


func _start_wave() -> void:
	if ended or wave_running or wave_index >= waves.size() - 1:
		return
	wave_index += 1
	wave_running = true
	spawn_queue.assign(waves[wave_index]["enemies"])
	spawn_timer = 0.0
	storm = _is_storm(wave_index)
	if Run.has_joker("detour"):
		var bonus := 0
		for p in path_previews:
			bonus = maxi(bonus, p.size() / 3)
		gold += bonus
		_say("Vague %d ! Long détour : +%d or" % [wave_index + 1, bonus])
	else:
		_say("Vague %d !" % (wave_index + 1) + ("  Tempête de sable !" if storm else ""))


func _end_wave() -> void:
	wave_running = false
	storm = false
	if wave_index >= waves.size() - 1:
		ended = true
		_say("Niveau réussi !", 99.0)
		get_tree().create_timer(1.5).timeout.connect(Run.level_won)
		return
	gold += WAVE_BONUS
	_shift_dunes()
	_say("Vague terminée ! +%d or" % WAVE_BONUS)


func _is_storm(index: int) -> bool:
	return biome["id"] == "desert" and index % 2 == 1


func _spawn_enemy(type_id: String) -> void:
	var e := Enemy.new()
	var start := spawns[spawn_turn % spawns.size()]
	spawn_turn += 1
	var speed_mult: float = biome["enemy_speed"]
	if wave_index == 0 and Run.has_joker("sablier"):
		speed_mult *= 0.7
	var grid := dig_astar if EnemyTypes.get_type(type_id).get("digs", false) else astar
	e.setup(type_id, grid, start, goal, waves[wave_index]["hp_mult"], speed_mult)
	e.ice = ice
	e.walls = walls
	e.venin = Run.has_joker("venin")
	e.died.connect(_on_enemy_died)
	e.reached_goal.connect(_on_enemy_reached_goal)
	enemies.append(e)
	add_child(e)


func _on_enemy_died(e: Enemy) -> void:
	gold += KILL_REWARD + (2 if Run.has_joker("prime") else 0)
	Run.score += e.data["score"]
	Run.kills += 1
	var was_poisoned := e.is_poisoned()
	var where := e.global_position
	_remove_enemy(e)
	if was_poisoned and Run.has_joker("fiole"):
		for other in enemies.duplicate():
			if is_instance_valid(other) and other.global_position.distance_to(where) <= 60.0:
				other.take_damage(15.0)


func _on_enemy_reached_goal(e: Enemy) -> void:
	_remove_enemy(e)
	if ended:
		return
	Run.lives -= e.data["damage"]
	if Run.has_joker("pillard"):
		gold += 6
	if Run.lives <= 0:
		Run.lives = 0
		ended = true
		for other in enemies:
			other.set_process(false)
		_say("L'expédition est perdue...", 99.0)
		get_tree().create_timer(1.5).timeout.connect(Run.level_lost)


func _remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	e.queue_free()


# --- Dunes (désert) ----------------------------------------------------------

## Entre deux vagues, les dunes bougent : les anciennes disparaissent et de nouvelles
## recouvrent des cases libres, sans jamais fermer complètement le passage.
func _shift_dunes() -> void:
	if biome["id"] != "desert":
		return
	for cell in dunes:
		astar.set_point_solid(cell, false)
		dig_astar.set_point_solid(cell, false)
	dunes.clear()
	var tries := 0
	while dunes.size() < DUNES_PER_WAVE and tries < 200:
		tries += 1
		var cell := Vector2i(Run.rng.randi_range(0, Grid.COLS - 1), Run.rng.randi_range(0, Grid.ROWS - 1))
		if not _is_free(cell):
			continue
		astar.set_point_solid(cell, true)
		if _every_path_open():
			dunes[cell] = true
			dig_astar.set_point_solid(cell, true)
		else:
			astar.set_point_solid(cell, false)
	_on_grid_changed()


## Case vide : ni mur, ni rocher, ni dune, ni entrée, ni sortie.
func _is_free(cell: Vector2i) -> bool:
	return not (walls.has(cell) or rocks.has(cell) or dunes.has(cell) or cell in spawns or cell == goal)


# --- Construction ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				selected = ""
			KEY_SPACE:
				_start_wave()
			KEY_F:
				Engine.time_scale = 2.0 if Engine.time_scale == 1.0 else 1.0
		for id in TowerTypes.ORDER:
			if event.keycode == TowerTypes.get_type(id)["key"]:
				selected = id
		return

	if ended:
		return
	if event is InputEventMouseButton and event.pressed:
		var pos := get_global_mouse_position()
		var bar_slot := _build_bar_slot(pos)
		if bar_slot >= 0:
			selected = "" if bar_slot == 0 else TowerTypes.ORDER[bar_slot - 1]
			return
		var cell := Grid.world_to_cell(pos)
		if not Grid.in_bounds(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if selected == "":
				_try_place_wall(cell)
			else:
				_try_place_tower(cell, selected)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_remove_at(cell)


func wall_cost() -> int:
	return 1 if Run.has_joker("briques") else WALL_COST


func tower_cost(id: String) -> int:
	var cost: int = TowerTypes.get_type(id)["cost"]
	if Run.has_joker("fondations"):
		cost = int(ceil(cost * 0.75))
	return cost


func _try_place_wall(cell: Vector2i) -> void:
	if walls.has(cell):
		return
	if rocks.has(cell) or dunes.has(cell) or cell in spawns or cell == goal:
		_say("Impossible de construire ici")
		return
	if gold < wall_cost():
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
	dig_astar.set_point_weight_scale(cell, DIG_WEIGHT)
	gold -= wall_cost()
	_on_grid_changed()


func _try_place_tower(cell: Vector2i, id: String) -> void:
	if not walls.has(cell):
		_say("Une tour se pose sur un mur")
		return
	if towers.has(cell):
		_say("Il y a déjà une tour ici")
		return
	var cost := tower_cost(id)
	if gold < cost:
		_say("Pas assez d'or")
		return
	var t := Tower.new()
	t.setup(id, self, cell)
	towers[cell] = t
	add_child(t)
	gold -= cost


func _remove_at(cell: Vector2i) -> void:
	if towers.has(cell):
		var t: Tower = towers[cell]
		gold += tower_cost(t.type_id) / 2  # on récupère la moitié du prix
		t.queue_free()
		towers.erase(cell)
	elif walls.has(cell):
		walls.erase(cell)
		astar.set_point_solid(cell, false)
		dig_astar.set_point_weight_scale(cell, 1.0)
		gold += wall_cost()
		_on_grid_changed()


## Vérifie qu'il reste un chemin depuis chaque entrée ET depuis chaque ennemi déjà en route.
## Les fouisseurs ne comptent pas : ils passent sous les murs.
func _every_path_open() -> bool:
	for s in spawns:
		if astar.get_id_path(s, goal).is_empty():
			return false
	for e in enemies:
		if not e.digs() and astar.get_id_path(e.next_cell, goal).is_empty():
			return false
	return true


func _cell_has_enemy(cell: Vector2i) -> bool:
	for e in enemies:
		if e.digs():
			continue
		if e.next_cell == cell or Grid.world_to_cell(e.position) == cell:
			return true
	return false


## Appelé après chaque changement de la grille : tout le monde recalcule son chemin.
func _on_grid_changed() -> void:
	_refresh_paths()
	for e in enemies:
		e.repath()


func _refresh_paths() -> void:
	path_previews.clear()
	for s in spawns:
		path_previews.append(astar.get_id_path(s, goal))


## Nombre de côtés d'une case bloqués par un mur, un rocher, une dune ou le bord.
func blocked_neighbors(cell: Vector2i) -> int:
	var n := 0
	for d in Grid.DIRS:
		var c: Vector2i = cell + d
		if not Grid.in_bounds(c) or walls.has(c) or rocks.has(c) or dunes.has(c):
			n += 1
	return n


## Portée d'une tour à cet endroit : tempête et joker Maçon compris.
func tower_range(id: String, cell: Vector2i) -> float:
	var r: float = TowerTypes.get_type(id)["range"]
	if storm:
		r *= STORM_RANGE
	if Run.has_joker("macon"):
		var n := 0
		for d in Grid.DIRS:
			var c: Vector2i = cell + d
			if walls.has(c) or rocks.has(c):
				n += 1
		r += MACON_RANGE * n
	return r


func _say(text: String, duration := 2.5) -> void:
	message = text
	message_time = duration


# --- Dessin ------------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var colors: Dictionary = biome["colors"]

	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), colors["background"])

	# Cases
	for x in Grid.COLS:
		for y in Grid.ROWS:
			var cell := Vector2i(x, y)
			var r := Grid.cell_rect(cell)
			draw_rect(r, colors["tile_a"] if (x + y) % 2 == 0 else colors["tile_b"])
			if ice.has(cell):
				draw_rect(r, Color("9fd3ea"))
				draw_line(r.position + Vector2(10, 34), r.position + Vector2(30, 14), Color(1, 1, 1, 0.7), 2.0)
	for cell in rocks:
		# Rochers : un amas de pierres arrondies, pour ne pas les confondre avec les murs
		var c := Grid.cell_to_world(cell)
		var q := Grid.CELL * 0.25
		for p in [Vector2(-q, q * 0.5), Vector2(q, q * 0.6), Vector2(0, -q * 0.6)]:
			draw_circle(c + p, q * 1.25, colors["rock_edge"])
			draw_circle(c + p + Vector2(-1, -2), q * 1.05, colors["rock"])
	for cell in dunes:
		var center := Grid.cell_to_world(cell)
		draw_circle(center + Vector2(0, 6), Grid.CELL * 0.45, Color("c9a467"))
		draw_circle(center + Vector2(-6, 2), Grid.CELL * 0.3, Color("d9b878"))

	# Chemins actuels des ennemis
	for p in path_previews:
		for cell in p:
			draw_circle(Grid.cell_to_world(cell), 4.0, Color(0.55, 0.2, 0.15, 0.5))

	# Entrées (vert) et sortie (violet)
	for s in spawns:
		draw_rect(Grid.cell_rect(s).grow(-4), Color("4caf50"))
	draw_rect(Grid.cell_rect(goal).grow(-4), Color("8e44ad"))

	# Murs
	for cell in walls:
		var r := Grid.cell_rect(cell).grow(-2)
		draw_rect(r, Color("6b5a45"))
		draw_rect(r, Color("43382b"), false, 2.0)

	# Tempête : voile de sable
	if storm:
		draw_rect(Rect2(Grid.OFFSET, Vector2(Grid.COLS, Grid.ROWS) * Grid.CELL), Color(0.85, 0.65, 0.35, 0.18))

	# Case survolée + aperçu de la portée
	var hover := Grid.world_to_cell(get_global_mouse_position())
	if Grid.in_bounds(hover) and not ended:
		draw_rect(Grid.cell_rect(hover), Color(1, 1, 1, 0.8), false, 2.0)
		var preview_range := 0.0
		if towers.has(hover):
			preview_range = towers[hover].range_px()
		elif selected != "":
			preview_range = tower_range(selected, hover)
		if preview_range > 0.0:
			draw_arc(Grid.cell_to_world(hover), preview_range, 0.0, TAU, 48, Color(0.25, 0.5, 0.82, 0.7), 2.0)

	_draw_hud(font)
	_draw_build_bar(font)


func _draw_hud(font: Font) -> void:
	var type_names := {"combat": "", "elite": "  ·  ÉLITE", "boss": "  ·  BOSS"}
	var title := "%s · %s%s" % [biome["name"], layout["name"], type_names[node["type"]]]
	draw_string(font, Vector2(12, 24), title, HORIZONTAL_ALIGNMENT_LEFT, 470, 17, Color.WHITE)
	var stats := "Vies %d    Or %d    Vague %d/%d" % [Run.lives, gold, wave_index + 1, waves.size()]
	if Engine.time_scale > 1.0:
		stats += "    x2"
	draw_string(font, Vector2(500, 24), stats, HORIZONTAL_ALIGNMENT_LEFT, 450, 17, Color.WHITE)

	var line2 := ""
	if not wave_running and wave_index < waves.size() - 1:
		line2 = "Prochaine vague (Espace) : " + _describe_wave(wave_index + 1)
		if _is_storm(wave_index + 1):
			line2 += "  ·  tempête"
	elif wave_running:
		line2 = "Restants : %d" % (spawn_queue.size() + enemies.size())
	draw_string(font, Vector2(12, 50), line2, HORIZONTAL_ALIGNMENT_LEFT, 600, 14, Color(1, 1, 1, 0.75))
	if message_time > 0.0:
		draw_string(font, Vector2(630, 50), message, HORIZONTAL_ALIGNMENT_LEFT, 320, 14, Color("ffe066"))


func _describe_wave(index: int) -> String:
	var counts := {}
	for t in waves[index]["enemies"]:
		counts[t] = counts.get(t, 0) + 1
	var parts := []
	for t in counts:
		var d := EnemyTypes.get_type(t)
		parts.append("%d %s" % [counts[t], d["name"] if counts[t] == 1 else d["plural"]])
	return ", ".join(parts)


## Barre du bas : les choix de construction, avec leur touche et leur prix.
## On peut aussi cliquer dessus.
func _draw_build_bar(font: Font) -> void:
	for i in TowerTypes.ORDER.size() + 1:
		var r := _build_bar_rect(i)
		var id: String = "" if i == 0 else TowerTypes.ORDER[i - 1]
		var label := "1 Mur"
		var cost := wall_cost()
		var color := Color("6b5a45")
		if id != "":
			var d := TowerTypes.get_type(id)
			label = "%d %s" % [i + 1, d["name"]]
			cost = tower_cost(id)
			color = d["color"]
		var active: bool = id == selected
		draw_rect(r, Color(1, 1, 1, 0.15) if active else Color(1, 1, 1, 0.05))
		if active:
			draw_rect(r, Color("ffe066"), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(6, 12), Vector2(16, 16)), color)
		var text_color := Color.WHITE if gold >= cost else Color(1, 1, 1, 0.4)
		draw_string(font, r.position + Vector2(28, 18), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34, 14, text_color)
		draw_string(font, r.position + Vector2(28, 34), "%d or" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


func _build_bar_rect(i: int) -> Rect2:
	var top := Grid.OFFSET.y + Grid.ROWS * Grid.CELL
	var slot_w := Grid.SCREEN.x / 7.0
	return Rect2(i * slot_w + 3, top + 4, slot_w - 6, 40)


func _build_bar_slot(pos: Vector2) -> int:
	for i in TowerTypes.ORDER.size() + 1:
		if _build_bar_rect(i).has_point(pos):
			return i
	return -1
