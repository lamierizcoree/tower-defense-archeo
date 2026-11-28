extends Node2D
## Construire son deck au camp de base : 20 cartes choisies parmi celles débloquées,
## avec au moins une carte de tour et une carte de murs. Les cartes se débloquent
## avec le rang d'archéologue. Le deck est sauvegardé dans le profil.

const ROW_H := 37.0
const TOP := 128.0
const BACK := Rect2(560, 680, 200, 40)
const DEFAULT_BTN := Rect2(200, 680, 200, 40)

var counts := {}


func _ready() -> void:
	counts = Profile.deck_counts()


func _process(_delta: float) -> void:
	queue_redraw()


func _row_rect(i: int) -> Rect2:
	return Rect2(40, TOP + i * ROW_H, 880, ROW_H - 4)


func _minus_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.end.x - 110, r.position.y + 4, 30, r.size.y - 8)


func _plus_rect(i: int) -> Rect2:
	var r := _row_rect(i)
	return Rect2(r.end.x - 38, r.position.y + 4, 30, r.size.y - 8)


func _total() -> int:
	var n := 0
	for id in counts:
		n += int(counts[id])
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if BACK.has_point(p):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
		return
	if DEFAULT_BTN.has_point(p):
		counts = Cards.DEFAULT_DECK.duplicate()
		Profile.set_deck(counts)
		return
	var ids := Cards.DATA.keys()
	for i in ids.size():
		var id: String = ids[i]
		if not Profile.is_card_unlocked(id):
			continue
		var n := int(counts.get(id, 0))
		if _minus_rect(i).has_point(p) and n > 0:
			counts[id] = n - 1
			Profile.set_deck(counts)
		elif _plus_rect(i).has_point(p) and n < Cards.MAX_COPIES and _total() < Cards.DECK_SIZE:
			counts[id] = n + 1
			Profile.set_deck(counts)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Screen.visible_rect(), Color("231d19"))
	draw_string(font, Vector2(0, 52), "Ton deck de cartes", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 32, Color("ffe066"))
	var towers := 0
	var walls := 0
	for id in counts:
		if Cards.kind_of(id) == "tower":
			towers += counts[id]
		elif Cards.kind_of(id) == "walls":
			walls += counts[id]
	var head := "%d / %d cartes  ·  %d de tour  ·  %d de murs  ·  %d exemplaires au plus par carte" % [_total(), Cards.DECK_SIZE, towers, walls, Cards.MAX_COPIES]
	draw_string(font, Vector2(0, 84), head, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color.WHITE)
	var problem := Cards.deck_problem(counts)
	var info := "Retire une carte (-) pour en ajouter une autre (+). Main de départ : %d cartes, dont toujours une tour et une carte de murs. +%d cartes après chaque vague." % [Cards.DRAW_START, Cards.DRAW_PER_WAVE]
	draw_string(font, Vector2(0, 108), problem + "  Sinon, le deck de départ sera utilisé." if problem != "" else info, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 0.55, 0.45) if problem != "" else Color(1, 1, 1, 0.55))

	var ids := Cards.DATA.keys()
	var hover := -1
	for i in ids.size():
		var id: String = ids[i]
		var c := Cards.get_card(id)
		var r := _row_rect(i)
		var unlocked := Profile.is_card_unlocked(id)
		var n := int(counts.get(id, 0))
		var color := Cards.color_of(id)
		if r.has_point(mouse):
			hover = i
		draw_rect(r, Color(1, 1, 1, 0.1 if r.has_point(mouse) else (0.06 if n > 0 else 0.025)))
		draw_rect(Rect2(r.position, Vector2(5, r.size.y)), color if unlocked else Color(1, 1, 1, 0.15))
		if not unlocked:
			draw_string(font, r.position + Vector2(16, 24), "???  ·  débloquée au rang %d" % c["unlock"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
			continue
		if c["kind"] == "tower":
			TowerArt.draw_icon(self, c["tower"], r.position + Vector2(28, r.size.y / 2), 30.0)
		else:
			UI.card_symbol(self, c["kind"], r.position + Vector2(28, r.size.y / 2), color)
		draw_string(font, r.position + Vector2(52, 16), c["name"], HORIZONTAL_ALIGNMENT_LEFT, 190, 14, Color.WHITE)
		draw_string(font, r.position + Vector2(52, 32), "%s  ·  %d or" % [Cards.KINDS[c["kind"]]["name"], Cards.base_cost(id, 0)], HORIZONTAL_ALIGNMENT_LEFT, 190, 11, color)
		draw_string(font, r.position + Vector2(250, 23), Cards.describe(id, 0), HORIZONTAL_ALIGNMENT_LEFT, 500, 12, Color(1, 1, 1, 0.75))
		UI.button(self, _minus_rect(i), "-", _minus_rect(i).has_point(mouse), n > 0, 16)
		draw_string(font, Vector2(r.end.x - 80, r.position.y + 25), str(n), HORIZONTAL_ALIGNMENT_CENTER, 42, 16, Color.WHITE if n > 0 else Color(1, 1, 1, 0.4))
		UI.button(self, _plus_rect(i), "+", _plus_rect(i).has_point(mouse), n < Cards.MAX_COPIES and _total() < Cards.DECK_SIZE, 16)
	if hover >= 0 and Profile.is_card_unlocked(ids[hover]):
		var id: String = ids[hover]
		var y := TOP + ids.size() * ROW_H + 6
		draw_string(font, Vector2(40, y + 14), "Améliorations (pendant l'expédition) : 1) %s   2) %s" % [Cards.upgrade_text(id, 0), Cards.upgrade_text(id, 1)], HORIZONTAL_ALIGNMENT_LEFT, 880, 12, Color("ffd54a"))
	UI.button(self, DEFAULT_BTN, "Deck de départ", DEFAULT_BTN.has_point(mouse), true, 14)
	UI.button(self, BACK, "Retour au camp", BACK.has_point(mouse), true, 14)
