extends Node2D
## La forge : on fusionne deux reliques de même rareté en une relique plus rare.
## Depuis la carte, la fusion se paie en trésor. Depuis le feu de camp, une fusion est offerte.

const CARD := Vector2(200, 104)
const FUSE := Rect2(380, 560, 200, 44)
const LEAVE := Rect2(380, 650, 200, 44)

var picked: Array[int] = []   # index des reliques choisies dans Run.relics
var message := ""
var result := ""              # dernière relique obtenue
var from_camp := false        # venue du feu de camp (fusion offerte)


func _ready() -> void:
	from_camp = Run.forge_free


func _process(_delta: float) -> void:
	queue_redraw()


func _card_rect(i: int) -> Rect2:
	var col := i % 4
	var row := i / 4
	var total := 4 * CARD.x + 3 * 14.0
	return Rect2(Vector2((Grid.SCREEN.x - total) / 2.0 + col * (CARD.x + 14.0), 190 + row * (CARD.y + 14.0)), CARD)


## Prix de la fusion choisie (0 si elle est offerte).
func cost() -> int:
	if picked.size() < 2 or Run.forge_free:
		return 0
	var rarity: String = Relics.get_relic(Run.relics[picked[0]])["rarity"]
	return int(ceil(Relics.FUSION_COST.get(rarity, 0) * Profile.forge_mult()))


## "" si on peut fusionner maintenant, sinon la raison.
func problem() -> String:
	if picked.size() < 2:
		return "Choisis deux reliques de même rareté."
	var p := Relics.fusion_problem(Run.relics[picked[0]], Run.relics[picked[1]])
	if p != "":
		return p
	if Run.treasure < cost():
		return "Pas assez de trésor."
	return ""


func _leave() -> void:
	if from_camp and Run.forge_free:
		# fusion pas utilisée : on retourne au feu de camp choisir autre chose
		Run.forge_free = false
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
	elif from_camp:
		Run.stop_done()
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_leave()
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if LEAVE.has_point(p):
		_leave()
		return
	if FUSE.has_point(p) and problem() == "" and (not from_camp or Run.forge_free):
		_fuse()
		return
	for i in Run.relics.size():
		if _card_rect(i).has_point(p):
			message = ""
			if i in picked:
				picked.erase(i)
			elif picked.size() < 2:
				picked.append(i)
			else:
				picked[1] = i
			return


func _fuse() -> void:
	var a: String = Run.relics[picked[0]]
	var b: String = Run.relics[picked[1]]
	Run.treasure -= cost()
	result = Relics.fuse(Run.rng, a, b, Profile.is_relic_unlocked)
	# on retire les deux reliques (la plus loin d'abord pour garder les bons index)
	var sorted := picked.duplicate()
	sorted.sort()
	Run.relics.remove_at(sorted[1])
	Run.relics.remove_at(sorted[0])
	Run.relics.append(result)
	picked.clear()
	message = "%s + %s  →  %s !" % [Relics.get_relic(a)["name"], Relics.get_relic(b)["name"], Relics.get_relic(result)["name"]]
	Run.forge_free = false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Screen.visible_rect(), Color("221a17"))
	# braises
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	draw_circle(Vector2(480, 700), 160, Color(1.0, 0.4, 0.1, 0.03 + 0.02 * glow))
	draw_string(font, Vector2(0, 70), "La forge", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 32, Color("ffb070"))
	var sub := "Une fusion offerte par le feu de camp." if Run.forge_free else "Fusion faite. Bonne route !" if from_camp else "Deux reliques de même rareté donnent une relique plus rare."
	draw_string(font, Vector2(0, 105), sub, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color(1, 1, 1, 0.65))
	var prices := "Prix : commune %d, peu commune %d, rare %d trésor" % [
		ceil(Relics.FUSION_COST["commun"] * Profile.forge_mult()), ceil(Relics.FUSION_COST["non_commun"] * Profile.forge_mult()), ceil(Relics.FUSION_COST["rare"] * Profile.forge_mult())]
	draw_string(font, Vector2(0, 140), "Trésor : %d    ·    %s" % [Run.treasure, "gratuit" if Run.forge_free else prices], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color.WHITE)

	if Run.relics.is_empty():
		draw_string(font, Vector2(0, 260), "Tu n'as aucune relique.", HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17, Color(1, 1, 1, 0.5))
	for i in Run.relics.size():
		var id: String = Run.relics[i]
		var rel := Relics.get_relic(id)
		var color: Color = Relics.RARITY_COLORS[rel["rarity"]]
		var r := _card_rect(i)
		var chosen := i in picked
		var hot := r.has_point(mouse)
		draw_rect(r, Color(1, 1, 1, 0.14 if (hot or chosen) else 0.05))
		draw_rect(r, Color("ffb070") if chosen else color, false, 3.5 if chosen else 1.5)
		draw_circle(r.position + Vector2(16, 18), 6.0, color)
		draw_string(font, r.position + Vector2(28, 24), rel["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 34, 14, Color.WHITE)
		draw_string(font, r.position + Vector2(10, 44), Relics.RARITY_NAMES[rel["rarity"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		draw_multiline_string(font, r.position + Vector2(10, 62), Relics.describe_short(id), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 11, 3, Color(1, 1, 1, 0.75))

	# Aperçu et bouton
	var info := problem()
	if picked.size() == 2 and Relics.fusion_problem(Run.relics[picked[0]], Run.relics[picked[1]]) == "":
		var preview := Relics.fusion_preview(Run.relics[picked[0]], Run.relics[picked[1]])
		draw_string(font, Vector2(0, 520), preview, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color("ffd59a"))
	elif message == "":
		draw_string(font, Vector2(0, 520), info, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 15, Color(1, 1, 1, 0.55))
	var label := "Fusionner" + ("" if cost() == 0 else " (%d)" % cost())
	if not from_camp or Run.forge_free:
		UI.button(self, FUSE, label, FUSE.has_point(mouse), info == "")
	if message != "":
		draw_string(font, Vector2(0, 630), message, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 17, Color("ffe066"))
	UI.button(self, LEAVE, "Retour au camp" if Run.forge_free else "Repartir", LEAVE.has_point(mouse))
