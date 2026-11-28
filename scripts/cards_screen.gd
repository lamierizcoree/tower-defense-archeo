extends Node2D
## L'atelier de cartes, après chaque victoire (combat, élite, fouille, boss).
## - On améliore une carte du deck (2 fois au plus par carte, pour toute l'expédition).
## - On peut graver une relique : elle est détruite et donne une amélioration de plus.
## - Un petit étal vend une relique et un joker contre du trésor.

const Shop := preload("res://scripts/shop_screen.gd")

const CARD := Vector2(176, 76)
const GAP := 8.0
const COLS := 5
const TOP := 108.0
const UPGRADE_BTN := Rect2(690, 448, 240, 40)
const CONTINUE := Rect2(380, 684, 200, 42)

var upgrades_left := 1
var chosen := -1          # index de la carte choisie dans Run.deck
var message := ""
var stall: Array = []     # {"kind": "relic"/"joker", "id", "price", "sold"}


func _ready() -> void:
	var relic := Relics.draw(Run.rng, "commun", Profile.luck(), Profile.is_relic_unlocked)
	stall.append({"kind": "relic", "id": relic, "price": Shop.RELIC_PRICES[Relics.get_relic(relic)["rarity"]], "sold": false})
	var jokers := Jokers.draw_choices(Run.rng, Run.jokers, 0, Profile.luck())
	if not jokers.is_empty():
		stall.append({"kind": "joker", "id": jokers[0], "price": Shop.JOKER_PRICES[Jokers.rarity_of(jokers[0])], "sold": false})


func _process(_delta: float) -> void:
	queue_redraw()


func _card_rect(i: int) -> Rect2:
	var x0 := (Grid.SCREEN.x - (COLS * CARD.x + (COLS - 1) * GAP)) / 2.0
	return Rect2(Vector2(x0 + (i % COLS) * (CARD.x + GAP), TOP + (i / COLS) * (CARD.y + GAP)), CARD)


func _relic_rect(i: int) -> Rect2:
	var w := 108.0
	var total := Relics.MAX_HELD * w + (Relics.MAX_HELD - 1) * 6.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (w + 6.0), 538), Vector2(w, 40))


func _stall_rect(i: int) -> Rect2:
	return Rect2(Vector2(Grid.SCREEN.x / 2.0 - 310 + i * 320, 612), Vector2(300, 58))


func _stall_blocked(item: Dictionary) -> String:
	if item["sold"]:
		return "Vendu"
	if Run.treasure < item["price"]:
		return "Pas assez de trésor"
	if item["kind"] == "relic" and Run.relics.size() >= Relics.MAX_HELD:
		return "Inventaire de reliques plein"
	if item["kind"] == "joker" and Run.jokers.size() >= Profile.max_jokers():
		return "Main de jokers pleine"
	return ""


