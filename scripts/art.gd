class_name Art
extends RefCounted
## Dessins détaillés partagés : murs en pierre taillée et petits outils de dessin.
## Tout est dessiné par code (pas d'images) : ombres, faces éclairées et faces à l'ombre
## donnent du relief avec une lumière qui vient d'en haut à gauche.

const BRICK_H := 8.0      # hauteur d'une rangée de pierres
const BRICK_W := 16.0     # largeur d'une pierre
const WALL_FRONT := 9.0   # hauteur de la face avant visible d'un mur
const SHADOW := Color(0, 0, 0, 0.22)

## Couleurs des murs selon le biome.
const WALL_PALETTES := {
	"desert": {"top": Color("c9a56b"), "mortar": Color("86683f"), "front": Color("94713f"),
		"edge": Color("e6c98e"), "base": Color("5e4528")},
	"glace": {"top": Color("98a6b3"), "mortar": Color("56636f"), "front": Color("66737f"),
		"edge": Color("c9d6e0"), "base": Color("3b4550"), "snow": Color("f4f8fb")},
}


## Petit hasard stable pour une position (même résultat à chaque image).
static func hash01(a: int, b: int, c := 0) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


## Polygone d'une ellipse (pour les ombres et les socles vus en perspective).
static func ellipse(center: Vector2, radius: Vector2, points := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


## Ombres de tous les murs (à dessiner avant les murs eux-mêmes).
static func draw_wall_shadows(canvas: CanvasItem, walls: Dictionary) -> void:
	for cell in walls:
		var r := Grid.cell_rect(cell)
		var right := not walls.has(cell + Vector2i(1, 0))
		var below := not walls.has(cell + Vector2i(0, 1))
		var above := walls.has(cell + Vector2i(0, -1))
		var left := walls.has(cell + Vector2i(-1, 0))
		# les ombres se prolongent d'une case à l'autre, sans trou
		if right:
			var y0 := r.position.y + (0.0 if above else 6.0)
			canvas.draw_rect(Rect2(r.end.x - 2, y0, 6, r.end.y - y0 + (0.0 if below else 4.0)), SHADOW)
		if below:
			var x0 := r.position.x + (0.0 if left else 5.0)
			canvas.draw_rect(Rect2(x0, r.end.y - 1, r.end.x - x0 - (2.0 if right else 0.0), 5), SHADOW)


## Un mur : un bloc de pierres taillées qui se raccorde à ses voisins.
static func draw_wall(canvas: CanvasItem, cell: Vector2i, walls: Dictionary, biome_id: String, sealed: bool) -> void:
	var pal: Dictionary = WALL_PALETTES.get(biome_id, WALL_PALETTES["desert"])
	var r := Grid.cell_rect(cell)
	var n := walls.has(cell + Vector2i(0, -1))
	var s := walls.has(cell + Vector2i(0, 1))
	var w := walls.has(cell + Vector2i(-1, 0))
	var e := walls.has(cell + Vector2i(1, 0))
	var left := r.position.x + (0.0 if w else 3.0)
	var right := r.end.x - (0.0 if e else 3.0)
	var top := r.position.y + (0.0 if n else 2.0)
	var bottom := r.end.y - (0.0 if s else 2.0)
	var face_bottom := bottom if s else bottom - WALL_FRONT

	# Dessus : rangées de pierres décalées, alignées sur toute la grille pour se raccorder
	var face := Rect2(left, top, right - left, face_bottom - top)
	canvas.draw_rect(face, pal["mortar"])
	var row0 := int(floor((top - Grid.OFFSET.y) / BRICK_H))
	var row1 := int(ceil((face_bottom - Grid.OFFSET.y) / BRICK_H))
	for row in range(row0, row1):
		var y0 := Grid.OFFSET.y + row * BRICK_H
		var shift := (BRICK_W / 2.0) if row % 2 != 0 else 0.0
		var k0 := int(floor((left - shift) / BRICK_W))
		var k1 := int(ceil((right - shift) / BRICK_W))
		for k in range(k0, k1):
			var x0 := shift + k * BRICK_W
			var brick := Rect2(x0 + 1, y0 + 1, BRICK_W - 2, BRICK_H - 2).intersection(face)
			if brick.size.x <= 0.5 or brick.size.y <= 0.5:
				continue
			var v := hash01(k, row)
			var col: Color = pal["top"].darkened(0.12 * v) if v < 0.5 else pal["top"].lightened(0.08 * (v - 0.5))
			canvas.draw_rect(brick, col)
			# arête éclairée en haut de chaque pierre
			canvas.draw_line(brick.position, Vector2(brick.end.x, brick.position.y), Color(pal["edge"], 0.45), 1.0)
			if v > 0.85:
				# fissure ou pierre usée
				canvas.draw_line(brick.position + Vector2(3, 2), brick.position + Vector2(7, brick.size.y - 1), Color(pal["mortar"], 0.8), 1.0)

	# Neige sur les murs de glace
	if pal.has("snow") and not n:
		var snow: Color = pal["snow"]
		canvas.draw_rect(Rect2(left, top, right - left, 4), snow)
		for i in 3:
			var x := left + 4 + hash01(cell.x, cell.y, i) * (right - left - 12)
			canvas.draw_circle(Vector2(x, top + 4), 3.0 + hash01(cell.y, cell.x, i) * 2.0, snow)

	# Bords éclairés (haut, gauche) et à l'ombre (droite)
	if not n:
		canvas.draw_line(Vector2(left, top + 0.5), Vector2(right, top + 0.5), pal["edge"], 1.5)
	if not w:
		canvas.draw_line(Vector2(left + 0.5, top), Vector2(left + 0.5, face_bottom), Color(pal["edge"], 0.7), 1.0)
	if not e:
		canvas.draw_line(Vector2(right - 0.5, top), Vector2(right - 0.5, bottom), Color(0, 0, 0, 0.25), 1.5)

	# Face avant : la hauteur du mur, plus sombre
	if not s:
		var front := Rect2(left, face_bottom, right - left, WALL_FRONT)
		canvas.draw_rect(front, pal["front"])
		var row := int(floor((face_bottom - Grid.OFFSET.y) / BRICK_H))
		var shift := (BRICK_W / 2.0) if row % 2 != 0 else 0.0
		var k0 := int(ceil((left - shift) / BRICK_W))
		var x := shift + k0 * BRICK_W
		while x < right:
			canvas.draw_line(Vector2(x, face_bottom), Vector2(x, front.end.y), Color(pal["mortar"], 0.9), 1.0)
			x += BRICK_W
		canvas.draw_line(Vector2(left, face_bottom + 0.5), Vector2(right, face_bottom + 0.5), Color(pal["edge"], 0.35), 1.0)
		canvas.draw_line(Vector2(left, front.end.y - 0.5), Vector2(right, front.end.y - 0.5), pal["base"], 1.5)

	if sealed:
		# Rune du sceau gravée dans la pierre, qui luit doucement
		var c := Vector2((left + right) / 2.0, (top + face_bottom) / 2.0)
		var q := Grid.CELL * 0.2
		var glow := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 400.0 + cell.x)
		var pts := PackedVector2Array([c + Vector2(0, -q), c + Vector2(q, 0), c + Vector2(0, q), c + Vector2(-q, 0), c + Vector2(0, -q)])
		canvas.draw_polyline(pts, Color(0.6, 0.8, 1.0, glow), 2.0)
		canvas.draw_circle(c, 2.5, Color(0.8, 0.9, 1.0, glow))
