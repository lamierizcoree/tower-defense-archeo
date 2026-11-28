extends Node2D
## Le marchand ambulant : on dépense son trésor en reliques, jokers et vies.
## Le trésor vient de l'or restant à la fin des niveaux (la moitié est gardée).

const CARD := Vector2(140, 285)
const LEAVE := Rect2(380, 650, 200, 44)
const RELIC_PRICES := {"commun": 25, "non_commun": 40, "rare": 60, "legendaire": 100}
const JOKER_PRICES := {"commun": 30, "non_commun": 45, "rare": 70, "legendaire": 110}
const LIVES_PRICE := 15
const LIVES_AMOUNT := 3

var items: Array = []   # {"kind": "relic"/"joker"/"lives", "id", "price", "sold"}
var message := ""


func _ready() -> void:
	var offered := []
	for i in 3:
		var id := Relics.draw(Run.rng, "commun", Profile.luck(), Profile.is_relic_unlocked)
		if id in offered:
			id = Relics.draw(Run.rng, "non_commun", Profile.luck(), Profile.is_relic_unlocked)
		offered.append(id)
		items.append({"kind": "relic", "id": id, "price": RELIC_PRICES[Relics.get_relic(id)["rarity"]], "sold": false})
	for id in Jokers.draw_choices(Run.rng, Run.jokers, 0, Profile.luck()).slice(0, 2):
		items.append({"kind": "joker", "id": id, "price": JOKER_PRICES[Jokers.rarity_of(id)], "sold": false})
	items.append({"kind": "lives", "id": "", "price": LIVES_PRICE, "sold": false})


func _process(_delta: float) -> void:
	queue_redraw()


func _card_rect(i: int) -> Rect2:
	var total := items.size() * CARD.x + (items.size() - 1) * 12.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + i * (CARD.x + 12.0), 170), CARD)


## Pourquoi on ne peut pas acheter cet objet ("" si on peut).
func _blocked(item: Dictionary) -> String:
	if item["sold"]:
		return "Vendu"
	if Run.treasure < item["price"]:
		return "Pas assez de trésor"
	if item["kind"] == "relic" and Run.relics.size() >= Relics.MAX_HELD:
		return "Inventaire plein"
	if item["kind"] == "joker" and Run.jokers.size() >= Profile.max_jokers():
		return "Main de jokers pleine"
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if LEAVE.has_point(p):
		Run.stop_done()
		return
	for i in items.size():
		if _card_rect(i).has_point(p):
			var item: Dictionary = items[i]
			var why := _blocked(item)
			if why != "":
				message = why
				return
			Run.treasure -= item["price"]
			item["sold"] = true
			match item["kind"]:
				"relic":
					Run.relics.append(item["id"])
					message = "%s rejoint ton sac." % Relics.get_relic(item["id"])["name"]
				"joker":
					Run.jokers.append(item["id"])
					message = "Nouveau joker : %s." % Jokers.get_joker(item["id"])["name"]
				"lives":
					Run.lives += LIVES_AMOUNT
					message = "+%d vies." % LIVES_AMOUNT
			return


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	var tip := ""  # joker survolé : son infobulle est dessinée à la fin
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("2a2118"))
	draw_string(font, Vector2(0, 70), "Le marchand ambulant", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 32, Color("ffe066"))
	draw_string(font, Vector2(0, 105), "« Tout se vend, tout s'achète. Surtout ce qui vient des tombeaux. »", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(0, 142), "Trésor : %d    Vies : %d    Reliques %d/%d    Jokers %d/%d" % [Run.treasure, Run.lives, Run.relics.size(), Relics.MAX_HELD, Run.jokers.size(), Profile.max_jokers()], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17, Color.WHITE)
	for i in items.size():
		var item: Dictionary = items[i]
		var r := _card_rect(i)
		var title_txt := ""
		var label := ""
		var desc := ""
		var color := Color("c9b48a")
		match item["kind"]:
			"relic":
				var rel := Relics.get_relic(item["id"])
				title_txt = rel["name"]
				color = Relics.RARITY_COLORS[rel["rarity"]]
				label = "RELIQUE\n" + Relics.RARITY_NAMES[rel["rarity"]].to_upper()
				desc = Relics.describe_short(item["id"])
			"joker":
				var j := Jokers.get_joker(item["id"])
				title_txt = j["name"]
				color = Jokers.color_of(item["id"])
				label = "JOKER %s\n" % Jokers.FAMILIES[j["family"]]["symbol"] + Jokers.RARITY_NAMES[j["rarity"]].to_upper()
				desc = j["desc"]
				var unlock := Jokers.would_unlock(Run.jokers, item["id"])
				if unlock != "" and not item["sold"]:
					desc += "\n\nActive : " + unlock
				if r.has_point(mouse) and not item["sold"]:
					tip = item["id"]
			"lives":
				title_txt = "Trousse de soins"
				color = Color("e06666")
				label = "SERVICE"
				desc = "+%d vies" % LIVES_AMOUNT
		var blocked := _blocked(item)
		var hot := r.has_point(mouse) and blocked == ""
		draw_rect(r, Color(1, 1, 1, 0.12 if hot else 0.05))
		draw_rect(r, color if not item["sold"] else Color(1, 1, 1, 0.15), false, 3.0 if hot else 1.5)
		var alpha := 0.35 if item["sold"] else 1.0
		draw_multiline_string(font, r.position + Vector2(8, 32), title_txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 16, 2, Color(1, 1, 1, alpha))
		draw_multiline_string(font, r.position + Vector2(0, 86), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, 2, Color(color, alpha))
		draw_multiline_string(font, r.position + Vector2(8, 132), desc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 12, 7, Color(1, 1, 1, 0.8 * alpha))
		var item_towers: Array = Relics.towers_of(item["id"]) if item["kind"] == "relic" else []
		if not item_towers.is_empty() and not item["sold"]:
			TowerArt.draw_icon_row(self, item_towers, r.position + Vector2(r.size.x / 2, r.size.y - 52), 28.0)
		var price := "VENDU" if item["sold"] else "%d trésor" % item["price"]
		draw_string(font, r.position + Vector2(0, r.size.y - 16), price, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17,
			Color(1, 1, 1, 0.4) if item["sold"] else (Color("ffe066") if Run.treasure >= item["price"] else Color(1, 0.5, 0.4)))
	if message != "":
		draw_string(font, Vector2(0, 470), message, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17, Color("ffe066"))
	draw_string(font, Vector2(0, 520), "Le trésor vient de l'or qu'il te reste à la fin de chaque niveau (la moitié est gardée).", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 13, Color(1, 1, 1, 0.5))
	UI.button(self, LEAVE, "Repartir", LEAVE.has_point(mouse))
	if tip != "":
		UI.joker_tip(self, tip, mouse)
