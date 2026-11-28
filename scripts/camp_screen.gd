extends Node2D
## Le feu de camp : une pause avant de repartir. On choisit une seule option.

const REST_LIVES := 6
const SEARCH_TREASURE := 25
const OPTION_W := 560.0
const CONTINUE := Rect2(380, 640, 200, 44)

var done := ""          # texte affiché une fois l'option choisie
var discarding := false # en train de choisir le joker à retirer


func _process(_delta: float) -> void:
	queue_redraw()


func _option_rect(i: int) -> Rect2:
	return Rect2(Vector2((Grid.SCREEN.x - OPTION_W) / 2.0, 250 + i * 86), Vector2(OPTION_W, 70))


func _joker_rect(i: int) -> Rect2:
	var w := 170.0
	var n := Run.jokers.size()
	var total := n * w + (n - 1) * 10.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (w + 10.0), 300), Vector2(w, 64))


func _options() -> Array:
	return [
		["Se reposer", "+%d vies" % REST_LIVES, true],
		["Fouiller les environs", "+%d trésor" % SEARCH_TREASURE, true],
		["Alléger le sac", "Retirer un joker pour faire de la place", not Run.jokers.is_empty()],
	]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if done != "":
		if CONTINUE.has_point(p):
			Run.stop_done()
		return
	if discarding:
		for i in Run.jokers.size():
			if _joker_rect(i).has_point(p):
				done = "%s retiré. Ton sac est plus léger." % Jokers.get_joker(Run.jokers[i])["name"]
				Run.jokers.remove_at(i)
				return
		discarding = false
		return
	var options := _options()
	for i in options.size():
		if _option_rect(i).has_point(p) and options[i][2]:
			match i:
				0:
					Run.lives += REST_LIVES
					done = "Une bonne nuit de sommeil. +%d vies." % REST_LIVES
				1:
					Run.treasure += SEARCH_TREASURE
					done = "Quelques babioles anciennes. +%d trésor." % SEARCH_TREASURE
				2:
					discarding = true
			return


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1c1a17"))
	# Le feu
	var flicker := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	draw_circle(Vector2(480, 560), 60 + 6 * flicker, Color(1.0, 0.5, 0.1, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(455, 585), Vector2(480, 520 - 8 * flicker), Vector2(505, 585)]), Color("f0a030"))
	draw_colored_polygon(PackedVector2Array([Vector2(468, 585), Vector2(480, 548 - 5 * flicker), Vector2(492, 585)]), Color("ffe066"))
	draw_string(font, Vector2(0, 80), "Feu de camp", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 32, Color("ffe066"))
	draw_string(font, Vector2(0, 120), "Une nuit calme avant de repartir. Choisis une seule chose à faire.", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.7))
	draw_string(font, Vector2(0, 160), "Vies : %d    Trésor : %d    Jokers : %d" % [Run.lives, Run.treasure, Run.jokers.size()], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.6))
	if done != "":
		draw_string(font, Vector2(0, 300), done, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 18, Color.WHITE)
		UI.button(self, CONTINUE, "Repartir", CONTINUE.has_point(mouse))
		return
	if discarding:
		draw_string(font, Vector2(0, 270), "Clique sur le joker à retirer (ailleurs pour annuler)", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color.WHITE)
		for i in Run.jokers.size():
			var r := _joker_rect(i)
			var hot := r.has_point(mouse)
			draw_rect(r, Color(1, 1, 1, 0.14 if hot else 0.06))
			draw_rect(r, Color("ff6b5a") if hot else Jokers.color_of(Run.jokers[i]), false, 2.0)
			draw_string(font, r.position + Vector2(0, 38), Jokers.get_joker(Run.jokers[i])["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color.WHITE)
		return
	var options := _options()
	for i in options.size():
		var r := _option_rect(i)
		var ok: bool = options[i][2]
		var hot := r.has_point(mouse) and ok
		draw_rect(r, Color(1, 1, 1, 0.14 if hot else 0.06))
		draw_rect(r, Color("ffe066") if hot else Color(1, 1, 1, 0.25), false, 2.0 if hot else 1.0)
		draw_string(font, r.position + Vector2(18, 30), options[i][0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 19, Color.WHITE if ok else Color(1, 1, 1, 0.35))
		draw_string(font, r.position + Vector2(18, 54), options[i][1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 14, Color(1, 1, 1, 0.6 if ok else 0.3))
