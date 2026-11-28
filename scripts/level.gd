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
##   E            : tourner une tour qui porte la Lance du Pharaon (au survol)
##   Barre du bas  : cliquer une relique, puis une tour, pour l'y poser

const WALL_COST := 2
const KILL_REWARD := 3
const WAVE_BONUS := 10
const SPAWN_INTERVAL := 0.7
const DUNES_PER_WAVE := 4
const STORM_RANGE := 0.75
const MACON_RANGE := 12.0
const WAVE_INFO_RECT := Rect2(6, 34, 614, 24)   # zone de la ligne « Prochaine vague » à survoler

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
var sealed := {}                     # murs que les fouisseurs ne peuvent pas creuser (Sceau de granit)
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
var gold_rest := 0.0   # morceaux d'or pas encore entiers (voir earn)
var wall_paid := {}    # Vector2i -> or payé pour ce mur (rendu s'il est retiré)
var upgrade_cell := Vector2i(-1, -1)  # tour dont le menu d'amélioration est ouvert
var free_walls_used := 0  # murs gratuits déjà posés (joker Architecte fou)
var selected := ""   # "" = mur, sinon l'identifiant de la tour choisie
var selected_relic := -1   # index dans Run.relics de la relique à poser (-1 = aucune)
var ended := false
var message := ""
var message_time := 0.0
var overlay: Node2D   # calque dessiné par-dessus les tours et les ennemis (fiches d'infos)


func _ready() -> void:
	node = Run.current_node()
	biome = Run.biome()
	layout = Levels.get_layout(node["layout"])
	_load_layout()
	waves = Levels.make_waves(Run.rng, Run.biome_index, Run.current.x, node["type"])
	_apply_difficulty_to_waves()
	gold = 70 + 5 * (Run.biome_index * 5 + Run.current.x)
	if Difficulty.active("bourse"):
		gold = int(gold * Difficulty.START_GOLD)
	if Run.has_joker("rempart"):
		Run.lives += 2
	_shift_dunes()
	_refresh_paths()
	_say("Construis ton labyrinthe, puis Espace")
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Node2D.new()
	layer.add_child(overlay)
	overlay.draw.connect(_draw_overlay)


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
	overlay.queue_redraw()


func _start_wave() -> void:
	if ended or wave_running or wave_index >= waves.size() - 1:
		return
	wave_index += 1
	call_deferred("_update_seals")  # la tempête change la portée, donc la zone scellée
	wave_running = true
	spawn_queue.assign(waves[wave_index]["enemies"])
	spawn_timer = 0.0
	storm = _is_storm(wave_index)
	gold += Profile.wave_gold()  # amélioration Économie
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
	_update_seals()
	if wave_index >= waves.size() - 1:
		ended = true
		_say("Niveau réussi !", 99.0)
		get_tree().create_timer(1.5).timeout.connect(Run.level_won)
		return
	earn(WAVE_BONUS)
	_shift_dunes()
	_say("Vague terminée ! +%d or" % WAVE_BONUS)


func _is_storm(index: int) -> bool:
	return biome["id"] == "desert" and index % 2 == 1


## Difficulté : transforme certains ennemis en élites et ajoute l'escorte du boss.
## Un élite est noté avec une étoile devant son type : "*eclaireur".
func _apply_difficulty_to_waves() -> void:
	for w in waves:
		var list: Array = w["enemies"]
		if Difficulty.active("elites"):
			var n := int(round(list.size() * Difficulty.ELITE_SHARE))
			var candidates := []
			for i in list.size():
				if not EnemyTypes.get_type(list[i]).get("boss", false):
					candidates.append(i)
			for k in mini(n, candidates.size()):
				var pick: int = candidates.pop_at(Run.rng.randi_range(0, candidates.size() - 1))
				list[pick] = "*" + list[pick]
		if Difficulty.active("escorte") and not list.is_empty() and EnemyTypes.get_type(base_type(list.back())).get("boss", false):
			for k in Difficulty.BOSS_ESCORT:
				list.insert(list.size() - 1, "*colosse")


## Type d'ennemi sans l'étoile des élites.
static func base_type(t: String) -> String:
	return t.trim_prefix("*")


func _spawn_enemy(type_id: String) -> void:
	var start := spawns[spawn_turn % spawns.size()]
	spawn_turn += 1
	var speed_mult: float = biome["enemy_speed"]
	if wave_index == 0 and Run.has_joker("sablier"):
		speed_mult *= 0.7
	if Difficulty.active("vitesse"):
		speed_mult *= Difficulty.SPEED_BONUS
	var e := _add_enemy(base_type(type_id), start, enemy_hp_mult(wave_index), speed_mult)
	if type_id.begins_with("*"):
		e.make_elite(Difficulty.ELITE_HP)


func _add_enemy(type_id: String, start: Vector2i, hp_mult: float, speed_mult: float) -> Enemy:
	var e := Enemy.new()
	var grid := dig_astar if EnemyTypes.get_type(type_id).get("digs", false) else astar
	e.setup(type_id, grid, start, goal, hp_mult, speed_mult)
	e.ice = ice
	e.walls = walls
	e.venin = Run.has_joker("venin")
	if Difficulty.active("regen"):
		e.regen = Difficulty.REGEN
	e.died.connect(_on_enemy_died)
	e.reached_goal.connect(_on_enemy_reached_goal)
	enemies.append(e)
	add_child(e)
	return e


