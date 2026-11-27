extends Node2D
## Écran de récompense après un niveau : choisir 1 carte parmi 3.
## Une carte est un joker (règle du jeu) ou une relique (à poser dans une tour).
## Élite : une relique rare ou légendaire garantie. Boss : une relique légendaire garantie.
## Si on a déjà 5 jokers, il faut en abandonner un pour prendre le nouveau.

const CARD_SIZE := Vector2(260, 300)
const SKIP_LIVES := 3

const RELIC_CHANCE := 0.35   # chance qu'une carte normale soit une relique

var choices: Array = []      # cartes : {"kind": "joker" ou "relic", "id": ...}
var pending := ""      # joker choisi qui attend qu'on libère une place
var pending_relic := "" # relique choisie qui attend qu'on libère une place
var node_type := ""


func _ready() -> void:
	node_type = Run.current_node()["type"]
	var relic_room := true  # si l'inventaire est plein, on pourra remplacer une relique
	var forced_relic: String = {"combat": "", "elite": "rare", "boss": "legendaire"}[node_type]
	var rare_jokers: int = {"combat": 0, "elite": 1, "boss": 2}[node_type]
	var jokers := Jokers.draw_choices(Run.rng, Run.jokers, rare_jokers)
	var relics_offered := []
	for i in 3:
		var relic := ""
		if relic_room:
			if i == 0 and forced_relic != "":
				relic = Relics.draw(Run.rng, forced_relic)
			elif forced_relic == "" and Run.rng.randf() < RELIC_CHANCE:
				relic = Relics.draw(Run.rng)
		if relic != "" and not relic in relics_offered:
			relics_offered.append(relic)
			choices.append({"kind": "relic", "id": relic})
		elif not jokers.is_empty():
			choices.append({"kind": "joker", "id": jokers.pop_front()})
		elif relic_room:
			choices.append({"kind": "relic", "id": Relics.draw(Run.rng)})


func _card_rect(i: int) -> Rect2:
	var total := choices.size() * CARD_SIZE.x + (choices.size() - 1) * 30.0
	var x := (Grid.SCREEN.x - total) / 2.0 + i * (CARD_SIZE.x + 30.0)
	return Rect2(Vector2(x, 150), CARD_SIZE)


func _held_rect(i: int) -> Rect2:
	var w := 170.0
	var total := Jokers.MAX_HELD * w + (Jokers.MAX_HELD - 1) * 10.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (w + 10.0), 520), Vector2(w, 64))


func _relic_rect(i: int) -> Rect2:
	var w := 108.0
	var total := Relics.MAX_HELD * w + (Relics.MAX_HELD - 1) * 6.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (w + 6.0), 640), Vector2(w, 56))


func _skip_rect() -> Rect2:
	return Rect2(Vector2(Grid.SCREEN.x / 2.0 - 120, 470), Vector2(240, 34))


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if pending_relic != "":
		for i in Run.relics.size():
			if _relic_rect(i).has_point(p):
				Run.relics[i] = pending_relic
				Run.reward_done()
				return
		if _skip_rect().has_point(p):
			pending_relic = ""  # annuler
		return
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
			if choices[i]["kind"] == "relic":
				if Run.relics.size() < Relics.MAX_HELD:
					Run.relics.append(choices[i]["id"])
					Run.reward_done()
				else:
					pending_relic = choices[i]["id"]
			else:
				_take(choices[i]["id"])
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

	var title := "Niveau réussi ! Choisis une récompense"
	if node_type == "boss":
		title = "%s vaincu ! Choisis une récompense" % EnemyTypes.get_type(Run.biome()["boss"])["name"]
	if pending != "":
		title = "Tu as déjà %d jokers : clique sur celui à abandonner" % Jokers.MAX_HELD
	if pending_relic != "":
		title = "Tu as déjà %d reliques : clique sur celle à abandonner" % Relics.MAX_HELD
	draw_string(font, Vector2(0, 60), title, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 28, Color.WHITE)
	draw_string(font, Vector2(0, 95), "Vies %d    Score %d    Reliques %d/%d" % [Run.lives, Run.score, Run.relics.size(), Relics.MAX_HELD], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.7))

	for i in choices.size():
		var card: Dictionary = choices[i]
		var r := _card_rect(i)
		var hot := r.has_point(mouse) and pending == "" and pending_relic == ""
		var chosen: bool = card["id"] == pending or card["id"] == pending_relic
		var card_name := ""
		var kind_label := ""
		var desc := ""
		var border := Color("c9b48a")
		var bg := Color("3b352c")
		if card["kind"] == "relic":
			var rel := Relics.get_relic(card["id"])
			card_name = rel["name"]
			border = Relics.RARITY_COLORS[rel["rarity"]]
			bg = Color("26313b") if rel["rarity"] != "legendaire" else Color("3d2c1a")
			kind_label = "RELIQUE · " + Relics.RARITY_NAMES[rel["rarity"]].to_upper()
			desc = Relics.describe(card["id"]) + ("" if Relics.is_legendary(card["id"]) else ".\nSe pose dans un emplacement de tour.")
		else:
			var j := Jokers.get_joker(card["id"])
			card_name = j["name"]
			if j["rare"]:
				border = Color("ffd54a")
				bg = Color("3a2f45")
			kind_label = "JOKER · " + ("RARE" if j["rare"] else "COMMUN")
			desc = j["desc"]
		draw_rect(r, bg)
		draw_rect(r, border, false, 4.0 if (hot or chosen) else 2.0)
		if card["kind"] == "relic":
			draw_circle(r.position + Vector2(r.size.x / 2, r.size.y - 22), 10.0, border.darkened(0.4))
			draw_circle(r.position + Vector2(r.size.x / 2, r.size.y - 23), 7.0, border)
		var title_size := 21 if card_name.length() <= 18 else 17
		draw_string(font, r.position + Vector2(0, 50), card_name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, title_size, Color.WHITE)
		draw_string(font, r.position + Vector2(0, 78), kind_label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, border)
		draw_multiline_string(font, r.position + Vector2(18, 122), desc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 36, 15, -1, Color(1, 1, 1, 0.85))

	var skip := _skip_rect()
	draw_rect(skip, Color(1, 1, 1, 0.15 if skip.has_point(mouse) else 0.07))
	var skip_text := "Annuler" if (pending != "" or pending_relic != "") else "Passer : +%d vies" % SKIP_LIVES
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

	# Reliques déjà en main
	for i in Relics.MAX_HELD:
		var r := _relic_rect(i)
		var hot := pending_relic != "" and r.has_point(mouse) and i < Run.relics.size()
		draw_rect(r, Color(1, 1, 1, 0.12 if hot else 0.05))
		if i < Run.relics.size():
			var rel := Relics.get_relic(Run.relics[i])
			var color: Color = Relics.RARITY_COLORS[rel["rarity"]]
			draw_rect(r, Color("ff6b5a") if hot else Color(color, 0.6), false, 2.0 if hot else 1.0)
			draw_circle(r.position + Vector2(r.size.x / 2, 16), 6.0, color)
			draw_string(font, r.position + Vector2(4, 40), rel["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 11, Color.WHITE)
		else:
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
	draw_string(font, Vector2(0, 718), "Tes reliques (%d/%d)" % [Run.relics.size(), Relics.MAX_HELD], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.5))
