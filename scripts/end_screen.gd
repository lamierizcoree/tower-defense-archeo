extends Node2D
## Fin de l'expédition : victoire ou défaite, score, points d'amélioration gagnés.

const BUTTON := Rect2(330, 620, 300, 44)


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventMouseButton and event.pressed and BUTTON.has_point(get_global_mouse_position())) \
		or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE])
	if go:
		get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1d1a22"))
	var title := "Expédition réussie !" if Run.victory else "L'expédition est perdue"
	var sub := "Les deux sites de fouilles sont pacifiés." if Run.victory else "Ce qui dormait dans le %s a eu raison de vous." % Run.biome()["name"].to_lower()
	draw_string(font, Vector2(0, 160), title, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 40, Color("ffe066") if Run.victory else Color("ff8a7a"))
	draw_string(font, Vector2(0, 205), sub, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 18, Color(1, 1, 1, 0.8))
	var lines := [
		("Score : %d   (meilleur : %d)" % [Run.score, Profile.best_score]) + ("   dont +%d de difficulté" % Run.score_bonus if Run.score_bonus > 0 else ""),
		"Niveaux réussis : %d" % Run.levels_cleared,
		"Ennemis vaincus : %d" % Run.kills,
		"",
		"Rang d'archéologue : %d" % Profile.rank,
		"Points d'amélioration gagnés : +%d   (total : %d)" % [Run.points_gained, Profile.points_earned()],
		"Score cumulé : %d   ·   prochain point à %d" % [Profile.total_score, Profile.next_point_score()] if Profile.next_point_score() > 0 else "Tous les points sont gagnés",
	]
	for i in lines.size():
		draw_string(font, Vector2(0, 280 + i * 34), lines[i], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 20, Color.WHITE)
	if not Run.new_unlocks.is_empty() and Run.victory:
		var names := []
		for id in Run.new_unlocks:
			names.append(Relics.get_relic(id)["name"])
		draw_string(font, Vector2(0, 495), "Nouvelle relique débloquée : " + ", ".join(names), HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color("ffd54a"))
	var next := Profile.next_unlock()
	if not next.is_empty():
		var r := Relics.get_relic(next[1])
		var text := "Prochaine relique débloquée au rang %d : %s" % [next[0], r["name"]]
		draw_string(font, Vector2(0, 530), text, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Relics.RARITY_COLORS[r["rarity"]])
	if Run.difficulty_unlocked_now:
		var d := Profile.difficulty_unlocked
		var rule := Difficulty.rule_of(d)
		draw_string(font, Vector2(0, 560), "%s débloquée ! Nouvelle règle : %s" % [Difficulty.name_of(d), rule["name"]], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17, Color("ff8a5c"))
		draw_string(font, Vector2(0, 584), rule["desc"], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 14, Color(1, 1, 1, 0.7))
	UI.button(self, BUTTON, "Retour au camp de base", BUTTON.has_point(get_global_mouse_position()))
