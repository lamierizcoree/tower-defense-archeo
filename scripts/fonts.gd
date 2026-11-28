extends Node
## Police de secours pour les symboles (★ ⚔ ☠ ⚗ ♜ ■ ▶...).
## Sur ordinateur, le système les trouve tout seul ; dans un navigateur (version web),
## Godot n'a pas accès aux polices du système, donc on fournit DejaVu Sans.

const SYMBOLS := preload("res://art/fonts/DejaVuSans.ttf")


func _ready() -> void:
	var font := ThemeDB.fallback_font
	if font and not SYMBOLS in font.fallbacks:
		font.fallbacks = font.fallbacks + [SYMBOLS]
