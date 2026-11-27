extends Node2D
## Écran de récompense après un niveau : choisir 1 joker parmi 3.
## Si on a déjà 5 jokers, il faut en abandonner un pour prendre le nouveau.

const CARD_SIZE := Vector2(260, 300)
const SKIP_LIVES := 3

var choices: Array[String] = []
var pending := ""      # joker choisi qui attend qu'on libère une place
var node_type := ""


func _ready() -> void:
	node_type = Run.current_node()["type"]
	var rare_slots: int = {"combat": 0, "elite": 1, "boss": 3}[node_type]
	choices = Jokers.draw_choices(Run.rng, Run.jokers, rare_slots)


func _card_rect(i: int) -> Rect2:
	var total := choices.size() * CARD_SIZE.x + (choices.size() - 1) * 30.0
	var x := (Grid.SCREEN.x - total) / 2.0 + i * (CARD_SIZE.x + 30.0)
	return Rect2(Vector2(x, 150), CARD_SIZE)


func _held_rect(i: int) -> Rect2:
	var w := 170.0
	var total := Jokers.MAX_HELD * w + (Jokers.MAX_HELD - 1) * 10.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (w + 10.0), 520), Vector2(w, 64))


func _skip_rect() -> Rect2:
	return Rect2(Vector2(Grid.SCREEN.x / 2.0 - 120, 470), Vector2(240, 34))


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if pending != "":
		for i in Run.jokers.size():
			if _held_rect(i).has_point(p):
				Run.jokers[i] = pending
				Run.reward_done()
				return
		if _skip_rect().has_point(p):
			pending = ""  # annuler
		return
	for i in choices.size():
		if _card_rect(i).has_point(p):
			_take(choices[i])
			return
	if _skip_rect().has_point(p):
		Run.lives += SKIP_LIVES
		Run.reward_done()


func _take(id: String) -> void:
	if Run.jokers.size() < Jokers.MAX_HELD:
		Run.jokers.append(id)
		Run.reward_done()
	else:
		pending = id


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Run.biome()["colors"]["background"])

	var title := "Niveau réussi ! Choisis un joker"
	if node_type == "boss":
		title = "%s vaincu ! Choisis un joker rare" % EnemyTypes.get_type(Run.biome()["boss"])["name"]
	if pending != "":
		title = "Tu as déjà %d jokers : clique sur celui à abandonner" % Jokers.MAX_HELD
	draw_string(font, Vector2(0, 60), title, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 28, Color.WHITE)
	draw_string(font, Vector2(0, 95), "Vies %d    Score %d" % [Run.lives, Run.score], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.7))

	for i in choices.size():
		var j := Jokers.get_joker(choices[i])
		var r := _card_rect(i)
		var hot := r.has_point(mouse) and pending == ""
		var chosen := choices[i] == pending
		draw_rect(r, Color("3a2f45") if j["rare"] else Color("3b352c"))
		var border := Color("ffd54a") if j["rare"] else Color("c9b48a")
		draw_rect(r, border, false, 4.0 if (hot or chosen) else 2.0)
		draw_string(font, r.position + Vector2(0, 50), j["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color.WHITE)
		draw_string(font, r.position + Vector2(0, 78), "RARE" if j["rare"] else "commun", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, border)
		draw_multiline_string(font, r.position + Vector2(20, 130), j["desc"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 40, 16, -1, Color(1, 1, 1, 0.85))

	var skip := _skip_rect()
	draw_rect(skip, Color(1, 1, 1, 0.15 if skip.has_point(mouse) else 0.07))
	var skip_text := "Annuler" if pending != "" else "Passer : +%d vies" % SKIP_LIVES
	draw_string(font, skip.position + Vector2(0, 23), skip_text, HORIZONTAL_ALIGNMENT_CENTER, skip.size.x, 16, Color.WHITE)

	# Jokers déjà en main
	for i in Jokers.MAX_HELD:
		var r := _held_rect(i)
		var hot := pending != "" and r.has_point(mouse) and i < Run.jokers.size()
		draw_rect(r, Color(1, 1, 1, 0.12 if hot else 0.05))
		draw_rect(r, Color("ff6b5a") if hot else Color(1, 1, 1, 0.2), false, 2.0)
		if i < Run.jokers.size():
			var j := Jokers.get_joker(Run.jokers[i])
			draw_string(font, r.position + Vector2(0, 26), j["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color.WHITE)
			draw_string(font, r.position + Vector2(0, 48), "rare" if j["rare"] else "commun", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1, 1, 1, 0.5))
		else:
			draw_string(font, r.position + Vector2(0, 38), "vide", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(1, 1, 1, 0.3))
	draw_string(font, Vector2(0, 612), "Tes jokers (%d/%d)" % [Run.jokers.size(), Jokers.MAX_HELD], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.5))