func _on_enemy_died(e: Enemy) -> void:
	var reward: int = e.data.get("gold", KILL_REWARD) * (2 if e.elite else 1)
	if Difficulty.active("maigre_butin"):
		reward = maxi(1, reward - 1)
	earn(reward + (2 if Run.has_joker("prime") else 0))
	Run.score += e.data["score"] * (3 if e.elite else 1)
	Run.kills += 1
	if e.is_boss():
		Run.boss_killed = true
	var was_poisoned := e.is_poisoned()
	var where := e.global_position
	_remove_enemy(e)
	_split(e, where)
	if was_poisoned and Run.has_joker("fiole"):
		for other in enemies.duplicate():
			if is_instance_valid(other) and other.global_position.distance_to(where) <= 60.0:
				other.take_damage(15.0)


func _on_enemy_reached_goal(e: Enemy) -> void:
	_remove_enemy(e)
	if ended:
		return
	Run.lives -= e.lives_cost()
	if Run.has_joker("pillard"):
		earn(6)
	if Run.lives <= 0:
		Run.lives = 0
		ended = true
		for other in enemies:
			other.set_process(false)
		_say("L'expédition est perdue...", 99.0)
		get_tree().create_timer(1.5).timeout.connect(Run.level_lost)


## Jarre : en mourant, elle libère des larves là où elle se trouvait.
## Elles gardent la difficulté de la vague (même multiplicateur de PV et de vitesse).
func _split(e: Enemy, where: Vector2) -> void:
	var child_id: String = e.data.get("splits", "")
	if child_id == "" or ended:
		return
	var hp_mult: float = e.hp_mult  # les larves d'une jarre élite ne sont pas élites
	var speed_mult: float = e.speed / e.data["speed"]
	var n: int = e.data.get("split_count", 3)
	for i in n:
		var larva := _add_enemy(child_id, e.next_cell, hp_mult, speed_mult)
		larva.position = where + Vector2.from_angle(TAU * i / n) * 10.0


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
				selected_relic = -1
			KEY_E:
				var hover := Grid.world_to_cell(get_global_mouse_position())
				if towers.has(hover) and towers[hover].is_line():
					_rotate_line(towers[hover])
			KEY_SPACE:
				_start_wave()
			KEY_U:
				var hover_u := Grid.world_to_cell(get_global_mouse_position())
				if towers.has(hover_u):
					upgrade_cell = hover_u
			KEY_ESCAPE:
				upgrade_cell = Vector2i(-1, -1)
			KEY_F:
				Engine.time_scale = 2.0 if Engine.time_scale == 1.0 else 1.0
		for id in TowerTypes.ORDER:
			if event.keycode == TowerTypes.get_type(id)["key"]:
				selected = id
				selected_relic = -1
		return

	if ended:
		return
	if event is InputEventMouseButton and event.pressed:
		var pos := get_global_mouse_position()
		# Menu d'amélioration ouvert : un clic choisit une option, ou ferme le menu
		if towers.has(upgrade_cell):
			var t: Tower = towers[upgrade_cell]
			for b in _upgrade_buttons(t):
				if b[0].has_point(pos) and event.button_index == MOUSE_BUTTON_LEFT:
					_try_upgrade(t, b[1])
					return
			upgrade_cell = Vector2i(-1, -1)
			return
		var bar_slot := _build_bar_slot(pos)
		if bar_slot >= 0:
			selected = "" if bar_slot == 0 else TowerTypes.ORDER[bar_slot - 1]
			selected_relic = -1
			return
		var relic_slot := _relic_bar_slot(pos)
		if relic_slot >= 0:
			_click_relic(relic_slot)
			return
		var cell := Grid.world_to_cell(pos)
		if not Grid.in_bounds(cell):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if selected_relic >= 0:
				_try_socket(cell, selected_relic)
			elif towers.has(cell):
				upgrade_cell = cell  # clic sur une tour : menu d'amélioration
			elif selected == "":
				_try_place_wall(cell)
			else:
				_try_place_tower(cell, selected)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_relic >= 0:
				selected_relic = -1  # le clic droit annule la relique choisie
			else:
				_remove_at(cell)


func wall_cost() -> int:
	if free_walls_left() > 0:
		return 0
	if Run.has_joker("briques"):
		return 1
	return Difficulty.WALL_COST if Difficulty.active("murs_chers") else WALL_COST


## Murs gratuits restants dans ce niveau (joker Architecte fou).
func free_walls_left() -> int:
	if not Run.has_joker("architecte"):
		return 0
	return maxi(0, Jokers.ARCHITECTE_FREE_WALLS - free_walls_used)


func tower_cost(id: String) -> int:
	var cost: float = TowerTypes.get_type(id)["cost"]
	if Run.has_joker("fondations"):
		cost *= 0.75
	if Run.has_joker("architecte"):
		cost *= Jokers.ARCHITECTE_TOWER
	return int(ceil(cost))


