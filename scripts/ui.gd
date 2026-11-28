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


## Infobulle d'un joker, affichée au survol : nom, rareté, clan, descriptif,
## duo éventuel et images des tours concernées. À dessiner en dernier.
static func joker_tip(canvas: CanvasItem, id: String, mouse: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var j := Jokers.get_joker(id)
	var color := Jokers.color_of(id)
	var fam: Dictionary = Jokers.FAMILIES[j["family"]]
	var towers := Jokers.towers_of(id)
	var desc: String = j["desc"]
	var partner := Jokers.partner_of(id)
	if partner != "":
		desc += "\nDuo avec %s." % Jokers.get_joker(partner)["name"]
	const W := 300.0
	var text_h := font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 14).y
	var h := 62.0 + text_h + 14.0
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
	var sub := "Joker %s · %s %s" % [Jokers.RARITY_NAMES[j["rarity"]].to_lower(), fam["symbol"], fam["name"]]
	canvas.draw_string(font, r.position + Vector2(12, 46), sub, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 13, color)
	canvas.draw_multiline_string(font, r.position + Vector2(12, 72), desc, HORIZONTAL_ALIGNMENT_LEFT, W - 24, 14, -1, Color(1, 1, 1, 0.88))
	if towers.is_empty():
		return
	var y := r.position.y + 62.0 + text_h + 10.0
	canvas.draw_line(Vector2(r.position.x + 12, y), Vector2(r.end.x - 12, y), Color(1, 1, 1, 0.15), 1.0)
	canvas.draw_string(font, Vector2(r.position.x + 12, y + 18), "Tours concernées", HORIZONTAL_ALIGNMENT_LEFT, W - 24, 12, Color(1, 1, 1, 0.55))
	var slot := 70.0
	var x0 := r.position.x + W / 2.0 - slot * towers.size() / 2.0
	for i in towers.size():
		var cx := x0 + slot * (i + 0.5)
		TowerArt.draw_icon(canvas, towers[i], Vector2(cx, y + 42), 34.0)
		canvas.draw_string(font, Vector2(cx - slot / 2.0, y + 72), TowerTypes.get_type(towers[i])["name"], HORIZONTAL_ALIGNMENT_CENTER, slot, 12, Color.WHITE)
