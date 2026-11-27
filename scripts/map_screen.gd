extends Node2D
## La carte du biome : on choisit son prochain niveau parmi les chemins possibles.
## On voit les règles du biome et le type de chaque niveau avant de choisir sa route.

const NODE_RADIUS := 26.0
const LEFT := 110.0
const STEP_X := 185.0
const TOP := 190.0
const HEIGHT := 360.0

const CODEX_BUTTON := Rect2(800, 20, 140, 34)

var hovered := Vector2i(-1, -1)


func _ready() -> void:
	if not Run.started:
		Run.new_run()


func _node_pos(f: int, i: int) -> Vector2:
	return Vector2(LEFT + f * STEP_X, TOP + Run.map[f][i]["pos"] * HEIGHT)


func _node_at(point: Vector2) -> Vector2i:
	for f in Run.map.size():
		for i in Run.map[f].size():
			if _node_pos(f, i).distance_to(point) <= NODE_RADIUS + 4:
				return Vector2i(f, i)
	return Vector2i(-1, -1)


func _process(_delta: float) -> void:
	hovered = _node_at(get_global_mouse_position())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if CODEX_BUTTON.has_point(get_global_mouse_position()):
			Run.codex_return = "res://scenes/map.tscn"
			get_tree().change_scene_to_file("res://scenes/codex.tscn")
			return
		var n := _node_at(get_global_mouse_position())
		if n in Run.reachable():
			Run.enter_level(n)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var biome := Run.biome()
	var colors: Dictionary = biome["colors"]
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), colors["background"])
	UI.button(self, CODEX_BUTTON, "Carnet", CODEX_BUTTON.has_point(get_global_mouse_position()))

	# En-tête : biome et règles
	var title := "Biome %d/%d : %s, %s" % [Run.biome_index + 1, Biomes.count(), biome["name"], biome["subtitle"]]
	draw_string(font, Vector2(24, 40), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var y := 70.0
	for rule in biome["rules"]:
		draw_string(font, Vector2(30, y), "•  " + rule, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
		y += 22

	# Liens entre les niveaux
	var reachable := Run.reachable()
	for f in Run.map.size() - 1:
		for i in Run.map[f].size():
			for j in Run.map[f][i]["links"]:
				var taken := Vector2i(f, i) in Run.visited and Vector2i(f + 1, j) in Run.visited
				var col := Color(1, 1, 1, 0.8) if taken else Color(1, 1, 1, 0.22)
				draw_line(_node_pos(f, i), _node_pos(f + 1, j), col, 4.0 if taken else 2.0)

	# Niveaux
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	for f in Run.map.size():
		for i in Run.map[f].size():
			var pos := _node_pos(f, i)
			var n: Dictionary = Run.map[f][i]
			var key := Vector2i(f, i)
			var r := NODE_RADIUS * (1.35 if n["type"] == "boss" else 1.0)
			var fill := _type_color(n["type"])
			if key in Run.visited:
				fill = fill.darkened(0.55)
			elif not key in reachable:
				fill = fill.darkened(0.25)
			draw_circle(pos, r, fill)
			if key in reachable:
				draw_arc(pos, r + 5, 0.0, TAU, 40, Color(1, 0.88, 0.4, 0.5 + 0.5 * pulse), 3.0)
			var symbol: String = {"combat": "⚔", "elite": "!", "boss": "☠"}[n["type"]]
			draw_string(font, pos + Vector2(-r, 8), symbol, HORIZONTAL_ALIGNMENT_CENTER, r * 2, 22, Color.WHITE)
			if key in Run.visited:
				draw_string(font, pos + Vector2(-r, r + 18), "fait", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 12, Color(1, 1, 1, 0.5))

	# Infobulle du niveau survolé
	if hovered.x >= 0:
		var n: Dictionary = Run.map[hovered.x][hovered.y]
		var lines := [
			Levels.get_layout(n["layout"])["name"],
			{"combat": "Combat", "elite": "Élite : plus dur, récompense rare garantie", "boss": "Boss : ce qui dormait au fond"}[n["type"]],
			"%d vagues" % Levels.WAVE_COUNT[n["type"]],
		]
		var p := Vector2(Grid.SCREEN.x - 314, 560)  # coin en bas à droite, hors de la carte
		draw_rect(Rect2(p, Vector2(290, 72)), Color(0, 0, 0, 0.45))
		for k in lines.size():
			draw_string(font, p + Vector2(10, 22 + k * 20), lines[k], HORIZONTAL_ALIGNMENT_LEFT, 270, 15 if k == 0 else 13, Color.WHITE)

	# Pied de page : état de l'expédition
	var footer := "Vies %d    Score %d    Reliques %d/%d    Jokers (%d/%d) : %s" % [
		Run.lives, Run.score, Run.relics.size(), Relics.MAX_HELD, Run.jokers.size(), Profile.max_jokers(), _joker_names()]
	draw_string(font, Vector2(24, Grid.SCREEN.y - 48), footer, HORIZONTAL_ALIGNMENT_LEFT, Grid.SCREEN.x - 360, 15, Color.WHITE)
	draw_string(font, Vector2(24, Grid.SCREEN.y - 22), "Clique sur un niveau entouré pour avancer.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))


func _type_color(type: String) -> Color:
	match type:
		"elite":
			return Color("b8433a")
		"boss":
			return Color("7d3c98")
	return Color("8c7a5b")


func _joker_names() -> String:
	if Run.jokers.is_empty():
		return "aucun"
	var names := []
	for id in Run.jokers:
		names.append(Jokers.get_joker(id)["name"])
	return ", ".join(names)