## Or gagné pendant une vague (ennemis tués, fin de vague, Pillard).
## Butin de fouille et Trésor maudit l'augmentent. Les centimes sont gardés de côté
## pour qu'un +30 % sur 3 or ne soit pas perdu à l'arrondi.
func earn(amount: int) -> void:
	var mult := 1.0
	if Run.has_joker("butin"):
		mult += Jokers.BUTIN_GOLD
	if Run.has_joker("maudit"):
		mult *= Jokers.MAUDIT_GOLD
	gold_rest += amount * mult
	var whole := int(gold_rest)
	gold += whole
	gold_rest -= whole


## Multiplicateur de PV des ennemis d'une vague (Trésor maudit compris).
func enemy_hp_mult(index: int) -> float:
	var m: float = waves[index]["hp_mult"]
	if Run.has_joker("maudit"):
		m *= Jokers.MAUDIT_HP
	return m


func _try_place_wall(cell: Vector2i) -> void:
	if walls.has(cell):
		return
	if rocks.has(cell) or dunes.has(cell) or cell in spawns or cell == goal:
		_say("Impossible de construire ici")
		return
	if Difficulty.active("carriere") and walls.size() >= Difficulty.WALL_LIMIT:
		_say("Carrière épuisée : %d murs au maximum" % Difficulty.WALL_LIMIT)
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

	walls[cell] = true  # les fouisseurs l'ignorent : pour eux, un mur compte comme du sable
	var cost := wall_cost()
	if cost == 0:
		free_walls_used += 1
	wall_paid[cell] = cost
	gold -= cost
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
	t.spent = cost


# --- Amélioration des tours --------------------------------------------------

## Prix de la prochaine amélioration d'une tour (-1 si elle est au maximum).
func upgrade_cost(t: Tower) -> int:
	match t.tier:
		1:
			return int(ceil(tower_cost(t.type_id) * TowerTypes.TIER2_COST))
		2:
			return int(ceil(tower_cost(t.type_id) * TowerTypes.TIER3_COST))
	return -1


## Améliore une tour. which = "next" pour le niveau 2, "a" ou "b" pour la spécialisation.
func _try_upgrade(t: Tower, which: String) -> void:
	var cost := upgrade_cost(t)
	if cost < 0:
		return
	if gold < cost:
		_say("Pas assez d'or (%d)" % cost)
		return
	gold -= cost
	t.spent += cost
	t.tier += 1
	if t.tier == 3:
		t.spec = which
		_say("%s : %s !" % [t.data["name"], t.spec_data(which)["name"]])
	else:
		_say("%s niveau %d" % [t.data["name"], t.tier])
	upgrade_cell = Vector2i(-1, -1)
	_update_seals()  # la portée a pu changer


## Position du menu d'amélioration, à côté de la tour.
func _upgrade_origin(t: Tower) -> Vector2:
	var p := t.global_position + Vector2(34, -30)
	if p.x + UPGRADE_W > Grid.SCREEN.x - 6:
		p.x = t.global_position.x - 34 - UPGRADE_W
	p.y = clampf(p.y, Grid.OFFSET.y + 4, Grid.OFFSET.y + Grid.ROWS * Grid.CELL - 190)
	return p


const UPGRADE_W := 380.0

## Boutons du menu : [rectangle, choix].
func _upgrade_buttons(t: Tower) -> Array:
	var o := _upgrade_origin(t) + Vector2(10, 44)
	match t.tier:
		1:
			return [[Rect2(o, Vector2(UPGRADE_W - 20, 48)), "next"]]
		2:
			return [[Rect2(o, Vector2(UPGRADE_W - 20, 56)), "a"], [Rect2(o + Vector2(0, 64), Vector2(UPGRADE_W - 20, 56)), "b"]]
	return []


