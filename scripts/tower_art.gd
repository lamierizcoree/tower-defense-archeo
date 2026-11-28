class_name TowerArt
extends RefCounted
## Dessin détaillé des tours, vues de trois quarts avec la lumière en haut à gauche.
## Chaque tour a un socle de pierre posé sur son mur, puis son arme, qui se tourne
## vers sa dernière cible (aim, en radians). kick va de 1 (tir à l'instant) à 0.

const STONE := Color("9a8c7a")
const STONE_DARK := Color("62584b")
const WOOD := Color("8a5a32")
const WOOD_DARK := Color("4e321c")
const IRON := Color("4a4f57")
const BRASS := Color("c99a3c")
const COPPER := Color("b8673a")


static func draw(c: CanvasItem, type_id: String, accent: Color, aim: float, kick: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Ombre portée au sol
	c.draw_colored_polygon(Art.ellipse(Vector2(4, 12), Vector2(18, 8)), Color(0, 0, 0, 0.28))
	match type_id:
		"arbalete":
			_round_base(c, 16.0, accent)
			_crossbow(c, aim, kick, 15.0, 5.0, WOOD, accent.darkened(0.2), Color("d9dde2"))
		"baliste":
			_square_base(c, 19.0, accent)
			_crossbow(c, aim, kick, 19.0, 8.0, WOOD_DARK, IRON, Color("e8e8e8"), true)
		"mortier":
			_round_base(c, 17.0, accent)
			_mortar(c, aim, kick)
		"givre":
			_hex_base(c, 15.0, accent)
			_crystal(c, t)
		"alambic":
			_round_base(c, 16.0, accent)
			_still(c, t, accent)
		"totem":
			_totem(c, t, accent)
		_:
			c.draw_circle(Vector2.ZERO, 14.0, accent)


# --- Socles ------------------------------------------------------------------

## Socle rond : un cylindre de pierre avec un liseré de la couleur de la tour.
static func _round_base(c: CanvasItem, r: float, accent: Color) -> void:
	c.draw_colored_polygon(Art.ellipse(Vector2(0, 6), Vector2(r, r * 0.62)), STONE_DARK)
	c.draw_rect(Rect2(-r, 0, r * 2, 6), STONE_DARK)
	c.draw_colored_polygon(Art.ellipse(Vector2.ZERO, Vector2(r, r * 0.62)), STONE)
	# joints des pierres sur le côté
	for k in [-0.6, 0.0, 0.6]:
		c.draw_line(Vector2(k * r, r * 0.55), Vector2(k * r, r * 0.55 + 5), Color(0, 0, 0, 0.3), 1.0)
	c.draw_arc(Vector2.ZERO, r - 1, PI * 1.05, PI * 1.95, 12, Color(1, 1, 1, 0.25), 1.5)  # reflet
	# anneau de couleur : on reconnaît la tour d'un coup d'œil
	c.draw_polyline(_closed(Art.ellipse(Vector2.ZERO, Vector2(r - 3, (r - 3) * 0.62))), Color(accent, 0.9), 2.0)


## Socle carré à créneaux (Baliste).
static func _square_base(c: CanvasItem, r: float, accent: Color) -> void:
	c.draw_rect(Rect2(-r, -r * 0.7 + 6, r * 2, r * 1.4), STONE_DARK)
	c.draw_rect(Rect2(-r, -r * 0.7, r * 2, r * 1.4), STONE)
	c.draw_line(Vector2(-r, -r * 0.7), Vector2(r, -r * 0.7), Color(1, 1, 1, 0.3), 1.5)
	for x in [-r, r - 7]:
		for y in [-r * 0.7 - 3, r * 0.7 - 7]:
			c.draw_rect(Rect2(x, y, 7, 7), STONE.lightened(0.1))
			c.draw_rect(Rect2(x, y + 7, 7, 3), STONE_DARK)
	c.draw_rect(Rect2(-r + 3, -r * 0.7 + 3, r * 2 - 6, r * 1.4 - 6), Color(accent, 0.8), false, 1.5)


## Socle hexagonal (Givre).
static func _hex_base(c: CanvasItem, r: float, accent: Color) -> void:
	var top := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0
		top.append(Vector2(cos(a) * r, sin(a) * r * 0.62))
	var side := PackedVector2Array()
	for p in top:
		side.append(p + Vector2(0, 6))
	c.draw_colored_polygon(side, STONE_DARK.lerp(Color("4a6a80"), 0.3))
	c.draw_rect(Rect2(-r, 0, r * 2, 6), STONE_DARK.lerp(Color("4a6a80"), 0.3))
	c.draw_colored_polygon(top, STONE.lerp(Color("b8d2e0"), 0.35))
	c.draw_polyline(_closed(top), Color(accent, 0.9), 1.5)


# --- Armes -------------------------------------------------------------------

## Arbalète et Baliste : un fût en bois, un arc, une corde et un carreau.
static func _crossbow(c: CanvasItem, aim: float, kick: float, size: float, thick: float,
		stock: Color, limb: Color, bolt: Color, heavy := false) -> void:
	var dir := Vector2.from_angle(aim)
	var side := dir.orthogonal()
	var lift := Vector2(0, -6)  # l'arme est posée au-dessus du socle
	var back := -dir * kick * 3.0  # recul au tir
	var o := lift + back
	# support
	c.draw_circle(lift + Vector2(0, 2), thick * 0.9, WOOD_DARK)
	# fût
	c.draw_line(o - dir * size * 0.75, o + dir * size * 0.9, stock.darkened(0.35), thick + 2)
	c.draw_line(o - dir * size * 0.75, o + dir * size * 0.9, stock, thick)
	c.draw_line(o - dir * size * 0.75 + side * thick * 0.2, o + dir * size * 0.9 + side * thick * 0.2, stock.lightened(0.25), 1.0)
	# arc courbé
	var arc := PackedVector2Array()
	for i in 9:
		var u := -1.0 + i / 4.0
		arc.append(o + dir * (size * 0.55 - size * 0.35 * u * u) + side * size * u)
	c.draw_polyline(arc, limb.darkened(0.4), (4.0 if heavy else 3.0) + 2.0)
	c.draw_polyline(arc, limb, 4.0 if heavy else 3.0)
	# corde : tendue en arrière, relâchée juste après le tir
	var nock := o + dir * (size * 0.05 if kick < 0.2 else size * 0.45)
	c.draw_line(arc[0], nock, Color(0.95, 0.92, 0.85, 0.9), 1.0)
	c.draw_line(arc[arc.size() - 1], nock, Color(0.95, 0.92, 0.85, 0.9), 1.0)
	# carreau prêt à partir
	if kick < 0.2:
		c.draw_line(nock, o + dir * size * 1.05, bolt, 2.5 if heavy else 1.5)
		var tip := o + dir * size * 1.05
		c.draw_colored_polygon(PackedVector2Array([tip + dir * 5, tip + side * 3, tip - side * 3]), IRON.lightened(0.3))
	# rivets de métal
	c.draw_circle(o + dir * size * 0.55, 2.0, BRASS)
	if heavy:
		c.draw_circle(o - dir * size * 0.5 + side * 4, 2.0, BRASS)
		c.draw_circle(o - dir * size * 0.5 - side * 4, 2.0, BRASS)


## Mortier : un gros fût de bronze incliné vers la cible, fumée au tir.
static func _mortar(c: CanvasItem, aim: float, kick: float) -> void:
	var dir := Vector2.from_angle(aim)
	var o := Vector2(0, -5) - dir * kick * 2.0
	var mouth := o + dir * 5.0 + Vector2(0, -4)
	# affût en bois
	c.draw_rect(Rect2(-12, -6, 24, 8), WOOD_DARK)
	c.draw_rect(Rect2(-12, -8, 24, 4), WOOD)
	# fût
	c.draw_circle(o, 11.0, BRASS.darkened(0.35))
	c.draw_line(o, mouth, BRASS.darkened(0.2), 18.0)
	c.draw_circle(mouth, 9.5, BRASS)
	c.draw_arc(mouth, 9.5, PI * 1.0, PI * 1.6, 8, BRASS.lightened(0.4), 2.0)
	c.draw_circle(mouth, 6.0, Color("1c1712"))
	c.draw_arc(mouth, 9.5, 0.0, TAU, 20, BRASS.darkened(0.45), 1.5)
	# frettes
	c.draw_circle(o + Vector2(-10, 0), 2.5, IRON)
	c.draw_circle(o + Vector2(10, 0), 2.5, IRON)
	if kick > 0.0:
		for i in 3:
			var p := mouth + Vector2(-6 + i * 6, -6 - i * 3) * (1.6 - kick)
			c.draw_circle(p, 5.0 + i, Color(0.85, 0.82, 0.78, 0.55 * kick))
		c.draw_circle(mouth, 7.0, Color(1.0, 0.7, 0.2, 0.7 * kick))


## Givre : des éclats de glace qui flottent au-dessus du socle, avec un halo.
static func _crystal(c: CanvasItem, t: float) -> void:
	var bob := sin(t * 2.2) * 2.0
	var glow := 0.18 + 0.08 * sin(t * 3.0)
	c.draw_circle(Vector2(0, -6 + bob), 16.0, Color(0.6, 0.9, 1.0, glow))
	var shards := [[Vector2(0, -10), 18.0, 6.0], [Vector2(-8, -4), 12.0, 4.5], [Vector2(8, -3), 11.0, 4.0]]
	for sh in shards:
		var base: Vector2 = sh[0] + Vector2(0, bob)
		var h: float = sh[1]
		var w: float = sh[2]
		var top := base + Vector2(0, -h * 0.7)
		var bot := base + Vector2(0, h * 0.3)
		# face à l'ombre, face éclairée
		c.draw_colored_polygon(PackedVector2Array([top, base + Vector2(w, 0), bot]), Color("5fb3d6"))
		c.draw_colored_polygon(PackedVector2Array([top, bot, base + Vector2(-w, 0)]), Color("c9f0ff"))
		c.draw_line(top, bot, Color(1, 1, 1, 0.9), 1.0)
		c.draw_polyline(PackedVector2Array([top, base + Vector2(w, 0), bot, base + Vector2(-w, 0), top]), Color("2f7fa6"), 1.0)
	# petites étincelles de froid
	for i in 3:
		var a := t * 1.5 + i * TAU / 3.0
		c.draw_circle(Vector2(cos(a) * 14.0, -6 + sin(a) * 6.0 + bob), 1.5, Color(1, 1, 1, 0.8))


## Alambic : une cuve de cuivre, une fenêtre sur le liquide qui bouillonne et un col.
static func _still(c: CanvasItem, t: float, accent: Color) -> void:
	var o := Vector2(0, -6)
	# col et serpentin
	c.draw_line(o + Vector2(2, -9), o + Vector2(9, -17), COPPER.darkened(0.3), 5.0)
	c.draw_line(o + Vector2(2, -9), o + Vector2(9, -17), COPPER, 3.0)
	c.draw_circle(o + Vector2(11, -16), 4.0, COPPER.darkened(0.1))
	# cuve
	c.draw_circle(o, 12.0, COPPER.darkened(0.35))
	c.draw_circle(o + Vector2(-1, -1), 11.0, COPPER)
	c.draw_arc(o + Vector2(-1, -1), 8.0, PI * 1.05, PI * 1.55, 8, COPPER.lightened(0.45), 2.5)
	# fenêtre de verre avec le poison
	c.draw_circle(o + Vector2(0, 3), 6.0, Color("2a3a20"))
	c.draw_circle(o + Vector2(0, 4), 5.0, accent.lightened(0.1))
	for i in 3:
		var phase := fmod(t * 1.3 + i * 0.33, 1.0)
		c.draw_circle(o + Vector2(-2 + i * 2, 6 - phase * 6), 1.2, Color(0.85, 1.0, 0.7, 1.0 - phase))
	# cerclages de laiton
	c.draw_arc(o, 11.5, PI * 0.1, PI * 0.9, 10, BRASS, 1.5)
	# vapeurs toxiques qui s'échappent
	for i in 2:
		var phase := fmod(t * 0.7 + i * 0.5, 1.0)
		c.draw_circle(o + Vector2(12 + phase * 4, -20 - phase * 10), 2.5 + phase * 3.0, Color(accent, 0.45 * (1.0 - phase)))


## Totem : un mât sculpté de visages, avec des ailes au sommet.
static func _totem(c: CanvasItem, t: float, accent: Color) -> void:
	c.draw_colored_polygon(Art.ellipse(Vector2(0, 10), Vector2(13, 6)), STONE_DARK)
	c.draw_colored_polygon(Art.ellipse(Vector2(0, 8), Vector2(13, 6)), STONE)
	var colors := [WOOD, accent.darkened(0.15), WOOD.lightened(0.1)]
	for i in 3:
		var y := 4.0 - i * 9.0
		var r := Rect2(-7, y - 9, 14, 10)
		c.draw_rect(r, colors[i])
		c.draw_rect(Rect2(r.end.x - 4, r.position.y, 4, r.size.y), Color(0, 0, 0, 0.25))  # côté à l'ombre
		c.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.3), 1.0)
		# visage sculpté
		c.draw_rect(Rect2(-5, y - 7, 3, 2), Color("1e140c"))
		c.draw_rect(Rect2(1, y - 7, 3, 2), Color("1e140c"))
		c.draw_line(Vector2(-3, y - 3), Vector2(3, y - 3), Color("1e140c"), 1.5)
	# ailes au sommet, qui battent doucement
	var flap := 2.0 * sin(t * 2.5)
	for k in [-1, 1]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(k * 6, -21), Vector2(k * 17, -27 - flap), Vector2(k * 15, -19), Vector2(k * 7, -16)]), accent.lightened(0.15))
		c.draw_line(Vector2(k * 7, -20), Vector2(k * 15, -24 - flap), accent.darkened(0.3), 1.0)
	c.draw_circle(Vector2(0, -22), 3.0, Color("e8d080"))


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
