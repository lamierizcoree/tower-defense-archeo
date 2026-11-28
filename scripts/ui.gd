class_name UI
extends RefCounted
## Petits outils de dessin partagés par les écrans (boutons).


## Dessine un bouton. hot = souris dessus.
static func button(canvas: CanvasItem, rect: Rect2, text: String, hot: bool, enabled := true, size := 16) -> void:
	var font := ThemeDB.fallback_font
	var bg := Color(1, 1, 1, 0.16 if (hot and enabled) else 0.07)
	canvas.draw_rect(rect, bg)
	canvas.draw_rect(rect, Color("ffe066") if (hot and enabled) else Color(1, 1, 1, 0.25), false, 2.0 if hot else 1.0)
	var color := Color.WHITE if enabled else Color(1, 1, 1, 0.35)
	canvas.draw_string(font, rect.position + Vector2(0, rect.size.y / 2 + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)



## Infobulle d'un joker, affichée au survol : nom, rareté, descriptif, synergies
## (clan et duo, avec leurs effets et s'ils sont actifs) et images des tours concernées.
## held = jokers en main (null hors expédition : on montre juste les règles). À dessiner en dernier.
static func joker_tip(canvas: CanvasItem, id: String, mouse: Vector2, held = null) -> void:
	var font := ThemeDB.fallback_font
	var j := Jokers.get_joker(id)
	var color := Jokers.color_of(id)
	var towers := Jokers.towers_of(id)
	const W := 340.0
	const IN := 12.0
	const ON := Color("8fdc6a")      # effet actif
	const NEXT := Color("ffb070")    # effet débloqué si on prend ce joker
	const OFF := Color(1, 1, 1, 0.45)
	# Lignes de texte : [texte, taille, couleur, retrait]
	var lines: Array = []
	lines.append([j["desc"], 14, Color(1, 1, 1, 0.9), 0.0])

	var in_run: bool = held != null
	var hand: Array = held if in_run else []
	var owned: bool = id in hand
	var after := hand.duplicate()
	if not owned:
		after.append(id)

	# Clan : bonus à 2 et 3 jokers
	var f := Jokers.family_of(id)
	var fam: Dictionary = Jokers.FAMILIES[f]
	var head := "%s Clan %s" % [fam["symbol"], fam["name"]]
	if in_run:
		head += "  (%d en main%s)" % [Jokers.family_count(hand, f), "" if owned else ", %d avec lui" % Jokers.family_count(after, f)]
	lines.append(["", 6, OFF, 0.0])
	lines.append([head, 14, fam["color"], 0.0])
	var lvl_now := Jokers.family_level(hand, f)
	var lvl_after := Jokers.family_level(after, f)
	for step in Jokers.FAMILY_STEPS:
		var state := ""
		var c := OFF
		if in_run and lvl_now >= step:
			state = "actif"
			c = ON
		elif in_run and lvl_after >= step:
			state = "débloqué en le prenant"
			c = NEXT
		var txt := "%d jokers : %s" % [step, fam["bonus"][step]]
		if state != "":
			txt += "  [%s]" % state
		lines.append([txt, 13, c, IN])

	# Duo : une paire précise de jokers
	var duo := Jokers.duo_of(id)
	if duo != "":
		var d: Dictionary = Jokers.DUOS[duo]
		var partner: String = Jokers.get_joker(Jokers.partner_of(id))["name"]
		lines.append(["", 6, OFF, 0.0])
		lines.append(["Duo %s  (avec %s)" % [d["name"], partner], 14, Color("ffcf9f"), 0.0])
		var c := OFF
		var txt: String = d["desc"]
		if in_run and Jokers.has_duo(hand, duo):
			c = ON
			txt += "  [actif]"
		elif in_run and Jokers.has_duo(after, duo):
			c = NEXT
			txt += "  [débloqué en le prenant]"
		elif in_run:
			txt += "  [il manque %s]" % partner
		lines.append([txt, 13, c, IN])

	# Hauteur totale
	var heights: Array = []
	var text_h := 0.0
	for l in lines:
		var hh: float = l[1] if l[0] == "" else font.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, W - 24 - l[3], l[1]).y
		heights.append(hh)
		text_h += hh + 2.0
	var h := 56.0 + text_h + 10.0
	if not towers.is_empty():
		h += 78.0
	# près de la souris, sans sortir de l'écran
	var pos := mouse + Vector2(18, 18)
	if pos.x + W > Grid.SCREEN.x - 8:
		pos.x = mouse.x - W - 18
	if pos.y + h > Grid.SCREEN.y - 8:
		pos.y = maxf(8.0, Grid.SCREEN.y - 8 - h)
	pos.x = maxf(8.0, pos.x)
	var r := Rect2(pos, Vector2(W, h))
	canvas.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.4))
	canvas.draw_rect(r, Color("1d1a24"))
	canvas.draw_rect(r, color, false, 2.0)
	canvas.draw_string(font, r.position + Vector2(12, 26), j["name"], HORIZONTAL_ALIGNMENT_LEFT, W - 24, 18, Color.WHITE)
	var sub := "Joker %s%s" % [Jokers.RARITY_NAMES[j["rarity"]].to_lower(), "  ·  en main" if owned else ""]
	canvas.draw_string(font, r.position + Vector2(12, 46), sub, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 13, color)
	var y := r.position.y + 56.0
	for k in lines.size():
		var l: Array = lines[k]
		if l[0] != "":
			canvas.draw_multiline_string(font, Vector2(r.position.x + 12 + l[3], y + l[1]), l[0], HORIZONTAL_ALIGNMENT_LEFT, W - 24 - l[3], l[1], -1, l[2])
		y += heights[k] + 2.0
	if towers.is_empty():
		return
	y += 6.0
	canvas.draw_line(Vector2(r.position.x + 12, y), Vector2(r.end.x - 12, y), Color(1, 1, 1, 0.15), 1.0)
	canvas.draw_string(font, Vector2(r.position.x + 12, y + 18), "Tours concernées", HORIZONTAL_ALIGNMENT_LEFT, W - 24, 12, Color(1, 1, 1, 0.55))
	var slot := 70.0
	var x0 := r.position.x + W / 2.0 - slot * towers.size() / 2.0
	for i in towers.size():
		var cx := x0 + slot * (i + 0.5)
		TowerArt.draw_icon(canvas, towers[i], Vector2(cx, y + 42), 34.0)
		canvas.draw_string(font, Vector2(cx - slot / 2.0, y + 72), TowerTypes.get_type(towers[i])["name"], HORIZONTAL_ALIGNMENT_CENTER, slot, 12, Color.WHITE)


