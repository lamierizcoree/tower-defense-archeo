class_name UI
extends RefCounted
## Petits outils de dessin partagés par les écrans (boutons).


## Dessine un bouton. hot = souris dessus.
static func button(canvas: CanvasItem, rect: Rect2, text: String, hot: bool, enabled := true, size := 16) -> void:
	var font := ThemeDB.fallback_font
	var bg := Color(1, 1, 1, 0.16 if (hot and enabled) else 0.07)
	canvas.draw_rect(rect, bg)
	canvas.draw_rect(rect, Color("ffe066") if (hot and enabled) else Color(1, 1, 1, 0.25), false, 2.0 if hot else 1.0)
	var color := Color.WHITE if enabled else Color(1, 1, 1, 0.35)
	canvas.draw_string(font, rect.position + Vector2(0, rect.size.y / 2 + size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)