func _draw_upgrade_menu(font: Font, t: Tower, mouse: Vector2) -> void:
	var o := _upgrade_origin(t)
	var buttons := _upgrade_buttons(t)
	var h := 54.0 + (buttons.size() * 64.0 if t.tier < 3 else 34.0)
	overlay.draw_rect(Rect2(o, Vector2(UPGRADE_W, h)), Color(0.08, 0.07, 0.06, 0.95))
	overlay.draw_rect(Rect2(o, Vector2(UPGRADE_W, h)), Color("ffd54a"), false, 1.5)
	var title := "%s  ·  niveau %d" % [t.data["name"], t.tier]
	if t.spec != "":
		title += "  ·  " + t.spec_data(t.spec)["name"]
	overlay.draw_string(font, o + Vector2(10, 22), title, HORIZONTAL_ALIGNMENT_LEFT, UPGRADE_W - 20, 16, Color.WHITE)
	var cost := upgrade_cost(t)
	var hint := "Améliorer (clic ailleurs pour fermer)" if t.tier == 1 else ("Choisis une spécialisation" if t.tier == 2 else "Niveau maximum")
	overlay.draw_string(font, o + Vector2(10, 38), hint, HORIZONTAL_ALIGNMENT_LEFT, UPGRADE_W - 20, 12, Color(1, 1, 1, 0.55))
	if t.tier == 3:
		overlay.draw_string(font, o + Vector2(10, 64), t.spec_data(t.spec)["desc"], HORIZONTAL_ALIGNMENT_LEFT, UPGRADE_W - 20, 13, Color("ffd54a"))
		return
	for b in buttons:
		var r: Rect2 = b[0]
		var hot := r.has_point(mouse)
		var ok := gold >= cost
		overlay.draw_rect(r, Color(1, 1, 1, 0.16 if hot and ok else 0.07))
		overlay.draw_rect(r, Color("ffd54a") if hot and ok else Color(1, 1, 1, 0.25), false, 1.5)
		var label: String
		var desc: String
		if b[1] == "next":
			label = "Niveau 2"
			desc = "Dégâts et effets +%d %%, portée +%d %%" % [roundi((TowerTypes.TIER2_POWER - 1.0) * 100), roundi((TowerTypes.TIER2_RANGE - 1.0) * 100)]
		else:
			var sd := t.spec_data(b[1])
			label = "Voie %s : %s" % [String(b[1]).to_upper(), sd["name"]]
			desc = sd["desc"]
		var col := Color.WHITE if ok else Color(1, 1, 1, 0.4)
		overlay.draw_string(font, r.position + Vector2(10, 20), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 90, 14, col)
		overlay.draw_string(font, r.position + Vector2(r.size.x - 80, 20), "%d or" % cost, HORIZONTAL_ALIGNMENT_RIGHT, 70, 14, Color("ffe066") if ok else Color(1, 0.5, 0.4))
		overlay.draw_multiline_string(font, r.position + Vector2(10, 38), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 12, 2, Color(1, 1, 1, 0.7 if ok else 0.4))


func _remove_at(cell: Vector2i) -> void:
	if towers.has(cell):
		var t: Tower = towers[cell]
		gold += t.spent / 2  # on récupère la moitié de ce qu'elle a coûté ; les reliques reviennent dans l'inventaire
		if upgrade_cell == cell:
			upgrade_cell = Vector2i(-1, -1)
		t.queue_free()
		towers.erase(cell)
		_update_seals()
	elif walls.has(cell):
		walls.erase(cell)
		astar.set_point_solid(cell, false)
		dig_astar.set_point_solid(cell, false)
		sealed.erase(cell)
		var paid: int = wall_paid.get(cell, wall_cost())
		if paid == 0 and free_walls_used > 0:
			free_walls_used -= 1  # le mur gratuit peut être reposé ailleurs
		gold += paid
		wall_paid.erase(cell)
		_on_grid_changed()


# --- Reliques ----------------------------------------------------------------

## La tour qui porte une relique, ou null si la relique est libre.
func relic_owner(index: int) -> Tower:
	for t in towers.values():
		if index in t.relics:
			return t
	return null


func _click_relic(index: int) -> void:
	if index >= Run.relics.size():
		return
	var owner := relic_owner(index)
	if owner:
		owner.relics.erase(index)  # on la retire de sa tour
		_update_seals()
		_say("%s retirée" % Relics.get_relic(Run.relics[index])["name"])
		return
	selected_relic = -1 if selected_relic == index else index


func _try_socket(cell: Vector2i, index: int) -> void:
	if not towers.has(cell):
		_say("Clique sur une tour pour y poser la relique")
		return
	var t: Tower = towers[cell]
	var id := Run.relics[index]
	if t.relics.size() >= t.slot_count():
		if t.slot_count() == 1:
			_say("Une seule relique par tour (2 avec le joker Écrin double)")
		else:
			_say("Plus d'emplacement libre (%d)" % t.slot_count())
		return
	if Relics.is_legendary(id):
		if t.data["attack"] == "support":
			_say("Le Totem n'attaque pas : pas de légendaire")
			return
		if t.has_legendary():
			_say("Une seule légendaire par tour")
			return
	t.relics.append(index)
	_update_seals()
	selected_relic = -1
	if t.is_line():
		t.line_dir = _best_line_dir(t)
	_say("%s posée" % Relics.get_relic(id)["name"])


## Choisit la direction où la ligne de tir couvre le plus de cases du chemin.
func _best_line_dir(t: Tower) -> Vector2i:
	var best := Vector2i.RIGHT
	var best_count := -1
	for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var count := 0
		for k in range(1, t.line_cells() + 1):
			var c: Vector2i = t.cell + d * k
			for p in path_previews:
				if c in p:
					count += 1
		if count > best_count:
			best = d
			best_count = count
	return best


func _rotate_line(t: Tower) -> void:
	var order := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	t.line_dir = order[(order.find(t.line_dir) + 1) % 4]


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
	_update_seals()
	for e in enemies:
		e.repath()