## Infobulle des synergies actives (clans et duos) avec leurs effets.
static func synergy_tip(canvas: CanvasItem, held: Array, mouse: Vector2) -> void:
	var font := ThemeDB.fallback_font
	const W := 380.0
	var lines: Array = []   # [texte, taille, couleur]
	for f in Jokers.FAMILIES:
		var lvl := Jokers.family_level(held, f)
		if lvl == 0:
			continue
		var fam: Dictionary = Jokers.FAMILIES[f]
		lines.append(["%s %s  (%d jokers)" % [fam["symbol"], fam["name"], Jokers.family_count(held, f)], 14, fam["color"]])
		for step in Jokers.FAMILY_STEPS:
			if lvl >= step:
				lines.append(["%d : %s" % [step, fam["bonus"][step]], 13, Color(1, 1, 1, 0.88)])
	for d in Jokers.DUOS:
		if Jokers.has_duo(held, d):
			lines.append(["Duo " + Jokers.DUOS[d]["name"], 14, Color("ffcf9f")])
			lines.append([Jokers.DUOS[d]["desc"], 13, Color(1, 1, 1, 0.88)])
	if lines.is_empty():
		return
	var heights: Array = []
	var h := 40.0
	for l in lines:
		var hh := font.get_multiline_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, W - 24, l[1]).y
		heights.append(hh)
		h += hh + 3.0
	var pos := Vector2(clampf(mouse.x - W / 2.0, 8.0, Grid.SCREEN.x - W - 8), mouse.y - h - 14)
	if pos.y < 8:
		pos.y = mouse.y + 18
	var r := Rect2(pos, Vector2(W, h))
	canvas.draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.4))
	canvas.draw_rect(r, Color("1d1a24"))
	canvas.draw_rect(r, Color("ff9f6b"), false, 2.0)
	canvas.draw_string(font, r.position + Vector2(12, 24), "Synergies actives", HORIZONTAL_ALIGNMENT_LEFT, W - 24, 16, Color.WHITE)
	var y := r.position.y + 36.0
	for k in lines.size():
		canvas.draw_multiline_string(font, Vector2(r.position.x + 12, y + lines[k][1]), lines[k][0], HORIZONTAL_ALIGNMENT_LEFT, W - 24, lines[k][1], -1, lines[k][2])
		y += heights[k] + 3.0


