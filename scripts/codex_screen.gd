extends Node2D
## Le carnet de l'expédition : la liste de toutes les reliques et de tous les jokers (pouvoirs).
## Les reliques pas encore débloquées sont masquées, avec le rang qui les débloque.

const TABS := ["Reliques", "Jokers", "Synergies"]
const BTN_BACK := Rect2(20, 20, 120, 34)
const ROW_TOP := 120.0
const ROW_H := 39.0
const ROW_BOTTOM := 700.0   # les lignes se resserrent si la liste est trop longue

var tab := 0


func _process(_delta: float) -> void:
	queue_redraw()


func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2((Grid.SCREEN.x - TABS.size() * 155 + 10) / 2.0 + i * 155, 70), Vector2(145, 32))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(Run.codex_return)
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if BTN_BACK.has_point(p):
		get_tree().change_scene_to_file(Run.codex_return)
	for i in TABS.size():
		if _tab_rect(i).has_point(p):
			tab = i


func _relic_ids() -> Array:
	var ids := []
	for rarity in Relics.RARITIES:
		for id in Relics.DATA:
			if Relics.DATA[id]["rarity"] == rarity:
				ids.append(id)
	return ids


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1f1b22"))
	draw_string(font, Vector2(0, 46), "Carnet de l'expédition", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 26, Color("ffe066"))
	UI.button(self, BTN_BACK, "Retour", BTN_BACK.has_point(mouse), true, 15)
	for i in TABS.size():
		var r := _tab_rect(i)
		UI.button(self, r, TABS[i], r.has_point(mouse) or i == tab, true, 15)

	if tab == 0:
		_draw_relics(font)
	elif tab == 1:
		_draw_jokers(font)
	else:
		_draw_synergies(font)


var row_h := ROW_H


func _draw_row(font: Font, i: int, color: Color, title: String, label: String, desc: String, dim := false) -> void:
	var y := ROW_TOP + i * row_h
	if i % 2 == 0:
		draw_rect(Rect2(20, y - 4, Grid.SCREEN.x - 40, row_h), Color(1, 1, 1, 0.03))
	draw_circle(Vector2(40, y + 15), 7.0, color if not dim else Color(color, 0.3))
	var text_color := Color.WHITE if not dim else Color(1, 1, 1, 0.4)
	draw_string(font, Vector2(56, y + 20), title, HORIZONTAL_ALIGNMENT_LEFT, 230, 15, text_color)
	draw_string(font, Vector2(290, y + 20), label, HORIZONTAL_ALIGNMENT_LEFT, 110, 12, color if not dim else Color(color, 0.5))
	draw_multiline_string(font, Vector2(405, y + 12), desc, HORIZONTAL_ALIGNMENT_LEFT, 530, 12, 2, text_color if not dim else Color(1, 1, 1, 0.45))


func _draw_relics(font: Font) -> void:
	var ids := _relic_ids()
	row_h = minf(ROW_H, (ROW_BOTTOM - ROW_TOP) / ids.size())
	var unlocked := 0
	for i in ids.size():
		var id: String = ids[i]
		var r := Relics.get_relic(id)
		var color: Color = Relics.RARITY_COLORS[r["rarity"]]
		var label: String = Relics.RARITY_NAMES[r["rarity"]]
		if Profile.is_relic_unlocked(id):
			unlocked += 1
			_draw_row(font, i, color, r["name"], label, Relics.describe_short(id))
		else:
			_draw_row(font, i, color, "? ? ?", label, "Se débloque au rang d'archéologue %d (tu es au rang %d)." % [r["unlock"], Profile.rank], true)
	var foot := "%d reliques débloquées sur %d  ·  1 relique par tour (2 avec Écrin double), une seule légendaire" % [unlocked, ids.size()]
	draw_string(font, Vector2(0, Grid.SCREEN.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.55))


func _draw_jokers(font: Font) -> void:
	var ids := []
	for rar in Jokers.RARITIES:
		for id in Jokers.DATA:
			if Jokers.rarity_of(id) == rar:
				ids.append(id)
	row_h = minf(ROW_H, (ROW_BOTTOM - ROW_TOP) / ids.size())
	for i in ids.size():
		var j := Jokers.get_joker(ids[i])
		var fam: Dictionary = Jokers.FAMILIES[j["family"]]
		_draw_row(font, i, Jokers.color_of(ids[i]), "%s  %s" % [j["name"], fam["symbol"]], Jokers.RARITY_NAMES[j["rarity"]], j["desc"])
	var foot := "Les jokers changent une règle du jeu pour toute l'expédition. Tu peux en garder %d." % Profile.max_jokers()
	draw_string(font, Vector2(0, Grid.SCREEN.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.55))


## Les clans de jokers (bonus à 2 et 3 jokers) et les duos.
func _draw_synergies(font: Font) -> void:
	var rows := []
	for f in Jokers.FAMILIES:
		var fam: Dictionary = Jokers.FAMILIES[f]
		var members := []
		for id in Jokers.DATA:
			if Jokers.family_of(id) == f:
				members.append(Jokers.get_joker(id)["name"])
		rows.append([fam["color"], "%s %s" % [fam["symbol"], fam["name"]], "Clan", ", ".join(members)])
		rows.append([fam["color"], "", "2 jokers", fam["bonus"][2]])
		rows.append([fam["color"], "", "3 jokers", fam["bonus"][3]])
	for d in Jokers.DUOS:
		var duo: Dictionary = Jokers.DUOS[d]
		var a: String = Jokers.get_joker(duo["jokers"][0])["name"]
		var b: String = Jokers.get_joker(duo["jokers"][1])["name"]
		rows.append([Color("ff9f6b"), "Duo " + duo["name"], "Duo", "%s + %s : %s" % [a, b, duo["desc"]]])
	row_h = minf(ROW_H, (ROW_BOTTOM - ROW_TOP) / rows.size())
	for i in rows.size():
		_draw_row(font, i, rows[i][0], rows[i][1], rows[i][2], rows[i][3])
	var foot := "Avoir plusieurs jokers d'un même clan, ou les deux jokers d'un duo, débloque un bonus en plus."
	draw_string(font, Vector2(0, Grid.SCREEN.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.55))
