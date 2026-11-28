extends Node
## Adapte l'affichage à la taille de la fenêtre ou de l'écran (PC 16:9, 16:10, ultra-large, 4K,
## téléphone en paysage ou en portrait).
##
## Chaque écran dessine dans une « zone de jeu » de taille fixe (960x736 par défaut, voir
## Grid.SCREEN). On agrandit cette zone le plus possible sans la déformer, on la centre, et le
## fond de l'écran remplit les bords (voir visible_rect). La mise à l'échelle passe par la
## transformation du canevas : get_global_mouse_position() reste dans les coordonnées de la zone,
## donc les écrans n'ont rien à convertir.
##
## Un écran peut proposer plusieurs dispositions : s'il a une méthode pick_layout(visible: Vector2)
## qui renvoie la taille de sa zone, elle est appelée à chaque changement de taille (voir level.gd).
##
## F11 ou Alt+Entrée : plein écran (PC).

const BASE := Vector2(960, 736)

var design := BASE          # taille de la zone de l'écran en cours
var zoom := 1.0             # agrandissement de la zone (1 = taille de base du projet)
var offset := Vector2.ZERO  # décalage de la zone pour la centrer
var portrait := false       # téléphone tenu en hauteur : on suggère de le tourner

var _hint_layer: CanvasLayer
var _hint: Node2D


func _ready() -> void:
	get_viewport().size_changed.connect(refit)
	get_tree().scene_changed.connect(refit)
	# Message « tourne ton téléphone », au-dessus de tout et hors de la zone de jeu
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 100
	add_child(_hint_layer)
	_hint = Node2D.new()
	_hint_layer.add_child(_hint)
	_hint.draw.connect(_draw_hint)
	refit.call_deferred()


## Recalcule la zone de jeu de l'écran en cours et la transformation du canevas.
func refit() -> void:
	var vis := get_viewport().get_visible_rect().size
	if vis.x <= 0.0 or vis.y <= 0.0:
		return
	var scene := get_tree().current_scene
	var d := BASE
	if scene and scene.has_method("pick_layout"):
		d = scene.pick_layout(vis)
	design = d
	Grid.SCREEN = d
	zoom = minf(vis.x / d.x, vis.y / d.y)
	offset = ((vis - d * zoom) / 2.0).floor()
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, offset)
	portrait = vis.y > vis.x * 1.15
	_hint.queue_redraw()
	if scene is CanvasItem:
		scene.queue_redraw()


## Ce qui est visible à l'écran, dans les coordonnées de la zone de jeu (déborde de la zone
## quand l'écran est plus large ou plus haut qu'elle) : à utiliser pour peindre le fond.
func visible_rect() -> Rect2:
	var vis := get_viewport().get_visible_rect().size
	return Rect2(-offset / zoom, vis / zoom).grow(2.0)


## Taille de la zone si on l'affiche dans vis : pour comparer deux dispositions.
static func fit_zoom(vis: Vector2, d: Vector2) -> float:
	return minf(vis.x / d.x, vis.y / d.y)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11 or (event.keycode in [KEY_ENTER, KEY_KP_ENTER] and event.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		return  # sur le web, c'est le navigateur qui gère (ou l'installation en appli)
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Téléphone en portrait : la grille est en paysage, on invite à tourner l'appareil,
## dans la bande libre sous la zone de jeu.
func _draw_hint() -> void:
	if not portrait:
		return
	var vis := get_viewport().get_visible_rect().size
	var band_top := offset.y + design.y * zoom
	var band_h := vis.y - band_top
	if band_h < 60.0:
		return
	var font := ThemeDB.fallback_font
	var size := clampf(vis.x / 26.0, 16.0, 48.0)
	var center := Vector2(vis.x / 2.0, band_top + band_h * 0.4)
	# Petit téléphone qui pivote
	var w := size * 1.3
	var h := size * 2.2
	_hint.draw_set_transform(center + Vector2(0, -size * 0.8), -PI / 4.0)
	_hint.draw_rect(Rect2(Vector2(-w, -h) / 2.0, Vector2(w, h)), Color(1, 1, 1, 0.75), false, maxf(2.0, size / 10.0))
	_hint.draw_set_transform(Vector2.ZERO)
	_hint.draw_string(font, Vector2(0, center.y + size * 1.4), "Tourne ton téléphone", HORIZONTAL_ALIGNMENT_CENTER, vis.x, int(size), Color(1, 1, 1, 0.85))
	_hint.draw_string(font, Vector2(0, center.y + size * 2.6), "pour jouer en grand", HORIZONTAL_ALIGNMENT_CENTER, vis.x, int(size * 0.75), Color(1, 1, 1, 0.55))