## Petite carte du deck (atelier de cartes, camp de base) : nom, type, prix, niveau d'amélioration.
static func deck_card(canvas: CanvasItem, r: Rect2, id: String, lvl: int, hot: bool, chosen: bool, dim := false) -> void:
	var font := ThemeDB.fallback_font
	var c := Cards.get_card(id)
	var color := Cards.color_of(id)
	var a := 0.4 if dim else 1.0
	canvas.draw_rect(r, Color(1, 1, 1, 0.16 if hot or chosen else 0.07))
	canvas.draw_rect(Rect2(r.position, Vector2(5, r.size.y)), Color(color, a))
	canvas.draw_rect(r, Color("ffe066") if chosen else Color(color, 0.6 * a), false, 3.0 if chosen else (2.0 if hot else 1.0))
	if c["kind"] == "tower":
		TowerArt.draw_icon(canvas, c["tower"], r.position + Vector2(26, r.size.y / 2), 34.0)
	else:
		card_symbol(canvas, c["kind"], r.position + Vector2(26, r.size.y / 2), Color(color, a))
	canvas.draw_string(font, r.position + Vector2(48, 22), c["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 52, 14, Color(1, 1, 1, a))
	canvas.draw_string(font, r.position + Vector2(48, 40), Cards.KINDS[c["kind"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 52, 11, Color(color, a))
	canvas.draw_string(font, r.position + Vector2(48, r.size.y - 10), "%d or" % Cards.base_cost(id, lvl), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.88, 0.4, a))
	var stars := "★".repeat(lvl) + "☆".repeat(Cards.MAX_LEVEL - lvl)
	canvas.draw_string(font, Vector2(r.end.x - 40, r.end.y - 10), stars, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.84, 0.29, a))


## Petit symbole pour les cartes sans tour.
static func card_symbol(canvas: CanvasItem, kind: String, at: Vector2, color: Color) -> void:
	match kind:
		"walls":
			for k in 3:
				canvas.draw_rect(Rect2(at + Vector2(-12 + (k % 2) * 6, 2 - k * 7), Vector2(18, 6)), color.lightened(0.15 * k))
		"trap":
			for k in 3:
				var p := at + Vector2(-8 + k * 8, 6)
				canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 4), p + Vector2(0, -10), p + Vector2(4, 4)]), color)
		"curse":
			canvas.draw_circle(at, 10.0, color)
			canvas.draw_circle(at + Vector2(-4, -2), 2.5, Color(0.1, 0.05, 0.15))
			canvas.draw_circle(at + Vector2(4, -2), 2.5, Color(0.1, 0.05, 0.15))
		"boost":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -12), at + Vector2(9, 2), at + Vector2(3, 2), at + Vector2(3, 11), at + Vector2(-3, 11), at + Vector2(-3, 2), at + Vector2(-9, 2)]), color)
