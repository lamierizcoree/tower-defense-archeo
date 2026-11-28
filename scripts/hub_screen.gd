extends Node2D
## Le camp de base : écran d'accueil entre deux expéditions.
## On y lance une expédition, on consulte le carnet et on répartit ses points d'amélioration.

const BTN_PLAY := Rect2(330, 330, 300, 50)
const BTN_ABANDON := Rect2(330, 390, 300, 34)
const BTN_CODEX := Rect2(330, 434, 300, 40)
const BTN_DECK := Rect2(330, 480, 300, 40)
const BTN_UPGRADES := Rect2(330, 526, 300, 40)
const BTN_RESET := Rect2(790, 690, 160, 32)
const BTN_TUTORIAL := Rect2(10, 690, 200, 32)
const BTN_DIFF_DOWN := Rect2(330, 580, 44, 40)
const BTN_DIFF_UP := Rect2(586, 580, 44, 40)

var confirm_reset := false


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if BTN_PLAY.has_point(p):
		if not Run.started:
			Run.new_run()
		get_tree().change_scene_to_file("res://scenes/map.tscn")
	elif BTN_ABANDON.has_point(p) and Run.started:
		Run.new_run()
		get_tree().change_scene_to_file("res://scenes/map.tscn")
	elif BTN_CODEX.has_point(p):
		Run.codex_return = "res://scenes/hub.tscn"
		get_tree().change_scene_to_file("res://scenes/codex.tscn")
	elif BTN_TUTORIAL.has_point(p):
		Run.start_tutorial()
	elif BTN_DECK.has_point(p):
		get_tree().change_scene_to_file("res://scenes/deck.tscn")
	elif BTN_UPGRADES.has_point(p):
		get_tree().change_scene_to_file("res://scenes/upgrades.tscn")
	elif BTN_DIFF_DOWN.has_point(p) and _can_choose_difficulty():
		Profile.change_difficulty(-1)
	elif BTN_DIFF_UP.has_point(p) and _can_choose_difficulty():
		Profile.change_difficulty(1)
	elif BTN_RESET.has_point(p):
		if confirm_reset:
			Profile.reset()
			confirm_reset = false
		else:
			confirm_reset = true
		return
	confirm_reset = false


## On choisit la difficulté avant de partir, pas pendant une expédition.
func _can_choose_difficulty() -> bool:
	return Profile.difficulty_unlocked > 0 and not Run.started


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("231d19"))
	# Un peu de décor : des dunes et une tente
	draw_circle(Vector2(150, 900), 380, Color("3a2e22"))
	draw_circle(Vector2(820, 950), 420, Color("33291f"))
	draw_colored_polygon(PackedVector2Array([Vector2(110, 640), Vector2(190, 540), Vector2(270, 640)]), Color("8c6d45"))
	draw_colored_polygon(PackedVector2Array([Vector2(175, 640), Vector2(190, 590), Vector2(205, 640)]), Color("2b211a"))

	draw_string(font, Vector2(0, 90), "Camp de base", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 40, Color("ffe066"))
	draw_string(font, Vector2(0, 125), "Expéditions archéologiques au désert et sous la glace", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.6))

	var lines := [
		"Rang d'archéologue : %d" % Profile.rank,
		"Expéditions : %d  ·  réussies : %d  ·  meilleur score : %d" % [Profile.runs, Profile.victories, Profile.best_score],
		"Points d'amélioration : %d utilisés sur %d" % [Profile.points_used(), Profile.points_available()],
	]
	for i in lines.size():
		draw_string(font, Vector2(0, 185 + i * 28), lines[i], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17 if i == 0 else 15, Color.WHITE if i == 0 else Color(1, 1, 1, 0.8))
	var next := Profile.next_unlock()
	if not next.is_empty():
		var r := Relics.get_relic(next[1])
		draw_string(font, Vector2(0, 285), "Prochaine relique au rang %d (%s)" % [next[0], Relics.RARITY_NAMES[r["rarity"]].to_lower()], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 14, Relics.RARITY_COLORS[r["rarity"]])

	UI.button(self, BTN_PLAY, "Continuer l'expédition" if Run.started else "Nouvelle expédition", BTN_PLAY.has_point(mouse), true, 20)
	if Run.started:
		UI.button(self, BTN_ABANDON, "Abandonner et repartir de zéro", BTN_ABANDON.has_point(mouse), true, 13)
	UI.button(self, BTN_CODEX, "Carnet des reliques et pouvoirs", BTN_CODEX.has_point(mouse))
	UI.button(self, BTN_DECK, "Deck de cartes" + ("  (en cours d'expédition)" if Run.started else ""), BTN_DECK.has_point(mouse), true, 16)
	var free := Profile.points_available() - Profile.points_used()
	UI.button(self, BTN_UPGRADES, "Améliorations" + (" (%d à répartir)" % free if free > 0 else ""), BTN_UPGRADES.has_point(mouse))
	_draw_difficulty(font, mouse)
	if not Profile.tutorial_done:
		draw_rect(BTN_TUTORIAL.grow(3), Color(1, 0.88, 0.4, 0.25 + 0.2 * sin(Time.get_ticks_msec() / 300.0)))
	UI.button(self, BTN_TUTORIAL, "Tutoriel" if Profile.tutorial_done else "Tutoriel (conseillé)", BTN_TUTORIAL.has_point(mouse), true, 14)
	UI.button(self, BTN_RESET, "Sûr ? Clique encore" if confirm_reset else "Effacer le profil", BTN_RESET.has_point(mouse), true, 12)