func _can_upgrade(i: int) -> bool:
	return i >= 0 and i < Run.deck.size() and upgrades_left > 0 and Run.deck[i]["lvl"] < Cards.MAX_LEVEL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		Run.cards_done()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if CONTINUE.has_point(p):
		Run.cards_done()
		return
	if UPGRADE_BTN.has_point(p) and _can_upgrade(chosen):
		Run.upgrade_card(chosen)
		upgrades_left -= 1
		var c := Cards.get_card(Run.deck[chosen]["id"])
		message = "%s améliorée (%s)." % [c["name"], "★".repeat(Run.deck[chosen]["lvl"])]
		return
	for i in Run.deck.size():
		if _card_rect(i).has_point(p):
			chosen = i
			return
	for i in Run.relics.size():
		if _relic_rect(i).has_point(p):
			var name: String = Relics.get_relic(Run.relics[i])["name"]
			Run.relics.remove_at(i)
			upgrades_left += Cards.RELIC_ENGRAVE
			message = "%s gravée : +%d amélioration." % [name, Cards.RELIC_ENGRAVE]
			return
	for i in stall.size():
		if _stall_rect(i).has_point(p):
			var item: Dictionary = stall[i]
			var why := _stall_blocked(item)
			if why != "":
				message = why
				return
			Run.treasure -= item["price"]
			item["sold"] = true
			if item["kind"] == "relic":
				Run.relics.append(item["id"])
				message = "%s rejoint ton sac." % Relics.get_relic(item["id"])["name"]
			else:
				Run.jokers.append(item["id"])
				message = "Nouveau joker : %s." % Jokers.get_joker(item["id"])["name"]
			return


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	var tip := ""
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("241e1a"))
	draw_string(font, Vector2(0, 46), "Atelier de cartes", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 30, Color("ffe066"))
	var sub := "Améliorations à faire : %d  ·  chaque carte s'améliore 2 fois au plus, pour toute l'expédition" % upgrades_left
	draw_string(font, Vector2(0, 76), sub, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color.WHITE if upgrades_left > 0 else Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(0, 98), "Ton deck (%d cartes)  ·  Trésor %d" % [Run.deck.size(), Run.treasure], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.55))

	for i in Run.deck.size():
		var r := _card_rect(i)
		var card: Dictionary = Run.deck[i]
		UI.deck_card(self, r, card["id"], card["lvl"], r.has_point(mouse), i == chosen, card["lvl"] >= Cards.MAX_LEVEL)

	# Détail de la carte choisie
	var shown := chosen
	for i in Run.deck.size():
		if _card_rect(i).has_point(mouse):
			shown = i
	if shown >= 0:
		var card: Dictionary = Run.deck[shown]
		var c := Cards.get_card(card["id"])
		var x := 30.0
		draw_string(font, Vector2(x, 452), "%s  %s" % [c["name"], "★".repeat(card["lvl"])], HORIZONTAL_ALIGNMENT_LEFT, 640, 16, Color.WHITE)
		draw_string(font, Vector2(x, 472), "Maintenant : " + Cards.describe(card["id"], card["lvl"]), HORIZONTAL_ALIGNMENT_LEFT, 650, 12, Color(1, 1, 1, 0.75))
		var next := Cards.upgrade_text(card["id"], card["lvl"])
		draw_string(font, Vector2(x, 492), "Amélioration : " + next if next != "" else "Niveau maximum", HORIZONTAL_ALIGNMENT_LEFT, 650, 13, Color("ffd54a") if next != "" else Color(1, 1, 1, 0.45))
	else:
		draw_string(font, Vector2(30, 470), "Clique sur une carte pour la choisir.", HORIZONTAL_ALIGNMENT_LEFT, 640, 14, Color(1, 1, 1, 0.6))
	UI.button(self, UPGRADE_BTN, "Améliorer cette carte", UPGRADE_BTN.has_point(mouse), _can_upgrade(chosen), 15)
	if message != "":
		draw_string(font, Vector2(0, 516), message, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 14, Color("ffe066"))

	# Graver une relique
	draw_string(font, Vector2(0, 532), "Graver une relique : clique dessus pour la détruire et gagner une amélioration de plus" if not Run.relics.is_empty() else "Pas de relique à graver", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 12, Color(1, 1, 1, 0.55))
	for i in Run.relics.size():
		var r := _relic_rect(i)
		var rel := Relics.get_relic(Run.relics[i])
		var color: Color = Relics.RARITY_COLORS[rel["rarity"]]
		var hot := r.has_point(mouse)
		draw_rect(r, Color(1, 1, 1, 0.14 if hot else 0.05))
		draw_rect(r, Color("ff6b5a") if hot else Color(color, 0.6), false, 2.0 if hot else 1.0)
		draw_circle(r.position + Vector2(10, 20), 5.0, color)
		draw_string(font, r.position + Vector2(19, 25), rel["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 21, 11, Color.WHITE)

	# Étal
	draw_string(font, Vector2(0, 604), "Étal de fin de manche (payé en trésor)", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color("ffd59a"))
	for i in stall.size():
		var item: Dictionary = stall[i]
		var r := _stall_rect(i)
		var ok := _stall_blocked(item) == ""
		var hot := r.has_point(mouse)
		var title := ""
		var desc := ""
		var color := Color.WHITE
		if item["kind"] == "relic":
			var rel := Relics.get_relic(item["id"])
			title = "Relique : " + rel["name"]
			desc = Relics.describe_short(item["id"])
			color = Relics.RARITY_COLORS[rel["rarity"]]
		else:
			var j := Jokers.get_joker(item["id"])
			title = "Joker : " + j["name"]
			desc = j["desc"]
			color = Jokers.color_of(item["id"])
			if hot and not item["sold"]:
				tip = item["id"]
		draw_rect(r, Color(1, 1, 1, 0.14 if hot and ok else 0.05))
		draw_rect(r, Color(color, 0.8 if not item["sold"] else 0.2), false, 2.0 if hot else 1.0)
		var alpha := 0.35 if item["sold"] else 1.0
		draw_string(font, r.position + Vector2(10, 20), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 90, 13, Color(1, 1, 1, alpha))
		draw_string(font, r.position + Vector2(r.size.x - 84, 20), "VENDU" if item["sold"] else "%d trésor" % item["price"], HORIZONTAL_ALIGNMENT_RIGHT, 76, 13, Color("ffe066") if ok else Color(1, 0.5, 0.4, alpha))
		draw_multiline_string(font, r.position + Vector2(10, 38), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 11, 2, Color(1, 1, 1, 0.7 * alpha))
	UI.button(self, CONTINUE, "Continuer" if upgrades_left == 0 else "Continuer sans améliorer", CONTINUE.has_point(mouse), true, 14 if upgrades_left == 0 else 12)
	if tip != "":
		UI.joker_tip(self, tip, mouse, Run.jokers)