## Sceau de granit : les murs à portée d'une tour qui porte la relique deviennent
## impossibles à creuser. Les fouisseurs doivent alors faire le tour comme les autres.
func _update_seals() -> void:
	var new_sealed := {}
	for t in towers.values():
		if not is_instance_valid(t) or t.is_queued_for_deletion() or not t.legendary("seal", false):
			continue
		for w in walls:
			if Grid.cell_to_world(w).distance_to(t.global_position) <= t.range_px() + 1.0:
				new_sealed[w] = true
	# On ne scelle pas un mur sous lequel un fouisseur est en train de passer.
	for e in enemies:
		if e.digs():
			new_sealed.erase(e.next_cell)
			new_sealed.erase(Grid.world_to_cell(e.position))
	if new_sealed == sealed:
		return
	sealed = new_sealed
	for w in walls:
		dig_astar.set_point_solid(w, sealed.has(w))
	for e in enemies:
		if e.digs():
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
		if sealed.has(cell):
			# Rune du sceau : un losange bleuté
			var c := r.get_center()
			var q := Grid.CELL * 0.22
			var pts := PackedVector2Array([c + Vector2(0, -q), c + Vector2(q, 0), c + Vector2(0, q), c + Vector2(-q, 0), c + Vector2(0, -q)])
			draw_polyline(pts, Color("9cc4ff"), 2.0)
			draw_rect(r, Color(0.6, 0.75, 1.0, 0.5), false, 1.5)

	# Tempête : voile de sable
	if storm:
		draw_rect(Rect2(Grid.OFFSET, Vector2(Grid.COLS, Grid.ROWS) * Grid.CELL), Color(0.85, 0.65, 0.35, 0.18))

	# Case survolée + aperçu de la portée
	var hover := Grid.world_to_cell(get_global_mouse_position())
	if Grid.in_bounds(hover) and not ended:
		draw_rect(Grid.cell_rect(hover), Color(1, 1, 1, 0.8), false, 2.0)
		var preview_range := 0.0
		if towers.has(hover):
			preview_range = 0.0 if towers[hover].is_line() else towers[hover].range_px()
		elif selected != "":
			preview_range = tower_range(selected, hover)
		if preview_range > 0.0:
			draw_arc(Grid.cell_to_world(hover), preview_range, 0.0, TAU, 48, Color(0.25, 0.5, 0.82, 0.7), 2.0)

	_draw_hud(font)
	_draw_build_bar(font)
	_draw_relic_bar(font)


func _draw_hud(font: Font) -> void:
	var type_names := {"combat": "", "elite": "  ·  ÉLITE", "boss": "  ·  BOSS"}
	var title := "%s · %s%s" % [biome["name"], layout["name"], type_names[node["type"]]]
	if Run.difficulty > 0:
		title += "  ·  D%d" % Run.difficulty
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
	if line2 != "":
		line2 += "   ⓘ"
		var hot := WAVE_INFO_RECT.has_point(get_global_mouse_position())
		if hot:
			draw_rect(WAVE_INFO_RECT, Color(1, 1, 1, 0.08))
	draw_string(font, Vector2(12, 50), line2, HORIZONTAL_ALIGNMENT_LEFT, 600, 14, Color(1, 1, 1, 0.75))
	if message_time > 0.0:
		draw_string(font, Vector2(630, 50), message, HORIZONTAL_ALIGNMENT_LEFT, 320, 14, Color("ffe066"))


func _describe_wave(index: int) -> String:
	var counts := {}
	for t in waves[index]["enemies"]:
		counts[t] = counts.get(t, 0) + 1
	var parts := []
	for t in counts:
		parts.append(_enemy_count_name(t, counts[t]))
	return ", ".join(parts)