## Sélecteur de difficulté, visible une fois la première expédition réussie.
func _draw_difficulty(font: Font, mouse: Vector2) -> void:
	if Profile.difficulty_unlocked == 0:
		return
	var level := Run.difficulty if Run.started else Profile.difficulty
	var color := Color.WHITE if level == 0 else Color("ff8a5c")
	var choose := _can_choose_difficulty()
	UI.button(self, BTN_DIFF_DOWN, "<", BTN_DIFF_DOWN.has_point(mouse), choose and level > 0, 20)
	UI.button(self, BTN_DIFF_UP, ">", BTN_DIFF_UP.has_point(mouse), choose and level < Profile.difficulty_unlocked, 20)
	draw_string(font, Vector2(380, 607), Difficulty.name_of(level), HORIZONTAL_ALIGNMENT_CENTER, 200, 18, color)
	var sub := "Aucune règle en plus" if level == 0 else "%d règle%s en plus, score +%d %%  ·  survole pour la liste" % [level, "s" if level > 1 else "", roundi(Difficulty.SCORE_PER_LEVEL * level * 100)]
	if Run.started:
		sub = "Expédition en cours  ·  " + sub
	else:
		sub += "  ·  débloquée jusqu'à %d" % Profile.difficulty_unlocked
	draw_string(font, Vector2(0, 642), sub, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.6))
	# Liste des règles actives au survol du nom de la difficulté
	if level > 0 and Rect2(380, 580, 200, 70).has_point(mouse):
		var h := 16.0 + level * 38.0
		var box := Rect2(150, 572 - h, 660, h)
		draw_rect(box, Color(0.08, 0.07, 0.06, 0.96))
		draw_rect(box, Color("ff8a5c"), false, 1.5)
		for i in level:
			var r: Dictionary = Difficulty.RULES[i]
			var y := box.position.y + 24 + i * 38
			draw_string(font, Vector2(box.position.x + 12, y), "%d. %s" % [i + 1, r["name"]], HORIZONTAL_ALIGNMENT_LEFT, 640, 14, Color("ff8a5c"))
			draw_string(font, Vector2(box.position.x + 28, y + 17), r["desc"], HORIZONTAL_ALIGNMENT_LEFT, 620, 12, Color(1, 1, 1, 0.8))
