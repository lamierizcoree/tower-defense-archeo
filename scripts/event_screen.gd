extends Node2D
## Un événement de la carte : une petite histoire et un choix (voir data/events.gd).

const CHOICE_W := 600.0
const CONTINUE := Rect2(380, 620, 200, 44)

var event_id := ""
var event: Dictionary = {}
var result := ""        # texte du résultat, une fois le choix fait


func _ready() -> void:
	event_id = Events.random_id(Run.rng)
	event = Events.get_event(event_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _choice_rect(i: int) -> Rect2:
	return Rect2(Vector2((Grid.SCREEN.x - CHOICE_W) / 2.0, 330 + i * 78), Vector2(CHOICE_W, 64))


## Un choix qui coûte du trésor est impossible si on n'en a pas assez.
func _allowed(choice: Dictionary) -> bool:
	return Run.treasure + int(choice.get("treasure", 0)) >= 0


func _unhandled_input(event_in: InputEvent) -> void:
	if not (event_in is InputEventMouseButton and event_in.pressed and event_in.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if result != "":
		if CONTINUE.has_point(p):
			Run.stop_done()
		return
	var choices: Array = event["choices"]
	for i in choices.size():
		if _choice_rect(i).has_point(p) and _allowed(choices[i]):
			result = _apply(choices[i])
			return


## Applique les effets d'un choix et renvoie le texte du résultat.
func _apply(effect: Dictionary) -> String:
	if effect.has("chance"):
		return _apply(effect["success"] if Run.rng.randf() < effect["chance"] else effect["fail"])
	var parts := [effect.get("text", "")]
	if effect.has("lives"):
		Run.lives = maxi(1, Run.lives + int(effect["lives"]))  # un événement ne peut pas tuer
		parts.append("%+d vies" % int(effect["lives"]))
	if effect.has("treasure"):
		Run.treasure += int(effect["treasure"])
		parts.append("%+d trésor" % int(effect["treasure"]))
	if effect.has("relic"):
		parts.append("Relique : " + Run.gain_relic(effect["relic"]))
	if effect.has("joker"):
		parts.append("Joker : " + Run.gain_joker(effect["joker"]))
	return "\n".join(parts)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var mouse := get_global_mouse_position()
	draw_rect(Rect2(Vector2.ZERO, Grid.SCREEN), Color("1f2430"))
	draw_string(font, Vector2(0, 80), event["name"], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 32, Color("ffe066"))
	draw_multiline_string(font, Vector2(150, 140), event["text"], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x - 300, 18, -1, Color(1, 1, 1, 0.85))
	draw_string(font, Vector2(0, 270), "Vies : %d    Trésor : %d" % [Run.lives, Run.treasure], HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x, 16, Color(1, 1, 1, 0.6))
	if result != "":
		draw_multiline_string(font, Vector2(150, 360), result, HORIZONTAL_ALIGNMENT_CENTER, Grid.SCREEN.x - 300, 18, -1, Color.WHITE)
		UI.button(self, CONTINUE, "Continuer", CONTINUE.has_point(mouse))
		return
	var choices: Array = event["choices"]
	for i in choices.size():
		var c: Dictionary = choices[i]
		var r := _choice_rect(i)
		var ok := _allowed(c)
		var hot := r.has_point(mouse) and ok
		draw_rect(r, Color(1, 1, 1, 0.14 if hot else 0.06))
		draw_rect(r, Color("ffe066") if hot else Color(1, 1, 1, 0.25), false, 2.0 if hot else 1.0)
		draw_string(font, r.position + Vector2(16, 26), c["label"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 18, Color.WHITE if ok else Color(1, 1, 1, 0.35))
		var desc: String = c["desc"] if ok else c["desc"] + "  (pas assez de trésor)"
		draw_string(font, r.position + Vector2(16, 50), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 14, Color(1, 1, 1, 0.6 if ok else 0.3))
