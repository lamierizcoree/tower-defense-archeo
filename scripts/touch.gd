extends Node
## Écran tactile (téléphone, tablette) : transforme les doigts en souris.
##   Toucher            : la souris se place sous le doigt (les infobulles s'affichent)
##   Toucher bref       : clic gauche, quand on lève le doigt
##   Appui long (0,45 s) : clic droit (retirer un mur ou une tour, annuler une relique)
##                        et l'infobulle reste affichée sans rien choisir
## Le clic se fait au relâché pour qu'on puisse d'abord lire l'infobulle en laissant le doigt.
## Nécessite input_devices/pointing/emulate_mouse_from_touch=false (project.godot).

const LONG_PRESS := 0.45
const MOVE_TOLERANCE := 24.0   # en pixels d'écran : au-delà, ce n'est plus un appui long

var finger := -1          # doigt suivi (un seul à la fois)
var start_pos := Vector2.ZERO
var held := 0.0
var long_done := false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			start_pos = event.position
			held = 0.0
			long_done = false
			_move(event.position)
		elif not event.pressed and event.index == finger:
			finger = -1
			_move(event.position)
			if not long_done:
				_click(event.position, MOUSE_BUTTON_LEFT)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_move(event.position)
		if event.position.distance_to(start_pos) > MOVE_TOLERANCE:
			long_done = true  # on a glissé : pas de clic au relâché
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if finger == -1 or long_done:
		return
	held += delta / maxf(Engine.time_scale, 0.01)  # en vraies secondes, même en vitesse x2
	if held >= LONG_PRESS:
		long_done = true
		_click(start_pos, MOUSE_BUTTON_RIGHT)


## Les positions des doigts sont déjà dans les coordonnées du jeu (960x736) ;
## un événement souris injecté repasse par la mise à l'échelle de la fenêtre,
## donc on le remet d'abord en coordonnées de la fenêtre.
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func _move(game_pos: Vector2) -> void:
	var pos := _to_window(game_pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func _click(game_pos: Vector2, button: MouseButton) -> void:
	var pos := _to_window(game_pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
