extends Node2D
## Les améliorations permanentes : on répartit les points gagnés avec le score.
## Les points se redistribuent librement et gratuitement.

const BTN_BACK := Rect2(20, 20, 120, 34)
const BTN_CLEAR := Rect2(380, 670, 200, 36)
const ROW_TOP := 200.0
const ROW_H := 62.0


func _process(_delta: float) -> void:
	queue_redraw()


func _minus_rect(i: int) -> Rect2:
	return Rect2(Vector2(690, ROW_TOP + i * ROW_H + 8), Vector2(36, 32))


func _plus_rect(i: int) -> Rect2:
	return Rect2(Vector2(890, ROW_TOP + i * ROW_H + 8), Vector2(36, 32))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if BTN_BACK.has_point(p):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
	elif BTN_CLEAR.has_point(p):
		Profile.clear_points()
	for i in Upgrades.ORDER.size():
		var id: String = Upgrades.ORDER[i]
		if _minus_rect(i).has_point(p):
			Profile.remove_point(id)
		elif _plus_rect(i).has_point(p):
			Profile.add_point(id)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1f1b22"))
	draw_string(font, Vector2(0, 46), "Améliorations", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 26, Color("ffe066"))
	UI.button(self, BTN_BACK, "Retour", BTN_BACK.has_point(mouse), true, 15)

	var used := Profile.points_used()
	var avail := Profile.points_available()
	draw_string(font, Vector2(0, 100), "Points utilisés : %d sur %d disponibles" % [used, avail], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 20, Color.WHITE)
	var next := Profile.next_point_score()
	var next_text := "plafond atteint" if next < 0 else "prochain point à %d" % next
	var info := "Score cumulé : %d  ·  %s  ·  points gagnés : %d (plafond %d)" % [
		Profile.total_score, next_text, Profile.points_earned(), Upgrades.CAP]
	draw_string(font, Vector2(0, 130), info, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, 160), "Chaque point coûte plus de score que le précédent. Tu peux redistribuer tes points librement entre deux expéditions.", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.6))

	for i in Upgrades.ORDER.size():
		var id: String = Upgrades.ORDER[i]
		var u := Upgrades.get_upgrade(id)
		var disabled: bool = u.get("disabled", false)
		var y := ROW_TOP + i * ROW_H
		draw_rect(Rect2(30, y, Grid.SCREEN.x - 60, ROW_H - 8), Color(1, 1, 1, 0.04))
		var text_color := Color(1, 1, 1, 0.4) if disabled else Color.WHITE
		draw_string(font, Vector2(46, y + 24), u["name"], HORIZONTAL_ALIGNMENT_LEFT, 200, 17, text_color)
		draw_string(font, Vector2(46, y + 44), u["desc"], HORIZONTAL_ALIGNMENT_LEFT, 630, 12, Color(1, 1, 1, 0.35 if disabled else 0.65))
		# Pastilles 0 à 10
		var lvl := Profile.level_of(id)
		for k in Upgrades.MAX_PER_CATEGORY:
			var c := Vector2(742 + k * 14, y + 24)
			draw_circle(c, 5.0, Color("ffe066") if k < lvl else Color(1, 1, 1, 0.15))
		UI.button(self, _minus_rect(i), "-", _minus_rect(i).has_point(mouse), lvl > 0, 20)
		UI.button(self, _plus_rect(i), "+", _plus_rect(i).has_point(mouse), Profile.can_add(id), 20)

	UI.button(self, BTN_CLEAR, "Tout redistribuer", BTN_CLEAR.has_point(mouse), used > 0, 15)