## « 3 éclaireurs », « 1 colosse élite », « 2 colosses élites ».
func _enemy_count_name(t: String, n: int) -> String:
	var d := EnemyTypes.get_type(base_type(t))
	var s := "%d %s" % [n, d["name"] if n == 1 else d["plural"]]
	if t.begins_with("*"):
		s += " élite" if n == 1 else " élites"
	return s


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
		var price := "%d or" % cost
		if id == "" and free_walls_left() > 0:
			price = "gratuit (%d)" % free_walls_left()
		if id == "" and Difficulty.active("carriere"):
			price += "  ·  %d/%d" % [walls.size(), Difficulty.WALL_LIMIT]
		draw_string(font, r.position + Vector2(28, 34), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


func _build_bar_rect(i: int) -> Rect2:
	var top := Grid.OFFSET.y + Grid.ROWS * Grid.CELL
	var slot_w := Grid.SCREEN.x / 7.0
	return Rect2(i * slot_w + 3, top + 4, slot_w - 6, 40)


## Barre des reliques, sous la barre de construction.
func _draw_relic_bar(font: Font) -> void:
	var top := Grid.OFFSET.y + Grid.ROWS * Grid.CELL + 48
	draw_string(font, Vector2(10, top + 20), "Reliques", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var hint := "%d/%d" % [Run.relics.size(), Relics.MAX_HELD]
	draw_string(font, Vector2(10, top + 38), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	for i in Relics.MAX_HELD:
		var r := _relic_bar_rect(i)
		if i >= Run.relics.size():
			draw_rect(r, Color(1, 1, 1, 0.03))
			continue
		var relic := Relics.get_relic(Run.relics[i])
		var color: Color = Relics.RARITY_COLORS[relic["rarity"]]
		var owner := relic_owner(i)
		var active := i == selected_relic
		draw_rect(r, Color(1, 1, 1, 0.15) if active else Color(1, 1, 1, 0.06))
		draw_rect(r, Color("ffe066") if active else Color(color, 0.6), false, 2.0 if active else 1.0)
		draw_circle(r.position + Vector2(10, 20), 5.0, color)
		var text_color := Color(1, 1, 1, 0.45) if owner else Color.WHITE
		draw_string(font, r.position + Vector2(19, 17), relic["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 21, 11, text_color)
		var status: String = "posée : %s" % owner.data["name"] if owner else Relics.RARITY_NAMES[relic["rarity"]]
		draw_string(font, r.position + Vector2(19, 33), status, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 21, 11, Color(color, 0.9) if not owner else Color(1, 1, 1, 0.45))


func _relic_bar_rect(i: int) -> Rect2:
	var top := Grid.OFFSET.y + Grid.ROWS * Grid.CELL + 48
	var left := 84.0
	var w := (Grid.SCREEN.x - left - 4) / Relics.MAX_HELD
	return Rect2(left + i * w + 2, top + 4, w - 4, 40)


func _relic_bar_slot(pos: Vector2) -> int:
	for i in Relics.MAX_HELD:
		if _relic_bar_rect(i).has_point(pos):
			return i
	return -1


func _build_bar_slot(pos: Vector2) -> int:
	for i in TowerTypes.ORDER.size() + 1:
		if _build_bar_rect(i).has_point(pos):
			return i
	return -1


# --- Fiches d'informations (au survol) ---------------------------------------

func _draw_overlay() -> void:
	if ended:
		return
	var mouse := get_global_mouse_position()
	var font := ThemeDB.fallback_font

	# Menu d'amélioration d'une tour
	if towers.has(upgrade_cell):
		_draw_upgrade_menu(font, towers[upgrade_cell], mouse)
		return

	# Détail de la vague à venir (ou en cours)
	if WAVE_INFO_RECT.has_point(mouse):
		var index := wave_index if wave_running else wave_index + 1
		if index >= 0 and index < waves.size():
			_draw_panel(font, Vector2(12, 62), _wave_panel(index))
		return

	# Tour dans la barre de construction
	var slot := _build_bar_slot(mouse)
	if slot > 0:
		var id: String = TowerTypes.ORDER[slot - 1]
		var r := _build_bar_rect(slot)
		_draw_panel(font, Vector2(r.position.x, r.position.y - 8), _tower_panel(id, null), true)
		return

	# Relique dans la barre
	var rslot := _relic_bar_slot(mouse)
	if rslot >= 0 and rslot < Run.relics.size():
		var r := _relic_bar_rect(rslot)
		_draw_panel(font, Vector2(r.position.x, r.position.y - 8), _relic_panel(rslot), true)
		return

	var cell := Grid.world_to_cell(mouse)
	# Ennemi sous la souris
	for e in enemies:
		if is_instance_valid(e) and e.global_position.distance_to(mouse) <= e.data["radius"] + 4:
			_draw_panel(font, mouse + Vector2(18, 18), _enemy_panel(e))
			return
	# Tour posée
	if Grid.in_bounds(cell) and towers.has(cell):
		_draw_panel(font, mouse + Vector2(18, 18), _tower_panel(towers[cell].type_id, towers[cell]))


## Une ligne de fiche : [texte, taille, couleur]
func _line(text: String, size := 13, color := Color(1, 1, 1, 0.85)) -> Array:
	return [text, size, color]


func _tower_panel(id: String, t: Tower) -> Array:
	var d := TowerTypes.get_type(id)
	var head: String = d["name"]
	if t and t.tier > 1:
		head += "  ·  niveau %d" % t.tier
	var lines := [_line(head, 17, Color.WHITE), _line(d["desc"], 13, Color(1, 1, 1, 0.6))]
	if t and t.spec != "":
		var sd := t.spec_data(t.spec)
		lines.append(_line("%s : %s" % [sd["name"], sd["desc"]], 13, Color("ffd54a")))
	var cell: Vector2i = t.cell if t else Vector2i(-10, -10)
	var line_mode: bool = t != null and t.is_line()
	var effect: float = t.effect_mult() if t else 1.0
	if d["attack"] != "support":
		var dmg: float = t._damage() if t else d["damage"]
		var rate: float = (t._fire_rate() if t else float(biome["tower_cadence"])) / float(d["delay"])
		if d["attack"] == "poison":
			var dps: float = t._poison_dps() if t else d["poison_dps"]
			lines.append(_line("Poison : %s dégâts/s pendant %d s (%d au total)" % [_num(dps), d["poison_time"], roundi(dps * d["poison_time"])]))
		else:
			var dmg_note := "  (Cul-de-sac x2)" if t and Run.has_joker("cul_de_sac") and blocked_neighbors(cell) >= 3 else ""
			lines.append(_line("Dégâts : %s%s" % [_num(dmg), dmg_note]))
		lines.append(_line("Tirs par seconde : %s" % _num(rate)))
	if line_mode:
		lines.append(_line("Tir en ligne droite : %d cases (E pour tourner)" % t.line_cells(), 13, Relics.RARITY_COLORS["legendaire"]))
	else:
		var rng: float = t.range_px() if t else tower_range(id, cell)
		lines.append(_line("Portée : %d%s" % [rng, "  (tempête -25 %)" if storm else ""]))
	match d["attack"]:
		"single":
			lines.append(_line("Touche tout ce qui est sur la ligne" if line_mode else "Vise l'ennemi le plus proche de la sortie"))
			if Run.has_joker("echo") and not line_mode:
				lines.append(_line("Écho : rebondit sur un 2e ennemi (60 %)", 13, Color("ffd54a")))
		"splash":
			if line_mode:
				lines.append(_line("Touche tout ce qui est sur la ligne"))
			else:
				var radius: float = t._splash_radius() if t else d["splash_radius"] * (1.5 if Run.has_joker("artilleur") else 1.0)
				lines.append(_line("Explosion : rayon %d" % radius))
				lines.append(_line("Ne tire pas à moins de %d" % d["min_range"]))
		"aura":
			var slow: float = 0.35 if Run.has_joker("givre_eternel") else d["slow"]
			var slow_time: float = d["slow_time"] * (2.0 if Run.has_joker("givre_eternel") else 1.0) * effect
			lines.append(_line("Touche tout ce qui est sur la ligne" if line_mode else "Touche tous les ennemis à portée"))
			lines.append(_line("Ralentit de %d %% pendant %s s" % [roundi((1.0 - slow) * 100), _num(slow_time)]))
		"poison":
			lines.append(_line("Touche tout ce qui est sur la ligne" if line_mode else "Vise d'abord les ennemis pas encore empoisonnés"))
		"support":
			var buff: float = t.buff_value() if t else d["buff"]
			lines.append(_line("N'attaque pas"))
			lines.append(_line("Tours à portée : +%d %% de cadence" % roundi(buff * 100)))
			if Run.has_joker("ancetres"):
				lines.append(_line("Totems ancestraux : les bonus se cumulent", 13, Color("ffd54a")))
	if t and t.rivalry():
		lines.append(_line("Rivalité des ateliers : cadence -%d %%" % roundi((1.0 - Difficulty.RIVALRY_RATE) * 100), 13, Color("ff8a5c")))
	if t and t.pack_bonus() > 0.0:
		lines.append(_line("Esprit de meute : +%d %% de cadence" % roundi(t.pack_bonus() * 100), 13, Relics.RARITY_COLORS["legendaire"]))
	if t and t.legendary("only_slowed", false):
		lines.append(_line("Ne vise que les ennemis ralentis", 13, Relics.RARITY_COLORS["legendaire"]))
	if biome["tower_cadence"] < 1.0:
		lines.append(_line("Froid : cadence -%d %%" % roundi((1.0 - biome["tower_cadence"]) * 100), 13, Color("9fd3ea")))
	# Reliques
	if t:
		lines.append(_line("Reliques : %d/%d" % [t.relics.size(), t.slot_count()], 14, Color.WHITE))
		for rid in t.relic_ids():
			var r := Relics.get_relic(rid)
			lines.append(_line("  • %s : %s" % [r["name"], _short_relic(rid)], 13, Relics.RARITY_COLORS[r["rarity"]]))
		if t.tier < 3:
			lines.append(_line("Clic ou U : améliorer (%d or)" % upgrade_cost(t), 13, Color("ffe066")))
		lines.append(_line("Revente (clic droit) : %d or" % (t.spent / 2), 13, Color(1, 1, 1, 0.6)))
	else:
		lines.append(_line("Reliques : %d (une seule légendaire)" % (2 if Run.has_joker("ecrin") else 1)))
		lines.append(_line("Prix : %d or  ·  se pose sur un mur" % tower_cost(id), 13, Color("ffe066")))
	return lines


## Effet court d'une relique pour la fiche d'une tour.
func _short_relic(id: String) -> String:
	var r := Relics.get_relic(id)
	if r.get("seal", false):
		return "murs à portée impossibles à creuser, +15 % portée"
	if not Relics.is_legendary(id):
		return Relics.describe(id)
	var parts := []
	if r.has("damage_x"):
		parts.append("dégâts x%s" % _num(r["damage_x"]))
	if r.has("rate_x"):
		parts.append("cadence x%s" % _num(r["rate_x"]))
	if r.get("line", false):
		parts.append("tir en ligne")
	if r.has("fixed_range"):
		parts.append("portée 1,5 case")
	if r.get("only_slowed", false):
		parts.append("ralentis seulement")
	return ", ".join(parts)


func _relic_panel(index: int) -> Array:
	var id := Run.relics[index]
	var r := Relics.get_relic(id)
	var color: Color = Relics.RARITY_COLORS[r["rarity"]]
	var lines := [_line(r["name"], 17, Color.WHITE), _line("Relique " + Relics.RARITY_NAMES[r["rarity"]].to_lower(), 13, color)]
	var words := Relics.describe(id).split(" ")
	var current := ""
	for w in words:  # coupe la description en lignes de 50 caractères environ
		if current.length() + w.length() > 50:
			lines.append(_line(current))
			current = ""
		current += ("" if current == "" else " ") + w
	if current != "":
		lines.append(_line(current))
	var owner := relic_owner(index)
	if owner:
		lines.append(_line("Posée sur : %s. Clique pour la retirer." % owner.data["name"], 13, Color(1, 1, 1, 0.6)))
	else:
		lines.append(_line("Clique, puis clique sur une tour pour l'y poser.", 13, Color("ffe066")))
	return lines


func _wave_panel(index: int) -> Array:
	var wave: Dictionary = waves[index]
	var hp_mult: float = enemy_hp_mult(index)
	var speed_mult: float = biome["enemy_speed"]
	var counts := {}
	var order := []
	for t in wave["enemies"]:
		if not counts.has(t):
			order.append(t)
		counts[t] = counts.get(t, 0) + 1
	var title := "Vague %d/%d : %d ennemis" % [index + 1, waves.size(), wave["enemies"].size()]
	var lines := [_line(title, 17, Color.WHITE)]
	if _is_storm(index):
		lines.append(_line("Tempête de sable : portée des tours -25 %", 13, Color("e0b070")))
	if index == 0 and Run.has_joker("sablier"):
		lines.append(_line("Sablier ancien : ennemis 30 % plus lents", 13, Color("ffd54a")))
	if Difficulty.active("vitesse"):
		speed_mult *= Difficulty.SPEED_BONUS
	for t in order:
		var d := EnemyTypes.get_type(base_type(t))
		var n: int = counts[t]
		var elite: bool = t.begins_with("*")
		var hp := roundi(d["hp"] * hp_mult * (Difficulty.ELITE_HP if elite else 1.0))
		var speed: float = d["speed"] * speed_mult / Grid.CELL
		var lost: int = d["damage"] + (1 if elite else 0)
		var label: String = (d["name"] if n == 1 else d["plural"]) + ((" élite" if n == 1 else " élites") if elite else "")
		lines.append(_line("%d × %s" % [n, label], 15, Color("ffd54a") if elite else d["color"].lightened(0.35)))
		lines.append(_line("    PV %d  ·  vitesse %s cases/s  ·  -%d vie%s" % [hp, _num(speed), lost, "s" if lost > 1 else ""]))
		lines.append(_line("    " + d["ability"], 13, Color(1, 1, 1, 0.6)))
		if d.has("splits"):
			var c := EnemyTypes.get_type(d["splits"])
			var c_speed: float = c["speed"] * speed_mult / Grid.CELL
			lines.append(_line("    puis %d × %s : PV %d  ·  vitesse %s cases/s" % [d["split_count"], c["plural"], roundi(c["hp"] * hp_mult), _num(c_speed)], 13, c["color"]))
	if not ice.is_empty():
		lines.append(_line("Sur la glace, tous les ennemis vont 2 fois plus vite", 13, Color("9fd3ea")))
	if Run.difficulty > 0:
		lines.append(_line("%s : %d règle%s active%s (voir le camp de base)" % [Difficulty.name_of(Run.difficulty), Run.difficulty, "s" if Run.difficulty > 1 else "", "s" if Run.difficulty > 1 else ""], 13, Color("ff8a5c")))
	return lines


func _enemy_panel(e: Enemy) -> Array:
	var d := e.data
	var title: String = d["name"].capitalize() if not e.is_boss() else d["name"]
	if e.elite:
		title += " élite"
	var lines := [_line(title, 16, Color("ffd54a") if e.elite else Color.WHITE)]
	lines.append(_line("PV %d / %d" % [ceili(e.hp), roundi(e.max_hp)]))
	lines.append(_line("Vitesse %s cases/s  ·  -%d vie%s" % [_num(e.speed / Grid.CELL), e.lives_cost(), "s" if e.lives_cost() > 1 else ""]))
	lines.append(_line(d["ability"], 13, Color(1, 1, 1, 0.6)))
	if e.slow_time > 0.0:
		lines.append(_line("Ralenti (%s s)" % _num(e.slow_time), 13, Color("7fd6e8")))
	if e.is_poisoned():
		lines.append(_line("Empoisonné (%s s)" % _num(e.poison_time), 13, Color("8fd14f")))
	return lines


## Dessine une fiche. Si above est vrai, la fiche est posée au-dessus du point donné.
func _draw_panel(font: Font, at: Vector2, lines: Array, above := false) -> void:
	var pad := 10.0
	var w := 0.0
	var h := pad
	for l in lines:
		w = maxf(w, font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1]).x)
		h += l[1] + 6
	w += pad * 2
	h += pad - 6
	var pos := at - Vector2(0, h) if above else at
	pos.x = clampf(pos.x, 4, Grid.SCREEN.x - w - 4)
	pos.y = clampf(pos.y, 4, Grid.SCREEN.y - h - 4)
	overlay.draw_rect(Rect2(pos, Vector2(w, h)), Color(0.08, 0.07, 0.09, 0.93), true)
	overlay.draw_rect(Rect2(pos, Vector2(w, h)), Color(1, 1, 1, 0.25), false, 1.0)
	var y := pos.y + pad
	for l in lines:
		y += l[1]
		overlay.draw_string(font, Vector2(pos.x + pad, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1], l[2])
		y += 6


## Nombre court : 1 décimale si besoin.
func _num(x: float) -> String:
	if absf(x - roundf(x)) < 0.05:
		return str(roundi(x))
	return "%.1f" % x
