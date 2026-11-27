extends Node2D
## Fin de l'expédition : victoire ou défaite, avec le score.


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE])
	if go:
		Run.new_run()
		get_tree().change_scene_to_file("res://scenes/map.tscn")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1d1a22"))
	var title := "Expédition réussie !" if Run.victory else "L'expédition est perdue"
	var sub := "Les deux sites de fouilles sont pacifiés." if Run.victory else "Ce qui dormait dans le %s a eu raison de vous." % Run.biome()["name"].to_lower()
	draw_string(font, Vector2(0, 220), title, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 40, Color("ffe066") if Run.victory else Color("ff8a7a"))
	draw_string(font, Vector2(0, 265), sub, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 18, Color(1, 1, 1, 0.8))
	var lines := [
		"Score : %d" % Run.score,
		"Niveaux réussis : %d" % Run.levels_cleared,
		"Ennemis vaincus : %d" % Run.kills,
	]
	for i in lines.size():
		draw_string(font, Vector2(0, 340 + i * 32), lines[i], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 20, Color.WHITE)
	draw_string(font, Vector2(0, 560), "Clique ou appuie sur Entrée pour une nouvelle expédition", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color(1, 1, 1, 0.6))
