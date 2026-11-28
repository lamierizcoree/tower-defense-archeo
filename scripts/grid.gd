class_name Grid
extends RefCounted
## Taille de la grille et conversions entre cases et pixels.

const COLS := 20          # nombre de colonnes
const ROWS := 12          # nombre de lignes
const CELL := 48          # taille d'une case en pixels
const OFFSET := Vector2(0, 64)  # la grille commence sous la barre d'infos
## Taille de la zone de jeu de l'écran en cours (960x736, ou plus large pour un niveau sur
## écran large) : mise à jour par Screen (screen.gd) selon la taille de la fenêtre.
static var SCREEN := Vector2(960, 736)

const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## Centre d'une case, en pixels.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return OFFSET + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


## Case qui se trouve sous un point en pixels.
static func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(((point - OFFSET) / CELL).floor())


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


## Rectangle d'une case, en pixels.
static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(OFFSET + Vector2(cell) * CELL, Vector2(CELL, CELL))
